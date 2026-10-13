shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * 1.8;
	ALPHA = COLOR.a;
}
