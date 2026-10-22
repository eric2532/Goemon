shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable;
uniform bool textured = false;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform bool compensate_filmic = false;
uniform float scene_exposure = 1.0;
uniform float scene_white = 1.0;

// Inverse of Godot 4.6's per-channel Filmic curve. The scenery keeps its
// existing HDR grading; this display-authored PS1 palette keeps its intended
// skin/cloth colours after that grading instead of bleaching toward white.
// Reference: godotengine/godot 4.6-stable, effects/tonemap.glsl.
float filmic_white(float x) {
	return (x * (0.88 * x + 0.06) + 0.002) / (x * (0.88 * x + 0.60) + 0.06) - 1.0 / 30.0;
}
vec3 inverse_filmic(vec3 desired) {
	vec3 k = clamp(desired, vec3(0.0), vec3(1.0)) * filmic_white(max(scene_white, 0.001)) + vec3(1.0 / 30.0);
	vec3 a = 0.88 * (vec3(1.0) - k);
	vec3 b = 0.60 * (vec3(0.10) - k);
	vec3 c = 0.20 * (vec3(0.01) - 0.30 * k);
	return max(vec3(0.0), (-b + sqrt(max(vec3(0.0), b * b - 4.0 * a * c))) / (2.0 * a)) / max(scene_exposure, 0.001);
}
void fragment() {
	vec4 paint = COLOR * tint_color;
	if (textured) paint *= texture(albedo_texture, UV);
	if (paint.a < 0.5) discard;
	ALBEDO = compensate_filmic ? inverse_filmic(paint.rgb) : paint.rgb;
}
