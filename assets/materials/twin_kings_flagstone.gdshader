shader_type spatial;
#include "res://scripts/forest/attack_range.gdshaderinc"

uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 mineral_tint = vec3(1.0);
uniform bool corridor_paving = false;
varying vec3 floor_point;
varying vec3 floor_normal;

void vertex() {
	floor_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	floor_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

float stone_variation(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

float surface_grain(vec2 p, float frequency) {
	vec2 sample_point = p * frequency;
	float visible = 1.0 - smoothstep(.45, 1.2, length(fwidth(sample_point)));
	return (stone_variation(floor(sample_point)) - .5) * visible;
}

vec3 flagstone_color(vec2 p) {
	float age = texture(rock_texture, p * .43).g;
	float grit = texture(rock_texture, p * 3.2).r;
	float flecks = surface_grain(p, 24.0);
	float chips = surface_grain(p + vec2(.33, .19), 8.0);
	vec2 tile = p / vec2(1.54, 1.27);
	float antialias = length(fwidth(tile));
	tile += vec2(.13 * sin(p.y * 2.3 + p.x * .91), .16 * sin(p.x * 2.16 - p.y * .7));
	tile.x += mod(floor(tile.y), 2.0) * .49;
	vec2 cell = fract(tile);
	vec2 margin = min(cell, 1.0 - cell);
	float random_stone = stone_variation(floor(tile));
	float round_corner = mix(.035, .10, random_stone) * pow(1.0 - max(margin.x, margin.y) * 2.0, 3.0);
	float joint = min(margin.x, margin.y) - round_corner + (grit - .18) * .12 + chips * .042;
	float face = smoothstep(.008, .031 + antialias, joint);
	float rim = face * (1.0 - smoothstep(.055, .20, joint));
	float leading = step(min(cell.x, cell.y), min(1.0 - cell.x, 1.0 - cell.y));
	vec3 stone = mix(vec3(.15, .19, .112), vec3(.31, .35, .25), random_stone);
	stone *= (.79 + .43 * age + .46 * grit + .46 * flecks + .29 * chips) * (1.0 + rim * mix(-.30, .36, leading));
	float moss = smoothstep(.13, .33, grit * .66 + age * .34);
	stone = mix(stone, vec3(.19,.245,.121) * (1.0 + flecks*.48), moss * .32);
	return mix(vec3(.105, .122, .078) * (.90 + .58 * flecks), stone, face);
}

vec3 corridor_color(vec2 p) {
	float grain = texture(rock_texture, p * .81).g;
	float grit = texture(rock_texture, p * 3.61).r;
	float flecks = surface_grain(p, 26.0);
	float chips = surface_grain(p + vec2(.17, .63), 11.0);
	// The brick courses run diagonally across the room so the joints read across the isometric view.
	vec2 course = vec2(p.x - p.y, p.x + p.y) * .7071068;
	vec2 tile = course / vec2(.91, .79);
	float antialias = length(fwidth(tile));
	tile += vec2(.098 * sin(course.y * 3.8 + course.x), (grain - .18) * .20);
	float row = floor(tile.y);
	tile.x += mod(row, 2.0) * .46 + .17 * sin(row * 2.34);
	vec2 cell = fract(tile);
	vec2 edge = min(cell, 1.0 - cell);
	float variation = stone_variation(floor(tile));
	float joint = min(edge.x, edge.y) + (grit - .18) * .105 + chips * .062;
	float face = smoothstep(.008, .030 + antialias, joint);
	float bevel = face * (1.0 - smoothstep(.045, .14, joint));
	float light_edge = step(min(cell.x, cell.y), min(1.0 - cell.x, 1.0 - cell.y));
	vec3 olive = vec3(.145, .183, .139);
	vec3 umber = vec3(.226, .166, .114);
	vec3 stone = mix(olive, umber, smoothstep(.22, .66, variation*.55 + grain*.45));
	stone *= (.72 + .37 * grain + .50 * grit + .57 * flecks + .31 * chips) * (.84 + .28 * variation);
	stone *= 1.0 + bevel * mix(-.19, .36, light_edge);
	vec3 mortar = mix(vec3(.105,.107,.080),vec3(.187,.187,.143),grit*.64 + .15) * (1.0 + flecks*.52);
	return mix(mortar, stone, face);
}

void fragment() {
	vec2 p = floor_point.xz;
	vec3 floor_color = corridor_paving ? corridor_color(p) : flagstone_color(p);
	ALBEDO = attack_range_ink(floor_color * mineral_tint, floor_point, floor_normal);
	ROUGHNESS = .94;
	SPECULAR = .16;
}
