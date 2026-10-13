shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
#include "res://assets/vfx/edo/brush_noise.gdshaderinc"
uniform float clock = 0.0;
uniform float fade = 1.0;
uniform float energy = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 0.22, 0.025, 1.0);
varying vec3 rest_position;
void vertex() { rest_position = VERTEX; }
void fragment() {
 vec2 p = vec2(rest_position.x + rest_position.z * 0.55, rest_position.y);
 float flow = brush_noise(p * vec2(5.5, 3.0) - vec2(clock * 0.4, clock * 3.8));
 float streak = sin(p.x * 28.0 + flow * 4.0 - clock * 4.0);
 float hot = smoothstep(0.30, 0.82, flow);
 float pigment_mask = smoothstep(-0.55, 0.35, streak);
 vec3 pigment = mix(vec3(0.38, 0.013, 0.008), tint.rgb, pigment_mask);
 pigment = mix(pigment, vec3(1.0, 0.83, 0.32), hot * 0.9);
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.3);
 ALBEDO = pigment;
 EMISSION = pigment * (0.40 + hot * 0.75) * energy;
 ALPHA = fade * (0.45 + pigment_mask * 0.4) * (0.9 - rim * 0.35);
}
