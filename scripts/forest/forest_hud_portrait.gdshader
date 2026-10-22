shader_type canvas_item;
// All twelve authored portraits share this camera and face position.
// Crop the source UVs directly; keep the original texture shared and cached.
uniform vec4 face_crop = vec4(0.3375, 0.20, 0.325, 0.52);
varying vec4 portrait_tint;
void vertex() {
	portrait_tint = COLOR;
}
void fragment() {
	vec4 portrait = texture(TEXTURE, face_crop.xy + UV * face_crop.zw);
	float circle = 1.0 - smoothstep(0.485, 0.5, length(UV - vec2(0.5)));
	COLOR = vec4(portrait.rgb, portrait.a * circle) * portrait_tint;
}
