shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_nearest;
uniform float clock=0.0;
uniform int species=0;
uniform bool neon_style=false;
varying vec4 actor_data;
mat3 rotate_x(float a){float c=cos(a);float s=sin(a);return mat3(vec3(1,0,0),vec3(0,c,s),vec3(0,-s,c));}
void vertex(){
 actor_data=INSTANCE_CUSTOM;
 float limb=round(UV2.x*8.0);
 float motion=INSTANCE_CUSTOM.y;
 float phase=clock*7.0+INSTANCE_CUSTOM.x;
 float attack=INSTANCE_CUSTOM.z;
 if(INSTANCE_CUSTOM.w>0.5){phase=INSTANCE_CUSTOM.x;motion=0.0;attack=0.0;}
 vec3 pivot=vec3(0);float swing=0.0;
 if(limb==1.0||limb==2.0){pivot=vec3(limb==1.0?-0.25:0.25,0.91,0);swing=sin(phase+(limb==2.0?3.14159:0.0))*0.6*motion;}
 if(limb==3.0||limb==4.0){pivot=vec3(limb==3.0?-0.34:0.34,1.43,0);swing=-sin(phase+(limb==4.0?3.14159:0.0))*0.45*motion-attack*1.6;}
 if(species==2){if(limb==1.0||limb==2.0){pivot=vec3(limb==1.0?-0.33:0.33,0.2,0);swing*=0.3;}else if(limb==3.0||limb==4.0){pivot=vec3(limb==3.0?-0.55:0.55,0.9,0);}}
 if(species==3){swing=0.0;}
 mat3 turn=rotate_x(swing);VERTEX=pivot+turn*(VERTEX-pivot);NORMAL=turn*NORMAL;
 if(species==3){VERTEX.y+=abs(sin(phase))*0.25*motion;}
 else if(species==2){VERTEX.x+=sin(phase)*0.07*motion;VERTEX.y+=abs(sin(phase))*0.035*motion;}
 else {VERTEX.y+=abs(sin(phase))*0.045*motion;}
 // Windup leans back; strike leans forward, retaining existing gameplay timing.
 mat3 lean=rotate_x(attack*0.18);VERTEX=lean*VERTEX;NORMAL=lean*NORMAL;
}
void fragment(){
 ALBEDO=texture(atlas,UV).rgb;ROUGHNESS=0.95;
 if(neon_style){
  ivec2 tile=ivec2(floor(UV*4.0));
  // glTF exports texture V downward; these are the cyan, magenta and amber rows.
  bool luminous=(tile.x==1&&(tile.y==0||tile.y==2))||(tile.x==3&&tile.y==3);
  EMISSION=luminous?ALBEDO*1.25:vec3(0.0);ROUGHNESS=.72;
 }
 if(actor_data.w>0.5){ALBEDO=mix(ALBEDO,vec3(0.35,0.8,1.0),0.7);}
}
