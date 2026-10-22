shader_type spatial;
render_mode cull_disabled, unshaded;

uniform bool use_texture = true;
uniform sampler2D source_texture : source_color, filter_nearest, repeat_disable;
uniform vec2 source_size = vec2(32.0, 64.0);
uniform vec2 tile_modes = vec2(2.0);
uniform vec2 mask_period = vec2(32.0, 64.0);
uniform vec2 tile_shift = vec2(1.0);
uniform vec2 tile_origin = vec2(0.0);

// Native renderer 80204D70 calls 8006D920: an unlit camera-facing sprite.
void vertex() {
 vec3 source_scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * source_scale.x, INV_VIEW_MATRIX[1] * source_scale.y, INV_VIEW_MATRIX[2] * source_scale.z, MODEL_MATRIX[3]);
 MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

int masked_texel(int value, int period, int mode) {
	if (period == 0) {
		return value;
	}
	int wrapped = value & (period - 1);
	if ((mode & 1) != 0 && (value & period) != 0) {
		wrapped = period - 1 - wrapped;
	}
	return wrapped;
}

vec4 source_texel(ivec2 coordinate) {
	ivec2 wrapped = ivec2(
		masked_texel(coordinate.x, int(mask_period.x), int(tile_modes.x)),
		masked_texel(coordinate.y, int(mask_period.y), int(tile_modes.y)));
	return texture(source_texture, (vec2(wrapped) + vec2(0.5)) / source_size);
}

void fragment() {
	// RDP order: tile shift/origin, clamp, then independently mask/mirror each
	// neighbouring integer texel. Never repeat the whole PNG for a smaller mask.
	vec2 coordinate = UV * source_size * tile_shift - tile_origin;
	if ((int(tile_modes.x) & 2) != 0 || mask_period.x == 0.0) {
		coordinate.x = clamp(coordinate.x, 0.0, source_size.x - 1.0);
	}
	if ((int(tile_modes.y) & 2) != 0 || mask_period.y == 0.0) {
		coordinate.y = clamp(coordinate.y, 0.0, source_size.y - 1.0);
	}
	ivec2 base = ivec2(floor(coordinate));
	vec2 fraction = floor(fract(coordinate) * 32.0) / 32.0;
	vec4 c00 = source_texel(base);
	vec4 c10 = source_texel(base + ivec2(1, 0));
	vec4 c01 = source_texel(base + ivec2(0, 1));
	vec4 c11 = source_texel(base + ivec2(1, 1));
	vec4 color;
	// Original G_TF_BILERP is a three-point triangular filter.
	if (fraction.x + fraction.y < 1.0) {
		color = c00 + fraction.x * (c10 - c00) + fraction.y * (c01 - c00);
	} else {
		color = c11 + (1.0 - fraction.x) * (c01 - c11) + (1.0 - fraction.y) * (c10 - c11);
	}
	if (color.a * COLOR.a < 0.1) {
		discard;
	}
	ALBEDO = (use_texture ? color.rgb : vec3(1.0)) * COLOR.rgb;
	ROUGHNESS = 0.82;
	SPECULAR = 0.0;
}
