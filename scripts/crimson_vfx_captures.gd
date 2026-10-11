extends SceneTree
var game
var directory="res://build/crimson-vfx/captures"
func _initialize():run.call_deferred()
func frames(count: int):
	for i in range(count):await process_frame
func capture(label: String):
	await frames(3);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+"/"+label+".png")
	print("CAPTURE ",label)
func run():
	if DisplayServer.get_name()=="headless":quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	game=load("res://scenes/main.tscn").instantiate();game.smoke_test=true;root.add_child(game)
	game.tuning.freeze_ai=true;game.tuning.invincible=true;game.settings.quality=1
	game.start_mode("defense");game.apply_quality();game.encounters.set_physics_process(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(1280,800)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;Engine.max_fps=60
	game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
	game.camera_rig.yaw=0
	var p=game.player;p.smoke_mode=true;p.set_physics_process(false)
	game.hud.hide()
	var camera=game.camera_rig.camera
	camera.global_position=Vector3(9,6,190);camera.look_at(Vector3(0,1.6,178))
	for index in range(10):
		p.select_character(index+3);p.set_physics_process(false)
		p.position=Vector3(0,.1,180);p.facing=Vector3.FORWARD
		var a=p.active_ability;a.reset_run();a.set_process(false)
		a.player.pos=p.position;a.aim=p.position+Vector3.FORWARD*20
		a.attack()
		if index==3:a.Actions.release_charge(a)
		if a.player.attack!=null:a.tick(a.player.attack.contact+.002,false)
		if not a.projectiles.is_empty():
			var pr=a.projectiles[0];pr.mesh.position+=pr.vel.normalized()*2
			a.Actions.update_projectile(a,pr,.02)
		a._animate(.04,0);a.fx.tick(.075)
		await capture("hero-"+a.class_id)
		if index==1:
			for stage in range(5):
				a.cancel();a.combo=stage;a.combo_timer=1;a.player.cooldowns.cutlass=0
				a.attack();a.tick(a.player.attack.contact+.002,false)
				a._animate(.04,0);a.fx.tick(.075)
				await capture("samurai-cut-"+str(stage+1))
			a.cancel();a.player.cooldowns.flintlock=0;a.action("flintlock")
			a._animate(.04,0);a.fx.tick(.06)
			await capture("samurai-energy-arrow")
			a.cancel();a.player.cooldowns.drink=0;a.action("drink");a.combo=4;a.combo_timer=1
			a.attack();a.tick(a.player.attack.contact+.002,false);a._animate(.3,0);a.fx.tick(.035)
			await capture("samurai-ultimate")
			game.settings.quality=0;game.apply_quality();a._animate(.3,0)
			await capture("samurai-low-quality")
			game.settings.quality=1;game.apply_quality()
		a.cancel()
	p.select_character(1);p.set_physics_process(false);p.position=Vector3(0,.1,180)
	p.facing=Vector3.FORWARD;p.rogue_pipe_combo.prepare();p.rogue_pipe_combo.set_process(false)
	p.rogue_pipe_combo.slash(2);p.rogue_pipe_combo.fx.tick(.075)
	p.activate_surge();await capture("hero-goemon")
	p.cancel_charge();p.end_surge()
	p.select_character(2);p.set_physics_process(false);p.position=Vector3(0,.1,180)
	p.musashi.activate_shield();p.musashi.primary_attack();await frames(8)
	await capture("hero-edo")
	p.musashi.cancel();game.sound_library.cancel();game.music.stop()
	game.queue_free();await frames(4);quit()
