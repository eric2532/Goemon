shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_back, shadows_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform bool descending = false;
uniform bool hunting = false;
uniform float flow_time = 0.0;
uniform bool instanced = false;
varying float effect_progress;
varying float effect_time;
varying vec3 shape_position;

float grain(vec3 p) {
	return fract(sin(dot(floor(p), vec3(12.9898, 78.233, 39.425))) * 43758.5453);
}

void vertex() {
	effect_time = instanced ? (hunting ? INSTANCE_CUSTOM.r : INSTANCE_CUSTOM.g) : flow_time;
	effect_progress = hunting ? effect_time / 3.0 : (instanced ? INSTANCE_CUSTOM.r : progress);
	shape_position = VERTEX;
	mat3 flight = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, 0.573576, 0.819152), vec3(0.0, -0.819152, 0.573576));
	vec3 posed = flight * (VERTEX - vec3(0.0, 7.0, 0.0)) + vec3(0.0, 2.5, -3.0);
	vec3 posed_normal = flight * NORMAL;
	if (COLOR.a < 0.5) {
		// Rotate the whole wing about its shoulder, including its shading normals.
		float side = sign(posed.x);
		float angle = sin(effect_time * 7.5) * 0.16 * side;
		mat2 flap = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
		vec2 hinge = vec2(side * 1.35, 2.7);
		posed.xy = flap * (posed.xy - hinge) + hinge;
		posed_normal.xy = flap * posed_normal.xy;
	}
	if (hunting) {
		VERTEX = posed;
		NORMAL = posed_normal;
		VERTEX *= mix(0.15, 1.0, smoothstep(0.0, 0.12, effect_time));
	} else {
		VERTEX = transpose(flight) * (posed - vec3(0.0, 2.5, -3.0)) + vec3(0.0, 7.0, 0.0);
		NORMAL = transpose(flight) * posed_normal;
		float rise = descending ? 1.0 : mix(0.02, 1.0, 1.0 - pow(1.0 - clamp(effect_progress / 0.12, 0.0, 1.0), 3.0));
		VERTEX.y *= rise;
	}
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float rim = pow(1.0 - abs(dot(n, normalize(VIEW))), 2.5);
	vec3 light_direction = normalize((VIEW_MATRIX * vec4(-0.5, 0.8, 0.7, 0.0)).xyz);
	float light = max(0.0, dot(n, light_direction));
	float eye = step(COLOR.g * 1.8 + 0.05, COLOR.r);
	vec3 paint = pow(COLOR.rgb, vec3(2.2)) * mix(0.65, 1.3, smoothstep(0.05, 0.85, light));
	paint += vec3(0.10, 0.09, 0.14) * (pow(light, 10.0) * 0.12 + rim * 0.08);
	ALBEDO = mix(paint, pow(COLOR.rgb, vec3(2.2)), eye);
	EMISSION = COLOR.rgb * eye * (0.5 + intensity * 0.5);
	float fade_start = hunting ? 0.90 : 0.65;
	float breakup = smoothstep(hunting ? 0.88 : 0.60, 1.0, effect_progress);
	float threshold = breakup * 1.3 - UV.y * 0.3;
	float visible_grain = mix(1.0, smoothstep(threshold - 0.12, threshold + 0.12, grain(shape_position * 5.0)), breakup);
	ALPHA = visible_grain * (1.0 - smoothstep(fade_start, 1.0, effect_progress));
	if (descending) { ALPHA *= smoothstep(0.0, 0.05, effect_time); }
}
