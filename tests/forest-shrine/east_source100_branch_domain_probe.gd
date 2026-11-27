extends SceneTree
## Read-only current Native support of the original-open outer crop, for branch grouping.
const Model=preload("res://scripts/forest/forest_model.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Army=preload("res://scripts/forest/crowd/army_runtime.gd")
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Display Handoff Proposal/"
func source_path()->String:return ROOT+"branch-domain-source.json"
func result_path()->String:return ROOT+"branch-domain-current.json"
func _initialize():run.call_deferred()
func run():
 var paths=[get_script().resource_path,"res://tests/forest-shrine/east_source100_branch_domain_probe.gd",source_path(),"res://scripts/forest/forest_model.gd","res://scripts/forest/forest_freyja_regions.gd","res://scripts/forest/forest_freyja_terrain.gd","res://scripts/forest/forest_east_road.gd","res://scripts/forest/crowd/army_runtime.gd"];var pins={}
 for path in paths:pins[path]=FileAccess.get_sha256(path)
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_path()));var bits=PackedByteArray();bits.resize(source.cells.size());var contexts=[]
 for index in 4:
  var area:String=["east_gate","south_gate","south_lakes","freyja"][index];var model=Model.new();model.reset(42,{},Regions.layout(area),false);var frame:Transform2D=Regions.frame(area);var nav=Army.navigation_data(model,true);nav.obstacle_min=nav.friendly_obstacle_min;nav.obstacle_max=nav.friendly_obstacle_max;nav.friendly_navigation=false;var native=ClassDB.instantiate("GoemonCrowdRuntime");native.set_navigation(nav);var count=0
  for i in source.cells.size():
   var cell:Array=source.cells[i];var p:Vector2=frame.inverse()*(Vector2(cell[0],cell[1])*3.)
   if native.ally_ground_clear(model.world_point(p),.35*model.falan_scale):bits[i]|=1<<index;count+=1
  contexts.append({"area":area,"bit":1<<index,"supported_points":count});native=null
 var changed=[]
 for path in pins:
  if pins[path]!=FileAccess.get_sha256(path):changed.append(path)
 var file=FileAccess.open(result_path(),FileAccess.WRITE);file.store_string(JSON.stringify({"source_hashes":pins,"source_changed":changed,"source_raw_sha256":source.source_raw_sha256,"point_count":bits.size(),"contexts":contexts,"radius":.35,"supported_owner_bits":Marshalls.raw_to_base64(bits),"scope":"READ ONLY actual existing Native-friendly point support; no private context activated, no scene resource/capture, route, height or collider changed. Point support does not prove an edge, display handoff or original-route fidelity."},"  "));file.close();print("EAST100_BRANCH_DOMAIN points=",bits.size()," contexts=",contexts," changed=",changed);quit(changed.size())
