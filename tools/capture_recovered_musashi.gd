extends SceneTree
var game
var output="res://build/Other Files/Playable Musashi"
func _initialize():run.call_deferred()
func frames(n: int):
	for i in n:await process_frame
func shot(label: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+label+".png")
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--musashi-capture-dir="):output=arg.trim_prefix("--musashi-capture-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	set_meta("forest_painterly_preview",true)
	root.size=Vector2i(1280,800)
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path="user://musashi-capture-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game
	await frames(10)
	game.begin_forest();await frames(5)
	game.menu.find_child("RogueFighter_musashi",true,false).grab_focus()
	await frames(10);await shot("01-character-gallery")
	game.choose_rogue_character(13);game.start_wave();game.tuning.invincible=true
	game.model.waves.spawn_clock=10000.0
	await frames(25);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await shot("02-musashi-gameplay")
	paused=true
	var p=game.player
	p.invuln=0;p.model.show();p.facing=Vector3.FORWARD;p.model.rotation=Vector3.ZERO
	game.forest_ui.hide()
	var camera=Camera3D.new();game.add_child(camera);camera.make_current()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.2
	camera.global_position=p.position+Vector3(-2.3,1.9,-3.5)
	camera.look_at(p.position+Vector3.UP*.95)
	p.active_ability.cancel();p.model.animate(0,0,true,0,0,false,0,false)
	await shot("03-musashi-front")
	p.active_ability.start_attack(false);p.active_ability.elapsed=.23
	p.model.animate(0,0,true,0,.5,false,1,false)
	await shot("04-musashi-sword")
	p.active_ability.cancel();p.active_ability.start_attack(true);p.active_ability.elapsed=.53
	p.model.animate(0,0,true,0,.5,true,0,false)
	await shot("05-musashi-heavy")
	paused=false;current_scene=null;game.queue_free();await frames(2)
	quit()
