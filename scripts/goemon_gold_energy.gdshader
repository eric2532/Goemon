shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform float brush_clock = 0.0;
uniform float energy = 0.8;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
 float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 1.8);
 float bands = 0.5 + 0.5 * sin(local_position.y * 17.0 - brush_clock * 12.0);
 vec3 gold = mix(vec3(1.0, 0.32, 0.015), vec3(1.0, 0.84, 0.25), rim);
 ALBEDO = gold;
 EMISSION = gold * energy * (0.18 + rim * 0.75);
 ALPHA = energy * (0.10 + rim * 0.50 + bands * 0.07);
}
