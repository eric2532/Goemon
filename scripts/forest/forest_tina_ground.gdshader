shader_type spatial;
#include "res://scripts/forest/forest_archive_palette.gdshaderinc"
render_mode cull_back;
uniform sampler2D continuous_floor : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 map_origin;
varying vec2 source_point;
void vertex(){source_point=(VERTEX.xz-map_origin)/3.0;}
void fragment(){
 vec3 color=texture(continuous_floor,(source_point+.5)/100.0).rgb;
 ALBEDO=vec3(0.0);EMISSION=archive_color(color);ROUGHNESS=.96;SPECULAR=0.0;
}
