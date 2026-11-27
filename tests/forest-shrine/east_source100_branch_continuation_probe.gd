extends SceneTree
## Adaptive read-only flood; original-open gaps stop at real measured support, not crop edges.
const Model=preload("res://scripts/forest/forest_model.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Army=preload("res://scripts/forest/crowd/army_runtime.gd")
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Display Handoff Proposal/"
var source:Dictionary
var walk:PackedByteArray
var cache:Dictionary={}
var owners=[]
var new_samples=0
func _initialize():run.call_deferred()
func original_open(cell:Vector2i)->bool:
 if cell.x<0 or cell.y<0 or cell.x>=int(source.size[0])or cell.y>=int(source.size[1]):return false
 var index=cell.y*int(source.size[0])+cell.x;return bool(walk[index>>3]&(1<<(index&7)))
func protected_context(cell:Vector2i)->String:
 for row:Dictionary in source.protected_rectangles:
  var r:Array=row.rect
  if Rect2i(r[0],r[1],r[2],r[3]).has_point(cell):return row.kind
 return ""
func current_support(cell:Vector2i)->int:
 if cache.has(cell):return cache[cell]
 var bits=0;new_samples+=1
 for i in owners.size():
  var row:Dictionary=owners[i];var point:Vector2=row.frame.inverse()*(Vector2(cell)*3.)
  if row.native.ally_ground_clear(row.model.world_point(point),.35*row.model.falan_scale):bits|=1<<i
 cache[cell]=bits;return bits
func run():
 var paths=[get_script().resource_path,ROOT+"branch-flood-source.json","res://scripts/forest/forest_model.gd","res://scripts/forest/forest_freyja_regions.gd","res://scripts/forest/forest_freyja_terrain.gd","res://scripts/forest/forest_east_road.gd","res://scripts/forest/crowd/army_runtime.gd"];var pins={}
 for path in paths:pins[path]=FileAccess.get_sha256(path)
 source=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"branch-flood-source.json"));walk=Marshalls.base64_to_raw(source.source_walk_bits);var bits=Marshalls.base64_to_raw(source.cached_current_native_owner_bits)
 for i in source.cached_cells.size():cache[Vector2i(source.cached_cells[i][0],source.cached_cells[i][1])]=bits[i]
 for area in ["east_gate","south_gate","south_lakes","freyja"]:
  var model=Model.new();model.reset(42,{},Regions.layout(area),false);var nav=Army.navigation_data(model,true);nav.obstacle_min=nav.friendly_obstacle_min;nav.obstacle_max=nav.friendly_obstacle_max;nav.friendly_navigation=false;var native=ClassDB.instantiate("GoemonCrowdRuntime");native.set_navigation(nav);owners.append({"area":area,"model":model,"native":native,"frame":Regions.frame(area)})
 var branches=[]
 for row:Dictionary in source.branches:
  var pending=[];var seen={};var supported=[];var protected=[]
  for p:Array in row.seeds:var cell=Vector2i(p[0],p[1]);pending.append(cell);seen[cell]=true
  var at=0
  while at<pending.size():
   var cell:Vector2i=pending[at];at+=1
   for delta:Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    var next=cell+delta
    if seen.has(next)or not original_open(next):continue
    var kind=protected_context(next)
    if not kind.is_empty():protected.append({"source_from":[cell.x,cell.y],"source_to":[next.x,next.y],"context":kind});continue
    var value=current_support(next)
    if value:supported.append({"source_from":[cell.x,cell.y],"source_to":[next.x,next.y],"owner_bits":value});continue
    seen[next]=true;pending.append(next)
  var cells=[]
  for p:Vector2i in pending:cells.append([p.x,p.y])
  branches.append({"id":row.id,"unsupported_original_open_cells":cells,"measured_supported_boundaries":supported,"protected_original_open_boundaries":protected})
 var changed=[]
 for path in pins:
  if pins[path]!=FileAccess.get_sha256(path):changed.append(path)
 var file=FileAccess.open(ROOT+"branch-continuation-current.json",FileAccess.WRITE);file.store_string(JSON.stringify({"source_hashes":pins,"source_changed":changed,"source_raw_sha256":source.source_raw_sha256,"new_Native_point_samples":new_samples,"radius":.35,"owner_bits":{"east_gate":1,"south_gate":2,"south_lakes":4,"freyja":8},"branches":branches,"scope":"READ ONLY adaptive original-open source flood to measured current Native support or exact protected context. No crop-edge wall, new route, display handoff or source/art/Native mutation. Supported point boundaries still require concrete edge/transfer/player proof."},"  "));file.close();print("EAST100_BRANCH_CONTINUATION branches=",branches.size()," new_samples=",new_samples," changed=",changed);owners.clear();quit(changed.size())
