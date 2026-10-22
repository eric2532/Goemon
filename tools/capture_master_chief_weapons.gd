extends SceneTree
## Capture the real native renderer through the normal source launcher.
const OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/master-chief-weapons"
var game
func _initialize():run.call_deferred()
func frames(count:int):
	for i in count:await process_frame
func capture(name_:String):
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+"/"+name_+".png")==OK)
func run():
	# The desktop launcher supplies --scene as well as --script. Remove that
	# initial scene before instantiating the isolated capture, avoiding two games.
	await frames(2)
	if is_instance_valid(current_scene):
		current_scene.queue_free();await frames(3)
	root.size=Vector2i(1440,900)
	set_meta("forest_painterly_preview",true)
	game=load("res://scenes/forest_shrine.tscn").instantiate()
	game.settings_path="user://chief-weapons-capture-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(12)
	game.player.select_character(18);game.start_wave()
	game.model.waves.pending=999;game.model.waves.spawn_clock=100000;game.tuning.invincible=true
	game.player.position=Vector3(0,game.model.surface_height(0,90)+.1,90);game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
	game.camera_rig.yaw=0;game.camera_rig.pitch=0
	await frames(40)
	var combat=game.player.master_chief_combat
	for slot in [1,2,3,4]:
		combat.select_slot(slot)
		# Wait in wall-clock time so native ready animations reach idle at any FPS.
		await create_timer(1.5).timeout;await frames(4)
		await capture(["rocket-launcher","pistol","shotgun","assault-rifle"][slot-1])
		combat.cooldown=0;combat.fire_shot()
		var fpfx=game.camera_rig.first_person_viewmodel.native_fx
		fpfx.set_process(false);combat.native_fx.set_process(false)
		fpfx.advance(.025);combat.native_fx.advance(.025);await frames(4)
		await capture(["rocket-launcher-fire","pistol-fire","shotgun-fire","assault-rifle-fire"][slot-1])
		combat.cancel();fpfx.set_process(true);combat.native_fx.set_process(true)
	game.show_rogue_roster();await frames(10)
	var card=game.find_child("RogueFighter_master-chief",true,false)
	if card!=null:card.grab_focus()
	await frames(10);await capture("weapon-roster")
	game.queue_free();paused=false;await frames(3)
	print("CHIEF_WEAPONS_NATIVE_CAPTURE_COMPLETE");quit()
