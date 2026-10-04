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
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.98, 0.91), edge * 0.85);
	ALPHA = (0.30 + edge * 0.70) * inner * head * tail * wake * strength;
}
