shader_type spatial;
render_mode cull_disabled;
uniform sampler2D pose_texture : filter_nearest, repeat_disable;
uniform sampler2D surface_properties : filter_nearest, repeat_disable;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool textured=false;
varying float frozen;
varying float flash;
varying float material_row;
vec3 deform(int part,int row,vec3 vertex,bool normal){
 int base=part*6+(normal?3:0);
 vec4 a=texelFetch(pose_texture,ivec2(base,row),0);
 vec4 b=texelFetch(pose_texture,ivec2(base+1,row),0);
 vec4 c=texelFetch(pose_texture,ivec2(base+2,row),0);
 return mat3(a.xyz,b.xyz,c.xyz)*vertex+(normal?vec3(0.0):vec3(a.w,b.w,c.w));
}
void vertex(){
 int row=int(floor(INSTANCE_CUSTOM.x));int next=min(row+1,textureSize(pose_texture,0).y-1);float blend=fract(INSTANCE_CUSTOM.x);
 int motion_row=int(floor(INSTANCE_CUSTOM.y));int motion_next=min(motion_row+1,textureSize(pose_texture,0).y-1);float motion_blend=fract(INSTANCE_CUSTOM.y);float motion_strength=mod(INSTANCE_CUSTOM.z,2.0);
 vec3 p=vec3(0.0);vec3 n=vec3(0.0);
 for(int i=0;i<4;i++){
  float weight=CUSTOM1[i];if(weight>0.00001){
   int part=int(round(CUSTOM0[i]));vec3 posed=mix(deform(part,row,VERTEX,false),deform(part,next,VERTEX,false),blend);vec3 normal=mix(deform(part,row,NORMAL,true),deform(part,next,NORMAL,true),blend);
   if(motion_strength>0.00001){posed=mix(posed,mix(deform(part,motion_row,VERTEX,false),deform(part,motion_next,VERTEX,false),motion_blend),motion_strength);normal=mix(normal,mix(deform(part,motion_row,NORMAL,true),deform(part,motion_next,NORMAL,true),motion_blend),motion_strength);}
   p+=posed*weight;n+=normal*weight;
  }
 }
 VERTEX=p;NORMAL=n/max(length(n),0.00001);frozen=floor(INSTANCE_CUSTOM.z*.5);flash=INSTANCE_CUSTOM.w;material_row=UV2.x;
}
void fragment(){
 vec4 paint=COLOR*texelFetch(surface_properties,ivec2(2,int(round(material_row))),0);if(textured)paint*=texture(albedo_texture,UV);
 ALBEDO=mix(paint.rgb,vec3(.35,.75,1.0),frozen*.55);
 vec4 surface=texelFetch(surface_properties,ivec2(0,int(round(material_row))),0);
 vec4 glow=texelFetch(surface_properties,ivec2(1,int(round(material_row))),0);
 if((glow.a<.5&&!FRONT_FACING)||(glow.a>.5&&glow.a<1.5&&FRONT_FACING))discard;
 ROUGHNESS=surface.r;METALLIC=surface.g;SPECULAR=surface.a;
 EMISSION=glow.rgb*surface.b;
 EMISSION+=vec3(1.0,.17,.06)*min(1.0,flash*24.0)*1.4;
}
