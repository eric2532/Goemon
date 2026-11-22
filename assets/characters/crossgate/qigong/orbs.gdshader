shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
instance uniform float frame = 0.0;
uniform bool instanced = false;
varying float orb_frame;
instance uniform float uru_palette = 0.0;
instance uniform float gold_palette = 0.0;
instance uniform vec4 qi_tint : source_color = vec4(1.0);
instance uniform float qi_chrome = 0.0;
#include "res://assets/characters/crossgate/qigong/chrome.gdshaderinc"

void vertex() {
 orb_frame=instanced ? mod(floor(INSTANCE_CUSTOM.x*30.0),8.0) : frame;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 atlas_size = vec2(textureSize(atlas, 0));
	vec2 cell_size = atlas_size / vec2(8.0, 1.0);
	vec2 texel = (UV * (cell_size - 1.0) + vec2(orb_frame * cell_size.x + 0.5, 0.5)) / atlas_size;
	vec4 source = texture(atlas, texel);
	// Both glow patterns are already painted into the source frames.
	vec3 base = mix(source.rgb, source.bgr * vec3(1.0, 0.85, 0.85), uru_palette);
	vec3 gold = vec3(source.b, max(source.g, source.b * 0.70), max(source.r * 0.35, source.b * 0.12));
	ALBEDO = mix(base, gold, gold_palette);
	if (distance(qi_tint.rgb, vec3(1.0)) > 0.001) {
		ALBEDO = max(max(source.r, source.g), source.b) * qi_tint.rgb;
	}
	if (qi_chrome > 0.5) {
		ALBEDO = rainbow_chrome(UV, max(max(source.r, source.g), source.b), TIME);
	}
	ALPHA = source.a;
}
