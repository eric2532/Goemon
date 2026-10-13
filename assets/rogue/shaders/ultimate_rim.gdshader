shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 energy_color : source_color = vec4(0.6, 0.4, 1.0, 1.0);
uniform float strength = 0.0;
uniform float clock = 0.0;
void fragment() {
 float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
 float veins = pow(0.5 + 0.5 * sin(UV.y * 42.0 + sin(UV.x * 19.0) * 2.0 - clock * 7.0), 14.0);
 ALBEDO = energy_color.rgb;
 EMISSION = energy_color.rgb * (1.5 + rim * 1.2);
 ALPHA = (rim * 0.42 + veins * rim * 0.22) * strength;
}
