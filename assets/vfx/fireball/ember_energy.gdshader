shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform float clock = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.18, 0.025, 1.0);
uniform float opacity = 0.3;
void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 1.7);
	float streams = pow(0.5 + 0.5 * sin(UV.x * 37.7 + sin(UV.y * 15.0 - clock * 5.0)), 6.0);
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * (1.6 + streams * 0.9);
	ALPHA = opacity * (0.2 + rim * 0.4 + streams * 0.4);
}
