extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Army=preload("res://scripts/forest/crowd/army_runtime.gd")
const DEST="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Remote Views/"
func _initialize():run.call_deferred()
func run():
 var paths=["res://scripts/forest/forest_model.gd","res://scripts/forest/forest_freyja_regions.gd","res://scripts/forest/forest_freyja_terrain.gd","res://scripts/forest/forest_east_road.gd","res://scripts/forest/crowd/army_runtime.gd","res://assets/maps/falan/freyja_residual/full/data.gd"];var pins={}
 for path in paths:pins[path]=FileAccess.get_sha256(path)
 var model=Model.new();model.reset(42,{},Regions.layout("east_gate"),false);var nav=Army.navigation_data(model,true);var rows=[]
 for cell:Vector2i in [Vector2i(638,168),Vector2i(536,286),Vector2i(496,359),Vector2i(641,168),Vector2i(653,160)]:
  var at:Vector2=Regions.frame("east_gate").inverse()*(Vector2(cell)*3.);var center=Vector3(at.x,model.surface_height(at.x,at.y),at.y);var bounds=AABB(center-Vector3(1.5,10,1.5),Vector3(3,40,3));var obstacles=[];var source_blocks=[];var friendly=[]
  for key in model.scenery_obstacles:
   var box:AABB=model.scenery_obstacles[key]
   if box.intersects(bounds):obstacles.append({"key":var_to_str(key),"bounds":var_to_str(box),"contains_anchor":box.has_point(center)})
  for row:Array in model.falan_frontier_plan:
   if row[0]is String and row[0]=="freyja_source_collision"and row[2].intersects(bounds):source_blocks.append({"source_rect":row[3],"bounds":var_to_str(row[2]),"contains_anchor":row[2].has_point(center)})
  var world=center*model.falan_scale
  for index in nav.friendly_obstacle_min.size():
   var box=AABB(nav.friendly_obstacle_min[index],nav.friendly_obstacle_max[index]-nav.friendly_obstacle_min[index])
   if box.has_point(world):friendly.append({"index":index,"bounds":var_to_str(box)})
  var samples=[]
  for dz in [-1.,-.5,0.,.5,1.]:
   for dx in [-1.,-.5,0.,.5,1.]:
    var p=center+Vector3(dx,0,dz);var disks=[]
    for radius in [.25,.45,.55,.8]:disks.append({"radius":radius,"clear":model.terrain.disk_clear(p,radius)})
    samples.append({"offset":[dx,dz],"height":model.surface_height(p.x,p.z),"contains":model.terrain.contains(p.x,p.z),"disks":disks})
  rows.append({"source_cell":[cell.x,cell.y],"anchor":var_to_str(center),"bounds":var_to_str(bounds),"scenery_obstacles_intersecting":obstacles,"exact_source_block_records":source_blocks,"friendly_obstacles_containing_anchor":friendly,"terrain_samples":samples})
 var changed=[]
 for path in pins:
  if pins[path]!=FileAccess.get_sha256(path):changed.append(path)
 var file=FileAccess.open(DEST+"closed-cell-current.json",FileAccess.WRITE);file.store_string(JSON.stringify({"source_hashes":pins,"source_changed":changed,"rows":rows,"scope":"Current default CPU model/Native exporter only; no collision/height/visual mutation. Terrain disk booleans alone omit explicit Native obstacle authority, which is recorded separately."},"  "));file.close();print("EAST100_CLOSED_CELL_CURRENT rows=",rows.size()," changed=",changed);quit(0 if changed.is_empty()else 1)
