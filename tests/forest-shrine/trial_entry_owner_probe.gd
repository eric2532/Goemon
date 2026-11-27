extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Army=preload("res://scripts/forest/crowd/army_runtime.gd")
func _initialize():run.call_deferred()
func run():
 var native=Army.new();assert(native.configure(null,64));var rows=[]
 for area in ["freyja","east_gate","south_gate","west_lakes","north_coast","south_lakes","east_coast"]:
  var model=Model.new();model.reset(41829558,{},Regions.layout(area),false)
  var point:Vector2=Regions.frame(area).inverse()*(Vector2(351,145)*3.)
  var world=model.world_point(point)
  native.native.set_navigation(Army.navigation_data(model))
  rows.append({"area":area,"source_cell":[351,145],"local_point":str(point),"terrain_clear":model.terrain.disk_clear(world/model.falan_scale,.5),"friendly_clear":native.native.ally_ground_clear(world,.5),"enemy_clear":native.native.can_reach(world,world,.5)})
 native.free();await process_frame
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Trial caves/source-entry-owners.json",FileAccess.WRITE);file.store_string(JSON.stringify({"rows":rows,"qualification":"Native/model support only; source entrance, visible scenery and actual control transition remain separate."},"  ")+"\n");file.close()
 print("TRIAL_ENTRY_OWNERS ",JSON.stringify(rows));quit(0)
