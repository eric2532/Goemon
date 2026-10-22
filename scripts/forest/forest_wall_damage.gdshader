shader_type spatial;
render_mode cull_disabled;
uniform float damage_stage=0.0;
uniform float impact=0.0;
void fragment() {
	if (COLOR.r*4.0>damage_stage+.1) { discard; }
	float width=mix(.48,1.0,clamp((damage_stage-1.0)/3.0,0.0,1.0));
	float edge=UV.x/width;
	if (abs(edge)>1.0) { discard; }
	// A dark recess with one narrow, chipped stone lip reads as depth under
	// both the original stone lighting and the painterly environment.
	float bevel=smoothstep(.4,.95,edge);
	ALBEDO=mix(vec3(.055,.067,.054),vec3(.38,.39,.31),bevel);
	ALBEDO=mix(ALBEDO,vec3(.48,.43,.31),impact*.16);
	ROUGHNESS=1.0;SPECULAR=.05;
	EMISSION=vec3(.23,.18,.09)*impact*.12;
}
