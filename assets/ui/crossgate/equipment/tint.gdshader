shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool chrome = false;
#include "res://assets/characters/crossgate/qigong/chrome.gdshaderinc"
void fragment() {
 vec4 source = COLOR;
 COLOR = vec4(max(max(source.r, source.g), source.b) * tint.rgb, source.a);
 if (chrome) {
  COLOR.rgb = rainbow_chrome(UV * vec2(512.0, 63.0) / vec2(63.0, 62.0), max(max(source.r, source.g), source.b), TIME);
 }
}
