extends "res://scripts/fire_siege_controls_tests.gd"
## Render the actual game and inputs for close review of the upgraded kits.

func stage(index: int, distance: float = 11):
	await fresh_class(index)
	game.reset_player_at(Vector3(0,.1,205))
	game.camera_rig.yaw=0
	game.player.facing=Vector3.FORWARD
	game.player.model.rotation.y=0
	game.camera_rig.set_process(false)
	var camera=game.camera_rig.camera
	camera.global_position=game.player.position+Vector3(distance*.65,distance*.42,distance*.8)
	camera.look_at(game.player.position+Vector3(0,1,-1))
	await frames(20)

func run():
	visual=true
	output_dir="res://tests/rogue-upgrade" if OS.has_feature("editor") else "user://tests/rogue-upgrade"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	Input.use_accumulated_input=false
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
	game.start_mode("defense");pause_fixture_director();await frames(5)
	if not "--abilities-only" in OS.get_cmdline_user_args():
		for index in range(10):
			await stage(index,6.5)
			await capture("idle-%02d-%s" % [index,CLASS_IDS[index]])
			game.player.smoke_move=Vector2.UP
			await frames(12)
			await capture("run-%02d-%s" % [index,CLASS_IDS[index]])
			game.player.smoke_move=Vector2.ZERO
	await stage(1)
	tap("heavy_attack");await frames(18);await capture("samurai-red-slash")
	await stage(1,7)
	tap("equip");await frames(2);await capture("samurai-bow-drawn")
	await stage(2,13)
	tap("heavy_attack");await frames(12);await capture("ninja-dash-cut")
	await stage(2,10)
	tap("equip");await frames(6);await capture("ninja-shuriken")
	await stage(8,12)
	tap("heavy_attack");await frames(10);await capture("rogue-cross-slash")
	await stage(5,14)
	tap("heavy_attack");await frames(54);await capture("dragoon-blue-impact")
	await frames(17);await capture("dragoon-outward-pulse")
	await stage(3,9)
	press("light_attack");await frames(181);await capture("mage-full-charge")
	press("light_attack",false);await frames(5);await capture("mage-giant-fireball")
	await stage(3,14)
	tap("heavy_attack");await frames(18);await capture("mage-frost-nova")
	await stage(9,7)
	press("weapon_chain");await frames(15);await capture("master-thief-red-guard")
	press("weapon_chain",false)
	await stage(4,13)
	tap("heavy_attack");await frames(4)
	game.player.active_ability.filter_damage(10,Vector3.BACK,false)
	await frames(12);await capture("knight-energy-bash")
	game.camera_rig.set_process(true)
	game.show_main_menu();game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	await frames(5)
	print("ROGUE_UPGRADE_TOUR_COMPLETE")
	get_tree().quit()
