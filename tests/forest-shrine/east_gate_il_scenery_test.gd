extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
## Play Goemon --script this file -- --east-il-road; --baseline captures the old scenery.

func check_east_il_road():
 await super.check_east_il_road()
 if Tour.area(game.model)!="east_coast":return
 var before="--baseline" in OS.get_cmdline_user_args()
 if not before:check_coast_scenery()
 if DisplayServer.get_name()!="headless":
  var label="before" if before else "after"
  var scale_:float=game.model.falan_scale
  await shot("East Gate to Il/"+label+"-river",Vector3(-310,24,-61)*scale_,Vector3(-268,6,-86)*scale_,59)
  await shot("East Gate to Il/"+label+"-road",Vector3(-155,89,-36)*scale_,Vector3(-55,5,50)*scale_,63)
  await shot("East Gate to Il/"+label+"-village",Vector3(166,46,207)*scale_,Vector3(98,8,247)*scale_,58)
 await walk_river_bridge()
 print("EAST_GATE_IL_SCENERY_RESULT failures=",errors)

func check_coast_scenery():
 var frontier=Tour.Frontier
 var woodland=game.world.find_child("FreyjaOuterRoads",true,false)
 var plants=game.world.find_child("ArchivedEastGatePlants",true,false)
 check(is_instance_valid(plants),"The recovered scenery continues across the river toward Il")
 if not is_instance_valid(plants):return
 var species={}
 for child in woodland.get_children():
  if child is MultiMeshInstance3D:
   for kind in ["cedar_tree","pine_tree","broadleaf_tree"]:
    if str(child.name).begins_with(kind):species[kind]=true
 check(species.size()==3,"The Il road reuses the three existing tree silhouettes")
 check(game.model.falan_frontier_plan==frontier.outer_plan(game.model),"The existing native obstacles remain unchanged")
 var frame=Tour.Regions.frame("east_coast")
 var anchors={}
 for row in frontier.EastScenery.DETAILS:anchors[row[0]]=true
 var mask:Image=game.model.terrain.mask_texture().get_image()
 var origin:Vector2=game.model.terrain.mask_origin()
 var count=0
 for batch in plants.get_children():
  if batch is not MultiMeshInstance3D:continue
  count+=batch.multimesh.instance_count
  if DisplayServer.get_name()=="headless":continue
  for i in batch.multimesh.instance_count:
   var p:Vector3=batch.multimesh.get_instance_transform(i).origin
   var at=Vector2(p.x,p.z)
   check(anchors.has((frame*at/3.0).round()),"Each Il road detail retains its Blue CG source tile")
   check(frontier.east_scatter_clear(mask,origin,at),"Restored details keep roads and waterways clear")
 check(count>75,"The Il corridor restores its small flowers, grasses and rocks")
 var clutter=0
 if DisplayServer.get_name()!="headless":
  for chunk in game.world.find_children("Foliage_*","Node3D",true,false):
   for batch in chunk.get_children():
    if batch is not MultiMeshInstance3D:continue
    for i in batch.multimesh.instance_count:
     var p:Vector3=batch.multimesh.get_instance_transform(i).origin+chunk.position
     if not frontier.east_scatter_clear(mask,origin,Vector2(p.x,p.z)):clutter+=1
  check(clutter==0,"Ambient bushes and rocks leave the original Il road clear")
 print("IL_SCENERY instances=",count," species=",species.keys()," road_clutter=",clutter if DisplayServer.get_name()!="headless" else "GPU buffers unavailable")

func walk_river_bridge():
 var frame=Tour.Regions.frame("east_gate")
 var at=frame.inverse()*(Vector2(552,233)*3.0)
 Tour.travel(game,Tour.outdoor_layout(get_meta("falan_venture"),"east_gate"),{"arrival":at,"yaw":PI,"velocity":Vector3.ZERO})
 for i in 8:await physics_frame
 var bridge=game.world.find_child("IlRiverBridge",true,false)
 check(bridge!=null and bridge.has_node("OriginalSingleArch") and bridge.has_node("ArchivedGrassDeck"),"The original single-arch river bridge is retained")
 var low=INF
 Input.action_press("move_forward")
 for i in 210:
  await physics_frame
  if Tour.area(game.model) not in ["east_gate","east_coast"]:break
  var cell=Tour.Regions.frame(Tour.area(game.model))*map_position()/3.0
  if cell.x>553.5 and cell.x<559.5:low=minf(low,game.player.position.y/game.model.falan_scale)
  if cell.x>560:break
 Input.action_release("move_forward")
 var final=Tour.Regions.frame(Tour.area(game.model))*map_position()/3.0
 check(final.x>559 and absf(final.y-233)<1.0 and low>4.0,"Walking crosses the river and region seam above the water")
