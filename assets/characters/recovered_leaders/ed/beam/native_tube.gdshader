shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
#include "res://assets/characters/recovered_leaders/ed/beam/source_color.gdshaderinc"
#include "res://assets/characters/recovered_leaders/ed/beam/native_lighting.gdshaderinc"
uniform bool native_lit = false;
uniform sampler2D index_page : filter_nearest, repeat_disable;
uniform sampler2D palettes : filter_nearest, repeat_disable;
uniform int palette_row = 0;
uniform int palette_rows = 16;
uniform bool compensate_filmic = false;
uniform float scene_exposure = 1.0;
uniform float scene_white = 1.0;
varying vec3 native_modulation;
void vertex() {
	native_modulation = native_lit ? vec3(native_gpu_rgb(COLOR.rgb, ivec3(128), MODEL_MATRIX)) / 128.0 : vec3(1.0);
}
void fragment() {
	float index = floor(texture(index_page, UV).r * 255.0 + 0.5);
	vec4 texel = texture(palettes, vec2((index + 0.5) / 16.0, (float(palette_row) + 0.5) / float(palette_rows)));
	if (texel.a < 0.5) discard;
	ALBEDO = source_output(clamp(texel.rgb * native_modulation, vec3(0.0), vec3(1.0)), compensate_filmic, scene_exposure, scene_white);
	ALPHA = 1.0;
}
