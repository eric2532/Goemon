shader_type spatial;
render_mode cull_disabled;
uniform bool tree = false;
uniform float strength = .12;
uniform bool canopy = false;
uniform bool canopy_cutaway = false;
uniform vec2 hero_position = vec2(0.0);
uniform vec3 foliage_tint = vec3(1.0);
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform float snow_breakup : hint_range(0.0, 1.0) = 0.0;
uniform bool use_source_paint = false;
uniform bool source_cutout = false;
uniform sampler2D source_paint : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 tint;
varying vec3 world;
void vertex(){
 vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
 float height=tree ? max(0.0,VERTEX.y-2.8)*.24 : max(0.0,VERTEX.y);
 float wave=sin(TIME*1.7+origin.x*.37+origin.z*.23)+.35*sin(TIME*2.8+origin.z*.7);
 VERTEX.x+=wave*strength*height*height;
 VERTEX.z+=cos(TIME*1.1+origin.x*.22)*strength*height*.4;
 if(!tree){VERTEX*=1.0-smoothstep(28.0,46.0,distance(origin.xz,CAMERA_POSITION_WORLD.xz));}
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 tint=COLOR.rgb*foliage_tint;
}
void fragment(){
 if(canopy && canopy_cutaway && distance(world.xz,hero_position)<10.0){discard;}
 vec4 source=use_source_paint ? texture(source_paint,UV) : vec4(1.0);
 if(source_cutout && source.a<.5){discard;}
 vec3 paint=tint*source.rgb;
 if(snow_amount>0.0){
  vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
  float dapple=.18*sin(world.x*4.8+world.y*3.2)+.17*sin(world.z*6.5-world.y*4.7);
  float cover=smoothstep(.46,.72,abs(dot(NORMAL,up))+dapple+(snow_amount-.5)*.52);
  cover*=smoothstep(.8,2.8,world.y);
  if(snow_breakup>0.0){
   float clumps=sin(world.x*2.0+world.y*.65)+.67*cos(world.z*1.82-world.y*1.1);
   cover*=mix(1.0,smoothstep(-.48,.53,clumps),snow_breakup);
  }
  paint=mix(paint,vec3(.62,.76,.86),cover*.90);
 }
 ALBEDO=paint; ROUGHNESS=1.0; EMISSION=paint*.075;
}
void light(){
 float wrapped=clamp((dot(NORMAL,LIGHT)+.45)/1.45,0.0,1.0);
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*(.2+.8*smoothstep(.05,.9,wrapped))/3.14159265;
}
