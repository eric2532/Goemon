shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
void fragment() {
 ALBEDO = COLOR.rgb;
 ALPHA = 1.0;
}
