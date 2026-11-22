shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled;

uniform sampler2D wind_atlas : source_color, filter_linear, repeat_disable;
varying flat vec4 swing;

void vertex() {
 swing = INSTANCE_CUSTOM;
 int style = int(floor(swing.a / 2.0));
 if (style == 5 || style == 7) {
  float crest_travel = 2.0 * (0.95 - (style == 5 ? 0.10 : 0.25)) / 1.65;
  float depth_direction = mod(swing.a, 2.0) * 2.0 - 1.0;
  float progress = min(swing.r * (style == 5 ? 1.9 : 2.0), 1.0);
  VERTEX.y += progress * (swing.b * sqrt(max(0.0, 1.0 - depth_direction * depth_direction)) - crest_travel);
  VERTEX.z += progress * swing.b * length(MODEL_MATRIX[1].xyz) * depth_direction;
 } else if (style == 9) {
  float progress = min(swing.r * 1.9, 1.0);
  VERTEX.y -= progress * 2.0 * (0.95 - 0.10) / 1.65;
  VERTEX.z += progress;
 } else if (style == 3 || style == 8) {
  VERTEX.z += VERTEX.x * length(MODEL_MATRIX[0].xyz) * swing.b;
  VERTEX.x *= sqrt(max(0.0, 1.0 - swing.b * swing.b));
 } else if (style == 0) {
  VERTEX.z += VERTEX.y * length(MODEL_MATRIX[1].xyz) * swing.b;
  VERTEX.y *= sqrt(max(0.0, 1.0 - swing.b * swing.b));
 }
}

float capsule(vec2 point, vec2 end, float radius) {
	float along = clamp(dot(point, end) / dot(end, end), 0.0, 1.0);
	return length(point - end * along) - radius;
}

void fragment() {
	int style = int(floor(swing.a / 2.0));
	float t = swing.r;
	if (style == 5 || style == 9) {
        vec2 p=vec2(UV.x*2.0-1.0,(1.0-UV.y)*1.65-0.30);
        float front=mix(0.10,0.95,min(t*1.9,1.0));
        vec2 cap=vec2(p.x/0.74,(p.y-front)/0.18);
        float rim=1.0-smoothstep(0.035,0.16,abs(length(cap)-1.0));
        rim*=smoothstep(front-0.10,front+0.02,p.y);
        float behind=front-p.y;
        float tail=smoothstep(0.02,0.12,behind)*(1.0-smoothstep(0.38,0.70,behind));
        float rails=1.0-smoothstep(0.025,0.12,abs(abs(p.x)-0.53));
        vec2 wind_uv=vec2(UV.x,clamp(behind/0.70,0.0,1.0));
        vec2 pixel=vec2(58.5,25.5+12.0*128.0)+wind_uv*vec2(28.0,77.0);
        vec4 wind=texture(wind_atlas,pixel/vec2(textureSize(wind_atlas,0)));
        float brush=wind.a*tail*(1.0-smoothstep(0.50,0.78,abs(p.x)));
        ALBEDO=mix(vec3(0.40,0.57,0.83),wind.rgb,wind.a);
        ALPHA=(rim*0.68+rails*tail*0.26+brush*0.42)*(1.0-smoothstep(0.35,1.0,t))*swing.g;
 } else if (style == 7) {
  vec2 p=vec2(UV.x*2.0-1.0,(1.0-UV.y)*1.65-0.30);
  float front=mix(0.25,0.95,min(t*2.0,1.0));
  vec2 bubble=(p-vec2(0.0,front))*vec2(1.0,2.2);
  float edge=1.0-smoothstep(0.02,0.11,abs(length(bubble)-0.62));
  float tail=(1.0-smoothstep(0.02,0.12,abs(abs(p.x)-0.42)))*smoothstep(front-0.65,front-0.30,p.y)*(1.0-smoothstep(front-0.10,front,p.y));
  ALBEDO=vec3(0.65,0.79,0.97);
  ALPHA=(edge*0.66+tail*0.32)*(1.0-smoothstep(0.35,1.0,t))*swing.g;
 } else if (style == 0) {
  float travel=1.0-UV.y;
  float front=mix(0.10,1.4,min(t*1.6,1.0));
  float wake=smoothstep(front-0.75,front-0.20,travel)*(1.0-smoothstep(front-0.04,front+0.06,travel));
  vec2 pixel=vec2(58.5,25.5+12.0*128.0)+UV*vec2(28.0,77.0);
  vec4 wind=texture(wind_atlas,pixel/vec2(textureSize(wind_atlas,0)));
  ALBEDO=mix(vec3(0.40,0.57,0.83),wind.rgb,wind.a);
  ALPHA=wind.a*wake*0.90*(1.0-smoothstep(0.35,1.0,t))*swing.g;
	} else if (style == 3 || style == 8) {
		vec2 point = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
		float radial = length(point);
		float travel = (atan(point.y, point.x) + 1.5707963) / 3.14159265;
		if (mod(swing.a, 2.0) > 0.5) travel = 1.0 - travel;
		float front = mix(0.10, 1.4, min(t * 1.6, 1.0));
		float wake = smoothstep(front - 0.75, front - 0.20, travel)
			* (1.0 - smoothstep(front - 0.04, front + 0.06, travel));
		vec2 wind_uv = vec2((radial - (style == 8 ? 0.30 : 0.58)) / (style == 8 ? 0.70 : 0.42), 1.0 - travel);
		vec4 wind = vec4(0.0);
		if (point.x >= 0.0 && all(greaterThanEqual(wind_uv, vec2(0.0))) && all(lessThanEqual(wind_uv, vec2(1.0)))) {
			vec2 pixel = vec2(58.5, 25.5 + 12.0 * 128.0) + wind_uv * vec2(28.0, 77.0);
			wind = texture(wind_atlas, pixel / vec2(textureSize(wind_atlas, 0)));
		}
		ALBEDO = mix(vec3(0.40, 0.57, 0.83), wind.rgb, wind.a);
		ALPHA = wind.a * wake * 0.90 * (1.0 - smoothstep(0.35, 1.0, t)) * swing.g;
	} else if (style == 1) {
		vec2 point = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
		float radius = length(point);
		float wave = mix(0.43, 0.88, 1.0 - pow(1.0 - t, 2.0));
		float ring = 1.0 - smoothstep(0.025, 0.14, abs(radius - wave));
		ring *= smoothstep(-0.60, -0.15, point.y);
		float front = smoothstep(-0.8, 0.5, point.y);
		float mist = (1.0 - smoothstep(0.0, wave, radius)) * 0.11;
		vec2 curl = vec2(atan(point.x, point.y) / 6.2831853 + 0.5, clamp((radius - wave) * 3.0 + 0.5, 0.0, 1.0));
		vec2 pixel = vec2(58.5, 25.5 + 12.0 * 128.0) + curl * vec2(28.0, 77.0);
		vec4 wind = texture(wind_atlas, pixel / vec2(textureSize(wind_atlas, 0)));
		ALBEDO = mix(vec3(0.65, 0.79, 0.97), wind.rgb, wind.a * 0.65);
		ALPHA = (ring * (0.30 + front * 0.35 + wind.a * 0.15) + mist)
			* (1.0 - smoothstep(0.30, 1.0, t)) * swing.g;
	} else {
	// Cosmetic coordinates are relative to the prepared stroke length.
	float radius = swing.b;
	float arc = mod(swing.a, 2.0);
	vec2 point = vec2((UV.x * 2.0 - 1.0) * (sin(arc) + radius),
		0.5 + (0.5 - UV.y) * (1.0 + radius * 2.0));
	float distance_to_edge = capsule(point, vec2(0.0, 1.0), radius);
	if (arc > 0.0) {
		// shortcut: Cross Gate has one seven-ray sweep; pass endpoints if another pattern is added.
		for (int i = 0; i < 7; i++) {
			float angle = mix(-arc, arc, float(i) / 6.0);
			distance_to_edge = min(distance_to_edge, capsule(point, vec2(sin(angle), cos(angle)), radius));
		}
	}
	float angle = atan(point.x, point.y);
	float nearest_angle = clamp(angle, -arc, arc);
	float envelope = capsule(point, vec2(sin(nearest_angle), cos(nearest_angle)), radius);
	if (envelope > 0.0) discard;
	float feather = max(fwidth(distance_to_edge), 0.001);
	float mask = 1.0 - smoothstep(-feather, 0.0, envelope);
	float footprint = 1.0 - smoothstep(-feather, 0.0, distance_to_edge);
	if (style == 2) footprint = 0.0;
	float radial = length(point);
	float travel = arc > 0.0 ? (angle / arc + 1.0) * 0.5 : point.y;
	float front = mix(0.10, 1.4, min(t * 1.6, 1.0));
	float wake = smoothstep(front - 0.75, front - 0.20, travel)
		* (1.0 - smoothstep(front - 0.04, front + 0.06, travel));
	// Bend the original upward 追月 crest into a sweep, or extend it along a thrust.
	vec2 wind_uv = arc > 0.0
		? vec2((radial - 0.55) / (0.50 + radius), 1.0 - travel)
		: vec2(point.x / (radius * 2.0) + 0.5, 1.0 - point.y / (1.0 + radius));
	vec4 wind = vec4(0.0);
	if (all(greaterThanEqual(wind_uv, vec2(0.0))) && all(lessThanEqual(wind_uv, vec2(1.0)))) {
		vec2 pixel = vec2(58.5, 25.5 + 12.0 * 128.0) + wind_uv * vec2(28.0, 77.0);
		wind = texture(wind_atlas, pixel / vec2(textureSize(wind_atlas, 0)));
	}
	ALBEDO = mix(vec3(0.40, 0.57, 0.83), wind.rgb, wind.a);
	ALPHA = mask * (footprint * 0.045 + wind.a * wake * 0.90)
		* (1.0 - smoothstep(0.35, 1.0, t)) * swing.g;
	}
}
