shader_type spatial;
#include "res://scripts/forest/attack_range.gdshaderinc"

uniform vec4 ice_color : source_color;
uniform vec4 frost_color : source_color;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool wall_glaze = false;
uniform float powder_cover : hint_range(0.0, 1.0) = 0.0;
uniform vec4 crystal_pools[3];

varying vec3 ice_point;
varying vec3 ice_normal;
varying vec2 floor_point;

void vertex() {
	ice_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ice_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	floor_point = VERTEX.xz;
}

float vein(float distance_to_edge, float width) {
	return 1.0 - smoothstep(width, width + .012 + fwidth(distance_to_edge), distance_to_edge);
}

void fragment() {
	vec3 n = normalize(ice_normal);
	vec3 p = ice_point;
	vec3 color;
	float frost;
	if (wall_glaze) {
		vec3 weight = pow(abs(n), vec3(4.0));
		weight /= dot(weight, vec3(1.0));
		vec3 uv = p * .42;
		vec3 rock = texture(rock_texture, uv.zy).rgb * weight.x
		          + texture(rock_texture, uv.xz).rgb * weight.y
		          + texture(rock_texture, uv.xy).rgb * weight.z;
		float grain = dot(rock, vec3(.2126, .7152, .0722));
		float ripple = sin(p.x * .46 + p.z * .33 + sin(p.y * .78 + p.x * .37) * .72);
		float runoff = sin(p.x * 4.1 - p.z * 3.8 + ripple * 2.0 + sin(p.y * .54) * .46);
		float glaze = smoothstep(.17, .77, .47 + .23 * ripple + .09 * runoff + .28 * n.y + .22 * grain);
		frost = smoothstep(.47, .96, glaze + max(n.y, 0.0) * .19);
		vec3 exposed = ice_color.rgb * (.44 + grain * 1.3);
		vec3 sheet = mix(ice_color.rgb, frost_color.rgb, .26 + frost * .48);
		color = mix(exposed, sheet, glaze) * (.75 + grain * .58 + .12 * runoff * glaze * glaze);
		ROUGHNESS = mix(.89, .29, glaze);
		float cap = smoothstep(.12, .64, n.y + .25 * ripple + grain * .29);
		vec3 bank = mix(vec3(.20, .24, .27), vec3(.71, .80, .84), cap) * (.78 + .43 * grain);
		color = mix(color, bank, powder_cover);
		ROUGHNESS = mix(ROUGHNESS, .92, powder_cover);
	} else {
		vec2 drift = sin(p.xz * .57 + p.zx * vec2(.22, -.24));
		vec2 warp = .24 * sin(p.zx * .32 + drift) + .13 * drift;
		vec2 facets = vec2(dot(p.xz, vec2(.133, .081)), dot(p.xz, vec2(-.095, .162))) + warp;
		vec2 cell = fract(facets);
		vec2 edge = min(cell, 1.0 - cell);
		vec2 tile = floor(facets);
		float variation = fract(sin(dot(tile, vec2(12.9898, 78.233))) * 43758.5453);
		float diagonal = mix(cell.x, 1.0 - cell.x, step(.5, variation)) + sin(cell.x * 9.0) * .085;
		float branch = vein(abs(cell.y - diagonal), .003) * step(.40, variation);
		float powder = texture(rock_texture, p.xz * .48 + drift * .10).g;
		float haze = sin(p.x * .38 + drift.y + sin(p.z * .24));
		frost = smoothstep(.18, .58, powder + haze * .16);
		float crack = min(edge.x, edge.y);
		float broken = smoothstep(-.38, .45, .78 * drift.x + drift.y * .62 + powder);
		float seam = vein(crack, .003) * (.29 + .71 * broken);
		float panels = (variation - .5) * .12 + (step(cell.y, diagonal) - .5) * .08 * step(.40, variation);
		color = mix(ice_color.rgb, frost_color.rgb, .14 + .43 * frost + panels);
		color *= 1.0 - .24 * vein(crack, .018) * broken;
		color = mix(color, frost_color.rgb, seam * (.29 + frost * .36) + .28 * branch * (1.0 - seam));
		ROUGHNESS = mix(.33, .69, frost);
		float spread = 0.0;
		for (int i = 0; i < 3; i++) {
			vec2 axis = crystal_pools[i].zw;
			vec2 delta = floor_point - crystal_pools[i].xy;
			vec2 reach = vec2(dot(delta, vec2(axis.y, -axis.x)) * .38, (dot(delta, axis) - 2.3) * .18);
			spread += (1.0 - smoothstep(.0, 1.65, dot(reach, reach))) * dot(axis, axis);
		}
		float ripple = abs(sin(dot(p.xz, vec2(.98, .65)) + warp.x * 1.9)
		                 + sin(dot(p.xz, vec2(-.44, 1.32)) + warp.y * 2.3));
		float glints = 1.0 - smoothstep(.05, .25 + fwidth(ripple), ripple);
		float pool = min(spread, 1.0);
		color = mix(color, frost_color.rgb, pool * .24);
		float drift_bank = .52 + .21 * sin(p.x * .18 + sin(p.z * .21))
		                 + .17 * cos(p.z * .16 - p.x * .12) + .13 * (powder - .5);
		float exposed_ice = smoothstep(.57, .98, pool + (drift_bank - .52) * .32);
		float snow = powder_cover * (1.0 - exposed_ice * .82);
		float bank = smoothstep(.06, .57, COLOR.r + drift_bank * .18 - .09);
		float grains = smoothstep(.22, .69, powder + haze * .08);
		float windrows = smoothstep(-.42, .66, sin(dot(floor_point, vec2(.72, -.27)) + 1.8 * drift.x));
		vec3 packed_snow = mix(vec3(.49, .63, .75), vec3(.69, .80, .87), .23 + .61 * windrows);
		vec3 snow_color = mix(packed_snow, vec3(.88, .94, .98), bank);
		snow_color *= .87 + .21 * grains;
		color = mix(color, snow_color, snow);
		ROUGHNESS = mix(ROUGHNESS, .94, snow);
		EMISSION = frost_color.rgb * pool * (1.0 - snow) * (.032 + .095 * glints + seam * .12);
	}
	ALBEDO = attack_range_ink(color, ice_point, ice_normal);
	SPECULAR = .42;
}
