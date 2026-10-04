shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;
uniform float stage = 1.0;
varying vec3 crack_position;
varying vec3 crack_normal;
vec2 fracture_seed(vec2 cell) {
	vec3 p = fract(vec3(cell.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.xx + p.yz) * p.zy);
}
void vertex() {
	crack_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	crack_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	VERTEX += NORMAL * 0.015;
}
void fragment() {
	vec3 n = abs(crack_normal);
	vec2 uv = n.y > max(n.x,n.z) ? crack_position.xz : (n.x > n.z ? crack_position.zy : crack_position.xy);
	uv *= 0.28;
	uv += (abs(fract(uv.yx * 4.7) - 0.5) - 0.25) * 0.18;
	vec2 cell = floor(uv);
	vec2 within = fract(uv);
	float nearest = 10.0;
	float second = 10.0;
	for (int y=-1; y<=1; y++) {
		for (int x=-1; x<=1; x++) {
			vec2 offset = vec2(float(x),float(y));
			vec2 delta = offset + fracture_seed(cell+offset) - within;
			float distance_squared = dot(delta,delta);
			second = min(second,max(nearest,distance_squared));
			nearest = min(nearest,distance_squared);
		}
	}
	float edge = second-nearest;
	ALBEDO = vec3(0.022,0.012,0.007);
	ALPHA = (1.0-smoothstep(0.005,0.014+stage*0.009,edge))*0.94;
}
