shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 energy_color : source_color = vec4(0.6, 0.4, 1.0, 1.0);
uniform float strength = 0.0;
void fragment() {
 float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
 ALBEDO = energy_color.rgb * 1.4;
 ALPHA = rim * strength * 0.48;
}
