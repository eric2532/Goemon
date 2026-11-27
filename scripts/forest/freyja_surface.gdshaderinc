uniform bool use_freyja_surface=false;
uniform mat4 map_frame=mat4(1.0);
uniform vec4 adjoining_city_bounds=vec4(0.0);
uniform float adjoining_city_end=-100000.0;
uniform bool adjoining_city_layer=false;
uniform bool use_adjoining_source_repair=false;
uniform sampler2D adjoining_source_repair : filter_nearest, repeat_disable;
uniform vec4 adjoining_source_bounds=vec4(0.0);

bool adjoining_city_clipped(vec2 point){
 if(adjoining_city_bounds.z<=0.0)return false;
 bool inside=all(greaterThanEqual(point,adjoining_city_bounds.xy)) && all(lessThan(point,adjoining_city_bounds.xy+adjoining_city_bounds.zw)) && point.y<adjoining_city_end;
 if(inside && use_adjoining_source_repair){
  vec2 uv=(point-adjoining_source_bounds.xy)/adjoining_source_bounds.zw;
  if(all(greaterThanEqual(uv,vec2(0.0))) && all(lessThan(uv,vec2(1.0))) && texture(adjoining_source_repair,uv).a>.5)inside=false;
 }
 return adjoining_city_layer ? !inside : inside;
}
uniform vec4 freyja_frame=vec4(0.0);
uniform float freyja_surface_start=-100000.0;
uniform sampler2D freyja_ground_index : filter_nearest, repeat_disable;
uniform sampler2DArray freyja_ground_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 freyja_grass_tile=vec4(0.0);
uniform bool use_connected_village=false;
uniform vec4 connected_village_frame=vec4(0.0);
uniform sampler2D connected_village_mask : filter_nearest, repeat_disable;
uniform sampler2D connected_village_index : filter_nearest, repeat_disable;
uniform sampler2DArray connected_village_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 connected_village_grass=vec4(0.0);

vec4 freyja_tile(vec2 grid,vec4 tile,bool water,sampler2DArray atlas_texture) {
 if(tile.a<.5 || (tile.b>.5)!=water) return vec4(0.0);
 vec2 square=vec2(fract(grid.y),1.0-fract(grid.x));
 vec2 cell=floor(tile.rg*255.0+.5);
 vec3 uv=vec3((.5+square*31.0)/32.0,cell.x+cell.y*32.0);
 vec2 axes=vec2(grid.y,-grid.x);
 return vec4(textureGrad(atlas_texture,uv,dFdx(axes)*31.0/32.0,dFdy(axes)*31.0/32.0).rgb,1.0);
}

vec4 freyja_surface(vec2 point,bool water) {
 if(!use_freyja_surface) return vec4(0.0);
 if(use_connected_village){
  vec2 basis=connected_village_frame.zw;
  vec2 grid=(connected_village_frame.xy+point.x*basis+point.y*vec2(-basis.y,basis.x))/3.0+vec2(.5);
  vec2 size_=vec2(textureSize(connected_village_mask,0));
  if(all(greaterThanEqual(grid,vec2(0.0))) && all(lessThan(grid,size_))){
   vec4 mask=texture(connected_village_mask,grid/size_);
   if(mask.a>.5 && mask.r<.5){
    vec4 tile=texture(connected_village_index,grid/size_);
    if(tile.a<.5) tile=connected_village_grass;
    return freyja_tile(grid,tile,water,connected_village_atlas);
   }
  }
 }
 if(point.y<freyja_surface_start && abs(point.x-3.0)<18.0) return vec4(0.0);
 vec2 basis=freyja_frame.zw;
 vec2 source=(freyja_frame.xy+point.x*basis+point.y*vec2(-basis.y,basis.x))/3.0;
 vec2 grid=source+vec2(.5);
 vec2 size_=vec2(textureSize(freyja_ground_index,0));
 if(any(lessThan(grid,vec2(0.0))) || any(greaterThanEqual(grid,size_))) return vec4(0.0);
 vec4 tile=texture(freyja_ground_index,grid/size_);
 if(tile.a<.5) tile=freyja_grass_tile;
 return freyja_tile(grid,tile,water,freyja_ground_atlas);
}
