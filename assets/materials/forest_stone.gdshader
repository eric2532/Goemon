shader_type spatial;
render_mode cull_back;
#include "res://scripts/forest/attack_range.gdshaderinc"
#include "res://scripts/forest/castle_stone.gdshaderinc"
#include "res://scripts/forest/forest_route_finish.gdshaderinc"
uniform bool use_castle_stone = false;
uniform float roof_cutaway_height = 0.0;
uniform vec4 stone_color : source_color = vec4(.48,.51,.48,1.0);
uniform bool use_cliff_face = false;
uniform bool cliff_crags = false;
uniform int entrance_cut_count = 0;
uniform vec4 entrance_cuts[3];
uniform vec2 entrance_back[3];
uniform vec4 entrance_profile[24];
uniform vec2 entrance_scale=vec2(1.0);
uniform sampler2D cliff_face : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool masonry = false;
uniform bool frost_paving = false;
uniform float snow_cover : hint_range(0.0, 1.0) = 0.0;
uniform vec2 masonry_tile = vec2(3.3,1.65);
uniform bool weathered_masonry = false;
uniform float weathered_masonry_strength : hint_range(0.0, 1.0) = 1.0;
uniform bool carved_detail = false;
uniform sampler2D detail_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 stone_point;
varying vec3 stone_normal;
varying vec3 cliff_local;
void vertex() {
	cliff_local=VERTEX;
	stone_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	stone_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	for(int i=0;i<entrance_cut_count;i++) {
		vec3 offset=cliff_local-entrance_cuts[i].xyz;
		vec2 back=entrance_back[i];
		float depth=dot(offset.xz,back);
		float across=dot(offset.xz,vec2(back.y,-back.x));
		if(abs(across)<2.1*entrance_scale.x && depth> -2.8*entrance_scale.y && depth<8.0*entrance_scale.y && offset.y> -.14 && offset.y<entrance_cuts[i].w) {
			float height=offset.y+.14;
			for(int row=0;row<7;row++) {
				vec3 lower=entrance_profile[i*8+row].xyz;
				vec3 upper=entrance_profile[i*8+row+1].xyz;
				if(height>=lower.z && height<=upper.z) {
					vec2 edges=mix(lower.xy,upper.xy,(height-lower.z)/max(.001,upper.z-lower.z));
					if(across>edges.x-.04 && across<edges.y+.04) discard;
				}
			}
		}
	}
	if(roof_cutaway_height>0.0 && CAMERA_POSITION_WORLD.y>roof_cutaway_height) discard;
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
		float row=floor(plane.y/masonry_tile.y);
		vec2 tile=plane/masonry_tile+vec2(mod(row,2.0)*.5,0.0);
		vec2 cell=fract(tile);vec2 seam=min(cell,1.0-cell);
		float mortar=1.0-smoothstep(.010,.028+max(fwidth(tile.x),fwidth(tile.y)),min(seam.x,seam.y));
		float variation=fract(sin(dot(floor(tile),vec2(12.99,78.23)))*43758.55);
		color*=.87+variation*.24;
		color=mix(color,stone_color.rgb*.39,mortar*.70);
		if(weathered_masonry) {
			float grit=texture(rock_texture,plane*2.8).g;
			float chip=(grit-.45)*.053;
			float border=min(seam.x,seam.y)+chip;
			float soft=max(fwidth(tile.x),fwidth(tile.y));
			float block=smoothstep(.026,.046+soft,border);
			float ridge=(1.0-smoothstep(.070,.19+soft,border))*block;
			float light_edge=step(min(cell.x,1.0-cell.y),min(1.0-cell.x,cell.y));
			vec3 face=stone_color.rgb*(.55+variation*.49+grain*.64+grit*.43);
			face*=1.0+ridge*mix(-.34,.57,light_edge);
			color=mix(color,mix(stone_color.rgb*.24,face,block),weathered_masonry_strength);
		}
	}
	float moss=(1.0-smoothstep(.15,2.5,stone_point.y))*.18;
	color=mix(color,vec3(.20,.28,.16),moss);
	if(use_cliff_face) {
		vec3 cp=stone_point*vec3(.145,.128,.145)+sin(stone_point.yzx*.73+stone_point.zxy*.26)*.067;
		if(cliff_crags) {
			vec3 leaves=texture(cliff_face,cp.zy).rgb*weights.x+texture(cliff_face,cp.xz).rgb*weights.y+texture(cliff_face,cp.xy).rgb*weights.z;
			float growth=smoothstep(.34,.72,.58+stone_normal.y*.24+.20*sin(stone_point.x*.42+stone_point.z*.31)+grain*.20);
			color=mix(rock*.78,leaves,growth)*(.90+grain*.20);
		} else {
			vec3 face=texture(cliff_face,cp.zy).rgb*weights.x+
				texture(cliff_face,cp.xz).rgb*weights.y+texture(cliff_face,cp.xy).rgb*weights.z;
			color=mix(color,face,.83)*(.79+grain*.43);
		}
	}
	if(frost_paving) {
		vec2 stone_tile=stone_point.xz/vec2(2.15,1.18);
		stone_tile.x+=mod(floor(stone_tile.y),2.0)*.5;
		vec2 seam=min(fract(stone_tile),1.0-fract(stone_tile));
		float joint=1.0-smoothstep(.012,.038+max(fwidth(stone_tile.x),fwidth(stone_tile.y)),min(seam.x,seam.y));
		float hue=fract(sin(dot(floor(stone_tile),vec2(12.99,78.23)))*43758.55);
		color*=.87+hue*.20;
		color=mix(color,vec3(.44,.54,.60),joint*.33);
	}
	if(snow_cover>0.0) {
		float slope=max(0.0,stone_normal.y);
		float pockets=.12*sin(stone_point.x*.64+stone_point.z*.55)+.14*grain;
		float frost=smoothstep(.57,.78,slope+pockets+(snow_cover-.5)*.48);
		color=mix(color,vec3(.74,.86,.93)*(.84+grain*.31),frost);
	}
	if(use_castle_stone) color=castle_stone(stone_point,stone_normal);
	if(use_cliff_face)color=mix(color,route_tint*(.88+grain*.18),route_weight(stone_point));
	ALBEDO=attack_range_ink(color,stone_point,stone_normal);
	ROUGHNESS=.96;SPECULAR=.18;
}
