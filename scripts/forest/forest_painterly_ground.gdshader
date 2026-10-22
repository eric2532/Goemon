shader_type spatial;
render_mode cull_back;
uniform sampler2D visibility_map : filter_linear, repeat_disable;
uniform vec4 base_color : source_color = vec4(0.38,0.53,0.27,1.0);
uniform bool ground_surface = false;
uniform bool show_grid = false;
uniform vec2 hero_position = vec2(0.0);
uniform bool canopy_cutaway = false;
uniform bool canopy_layer = false;
uniform sampler2D painted_ground : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_point;
varying vec3 object_origin;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;object_origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;}
void fragment(){
 vec2 sample_point=ground_surface ? world_point.xz : object_origin.xz;
 vec2 map_uv=(sample_point/6.0+vec2(40.5))/80.0;
 vec2 sight=texture(visibility_map,map_uv).rg;
 if(canopy_layer && canopy_cutaway && distance(object_origin.xz,hero_position)<15.0) discard;
 float explored=smoothstep(.04,.96,sight.r);
 float visible=smoothstep(.05,.9,sight.g);
 float noise=sin(world_point.x*.11+sin(world_point.z*.17))*sin(world_point.z*.23);
 vec3 paint=texture(painted_ground,world_point.xz/19.0).rgb;
 // Roads keep a worn earth tint; raised stone walls retain their own material.
 if(!ground_surface) paint=mix(paint,vec3(.25,.18,.10),.40);
 vec3 hidden;
 if(ground_surface){
  hidden=pow(mix(vec3(.16,.235,.205),vec3(.20,.28,.23),noise*.2+.5),vec3(2.2));
 }else{
  hidden=mix(pow(vec3(.075,.15,.13),vec3(2.2)),base_color.rgb*COLOR.rgb,.48);
  hidden*=mix(.8,1.2,clamp(world_point.y/28.0,0.0,1.0));
 }
 // Painted scenery also has texture under fog. Scouting, actors and grid
 // visibility still use the unchanged visibility map.
 hidden=mix(hidden,paint*.30,.85);
 paint=mix(hidden,paint*mix(.38,1.0,visible),explored);
 float haze=smoothstep(60.0,255.0,distance(world_point.xz,hero_position));
 vec3 mist=pow(vec3(.42,.51,.44),vec3(2.2));
 paint=mix(paint,mist,haze*.72*(1.0-visible*.45));
 if(ground_surface && show_grid){vec2 line=abs(fract(world_point.xz/6.0+.5)-.5);float grid=smoothstep(.478,.499,max(line.x,line.y));paint=mix(paint,vec3(.65,.55,.32),grid*.25*sight.r);}
 ALBEDO=paint;EMISSION=paint*.16;ROUGHNESS=1.0;
}
