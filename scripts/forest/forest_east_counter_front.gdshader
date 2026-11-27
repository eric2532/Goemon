shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D native_paint : source_color, filter_nearest, repeat_disable;
void fragment() {
 if(any(lessThan(UV,vec2(0.0))) || any(greaterThan(UV,vec2(1.0)))) discard;
 vec4 art=texture(native_paint,UV);
 ALBEDO=art.rgb; ALPHA=art.a; ALPHA_SCISSOR_THRESHOLD=0.5;
}
