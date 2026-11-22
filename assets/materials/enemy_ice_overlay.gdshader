shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
uniform float ice_coat = 0.0;
varying vec3 ice_position;
#include "enemy_ice_surface.gdshaderinc"
void vertex() { ice_position = VERTEX; }
void fragment() {
 float coat = abs(ice_coat);
 ALBEDO = enemy_ice_surface(vec3(0.54, 0.83, 0.92), ice_position, NORMAL, VIEW, ice_coat);
 float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.5);
 ALPHA = coat * (0.12 + rim * 0.6);
 ROUGHNESS = 0.23;
}
