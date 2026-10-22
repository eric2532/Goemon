extends SceneTree
## Expanded navigation grids must fit in the terrain cache across gate revisions.
const Model=preload("res://scripts/forest/forest_model.gd")
class MeasuredTerrain extends "res://scripts/forest/forest_blood_gulch_terrain.gd":
 var samples=0
 func _sample_cliff_cell(cell:Vector2i)->bool:
  samples+=1;return super._sample_cliff_cell(cell)
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",note)
func run():
 var layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_blood_gulch.json"));layout.terrain_scale=1.2
 var m=Model.new();m.reset(90824,{},layout)
 var terrain=MeasuredTerrain.new();terrain.horizontal_scale=1.2;terrain.configure([]);m.terrain=terrain
 var region:Rect2i=m.enemy_grid.region
 m.rebuild_navigation();var samples=terrain.samples;var before=[]
 for x in range(region.position.x,region.end.x):
  for z in range(region.position.y,region.end.y):before.append(m.enemy_grid.is_point_solid(Vector2i(x,z)))
 var start=Time.get_ticks_usec();m.rebuild_navigation();var elapsed=Time.get_ticks_usec()-start
 check(terrain.samples==samples,"Changing only structure navigation reuses all expanded-map cliff results")
 var after=[]
 for x in range(region.position.x,region.end.x):
  for z in range(region.position.y,region.end.y):after.append(m.enemy_grid.is_point_solid(Vector2i(x,z)))
 check(before==after,"Reusing cliff results preserves the exact navigation topology")
 print("CLIFF_CACHE_REBUILD us=",elapsed," repeated_samples=",terrain.samples-samples," cached=",terrain.cliff_cache.size()," cells=",region.get_area())
 terrain.configure([]);samples=terrain.samples;m.rebuild_navigation()
 check(terrain.samples>samples,"Reconfiguring terrain invalidates cliff results")
 print("TERRAIN_CLIFF_CACHE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
