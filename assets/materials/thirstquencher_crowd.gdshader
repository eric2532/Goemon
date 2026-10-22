shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D pose_texture : filter_nearest, repeat_disable;
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable;
uniform bool textured=false;
uniform bool use_tint_palette=false;
uniform sampler2D tint_palette : filter_nearest, repeat_disable;
uniform vec4 tint_color : source_color=vec4(1.0);
uniform bool compensate_filmic=false;
uniform float scene_exposure=1.0;
uniform float scene_white=1.0;
varying float frozen_tint;
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
 vec4 x=texelFetch(pose_texture,ivec2(part*3,row),0);
 vec4 y=texelFetch(pose_texture,ivec2(part*3+1,row),0);
 vec4 z=texelFetch(pose_texture,ivec2(part*3+2,row),0);
 mat3 rigid=mat3(x.xyz,y.xyz,z.xyz);
 VERTEX=rigid*VERTEX+vec3(x.w,y.w,z.w);NORMAL=normalize(rigid*NORMAL);
 frozen_tint=INSTANCE_CUSTOM.y;surface_row=UV2.y;
}
void fragment(){
 vec4 tint=use_tint_palette?texelFetch(tint_palette,ivec2(0,int(round(surface_row))),0):tint_color;
 vec4 paint=COLOR*tint;
 if(textured){paint*=texture(albedo_texture,UV);}else{paint.rgb=display_to_linear(paint.rgb);}
 if(paint.a<0.5)discard;
 paint.rgb=mix(paint.rgb,vec3(.35,.75,1.0),frozen_tint*.55);
 ALBEDO=compensate_filmic?inverse_filmic(paint.rgb):paint.rgb;
}
