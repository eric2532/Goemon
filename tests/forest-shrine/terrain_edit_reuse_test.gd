extends SceneTree
const Document=preload("res://scripts/forest/forest_map_document.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const Kit=preload("res://scripts/forest/forest_environment_kit.gd")
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
var checks=0
var failures=0
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():run.call_deferred()
func run():
 var data=JSON.parse_string(FileAccess.get_file_as_string(Document.WIND_MEADOW_PATH))
 data.trees=data.trees.filter(func(item):return not Rect2i(-32,8,20,22).has_point(Vector2i(item.x,item.z)))
 data.trees.append({"x":-23,"z":14,"scale":1,"rotation":0})
 data.props=[{"kind":"stone_block","x":-22,"z":14,"scale":1,"rotation":0},{"kind":"stone_block","x":-22,"z":14,"scale":1,"rotation":0,"height":6}]
 var model=Model.new();model.reset(42,{},data,false);var terrain=model.terrain
 var untouched=Vector2i(40,40);var previous_cliff:bool=terrain.cliff_cell(untouched)
 var layouts=[Kit.placement("platform_18",Vector2(-24,14),0,0),Kit.placement("platform_18",Vector2(-24,14),0,12),Kit.placement("corner_18",Vector2(-24,14),1,0),Kit.placement("t_junction_18",Vector2(-24,14),2,0),[]]
 for pieces in layouts:
  data.ramparts=pieces
  check(Document.validate(data).is_empty(),"Prepared regression layout validates")
  model.update_editor_terrain(data);model.update_scenery(data)
  var fresh=Model.new();fresh.reset(42,{},data,false)
  var same=true
  for x in range(model.navigation_region.position.x,model.navigation_region.end.x):
   for z in range(model.navigation_region.position.y,model.navigation_region.end.y):
    var cell=Vector2i(x,z)
    if model.allied_grid.is_point_solid(cell)!=fresh.allied_grid.is_point_solid(cell) or model.enemy_grid.is_point_solid(cell)!=fresh.enemy_grid.is_point_solid(cell):same=false
  check(same,"Every allied/enemy grid cell matches a complete rebuild")
  check(model.terrain==terrain and terrain.cliff_cache.has(untouched) and terrain.cliff_cache[untouched]==previous_cliff,"Unchanged terrain and distant cliff results are retained")
  check(model.scenery_obstacles==fresh.scenery_obstacles,"Trees and independent stacked layers use the new support height")
  var incremental=Runtime.navigation_data(model);var rebuilt=Runtime.navigation_data(fresh)
  check(incremental==rebuilt,"The native owner receives exactly the same terrain, obstacles and rays as a complete rebuild")
  for x in range(-27,-17):
   for z in range(8,21):
    check(is_equal_approx(model.surface_height(x*6,z*6),fresh.surface_height(x*6,z*6)),"Local support heights match")
 print("TERRAIN_EDIT_REUSE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
