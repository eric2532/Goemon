extends SceneTree
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func run():
 var doc=preload("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 set_meta("forest_custom_layout",doc.data);set_meta("forest_painterly_preview",true)
 var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://skullpion-spawn-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 5:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.explorer_helpers.set_process(false);game.army_runtime.set_process(false);game.camera_rig.set_process(false)
 game.start_wave();game.model.waves.spawn_clock=100000;game.model.waves.pending=999;game.ui.hide();AudioServer.set_bus_mute(0,true)
 var runtime=game.army_runtime;runtime.clear();runtime.refresh_kits();game.world.sync(0)
 var nav=runtime.navigation_data(game.model);var collision=runtime.static_collision_data(game.world)
 nav.air_faces=collision.faces;nav.air_owner=collision.owners;runtime.set_navigation(999999,nav)
 var portals=game.model.portals.duplicate();var starts={}
 for camp in portals:
  game.model.portals=[camp]
  var mouth:Vector3=game.model.waves.routes.exit_point(camp,4);mouth.y=game.model.surface_height(mouth.x,mouth.z)
  check(game.model.waves.navigation.move_clear(mouth,18),"Expanded castle exit clears large bosses at "+str(mouth))
  check(game.model.waves.navigation.move_clear(mouth,1.3),"Ordinary soldiers retain their existing barracks exit")
  check(game.model.waves.spawn_skullpion([]),"Fallback admits a boss outside each barracks")
 game.model.portals=portals;runtime.import_arrivals()
 check(runtime.handles.size()==4,"Four bosses coexist in the same native owner")
 for id in runtime.handles:
  var point:Vector3=runtime.unit_state(runtime.handles[id]).position;starts[id]=point
  check(game.model.waves.navigation.move_clear(point,18),"Admitted boss has clear spawn geometry")
 var context={"targets":runtime.external_targets()}
 var visual=DisplayServer.get_name()!="headless";var camera:Camera3D
 if visual:
  camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(85,100,-400);camera.look_at(Vector3(0,10,-280));camera.current=true;camera.fov=55
 var nodes=0;var resources=0
 for tick in 1000:
  runtime.step(.02,context);runtime.native.take_events()
  if visual:
   var snapshot=runtime.render_snapshot();game.crowd.army.present(snapshot,[])
   for boss in game.crowd.army.skullpions.values():boss.show()
   await process_frame
   if tick==99:nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
   if tick in [99,999]:
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://build/Other Files/Asset Toolkit/Skullpion/Movement/moving-%d.png"%tick)
 for id in starts:
  var point:Vector3=runtime.unit_state(runtime.handles[id]).position
  print("SKULLPION_TRAVEL id=",id," start=",starts[id]," end=",point," distance=",starts[id].distance_to(point))
  check(starts[id].distance_to(point)>30,"Boss leaves barracks and advances toward castle")
 if visual:
  check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))<=nodes,"Repeated boss movement does not grow nodes")
  check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=resources,"Repeated boss movement does not grow resources")
  camera.queue_free()
 var camp:Dictionary=portals[0];var mouth:Vector3=game.model.waves.routes.exit_point(camp,4);mouth.y=game.model.surface_height(mouth.x,mouth.z)
 game.model.damage_enemy_objective(0,99999)
 check(game.model.waves.navigation.move_clear(mouth,18),"Destroyed castle no longer blocks the broad spawn position")
 game.model.portals=[camp]
 check(not game.model.waves.spawn_skullpion([]),"Boss fallback cannot spawn from a destroyed castle")
 game.model.portals=portals
 game.sound_library.cancel();game.music.stop();game.move_audio.stop();game.queue_free();current_scene=null;paused=false
 for i in 3:await process_frame
 print("SKULLPION_SPAWN_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
