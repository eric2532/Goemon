shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

uniform float fade = 1.0;
uniform float energy = 1.0;

void fragment() {
 // Long bristle grooves and an uneven inner edge, painted along the swing.
 float bristles = sin(UV.y * 97.0 + sin(UV.x * 5.0) * 0.6);
 float grain = sin(UV.x * 113.0 + UV.y * 29.0) * sin(UV.y * 173.0);
 float ragged = 0.10 + 0.055 * sin(UV.x * 41.0) + 0.025 * grain;
 float ink = smoothstep(ragged, ragged + 0.12, UV.y);
 float dry_brush = 0.65 + 0.35 * smoothstep(-0.6, 0.4, bristles + grain * 0.3);
 float edge = smoothstep(0.91, 0.985, UV.y);
 float cyan = pow(max(0.0, sin(UV.x * 23.0 + UV.y * 14.0)), 24.0) * smoothstep(0.73, 0.85, UV.y) * (1.0 - edge);
 float taper = smoothstep(0.0, 0.14, UV.x);
 vec3 purple = mix(vec3(0.08, 0.008, 0.19), vec3(0.24, 0.028, 0.52), UV.y);
 vec3 pigment = mix(purple, vec3(0.96, 0.82, 1.0), edge);
 pigment = mix(pigment, vec3(0.24, 0.88, 1.0), cyan * 0.55);
 ALBEDO = pigment;
 EMISSION = pigment * (0.12 + edge * 2.2 + cyan * 0.7) * energy;
 ALPHA = ink * dry_brush * taper * (0.78 + edge * 0.2) * fade;
}
