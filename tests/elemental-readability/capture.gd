extends SceneTree
var game: Node
var label="before"
func _initialize():call_deferred("run")
func run():
	if "--after" in OS.get_cmdline_user_args():label="after"
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.player.smoke_mode=true;game.encounters.enabled=false;game.encounters.pending=0;game.orb_system.active=false
	game.player.set_physics_process(false)
	game.player.position=Vector3(-2,game.world.height_at(-2,30)+.12,30);game.player.rotation.y=PI
	game.camera_rig.yaw=0;game.camera_rig.pitch=.36;game.camera_rig.distance=14;game.camera_rig.current_distance=14;game.camera_rig.reset_follow()
	game.camera_rig._process(1);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
	game.hud.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for scene in ["clear","fire","smoke","ice","overlap","surge_overlap"]:
		for group in ["elemental_vfx","edo_explosions"]:
			for n in get_nodes_in_group(group):n.queue_free()
		await process_frame
		if scene=="surge_overlap":
			game.player.select_character(2);game.player.musashi.ensure_shield_visual()
			game.player.musashi.shield.set_process(false);game.player.musashi.shield._process(.4)
		if scene in ["fire","smoke","ice"]:
			game.orb_system.burst("ice" if scene=="ice" else "fire")
			for n in get_nodes_in_group("elemental_vfx"):
				n.set_physics_process(false);n._physics_process(.55 if scene=="smoke" else .18)
		if scene in ["overlap","surge_overlap"]:
			for i in range(3):
				for kind in ["fire","ice"]:
					game.orb_system.burst(kind)
					var n=get_nodes_in_group("elemental_vfx")[-1];n.set_physics_process(false);n._physics_process(.18+i*.12)
		await process_frame;await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://docs/elemental-readability/"+label+"-"+scene+".png")
		print("CAPTURE ",label," ",scene," camera=",game.camera_rig.camera.global_transform)
	quit()
