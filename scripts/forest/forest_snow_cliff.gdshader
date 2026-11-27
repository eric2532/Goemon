shader_type spatial;
#include "res://scripts/forest/forest_archive_palette.gdshaderinc"
uniform sampler2D base_texture : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D brush_texture : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 point;
void vertex(){point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 native=archive_color(texture(base_texture,UV,2.0).rgb);
 float snow=smoothstep(.60,.84,min(native.r,min(native.g,native.b)));
 float brush=texture(brush_texture,point.xz*.045+point.yy*.025).g;
 // Broad painted masses keep the native rock/snow boundaries without enlarged pixel contrast.
 float light=dot(native,vec3(.2126,.7152,.0722));
 vec3 stone=mix(native,vec3(light),.30);
 stone=mix(stone,vec3(.37,.40,.40),.72)*(.96+brush*.08);
 vec3 cap=mix(vec3(.73,.82,.86),vec3(.91,.95,.96),brush);
 vec3 color=mix(stone,cap,snow);
 ALBEDO=color*.84;EMISSION=color*.16;ROUGHNESS=1.0;SPECULAR=.025;
}
