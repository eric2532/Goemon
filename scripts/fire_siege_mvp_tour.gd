extends Node
## Input-driven rendered QA. Invincibility protects the capture operator only.
var game: Node
var output="res://tests/fire-siege-mvp" if OS.has_feature("editor") else "user://fire-siege-mvp-captures"

func frames(count: int):
 for i in range(count):await get_tree().physics_frame

func hold(action: String,pressed: bool):
 var event=InputEventAction.new();event.action=action;event.pressed=pressed
 Input.parse_input_event(event);Input.flush_buffered_events()

func position_at(point: Vector3,look: Vector3,distance: float=15):
 game.reset_player_at(point);game.player.facing=(look-point).normalized()
 game.camera_rig.yaw=0;game.camera_rig.pitch=.48;game.camera_rig.distance=distance;game.camera_rig.reset_follow()

func capture(label: String):
 game.hud.banner_time=0;game.hud.toast_time=0
 await RenderingServer.frame_post_draw
 var result=get_viewport().get_texture().get_image().save_png(output.path_join(label+".png"))
 if result!=OK:
  push_error("Could not save capture: "+label);get_tree().quit(1);return
 print("MVP_CAPTURE ",label)

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
 game.tuning.invincible=true;game.player.smoke_mode=true;game.selected_rogue_id=1
 Input.use_accumulated_input=false
 game.start_mode("defense");await frames(8)
 var run=game.encounters;var site=game.world.cannon_sites[0]
 position_at(site.build_position,site.position)
 await frames(12);await capture("01-opening")
 hold("siege_build",true);await frames(90);await capture("02-half-built")
 hold("siege_build",false);await frames(30);await capture("03-release-decay")
 hold("siege_build",true);await frames(160);hold("siege_build",false)
 await capture("04-tower-complete")
 print("MVP_TOUR first_tower=",run.cannons.size()," gold=",run.money)
 game.restart_area();await frames(8);run=game.encounters
 position_at(game.world.mine_build_position,game.world.mine_position,13)
 await frames(10);hold("siege_build",true);await frames(250);hold("siege_build",false)
 await capture("05-mine-built")
 hold("siege_start",true);await frames(90);await capture("06-confirm-wave")
 await frames(100);hold("siege_start",false);await frames(190)
 await capture("07-mine-working")
 site=game.world.cannon_sites[6]
 position_at(site.build_position,site.position)
 await frames(12);hold("siege_build",true);await frames(190);hold("siege_build",false)
 await frames(50);await capture("08-live-arrows")
 print("MVP_TOUR wave=",run.wave," spawned=",run.total_spawned," gold=",run.money," mine=",run.mine_built," towers=",run.cannons.size())
 game.player.select_character(9);await frames(6);await capture("09-native-hero-hud")
 game.tuning.invincible=false;game.player.invuln=0;game.player.take_hit(100000,Vector3.FORWARD)
 await frames(20);await capture("10-hero-down")
 game.hud.revive_button.pressed.emit();await frames(6);await capture("11-revived")
 print("MVP_TOUR revive hp=",game.player.hp," dead=",run.hero_dead)
 game.show_main_menu();await frames(5)
 game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 print("FIRE_SIEGE_MVP_TOUR_COMPLETE")
 get_tree().quit()
