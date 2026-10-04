shader_type spatial;
render_mode cull_disabled;
uniform bool gold_cloak=false;
uniform float cloth_clock=0.0;
uniform float flow=0.0;
uniform float sway=0.0;
uniform float airborne=0.0;
uniform float hem_lift=0.0;
uniform vec2 wind_direction=vec2(0.0,1.0);

void vertex() {
	// glTF flips Blender's vertical texture coordinate on export.
	// Convert it back so the neck has zero motion and only the hem/tips billow.
	float t=1.0-UV.y;
	float weight=pow(t,1.7);
	if (UV2.x>0.5) {
		// Keep chest and shoulders covered. The lower front opens sideways,
		// while the back streams out, clear of the legs instead of through them.
		float skirt=smoothstep(0.22,1.0,t);
		vec2 radial=normalize(VERTEX.xz);
		float back=smoothstep(-0.3,0.6,dot(radial,wind_direction));
		vec2 side=vec2(wind_direction.y,-wind_direction.x);
		float breeze=flow+airborne*0.22;
		VERTEX.xz+=wind_direction*breeze*skirt*1.25*back;
		VERTEX.xz+=side*sign(dot(radial,side))*breeze*skirt*.40*(1.0-back);
		VERTEX.y+=skirt*(breeze*0.25+hem_lift);
		VERTEX.x+=weight*(sway*.32+sin(cloth_clock*3.0-t*5.5+UV.x*9.0)*(.018+flow*.055));
		VERTEX.y+=skirt*sin(cloth_clock*3.7-t*6.5+UV.x*11.0)*(.012+flow*.05);
	} else {
		// The wrap and knot use UV.y=0; only the narrow scarf ends move.
		VERTEX.z-=(VERTEX.z-0.40)*(1.0-flow)*0.42*step(0.001,t);
		float angle=atan(wind_direction.x,wind_direction.y)*smoothstep(0.0,.50,t)*(flow*.92+airborne*.08);
		vec2 tail=VERTEX.xz-vec2(0.0,.40);
		VERTEX.xz=vec2(tail.x*cos(angle)+tail.y*sin(angle),-tail.x*sin(angle)+tail.y*cos(angle))+vec2(0.0,.40);
		VERTEX.y+=(flow*0.85+airborne*.10)*t;
		VERTEX.x+=weight*(sway+sin(cloth_clock*(2.8+flow*2.3)-t*7.0+UV.x*1.6)*(0.055+flow*0.13));
		VERTEX.y+=weight*sin(cloth_clock*(3.1+flow*2.3)-t*8.0)*(0.035+flow*0.08);
	}
}

void fragment() {
	vec3 fabric=gold_cloak ? mix(vec3(0.35,0.14,0.015),vec3(1.0,0.66,0.10),clamp(dot(COLOR.rgb,vec3(0.6,0.25,0.15))*1.7+0.2,0.0,1.0)) : COLOR.rgb;
	ALBEDO=fabric*(0.98+0.02*sin(UV.x*310.0)*sin(UV.y*670.0));
	EMISSION=gold_cloak ? fabric*0.14 : vec3(0.0);
	ROUGHNESS=gold_cloak ? 0.68 : 0.94;
	SPECULAR=0.15;
	NORMAL=FRONT_FACING ? NORMAL : -NORMAL;
}
