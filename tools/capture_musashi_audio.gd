extends SceneTree
## Review stage, not recorded combat: runtime rig/trail with source sample cues.
var game
var hero
var model
var combat
var output=""
var index=0
var label: Label
var cues=[]
func _initialize():run.call_deferred()
func frames(n: int):
	for i in n:await process_frame
func shot(title: String):
	label.text=title
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(output+"/frame_%04d.png"%index)
	index+=1
func idle(n: int):
	combat.cancel()
	for i in n:
		model.animate(1.0/30.0,0,true,0,0,false,0,false)
		await shot("MUSASHI · ORIGINAL AUDIO / ANIMATION REVIEW")
func attack(heavy: bool,cut: int=0):
	combat.combo_timer=0 if cut==0 else 1
	combat.combo=cut-1
	combat.start_attack(heavy)
	if not heavy:
		combat.clip=model.STRIKES[cut];hero.attack_duration=model.animation_player.get_animation(combat.clip).length
	var start=index
	var swing=13 if heavy else 0
	var contact=15 if heavy else [2,3,6][cut]
	cues.append({"frame":start+swing,"file":"lumina_swing" if heavy else ("fusion_swing_2" if cut==1 else "fusion_swing"),"gain":.7})
	cues.append({"frame":start+swing,"file":"voice_exertion" if cut==2 else "voice_attack","gain":.55})
	cues.append({"frame":start+contact,"file":"fusion_finisher_hit" if cut==2 else "sword_hit","gain":.5})
	for i in roundi(hero.attack_duration*30):
		combat.elapsed=i/30.0
		hero.attack_left=hero.attack_duration-combat.elapsed
		model.animate(1.0/30.0,0,true,0,1,heavy,cut+1,false)
		await shot("LUMINA · OVERHEAD DOWNSTROKE + CONTACT SAMPLE" if heavy else "FUSION · CUT %d + CONTACT SAMPLE"%(cut+1))
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audio-capture-dir="):output=arg.trim_prefix("--audio-capture-dir=")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(960,600)
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path="user://musashi-audio-preview-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(10)
	game.begin_forest();game.choose_rogue_character(13);game.start_wave();await frames(10)
	paused=true
	hero=game.player;combat=hero.active_ability;model=hero.model
	model.reparent(root);model.position=Vector3.ZERO;model.rotation=Vector3.ZERO
	model.scale=Vector3.ONE;model.show();combat.cancel()
	game.hide();game.forest_ui.hide()
	var camera=Camera3D.new();root.add_child(camera);camera.make_current()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.9
	camera.position=Vector3(-2,1.5,-4);camera.look_at(Vector3.UP*.95)
	var world=WorldEnvironment.new();root.add_child(world);world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("24313b")
	var canvas=CanvasLayer.new();root.add_child(canvas)
	label=Label.new();label.position=Vector2(20,20);label.add_theme_font_size_override("font_size",22);canvas.add_child(label)
	hero.jumps_used=0
	await idle(15)
	for cut in 3:
		await attack(false,cut);await idle(9)
	await attack(true);await idle(15)
	camera.position=Vector3(0,1.4,-4);camera.look_at(Vector3.UP*.95)
	await attack(true);await idle(20)
	var file=FileAccess.open(output+"/audio_cues.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fps":30,"frames":index,"cues":cues},"\t"));file.close()
	print("MUSASHI_AUDIO_PREVIEW frames=",index)
	paused=false;current_scene=null;game.queue_free();model.queue_free();canvas.queue_free();world.queue_free();camera.queue_free();await frames(3)
	quit()
