shader_type spatial;
#include "res://scripts/forest/forest_archive_palette.gdshaderinc"
render_mode cull_disabled;

uniform sampler2D floor_atlas : source_color, filter_linear;
uniform bool original_palette = false;
varying vec2 pool_point;

void vertex() {
 pool_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
}

void fragment() {
 vec3 original=texture(floor_atlas,UV).rgb;
 float broad=sin(pool_point.x*1.7+pool_point.y*.67+TIME*.78);
 float fine=sin(pool_point.y*2.1-pool_point.x*.86-TIME*.97);
 float glint=smoothstep(.67,1.0,broad*.63+fine*.37);
 ALBEDO=original*(.86+broad*.10+fine*.07)+vec3(.018,.051,.071)*glint;
 EMISSION=original_palette ? archive_color(original) : original*.12+vec3(.012,.041,.060)*glint;
 if(original_palette) ALBEDO=vec3(0.0);
 NORMAL_MAP=vec3(.5+broad*.033,.5+fine*.036,1.0);
 ROUGHNESS=.31;
 SPECULAR=original_palette ? 0.0 : .47;
}
