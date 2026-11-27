shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec2 grid = vec2(1.0);
uniform float frames = 1.0;
uniform float duration = 1.0;
uniform float opacity = 1.0;
void fragment() {
 float frame = mod(floor(TIME * frames / max(duration, 0.001)), frames);
 vec2 cell = vec2(mod(frame, grid.x), floor(frame / grid.x));
 vec4 pixel = texture(atlas, (UV + cell) / grid);
 ALBEDO = pixel.rgb;
 ALPHA = pixel.a * opacity;
}
