extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 set_meta("forest_fighter",11)
 var doc=preload("res://tests/forest-shrine/reference/map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://army-defender-retention-%d.cfg"%OS.get_process_id();root.add_child(game)
 for i in 3:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.start_wave();game.model.waves.pending=100000;game.model.waves.spawn_clock=100000
 var army=game.army_runtime;var handles=[]
 for i in 2000:
  var handle:int=army.spawn(-1000-i,1,11,Vector3(i%50*3,0,i/50*3),200,.4);handles.append(handle);army.native.set_guard(handle,Vector3(i,0,0),18)
 game.explorer_helpers.sync_targets()
 var rows=game.model.defenders.duplicate();var order=game.model.defenders.keys()
 for i in 10:
  game.explorer_helpers.sync_targets()
 check(game.model.defenders.keys()==order,"Stable allied ordering survives repeated live mirror updates")
 var retained=0
 for id in rows:
  if id<=-1000 and is_same(rows[id],game.model.defenders.get(id,{})):retained+=1
 check(retained==2000,"Repeated updates retain all 2000 live ally records")
 army.set_pose(handles[0],Vector3(7,8,9),1);army.apply_hit(handles[0],{"amount":.125})
 game.explorer_helpers.sync_targets()
 check(game.model.defenders[-1000].pos==Vector3(7,8,9) and game.model.defenders[-1000].hp==199.875,"Retained rows still receive exact new position and fractional health")
 army.despawn(handles[1]);game.explorer_helpers.sync_targets()
 check(not game.model.defenders.has(-1001) and game.model.fighter_count==1999,"Death removes only the retired ally and updates population")
 var cfg=game.settings_path;game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("ARMY_DEFENDER_RETENTION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
