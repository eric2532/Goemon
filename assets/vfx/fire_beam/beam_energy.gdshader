shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.18, 0.025, 1.0);
uniform float clock = 0.0;
uniform float opacity = 0.35;
void fragment() {
	float flow = pow(0.5 + 0.5 * sin(UV.y * 94.2 - clock * 18.0 + UV.x * 6.28), 5.0);
	float veins = pow(0.5 + 0.5 * sin(UV.x * 50.2 + UV.y * 7.0 - clock * 5.0), 10.0);
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * (1.1 + flow * 0.8 + veins * 0.8);
	ALPHA = opacity * (0.5 + flow * 0.3 + veins * 0.2);
}
