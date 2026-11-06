extends SceneTree
const Kit=preload("res://scripts/forest/forest_environment_kit.gd")
const Document=preload("res://scripts/forest/forest_map_document.gd")
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Scenery=preload("res://scripts/forest/forest_scenery.gd")
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const OUT="res://build/Other Files/Asset Toolkit/Modular Environment/"
var failures=0
var checks=0
var game
const JUNCTION_PATHS=[
 [Vector2(-161,-42),Vector2(-126,-42),Vector2(-126,2)],
 [Vector2(-161,42),Vector2(-126,42),Vector2(-91,42)],
 [Vector2(-161,42),Vector2(-126,42),Vector2(-126,86)],
 [Vector2(-126,86),Vector2(-126,42),Vector2(-91,42)]
]
func _initialize():
 create_timer(180).timeout.connect(func():printerr("FAIL: modular environment timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func frames(count_:int=4):
 for i in count_:await process_frame
func blank()->Dictionary:return {"format":"forest_shrine_map","schema":1,"title":"Kit check","buildings":[],"trees":[],"deposits":[],"roads":[],"portals":[]}
func run():
 for kind in Kit.TERRAIN.keys()+Kit.JUNCTIONS.keys():
  var prefab=load(Kit.DIR+kind+".tscn").instantiate()
  check(prefab.get_meta("ramparts")==Kit.segments(kind,Vector2.ZERO),kind+": prefab retains exact native recipe")
  check(prefab.find_children("*","CollisionShape3D",true,false).size()>0,kind+": prefab has physical collision")
  prefab.free()
  for turn in 4:
   var recipe=Kit.segments(kind,Vector2(-12,-10),turn)
   check(preload("res://scripts/forest/forest_ramparts.gd").validation_error(recipe).is_empty(),kind+": grid/quarter-turn contract")
 for kind in ["boulder_pair","river_cluster","fence_corner"]:
  var scene=load(Scenery.asset(kind)).instantiate();var box:AABB=scene.get_meta("scenery_bounds")
  check(box.position.is_equal_approx(Scenery.CATALOG[kind].box.position) and box.size.is_equal_approx(Scenery.CATALOG[kind].box.size),kind+": catalog and prefab bounds match")
  var parts=Assets.source(Scenery.asset(kind));check(parts.size()==2,kind+": source meshes remain shared and batchable")
  var original="mossy_boulder" if kind=="boulder_pair" else Scenery.CEDAR+("river_rock" if kind=="river_cluster" else "fence")+".glb"
  check(parts[0].mesh==Assets.source(original)[0].mesh and parts[1].mesh==parts[0].mesh,kind+": both parts reference the authoritative source mesh")
  for part in parts:
   check(box.grow(.0001).encloses(part.transform*part.mesh.get_aabb()),kind+": collision contains every visual")
   if kind in ["river_cluster","fence_corner"]:check(part.material==preload("res://assets/models/cedar_pass/shared_matte.tres"),kind+": assembly retains existing matte material")
  scene.free()
  var orphan_count=Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
  var resource_count=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  for repeat in 8:
   var again=load(Scenery.asset(kind)).instantiate();again.free()
  check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)==orphan_count and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resource_count,kind+": repeated instancing keeps resources/nodes bounded")
  for angle in [0,90,180,270]:
   var doc=Document.new(false);check(doc.decode(JSON.stringify(blank())).is_empty(),"Blank authoring fixture validates")
   check(doc.place(kind,Vector2i(10,10),angle).is_empty(),kind+": existing editor placement")
   var encoded=doc.encode();var copy=Document.new(false)
   check(copy.decode(encoded).is_empty() and copy.encode()==encoded,kind+": exact saved-map round trip")
   check(doc.undo() and doc.redo() and doc.encode()==encoded,kind+": existing undo/redo")
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://tests/forest-shrine/reference/maps/forest_modular_kit.json"))
 check(Document.validate(fixture).is_empty(),"Separate valley test layout passes production map validation: "+Document.validate(fixture))
 root.size=Vector2i(1440,900);root.content_scale_size=Vector2i.ZERO
 var demo=load("res://tests/forest-shrine/modular_environment_demo.tscn").instantiate();root.add_child(demo);current_scene=demo;game=demo.game
 await frames()
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false);game.army_runtime.set_physics_process(false)
 await physics_frame;await physics_frame
 var terrain=game.model.terrain
 for path in JUNCTION_PATHS:
  for leg in range(1,path.size()):
   var a:Vector2=path[leg-1];var b:Vector2=path[leg];var side=(b-a).normalized().orthogonal()
   for step in ceili(a.distance_to(b))+1:
    for offset in [-3.0,0.0,3.0]:
     var p=a.lerp(b,minf(1,float(step)/a.distance_to(b)))+side*offset
     var height:float=terrain.height(p.x,p.y)
     var hit=game.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,40,p.y),Vector3(p.x,-2,p.y),1))
     check(not hit.is_empty() and absf(hit.position.y-height)<.025,"Joined corner/T physics and native surface agree at "+str(p))
     check(terrain.disk_clear(Vector3(p.x,height,p.y),1.3),"Joined corner/T supports a soldier-width disk")
 # Sample all three assemblies, including their exact shared planes and the full ramp width.
 for row in [{"z":0.0,"end":132.0,"height":6.0},{"z":42.0,"end":150.0,"height":12.0},{"z":-42.0,"end":126.0,"height":6.0}]:
  for x in range(60,int(row.end)+1):
   for offset in [-5.0,0.0,5.0]:
    var z:float=row.z+offset;var height:float=game.model.surface_height(x,z)
    var query=PhysicsRayQueryParameters3D.create(Vector3(x,40,z),Vector3(x,-2,z),1)
    var hit=game.world.get_world_3d().direct_space_state.intersect_ray(query)
    check(not hit.is_empty() and absf(hit.position.y-height)<.025,"Physics/native support parity at "+str(Vector2(x,z)))
    check(terrain.disk_clear(Vector3(x,height,z),.4),"Continuous player/enemy support across every join")
  for seam in ([78,114] if row.z==0.0 else [96,114] if row.z==42.0 else [78,108]):
   check(absf(terrain.height(seam-.0001,row.z)-terrain.height(seam+.0001,row.z))<.001,"No height gap at seam")
 # Explicitly detect overlapping deck interiors; touching module end faces are allowed.
 for a in terrain.pieces.size():
  for b in range(a+1,terrain.pieces.size()):
   var one:Dictionary=terrain.pieces[a];var two:Dictionary=terrain.pieces[b]
   var box1=Rect2(one.a.min(one.b)-one.side.abs()*one.half,(one.b-one.a).abs()+one.side.abs()*one.half*2)
   var box2=Rect2(two.a.min(two.b)-two.side.abs()*two.half,(two.b-two.a).abs()+two.side.abs()*two.half*2)
   check(not box1.intersects(box2),"Module collision interiors do not overlap")
 var runtime=Runtime.new();check(runtime.configure(null),"Production native army runtime initializes")
 runtime.set_navigation(1,Runtime.navigation_data(game.model))
 var handles=PackedInt64Array();var goals=PackedVector3Array();var speeds=PackedFloat32Array()
 for team in [0,1]:
  for row in [0,42,-42]:
   var start=Vector3(61,terrain.height(61,row),row);var end=150 if row==42 else 132 if row==0 else 126
   handles.append(runtime.spawn(100+handles.size(),team,0,start,100,.4));goals.append(Vector3(end-1,terrain.height(end-1,row),row));speeds.append(6)
 for tick in 1500:runtime.step(1.0/60,{"goal_handles":handles,"goal_positions":goals,"goal_speeds":speeds})
 var snapshot=runtime.snapshot()
 for i in handles.size():check(snapshot.positions[snapshot.handles.find(handles[i])].distance_to(goals[i])<1,"Both native teams traverse connected ramps/platforms")
 runtime.free()
 for path in JUNCTION_PATHS:
  runtime=Runtime.new();runtime.configure(null);runtime.set_navigation(1,Runtime.navigation_data(game.model))
  var joined_handles=PackedInt64Array();var joined_goals=PackedVector3Array();var joined_speeds=PackedFloat32Array()
  for team in [0,1]:
   var p:Vector2=path.front()+Vector2(0,team*2-1);var goal:Vector2=path.back()
   joined_handles.append(runtime.spawn(200+team,team,0,Vector3(p.x,terrain.height(p.x,p.y),p.y),100,.4))
   joined_goals.append(Vector3(goal.x,terrain.height(goal.x,goal.y),goal.y));joined_speeds.append(6)
  for tick in 3000:runtime.step(1.0/60,{"goal_handles":joined_handles,"goal_positions":joined_goals,"goal_speeds":joined_speeds})
  var joined_snapshot=runtime.snapshot()
  for index in joined_handles.size():check(joined_snapshot.positions[joined_snapshot.handles.find(joined_handles[index])].distance_to(joined_goals[index])<1.5,"Both native teams navigate the joined corner/T without supplied turn waypoints")
  runtime.free()
 # Exercise the real CharacterBody controller on both the low and high arrangements.
 game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000;game.camera_rig.yaw=0
 game.player.select_character(5);game.player.smoke_mode=true;game.player.smoke_move=Vector2.RIGHT;game.tuning.invincible=true
 var controller=game.player.active_ability
 for row in [0,42,-42]:
  var start=Vector3(61,terrain.height(61,row)+.1,row)
  game.player.position=start;game.player.velocity=Vector3.ZERO;controller.reset_run();controller.player.pos=start
  await physics_frame
  var end=150 if row==42 else 132 if row==0 else 126
  for tick in 1200:
   controller.physics_step(1.0/60)
   if game.player.position.x>=end-1:break
  check(game.player.position.x>end-2 and absf(game.player.position.y-terrain.height(game.player.position.x,row))<.3,"Actual player traverses ramp/deck/descent row "+str(row)+": "+str(game.player.position))
 game.player.smoke_move=Vector2.ZERO
 for path in JUNCTION_PATHS:
  var p:Vector2=path.front();game.player.position=Vector3(p.x,terrain.height(p.x,p.y)+.1,p.y);game.player.velocity=Vector3.ZERO
  controller.reset_run();controller.player.pos=game.player.position;await physics_frame
  for leg in range(1,path.size()):
   var goal:Vector2=path[leg]
   for tick in 1400:
    var offset=goal-Vector2(game.player.position.x,game.player.position.z)
    if offset.length()<.6:break
    game.player.smoke_move=offset.normalized();controller.physics_step(1.0/60)
   check(Vector2(game.player.position.x,game.player.position.z).distance_to(goal)<.8 and absf(game.player.position.y-terrain.height(game.player.position.x,game.player.position.z))<.3,"Actual player walks and turns through the joined corner/T: "+str(game.player.position))
 game.player.smoke_move=Vector2.ZERO
 if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
  game.forest_ui.hide();game.ui.hide()
  var camera=game.camera_rig.camera;camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=52
  for shot in [{"name":"overview","position":Vector3(184,99,135),"target":Vector3(101,4,0)},{"name":"junctions","position":Vector3(-45,105,163),"target":Vector3(-127,3,14)},{"name":"stacked-wall","position":Vector3(89,24,42),"target":Vector3(66,8,18)},{"name":"connections","position":Vector3(144,28,35),"target":Vector3(96,4,0)},{"name":"obstacles","position":Vector3(99,38,32),"target":Vector3(99,1,18)}]:
   camera.global_position=shot.position;camera.look_at(shot.target);await frames(10);await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png(OUT+shot.name+".png")==OK,"Rendered preview saved")
 var report={"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"army_units":handles.size()+JUNCTION_PATHS.size()*2,"gameplay_frame_time_profiled":false}
 var file=FileAccess.open(OUT+"validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report," "));file.close()
 game.sound_library.cancel();game.music.stop();demo.queue_free();paused=false;await frames()
 print("MODULAR_ENVIRONMENT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
