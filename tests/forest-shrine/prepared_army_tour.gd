extends SceneTree
var game
var cfg="user://prepared-army-tour-%d.cfg"%OS.get_process_id()
var out="user://prepared-army.png"
func _initialize():run.call_deferred()
func frames(n=3):
 for i in n:await process_frame
func run():
 if DisplayServer.get_name()=="headless":quit(1);return
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_four_gates();set_meta("forest_custom_layout",doc.data);set_meta("forest_painterly_preview",true)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 AudioServer.set_bus_mute(0,true)
 for slot in 5:
  var key=InputEventKey.new();key.physical_keycode=KEY_1+slot;key.pressed=true;root.push_input(key,true);key.pressed=false;root.push_input(key,true)
 game.pan=Vector3(0,0,20);game.preparation_size=110;game.update_preparation_camera();game.forest_ui.sync()
 await frames(90);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out)
 var allies=game.explorer_helpers.active_units()
 var good=allies.size()==12 and allies.all(func(u):return u.state=="prepared" and not u.has_offensive_action()) and game.model.phase=="preparing"
 print("PREPARED_ARMY_NATIVE_RESULT allies=",allies.size()," failures=",0 if good else 1)
 game.sound_library.cancel();game.music.stop()
 for k in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
  for v in game.find_children("*",k,true,false):v.stop()
 OS.delay_msec(120);game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(0 if good else 1)
