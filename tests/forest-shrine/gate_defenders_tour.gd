extends SceneTree
var game
var folder=ProjectSettings.globalize_path("user://gate-defender-tour")
var path="user://gate-defender-tour-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func frames(n:int):
 for i in n:await process_frame
func capture(file:String):
 await frames(4);RenderingServer.force_draw();root.get_texture().get_image().save_png(folder+"/"+file+".png")
func run():
 if not OS.get_environment("GATE_DEFENDERS_OUTPUT_DIR").is_empty():folder=OS.get_environment("GATE_DEFENDERS_OUTPUT_DIR")
 DirAccess.make_dir_recursive_absolute(folder)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=path;root.add_child(game);current_scene=game;await frames(8)
 game.show_gate_defenders();await capture("defender-selection");game.forest_ui.get_node("GateDefenderPanel").close();await frames(2)
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000;game.tuning.invincible=true
 var south
 for unit in game.gate_defenders.units.values():
  if unit.post.z>40:south=unit
  var out=unit.post.normalized();out.y=0
  for i in 4:
   var p:Vector3=unit.post+out*(7+i*2)+Vector3(out.z,0,-out.x)*(i%2-0.5)*3;p.y=game.model.surface_height(p.x,p.z)
   game.model.waves.spawn_enemy(0 if i%2==0 else 3,p)
 game.player.position=south.post+Vector3(7,0,-5);game.player.set_physics_process(false)
 game.camera_rig.set_process(false);game.camera_rig.camera.global_position=south.post+Vector3(15,13,18);game.camera_rig.camera.look_at(south.post+Vector3(0,1,4));game.sync_enemies()
 await frames(60);await capture("defenders-in-combat")
 var times=[];var last=Time.get_ticks_usec()
 for i in 150:
  await process_frame
  var now=Time.get_ticks_usec()
  if i>30:times.append((now-last)/1000.0)
  last=now
 times.sort();print("GATE_NATIVE_COMBAT median_ms=",times[times.size()/2]," p95_ms=",times[int(times.size()*.95)]," enemies=",game.model.enemies.size()," allies=",game.gate_defenders.units.size())
 await capture("defenders-after-combat")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(3);DirAccess.remove_absolute(ProjectSettings.globalize_path(path));quit()
