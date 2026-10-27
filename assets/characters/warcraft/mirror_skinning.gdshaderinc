uniform sampler2D pose_texture : filter_nearest, repeat_disable;
uniform sampler2D surface_properties : filter_nearest, repeat_disable;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool textured=false;
uniform bool glow=false;
uniform float model_scale=1.0;
varying float opacity;
varying float flash;
varying float frozen;
varying float material_row;
vec3 deform(int part,int row,vec3 vertex){
 vec4 a=texelFetch(pose_texture,ivec2(part*6,row),0),b=texelFetch(pose_texture,ivec2(part*6+1,row),0),c=texelFetch(pose_texture,ivec2(part*6+2,row),0);
 return mat3(a.xyz,b.xyz,c.xyz)*vertex+vec3(a.w,b.w,c.w);
}
void vertex(){
 int row=int(floor(INSTANCE_CUSTOM.x)),next=min(row+1,textureSize(pose_texture,0).y-1);
 int moving=int(floor(INSTANCE_CUSTOM.y)),moving_next=min(moving+1,textureSize(pose_texture,0).y-1);
 float t=fract(INSTANCE_CUSTOM.x),mt=fract(INSTANCE_CUSTOM.y),strength=mod(INSTANCE_CUSTOM.z,2.0);
 vec3 source=CUSTOM2.w>.5?CUSTOM2.xyz:VERTEX;vec3 p=vec3(0);opacity=0.0;
 for(int i=0;i<4;i++){
  if(CUSTOM1[i]>.00001){
   int part=int(round(CUSTOM0[i]));
   vec3 a=mix(deform(part,row,source),deform(part,next,source),t);
   vec3 b=mix(deform(part,moving,source),deform(part,moving_next,source),mt);
   p+=mix(a,b,strength)*CUSTOM1[i];
   float alpha=mix(texelFetch(pose_texture,ivec2(part*6+3,row),0).w,texelFetch(pose_texture,ivec2(part*6+3,next),0).w,t);
   float move_alpha=mix(texelFetch(pose_texture,ivec2(part*6+3,moving),0).w,texelFetch(pose_texture,ivec2(part*6+3,moving_next),0).w,mt);
   opacity+=mix(alpha,move_alpha,strength)*CUSTOM1[i];
  }
 }
 if(CUSTOM2.w>.5){mat3 local=mat3(inverse(MODEL_MATRIX))*mat3(INV_VIEW_MATRIX);vec3 up=CUSTOM2.w>1.5?vec3(0,1,0):local[1];p+=local[0]*CUSTOM3.x+up*CUSTOM3.y;}
 VERTEX=p*model_scale;material_row=UV2.x;flash=INSTANCE_CUSTOM.w;frozen=floor(INSTANCE_CUSTOM.z*.5);
}
void fragment(){
 vec4 color=texelFetch(surface_properties,ivec2(2,int(round(material_row))),0);if(textured)color*=texture(albedo_texture,UV);
 ALBEDO=mix(color.rgb,vec3(.35,.75,1.0),frozen*.55)+vec3(1,.17,.06)*min(1.0,flash*24.0);
 ALPHA=color.a*opacity;
 if(!glow)ALPHA_SCISSOR_THRESHOLD=.1;
}
