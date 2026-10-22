shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
uniform float native_bias=1.0;
void fragment() {
 // Preserve original TMD vertex palette; approximate native light-matrix fade.
 ALBEDO = max(vec3(0.0), COLOR.rgb + vec3(min(0.0,native_bias-1.0)));
 ALPHA = 1.0;
}
