shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://assets/characters/recovered_leaders/ed/beam/source_color.gdshaderinc"
uniform vec3 source_tint = vec3(1.0);
uniform bool billboard = false;
uniform bool strip = false;
uniform float strip_width = 1.0;
uniform bool compensate_filmic = false;
uniform float scene_exposure = 1.0;
uniform float scene_white = 1.0;
void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
			INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
	}
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (strip) {
		vec4 a = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(0.0, 0.0, UV2.x, 1.0);
		vec4 b = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(0.0, 0.0, UV2.y, 1.0);
		vec2 delta = (b.xy / b.w - a.xy / a.w) * VIEWPORT_SIZE;
		vec2 perpendicular = vec2(delta.y, -delta.x) / VIEWPORT_SIZE;
		POSITION.xy += perpendicular * UV.x * strip_width * POSITION.w;
	}
}
void fragment() {
	ALBEDO = source_output(COLOR.rgb * source_tint, compensate_filmic, scene_exposure, scene_white);
	ALPHA = 1.0;
}
