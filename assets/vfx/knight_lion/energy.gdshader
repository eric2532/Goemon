shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_back, shadows_disabled;

uniform float flow_time = 0.0;
uniform float opacity = 1.0;
varying vec3 shape_position;

void vertex() {
	shape_position = VERTEX;
}

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float light = 0.55 + 0.45 * max(0.0, dot(normalize(NORMAL), normalize(vec3(-0.5, 0.8, 0.7))));
	float streak = pow(0.5 + 0.5 * sin(shape_position.z * 8.0 + shape_position.y * 4.0 + flow_time * 19.0), 16.0);
	vec3 navy = vec3(0.098, 0.286, 0.549);
	vec3 cyan = vec3(0.467, 0.812, 1.0);
	float face = smoothstep(0.05, 0.4, COLOR.b);
	vec3 energy = mix(navy * 0.2, mix(navy, cyan, 0.35 + rim * 0.65) * light, face);
	ALBEDO = energy;
	EMISSION = cyan * (rim * 0.9 + streak * 0.3) * face;
	ALPHA = opacity * (0.82 + rim * 0.18);
}
