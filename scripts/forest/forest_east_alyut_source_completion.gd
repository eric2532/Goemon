extends RefCounted
## Compatible full2400 data feeding the existing terrain, village and source-art owners.
const ROOT="res://assets/maps/falan/east_region/alyut_source_completion/"
static var review_root=""
static var catalogs:Dictionary={}
static var images:Dictionary={}
static var textures:Dictionary={}
static var bits:Dictionary={}
static var extra_meshes:Dictionary={}
static var handoff_folders:Dictionary={}
static var handoff_cells:Dictionary={}
static var underlay_settings:Dictionary={}
static var underlay_water_rows:Dictionary={}
static var water_backings:Dictionary={}
static var source_overlaps:Dictionary={}

static func folder()->String:return review_root if not review_root.is_empty() else ROOT
static func enabled()->bool:return FileAccess.file_exists(folder()+"map-data.json")

static func data()->Dictionary:
 var key=folder()
 if not catalogs.has(key):catalogs[key]=JSON.parse_string(FileAccess.get_file_as_string(key+"map-data.json"))
 return catalogs[key]

static func texture(name_:String)->Texture2D:
 var key=folder()+name_
 if not textures.has(key):
  images[key]=Image.load_from_file(key);textures[key]=ImageTexture.create_from_image(images[key]);textures[key].set_meta("source_cpu_image",images[key])
 return textures[key]

static func mask()->Texture2D:return texture("mask.png")
static func ground_index()->Texture2D:return texture("ground-index.png")
static func ground_atlas()->Texture2D:return texture("ground-atlas.png")

static func source_open(cell:Vector2i)->bool:
 var size_=Vector2i(data().size[0],data().size[1])
 if not Rect2i(Vector2i.ZERO,size_).has_point(cell):return false
 var key=folder()
 if not bits.has(key):bits[key]=Marshalls.base64_to_raw(data().walk_bits).decompress((size_.x*size_.y+7)>>3,FileAccess.COMPRESSION_DEFLATE)
 var index=cell.y*size_.x+cell.x
 return bool(bits[key][index>>3]&(1<<(index&7)))

static func field_handoff(cell:Vector2i)->bool:
 # Prepared-source availability and exact cells are loaded once per source
 # folder/version, matching the other immutable map caches; no per-tick IO.
 var key_folder=folder()
 if not handoff_folders.has(key_folder):handoff_folders[key_folder]=enabled()
 if not bool(handoff_folders[key_folder]):return false
 var key=[key_folder,String(data().source.sha256)]
 if not handoff_cells.has(key):
  var cells={};var path=key_folder+"gate-handoffs.json"
  if FileAccess.file_exists(path):
   var prepared_handoff:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
   assert(prepared_handoff.source_hybrid_sha256==data().source.sha256,"Source100 handoff requires the same compatible Alyut variant")
   for row:Dictionary in prepared_handoff.handoff_cells:cells[Vector2i(row.village_cell[0],row.village_cell[1])]=true
  handoff_cells[key]=cells
 return handoff_cells[key].has(cell)

static func source_overlap_data()->Dictionary:
 var key=[folder(),String(data().source.sha256)]
 if not source_overlaps.has(key):
  var path=folder()+"source-overlaps.json";var source:Dictionary={}
  if FileAccess.file_exists(path):
   source=JSON.parse_string(FileAccess.get_file_as_string(path))
   assert(source.source_hybrid_sha256==data().source.sha256,"Source100 overlaps require the same compatible Alyut variant")
   var cells={}
   for row:Dictionary in source.source100_overlap_cells:cells[Vector2i(row.village_cell[0],row.village_cell[1])]=true
   source.cells=cells
  source_overlaps[key]=source
 return source_overlaps[key]

static func field_overlap(cell:Vector2i)->bool:
 # This source owner is separate from the twelve original gate-warp buffers.
 var key_folder=folder()
 if not handoff_folders.has(key_folder):handoff_folders[key_folder]=enabled()
 if not bool(handoff_folders[key_folder]):return false
 var source=source_overlap_data()
 return not source.is_empty() and source.cells.has(cell)

static func local_point(cell:Vector2)->Vector2:
 return (cell-Vector2(float(data().size[0])*.5,float(data().size[1])*.5))*3.

static func cliff_rows()->Array:
 var result=[]
 for row:Dictionary in data().placements:
  if int(row.graphic) in range(12536,12548):result.append({"map":2400,"cell":row.cell,"graphic":row.graphic})
 return result

static func plan(model,building_plan:Array)->Array:
 # Existing five measured buildings keep their source footprints and door clearance.
 var result=building_plan.duplicate(true)
 var blocks:Array=data().blocked_land_rectangles
 var context=load("res://scripts/forest/forest_freyja_regions.gd").private_source_context
 var private_town=context!=null and context.owns(model)
 if not private_town and FileAccess.file_exists(folder()+"gate-handoffs.json"):
  var handoffs:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder()+"gate-handoffs.json"))
  assert(handoffs.source_hybrid_sha256==data().source.sha256,"Gate handoffs must retain the same original source variant")
  blocks=handoffs.blocked_land_rectangles
 for row:Array in blocks:
  var at=local_point(Vector2(row[0],row[1]))-Vector2.ONE*1.5
  var center=at+Vector2(row[2],row[3])*1.5
  var box=AABB(Vector3(at.x,model.surface_height(center.x,center.y)-.05,at.y),Vector3(row[2]*3.,12.,row[3]*3.))
  result.append(["freyja_source_collision",Transform3D.IDENTITY,box,row])
 var overlap=source_overlap_data()
 if not private_town and not overlap.is_empty():
  for row:Dictionary in overlap.source100_overlap_cells:
   if row.field_native_open:continue
   assert(int(row.field_pg1)==12172 and Vector2i(row.source_footprint[0],row.source_footprint[1])==Vector2i.ONE,"Only the original source100flower needs additional closed footprint")
   var at=local_point(Vector2(row.village_cell[0],row.village_cell[1]))
   var flower:Dictionary=load("res://scripts/forest/forest_east_village_props.gd").data().graphics["12172"]
   var height_=1.
   for crown:Dictionary in flower.crowns:height_=maxf(height_,float(crown.height))
   # The standalone2400view has water here; the retained source100land has
   # the existing joined6m datum. Its flower closure must use that owner.
   var box=AABB(Vector3(at.x-1.5,float(row.joined_land_height)-.05,at.y-1.5),Vector3(3.,height_,3.))
   result.append(["freyja_source_collision",Transform3D.IDENTITY,box,{"map":100,"cell":row.field_cell,"graphic":12172,"source_overlap":true}])
 return result

static func source_height(model,point:Vector2)->float:
 if model.has_meta("east_alyut_parent_terrain"):
  var parent_terrain=model.get_meta("east_alyut_parent_terrain")
  var joined=point+Vector2(-165,-123)
  return parent_terrain.height(joined.x,joined.y)
 return model.surface_height(point.x,point.y)

static func bank_rows(joined:bool=false)->Array:
 var path=folder()+"banks.json"
 if not FileAccess.file_exists(path):return []
 var prepared:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 assert(prepared.source_hybrid_sha256==data().source.sha256,"Alyut bank placements require the exact compatible source variant")
 assert(prepared.bank_data_sha256==FileAccess.get_sha256("res://assets/maps/falan/east_region/bank_caps/data.json"),"Rebuild Alyut bank metadata after changing the shared native cap source")
 var result=[]
 for source:Dictionary in prepared.rows:
  var row:Dictionary=source.duplicate(true);row.anchor=Vector2(source.anchor[0],source.anchor[1])+(Vector2(-165,-123) if joined else Vector2.ZERO)
  row.source_cell=Vector2i(source.source_cell[0],source.source_cell[1]);result.append(row)
 return result

static func bank_underlay_settings(terrain)->Dictionary:
 # Visual ownership only. The exact native-open tile supports, terrain height
 # field, source walk bits and original water remain owned by their existing APIs.
 if not enabled():return {}
 assert(terrain.variant in ["alyut","north_coast"],"Alyut banks require the existing village/connected-field frame")
 var key=[folder(),String(data().source.sha256),terrain.variant,terrain.width,terrain.spacing,terrain.horizontal_scale,terrain.expansion]
 if underlay_settings.has(key):return underlay_settings[key]
 assert(terrain.width>0 and is_equal_approx(terrain.spacing,3.),"Visibility uses the configured native3m terrain grid")
 var rows=bank_rows(terrain.variant=="north_coast")
 var ground=Marshalls.base64_to_raw(data().ground_u16le_deflate).decompress(int(data().size[0])*int(data().size[1])*2,FileAccess.COMPRESSION_DEFLATE)
 assert(rows.size()==117,"Only all117 exact source-confirmed Alyut bank cells are owned")
 for row:Dictionary in rows:
  var cell:Vector2i=row.source_cell;var source_ground=ground.decode_u16((cell.y*int(data().size[0])+cell.x)*2)
  assert(source_ground in range(5000,5009) and source_open(cell),"Visual cutout cannot remove source dryland or a blocked tile")
 var helper=load("res://scripts/forest/forest_east_bank_underlay.gd")
 # Include the existing decorative apron too: the sampler discards outside
 # its bounds, so limiting it to the collision field would cut unrelated art.
 var bounds:Rect2=helper.visual_bounds(terrain.mesh())
 var settings:Dictionary=helper.settings(bounds,rows,bank_underlay_water_rows(terrain.variant=="north_coast"))
 var texture_:Texture2D=settings.native_land_visibility
 texture_.set_meta("alyut_source_hybrid_sha256",data().source.sha256)
 texture_.set_meta("alyut_source_bank_cells",rows.map(func(row):return row.source_cell))
 underlay_settings[key]=settings
 return settings

static func bank_underlay_water_rows(joined:bool=false)->Array:
 var key=[folder(),String(data().source.sha256),joined]
 if underlay_water_rows.has(key):return underlay_water_rows[key]
 var source_banks={};var cells={};var result=[];var size_=Vector2i(data().size[0],data().size[1])
 var ground=Marshalls.base64_to_raw(data().ground_u16le_deflate).decompress(size_.x*size_.y*2,FileAccess.COMPRESSION_DEFLATE)
 for row:Dictionary in bank_rows():source_banks[row.source_cell]=true
 for cell:Vector2i in source_banks:
  for dz in [-1,0,1]:
   for dx in [-1,0,1]:
    var neighbor=cell+Vector2i(dx,dz)
    if not Rect2i(Vector2i.ZERO,size_).has_point(neighbor) or source_banks.has(neighbor) or cells.has(neighbor):continue
    var source_ground=ground.decode_u16((neighbor.y*size_.x+neighbor.x)*2)
    if source_ground not in range(5000,5009):continue
    assert(not source_open(neighbor),"This bounded water-only underlay ring does not include an original walk route")
    cells[neighbor]=true
    result.append({"anchor":local_point(Vector2(neighbor))+(Vector2(-165,-123) if joined else Vector2.ZERO),"source_cell":neighbor,"source_bg":source_ground,"native_open":false,"source_water_context":true})
 # Six cells retain their distinct, original source100land/flower owner.
 # Their source2400water cannot erase a reachable original field road.
 var overlap=source_overlap_data()
 if not overlap.is_empty():result=result.filter(func(row):return not overlap.cells.has(row.source_cell))
 assert(result.size()==(82 if overlap.is_empty() else 76),"Only proven source2400water neighbors may be hidden; source100overlaps are excluded")
 underlay_water_rows[key]=result;return result

static func bank_water_mask(terrain,original:Texture2D,material_bounds:Vector4,map_scale:float)->Texture2D:
 assert(enabled() and terrain.variant in ["alyut","north_coast"] and map_scale>0.,"Water backing uses the existing Alyut source frame")
 var key=[folder(),String(data().source.sha256),terrain.variant,original.get_instance_id(),material_bounds,map_scale]
 if water_backings.has(key):return water_backings[key]
 var image:Image=original.get_meta("source_cpu_image") if original.has_meta("source_cpu_image") else original.get_image()
 var changed=image.duplicate();var cells=[];var bounds=Rect2(material_bounds.x,material_bounds.y,material_bounds.z,material_bounds.w)
 for row:Dictionary in bank_rows(terrain.variant=="north_coast"):
  var uv=(row.anchor*map_scale-bounds.position)/bounds.size;var cell=Vector2i((uv*Vector2(image.get_size())).floor())
  assert(Rect2i(Vector2i.ZERO,image.get_size()).has_point(cell),"Original water backing must retain its complete existing bounds")
  var pixel=changed.get_pixelv(cell);pixel.r=1.;pixel.a=1.;changed.set_pixelv(cell,pixel);cells.append(cell)
 var texture_=ImageTexture.create_from_image(changed);texture_.set_meta("source_cpu_image",changed);texture_.set_meta("alyut_source_water_bank_cells",cells);texture_.set_meta("alyut_source_hybrid_sha256",data().source.sha256)
 var digest=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(image.get_data());texture_.set_meta("original_water_mask_rgba_sha256",digest.finish().hex_encode())
 water_backings[key]=texture_;return texture_

static func apply_materials(ground:ShaderMaterial,water:ShaderMaterial,terrain)->bool:
 if load("res://scripts/forest/forest_freyja_regions.gd").private_source_context!=null:return false
 # Setup only, owned by this exact source-completed village. Canonical assets
 # remain absent until reviewed publication; all other material owners stay put.
 if terrain.variant not in ["alyut","north_coast"] or not enabled():return false
 var source_sha=String(data().source.sha256)
 if ground.get_meta("alyut_complete_material_source","")==source_sha and water.get_meta("alyut_complete_material_source","")==source_sha:return true
 if ground.get_shader_parameter("use_native_land_visibility")==true:
  terrain.set_meta("alyut_complete_material_blocker","Existing terrain visibility owner is enabled; source-bank cutout was not committed");return false
 for material:ShaderMaterial in [ground,water]:
  var frame=material.get_shader_parameter("map_frame")
  if frame!=null and frame!=Transform3D.IDENTITY:
   terrain.set_meta("alyut_complete_material_blocker","Unsupported material frame; source-bank cutout and water backing were not committed");return false
 var original:Texture2D=water.get_shader_parameter("layout_mask");var scale_=float(water.get_shader_parameter("map_scale"))
 if original==null or scale_<=0.:
  terrain.set_meta("alyut_complete_material_blocker","Original bounded source water material is unavailable; no material changes committed");return false
 # Prepare both immutable masks before committing either owned material.
 var settings=bank_underlay_settings(terrain)
 var backing=bank_water_mask(terrain,original,water.get_shader_parameter("bounds"),scale_)
 for key in settings:ground.set_shader_parameter(key,settings[key])
 water.set_shader_parameter("layout_mask",backing)
 ground.set_meta("alyut_complete_material_source",source_sha);water.set_meta("alyut_complete_material_source",source_sha)
 terrain.set_meta("alyut_complete_materials",{"source_hybrid_sha256":source_sha,"bank_tiles":117,"adjacent_original_water_tiles":bank_underlay_water_rows().size(),"water_backing_tiles":117})
 terrain.remove_meta("alyut_complete_material_blocker")
 return true

static func extra_prop(serial:int)->Mesh:
 var key=[folder(),serial]
 if extra_meshes.has(key):return extra_meshes[key]
 assert(serial==10461,"Only the source-confirmed broken-fence segment needs additional village paint")
 var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder()+"props/data.json"))
 var g:Dictionary=catalog.graphics[str(serial)].duplicate(true);g.cut=[serial];g.depth=.12
 var paint=texture("props/native.png")
 extra_meshes[key]=load("res://scripts/forest/forest_elsa_scenery.gd").relief_shape(g,paint,paint,g.outline)
 return extra_meshes[key]

static func build_props(root:Node3D,model):
 var props=load("res://scripts/forest/forest_east_village_props.gd")
 var assets=load("res://scripts/forest/forest_wind_meadow_assets.gd")
 var ruby=load("res://scripts/forest/forest_ruby_region_art.gd")
 var art=load("res://scripts/forest/forest_original_map_art.gd");art.load_east()
 var bank_owner=load("res://scripts/forest/forest_tina_ground.gd")
 var context=load("res://scripts/forest/forest_freyja_regions.gd").private_source_context
 var private_town=context!=null and context.owns(model)
 var recovered_banks=[] if private_town else bank_rows();var recovered_bank_cells={}
 for row:Dictionary in recovered_banks:recovered_bank_cells[row.source_cell]=true
 var groups={};var extras={};var trees={};var banks={};var counts={};var represented=[]
 for row:Dictionary in data().placements:
  var serial=int(row.graphic);var at=local_point(Vector2(row.cell[0],row.cell[1]));var owner=String(row.owner)
  if private_town and serial in range(12500,12536):continue
  counts[owner]=int(counts.get(owner,0))+1
  if owner in ["existing_building_owner","existing_gate_owner","source_blank","existing_shore_cliff_owner"] and serial not in range(12500,12536):continue
  var pose=Transform3D(Basis.IDENTITY,Vector3(at.x,source_height(model,at),at.y))
  if owner=="native_prop":
   var target=groups if props.owns(serial) else extras
   if not target.has(serial):target[serial]=[]
   target[serial].append(pose)
  elif owner=="existing_tree_owner":
   if not trees.has(serial):trees[serial]=[]
   trees[serial].append(pose*ruby.tree_fit(serial))
  elif serial in range(12500,12536):
   if recovered_bank_cells.has(Vector2i(row.cell[0],row.cell[1])):
    represented.append([serial,row.cell[0],row.cell[1]]);continue
   if not banks.has(serial):banks[serial]=[]
   # Match the existing actual terrain datum; a walk bit alone never raises a cap.
   pose.origin.y+=.035
   pose.basis=Basis.IDENTITY.scaled(Vector3(1,maxf(.01,(pose.origin.y-model.terrain.WATER_HEIGHT)/2.10),1))
   banks[serial].append(pose)
  else:continue
  represented.append([serial,row.cell[0],row.cell[1]])
 props.batch(root,groups)
 var overlap=source_overlap_data()
 if not private_town and not overlap.is_empty():
  var field_groups={};var field_records=[]
  for row:Dictionary in overlap.source100_overlap_cells:
   if not row.restore_graphic:continue
   var serial=int(row.field_pg1);assert(props.owns(serial),"Restored field flower must reuse its existing original prop owner")
   var at=local_point(Vector2(row.village_cell[0],row.village_cell[1]));field_groups[serial]=[Transform3D(Basis.IDENTITY,Vector3(at.x,source_height(model,at),at.y))]
   field_records.append({"map":100,"cell":row.field_cell,"graphic":serial,"village_cell":row.village_cell})
  var first=root.get_child_count();props.batch(root,field_groups)
  for index in range(first,root.get_child_count()):root.get_child(index).set_meta("source100_overlap_graphics",field_records)
  root.set_meta("alyut_source100_overlap_graphics",field_records)
 if not extras.is_empty():
  var ready={}
  for serial in extras:ready[serial]=extra_prop(int(serial))
  load("res://scripts/forest/forest_kili_art.gd").batch_meshes(root,extras,ready,"CompleteAlyutNativeProp")
 for serial in trees:
  var first=root.get_child_count();assets.batch(root,assets.crossgate_tree(int(serial)),trees[serial],true)
  for i in range(first,root.get_child_count()):root.get_child(i).set_meta("alyut_complete_tree",serial)
 for serial in banks:
  var graphic:Dictionary=art.data().graphics[str(serial)]
  var node=MultiMeshInstance3D.new();node.name="CompleteAlyutBank_"+str(serial);node.multimesh=MultiMesh.new()
  node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=bank_owner.bank_mesh(int(serial),graphic)
  node.multimesh.instance_count=banks[serial].size()
  for i in banks[serial].size():node.multimesh.set_instance_transform(i,banks[serial][i])
  node.set_meta("source_graphic",serial);node.set_meta("source_poses",banks[serial]);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  root.add_child(node)
 if not recovered_banks.is_empty():
  var caps=load("res://scripts/forest/forest_east_bank_caps.gd")
  caps.build(root,recovered_banks)
  var joined=model.has_meta("east_alyut_parent_terrain")
  var terrain=model.get_meta("east_alyut_parent_terrain") if joined else model.terrain
  var key="alyut_recovered_bank_support_"+data().source.sha256
  if not terrain.has_meta(key):caps.append_pieces(terrain,bank_rows(joined));terrain.set_meta(key,true)
  root.set_meta("alyut_recovered_bank_support_count",recovered_banks.size())
 if private_town:context.build_banks(root,model)
 root.set_meta("alyut_complete_source_sha256",data().source.sha256)
 root.set_meta("alyut_complete_source_placements",represented);root.set_meta("alyut_complete_owner_counts",counts)
 root.set_meta("alyut_complete_existing_gates",data().placements.filter(func(row):return row.owner=="existing_gate_owner"))
