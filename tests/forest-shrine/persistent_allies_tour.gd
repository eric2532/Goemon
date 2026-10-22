extends SceneTree
const GuardFixture=preload("res://tests/forest-shrine/guard_combat_fixture.gd")
var game
var cfg="user://ally-tour-%d.cfg"%OS.get_process_id()
var out="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/persistent-allies-20261018"
func _initialize():run.call_deferred()
func frames(n=3):
 for i in n:await process_frame
func run():
 if DisplayServer.get_name()=="headless":quit(1);return
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data);set_meta("forest_painterly_preview",true)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.start_wave();game.model.waves.spawn_clock=100000;game.model.waves.pending=999
 game.player.position=Vector3(0,.15,78);game.player.invuln=100;game.player.set_physics_process(false)
 game.camera_rig.set_process(false);game.ui.hide();AudioServer.set_bus_mute(0,true)
 var camera=game.camera_rig.camera;camera.global_position=Vector3(24,19,102);camera.look_at(Vector3(0,2,64))
 for i in 12:game.model.waves.spawn_enemy(0,Vector3((i%4-1.5)*7,0,54+(i/4)*5))
 var boss=game.model.waves.spawn_enemy(4,Vector3(0,0,66));boss.hp=100000;boss.max_hp=100000
 game.sync_enemies();game.model.update_vision(game.player.position);await frames()
 for group in 2:
  for slot in 5:GuardFixture.deploy(game.explorer_helpers,slot)
 await frames(100);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join("allied-army.png"))
 var starting=game.explorer_helpers.active_units().size()
 await frames(400)
 var allies=game.explorer_helpers.active_units()
 var hurt=allies.filter(func(u):return u.hp<u.max_hp)
 print("PERSISTENT_ALLIES_NATIVE_RESULT initial=",starting," survivors=",allies.size()," wounded=",hurt.size()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out.path_join("allies-in-combat.png"))
 game.sound_library.cancel();game.music.stop()
 for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
  for voice in game.find_children("*",kind,true,false):voice.stop()
 OS.delay_msec(120);game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit()
