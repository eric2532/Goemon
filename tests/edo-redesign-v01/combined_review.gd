extends SceneTree
var failures=0
func check(ok: bool,message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
	game.start_game();game.encounters.enabled=false;game.encounters.pending=0;game.orb_system.active=false;game.player.smoke_mode=true
	var p=game.player;var shape=p.find_children("*","CollisionShape3D",false,false)[0]
	var collider=shape.shape;var collider_transform=shape.transform;var hp=p.hp
	p.select_character(2);await process_frame
	var expected=MusashiModel.ORIGINAL_MODEL if "--edo-original" in OS.get_cmdline_user_args() else MusashiModel.REVIEW_MODEL
	check(p.model.rig_visual.scene_file_path==expected,"Ordinary Edo selection loads requested model: "+expected)
	check(p.model.skeleton.get_bone_count()==16,"Runtime review model has all16 animation bones")
	check(shape.shape==collider and shape.transform==collider_transform and p.hp==hp,"Switching preserves shared collider, transform and health")
	check(game.active_enemy_limit==200 and game.crowd.batches.size()==4,"Enemy cap and four original species batches remain active")
	check(game.world.find_child("TidefallProps",true,false)!=null,"Main town prop kit remains integrated")
	for side in ["L","R"]:check(p.model.hand_position(side).is_finite(),"Hand attachment origin remains finite: "+side)
	if "--visual" in OS.get_cmdline_user_args():
		p.set_physics_process(false);p.position=Vector3(-2,game.world.height_at(-2,30)+.12,30);p.rotation.y=PI
		game.camera_rig.yaw=0;game.camera_rig.pitch=.36;game.camera_rig.distance=14;game.camera_rig.current_distance=14;game.camera_rig.reset_follow();game.camera_rig._process(1);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
		game.hud.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/combined-review/edo-gameplay.png")
		p.musashi.ensure_shield_visual();p.musashi.shield.set_process(false);p.musashi.shield._process(.4)
		for i in range(3):
			for kind in ["fire","ice"]:
				game.orb_system.burst(kind)
				var n=get_nodes_in_group("elemental_vfx")[-1];n.set_physics_process(false);n._physics_process(.18+i*.12)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/combined-review/edo-elemental-overlap.png")
	print("COMBINED_REVIEW_RESULT failures=",failures)
	game.queue_free();await process_frame;await process_frame
	quit(1 if failures else 0)
