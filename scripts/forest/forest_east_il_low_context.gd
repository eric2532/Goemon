extends RefCounted
## Private integration candidate only. A fixture must explicitly inject this
## script is delegated by the one Regions.private_source_context adapter;
## no shared caller is enrolled here.
const Field=preload("res://scripts/forest/forest_east_il_low_source.gd")
const Il=preload("res://scripts/forest/forest_east_il_source_completion.gd")
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/"
static var manifest:Dictionary={}
static var shore:Dictionary={}

static func data()->Dictionary:
 if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"Low Source Candidate/data.json"))
 return manifest
static func owns(model)->bool:return model.falan_area=="il_village" and model.terrain.get_meta("east_il_low_source_private",false)
static func host(model)->bool:return model.falan_area=="east_gate"
static func local_source(source:int)->bool:return source==2000
static func point(cell:Vector2i)->Vector2:return Vector2(-135,-180)+Vector2(cell)*3.
static func source_id(model)->int:return 2000 if owns(model) else 100 if host(model) else -1
static func can_travel(cell:Vector2i)->bool:return Il.source_open(cell)
static func suppress_joined(area:String)->bool:return area=="east_gate"
static func layout()->Dictionary:
 return load("res://scripts/forest/forest_freyja_regions.gd").layout("il_village")
static func arrival_yaw(game,source:int)->float:
 # Preserve source-axis facing between the rotated field presentation and
 # original local village frame; the original table itself supplies no yaw.
 return game.camera_rig.yaw+PI*.5 if source==2000 and host(game.model) else game.camera_rig.yaw-PI*.5 if source==100 and owns(game.model) else game.camera_rig.yaw

static func configure_model(model):
 if model.falan_area!="il_village":return
 var terrain=Field.new();terrain.setup(data());model.terrain=terrain;model.falan_road=""
 var bounds:Rect2=terrain.mask_bounds();var low=Vector2i((bounds.position/6.).floor());var high=Vector2i((bounds.end/6.).ceil())
 model.navigation_region=Rect2i(low,high-low);model.set_meta("east_il_low_source_private",true)

static func add_navigation(nav:Dictionary,model):
 if not owns(model):return
 var exact:Dictionary=model.terrain.native_data(1.)
 for key in ["width","spacing","route_spacing","origin","bounds_min","bounds_max","heights","covered","pieces"]:nav[key]=exact[key]
 for key in ["obstacle_min","obstacle_max"]:
  nav[key].append_array(exact[key])
  var friendly="friendly_"+key
  if nav.has(friendly):nav[friendly].append_array(exact[key])

static func links_model(model)->Array:
 var region=load("res://scripts/forest/forest_east_region.gd");var result=[]
 if owns(model):
  result=region.links_source(2000,model.seed_value)
  result.append(region.destination_link(point(Vector2i(45,31)),100,Vector2i(682,343)))
 elif host(model):
  result=region.links_source(100,model.seed_value,"east_gate")
  result.append(region.destination_link(region.source_point(100,Vector2i(681,343),"east_gate"),2000,Vector2i(44,31)))
 return result

static func merge_links(model,legacy:Array)->Array:
 if not owns(model):return legacy
 # The compiled original rows own all seven fixed interior/dock connections;
 # legacy scene hints must not retain another exit or override their cells.
 return legacy.filter(func(link):return link.to not in ["freyja_door","freyja_return","freyja_outside","city","castle","interior"])

static func build_banks(root:Node3D,model):
 if not owns(model):return
 if shore.is_empty():shore=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"Whole Shore Candidate/banks.json"))
 model.terrain.build_bank_visuals(root,shore.rows)

static func prepare_world(world,player):
 if not owns(world.model):return
 var terrain=world.model.terrain;var scale_:float=world.model.falan_scale;var bounds:Rect2=terrain.mask_bounds()
 # Match the existing Player contraction; collision edges enforce the exact
 # source rectangle, including the16original-open top-row cells.
 world.playable_bounds=Rect2(bounds.position*scale_,bounds.size*scale_).grow(2.*player.growth_multiplier())
 if world.map_features.has_meta("east_il_low_boundary_runs"):return
 var maps=load("res://scripts/forest/forest_original_maps.gd");var raw=FileAccess.get_file_as_bytes(Il.ROOT+"hybrid-map.bin");var bits=Marshalls.base64_to_raw(data().walk_bits)
 var before=world.map_features.get_child_count();var walls=maps.boundaries(world.map_features,bits,Vector2i(90,120),Vector2(-135,-180),raw)
 for index in range(before,world.map_features.get_child_count()):
  var node=world.map_features.get_child(index);node.set_meta("source_map",2000);node.set_meta("east_il_low_source_boundary",true)
 world.map_features.set_meta("east_il_low_boundary_runs",walls.size())

static func npc_sources(model)->Array:
 return [2000] if owns(model) else [100] if host(model) else []
