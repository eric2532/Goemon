extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
## Run through Play Goemon with -- --east-il-road; --baseline records the old view.

func check_east_il_road():
 game.tuning.invincible=true
 var edge:float=Tour.Frontier.OUTER_EDGE.east_gate
 await position_at(Tour.Frontier.to_city("east_gate",Vector2(3,edge-1)))
 await position_at(Tour.Frontier.to_city("east_gate",Vector2(3,edge+1)))
 check(Tour.area(game.model)=="east_gate","Walking out of Falan reaches the East Gate countryside")
 if Tour.area(game.model)!="east_gate":return
 var start=map_position()
 check((Tour.Regions.frame("east_gate")*start/3.0).distance_to(Vector2(475,196))<.1,
  "The beginner landing retains its original Blue CG tile")
 check(road_connected(start,Vector2(-108,411),.55),"The original beginner road remains connected to the river crossing")
 var before="--baseline" in OS.get_cmdline_user_args()
 if not before:check_scenery()
 if DisplayServer.get_name()!="headless":
  var label="before" if before else "after"
  var scale_:float=game.model.falan_scale
  await shot("East Gate Beginner Area/"+label+"-landing",Vector3(3,14,164)*scale_,Vector3(-6,10,215)*scale_,63)
  await shot("East Gate Beginner Area/"+label+"-woodland",Vector3(72,77,190)*scale_,Vector3(-18,6,258)*scale_,64)
  await shot("East Gate Beginner Area/"+label+"-road",Vector3(-19,13,218)*scale_,Vector3(-61,9,255)*scale_,63)
 await position_at(start)
 game.camera_rig.yaw=PI
 Input.action_press("move_forward")
 for i in 90:await physics_frame
 Input.action_release("move_forward")
 check(map_position().y>start.y+5.0 and game.player.is_on_floor(),"The player walks forward from the gate on the original ground")
 await position_at(Vector2(3,edge+1))
 await position_at(Vector2(3,edge-1))
 check(Tour.area(game.model)=="city","The original gate still returns to Falan on foot")
 print("EAST_GATE_SCENERY_RESULT failures=",errors)

func check_scenery():
 var frontier=Tour.Frontier
 var mask:Image=game.model.terrain.mask_texture().get_image()
 var origin:Vector2=game.model.terrain.mask_origin()
 var source_pixels=mask.get_data()
 var forts=preload("res://scripts/forest/forest_falan_fortifications.gd")
 forts.water_mask(game.model.terrain.mask_texture(),origin,[game.model.terrain.il_bridge_bounds()])
 check(game.model.terrain.mask_texture().get_image().get_data()==source_pixels,"Building the river water mask cannot overwrite the shared road mask")
 check(not frontier.east_scatter_clear(mask,origin,Vector2(3,174)),"Decorative scatter stays off the beginner landing")
 check(not frontier.east_scatter_clear(mask,origin,Vector2(900,900)),"Decorative scatter rejects positions beyond the archive")
 var woodland=game.world.find_child("FreyjaOuterRoads",true,false)
 var plants=game.world.find_child("ArchivedEastGatePlants",true,false)
 check(is_instance_valid(plants) and plants.get_child_count()>=3,"Recovered flowers, grasses and rocks are rendered")
 var species={}
 for child in woodland.get_children():
  if child is MultiMeshInstance3D:
   for kind in ["cedar_tree","pine_tree","broadleaf_tree"]:
    if str(child.name).begins_with(kind):species[kind]=true
 check(species.size()==3,"The original woodland uses all three existing tree silhouettes")
 check(game.model.falan_frontier_plan==frontier.outer_plan(game.model),"Visual restoration leaves the native scenery and obstacle plan unchanged")
 var anchors={}
 for row in frontier.EastScenery.DETAILS:anchors[Tour.Regions.frame("east_gate").inverse()*(row[0]*3.0)]=true
 var count=0
 for child in plants.get_children():
  if child is not MultiMeshInstance3D:continue
  count+=child.multimesh.instance_count
  # The headless dummy renderer does not retain MultiMesh transform buffers.
  if DisplayServer.get_name()=="headless":continue
  for i in child.multimesh.instance_count:
   var p:Vector3=child.multimesh.get_instance_transform(i).origin
   var at=Vector2(p.x,p.z)
   check(anchors.has(at),"Each restored detail retains an original Blue CG anchor")
   check(frontier.east_scatter_clear(mask,origin,at),"Restored scenery leaves the original road and water clear")
 check(count>20,"The restored woodland includes more than twenty original small details")
 var road_clutter=0
 var chunks=[] if DisplayServer.get_name()=="headless" else game.world.find_children("Foliage_*","Node3D",true,false)
 for child in chunks:
  for batch in child.get_children():
   if batch is not MultiMeshInstance3D:continue
   for i in batch.multimesh.instance_count:
    var p:Vector3=batch.multimesh.get_instance_transform(i).origin+child.position
    if p.z>=153.0 and not frontier.east_scatter_clear(mask,origin,Vector2(p.x,p.z)):road_clutter+=1
 if DisplayServer.get_name()!="headless":check(road_clutter==0,"Ambient foliage batches also keep the East Gate road clear")
 print("EAST_GATE_DETAILS instances=",count," species=",species.keys()," road_clutter=",road_clutter if DisplayServer.get_name()!="headless" else "GPU buffers unavailable")
