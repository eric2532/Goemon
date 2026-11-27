extends RefCounted
## Private source100 host owner. Terrain installation remains unhooked/pending;
## the original-destination preflight is usable by the one review dispatcher.
const SHORE="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Host/shore-interface-plan.json"
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/Host/Original100 Candidate/"
const Field=preload("res://scripts/forest/forest_east_host_source_field.gd")
const Caps=preload("res://scripts/forest/forest_east_bank_caps.gd")
const Solids=preload("res://scripts/forest/forest_art.gd")
const WaterCamera=preload("res://scripts/forest/forest_original_water_camera.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
static var native_bits:Dictionary={}
static var shore_cells:Dictionary={}
static var products:Dictionary={}
static var fields:Dictionary={}
static var materials:Dictionary={}
static var terrains:Dictionary={}
static var domains:Dictionary={}

static func manifest()->Dictionary:
 if products.is_empty() and FileAccess.file_exists(ROOT+"manifest.json"):products=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
 return products
static func ready(restore:Dictionary)->bool:
 var data=manifest()
 if data.is_empty() or data.raw_sha256!=restore.raw_sha256 or not FileAccess.file_exists(ROOT+"contract-proof.json") or not FileAccess.file_exists(ROOT+"player-boundaries.json"):return false
 var proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"contract-proof.json"))
 if int(proof.get("failures",1))!=0 or proof.get("raw_sha256","")!=restore.raw_sha256 or not proof.get("source_changed",["unverified"]).is_empty():return false
 var hashes:Dictionary=proof.get("source_hashes",{})
 if hashes.is_empty():return false
 var verified={}
 for path:String in hashes:
  var normalized=path if path.begins_with("res://") or path.is_absolute_path() else "res://"+path
  if FileAccess.get_sha256(normalized)!=str(hashes[path]):return false
  verified[normalized]=true
 for path:String in ["res://scripts/forest/forest_east_host_source_context.gd","res://scripts/forest/forest_east_host_source_field.gd","res://tools/prepare_east_host100_fields.py","res://tools/prepare_east_host100_boundaries.py",ROOT+"manifest.json",ROOT+"player-boundaries.json",restore.raw_path,data.areas.east_gate.path,data.areas.north_coast.path]:
  if not verified.has(path):return false
 for area:String in ["east_gate","north_coast"]:
  var row:Dictionary=data.areas[area]
  if FileAccess.get_sha256(row.path)!=row.sha256:return false
 var boundaries:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"player-boundaries.json"))
 if boundaries.raw_sha256!=restore.raw_sha256 or not boundaries.source_changed.is_empty():return false
 for area:String in data.areas:
  if boundaries.areas[area].field_sha256!=data.areas[area].sha256:return false
 return bool(proof.get("concrete_owner_ready",false))
static func reset():
 products={};fields.clear();materials.clear();native_bits.clear();shore_cells.clear();terrains.clear();domains.clear()
static func data(area:String)->Dictionary:
 if not fields.has(area):
  var spec:Dictionary=manifest().areas[area];assert(FileAccess.get_sha256(spec.path)==spec.sha256,"Private100field products changed")
  fields[area]=JSON.parse_string(FileAccess.get_file_as_string(spec.path))
 return fields[area]
static func owns(model)->bool:return model.falan_area in ["east_gate","north_coast"] and model.terrain.get_meta("east_source100_context_private",false)
static func terrain_for(area:String):
 if not terrains.has(area):
  var terrain=Field.new();terrain.setup(data(area));terrains[area]=terrain
  terrain.source_open(Vector2i.ZERO)
  var grid=Rect2(Vector2(terrain.proposal.origin[0],terrain.proposal.origin[1]),Vector2.ONE*(terrain.width-1)*terrain.spacing)
  var region=Rect2i(-80,-80,160,160)
  if area=="east_gate":
   var bounds:Rect2=terrain.mask_bounds();var low=Vector2i((bounds.position/6.).floor());region=Rect2i(low,Vector2i((bounds.end/6.).ceil())-low)
  domains[area]=grid.intersection(Rect2(Vector2(region.position)*6.-Vector2.ONE*3.,Vector2(region.size)*6.))
 return terrains[area]
static func configure_model(model,restore:Dictionary):
 assert(model.falan_area in ["east_gate","north_coast"] and model.ramparts.is_empty(),"Private original100review uses the existing regional layouts, never user-authored maps")
 var proposal=data(model.falan_area);assert(proposal.raw_sha256==restore.raw_sha256,"All100consumers require the same merged source")
 var reference=model.terrain;model.terrain=terrain_for(model.falan_area);terrain_for("north_coast" if model.falan_area=="east_gate" else "east_gate")
 model.set_meta("east_source100_reference_terrain",reference);model.set_meta("east_source100_context_private",true)
 load_shore_cells()
 prepare_tiles()
static func original_disk(terrain,at:Vector2,radius:float,scale_:float)->bool:
 var center:float=terrain._covered_height(at.x,at.y)
 if not is_finite(center):return false
 for axis:Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(.707,.707),Vector2(-.707,.707),Vector2(.707,-.707),Vector2(-.707,-.707)]:
  var p=at+axis*radius;var height:float=terrain._covered_height(p.x,p.y)
  if not is_finite(height) or absf(height-center)>.15/scale_+radius*.35:return false
 # The complete original source-cell obstacle contract includes Native's
 # existing0.05m padding; this is bounded to the nearby3×3source cells.
 var cell:Vector2i=terrain.source_cell(at);var expanded=radius+.05/scale_
 var extent=ceili((radius+1.5+.05/scale_)/3.)
 for dz in range(-extent,extent+1):
  for dx in range(-extent,extent+1):
   var neighbor=cell+Vector2i(dx,dz)
   if terrain.source_open(neighbor):continue
   var p:Vector2=terrain.source_point(Vector2(neighbor));var gap=(at-p).abs()-Vector2.ONE*1.5
   if Vector2(maxf(gap.x,0.),maxf(gap.y,0.)).length_squared()<expanded*expanded:return false
 return true
static func scene_handoff(model,before:Vector2,at:Vector2,radius:float)->Dictionary:
 if not owns(model) or not before.is_finite() or not at.is_finite() or not is_finite(radius) or radius<=0:return {}
 var area:String=model.falan_area
 if not domains.has(area):return {}
 var delta=at-before;var domain:Rect2=domains[area];var guard=maxf(3.,radius+.05/model.falan_scale);var outward=false
 if at.x<domain.position.x+guard and delta.x<-.000001:outward=true
 if at.x>domain.end.x-guard and delta.x>.000001:outward=true
 if at.y<domain.position.y+guard and delta.y<-.000001:outward=true
 if at.y>domain.end.y-guard and delta.y>.000001:outward=true
 if not outward:return {}
 var target_area="north_coast" if area=="east_gate" else "east_gate"
 if not terrains.has(target_area):return {}
 var source_frame:Transform2D=Regions.frame(area);var target_frame:Transform2D=Regions.frame(target_area)
 var source_at:Vector2=source_frame*at;var cell=Vector2i((source_at/3.).round())
 if not scene_contains(cell):return {}
 var arrival:Vector2=target_frame.inverse()*source_at;var target=terrains[target_area];var target_domain:Rect2=domains[target_area]
 if not target_domain.grow(-guard).has_point(arrival) or not target.source_open(cell) or not original_disk(target,arrival,radius,model.falan_scale):return {}
 return {"area":target_area,"arrival":arrival,"rotation":target_frame.get_rotation()-source_frame.get_rotation(),"source":100,"source_float":source_at/3.,"source_cell":cell,"display_boundary_only":true}
static func add_navigation(nav:Dictionary,model):
 if not owns(model):return
 var exact:Dictionary=model.terrain.native_data()
 for key in ["width","spacing","route_spacing","origin","heights","covered","pieces"]:nav[key]=exact[key]
 if exact.has("diagonal_flips"):nav.diagonal_flips=exact.diagonal_flips
 for key in ["obstacle_min","obstacle_max"]:
  nav[key].append_array(exact[key])
  if nav.has("friendly_"+key):nav["friendly_"+key].append_array(exact[key])
static func build(root:Node3D,model):
 if not owns(model) or root.has_meta("east_source100_context_built"):return
 var terrain=model.terrain;var groups={}
 for index_ in terrain.proposal.bank_cells:
  var index=int(index_);var cell=Vector2i(index%840,index/840);var serial_=terrain.serial(cell,1)
  if serial_ not in range(12500,12536):continue
  var at:Vector2=terrain.source_point(Vector2(cell));var frame=Basis(Vector3.UP,-PI*.5) if model.falan_area=="east_gate" else Basis.IDENTITY
  if not groups.has(serial_):groups[serial_]=[]
  groups[serial_].append(Transform3D(frame,Vector3(at.x,2.1,at.y)))
 for serial_:int in groups:
  var node=MultiMeshInstance3D.new();node.name="Original100NativeBank_"+str(serial_);node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
  node.multimesh.mesh=Caps.mesh(serial_,.100);node.multimesh.instance_count=groups[serial_].size()
  for index in groups[serial_].size():node.multimesh.set_instance_transform(index,groups[serial_][index])
  node.set_meta("source_map",100);node.set_meta("source_graphic",serial_);node.set_meta("prepared_poses",groups[serial_]);root.add_child(node)
 var boundaries:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"player-boundaries.json"))
 assert(boundaries.areas[model.falan_area].field_sha256==manifest().areas[model.falan_area].sha256,"Player boundary and Native fields require the same prepared source")
 var holder=Node3D.new();holder.name="Original100SourceBoundaries";root.add_child(holder)
 holder.transform=Transform3D(Basis(Vector3.UP,-PI*.5),Vector3(591,0,-1251)) if model.falan_area=="east_gate" else Transform3D(Basis.IDENTITY,Vector3(-1902,0,-333))
 var bits=Marshalls.base64_to_raw(boundaries.native_walk_bits);var boundary_raw=FileAccess.get_file_as_bytes(boundaries.boundary_metadata_raw_path)
 assert(FileAccess.get_sha256(boundaries.boundary_metadata_raw_path)==boundaries.boundary_metadata_raw_sha256,"Boundary-only complete-source evidence changed")
 for row:Array in boundaries.areas[model.falan_area].runs:
  var along_x=bool(row[0]);var line=int(row[1]);var start=int(row[2]);var end=int(row[3]);var p=Vector2((start+end-1)*1.5,line*3.-1.5) if along_x else Vector2(line*3.-1.5,(start+end-1)*1.5)
  var extent=Vector3((end-start)*3.,40.,.04) if along_x else Vector3(.04,40.,(end-start)*3.)
  var body=Solids.solid(holder,Vector3(p.x,10.,p.y),extent,1,"stone");body.name="OriginalSourceBoundary_"+str(holder.get_child_count())
  WaterCamera.record(root,body,boundary_raw,bits,Vector2i(840,610),along_x,line,start,end)
 root.set_meta("east_source100_context_built",true)
static func prepare_world(world,player):
 if not owns(world.model):return
 var bounds:Rect2=world.model.terrain.mask_bounds();var scale_:float=world.model.falan_scale
 world.playable_bounds=Rect2(bounds.position*scale_,bounds.size*scale_).grow(2.*player.growth_multiplier())
static func apply_materials(ground:ShaderMaterial,water:ShaderMaterial,terrain):
 if not terrain.get_meta("east_source100_context_private",false):return
 var context=load("res://scripts/forest/forest_east_source_context_review.gd");var art=load("res://scripts/forest/forest_freyja_art.gd")
 var atlas:Texture2D=context.field_ground_atlas();prepare_tiles()
 ground.set_shader_parameter("freyja_ground_index",context.field_ground_index());ground.set_shader_parameter("freyja_ground_atlas",art.ground_tiles(atlas))
 ground.set_shader_parameter("use_connected_village",false);water.set_shader_parameter("use_connected_village",false)
 water.set_shader_parameter("layout_mask",terrain.mask_texture());water.set_shader_parameter("island",false)
static func prepare_tiles():
 var context=load("res://scripts/forest/forest_east_source_context_review.gd");var art=load("res://scripts/forest/forest_freyja_art.gd");var atlas:Texture2D=context.field_ground_atlas()
 if not art.tile_arrays.has(atlas):
  var image:Image=atlas.get_meta("source_cpu_image");var images:Array[Image]=[]
  for y in image.get_height()/36:
   for x in 32:
    var tile=image.get_region(Rect2i(x*36+2,y*36+2,32,32));tile.generate_mipmaps();images.append(tile)
  var array_=Texture2DArray.new();assert(array_.create_from_images(images)==OK);art.tile_arrays[atlas]=array_

static func area_for(cell:Vector2i)->String:
 return "north_coast" if cell.y<100 and cell.x>510 or cell.x>670 and cell.y<210 else "east_gate"

static func point(cell:Vector2i,area:String)->Vector2:
 return Vector2(cell.x*3.-1902.,cell.y*3.-333.) if area=="north_coast" else Vector2(591.-cell.y*3.,cell.x*3.-1251.)

static func scene_contains(cell:Vector2i)->bool:
 var area=area_for(cell);var at=point(cell,area)
 var bounds=Rect2(-481.5,-481.5,963,963) if area=="north_coast" else Rect2(-676.5,-205.5,1161,1377)
 if not bounds.has_point(at) or cell.x<440:return false
 # Preserve explicit other-goal boundaries. The core source inventory ends
 # at360; the two detached village footprints and audited coast are explicit
 # additions, not permission to route into every overlapping world envelope.
 if cell.y<360 or Rect2i(636,312,90,111).has_point(cell) or Rect2i(529,20,100,100).has_point(cell):return true
 load_shore_cells()
 return shore_cells.has(cell)
static func load_shore_cells():
 if not shore_cells.is_empty():return
 var proof:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SHORE))
 for row:Dictionary in proof.private_connected_shore_rows:shore_cells[Vector2i(row.cell[0],row.cell[1])]=true

static func can_travel(source:int,cell:Vector2i,restore:Dictionary)->bool:
 if source!=100 or not Rect2i(0,0,840,610).has_point(cell) or not scene_contains(cell):return false
 var key:String=restore.raw_sha256
 if not native_bits.has(key):
  var bits=Marshalls.base64_to_raw(restore.native_walk_bits)
  assert(bits.size()==64050,"Original source100 preflight requires the complete pinned-sized native bitset")
  native_bits[key]=bits
 var index=cell.y*840+cell.x
 return bool(native_bits[key][index>>3]&(1<<(index&7)))
