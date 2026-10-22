float display_to_linear_channel(float value) {
	return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4);
}
vec3 display_to_linear(vec3 value) {
	return vec3(display_to_linear_channel(value.r), display_to_linear_channel(value.g), display_to_linear_channel(value.b));
}
float filmic_white(float x) {
	return (x * (0.88 * x + 0.06) + 0.002) / (x * (0.88 * x + 0.60) + 0.06) - 1.0 / 30.0;
}
vec3 source_output(vec3 display_rgb, bool compensate_filmic, float scene_exposure, float scene_white) {
	vec3 linear_rgb = display_to_linear(clamp(display_rgb, vec3(0.0), vec3(1.0)));
	if (!compensate_filmic) return linear_rgb;
	vec3 k = linear_rgb * filmic_white(max(scene_white, 0.001)) + vec3(1.0 / 30.0);
	vec3 a = 0.88 * (vec3(1.0) - k);
	vec3 b = 0.60 * (vec3(0.10) - k);
	vec3 c = 0.20 * (vec3(0.01) - 0.30 * k);
	return max(vec3(0.0), (-b + sqrt(max(vec3(0.0), b * b - 4.0 * a * c))) / (2.0 * a)) / max(scene_exposure, 0.001);
}
