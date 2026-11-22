shader_type spatial;
render_mode cull_disabled;
uniform sampler2D pose_texture : filter_nearest, repeat_disable;
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable;
uniform bool textured=false;
uniform bool finale=false;
uniform sampler2D sword_morph : filter_nearest, repeat_disable;
uniform int effect_pose_start=-1;
uniform int effect_pose_count=1;
varying float finale_mode;
varying float finale_discard;
uniform float enemy_size=1.0;
uniform float role_size=1.0;
uniform bool use_tint_palette=false;
uniform sampler2D tint_palette : filter_nearest, repeat_disable;
uniform vec4 tint_color : source_color=vec4(1.0);
uniform bool compensate_filmic=false;
uniform float scene_exposure=1.0;
uniform float scene_white=1.0;
varying float frozen_tint;
varying vec3 ice_position;
#include "enemy_ice_surface.gdshaderinc"
varying float hit_flash;
varying float surface_row;
float filmic_white(float x){return (x*(0.88*x+0.06)+0.002)/(x*(0.88*x+0.60)+0.06)-1.0/30.0;}
vec3 inverse_filmic(vec3 desired){
 vec3 k=clamp(desired,vec3(0.0),vec3(1.0))*filmic_white(max(scene_white,0.001))+vec3(1.0/30.0);
 vec3 a=0.88*(vec3(1.0)-k);vec3 b=0.60*(vec3(0.10)-k);vec3 c=0.20*(vec3(0.01)-0.30*k);
 return max(vec3(0.0),(-b+sqrt(max(vec3(0.0),b*b-4.0*a*c)))/(2.0*a))/max(scene_exposure,0.001);
}
vec3 display_to_linear(vec3 c){return mix(c/12.92,pow((c+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),c));}
void vertex(){
 int part=int(round(UV2.x));int row=int(round(INSTANCE_CUSTOM.x));
 if(effect_pose_start>=0)row=effect_pose_start+clamp(int(floor(INSTANCE_CUSTOM.x*30.0)),0,effect_pose_count-1);
 finale_mode=INSTANCE_CUSTOM.z;finale_discard=0.0;
 if(finale){
  bool armed=int(round(finale_mode))==7;
  if((part==17&&!armed)||(armed&&(part==11||part==12||part==13)))finale_discard=1.0;
  if(part==17){
   int vertex=int(round(fract(UV2.x)*10000.0));
   VERTEX=mix(texelFetch(sword_morph,ivec2(vertex,0),0).xyz,texelFetch(sword_morph,ivec2(vertex,1),0).xyz,clamp(fract(finale_mode)*10.0,0.0,1.0));
   part=11;
  }
 }
 vec4 x=texelFetch(pose_texture,ivec2(part*3,row),0);
 vec4 y=texelFetch(pose_texture,ivec2(part*3+1,row),0);
 vec4 z=texelFetch(pose_texture,ivec2(part*3+2,row),0);
 mat3 rigid=mat3(x.xyz,y.xyz,z.xyz);
 VERTEX=(rigid*VERTEX+vec3(x.w,y.w,z.w))*enemy_size*role_size;NORMAL=normalize(rigid*NORMAL);
 ice_position=VERTEX;
 frozen_tint=effect_pose_start>=0?0.0:INSTANCE_CUSTOM.y;hit_flash=frozen_tint>=0.99?0.0:INSTANCE_CUSTOM.w;surface_row=UV2.y;
}
void fragment(){
 if(finale_discard>0.5)discard;
 vec4 tint=use_tint_palette?texelFetch(tint_palette,ivec2(0,int(round(surface_row))),0):tint_color;
 vec4 paint=COLOR*tint;
 if(textured){paint*=texture(albedo_texture,UV);}else{paint.rgb=display_to_linear(paint.rgb);}
 if(paint.a<0.5)discard;
 if(finale){
  int mode=int(round(finale_mode));vec3 light=vec3(.25,.25,.5);
  if(mode==1||mode==7)light=vec3(.5,0,.75);
  else if(mode==2)light=vec3(0,.75,0);
  else if(mode==3)light=vec3(0,0,1);
  else if(mode==4)light=vec3(1,.125,0);
  else if(mode==5)light=vec3(.5,.25,0);
  else if(mode==6)light=vec3(.125,.25,1);
  paint.rgb=pow(max(paint.rgb,vec3(0.0)),vec3(1.15))*(vec3(.12)+light*1.25);
 }
 paint.rgb=enemy_ice_surface(paint.rgb,ice_position,NORMAL,VIEW,frozen_tint);
 ALBEDO=compensate_filmic&&!finale?inverse_filmic(paint.rgb):paint.rgb;
 ROUGHNESS=mix(0.65,0.23,abs(frozen_tint));SPECULAR=0.25;
 EMISSION=vec3(1.0,.17,.06)*min(1.0,hit_flash*24.0)*1.4;
 if(finale){
  float rim=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),3.0);
  EMISSION+=paint.rgb*rim*.45;ROUGHNESS=.42;SPECULAR=.45;
 }
}
