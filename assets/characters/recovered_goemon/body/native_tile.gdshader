shader_type spatial;
render_mode cull_disabled;

uniform sampler2D source_texture : source_color, filter_nearest, repeat_disable;
uniform vec2 source_size = vec2(32.0, 64.0);
uniform vec2 tile_modes = vec2(2.0);
uniform vec2 mask_period = vec2(32.0, 64.0);
uniform vec2 tile_shift = vec2(1.0);
uniform vec2 tile_origin = vec2(0.0);
// Optional costume presentation. Defaults preserve the original Goemon pixels.
uniform int costume_palette = 0;
uniform vec3 costume_emission : source_color = vec3(0.0);
uniform vec3 costume_maroon : source_color = vec3(0.447059, 0.184314, 0.243137);
uniform vec3 costume_navy : source_color = vec3(0.145098, 0.2, 0.266667);
uniform vec3 costume_gold : source_color = vec3(0.835294, 0.678431, 0.345098);
uniform vec3 costume_silver : source_color = vec3(0.886275, 0.866667, 0.878431);

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

vec3 costume_color(vec3 original) {
	bool blue = original.b > 0.2 && original.r < 0.1 && original.g < 0.1;
	if (costume_palette == 2 && blue) { return costume_silver; }
	if (costume_palette != 1) { return original; }
	if (blue) { return costume_gold; }
	if (original.r > 0.65 && original.g > 0.65 && original.b > 0.65) { return costume_navy; }
	if (original.r > 0.5 && original.g > 0.25 && original.b < 0.12) { return costume_gold; }
	if (original.r > 0.15 && original.g < 0.25 && original.r > original.b + 0.12) { return costume_maroon; }
	return original;
}

vec4 source_texel(ivec2 coordinate) {
	ivec2 wrapped = ivec2(
		masked_texel(coordinate.x, int(mask_period.x), int(tile_modes.x)),
		masked_texel(coordinate.y, int(mask_period.y), int(tile_modes.y)));
	vec4 color = texture(source_texture, (vec2(wrapped) + vec2(0.5)) / source_size);
	color.rgb = costume_color(color.rgb);
	return color;
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
	ALBEDO = color.rgb * COLOR.rgb;
	EMISSION = costume_emission;
	ROUGHNESS = 0.82;
	SPECULAR = 0.0;
}
