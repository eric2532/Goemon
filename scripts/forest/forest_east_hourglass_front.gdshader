shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D base_texture : source_color, filter_nearest, repeat_disable;
void fragment() {
 vec4 art=texture(base_texture,UV);
 ALBEDO=art.rgb;
 ALPHA=art.a;
 ALPHA_SCISSOR_THRESHOLD=0.5;
}
