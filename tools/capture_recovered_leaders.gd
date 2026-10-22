extends SceneTree
## In-place review of actual runtime animation states; physics has separate tests.
var output=""
var game
var hero
var model
var camera: Camera3D
var label: Label
var index=0
func _initialize():run.call_deferred()
func frames(n: int):
	for i in n:await process_frame
func shot(words: String,file: String=""):
	label.text=words;await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(output+("/frame_%04d.png"%index if file.is_empty() else "/"+file+".png"));index+=1
func movement(words: String,n: int,speed: float,grounded: bool,vertical: float):
	for i in n:
		model.animate(1.0/30.0,speed,grounded,vertical,0,false,0,false)
		await shot(words)
func cast(words: String,heavy: bool):
	var combat=hero.active_ability;combat.cancel();combat.start_attack(heavy)
	hero.facing=Vector3.FORWARD;model.rotation=Vector3.ZERO
	var duration=model.animation_player.get_animation(combat.clip).length
	for i in roundi(duration*30):
		combat.elapsed=i/30.0;hero.attack_left=(duration-combat.elapsed)/combat.playback_rate
		model.animate(1.0/30.0,0,true,0,1,heavy,combat.combo+1,false)
		await shot(words)
	combat.cancel()
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--leaders-capture-dir="):output=arg.trim_prefix("--leaders-capture-dir=")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	set_meta("forest_painterly_preview",true);root.size=Vector2i(960,600)
	game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="user://leaders-preview-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(10)
	game.begin_forest();game.choose_rogue_character(14);game.start_wave();game.tuning.invincible=true;game.tuning.freeze_ai=true;await frames(12)
	paused=true;hero=game.player;game.hide();game.forest_ui.hide()
	var environment=game.get_world_3d().environment
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("24313b")
	camera=Camera3D.new();root.add_child(camera);camera.make_current();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.2
	camera.position=Vector3(-2,1.6,-4);camera.look_at(Vector3.UP*1.1)
	var canvas=CanvasLayer.new();root.add_child(canvas);label=Label.new();label.position=Vector2(20,20);label.add_theme_font_size_override("font_size",24);canvas.add_child(label)
	var previous: Node3D
	for id in [14,15]:
		if previous!=null:previous.hide()
		hero.select_character(id);hero.flying=false;hero.jumps_used=0;hero.velocity=Vector3.ZERO;hero.facing=Vector3.FORWARD
		model=hero.model;model.reparent(root);model.position=Vector3.ZERO;model.rotation=Vector3.ZERO;model.scale=Vector3.ONE;model.show()
		var name_="ED" if id==14 else "BEN"
		hero.active_ability.cancel();model.animate(.1,0,true,0,0,false,0,false)
		await shot(name_+" · RECOVERED ORIGINAL COLORS",name_.to_lower()+"-idle")
		await movement(name_+" · CONTROLLABLE RUN",30,7,true,0)
		await movement(name_+" · IDLE",8,0,true,0)
		if id==14:
			hero.jumps_used=1;await movement("ED · JUMP RISE",12,5,false,6)
			await movement("ED · JUMP FALL",12,5,false,-5);hero.jumps_used=0;await movement("ED · LAND",12,0,true,0)
			await cast("ED · BEAM RELEASE",false);await cast("ED · FIREBALL THROW",true)
		else:
			await cast("BEN · GUANDAO STRIKE",false)
			hero.flying=true
			await movement("BEN · HOLD SPACE · PROPELLER DEPLOY",24,0,false,5)
			await movement("BEN · HOLD SPACE · FLIGHT",36,0,false,5)
			await shot("BEN · ORIGINAL PROPELLER FLIGHT","ben-flight")
			await cast("BEN · PROPELLER BOMB THROW",true)
			hero.flying=false;await movement("BEN · RELEASE SPACE · LAND",36,0,true,0)
		previous=model
	print("LEADERS_PREVIEW frames=",index)
	paused=false;current_scene=null;game.queue_free();camera.queue_free();canvas.queue_free()
	for item in [hero.character_models.get(14),hero.character_models.get(15)]:
		if is_instance_valid(item):item.queue_free()
	await frames(3);quit()
