shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform sampler2D native_atlas : source_color, filter_linear_mipmap;
uniform bool sprite_glow = false;
void fragment() {
	vec4 native = texture(native_atlas, UV);
	vec3 energy = native.rgb * (sprite_glow ? COLOR.rgb : vec3(1.0));
	ALBEDO = energy;
	// The original additive atlas keeps black pixels. Derive coverage for the
	// transparent first-person viewport so those pixels never obscure scenery.
	ALPHA = max(native.r, max(native.g, native.b));
}
