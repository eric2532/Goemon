shader_type spatial;
render_mode unshaded, cull_front;

void vertex() {
	VERTEX += NORMAL * 0.003;
}

void fragment() {
	ALBEDO = vec3(0.023, 0.036, 0.065);
}
