extends RefCounted
## Original Sokia props share the existing terrain, foliage and static collision owners.
const Data=preload("res://assets/maps/falan/sokia/data.gd")
const Atlas=preload("res://assets/maps/falan/sokia/props.png")
const WATER=preload("res://assets/maps/falan/sokia/scenery/water.png")
const Details=preload("res://scripts/forest/forest_sokia_details.gd")
const MASKS={
 "sokia_coast":preload("res://assets/maps/falan/sokia/sokia_coast_surface.png"),
 "sokia_desert":preload("res://assets/maps/falan/sokia/sokia_desert_surface.png"),
 "ghana_road":preload("res://assets/maps/falan/sokia/ghana_road_surface.png"),
 "ghana_north_road":preload("res://assets/maps/falan/sokia/ghana_north_road_surface.png")}
# Prepared CPU pixels are read-only; shader textures keep their existing owner.
static func mask_image(area:String)->Image:
 var image:Image=load("res://assets/maps/falan/sokia/cpu-masks/"+area+".res")
 assert(image.get_meta("rgba_sha256")==Data.MASK_RGBA[area],"Rebuild the prepared Sokia CPU mask after changing its source")
 return image
static var meshes={}
static var completed_meshes={}
static var completed_graphics:Dictionary={}
static var stele_data:Dictionary={}
static var stele_meshes:Dictionary={}
static var mouth_data:Array=[]
static var mouth_cut_shader:Shader
static var northeast_shaders:Dictionary={}
static var northeast_footprint:Dictionary={}
static func northeast_clip_material(material_:ShaderMaterial,terrain,ground:bool=false):
 var northeast=terrain.variant in ["ghana_road","ghana_north_road"]
 var shore=ground and owns(terrain.variant)
 if not northeast and not shore:
  if material_.get_meta("sokia_northeast_clip",false):
   material_.set_shader_parameter("sokia_ne_clip",false)
   if ground:
    material_.set_shader_parameter("sokia_source_bank",false)
    var empty=PackedVector4Array();empty.resize(8)
    material_.set_shader_parameter("sokia_ne_entry",Vector4.ZERO);material_.set_shader_parameter("sokia_ne_profile",empty)
   else:
    material_.set_shader_parameter("sokia_ne_bounds",Vector4.ZERO);material_.set_shader_parameter("sokia_ne_footprint",null)
  return
 var original:Shader=material_.shader.get_meta("sokia_ne_original_shader",material_.shader)
 var key=[original,ground]
 if not northeast_shaders.has(key):
  var shader=Shader.new();var code=original.code
  if ground:
   code=code.replace("void fragment(){","uniform bool sokia_source_bank=false;\nuniform sampler2D sokia_source_bank_stone : source_color,filter_linear_mipmap,repeat_enable;\nuniform bool sokia_ne_clip=false;\nuniform vec4 sokia_ne_entry;\nuniform vec4 sokia_ne_profile[8];\nvoid fragment(){")
   code=code.replace("if(use_native_land_visibility){","""vec3 ne_offset=map_pos-sokia_ne_entry.xyz;
 float ne_depth=ne_offset.x;
 float ne_across=-ne_offset.z;
 if(sokia_ne_clip && sokia_ne_entry.w>0.0 && ne_depth> -1.5 && ne_depth<8.0 && ne_offset.y>.16 && ne_offset.y<sokia_ne_entry.w){
  float ne_height=ne_offset.y+.14;
  for(int ne_row=0;ne_row<7;ne_row++){
   vec3 ne_lower=sokia_ne_profile[ne_row].xyz;
   vec3 ne_upper=sokia_ne_profile[ne_row+1].xyz;
   if(ne_height>=ne_lower.z && ne_height<=ne_upper.z){
    vec2 ne_edges=mix(ne_lower.xy,ne_upper.xy,(ne_height-ne_lower.z)/max(.001,ne_upper.z-ne_lower.z));
    if(ne_across>ne_edges.x-.04 && ne_across<ne_edges.y+.04)discard;
   }
  }
 }
 if(use_native_land_visibility){""")
   code=code.replace("if(use_native_land_visibility){","float source_bank_coverage=0.0;\nif(use_native_land_visibility){")
   var visibility_anchor="vec2 uv=(map_pos.xz-native_visibility_bounds.xy)/native_visibility_bounds.zw;"
   code=code.replace(visibility_anchor,visibility_anchor+"\nvec4 sokia_visibility=texture(native_land_visibility,uv);source_bank_coverage=sokia_visibility.b;")
   code=code.replace("texture(native_land_visibility,uv).g<.5","sokia_visibility.g<.5")
   var rock_anchor="float rock=smoothstep(.24,.65,1.0-normalize(normal_world).y);"
   code=code.replace(rock_anchor,rock_anchor+"""
 float source_bank_side=0.0;
 vec3 source_bank_normal=vec3(0.0,1.0,0.0);
 if(sokia_source_bank){
  source_bank_normal=normalize(cross(dFdx(world),dFdy(world)));
  source_bank_side=smoothstep(.2,.6,1.0-abs(source_bank_normal.y))*source_bank_coverage;
  rock=max(rock,source_bank_side);
 }
""")
   var stone_anchor="if(use_ghana_palette && detail_paint.a>.5){"
   code=code.replace(stone_anchor,"""
 if(source_bank_side>0.0){
  vec3 bank_p=world/map_scale;
  vec3 bank_w=pow(abs(source_bank_normal),vec3(4.0));bank_w/=bank_w.x+bank_w.y+bank_w.z;
  vec3 bank_stone=texture(sokia_source_bank_stone,bank_p.zy*.16).rgb*bank_w.x+texture(sokia_source_bank_stone,bank_p.xz*.16).rgb*bank_w.y+texture(sokia_source_bank_stone,bank_p.xy*.16).rgb*bank_w.z;
  stone=mix(stone,bank_stone,source_bank_side);
 }
"""+stone_anchor)
  else:
   code=code.replace("void fragment() {","""uniform bool sokia_ne_clip=false;
 uniform sampler2D sokia_ne_footprint : filter_nearest,repeat_disable;
 uniform vec4 sokia_ne_bounds;
 void fragment() {
  vec2 ne_uv=(cliff_local.xz-sokia_ne_bounds.xy)/sokia_ne_bounds.zw;
  if(sokia_ne_clip && all(greaterThanEqual(ne_uv,vec2(0.0))) && all(lessThan(ne_uv,vec2(1.0))) && texture(sokia_ne_footprint,ne_uv).r<.5)discard;
 """)
  shader.code=code;shader.set_meta("sokia_ne_original_shader",original);northeast_shaders[key]=shader
 var values={}
 for uniform in material_.shader.get_shader_uniform_list():values[uniform.name]=material_.get_shader_parameter(uniform.name)
 material_.shader=northeast_shaders[key]
 for name_ in values:material_.set_shader_parameter(name_,values[name_])
 material_.set_shader_parameter("sokia_ne_clip",northeast)
 if ground:
  material_.set_shader_parameter("sokia_source_bank",shore)
  material_.set_shader_parameter("sokia_source_bank_stone",preload("res://assets/maps/falan/sokia_cliff_face.png"))
  if not northeast:
   var empty=PackedVector4Array();empty.resize(8)
   material_.set_shader_parameter("sokia_ne_entry",Vector4.ZERO);material_.set_shader_parameter("sokia_ne_profile",empty)
   material_.set_meta("sokia_northeast_clip",true)
   return
 var regions=load("res://scripts/forest/forest_freyja_regions.gd")
 var frame:Transform2D=regions.frame(terrain.variant).inverse()
 if ground:
  var at=frame*(Vector2(755,81)*3.)
  var profile:Array=source_mouth_profile(Vector2i(755,81));var rows=PackedVector4Array()
  for i in 8:rows.append(Vector4(profile[i].x,profile[15-i].x,profile[i].y,0))
  material_.set_shader_parameter("sokia_ne_entry",Vector4(at.x,terrain.height(at.x,at.y),at.y,profile.map(func(p):return p.y).max()))
  material_.set_shader_parameter("sokia_ne_profile",rows)
 else:
  if northeast_footprint.is_empty():northeast_footprint=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/scenery/northeast-cliff-footprint.json"))
  var b:Array=northeast_footprint.bounds;var at=frame*(Vector2(b[0],b[1])*3.-Vector2.ONE*1.5)
  material_.set_shader_parameter("sokia_ne_footprint",load("res://assets/maps/falan/sokia/scenery/northeast-cliff-footprint.png"))
  material_.set_shader_parameter("sokia_ne_bounds",Vector4(at.x,at.y,b[2]*3.,b[3]*3.))
 material_.set_meta("sokia_northeast_clip",true)
static func source_mouth_profile(cell:Vector2i)->Array:
 if mouth_data.is_empty():mouth_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/scenery/mouths.json"))
 for row in mouth_data:
  if Vector2i(row.cell[0],row.cell[1])==cell:
   return row.profile.map(func(p):return Vector2(p[0],p[1]))
 return []
static func mouth_offset(cell:Vector2i)->Vector2:
 source_mouth_profile(Vector2i.ZERO)
 for row in mouth_data:
  if Vector2i(row.cell[0],row.cell[1])==cell:return Vector2(row.center_offset[0],row.center_offset[1])
 return Vector2.ZERO
static func mouths(area:String,frame:Transform2D)->Dictionary:
 source_mouth_profile(Vector2i.ZERO) # Prepared data is loaded once at scene setup.
 var result={Vector2i(240,265):Vector2(0,-1),Vector2i(356,334):Vector2(1,0),Vector2i(402,304):Vector2(0,-1)}
 for row in mouth_data:result[Vector2i(row.cell[0],row.cell[1])]=Vector2(row.back[0],row.back[1])
 var current=bounds(area)
 for cell in result.keys():
  if not current.has_point(frame*(Vector2(cell)*3.)):result.erase(cell)
 return result
static func mouth_shader(base:Shader)->Shader:
 if mouth_cut_shader==null:
  # A local derivative expands the original renderer's three cuts for overlapping
  # Sokia crops. The shared shader/material and every other route stay untouched.
  mouth_cut_shader=Shader.new()
  mouth_cut_shader.code=base.code.replace("entrance_cuts[3]","entrance_cuts[8]").replace("entrance_back[3]","entrance_back[8]").replace("entrance_profile[24]","entrance_profile[64]")
 return mouth_cut_shader
static func mouth_material(material_:ShaderMaterial):
 var values={}
 for uniform in material_.shader.get_shader_uniform_list():
  values[uniform.name]=material_.get_shader_parameter(uniform.name)
 material_.shader=mouth_shader(material_.shader)
 for name_ in values:material_.set_shader_parameter(name_,values[name_])
const STELES=[11566,11567,11569,11571,11574]
static func stele(serial:int)->Mesh:
 if stele_meshes.has(serial):return stele_meshes[serial]
 if stele_data.is_empty():stele_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/scenery/steles.json"))
 var g:Dictionary=stele_data[str(serial)];var forms=load("res://scripts/forest/forest_original_map_solids.gd")
 var atlas:Texture2D=load("res://assets/maps/falan/sokia/scenery/steles.png")
 var family="prop" if serial in [11566,11567,11569] else "obelisk"
 var key=[serial,family];var previous:Mesh=forms.meshes.get(key)
 forms.meshes.erase(key) # This atlas belongs only to the Sokia derivative.
 var raw:Mesh=forms.mesh(serial,family,g,atlas)
 forms.meshes.erase(key)
 if previous!=null:forms.meshes[key]=previous
 var fit=Details.Shapes.Proportions;var b:Array=g.bounds
 var pose=fit.measure(fit.mesh_points(raw),"",Basis(Vector3.UP,PI*.5),Rect2(b[0],b[1],b[2],b[3]))
 var mesh=fit.transformed(raw,pose);var r:Array=g.rect;var rgb:Array=g.rgb
 var paint=fit.material("",Transform3D(Basis(Vector3.UP,PI*.5),Vector3.ZERO),true,atlas,Rect2(r[0],r[1],r[2],r[3]),load("res://assets/maps/falan/sokia/scenery/steles-mask.png"),Color(rgb[0],rgb[1],rgb[2]),null,Rect2(g.origin[0],g.origin[1],r[2],r[3]))
 paint.set_shader_parameter("original_palette",true)
 if family=="prop":paint.set_shader_parameter("falan_source_contour",true)
 mesh.surface_set_material(0,paint)
 stele_meshes[serial]=mesh;return mesh
static var bank_side_shader:Shader
static func bank_material(paint:ShaderMaterial)->ShaderMaterial:
 if bank_side_shader==null:
  bank_side_shader=Shader.new()
  var code=paint.shader.code
  code=code.replace("shader_type spatial;","shader_type spatial;\nuniform sampler2D sokia_bank_side : source_color,filter_linear_mipmap,repeat_enable;")
  var anchor="vec3 color=base_color.rgb*tex.rgb*vertex_color;"
  assert(code.contains(anchor),"Source bank paint hook changed")
  code=code.replace(anchor,anchor+"""
 vec3 bank_n=normalize(world_normal);
 vec3 bank_weights=pow(abs(bank_n),vec3(4.0));bank_weights/=bank_weights.x+bank_weights.y+bank_weights.z;
 vec3 bank_rock=texture(sokia_bank_side,local_point.zy*.16).rgb*bank_weights.x+texture(sokia_bank_side,local_point.xz*.16).rgb*bank_weights.y+texture(sokia_bank_side,local_point.xy*.16).rgb*bank_weights.z;
 color=mix(color,bank_rock,smoothstep(.2,.6,1.0-abs(bank_n.y)));
""")
  bank_side_shader.code=code
 paint.shader=bank_side_shader
 paint.set_shader_parameter("sokia_bank_side",preload("res://assets/maps/falan/sokia_cliff_face.png"))
 return paint
static var material:ShaderMaterial
static var fixed_catalog:Dictionary={}
static var fixed_meshes:Dictionary={}
static var fixed_trees:Dictionary={}
static var ghana_scenery:Array=[]
static func ghana_rows()->Array:
 if ghana_scenery.is_empty():
  for row in JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/scenery/ghana-scenery.json")):
   ghana_scenery.append([Vector2i(row[0],row[1]),int(row[2]),Vector2i(row[3],row[4]),int(row[5]),false])
 return ghana_scenery
static var crossing_regions:Script
static func fixed_map(id:int)->Dictionary:
 var original=load("res://scripts/forest/forest_original_map_art.gd")
 if id in original.EXPLORE_RECOVERED_IDS:
  original.load_explore_recovered()
  var completed:Dictionary=original.data().maps.get("BlueCrossgate/map/0/%d.dat"%id,{})
  if completed.get("fixed_bounds_complete",false):return completed
 if id in original.SOKIA_CAPE_ACCESS_IDS:
  original.load_sokia_cape_access()
  return original.data().maps.get("BlueCrossgate/map/0/%d.dat"%id,{})
 if fixed_catalog.is_empty():fixed_catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/fixed/catalog.json"))
 return fixed_catalog.maps.get("BlueCrossgate/map/0/%d.dat"%id,{})
static func tree_fit(id:int,serial:int)->Transform3D:
 var key=Vector2i(id,serial)
 if fixed_trees.has(key):return fixed_trees[key]
 var meadow=load("res://scripts/forest/forest_wind_meadow_assets.gd");var fit=Details.Shapes.Proportions
 var turn=Transform3D(Basis(Vector3.UP,-PI*.25),Vector3.ZERO);var points:Array[Vector3]=[]
 for part in meadow.source(meadow.crossgate_tree(serial)):points.append_array(fit.mesh_points(part.mesh,turn*part.transform))
 var b:Array=fixed_map(id).visible_bounds[str(serial)]
 fixed_trees[key]=fit.measure(points,"",Basis(Vector3.UP,PI*.5),Rect2(b[0],b[1],b[2],b[3]))*turn
 return fixed_trees[key]
static func tree_color(serial:int)->Color:
 var source=load("res://scripts/forest/forest_ruby_region_art.gd").catalog()
 var native=10058 if serial<10074 else 10085 if serial<10088 else 10088
 var rgb:Array=source.graphics[str(serial)].leaf_rgb;var base:Array=source.palettes[str(native)]
 return Color(rgb[0]/base[0],rgb[1]/base[1],rgb[2]/base[2])
const COAST_PORTS=[[148,199,5003,2,10,"飼養師之家","house"],[187,229,13014,6,64,"流星山丘 · 下山口","cave"],[380,324,23600,7,23,"獅子之穴 · 大廳","cave"],[368,351,15564,5,24,"風之洞窟","cave"],[369,351,15564,6,24,"風之洞窟","cave"],[671,157,13015,8,23,"波塔的家","house"],[626,209,13500,33,2,"水之洞窟","cave"],
 [760,59,15527,15,27,"索奇亞東北入口 · 15527","house"],[755,81,15530,5,6,"索奇亞東北洞窟 · 15530","cave"]]
static func branch_links(model)->Array:
 var result=[];var original=load("res://scripts/forest/forest_original_maps.gd");var regions=load("res://scripts/forest/forest_freyja_regions.gd")
 if owns(model.falan_area):
  for p in COAST_PORTS:
   var at=regions.frame(model.falan_area).inverse()*(Vector2(p[0],p[1])*3.)
   if not bounds(model.falan_area).has_point(at):continue
   result.append({"at":at,"to":"freyja_site","site":p[2],"kind":p[6],"arrival":original.source_point(p[2],Vector2i(p[3],p[4])),"yaw":0.,"caption":p[5],"door":true})
 elif model.falan_area=="interior":
  if fixed_catalog.is_empty():fixed_catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/fixed/catalog.json"))
  if not fixed_catalog.maps.has("BlueCrossgate/map/0/%d.dat"%model.falan_floor):return result
  for w in original.Art.data().warps:
   if int(w[0])!=model.falan_floor or int(w[3])!=300:continue
   var area="ghana_road" if int(w[4])>=550 else "sokia_coast"
   result.append({"at":original.source_point(model.falan_floor,Vector2i(w[1],w[2])),"to":"freyja_outside","area":area,"arrival":regions.frame(area).inverse()*(Vector2(w[4],w[5])*3.),"caption":"索奇亞","door":true})
 return result
static func interior_mesh(serial:int,mesh:Mesh,source_id:int=5003,native_paint:bool=false,wall:bool=false,source_cap:bool=false)->Mesh:
 var key=Vector2i(source_id,serial)
 if fixed_meshes.has(key):return fixed_meshes[key]
 var source=fixed_map(source_id)
 var bounds:Array=source.visible_bounds[str(serial)] if wall else source.solid_bounds.get(str(serial),source.visible_bounds[str(serial)])
 var fit=Details.Shapes.Proportions
 var pose=Transform3D.IDENTITY if source_cap else fit.measure(fit.mesh_points(mesh),"",Basis(Vector3.UP,PI*.5),Rect2(bounds[0],bounds[1],bounds[2],bounds[3]))
 fixed_meshes[key]=fit.transformed(mesh,pose)
 var house=load("res://scripts/forest/forest_sokia_house_art.gd")
 if native_paint:
  var art=load("res://scripts/forest/forest_original_map_art.gd");var g:Dictionary=art.data().graphics[str(serial)]
  var texture:Texture2D=load(art.ROOT+art.data().pages[int(g.page)])
  var arrays=fixed_meshes[key].surface_get_arrays(0)
  var paint_center:Vector3=fixed_meshes[key].get_aabb().get_center()
  for i in arrays[Mesh.ARRAY_VERTEX].size():
   var p:Vector3=arrays[Mesh.ARRAY_VERTEX][i]
   var normal:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
   var sample=p
   if wall:
    # The black native cap is a horizontal cutaway, not a rear wall material.
    # Continue the two painted elevations around the unseen vertical sides.
    if normal.x>.01:sample.x=2.*paint_center.x-sample.x
    if normal.z<-.01:sample.z=2.*paint_center.z-sample.z
   var pixel=Vector2((sample.x+sample.z)*fit.HORIZONTAL,(sample.z-sample.x)*fit.FLOOR-sample.y*fit.VERTICAL)-Vector2(g.origin[0],g.origin[1])
   if wall and normal.y>.5:
    var cap:Array=source.cap_pixels.get(str(serial),[g.rect[2]*.5,5]);pixel=Vector2(cap[0],cap[1])
   pixel=pixel.clamp(Vector2.ONE*.5,Vector2(g.rect[2],g.rect[3])-Vector2.ONE*.5)
   arrays[Mesh.ARRAY_TEX_UV][i]=(Vector2(g.rect[0],g.rect[1])+pixel)/texture.get_size()
  var painted=ArrayMesh.new();painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);painted.surface_set_material(0,house.Source.material(texture))
  fixed_meshes[key]=painted
 return fixed_meshes[key]
static func owns(area:String)->bool:return MASKS.has(area)
static func bounds(area:String)->Rect2:
 var size_=Vector2(MASKS[area].get_size())*3.
 return Rect2(-size_*.5,size_)
static func margin(area:String,at:Vector2)->float:
 var rect=bounds(area)
 return minf(minf(at.x-rect.position.x,at.y-rect.position.y),minf(rect.end.x-at.x,rect.end.y-at.y))/3.
static func crossing(area:String,previous:Vector2,next:Vector2)->Dictionary:
 if crossing_regions==null:crossing_regions=load("res://scripts/forest/forest_freyja_regions.gd")
 var regions=crossing_regions
 var local=regions.frame(area).inverse()*next;var edge=margin(area,local)
 if edge>24. or margin(area,regions.frame(area).inverse()*previous)<=edge:return {}
 var target="";var best=edge+24.
 for candidate in MASKS:
  if candidate==area:continue
  var distance_=margin(candidate,regions.frame(candidate).inverse()*next)
  if distance_>best:target=candidate;best=distance_
 if target.is_empty():return {}
 return {"area":target,"arrival":regions.frame(target).inverse()*next,"rotation":0.}
static func expansion(area:String)->float:
 return 1.5 if owns(area) and maxi(MASKS[area].get_width(),MASKS[area].get_height())>321 else 1.0
static func collisions(model,frame:Transform2D)->Array:
 var result=[]
 for rect:Rect2i in Data.BLOCKS[model.falan_area]:
  var center=frame*((Vector2(rect.position)+Vector2(rect.size-Vector2i.ONE)*.5)*3.0)
  var size_=Vector2(rect.size)*3.0
  var height=30.0 if model.falan_area=="ghana_north_road" else 10.0
  var box=AABB(Vector3(center.x-size_.x*.5,2.0,center.y-size_.y*.5),Vector3(size_.x,height,size_.y))
  result.append(["sokia_source_collision",Transform3D(Basis.IDENTITY,box.get_center()),box,0])
 return result
static func kili_prop(serial:int)->bool:
 return Data.GRAPHICS.has(serial) and ((serial>=11625 and serial<=11710) or (serial>=12160 and serial<=12180))
static func solid_building(area:String,serial:int,cell:Vector2i)->bool:
 # The northeast castle repeats the same 71 native pieces as the existing Beast Castle.
 return owns(area) and (serial in [11289,11290,11292,11293,11294,11295,11298] or serial==10011 and cell==Vector2i(756,58))

static func completed_mesh(serial:int)->Mesh:
 if completed_meshes.has(serial):return completed_meshes[serial]
 if serial in [10017,11139]:completed_meshes[serial]=load("res://scripts/forest/forest_kili_ghana_props.gd").mesh(serial)
 elif serial==11229:completed_meshes[serial]=load("res://scripts/forest/forest_ghana_details.gd").mesh()
 else:
  var art=load("res://scripts/forest/forest_original_map_art.gd");var forms=load("res://scripts/forest/forest_original_map_solids.gd")
  var g:Dictionary=art.data().graphics[str(serial)]
  if completed_graphics.is_empty():completed_graphics=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/provenance.json")).source_graphics
  var source:Dictionary=completed_graphics[str(serial)]
  assert(g.rgba_sha256==source.rgba_sha256,"Reused source prop must keep its original paint")
  var raw:Mesh=forms.mesh(serial,forms.kind(serial,false,g),g,art.solid_texture(int(g.page)))
  var fit=load("res://scripts/forest/forest_falan_proportions.gd");var b:Array=source.native_visible_bounds
  completed_meshes[serial]=fit.transformed(raw,fit.measure(fit.mesh_points(raw),"",Basis(Vector3.UP,PI*.5),Rect2(b[0],b[1],b[2],b[3])))
 return completed_meshes[serial]
static func cliff_origin(model,frame:Transform2D,anchor:Vector2,point:Vector3)->Vector3:
 # These native 3×3 cliff pieces rise from the cave's recorded open footpoint,
 # not from the raised placeholder cells under the middle of each compound tile.
 if anchor.x>=756 and anchor.x<=762 and anchor.y>=79 and anchor.y<=85:
  var foot=frame*(Vector2(755,81)*3.)
  point.y=minf(point.y,model.surface_height(foot.x,foot.y))
 return point
static func cliff_foundation(model,frame:Transform2D,point:Vector3)->float:
 if model.falan_area!="ghana_north_road":return NAN
 var source=frame.inverse()*Vector2(point.x,point.z)
 if point.y-model.terrain.Regions.land_height(source)<3.0:return NAN
 # Raised source cliff cells need a buried visual base without lowering their crowns.
 return model.terrain.WATER_HEIGHT-.35
static func build(parent:Node3D,model,frame:Transform2D,rows:Array):
 if material==null:
  material=ShaderMaterial.new();material.shader=preload("res://scripts/forest/sokia_scenery.gdshader")
  material.set_shader_parameter("source_art",Atlas)
 var groups={};var native_groups={}
 for row in rows:
  var serial:int=row[1]
  if not Data.GRAPHICS.has(serial):continue
  var cell:Vector2i=row[0];var span:Vector2i=row[2]
  var at=frame*((Vector2(cell)+Vector2(span-Vector2i.ONE)*Vector2(.5,-.5))*3.0)
  if serial in [10017,11139,11229,12199,16794]:
   if not native_groups.has(serial):native_groups[serial]=[]
   completed_mesh(serial)
   native_groups[serial].append(Transform3D(Basis.IDENTITY,Vector3(at.x,model.surface_height(at.x,at.y),at.y)))
   continue
  if solid_building(model.falan_area,serial,cell):
   var index=parent.get_child_count()
   if serial==10011:
    var anchor=frame*(Vector2(cell+Vector2i(4,0))*3.)
    load("res://scripts/forest/forest_beast_castle.gd").build(parent,Vector3(anchor.x,model.surface_height(anchor.x,anchor.y),anchor.y))
   else:Details.Shapes.build(parent,Vector3(at.x,model.surface_height(at.x,at.y),at.y),serial)
   var building=parent.get_child(index)
   building.set_meta("sokia_source_solid",true);building.set_meta("source_cell",cell)
   if serial==10011:
    building.name="SokiaNortheastCastle"
    building.set_meta("reused_source_anchor",Vector2i(135,333));building.set_meta("original_source_anchor",Vector2i(760,58))
   continue
  var key=[serial,Vector2i(floori(at.x/48),floori(at.y/48))]
  if not groups.has(key):groups[key]=[]
  var rect:Rect2i=Data.GRAPHICS[serial]
  groups[key].append(Transform3D(Basis.IDENTITY,Vector3(at.x,model.surface_height(at.x,at.y)+rect.size.y*.023,at.y)))
 load("res://scripts/forest/forest_kili_art.gd").batch_meshes(parent,native_groups,completed_meshes,"SokiaCompletedNativeFixture")
 for key in groups:
  var serial:int=key[0]
  if not meshes.has(serial):
   var rect:Rect2i=Data.GRAPHICS[serial]
   var mesh=QuadMesh.new();mesh.size=Vector2(rect.size)*.046
   var arrays=mesh.surface_get_arrays(0);var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
   for i in uvs.size():uvs[i]=(Vector2(rect.position)+uvs[i]*Vector2(rect.size))/Atlas.get_size()
   var mapped=ArrayMesh.new();mapped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);meshes[serial]=mapped
  var batch=MultiMeshInstance3D.new();batch.name="SokiaNativeProp_%d_%d_%d"%[serial,key[1].x,key[1].y];batch.material_override=material
  batch.extra_cull_margin=Data.GRAPHICS[serial].size.x*.023;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.mesh=meshes[serial]
  batch.multimesh.instance_count=groups[key].size()
  for i in groups[key].size():batch.multimesh.set_instance_transform(i,groups[key][i])
  batch.set_meta("source_graphic",serial);batch.set_meta("source_placements",groups[key].size())
  parent.add_child(batch)
