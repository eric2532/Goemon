shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D visibility_map : filter_linear, repeat_disable;
uniform sampler2D wood_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool road_mode=false;
uniform vec2 hero_position=vec2(0.0);
uniform bool show_grid=false;
uniform bool compensate_filmic=true;
uniform float scene_exposure=1.05;
uniform float scene_white=1.0;
varying vec3 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float filmic_white(float x){return (x*(.88*x+.06)+.002)/(x*(.88*x+.60)+.06)-1.0/30.0;}
vec3 inverse_filmic(vec3 desired){
 vec3 k=clamp(desired,vec3(0),vec3(1))*filmic_white(max(scene_white,.001))+vec3(1.0/30.0);
 vec3 a=.88*(vec3(1)-k);vec3 b=.60*(vec3(.10)-k);vec3 c=.20*(vec3(.01)-.30*k);
 return max(vec3(0),(-b+sqrt(max(vec3(0),b*b-4.0*a*c)))/(2.0*a))/max(scene_exposure,.001);
}
void fragment(){
 vec4 texel=texture(albedo_texture,UV);if(road_mode && COLOR.r>.5)texel=texture(wood_texture,UV);if(texel.a<.5)discard;
 vec2 sight=texture(visibility_map,(world_point.xz/6.0+vec2(40.5))/80.0).rg;
 float explored=smoothstep(.04,.96,sight.r);float visible=smoothstep(.05,.9,sight.g);
 vec3 color=mix(mix(vec3(.055,.10,.065),texel.rgb,.40),texel.rgb*mix(.58,1.0,visible),explored);
 if(show_grid){vec2 line=abs(fract(world_point.xz/6.0+.5)-.5);float grid=smoothstep(.478,.499,max(line.x,line.y));color=mix(color,vec3(.65,.53,.30),grid*.15*explored);}
 float haze=smoothstep(145.0,360.0,distance(world_point.xz,hero_position));color=mix(color,vec3(.14,.22,.18),haze*.30*(1.0-visible*.5));
 ALBEDO=compensate_filmic?inverse_filmic(color):color;
}
