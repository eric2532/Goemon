shader_type spatial;
render_mode unshaded;

uniform vec4 cutting_edge : source_color = vec4(0.95, 0.97, 1.0, 1.0);
uniform vec4 blade_face : source_color = vec4(0.63, 0.66, 0.83, 1.0);
uniform vec4 blade_spine : source_color = vec4(0.43, 0.46, 0.67, 1.0);
instance uniform float growth = 1.0;

void vertex() {
	VERTEX *= growth;
}

void fragment() {
	vec3 face = mix(blade_face.rgb, blade_spine.rgb, smoothstep(0.18, 1.0, UV.x));
	vec3 light = mat3(VIEW_MATRIX) * normalize(vec3(-0.35, 0.8, 0.45));
	float shade = mix(0.76, 1.0, max(0.0, dot(normalize(NORMAL), light)));
	float edge = 1.0 - smoothstep(0.015, 0.15, UV.x);
	ALBEDO = mix(face * shade, cutting_edge.rgb, edge);
}
