shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
#include "res://assets/vfx/edo/brush_noise.gdshaderinc"
uniform sampler2D flame_texture : source_color, repeat_enable;
uniform vec4 tint : source_color;
instance uniform float playback_age = 0.0;

void fragment() {
	vec2 flow = UV * vec2(3.0, 2.0) - vec2(playback_age * 0.25, playback_age * 1.8);
	float noise = brush_noise(flow * 3.0);
	float flame = texture(flame_texture, flow + vec2(noise * 0.2, 0.0)).r;
	float hot = smoothstep(0.12, 0.85, flame + noise * 0.35);
	vec3 fire = mix(tint.rgb * 0.65, mix(tint.rgb, vec3(0.95, 0.72, 1.0), 0.65), hot);
	ALBEDO = fire;
	EMISSION = fire * (0.25 + hot * 0.45);
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALPHA = smoothstep(0.05, 0.6, facing) * (0.25 + hot * 0.65);
}
