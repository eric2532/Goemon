shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;

uniform float fade = 1.0;
uniform float energy = 1.0;
uniform bool crimson = false;
uniform bool custom_palette = false;
uniform vec4 ink_tint : source_color = vec4(1.0, 0.7, 0.2, 1.0);
uniform float brush_clock = 0.0;
uniform bool use_vertex_alpha = false;
varying float trail_alpha;
void vertex() { trail_alpha = COLOR.a; }

void fragment() {
 // Long bristle grooves and an uneven inner edge, painted along the swing.
 float flow = brush_clock * 2.0;
 float bristles = sin(UV.y * 97.0 + sin(UV.x * 5.0 + flow) * 0.6);
 float grain = sin(UV.x * 113.0 + UV.y * 29.0 + flow * 4.0) * sin(UV.y * 173.0);
 float ragged = 0.10 + 0.055 * sin(UV.x * 41.0) + 0.025 * grain;
 float ink = smoothstep(ragged, ragged + 0.12, UV.y);
 float dry_brush = 0.65 + 0.35 * smoothstep(-0.6, 0.4, bristles + grain * 0.3);
 float edge = smoothstep(0.91, 0.985, UV.y);
 float accent = pow(max(0.0, sin(UV.x * 23.0 + UV.y * 14.0 + flow)), 24.0) * smoothstep(0.73, 0.85, UV.y) * (1.0 - edge);
 float taper = smoothstep(0.0, 0.14, UV.x);
 vec3 inner_ink = crimson ? vec3(0.19, 0.003, 0.012) : vec3(0.08, 0.008, 0.19);
 vec3 outer_ink = crimson ? vec3(0.55, 0.014, 0.022) : vec3(0.24, 0.028, 0.52);
 vec3 pigment = mix(mix(inner_ink, outer_ink, UV.y), crimson ? vec3(1.0, 0.79, 0.69) : vec3(0.96, 0.82, 1.0), edge);
 pigment = mix(pigment, crimson ? vec3(0.98, 0.30, 0.09) : vec3(0.24, 0.88, 1.0), accent * 0.55);
 if (custom_palette) {
  vec3 body = mix(ink_tint.rgb * 0.14, ink_tint.rgb * 0.65, UV.y);
  pigment = mix(body, mix(ink_tint.rgb, vec3(1.0), 0.82), edge);
  pigment = mix(pigment, mix(ink_tint.rgb, vec3(1.0), 0.4), accent * 0.55);
 }
 ALBEDO = pigment;
 EMISSION = pigment * (0.12 + edge * 2.2 + accent * 0.7) * energy;
 ALPHA = ink * dry_brush * taper * (0.78 + edge * 0.2) * fade * (use_vertex_alpha ? trail_alpha : 1.0);
}
