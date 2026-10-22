shader_type spatial;
render_mode diffuse_lambert;
uniform sampler2D grass_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool coastal = false;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	vec3 grass=texture(grass_tex,world_position.xz*.32).rgb;
	vec3 sand=texture(sand_tex,world_position.xz*.32).rgb;
	float shore=coastal?smoothstep(39.5,42.5,world_position.z):0.0;
	float bank=coastal?(1.0-smoothstep(4.8,6.8,abs(world_position.x-(24.0+3.0*sin(world_position.z*.055))))):0.0;
	ALBEDO=mix(grass,sand,max(shore,bank*.65));
	ROUGHNESS=1.0;
}
