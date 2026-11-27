extends "res://tests/forest-shrine/south_kili_population_test.gd"
const SOKIA_OUT="res://build/Other Files/Asset Toolkit/Sokia Region Reconstruction/Population/"
func _initialize():
 create_timer(1500).timeout.connect(func():printerr("SOKIA_POPULATION_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-sokia-population-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false)
 var region="sokia_coast";var floor_=0;var npc_filter=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--region="):region=arg.trim_prefix("--region=")
  if arg.begins_with("--floor="):floor_=int(arg.trim_prefix("--floor="))
  if arg.begins_with("--npc="):npc_filter=arg.trim_prefix("--npc=")
 Tour.travel(game,(Tour.Indoor.layout(floor_) if floor_>0 else Tour.Regions.layout(region)),{"arrival":Vector2.ZERO,"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 game.army_runtime.refresh_navigation(0)
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.explorer_clock.load_hour(22);game.explorer_clock.update_lighting()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOKIA_OUT))
 if "--all-villagers" in OS.get_cmdline_user_args():
  var total=0
  for spec in [["ghana",0],["ghana_north_road",0],["interior",3001],["interior",3002],["interior",3008],["interior",3010],["interior",3012],["interior",3013],["interior",3014],["interior",3020],["interior",3021],["interior",3099],["interior",3350],["interior",3352]]:
   var layout=Tour.Indoor.layout(spec[1]) if spec[1]>0 else Tour.Regions.layout(spec[0])
   Tour.travel(game,layout,{"arrival":Vector2.ZERO,"yaw":0.,"velocity":Vector3.ZERO})
   game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
   for i in 3:await process_frame
   var actors_=await check_npcs(spec[0],spec[1]);total+=actors_.size()
  print("SOKIA_ALL_VILLAGERS_RESULT actors=",total," checks=",checks," failures=",errors)
  game.queue_free();await process_frame;quit(1 if errors else 0);return
 var npc_results=await check_npcs(region,floor_,npc_filter)
 if "--npcs-only" in OS.get_cmdline_user_args():
  print("SOKIA_NPC_ONLY_RESULT region=",region," npcs=",npc_results.size()," checks=",checks," failures=",errors)
  game.queue_free();await process_frame;quit(1 if errors else 0);return
 clear_enemies();game.model.waves.spawned=2
 var state=game.model.waves.route_state;var by_zone={}
 for y in state.size.y:
  for x in state.size.x:
   var cell=Vector2i(x,y)
   if not Tour.Indoor.open_cell(state.bits,state.size,x,y):continue
   var point:Vector2=state.origin+Vector2(cell)*3.
   var zone=Population.zone_at(300,Population.source_cell(game.model,point))
   if zone.is_empty():continue
   if not by_zone.has(int(zone.id)):by_zone[int(zone.id)]=[]
   by_zone[int(zone.id)].append(point)
 var zone_results=[]
 for zone_id in by_zone:
  var zone=Population.data().zones.filter(func(z):return int(z.id)==zone_id and int(z.map)==300)[0]
  var tested=false
  for point in by_zone[zone_id]:
   if game.model.get_meta("falan_links",[]).any(func(l):return point.distance_squared_to(l.at)<144):continue
   game.player.position=game.model.world_point(point,.15);game.model.hero_position=game.player.position
   game.model.waves.snow_last=game.player.position/game.model.falan_scale;game.model.waves.snow_distance=0.;game.model.waves.snow_pending=[]
   for i in 3:game.model.waves.tick(1.,game.player.position)
   check(game.model.enemies.is_empty(),"Standing still has no encounter")
   var groups=[]
   for choice in zone.groups:
    var members=[]
    for member in Population.data().groups[choice[0]].members:members.append([int(member[0]),int(member[1])])
    game.model.waves.snow_pending=members;game.model.waves.spawn_clock=0
    game.model.waves.tick(1.,game.player.position)
    if game.model.enemies.size()!=members.size():clear_enemies();continue
    game.army_runtime.import_arrivals()
    check(game.model.enemies.values().all(func(e):return e.has("route_encounter") and game.army_runtime.handles.has(e.id)),"Original pool uses the existing native owner "+choice[0])
    groups.append(choice[0]);clear_enemies()
   if groups.size()!=zone.groups.size():continue
   zone_results.append({"id":zone_id,"cell":v(Vector2(Population.source_cell(game.model,point))),"groups":groups});tested=true;break
  check(tested,"Every reachable source coast pool spawns at an actual location "+str(zone_id))
 var file=FileAccess.open(SOKIA_OUT+region+"-locations.json",FileAccess.WRITE);file.store_string(JSON.stringify({"npcs":npc_results,"zones":zone_results},"  "));file.close()
 print("SOKIA_POPULATION_RESULT npcs=",npc_results.size()," zones=",zone_results.size()," checks=",checks," failures=",errors)
 game.queue_free();await process_frame;quit(1 if errors else 0)

func check_npcs(region:String,floor_:int=0,npc_filter:String="")->Array:
 game.explorer_npcs.prepare()
 check(game.explorer_npcs.actors.size()==Population.sokia_npcs(game.model).size()+Tour.VillageNPCs.AREAS.get(str(floor_) if floor_>0 else region,[]).size(),"Documented regional actors, with no duplicate owners")
 game.explorer_clock.load_hour(12);game.explorer_npcs._process(.2)
 for actor in game.explorer_npcs.actors:
  var record:Dictionary=actor.node.get_meta("npc_record",{})
  if record.is_empty():continue
  if record.get("night_only",false):check(not actor.node.visible,"Original night actor is hidden at noon: "+record.id)
 game.explorer_clock.load_hour(22);game.explorer_clock.update_lighting();game.explorer_npcs._process(.2)
 var ids={};var npc_results=[]
 for actor in game.explorer_npcs.actors:
  var record:Dictionary=actor.node.get_meta("npc_record",{})
  if record.is_empty():
   var cell_=Population.source_cell(game.model,Vector2(actor.node.position.x,actor.node.position.z))
   record={"id":actor.record.id,"cell":[cell_.x,cell_.y],"name":actor.record.name}
  if not npc_filter.is_empty() and record.id!=npc_filter:continue
  check(not ids.has(record.id),"Source NPC identity is unique "+record.id);ids[record.id]=true
  if int(record.get("graphic",-1)) in Tour.Regions.Sokia.STELES:
   var body=actor.node.get_node_or_null("NativeSokiaStele_"+str(int(record.graphic))) as MeshInstance3D
   check(body!=null,"Source event stone has solid depth: "+record.id)
   if body!=null:
    var points=Tour.Regions.Sokia.Details.Shapes.Proportions.mesh_points(body.mesh,body.transform)
    var right=Vector3(1,0,1).normalized();var up=Vector3(8,Tour.Regions.Sokia.Details.Shapes.Proportions.VERTICAL,-8).normalized()
    var bounds_=Rect2(Vector2(points[0].dot(right),-points[0].dot(up)),Vector2.ZERO)
    for point in points:bounds_=bounds_.expand(Vector2(point.dot(right),-point.dot(up)))
    var size_:Vector2=actor.node.texture.get_size()
    var reference=Rect2(Vector2(actor.node.offset.x-size_.x*.5,-actor.node.offset.y-size_.y*.5)*actor.node.pixel_size,size_*actor.node.pixel_size)
    check(bounds_.position.distance_to(reference.position)<.01 and bounds_.size.distance_to(reference.size)<.01,"3D event stone retains its previous sprite bounds at the source camera: "+record.id)
    check(body.find_children("*","CollisionObject3D",true,false).is_empty(),"Event stone adds no physical obstacle: "+record.id)
  check(Population.source_cell(game.model,Vector2(actor.node.position.x,actor.node.position.z))==Vector2i(record.cell[0],record.cell[1]),"Exact original coast NPC cell "+record.id)
  var talked=false
  for dy in range(-6,7):
   for dx in range(-6,7):
    if dx==0 and dy==0:continue
    var spot=Vector2(actor.node.position.x,actor.node.position.z)+Vector2(dx,dy)*.75
    if not game.model.terrain.disk_clear(Vector3(spot.x,game.model.surface_height(spot.x,spot.y)+.5,spot.y),.4):
     if record.id==npc_filter:print("SOKIA_NPC_BLOCKED ",record.id," spot=",spot," y=",game.model.surface_height(spot.x,spot.y)," actor=",actor.node.position)
     continue
    game.player.position=game.model.world_point(spot,.15);game.player.reset_physics_interpolation()
    game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
    if game.explorer_npcs.nearest.get("node")!=actor.node:
     if record.id==npc_filter:
      var eye=game.player.position+Vector3.UP*2.5;var sight=actor.node.global_position+Vector3.UP*2.5
      if actor.get("source_cell_blocked",false):sight=sight.move_toward(eye,1.6*game.model.falan_scale)
      var query=PhysicsRayQueryParameters3D.create(eye,sight,1);query.hit_from_inside=true
      var hit=game.get_world_3d().direct_space_state.intersect_ray(query)
      print("SOKIA_NPC_DIAG ",record.id," spot=",spot," global_actor=",actor.node.global_position," player=",game.player.position," distance=",game.player.position.distance_to(actor.node.global_position)," hit=",hit.get("position")," owner=",hit.get("collider"))
     continue
    var key=InputEventKey.new();key.physical_keycode=KEY_F;key.pressed=true;game._input(key)
    talked=is_instance_valid(game.dialogue) and game.explorer_npcs.selected.get("id","")==actor.record.id
    if talked:
     check(not game.dialogue.body.text.strip_edges().is_empty(),"Short placeholder dialogue "+record.id)
     if DisplayServer.get_name()!="headless":
      var toward=actor.node.global_position-game.player.position
      game.camera_rig.yaw=atan2(-toward.x,-toward.z);game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
      game.camera_rig.reset_follow();game.camera_rig.update_camera(1.,true)
      for i in 4:await process_frame
      RenderingServer.force_draw();root.get_texture().get_image().save_png(SOKIA_OUT+"npc-"+record.id+".png")
     game.explorer_npcs.finish();break
   if talked:break
  check(talked,"Normal F input reaches source NPC "+record.id)
  npc_results.append({"id":record.id,"cell":record.cell,"talked":talked})
 return npc_results
