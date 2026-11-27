shader_type spatial;
#include "res://scripts/forest/forest_archive_palette.gdshaderinc"
#include "res://scripts/forest/forest_route_finish.gdshaderinc"
render_mode cull_back;
uniform vec4 base_color : source_color = vec4(.4,.25,.12,1);
uniform vec3 grain_axis = vec3(0,1,0);
// Wood, stone, slate, foliage, bark, imported painted art, mineral/metal.
uniform float surface_kind = 0.0;
uniform sampler2D brush_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_vertex_color = true;
uniform bool vertex_color_srgb = false;
uniform bool use_base_texture = false;
uniform bool archive_triplanar = false;
uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float atlas_tile_pixels = 0.0;
uniform bool architecture_roof = false;
uniform bool architecture_facade = false;
uniform bool falan_source_projection = false;
uniform sampler2D falan_source_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool falan_source_restore_uv = false;
uniform bool falan_source_contour = false;
uniform bool falan_source_visibility = false;
uniform sampler2D falan_source_depth : filter_nearest, repeat_disable;
uniform vec3 falan_source_depth_fit = vec3(0.0,1.0,.20);
uniform bool armor_source_views = false;
uniform bool armor_source_parts = false;
uniform sampler2D armor_source_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform mat4 armor_source_frame;
uniform vec4 armor_source_rects[4];
uniform vec2 armor_source_origins[4];
uniform sampler2D falan_source_mask : filter_linear_mipmap, repeat_disable;
uniform vec4 falan_source_fallback : source_color = vec4(.7,.65,.55,1.0);
uniform bool falan_source_local = false;
uniform mat4 falan_source_frame;
uniform vec4 falan_source_rect = vec4(0.0);
uniform vec4 falan_source_paint = vec4(0.0);
uniform bool alpha_cutout = false;
uniform bool cave_floor = false;
uniform bool inlay_carving = false;
uniform bool original_palette = false;
uniform bool use_brush_finish = true;
uniform float alpha_threshold = .5;
uniform float roof_cutaway_height = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_strength = 0.0;
uniform bool fog_enabled = false;
uniform sampler2D visibility_map : filter_linear, repeat_disable;
uniform vec2 hero_position = vec2(0.0);
uniform bool canopy_cutaway = false;
uniform bool canopy_layer = false;
uniform vec4 falan_roof_paint : source_color = vec4(0.0);
varying vec3 local_point;
varying vec3 local_normal;
varying vec3 world_point;
varying vec3 world_normal;
varying vec3 object_origin;
varying vec3 armor_camera;
varying vec3 source_camera;
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void vertex(){
 local_normal=NORMAL;local_point=VERTEX;world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);object_origin=(MODEL_MATRIX*vec4(0,0,0,1)).xyz;
 if(armor_source_views)armor_camera=(armor_source_frame*vec4(transpose(MODEL_NORMAL_MATRIX)*(CAMERA_POSITION_WORLD-object_origin),1.0)).xyz;
 if(falan_source_visibility)source_camera=(falan_source_frame*vec4(transpose(MODEL_NORMAL_MATRIX)*(CAMERA_POSITION_WORLD-object_origin),1.0)).xyz;
}
void fragment(){
 if(roof_cutaway_height>0.0 && CAMERA_POSITION_WORLD.y>roof_cutaway_height) discard;
 if(fog_enabled && canopy_layer && canopy_cutaway && distance(object_origin.xz,hero_position)<15.0) discard;
 // The generic shop awning is baked into the mesh. Archived storefronts have exposed timber portals.
 if(falan_roof_paint.a>0.0 && local_point.z>6.14 && local_point.y>3.83 && local_point.y<4.88) discard;
 if(falan_roof_paint.a>0.0 && local_point.z>7.40 && local_point.y>2.90 && local_point.y<3.84) discard;
 vec2 texture_uv=UV*uv_scale+uv_offset;
 bool source_valid=true;
 bool source_front=false;
 float source_weight=1.0;
 vec2 source_uv=vec2(0.0);
 if(archive_triplanar) {
  vec3 axes=abs(normalize(world_normal));
  texture_uv=(axes.y>max(axes.x,axes.z) ? world_point.xz : (axes.x>axes.z ? world_point.zy : world_point.xy))*uv_scale;
 }
 if(falan_source_projection){
  vec3 p=(falan_source_frame*vec4(falan_source_local ? local_point : world_point,1.0)).xyz;
  vec3 source_normal=normalize(mat3(falan_source_frame)*(falan_source_local ? local_normal : world_normal));
  // Only source-angle silhouette trimming depends on the camera; paint stays on the solid faces.
  if(falan_source_visibility)source_weight=smoothstep(.85,.98,dot(normalize(source_camera-p),normalize(vec3(1.0,1.603567,1.0))));
  source_front=dot(source_normal,vec3(1.0,1.603567,1.0))>=0.0;
  if(!falan_source_contour && source_normal.x+source_normal.z<-.001)source_front=false;
  vec2 pixel=vec2((p.x-p.z)*(32.0/3.0),(p.x+p.z)*8.0-p.y*sqrt(2.0*((32.0/3.0)*(32.0/3.0)-64.0)))-falan_source_rect.xy;
  source_uv=(falan_source_paint.xy+clamp(pixel,vec2(.5),falan_source_paint.zw-vec2(.5)))/vec2(textureSize(falan_source_texture,0));
  source_valid=all(greaterThanEqual(pixel,vec2(0.0))) && all(lessThan(pixel,falan_source_paint.zw)) && texture(falan_source_mask,source_uv).r>.5;
  if(falan_source_contour && source_front && !source_valid && source_weight>.99)discard;
  if(falan_source_visibility && source_front && source_valid){
   vec2 packed=texture(falan_source_depth,source_uv).rg;
   float captured=dot(packed,vec2(65280.0,255.0))/65535.0;
   float nearest=falan_source_depth_fit.x+captured*falan_source_depth_fit.y;
   float actual=dot(p,normalize(vec3(1.0,1.603567,1.0)));
   source_valid=captured>0.0 && actual>=nearest-falan_source_depth_fit.z && texture(falan_source_mask,source_uv).g>.5;
  }
 }
 vec4 tex=use_base_texture ? texture(base_texture,texture_uv) : vec4(1.0);
 if(use_base_texture && atlas_tile_pixels>0.0){
  vec2 atlas_size=vec2(textureSize(base_texture,0));
  vec2 span=vec2(atlas_tile_pixels-17.0)/atlas_size;
  texture_uv=(UV2+vec2(8.5))/atlas_size+fract(UV)*span;
  tex=textureGrad(base_texture,texture_uv,dFdx(UV)*span,dFdy(UV)*span);
 }
 if(architecture_roof){
  // Native luminance supplies wear without magnifying the palette's colored dithering.
  float wear=dot(tex.rgb,vec3(.2126,.7152,.0722));
  vec2 slate=vec2(UV.y/.58,UV.x/.34);
  slate.x+=mod(floor(slate.y),2.0)*.5;
  vec2 tile=fract(slate);
  vec2 aa=max(fwidth(slate),vec2(.001));
  float seam=1.0-smoothstep(.012,.030+aa.x,min(tile.x,1.0-tile.x));
  float overlap=1.0-smoothstep(.012,.055+aa.y,tile.y);
  float variation=hash(floor(slate));
  float patina=texture(brush_texture,local_point.xz*.11+local_point.yy*.025).g;
  float crown=sin(3.14159265*tile.x)*sin(3.14159265*tile.y);
  tex=vec4(vec3(.70+variation*.18+wear*.27+patina*.10+crown*.19-seam*.19-overlap*.24),1.0);
  float relief=crown*.045-overlap*.015;
  vec3 dx=dFdx(VERTEX);vec3 dy=dFdy(VERTEX);
  vec3 across=cross(dy,NORMAL);vec3 down=cross(NORMAL,dx);
  float determinant_=dot(dx,across);
  vec3 gradient=sign(determinant_)*(dFdx(relief)*across+dFdy(relief)*down)/max(abs(determinant_),.000001);
  NORMAL=normalize(NORMAL-gradient);
 }
 if(falan_source_projection){
  if(source_front)tex=source_valid ? texture(falan_source_texture,source_uv) : (falan_source_visibility && falan_source_restore_uv ? tex : falan_source_fallback);
  else if(!falan_source_restore_uv)tex=falan_source_fallback;
 }
 if(armor_source_views && (!armor_source_parts || COLOR.a>.5)){
  int facing=armor_camera.x<0.0 ? (armor_camera.z>=0.0 ? 0 : 1) : (armor_camera.z>=0.0 ? 2 : 3);
  vec3 p=(armor_source_frame*vec4(local_point,1.0)).xyz;
  if(facing==1)p=vec3(p.z,p.y,-p.x);
  else if(facing==2)p=vec3(-p.z,p.y,p.x);
  else if(facing==3)p=vec3(-p.x,p.y,-p.z);
  vec4 rect=armor_source_rects[facing];
  vec2 pixel=vec2((p.x+p.z)*(32.0/3.0),(p.z-p.x)*8.0-p.y*sqrt(2.0*((32.0/3.0)*(32.0/3.0)-64.0)))-armor_source_origins[facing];
  tex=texture(armor_source_texture,(rect.xy+clamp(pixel,vec2(.5),rect.zw-vec2(.5)))/vec2(textureSize(armor_source_texture,0)));
 }
 if(alpha_cutout && tex.a*base_color.a<alpha_threshold)tex=vec4(COLOR.rgb,1.0);
 vec3 vertex_color=use_vertex_color ? COLOR.rgb : vec3(1.0);
 if(vertex_color_srgb) vertex_color=pow(vertex_color,vec3(2.2));
 vec3 color=base_color.rgb*tex.rgb*vertex_color;
 if(architecture_facade && COLOR.a>.5){
  vec2 plane=abs(local_normal.x)>abs(local_normal.z) ? local_point.zy : local_point.xy;
  vec2 brick=plane/vec2(1.05,.58);
  brick.x+=mod(floor(brick.y),2.0)*.5;
  vec2 cell=fract(brick);vec2 edge=min(cell,1.0-cell);
  float aa=max(fwidth(brick.x),fwidth(brick.y));
  float joint=1.0-smoothstep(.014,.035+aa,min(edge.x,edge.y));
  float bevel=(1.0-smoothstep(.04,.12+aa,min(edge.x,edge.y)))*(1.0-joint);
  color*=.94+hash(floor(brick))*.12+bevel*.08-joint*.25;
 }
 vec3 normal=abs(normalize(world_normal));
 if(falan_roof_paint.a>0.0 && local_point.y>7.8
    && vertex_color.b>vertex_color.r*1.45 && vertex_color.b>vertex_color.g*1.43){
  color=falan_roof_paint.rgb*(.50+vertex_color.b*2.5);
  if(normal.y>.18){
   vec2 grid=vec2(local_point.z/.61,local_point.y/.40);
   grid.x+=mod(floor(grid.y),2.0)*.5;
   vec2 tile=fract(grid);
   float mortar=(1.0-smoothstep(.02,.11,min(min(tile.x,1.0-tile.x),tile.y)));
   color*=.87+hash(floor(grid))*.23-mortar*.20;
  }
 }
 vec2 plane=normal.y>max(normal.x,normal.z) ? world_point.xz : (normal.x>normal.z ? world_point.zy : world_point.xy);
 float brush=dot(texture(brush_texture,plane/6.0).rgb,vec3(.2126,.7152,.0722));
 float stroke=floor(smoothstep(.025,.28,brush)*5.0)/5.0;
 if(use_brush_finish)color*=.80+stroke*.38;
 float along=dot(local_point,grain_axis);
 vec3 across=local_point-grain_axis*along;
 if(surface_kind<.5 || (surface_kind>3.5 && surface_kind<4.5)){
  float grain=sin((across.x+across.y+across.z)*22.0+sin(along*.9)*1.5);
  color*=.90+smoothstep(-.8,.2,grain)*.14;
  float moss=(1.0-smoothstep(.2,1.9,world_point.y))*.28;
  color=mix(color,vec3(.07,.12,.025),moss);
 }else if(surface_kind<2.5){
  vec2 size_=surface_kind<1.5 ? vec2(2.8,1.35) : vec2(1.45,.8);
  float row=floor(plane.y/size_.y);
  vec2 cell=fract(plane/size_+vec2(mod(row,2.0)*.5,0));
  vec2 seam=min(cell,1.0-cell);
  vec2 aa=fwidth(plane/size_);
  float edge=1.0-smoothstep(.012,.026+max(aa.x,aa.y),min(seam.x,seam.y));
  color*=1.0-edge*.22;
  float block=hash(floor(plane/size_+vec2(mod(row,2.0)*.5,0)));
  color*=.92+block*.16;
  color=mix(color,vec3(.09,.14,.055),smoothstep(.64,.9,brush)*.12);
 }else if(surface_kind<3.5){
  float tip=smoothstep(-2.0,3.6,local_point.y);
  color=mix(color,vec3(.16,.22,.055),.18+tip*.22);
  color*=.86+hash(object_origin.xz)*.26;
 }else if(surface_kind>4.5 && surface_kind<5.5){
  // Keep shrine markings and vertex colors; add a restrained painted finish.
  if(use_brush_finish)color*=.97+stroke*.07;
 }
 if(cave_floor){
  float grit=dot(texture(brush_texture,world_point.xz*.74).rgb,vec3(.2126,.7152,.0722));
  color*=.88+smoothstep(.07,.50,grit)*.22;
  color=mix(color,tex.rgb*.83,.30);
 }
 if(fog_enabled){
  vec2 sight=texture(visibility_map,(object_origin.xz/6.0+vec2(40.5))/80.0).rg;
  float explored=smoothstep(.04,.96,sight.r);float visible=smoothstep(.05,.9,sight.g);
  vec3 hidden=mix(pow(vec3(.075,.15,.13),vec3(2.2)),color,.48);
  hidden*=mix(.8,1.2,clamp(world_point.y/28.0,0.0,1.0));
  color=mix(hidden,color*mix(.50,1.0,visible),explored);
  float haze=smoothstep(60.0,255.0,distance(world_point.xz,hero_position));
  color=mix(color,pow(vec3(.42,.51,.44),vec3(2.2)),haze*.72*(1.0-visible*.45));
 }
 if(inlay_carving){color*=mix(1.0,.24,COLOR.r);AO=1.0-COLOR.r*.8;}
 ALBEDO=original_palette ? vec3(0.0) : color;
 EMISSION=original_palette ? archive_color(tex.rgb) : color*.10+emission_color.rgb*emission_strength;
 float finish=route_weight(world_point);
 if(route_preserve_ink)finish*=smoothstep(.16,.35,dot(tex.rgb,vec3(.299,.587,.114)));
 if(finish>0.0){
  vec3 paint=route_tint*(.94+.06*sin(world_point.x*.13+world_point.z*.17));
  if(original_palette)EMISSION=mix(EMISSION,archive_color(paint),finish);
  else ALBEDO=mix(ALBEDO,paint,finish);
 }
 ROUGHNESS=surface_kind>5.5 ? .65 : .96;SPECULAR=original_palette ? 0.0 : .18;
}
