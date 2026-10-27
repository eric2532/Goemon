shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
varying float tile;
void vertex() { tile=INSTANCE_CUSTOM.x; }
void fragment() {
 vec4 pixel=texture(atlas,vec2(UV.x,(UV.y+tile)/32.0));
 ALBEDO=pixel.rgb;
 ALPHA=pixel.a;
}
