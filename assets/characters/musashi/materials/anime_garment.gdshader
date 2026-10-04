shader_type spatial;
render_mode diffuse_burley;

// Rest-space garment coordinates exported as UV (depth) and UV2 (x, height).
// These remain attached to the cloth when the existing skeleton bends it.
uniform bool trousers = false;
const vec3 CRIMSON = vec3(.34,.018,.037);
const vec3 EDGE = vec3(.58,.046,.038);
const vec3 VEST = vec3(.036,.044,.051);
const vec3 ORANGE = vec3(.98,.32,.028);
const vec3 WRAP = vec3(.64,.59,.43);
const vec3 SHOE = vec3(.031,.068,.13);
const vec3 SOLE = vec3(.017,.023,.027);

float peak(float x, float center, float width, float height) {
	return height * max(0.0, 1.0 - abs(x-center)/width);
}
void fragment() {
	float x=abs(UV2.x);
	// glTF flips Blender's V coordinate on export.
	float z=1.0-UV2.y;
	float front=UV.x;
	vec3 color=CRIMSON;
	if (trousers) {
		if (z<.39) color=WRAP;
		if (z<.19) color=SHOE;
		if (z<.075) color=SOLE;
		// Restrained diagonal wrap overlaps, following the original ivory wraps.
		if (z>.20 && z<.385) {
			float line=abs(fract((z+x*.15)*26.0)-.5);
			color*=mix(.82,1.0,smoothstep(.0,.085,line));
		}
	} else {
		if (z<.825) color=EDGE;
		float vest_width=mix(.124,.162,smoothstep(.85,1.12,z));
		vest_width-=.044*smoothstep(1.14,1.34,z);
		if (front>.046 && z>.825 && x<vest_width+.019) color=EDGE;
		if (front>.047 && z>.843 && x<vest_width) color=VEST;
		if (z>1.305 && x<.117) color=VEST;
		// Three tapering flame tongues retain the orange sleeve motif.
		float u=(x-.266)/.212;
		float flame_top=.932 + max(peak(u,.15,.20,.14), max(peak(u,.47,.24,.205),peak(u,.81,.21,.125)));
		if (u>0.0 && u<1.1 && front>.005 && z>.863 && z<flame_top) color=ORANGE;
		if (z>.832 && z<.861 && x>.29) color=EDGE;
	}
	ALBEDO=color;
	ROUGHNESS=.94;
	SPECULAR=.03;
}
