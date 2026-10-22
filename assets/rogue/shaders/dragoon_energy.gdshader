shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_back, shadows_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform bool descending = false;
uniform float flow_time = 0.0;
varying vec3 shape_position;

float grain(vec3 p) {
	return fract(sin(dot(floor(p), vec3(12.9898, 78.233, 39.425))) * 43758.5453);
}

void vertex() {
	shape_position = VERTEX;
	float rise = descending ? 1.0 : mix(0.02, 1.0, 1.0 - pow(1.0 - clamp(progress / 0.12, 0.0, 1.0), 3.0));
	if (!descending) { rise *= 1.0 + 0.08 * sin(clamp(progress / 0.26, 0.0, 1.0) * 3.141593); }
	VERTEX.y *= rise;
	VERTEX.x += sin(VERTEX.y * 0.65 - (descending ? flow_time * 7.0 : progress * 9.0)) * 0.12 * smoothstep(0.1, 0.35, progress);
}

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float volume = 0.60 + 0.40 * max(0.0, dot(normalize(NORMAL), normalize(vec3(-0.5, 0.8, 0.7))));
	float streak = pow(0.5 + 0.5 * sin(shape_position.y * 6.0 + shape_position.z * 2.5 - (descending ? flow_time * 17.0 : progress * 22.0)), 18.0);
	vec3 ice = pow(COLOR.rgb, vec3(2.2)) * volume;
	ice = mix(ice, vec3(0.20, 0.75, 1.0), rim * 0.65);
	ALBEDO = ice * (1.2 + intensity * 0.45) + vec3(0.08, 0.55, 1.0) * (rim * 0.55 + streak * 0.2) * intensity;
	EMISSION = ice * (0.15 + intensity * (0.6 + rim * 1.2 + streak * 0.7));
	float breakup = smoothstep(0.60, 1.0, progress);
	float threshold = breakup * 1.3 - UV.y * 0.3;
	float visible_grain = smoothstep(threshold - 0.12, threshold + 0.12, grain(shape_position * 5.0));
	ALPHA = visible_grain * (1.0 - smoothstep(0.65, 1.0, progress)) * 0.86;
	if (descending) { ALPHA *= smoothstep(0.0, 0.05, flow_time); }
}
