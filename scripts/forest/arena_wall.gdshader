shader_type spatial;
render_mode cull_back;
uniform sampler2D base_texture : source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
uniform float roof_cutaway_height = 0.0;
uniform vec2 panel_size = vec2(12.0,36.0);
varying vec3 world_point;
varying vec3 world_normal;
varying float bay_width;
void vertex(){
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 bay_width=UV2.x;
}
void fragment(){
 if(CAMERA_POSITION_WORLD.y>roof_cutaway_height) discard;
 vec2 atlas=vec2(textureSize(base_texture,0));
 vec2 origin=floor(UV*atlas/vec2(36.0,100.0))*vec2(36.0,100.0)+vec2(2.5);
 vec2 chart=(UV*atlas-origin)/vec2(31.0,95.0);
 float along=abs(world_normal.x)>.5?world_point.z:world_point.x;
 // Only the plain stone repeats; windows, piers and trim keep their proportions.
 vec2 stone=vec2(fract(along/12.0),fract(world_point.y/9.0));
 vec2 lookup=origin+vec2(stone.x*31.0,32.0+stone.y*24.0);
 vec2 panel=vec2((chart.x-.5)*bay_width/panel_size.x+.5,(roof_cutaway_height-world_point.y)/panel_size.y);
 if(all(greaterThanEqual(panel,vec2(0.0))) && all(lessThanEqual(panel,vec2(1.0)))) lookup=origin+panel*vec2(31.0,95.0);
 if(world_point.y<6.0) lookup=origin+vec2(stone.x*31.0,95.0-world_point.y*2.0);
 vec3 color=textureGrad(base_texture,lookup/atlas,vec2(dFdx(along)/12.0*31.0,dFdx(world_point.y)/9.0*24.0)/atlas,vec2(dFdy(along)/12.0*31.0,dFdy(world_point.y)/9.0*24.0)/atlas).rgb;
 ALBEDO=color;ROUGHNESS=1.0;SPECULAR=.15;
}
