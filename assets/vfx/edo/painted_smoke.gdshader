shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never;
#include "res://assets/vfx/edo/brush_noise.gdshaderinc"
uniform float clock = 0.0;
uniform float fade = 0.28;
varying vec3 rest_position;
void vertex() { rest_position = VERTEX; }
void fragment() {
 float noise = brush_noise(rest_position.xz * 3.2 + vec2(clock * 0.16, clock * 0.24));
 float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
 ALBEDO = mix(vec3(0.10, 0.075, 0.085), vec3(0.31, 0.26, 0.28), smoothstep(0.25, 0.72, noise));
 ROUGHNESS = 1.0;
 ALPHA = fade * smoothstep(0.02, 0.5, facing) * (0.55 + noise * 0.45);
}
