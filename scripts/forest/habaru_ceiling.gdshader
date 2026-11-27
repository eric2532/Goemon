shader_type spatial;
#include "res://scripts/forest/forest_archive_palette.gdshaderinc"
#include "res://scripts/forest/forest_route_finish.gdshaderinc"
render_mode cull_disabled, shadows_disabled;

uniform sampler2D rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D archive_rock : source_color, filter_linear;
uniform sampler2D wall_faces : source_color, filter_linear, repeat_disable;
uniform int rock_family = -1;
uniform bool is_roof = true;
uniform bool has_wall_faces = false;
uniform bool original_palette = false;
uniform bool crag_surface = false;
// Opt-in visual cutaway reuses the arena roof rule; the physical slab is untouched.
uniform float roof_camera_cutaway_margin = -1.0;
varying vec3 rock_point;
varying vec3 rock_normal;
varying float surface_height;

void vertex() {
 rock_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 rock_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 surface_height=VERTEX.y;
}

vec3 archive_stone(vec2 point,float variant) {
 vec2 cell=vec2(float(rock_family)*.25,variant*.5);
 vec2 uv=cell+vec2(.002)+fract(point)*vec2(.246,.496);
 return texture(archive_rock,uv).rgb;
}

vec3 rock_pattern(vec2 point) {
 vec2 turned=mat2(vec2(.81,.59),vec2(-.59,.81))*point;
 float blend=.53+.17*sin(point.x*2.1+sin(point.y*2.6)*1.6);
 return mix(archive_stone(point,0.0),archive_stone(turned*.83+vec2(.21,.37),1.0),blend);
}

void fragment() {
 if(is_roof && roof_camera_cutaway_margin>=0.0 && CAMERA_POSITION_WORLD.y>rock_point.y-roof_camera_cutaway_margin && INV_VIEW_MATRIX[2].y>.05) discard;
 if(rock_family<0) {
  vec3 fine=texture(rock,rock_point.xz*.29).rgb;
  vec3 coarse=texture(rock,rock_point.xz*.071).rgb;
  ALBEDO=vec3(.26,.23,.18)*(.57+dot(mix(fine,coarse,.65),vec3(.299,.587,.114))*1.16);
 } else {
  vec3 weights=pow(abs(normalize(rock_normal)),vec3(4.0));
  weights/=max(.001,weights.x+weights.y+weights.z);
  vec3 scale=crag_surface && !has_wall_faces && !is_roof ? vec3(.48,.32,.48) : vec3(.26,.16,.26);
  vec3 p=rock_point*scale+sin(rock_point.yzx*.47+rock_point.zxy*.34)*.15;
  vec3 paint=rock_pattern(p.zy)*weights.x+rock_pattern(p.xz)*weights.y+rock_pattern(p.xy)*weights.z;
  if(has_wall_faces) {
   vec4 face=texture(wall_faces,UV);
   float edge=fract(UV.x*16.0);
   float join=smoothstep(.07,.19,min(edge,1.0-edge));
   paint=mix(paint,face.rgb,face.a*join*.84*(1.0-.50*smoothstep(6.8,9.2,surface_height)));
  }
  float shade=.84+.16*sin(rock_point.x*.34+rock_point.z*.21+sin(rock_point.y*.66));
  float dim=is_roof?.60:mix(.62,.87,smoothstep(0.0,3.0,surface_height));
  if(is_roof && !original_palette) {
   vec3 weathered=texture(rock,rock_point.xz*.09).rgb;
   paint=mix(paint,weathered*vec3(.48,.45,.41),.30);
  }
  ALBEDO=paint*dim*shade;
  EMISSION=paint*.075;
  if(original_palette) {
   vec4 face=texture(wall_faces,UV);
   vec3 source=has_wall_faces && face.a>.5 && UV!=vec2(0.0) ? face.rgb : paint;
   if(crag_surface) {
    if(is_roof) source=vec3(.025,.024,.020)+paint*.075;
    else if(has_wall_faces) source=vec3(.018,.017,.014)+paint*.04;
    else source=paint*(.68+.32*max(0.0,dot(normalize(rock_normal),normalize(vec3(-.4,.8,.3)))));
   }
   ALBEDO=vec3(0.0);
   EMISSION=archive_color(source);
  }
 }
 float finish=route_weight(rock_point);
 if(finish>0.0){
  float mass=.92+.08*sin(rock_point.x*.11+rock_point.z*.13+sin(rock_point.y*.17));
  vec3 paint=archive_color(route_tint*mass*(is_roof ? .24 : .88+.12*max(0.0,rock_normal.y)));
  if(original_palette)EMISSION=mix(EMISSION,paint,finish);
  else ALBEDO=mix(ALBEDO,paint,finish);
 }
 ROUGHNESS=1.0;
 SPECULAR=original_palette ? 0.0 : .5;
}
