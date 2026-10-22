shader_type canvas_item;
render_mode unshaded, blend_disabled;

// Keep the recovered RGB555 foreground, but smoothly present it over the
// full-resolution scene. A black effect fragment must not pixelate the world.
// These samplers contain encoded values. Only HDR2D scene data is linear.
uniform sampler2D foreground_rgb5 : filter_linear, repeat_disable;
uniform sampler2D scene_color : hint_screen_texture, filter_nearest, repeat_disable;
uniform bool canvas_linear = false;

vec3 display_from_linear(vec3 value) {
	return mix(value*12.92,1.055*pow(max(value,vec3(0.0)),vec3(1.0/2.4))-0.055,greaterThan(value,vec3(0.0031308)));
}
vec3 linear_from_display(vec3 value) {
	return mix(value/12.92,pow((value+0.055)/1.055,vec3(2.4)),greaterThan(value,vec3(0.04045)));
}
void fragment() {
	vec3 foreground=textureLod(foreground_rgb5,SCREEN_UV,0.0).rgb*(255.0/31.0);
	// Foreground RGB already includes coverage. Multiplying alpha again would
	// darken filtered edges, while adding zero should leave scenery untouched.
	if (max(foreground.r,max(foreground.g,foreground.b))<=0.0) { discard; }
	vec3 background=textureLod(scene_color,SCREEN_UV,0.0).rgb;
	if (canvas_linear) { background=display_from_linear(background); }
	vec3 output_rgb=min(background+foreground,vec3(1.0));
	if (canvas_linear) { output_rgb=linear_from_display(output_rgb); }
	COLOR=vec4(output_rgb,1.0);
}
