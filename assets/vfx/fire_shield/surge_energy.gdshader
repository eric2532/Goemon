shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, fog_disabled;
#include "res://assets/vfx/edo/brush_noise.gdshaderinc"
uniform float clock = 0.0;
uniform float energy = 1.0;
void fragment() {
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
 float noise = brush_noise(UV * vec2(18.0, 9.0) + vec2(clock * 0.25, -clock * 0.6));
 float swipe = pow(max(0.0, sin(UV.y * 42.0 + UV.x * 12.56 - clock * 3.5 + noise)), 16.0);
 float pigment = 0.55 + 0.45 * smoothstep(-0.5, 0.45, sin(UV.y * 143.0 + noise * 2.5));
 vec3 blue = mix(vec3(0.025, 0.19, 0.65), vec3(0.30, 0.86, 1.0), swipe);
 ALBEDO = blue;
 EMISSION = blue * (0.25 + rim * 1.65 + swipe * 0.85) * energy;
 ALPHA = (0.018 + rim * 0.32 + swipe * 0.06) * pigment;
}
