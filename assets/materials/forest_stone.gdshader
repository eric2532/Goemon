shader_type spatial;
render_mode cull_back;
uniform vec4 stone_color : source_color = vec4(.48,.51,.48,1.0);
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool masonry = false;
uniform bool carved_detail = false;
uniform sampler2D detail_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 stone_point;
varying vec3 stone_normal;
void vertex() {
	stone_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	stone_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	vec3 weights=pow(abs(normalize(stone_normal)),vec3(4.0));
	weights/=max(.001,weights.x+weights.y+weights.z);
	vec3 p=stone_point*.36;
	vec3 rock=texture(rock_texture,p.zy).rgb*weights.x+texture(rock_texture,p.xz).rgb*weights.y+texture(rock_texture,p.xy).rgb*weights.z;
	float grain=dot(rock,vec3(.2126,.7152,.0722));
	vec3 color=stone_color.rgb*(.70+grain*1.05);
	float vein=pow(1.0-abs(sin(stone_point.y*.53+grain*3.8+stone_point.x*.13)),18.0);
	color=mix(color,stone_color.rgb*1.2,vein*.14);
	if(carved_detail) {
		vec3 marks=texture(detail_texture,UV).rgb;
		float engraving=dot(marks,vec3(.2126,.7152,.0722));
		color*=.69+engraving*.43;
	}
	if(masonry) {
		vec2 plane=abs(stone_normal.x)>abs(stone_normal.z) ? stone_point.zy : stone_point.xy;
		float row=floor(plane.y/1.65);
		vec2 tile=plane/vec2(3.3,1.65)+vec2(mod(row,2.0)*.5,0.0);
		vec2 cell=fract(tile);vec2 seam=min(cell,1.0-cell);
		float mortar=1.0-smoothstep(.010,.028+max(fwidth(tile.x),fwidth(tile.y)),min(seam.x,seam.y));
		float variation=fract(sin(dot(floor(tile),vec2(12.99,78.23)))*43758.55);
		color*=.87+variation*.24;
		color=mix(color,stone_color.rgb*.39,mortar*.70);
	}
	float moss=(1.0-smoothstep(.15,2.5,stone_point.y))*.18;
	color=mix(color,vec3(.20,.28,.16),moss);
	ALBEDO=color;
	ROUGHNESS=.96;SPECULAR=.18;
}
