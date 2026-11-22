extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
func _initialize():run.call_deferred()
func run():
 var model=Model.new();var layout=JSON.parse_string(FileAccess.get_file_as_string("res://tests/forest-shrine/reference/maps/forest_falan_city.json"));model.reset(42,{},layout,false)
 for row in Tour.Indoor.Data.DOORS[1000]:
  var at:Vector2=row[0];var p=Vector3(at.x,model.surface_height(at.x,at.y)+.4,at.y)
  var blocked=[]
  for anchor in model.scenery_obstacles:
   if model.scenery_obstacles[anchor].grow(.55).has_point(p):blocked.append([str(anchor),str(model.scenery_obstacles[anchor]),str(model.props.get(anchor,{}))])
  if not blocked.is_empty():print("SOURCE_DOOR_BLOCKED ",row," ",blocked)
 print("CLEARANCE_SCAN_DONE");quit()
