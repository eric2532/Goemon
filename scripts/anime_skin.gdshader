shader_type spatial;
render_mode unshaded;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool textured = false;
varying vec3 world_normal;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 color = base_color.rgb;
	if (textured) color *= texture(albedo_texture, UV).rgb;
	// Stable painted colors with two broad cel bands, independent of the
	// environment's bright ambient fill. Keep the illustrated face readable.
	float band = smoothstep(0.08, 0.13, dot(normalize(world_normal), normalize(vec3(-0.4, 0.8, -0.6))));
	ALBEDO = color * (textured ? 1.0 : mix(0.66, 1.0, band));
}
