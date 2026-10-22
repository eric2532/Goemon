extends SceneTree
var game
var checks=0
var failures=0
var cfg="user://boss-hud-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1;print("PASS: " if ok else "FAIL: ",label_)
 if not ok:failures+=1
func frames(n=3):
 for i in n:await process_frame
func run():
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 var ui=game.forest_ui;var m=game.model
 for bosses_per_portal in [0,1]:
  m.balance["bosses_per_portal"]=bosses_per_portal;ui.sync()
  check(ui.find_child("EnemyHub",true,false)==null,"Boss settings do not restore the removed enemy-count panel")
 if "--preparation-only" in OS.get_cmdline_user_args():await finish();return
 m.balance["bosses_per_portal"]=1;m.balance["waves"]=[[0,0,0,0]]
 check(m.start_wave(),"A real portal-boss wave starts")
 var living=m.waves.spawn_enemy(4,Vector3(0,0,52))
 ui.sync()
 check(ui.find_child("EnemyHub",true,false)==null,"Live and queued bosses do not add count HUD")
 m.enemies.erase(living.id);ui.sync()
 check(ui.find_child("EnemyHub",true,false)==null,"Retiring a boss keeps count HUD removed")
 await finish()
func finish():
 game.sound_library.cancel();game.music.stop()
 for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
  for voice in game.find_children("*",kind,true,false):voice.stop()
 OS.delay_msec(120)
 game.queue_free();paused=false;await frames();await create_timer(.2).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("BOSS_HUD_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
