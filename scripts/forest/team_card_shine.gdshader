shader_type canvas_item;
render_mode unshaded;

uniform vec4 rarity_color : source_color = vec4(1.0);
uniform float rarity = 1.0;
uniform float phase = 0.0;

float sparkle(vec2 uv, vec2 center, float clock) {
	vec2 d = abs((uv - center) * vec2(0.7, 1.0));
	float cross = exp(-d.x * 850.0 - d.y * 85.0) + exp(-d.y * 850.0 - d.x * 85.0);
	return cross * pow(max(0.0, sin(clock)), 8.0);
}

void fragment() {
	bool legendary = rarity > 3.5;
	float outset = legendary ? 32.0 : 0.0;
	vec2 uv = (UV * (vec2(284.0, 440.0) + 2.0 * outset) - outset) / vec2(284.0, 440.0);
	vec2 edge = min(uv, 1.0 - uv) * vec2(284.0, 440.0);
	float inset = min(min(edge.x, edge.y), (edge.x + edge.y - 10.0) * 0.707);
	float border = 1.0 - smoothstep(1.0, 3.0, inset);
	float glow = exp(-max(inset, 0.0) / 13.0);
	float clock = TIME + phase;
	float sweep = pow(max(0.0, 1.0 - abs(UV.x + UV.y * 0.35 - (mod(clock * 0.38, 2.4) - 0.5)) / 0.15), 2.0);
	float stars = sparkle(UV, vec2(0.06, 0.12), clock * 1.8)
		+ sparkle(UV, vec2(0.94, 0.76), clock * 1.6 + 2.0)
		+ sparkle(UV, vec2(0.72, 0.97), clock * 1.4 + 4.0);
	vec3 tint = rarity_color.rgb;
	if (rarity > 2.5) {
		tint = mix(tint, vec3(0.80, 0.66, 1.0), 0.35 + 0.25 * sin(UV.y * 9.0 + clock));
		stars += sparkle(UV, vec2(0.91, 0.25), clock * 2.0 + 1.0);
	}
	float alpha = 0.045 + border * 0.75 + glow * 0.17 + sweep * (0.12 + border * 0.6) + stars * 0.6;
	if (legendary) {
		tint = 0.6 + 0.4 * cos(6.28318 * (vec3(0.0, 0.333, 0.667) + uv.y * 0.65 + uv.x * 0.24 - clock * 0.12));
		sweep = pow(max(0.0, 1.0 - abs(uv.x + uv.y * 0.35 - (mod(clock * 0.55, 2.6) - 0.6)) / 0.38), 2.0);
		stars = sparkle(uv * 0.45, vec2(0.02, 0.05), clock * 1.4)
			+ sparkle(uv * 0.45, vec2(0.43, 0.34), clock * 1.2 + 2.0)
			+ sparkle(uv * 0.45, vec2(0.32, 0.44), clock * 1.1 + 4.0)
			+ sparkle(uv * 0.45, vec2(0.43, 0.10), clock * 1.3 + 1.0);
		float halo = exp(-abs(inset) / 15.0);
		float inside = smoothstep(-0.5, 0.5, inset);
		alpha = (0.10 + sweep * 0.25) * inside + halo * (0.55 + sweep * 0.4) + stars * 0.9;
		float outer_fade = smoothstep(0.0, 0.035, min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y)));
		COLOR = vec4(mix(tint, vec3(1.0), clamp(stars * 0.7 + sweep * 0.4, 0.0, 0.9)), clamp(alpha, 0.0, 1.0) * outer_fade);
	} else {
	COLOR = vec4(mix(tint, vec3(1.0), clamp(sweep * 0.45 + stars * 0.6, 0.0, 0.85)), clamp(alpha, 0.0, 1.0) * smoothstep(-0.5, 0.5, inset));
	}
}
