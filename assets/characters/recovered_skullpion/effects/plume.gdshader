shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform float frame = 0.0;
void fragment() {
 vec4 pixel=texture(atlas,vec2(UV.x,(UV.y+frame)/8.0));
 ALBEDO=pixel.rgb;
 ALPHA=pixel.a*.5;
}
