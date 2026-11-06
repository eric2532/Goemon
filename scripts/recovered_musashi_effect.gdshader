shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float energy = 1.0;
void fragment() {
 ALBEDO = COLOR.rgb;
 ALPHA = energy;
}
