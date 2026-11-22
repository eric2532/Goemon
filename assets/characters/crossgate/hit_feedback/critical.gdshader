shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled;

uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform float frame_count = 4.0;
uniform float frame_rows = 1.0;
varying flat vec2 frame_opacity;

void vertex() {
	frame_opacity = INSTANCE_CUSTOM.xy;
}

void fragment() {
	vec2 atlas_size = vec2(textureSize(atlas, 0));
	vec2 frame_size = atlas_size / vec2(frame_count, frame_rows);
	vec2 cell = vec2(mod(frame_opacity.x, frame_count), floor(frame_opacity.x / frame_count));
	vec2 texel = UV * (frame_size - 1.0) + cell * frame_size + vec2(0.5);
	vec4 source = texture(atlas, texel / atlas_size);
	ALBEDO = source.rgb;
	ALPHA = source.a * frame_opacity.y;
}
