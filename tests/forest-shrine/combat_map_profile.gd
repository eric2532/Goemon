extends SceneTree
var game
var report=[]
var out="user://combat-map-profile.json"
var config_path="user://combat-profile-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func measure(label_:String,live:bool):
 var times=[];var last=Time.get_ticks_usec()
 for i in 110:
  if live:
   game._physics_process(1.0/60)
   for a in game.actors.values():a._physics_process(1.0/60)
   game.world.sync(1.0/60)
   game.crowd._process(1.0/60)
  await process_frame
  var now=Time.get_ticks_usec()
  if i>=20:times.append((now-last)/1000.0)
  last=now
 times.sort();var row={"stage":label_,"median":times[45],"p95":times[85],"max":times[-1],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)};report.append(row);print("NATIVE ",JSON.stringify(row))
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await process_frame;await physics_frame
 AudioServer.set_bus_mute(0,true);game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000;game.tuning.invincible=true
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.crowd.set_process(false);game.camera_rig.set_process(false)
 game.player.position=Vector3(0,3.5,65);game.model.hero_position=game.player.position;game.camera_rig.reset_follow();game.camera_rig._process(0)
 await measure("empty",false)
 for count in [48,96]:
  while game.model.enemies.size()<count:
   var i=game.model.enemies.size();var variant=[0,1,3][i%3];var portal=game.model.portals[i%8]
   var p=game.model.waves.routes.exit_point(portal,variant)+game.model.waves.routes.direction(portal)*(6+int(i/8)*2);p.y=game.model.surface_height(p.x,p.z)
   var e=game.model.waves.spawn_enemy(variant,p);e.road_path=game.model.waves.routes.guidance(p,variant);var d=game.model.waves.routes.direction(portal);e.facing=atan2(-d.x,-d.z)
  game.sync_enemies()
  for a in game.actors.values():a.set_physics_process(false);a._physics_process(0)
  var costs={"stage":"components","count":count}
  for component in ["simulation","actors","crowd","world"]:
   var start=Time.get_ticks_usec()
   for i in 20:
    match component:
     "simulation":game.model.tick(1.0/60,game.player.position)
     "actors":
      for a in game.actors.values():a._physics_process(1.0/60)
     "crowd":game.crowd._process(1.0/60)
     "world":game.world.sync(1.0/60)
   costs[component]=(Time.get_ticks_usec()-start)/20000.0
  report.append(costs);print("COMPONENTS ",JSON.stringify(costs))
  await measure("render_only_%d"%count,false)
  await measure("live_%d"%count,true)
 FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await process_frame;DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path));quit()
