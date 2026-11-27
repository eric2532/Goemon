shader_type spatial;
render_mode cull_back;
#include "res://scripts/forest/attack_range.gdshaderinc"
uniform sampler2D native_paint : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 native_eye=vec3(-.669,.323,.669);
varying vec3 local_point;
varying vec3 source_camera;
varying vec3 source_normal;
varying vec3 world_point;
varying vec3 world_normal;
void vertex(){
 local_point=VERTEX;
 source_normal=NORMAL;
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 source_camera=transpose(MODEL_NORMAL_MATRIX)*(CAMERA_POSITION_WORLD-MODEL_MATRIX[3].xyz);
}
void fragment(){
 vec3 weights=pow(abs(normalize(world_normal)),vec3(4.0));
 weights/=max(.001,weights.x+weights.y+weights.z);
 vec3 p=world_point*1.08;
 vec3 grain=texture(rock_texture,p.zy).rgb*weights.x+texture(rock_texture,p.xz).rgb*weights.y+texture(rock_texture,p.xy).rgb*weights.z;
 float grit=dot(grain,vec3(.2126,.7152,.0722));
 vec3 continued=COLOR.rgb*(.83+grit*.34);
 // Original-angle paint has evidence only around the recorded viewing direction.
 // Other angles retain complete stone volumes and independent moss/stone grain.
 float observed=smoothstep(.72,.94,dot(normalize(source_camera-local_point),normalize(native_eye)));
 // Projection cannot establish paint on the curved silhouette or hidden back.
 // Fade those grazing normals into the independent fixed-scale stone material.
 observed*=smoothstep(.28,.58,dot(normalize(source_normal),normalize(native_eye)));
 bool inside=all(greaterThanEqual(UV,vec2(0.0)))&&all(lessThan(UV,vec2(1.0)));
 vec4 original=texture(native_paint,UV);
 vec3 color=inside&&original.a>=.5?mix(continued,original.rgb,observed):continued;
 color=attack_range_ink(color,world_point,world_normal);
 ALBEDO=color;
 EMISSION=color*.10;
 ROUGHNESS=.96;
 SPECULAR=.12;
}
