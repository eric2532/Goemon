shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 ice_glimmer : source_color;
varying vec2 passage_point;

void vertex() {
	passage_point = VERTEX.xy;
}

void fragment() {
	vec2 spill = (passage_point - vec2(0.0, .50)) * vec2(.57, .74);
	float bounce = 1.0 - smoothstep(.0, 1.45, dot(spill, spill));
	ALBEDO = ice_glimmer.rgb * (.12 + .62 * bounce);
}
