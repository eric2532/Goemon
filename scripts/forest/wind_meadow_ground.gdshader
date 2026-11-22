shader_type spatial;
uniform sampler2D roads : filter_linear, repeat_disable;
uniform sampler2D detail_mask : filter_linear, repeat_disable;
uniform vec4 tomato_plot;
uniform bool use_mountain_surface=false;
uniform vec4 detail_bounds=vec4(0.0);
uniform bool use_courtyard_paving=false;
uniform bool clip_archive_land=false;
uniform bool use_coastal_sand=false;
uniform bool use_ghana_palette=false;
uniform sampler2D courtyard_paving : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool use_city_paving=false;
uniform vec4 city_paving_bounds=vec4(0.0);
uniform vec4 city_gate_frame=vec4(0.0);
uniform float city_gate_paving_end=54.0;
uniform sampler2D city_paving_index : filter_nearest, repeat_disable;
uniform sampler2D city_paving_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D cliff : source_color, filter_linear_mipmap, repeat_enable;
uniform bool show_grid=false;
#include "res://scripts/forest/attack_range.gdshaderinc"
#include "res://scripts/forest/castle_stone.gdshaderinc"
#include "res://scripts/forest/freyja_surface.gdshaderinc"
uniform float castle_half_size=0.0;
uniform vec2 castle_stairs=vec2(0.0);
uniform bool arena_floor=false;
uniform vec4 arena_inlay_cutouts[5];
uniform float map_extent=240.0;
uniform float map_scale=1.0;
uniform bool clip_village=false;
uniform vec4 village_bounds=vec4(0.0);
varying vec3 world;
varying vec3 normal_world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;normal_world=(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 if(arena_floor){
  for(int i=0;i<5;i++){
   vec4 patch=arena_inlay_cutouts[i];
   if(patch.z>0.0 && max(abs(world.x-patch.x),abs(world.z-patch.y))<patch.z) discard;
  }
 }
 vec3 map_pos=world/map_scale;
 if(adjoining_city_clipped(map_pos.xz))discard;
 map_pos=(map_frame*vec4(map_pos,1.0)).xyz;
 if(clip_village && (any(lessThan(map_pos.xz,village_bounds.xy)) || any(greaterThanEqual(map_pos.xz,village_bounds.zw)))) discard;
 float patch=sin(map_pos.x*.031+sin(map_pos.z*.043)*1.8)*.5+.5;
 float brush=sin(map_pos.x*1.8+sin(map_pos.z*2.7)*2.0)*sin(map_pos.z*3.1)*.009;
 vec3 grass=mix(vec3(.15,.28,.055),vec3(.29,.43,.10),patch)+brush;
 float detail=1.0-smoothstep(.2,.7,max(length(dFdx(map_pos.xz)),length(dFdy(map_pos.xz))));
 float strokes=smoothstep(.6,.95,sin(map_pos.x*17.0+sin(map_pos.z*4.0)*2.0))*smoothstep(0.0,.8,sin(map_pos.z*8.0+map_pos.x*1.7));
 grass*=1.0+strokes*.12*detail;
 float path=use_mountain_surface?0.0:texture(roads,(map_pos.xz+map_extent)/(map_extent*2.0)).r;
 vec3 earth=mix(vec3(.32,.28,.17),vec3(.46,.41,.26),patch);
 vec4 detail_paint=vec4(0.0);
 vec4 courtyard=vec4(0.0);
 if(detail_bounds.z>0.0){
  vec2 detail_uv=(map_pos.xz-detail_bounds.xy)/detail_bounds.zw;
  if(all(greaterThanEqual(detail_uv,vec2(0.0))) && all(lessThanEqual(detail_uv,vec2(1.0)))){
   detail_paint=texture(detail_mask,detail_uv);
   if(use_courtyard_paving) courtyard=texture(courtyard_paving,detail_uv);
   path=mix(path,detail_paint.g,detail_paint.a);
  }
 }
 if((use_courtyard_paving || clip_archive_land) && (detail_paint.a<.44 || detail_paint.r>.54)) discard;
 bool gate_paving=dot(city_gate_frame.zw,city_gate_frame.zw)>0.0;
 if(use_city_paving && (!gate_paving || map_pos.z<=city_gate_paving_end)){
  vec2 gate_basis=city_gate_frame.zw;
  vec2 city_point=gate_paving ? city_gate_frame.xy+map_pos.x*gate_basis+map_pos.z*vec2(-gate_basis.y,gate_basis.x) : map_pos.xz;
  vec2 city_uv=(city_point-city_paving_bounds.xy)/city_paving_bounds.zw;
  if(all(greaterThanEqual(city_uv,vec2(0.0))) && all(lessThanEqual(city_uv,vec2(1.0)))){
   vec2 grid=city_uv*vec2(textureSize(city_paving_index,0));
   vec4 tile=texture(city_paving_index,city_uv);
   vec2 atlas=vec2(textureSize(city_paving_atlas,0));
   vec2 uv=(floor(tile.rg*255.0+.5)*36.0+2.5+fract(grid)*31.0)/atlas;
   float gate_blend=gate_paving ? detail_paint.a*(1.0-smoothstep(city_gate_paving_end-7.0,city_gate_paving_end,map_pos.z)) : 1.0;
   courtyard=vec4(textureGrad(city_paving_atlas,uv,dFdx(grid)*31.0/atlas,dFdy(grid)*31.0/atlas).rgb,tile.a*gate_blend);
  }
 }
 float rock=smoothstep(.24,.65,1.0-normalize(normal_world).y);
 vec3 weights=pow(abs(normalize(normal_world)),vec3(4.0));weights/=weights.x+weights.y+weights.z;
 vec3 stone=(texture(cliff,map_pos.zy*.045).rgb*weights.x+texture(cliff,map_pos.xz*.045).rgb*weights.y+texture(cliff,map_pos.xy*.045).rgb*weights.z)*vec3(.78,.88,.92);
 if(use_ghana_palette && detail_paint.a>.5){
  rock=max(rock,smoothstep(.85,.99,detail_paint.b));
  stone=vec3(.40,.27,.16)*(.65+dot(stone,vec3(.33))*1.6);
 }
 vec2 extent=abs(map_pos.xz);
 bool fort=max(extent.x,extent.y)<castle_half_size+3.0 || (min(extent.x,extent.y)<castle_stairs.x && max(extent.x,extent.y)<castle_stairs.y);
 if(castle_half_size>0.0 && fort && rock>0.0) stone=castle_stone(map_pos,normal_world);
 ALBEDO=mix(mix(grass,earth,path*.9),stone,rock);
 bool cabin_plot=all(greaterThan(map_pos.xz,tomato_plot.xy)) && all(lessThan(map_pos.xz,tomato_plot.zw));
 if(cabin_plot || (use_mountain_surface && detail_paint.b>.42)){
  float furrow=smoothstep(-.8,.8,sin(map_pos.z*TAU*2.0/3.0));
  ALBEDO=mix(vec3(.22,.125,.064),vec3(.36,.215,.105),furrow*.7+brush*5.0);
 }
 if(!use_mountain_surface && detail_paint.b*detail_paint.a>0.0){
  vec3 paving=use_coastal_sand ? mix(vec3(.53,.37,.20),vec3(.38,.27,.15),smoothstep(.12,.68,detail_paint.g))*(.93+brush*2.0)
   : castle_stone(map_pos,vec3(0.0,1.0,0.0))*mix(.63,1.04,smoothstep(.47,.9,detail_paint.b));
  if(use_ghana_palette) paving=mix(vec3(.41,.27,.13),vec3(.68,.51,.31),smoothstep(.12,.68,detail_paint.g))*(.94+patch*.10+brush*3.0);
  ALBEDO=mix(ALBEDO,paving,smoothstep(.08,.48,detail_paint.b)*detail_paint.a*(1.0-rock));
 }
 ALBEDO=mix(ALBEDO,courtyard.rgb*(.92+brush*6.0),courtyard.a*(1.0-rock));
 vec4 archive=freyja_surface(map_pos.xz,false);
 if(!cabin_plot) ALBEDO=mix(ALBEDO,archive.rgb*(.97+brush*3.0),archive.a*(1.0-rock)*.91);
 if(arena_floor && courtyard.a<.5) ALBEDO=castle_stone(map_pos,normal_world);
 if(arena_floor) ALBEDO=mix(ALBEDO,castle_stone(map_pos,normal_world),smoothstep(.002,.015,1.0-normalize(normal_world).y));
 if(show_grid){vec2 grid=abs(fract((map_pos.xz+3.0)/6.0)-.5);ALBEDO*=1.0-.13*max(smoothstep(.48,.5,grid.x),smoothstep(.48,.5,grid.y));}
 ALBEDO=attack_range_ink(ALBEDO,world,normal_world);
 ROUGHNESS=1.0;
}
