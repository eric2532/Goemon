extends SceneTree
var game
var out="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/stone-fortress-20261018"
func _initialize():run.call_deferred()
func frames(n=5):
	for i in n:await process_frame
func capture(label_:String,point:Vector3,look:Vector3,size_:float=0):
	var camera=game.camera_rig.camera
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL if size_>0 else Camera3D.PROJECTION_PERSPECTIVE
	if size_>0:camera.size=size_
	camera.global_position=point;camera.look_at(look);game.world.sync(.5)
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label_+".png"))
func run():
	if DisplayServer.get_name()=="headless":quit(1);return
	set_meta("forest_painterly_preview",true)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://stone-tour-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game;await frames()
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false);game.ui.hide();AudioServer.set_bus_mute(0,true)
	for unit in game.gate_defenders.units.values():unit.set_physics_process(false)
	game.model.defenders.clear()
	await capture("stone-fort-overview",Vector3(90,135,155),Vector3(0,6,0),150)
	await capture("goemon-stone-statue",Vector3(25,23,47),Vector3(0,16,0))
	await capture("stone-gate-closed",Vector3(22,15,78),Vector3(3,8,48))
	game.model.hero_position=Vector3(3,.1,54);game.world.sync(1)
	await capture("stone-gate-open",Vector3(22,15,78),Vector3(3,8,48))
	var draws=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	print("STONE_FORTRESS_NATIVE_RESULT draws=",draws)
	game.sound_library.cancel();game.music.stop()
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
		for voice in game.find_children("*",kind,true,false):voice.stop()
	OS.delay_msec(120);game.queue_free();paused=false;await frames();quit()
