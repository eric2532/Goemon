shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
instance uniform float growth = 1.0;

void vertex() {
	VERTEX *= growth;
}

void fragment() {
	// The alternate cells blank most of this crest.
	vec2 cell = (UV + vec2(0.0, 12.0)) / vec2(4.0, 16.0);
	vec4 blade = texture(atlas, cell);
	vec3 normal = normalize(NORMAL);
	float rim = 1.0 - abs(dot(normal, VIEW));
	vec3 light = mat3(VIEW_MATRIX) * normalize(vec3(-0.35, 0.8, 0.45));
	float highlight = abs(dot(normal, light));
	float tone = dot(blade.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 steel = mix(vec3(0.32, 0.24, 0.54), vec3(1.0, 0.98, 1.0), smoothstep(0.18, 0.78, tone));
	ALBEDO = steel * (0.76 + 0.36 * highlight) + 0.24 * rim * rim;
	ALPHA = smoothstep(0.07, 0.91, blade.a) * 0.96;
}
