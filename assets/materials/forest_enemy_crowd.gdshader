shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D emission_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_albedo_texture=false;
uniform bool has_emission_texture=false;
uniform vec4 albedo_color : source_color=vec4(1.0);
uniform vec4 emission_color : source_color=vec4(0.0);
uniform float emission_energy=1.0;
uniform float roughness=.8;
uniform float metallic=0.0;
uniform sampler2D pose_texture : filter_nearest, repeat_disable;
varying float frozen_tint;
void vertex(){
 int group=int(round(UV2.x));int actor=int(round(INSTANCE_CUSTOM.w));
 vec4 col_x=texelFetch(pose_texture,ivec2(group*3,actor),0);
 vec4 col_y=texelFetch(pose_texture,ivec2(group*3+1,actor),0);
 vec4 col_z=texelFetch(pose_texture,ivec2(group*3+2,actor),0);
 mat3 rigid=mat3(col_x.xyz,col_y.xyz,col_z.xyz);
 VERTEX=rigid*VERTEX+vec3(col_x.w,col_y.w,col_z.w);
 mat3 normal_basis=mat3(
  texelFetch(pose_texture,ivec2(22+group*3,actor),0).xyz,
  texelFetch(pose_texture,ivec2(23+group*3,actor),0).xyz,
  texelFetch(pose_texture,ivec2(24+group*3,actor),0).xyz);
 NORMAL=normalize(normal_basis*NORMAL);
 frozen_tint=texelFetch(pose_texture,ivec2(21,actor),0).r;
}
void fragment(){
 vec3 artwork=albedo_color.rgb;
 if(has_albedo_texture){artwork*=texture(albedo_texture,UV).rgb;}
 ALBEDO=mix(artwork,vec3(.35,.75,1.0),frozen_tint*.55);
 ROUGHNESS=roughness;METALLIC=metallic;
 EMISSION=emission_color.rgb*emission_energy;
 if(has_emission_texture){EMISSION*=texture(emission_texture,UV).rgb;}
}
