shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
#include "res://assets/vfx/edo/brush_noise.gdshaderinc"
uniform float clock = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.22, 0.035, 1.0);
uniform float opacity = 0.50;
uniform float energy = 1.0;
void fragment() {
 float noise = brush_noise(UV * vec2(12.0, 6.0) + vec2(clock * 0.35, -clock * 3.2));
 float flow = sin(UV.x * 37.7 + noise * 4.0 - clock * 7.0);
 float bristles = smoothstep(-0.6, 0.55, sin(UV.x * 111.0 + noise * 3.0));
 float hot = smoothstep(0.36, 0.85, noise + flow * 0.22);
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.8);
 vec3 pigment = mix(vec3(0.30, 0.008, 0.014), tint.rgb, smoothstep(-0.6, 0.3, flow));
 pigment = mix(pigment, vec3(1.0, 0.88, 0.47), hot);
 ALBEDO = pigment;
 EMISSION = pigment * (0.35 + hot * 0.85 + rim * 0.30) * energy;
 ALPHA = opacity * (0.25 + rim * 0.40 + hot * 0.35) * (0.55 + bristles * 0.45);
}
