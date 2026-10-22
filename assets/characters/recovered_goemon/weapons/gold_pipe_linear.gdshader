shader_type spatial;
render_mode cull_disabled;

uniform sampler2D source_texture : source_color, filter_linear, repeat_disable;
uniform vec2 source_texture_scale = vec2(0.03125, 0.0625);
uniform vec2 source_texture_size = vec2(32.0, 64.0);

void vertex() {
	// Retail DL09002518 uses G_TEXTURE_GEN_LINEAR, with gSPTexture 0800/1000.
	// Its generated range is 1024 texels: these scales span the 32x64 gold PIC.
	// Generate per vertex so interpolation follows the original RSP pipeline.
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	UV = acos(clamp(view_normal.xy, vec2(-1.0), vec2(1.0))) / PI;
	UV *= 1024.0 * source_texture_scale / source_texture_size;
}

void fragment() {
	ALBEDO = texture(source_texture, UV).rgb;
	ROUGHNESS = 0.55;
	SPECULAR = 0.0;
}
