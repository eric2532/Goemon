shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_add, depth_draw_never;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable;
uniform bool textured = false;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform bool compensate_filmic = false;
uniform float scene_exposure = 1.0;
uniform float scene_white = 1.0;
uniform bool billboard = false;

void vertex() {
	if (billboard) {
		// Face the camera while retaining inherited scale from the bomb/blast.
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
			INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
			INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
	}
}

// These recovered leaders keep the disc's display-authored RGB in COLOR_0.
// Godot leaves vertex colors raw, but source_color textures/uniforms are linear.
// Reproduce PS1 display-RGB modulation first, then decode exactly once. No mesh
// colors or texture pixels are changed to accommodate the modern renderer.
float display_to_linear_channel(float value) {
	return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4);
}
float linear_to_display_channel(float value) {
	return value <= 0.0031308 ? value * 12.92 : 1.055 * pow(max(value, 0.0), 1.0 / 2.4) - 0.055;
}
vec3 display_to_linear(vec3 value) {
	return vec3(display_to_linear_channel(value.r), display_to_linear_channel(value.g), display_to_linear_channel(value.b));
}
vec3 linear_to_display(vec3 value) {
	return vec3(linear_to_display_channel(value.r), linear_to_display_channel(value.g), linear_to_display_channel(value.b));
}

// Inverse of Godot 4.6's per-channel Filmic curve, with its exposure bias baked
// into the constants. Keep Forest HDR grading while preserving these source RGBs.
// Reference: godotengine/godot 4.6-stable, effects/tonemap.glsl, tonemap_filmic.
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
	vec3 display_rgb = COLOR.rgb * linear_to_display(tint_color.rgb);
	float alpha = COLOR.a * tint_color.a;
	if (textured) {
		vec4 texel = texture(albedo_texture, UV);
		display_rgb *= linear_to_display(texel.rgb);
		alpha *= texel.a;
	}
	if (alpha < 0.5) discard;
	vec3 desired_linear = display_to_linear(clamp(display_rgb, vec3(0.0), vec3(1.0)));
	ALBEDO = compensate_filmic ? inverse_filmic(desired_linear) : desired_linear;
	ALPHA = 1.0;
}
