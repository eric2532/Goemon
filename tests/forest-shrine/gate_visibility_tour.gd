extends SceneTree
var game
var out="res://build/Other Files/Castle Door"
var cfg="user://gate-visibility-tour-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func frames():
	for i in 8:await process_frame
func capture(label_:String):
	game.world.sync(1)
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label_+".png"))
func run():
	if DisplayServer.get_name()=="headless":quit(1);return
	set_meta("forest_painterly_preview",true)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
	await frames()
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.ui.hide();game.forest_ui.hide();game.player.hide();AudioServer.set_bus_mute(0,true)
	game.model.defenders.clear()
	for w in game.model.workers.values():w.pos=Vector3(140,0,140)
	var gate=game.model.buildings.values().filter(func(b):return b.kind=="gate")[0]
	var center:Vector3=game.model.center(gate);var outward=game.model.waves.navigation.gate_outward(gate)
	var right=outward.cross(Vector3.UP);var camera=game.camera_rig.camera
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.global_position=center+outward*20+right*5+Vector3.UP*7;camera.look_at(center+Vector3.UP*5)
	game.model.hero_position=center+outward*18
	for fraction in [1.0,.9,.6,.35,.1]:
		gate.hp=gate.max_hp*fraction
		await capture("outside-hp-%d"%roundi(fraction*100))
	camera.global_position=center-outward*18+Vector3.UP*6;camera.look_at(center+Vector3.UP*5)
	await capture("inside-view-opaque-reference")
	game.model.hero_position=center-outward*18
	await capture("inside-view-translucent")
	gate.hp=gate.max_hp
	await capture("inside-view-repaired")
	print("GATE_VISIBILITY_RENDER_RESULT captures=8 draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
	await frames()
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	quit()
