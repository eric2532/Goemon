uniform sampler2D castle_stone_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;

vec3 castle_stone(vec3 point, vec3 normal) {
	bool top = abs(normal.y) > .65;
	vec2 plane = top ? point.xz : (abs(normal.x) > abs(normal.z) ? point.zy : point.xy);
	vec2 tiled = plane / (top ? vec2(6.0) : vec2(6.0, 7.3));
	vec2 tile = fract(tiled);
	// Match the wall master's padded stone/coping atlas cells; Godot UVs start at the top.
	vec2 uv = (vec2(top ? 1.0 : 0.0, 3.0) + vec2(tile.x * .96 + .02, .98 - tile.y * .96)) * .25;
	return textureGrad(castle_stone_texture, uv, dFdx(tiled) * vec2(.24, -.24), dFdy(tiled) * vec2(.24, -.24)).rgb;
}
