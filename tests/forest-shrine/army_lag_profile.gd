extends SceneTree
const GuardFixture=preload("res://tests/forest-shrine/guard_combat_fixture.gd")
var game
var report=[]
var out="user://army-performance.json"
var cfg="user://army-profile-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func frames(n=3):
 for i in n:await process_frame
func freeze():
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 for u in game.gate_defenders.units.values():u.set_physics_process(false)
 for u in game.explorer_helpers.pool:u.set_physics_process(false)
 for e in game.actors.values():e.set_physics_process(false)
func measure(label_:String,disable_visuals:bool=false):
 var times=[];var costs={"helpers_us":0,"vision_us":0,"animate_us":0,"aim_us":0};var last=Time.get_ticks_usec()
 for i in 100:
  var begin=Time.get_ticks_usec()
  for u in game.explorer_helpers.active_units():u._physics_process(1.0/60)
  costs.helpers_us+=Time.get_ticks_usec()-begin
  if i%12==0:
   begin=Time.get_ticks_usec();game.explorer_helpers.sync_targets();game.model.update_vision(game.player.position);costs.vision_us+=Time.get_ticks_usec()-begin
  await process_frame;freeze()
  var now=Time.get_ticks_usec()
  if i>=20:times.append((now-last)/1000.0)
  last=now
 times.sort()
 var start=Time.get_ticks_usec()
 for i in 10:
  for u in game.explorer_helpers.active_units():u.active_ability._animate(1.0/60,0)
 costs.animate_us=(Time.get_ticks_usec()-start)/10.0
 start=Time.get_ticks_usec()
 for u in game.explorer_helpers.active_units():game.explorer_helpers.closest_target(u.global_position,48)
 costs.aim_us=Time.get_ticks_usec()-start
 var row={"stage":label_,"allies":game.explorer_helpers.active_units().size(),"enemies":game.model.enemies.size(),"median_ms":times[40],"p95_ms":times[76],"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"helper_tick_ms":costs.helpers_us/100000.0,"vision_ms_per_frame":costs.vision_us/100000.0,"all_pose_ms":costs.animate_us/1000.0,"all_target_ms":costs.aim_us/1000.0};print("ARMY_PROFILE ",JSON.stringify(row));report.append(row)
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data);set_meta("forest_painterly_preview",true)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000;game.player.position=Vector3(0,.15,78);game.model.update_vision(game.player.position);freeze();game.set_process(false)
 game.camera_rig.camera.global_position=Vector3(24,20,102);game.camera_rig.camera.look_at(Vector3(0,2,64));AudioServer.set_bus_mute(0,true)
 await measure("empty")
 for i in 96:
  var e=game.model.waves.spawn_enemy(0,Vector3((i%12-5.5)*3.0,0,48+int(i/12)*3));e.hp=1000000000;e.max_hp=1000000000
 game.sync_enemies();await frames();freeze()
 for e in game.actors.values():e.boss=true;e._sync_fitted_pose()
 game.model.update_vision(game.player.position)
 for groups in [1,2,4,8]:
  var attempts=0
  while game.explorer_helpers.active_units().size()<groups*12 and attempts<8:
   attempts+=1
   for slot in 5:GuardFixture.deploy(game.explorer_helpers,slot)
   freeze()
  await measure("army_%d"%(groups*12))
 FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 var failure=report.filter(func(row):return row.stage=="army_48" and (row.allies!=48 or row.median_ms>33.3)).size()>0
 print("ARMY_PERFORMANCE_RESULT failures=",1 if failure else 0)
 game.sound_library.cancel();game.music.stop()
 for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
  for voice in game.find_children("*",kind,true,false):voice.stop()
 OS.delay_msec(120);game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failure else 0)
