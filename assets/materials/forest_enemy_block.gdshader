shader_type spatial;
render_mode unshaded;

uniform vec3 block_size = vec3(1.0);
varying vec3 block_position;
varying vec3 block_normal;

void vertex() {
	block_position = VERTEX / block_size;
	block_normal = NORMAL;
}

void fragment() {
	vec3 color = COLOR.rgb;
	// Enemy steering faces local -Z. Paint only the body's front face;
	// eyes ride the existing pose, freeze, recoil and death transforms.
	if (block_normal.z < -0.5) {
		vec2 eye = vec2(abs(block_position.x) - 0.22, block_position.y - 0.29);
		float edge = length(eye / vec2(0.145, 0.075));
		float white = 1.0 - smoothstep(0.92, 1.0, edge);
		color = mix(color, vec3(0.98, 0.96, 0.87), white);
		vec2 pupil = eye - vec2(-0.018, -0.006);
		float ink = (1.0 - smoothstep(0.85, 1.0, length(pupil / vec2(0.062, 0.052)))) * white;
		color = mix(color, vec3(0.035, 0.028, 0.06), ink);
		float glint = 1.0 - smoothstep(0.7, 1.0, length((pupil - vec2(-0.016, 0.018)) / vec2(0.019, 0.018)));
		color = mix(color, vec3(1.0), glint * ink);
	}
	ALBEDO = color;
}
