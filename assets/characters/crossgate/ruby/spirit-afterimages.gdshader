shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
instance uniform float tick = 0.0;
instance uniform float opacity = 1.0;
varying flat vec2 stamp;

void vertex() {
	stamp = INSTANCE_CUSTOM.xy;
	float size = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = mat4(vec4(size, 0.0, 0.0, 0.0),
		vec4(0.0, size, 0.0, 0.0), vec4(0.0, 0.0, size, 0.0), MODELVIEW_MATRIX[3]);
}

void fragment() {
	if (tick - stamp.y >= 12.0) {
		discard;
	}
	vec2 cell_size = vec2(40.0, 80.0);
	vec2 texel = floor(UV * (cell_size - 0.0001)) + vec2(stamp.x * cell_size.x + 0.5, 0.5);
	vec4 source = texture(atlas, texel / vec2(textureSize(atlas, 0)));
	if (source.a == 0.0) {
		discard;
	}
	ALBEDO = source.rgb;
	ALPHA = source.a * (128.0 / 255.0) * opacity;
}
