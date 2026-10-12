shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://assets/vfx/edo/brush_noise.gdshaderinc"
uniform vec4 tint : source_color = vec4(1.0, 0.18, 0.025, 1.0);
uniform float clock = 0.0;
uniform float opacity = 0.35;
uniform float energy = 1.0;
void fragment() {
 float noise = brush_noise(UV * vec2(15.0, 21.0) - vec2(clock * 0.3, clock * 5.0));
 float flow = pow(0.5 + 0.5 * sin(UV.y * 94.2 - clock * 18.0 + UV.x * 6.28 + noise * 2.5), 5.0);
 float bristles = smoothstep(-0.55, 0.4, sin(UV.x * 150.0 + noise * 3.0));
 float veins = pow(0.5 + 0.5 * sin(UV.x * 50.2 + UV.y * 7.0 - clock * 5.0), 10.0);
 vec3 pigment = mix(tint.rgb * 0.45, tint.rgb, 0.4 + flow * 0.6);
 pigment = mix(pigment, mix(tint.rgb, vec3(1.0), 0.7), veins * 0.4);
 ALBEDO = pigment;
 EMISSION = pigment * (0.9 + flow * 0.85 + veins * 0.9) * energy;
 ALPHA = opacity * (0.45 + flow * 0.35 + veins * 0.2) * (0.65 + bristles * 0.35);
}
