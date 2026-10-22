shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.78, 0.43, 1.0);
uniform float age = 0.0;
uniform float strength = 0.95;
uniform float delay = 0.0;

void fragment() {
	float t = max(0.0, age - delay);
	float sweep = 1.0 - pow(1.0 - min(t / 0.43, 1.0), 2.0);
	float front = 0.04 + sweep * 1.08;
	float head = 1.0 - smoothstep(front - 0.065, front, UV.x);
	float tail = smoothstep(front - 0.88, front - 0.58, UV.x);
	float edge = smoothstep(0.80, 0.98, UV.y);
	float inner = smoothstep(0.0, 0.24, UV.y);
	float wake = pow(1.0 - min(t, 1.0), 0.82);
	// Fine parallel cuts and a bright leading edge, timed by the combat clock.
	float filament = pow(0.5 + 0.5 * sin(UV.y * 51.0 + UV.x * 8.0 - age * 9.0), 10.0);
	float cutting_tip = exp(-abs(UV.x - front + 0.04) * 45.0);
	vec3 energy = mix(tint.rgb, vec3(1.0, 0.96, 0.92), edge * 0.65 + cutting_tip * 0.25);
	ALBEDO = energy;
	EMISSION = energy * (1.1 + edge * 1.3 + filament * 0.5);
	ALPHA = (0.34 + edge * 0.50 + filament * 0.16) * inner * head * tail * wake * strength;
}
