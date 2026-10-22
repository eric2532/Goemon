extends SceneTree
const OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/halo-energy-sword"
var game
func _initialize():run.call_deferred()
func frames(count:int):
	for i in count:await process_frame
func capture(name_:String):
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+"/"+name_+".png")==OK)
func run():
	await frames(2)
	if is_instance_valid(current_scene):current_scene.queue_free();await frames(3)
	root.size=Vector2i(1440,900);set_meta("forest_painterly_preview",true)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://sword-capture-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(12)
	game.player.select_character(18);game.start_wave();game.model.waves.spawn_clock=100000;game.tuning.invincible=true
	game.player.position=Vector3(0,game.model.surface_height(0,90)+.1,90);game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
	game.camera_rig.yaw=0;game.camera_rig.pitch=0;await frames(25)
	var combat=game.player.master_chief_combat;combat.select_slot(5)
	await create_timer(1.6).timeout
	await capture("sword-idle")
	var view=game.camera_rig.first_person_viewmodel
	combat.cooldown=0;combat.fire_shot();view.animations.pause();game.player.set_physics_process(false)
	for time in [.12,.28,.48]:
		view.animations.seek(time*view.animations.speed_scale,true);await frames(4)
		await capture("sword-swing-%d"%int(time*100))
	combat.cancel();game.show_rogue_roster();await frames(10);await capture("sword-roster")
	game.queue_free();paused=false;await frames(4)
	print("HALO_ENERGY_SWORD_NATIVE_CAPTURE_COMPLETE");quit()
