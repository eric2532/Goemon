extends SceneTree
## Native-renderer review of the actual gallery, character, and current world.
var game
var output=OS.get_environment("SASUKE_CAPTURE_DIR")
func _initialize():run.call_deferred()
func frames(n:int):
	for i in n:await process_frame
func capture(label_:String):
	await frames(3)
	await RenderingServer.frame_post_draw
	var path=output.path_join(label_+".png")
	var result=root.get_texture().get_image().save_png(path)
	print("CAPTURE ",label_," result=",result," ",path)
func run():
	if output.is_empty():output="/tmp"
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path="user://sasuke-capture-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(8)
	game.begin_forest();await frames(4)
	var card=game.find_child("RogueFighter_sasuke",true,false)
	if card!=null:
		var grid=card.get_parent();var scroll=grid.get_parent()
		if scroll is ScrollContainer:scroll.ensure_control_visible(card)
	await capture("sasuke-gallery")
	game.choose_rogue_character(16);game.start_wave()
	game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.model.waves.pending=999;game.model.waves.spawn_clock=100000
	await frames(8)
	var p=game.player
	p.set_physics_process(false);game.set_physics_process(false);game.camera_rig.set_process(false)
	p.position=Vector3(0,game.model.surface_height(0,18)+.05,18);p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD
	p.model.rotation=Vector3.ZERO;p.model.animate(0,0,true,0,0,false,0,false);p.model.sync_skeleton()
	var camera=game.camera_rig.camera
	camera.global_position=p.global_position+Vector3(4.8,3.3,-7.0);camera.look_at(p.global_position+Vector3.UP*1.2);camera.fov=42
	game.forest_ui.sync()
	await capture("sasuke-in-game")
	for entry in [["sasuke-gold-combo","light_attack",.16],["sasuke-bomb","heavy_attack",.2],["sasuke-hair","sky_strike",.24],["sasuke-jetpack","surge",.42]]:
		p.active_ability.cancel()
		var event=InputEventAction.new();event.action=entry[1];event.pressed=true;p._unhandled_input(event)
		for i in roundi(float(entry[2])*60):p._physics_process(1.0/60)
		p.model.sync_skeleton();await capture(entry[0])
	p.active_ability.cancel();game.queue_free();current_scene=null;paused=false;await frames(3)
	print("SASUKE_CAPTURE_COMPLETE");quit()
