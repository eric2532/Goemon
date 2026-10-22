extends SceneTree
var game
var checks=0
var failures=0
var folder="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/painterly-gate-20261017"
var config_path="user://painterly-test-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(100).timeout.connect(func():printerr("Painterly gameplay test timeout");quit(1))
 run.call_deferred()
func frames(n=3):
 for i in n:await process_frame
func check(ok:bool,note:String):
 checks+=1;print("PASS: " if ok else "FAIL: ",note)
 if not ok:failures+=1
func capture(label_:String):
 if not "--visual" in OS.get_cmdline_user_args():return
 await frames(5);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(folder+"/"+label_+".png")==OK,"Native capture "+label_)
func run():
 set_meta("forest_painterly_preview",false)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
 await frames();game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.pan=Vector3(-7,0,37);game.preparation_size=76;game.update_preparation_camera()
 var button=game.forest_ui.find_child("PreparationPainterly",true,false)
 check(button!=null and button.visible,"Building view exposes a painterly comparison button")
 var hp=game.player.hp;var position_=game.player.position;var selected=game.player.character_id
 var camera_before=game.camera_rig.camera.transform
 game.ui.hide();await capture("gate-tower-before")
 button.pressed.emit();await frames()
 check(game.painterly_preview and game.world.painterly_pilot.enabled and button.text=="Painterly: On","Building button enables the preview and reflects its state")
 check(game.player.hp==hp and game.player.position==position_ and game.player.character_id==selected,"Toggle preserves the fighter, position and health")
 check(game.camera_rig.camera.transform==camera_before,"Comparison leaves camera framing unchanged")
 await capture("gate-tower-painterly")
 game.ui.show();await capture("building-preview-button")
 game.ui.hide()
 var camera=game.camera_rig.camera;camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.position=Vector3(18,10,66);camera.look_at(Vector3(-6,5,34))
 await capture("gate-eye-level-painterly")
 game.toggle_painterly_preview();await capture("gate-eye-level-before")
 check(not game.painterly_preview and not game.world.painterly_pilot.enabled,"The same button returns to the current look")
 game.open_map_editor();await frames();game.map_editor.load_original();await frames()
 check(game.model.ramparts.is_empty(),"Original Map remains accessible in the editor")
 game.map_editor.load_ramparts();await frames();game.map_editor.close_discard();await frames()
 check(game.model.ramparts.size()==5,"Current Twin Ramparts map also remains accessible")
 game.toggle_painterly_preview();game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
 check(game.model.phase=="wave" and game.world.painterly_pilot.enabled,"Normal wave gameplay starts while the art pilot is enabled")
 game.player.select_character(5);game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
 game.player.position=Vector3(3,.1,40);game.model.hero_position=game.player.position
 game.world.sync(.2)
 var gate_node:Node3D=game.world.structure_nodes[game.world.painterly_pilot.selected_ids[0]]
 check(gate_node.get_node("GateDoor").position.y>2.4,"The existing gate still opens for the player")
 game.player.active_ability.cancel();game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 game.queue_free();paused=false;await frames();await create_timer(.3).timeout
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 print("PAINTERLY_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
