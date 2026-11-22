shader_type spatial;
render_mode cull_disabled;

uniform sampler2D layout_mask : filter_linear, repeat_disable;
uniform vec4 bounds;
uniform bool island=false;
uniform bool extend_shore=false;
uniform float map_scale=1.0;
#include "res://scripts/forest/freyja_surface.gdshaderinc"
varying vec2 world_xz;

void vertex() {
 world_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
}

void fragment() {
 if(adjoining_city_clipped(world_xz/map_scale))discard;
 vec2 source_point=(map_frame*vec4(world_xz.x/map_scale,0.0,world_xz.y/map_scale,1.0)).xz*map_scale;
 vec2 uv=(source_point-bounds.xy)/bounds.zw;
 if(extend_shore && uv.y<0.0) discard;
 vec4 paint=texture(layout_mask,uv);
 if(extend_shore){
  vec2 beyond=(uv-clamp(uv,0.0,1.0))*bounds.zw;
  float distance_=length(beyond);
  if(distance_>0.0){
   float shore_width=10.0+7.0*sin(world_xz.x*.07+world_xz.y*.09);
   paint=mix(paint,vec4(1.0),smoothstep(0.0,shore_width,distance_));
  }
 }
 if(island){
  ivec2 size_=textureSize(layout_mask,0);
  ivec2 cell=ivec2(floor(uv*vec2(size_)));
  if(all(greaterThanEqual(cell,ivec2(0))) && all(lessThan(cell,size_))){
   vec4 source=texelFetch(layout_mask,cell,0);
   if(source.a>.44 && source.r<.54) discard;
  }
  paint=vec4(1.0);
 }
 if(paint.r<0.54 || paint.a<0.44) discard;
 vec2 p=world_xz;
 float swell=sin(p.x*.19+p.y*.32+TIME*.62);
 float strokes=sin(p.x*.82-p.y*.33+swell*1.65+TIME*.94);
 float flecks=sin(p.y*1.42+p.x*.47+TIME*.31);
 float shallow=1.0-smoothstep(.68,.99,paint.r*paint.a);
 float foam=(1.0-smoothstep(.63,.82,paint.r))*smoothstep(-.65,.65,flecks)*.31;
 vec3 deep=vec3(.025,.135,.23);
 vec3 shore=vec3(.062,.32,.36);
 if(island){
  deep=vec3(.023,.172,.287);
  shore=vec3(.053,.29,.36);
 }
 float ripple=island?.42:1.0;
 vec3 water=mix(deep,shore,shallow*.84)+vec3(.018,.035,.047)*(swell*.45+strokes*.55)*ripple;
 water=mix(water,vec3(.39,.64,.64),foam+smoothstep(.86,1.0,strokes)*smoothstep(.22,.92,flecks)*.12*ripple);
 vec4 archive=freyja_surface(source_point/map_scale,true);
 water=mix(water,archive.rgb*(.91+swell*.035+strokes*.035),archive.a*.89);
 ALBEDO=water;
 ROUGHNESS=.54;
 SPECULAR=.38;
 EMISSION=water*.09;
}
