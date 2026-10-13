extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	create_timer(40).timeout.connect(func():printerr("FAIL: definitive timeout");quit(1))
	call_deferred("run")
func settle():
	for i in range(8):await process_frame
func run():
	check(ResourceLoader.exists("res://scenes/forest_title.tscn"),"A dedicated Forest Shrine title replaces the old mode selector")
	if failures:finish();return
	change_scene_to_file("res://scenes/main.tscn");await settle()
	var game=current_scene
	check(game.has_method("begin_forest") and not game.playing,"Default launch opens the definitive Forest Shrine title")
	check(game.find_child("ForestPlay",true,false)!=null,"Title offers Play Forest Shrine")
	for name_ in ["RogueSiegeButton","RogueBattleButton","ForestShrineButton"]:
		check(game.find_child(name_,true,false)==null,"Historical mode choice is hidden: "+name_)
	game.find_child("ForestPlay",true,false).pressed.emit();await settle()
	check(game.rogue_roster_open and game.menu.find_children("RogueFighter_*","Button",true,false).size()==12,"Play opens all twelve hero choices")
	game.choose_rogue_character(7);await settle()
	check(game.playing and game.model.phase=="preparing" and game.paused and game.player.character_id==7,"Fighter choice enters overhead preparation")
	game.start_wave();await settle();game.player.active_ability.player.cooldowns.drink=12
	check(game.camera_rig.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and not paused,"Start Wave enters the closer 3D combat view")
	game.model.damage_building(1,10000);await settle()
	check(game.model.phase=="defeat","Shrine destruction still ends the run")
	game.restart_area();await settle();game=current_scene
	check(game.model.wave==0 and game.model.gold==400 and game.player.character_id==7 and game.player.active_ability.player.cooldowns.drink==0,"Retry keeps the fighter and resets the settlement and skills")
	game.show_main_menu();await settle();game=current_scene
	check(not game.playing and game.find_child("ForestPlay",true,false)!=null,"Return reaches the Forest Shrine title without legacy modes")
	if "--visual" in OS.get_cmdline_user_args():
		await capture("definitive-title")
		game.begin_forest();await capture("definitive-roster")
		game.choose_rogue_character(7);game.forest_ui.message_left=0;await capture("definitive-preparation")
		game.start_wave();game.model.waves.spawn_clock=10000;game.player.position=Vector3(0,.1,55);game.camera_rig.reset_follow();game.forest_ui.message_left=0
		for i in range(6):
			game.model.waves.spawn_one();var e=game.model.enemies.values().back();e.pos=Vector3(-6+i*2,0,47-i%2*2);e.stun=100
		game.model.update_vision(game.player.position);game.sync_enemies()
		for i in range(12):await physics_frame
		var screen=game.camera_rig.camera.unproject_position(Vector3(0,0,48))
		var motion=InputEventMouseMotion.new();motion.position=screen;root.push_input(motion,true);Input.warp_mouse(screen);game.rogue_view.aim_at(screen)
		await capture("definitive-combat")
	game.queue_free();paused=false;await settle();await create_timer(.35).timeout;finish()
func capture(name_: String):
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/forest-shrine/"+name_+".png")
func finish():print("FOREST_DEFINITIVE_RESULT failures=%d"%failures);quit(1 if failures else 0)
