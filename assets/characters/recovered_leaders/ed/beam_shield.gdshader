shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_add;
#include "res://assets/characters/recovered_leaders/ed/beam/native_lighting.gdshaderinc"
uniform float clock = 0.0;
uniform float release_tick = 0.0;
uniform bool compensate_filmic = false;
uniform float scene_exposure = 1.0;
uniform float scene_white = 1.0;
varying vec3 source_rgb;

void vertex() {
	// Source TMD rings, replaced by runtime Gouraud colors at80181478.
	float band = VERTEX.y > 144.5 ? 4.0 : VERTEX.y > 122.5 ? 3.0 : VERTEX.y > 81.5 ? 2.0 : VERTEX.y > 28.5 ? 1.0 : 0.0;
	// 80181478 decrements phase before the first visible update.
	float phase = mod(-199.0 * (floor(clock * 30.0) + 1.0) + 307.0 * band, 1536.0);
	float blue = phase < 256.0 || phase >= 1280.0 ? 0.0 : phase < 512.0 ? mod(phase, 256.0) : phase < 1024.0 ? 255.0 : 255.0 - mod(phase, 256.0);
	// 80181500 subtracts 0x100 from Q12 intensity on each release tick;
	// 801816DC scales each integer channel separately with a right shift of 12.
	float intensity = max(0.0, 4096.0 - floor(release_tick) * 256.0);
	ivec3 base_rgb = ivec3(floor(vec3(floor(blue / 4.0), floor(blue / 2.0), blue) * intensity / 4096.0));
	source_rgb = vec3(native_gpu_rgb(COLOR.rgb, base_rgb, MODEL_MATRIX)) / 255.0;
}

float linear_channel(float value) {
	return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4);
}
float filmic_white(float x) {
	return (x * (0.88 * x + 0.06) + 0.002) / (x * (0.88 * x + 0.60) + 0.06) - 1.0 / 30.0;
}
vec3 inverse_filmic(vec3 desired_linear) {
	vec3 k = clamp(desired_linear, vec3(0.0), vec3(1.0)) * filmic_white(max(scene_white, 0.001)) + vec3(1.0 / 30.0);
	vec3 a = 0.88 * (vec3(1.0) - k);
	vec3 b = 0.60 * (vec3(0.10) - k);
	vec3 c = 0.20 * (vec3(0.01) - 0.30 * k);
	return max(vec3(0.0), (-b + sqrt(max(vec3(0.0), b * b - 4.0 * a * c))) / (2.0 * a)) / max(scene_exposure, 0.001);
}
void fragment() {
	vec3 linear_rgb = vec3(linear_channel(source_rgb.r), linear_channel(source_rgb.g), linear_channel(source_rgb.b));
	ALBEDO = compensate_filmic ? inverse_filmic(linear_rgb) : linear_rgb;
	// Actor attribute 0x50000000 selects DR_MODE 0xE100002A: ABR1 (B + F).
	ALPHA = 1.0;
}
