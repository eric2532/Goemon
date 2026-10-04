extends SceneTree
## Run with the editor binary from an empty --path, using --main-pack and --script.
var game
var failed=0
var passed=0

func _initialize():call_deferred("run")

func check(ok: bool,words: String):
	print("PASS: " if ok else "FAIL: ",words)
	if ok:passed+=1
	else:failed+=1

func key(code: Key):
	for down in [true,false]:
		var event=InputEventKey.new();event.physical_keycode=code;event.pressed=down
		root.push_input(event,true);await process_frame

func click(button: Button):
	var point=button.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	root.push_input(motion,true)
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
		event.position=point;event.global_position=point;event.pressed=down
		root.push_input(event,true);await process_frame

func capture(name: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/defense-heroes-packaged-"+name+".png")

func run():
	game=load("res://scripts/game.gd").new();root.add_child(game)
	game.smoke_test=true;root.set_flag(Window.FLAG_NO_FOCUS,true)
	await process_frame
	check(game.menu.find_child("TowerDefenseButton",true,false)!=null,"Release main menu offers Fire Siege")
	game.start_defense(false)
	for i in range(10):await process_frame
	check(game.paused and game.defense_drafting(),"Release opens with the mandatory three-card draft")
	await key(KEY_H)
	check(not game.barracks.menu_open,"H cannot bypass the wave draft")
	await key(KEY_1)
	check(not game.paused and game.encounters.upgrade_level("ice_shells")==1,"Physical card input resumes the siege")
	check(game.world.get_node_or_null("MainCastleWall")!=null and game.world.get_node_or_null("CastleBarracks")!=null,"Release includes castle wall and courtyard barracks")
	check(game.world.cannon_sites.size()==24 and game.world.playable_bounds==Rect2(-80,-400,160,760),"Release preserves compact map and all 24 tower mounts")
	var definitions=load("res://scripts/defense_hero_catalog.gd").definitions()
	check(definitions.size()==10,"Release contains all ten named character profiles")
	check(not FileAccess.file_exists("res://asset_packs/hero_concepts/glb/sen.glb") and not FileAccess.file_exists("res://assets/blender/defense_heroes/sen.blend"),"Release excludes the dense upstream sculptures and editable Blender sources")
	for data in definitions:
		var scene=load(data.asset).instantiate();root.add_child(scene)
		var players=scene.find_children("*","AnimationPlayer",true,false)
		var complete=players.size()==1
		if complete:
			for clip in ["Idle","Walk","Run","Sprint","Strafe_L_Walk","Strafe_R_Walk"]:complete=complete and players[0].has_animation(clip)
		check(complete and ResourceLoader.exists(data.portrait),"Release bundles %s model, portrait, and Goemon locomotion clips" % data.name)
		scene.queue_free()
	await key(KEY_H)
	check(game.paused and game.barracks.menu_open and game.menu.find_children("HeroSummon_*","Button",true,false).size()==10,"H opens all ten selectable barracks cards in the release")
	await capture("barracks")
	var before=game.encounters.money
	await click(game.menu.find_child("HeroSummon_sen",true,false))
	check(game.barracks.living_count()==1 and game.encounters.money==before-300 and not game.paused,"Clicking Sen pays exactly 300 gold and resumes battle")
	var hero=game.barracks.heroes[0]
	check(hero.position.z>180 and absf(hero.position.x)<6 and not game.enemies.any(func(actor):return actor==hero),"Companion starts behind the castle gateway in its separate ally roster")
	check(hero.model is HeroModel and hero.model.locomotion is HeroLocomotion and is_equal_approx(hero.attack_duration(),1.18),"Character uses the actual Goemon model, locomotion and three-stage combo")
	await key(KEY_H)
	var cooldown=game.barracks.cooldown_left
	for i in range(8):await process_frame
	check(game.menu.find_child("HeroSummon_sen",true,false).disabled and is_equal_approx(cooldown,game.barracks.cooldown_left),"Summon cooldown cannot advance or be bypassed while the barracks is paused")
	await key(KEY_G)
	check(game.paused and game.kennel.menu_open and not game.barracks.menu_open and game.menu.find_children("DogSummon_*","Button",true,false).size()==10,"G switches directly from characters to the preserved dog roster")
	before=game.encounters.money
	await click(game.menu.find_child("DogSummon_kogane",true,false))
	check(game.kennel.living_count()==1 and game.barracks.living_count()==1 and game.encounters.money==before-150,"Dogs and characters can be summoned together with independent cooldowns")
	await key(KEY_G);await key(KEY_H)
	check(game.barracks.menu_open and not game.kennel.menu_open,"H switches back from the dog roster without unpausing")
	await key(KEY_ESCAPE)
	check(not game.paused and not game.barracks.menu_open,"Escape closes the barracks and resumes battle")
	game.encounters.set_physics_process(false);game.player.set_physics_process(false)
	game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
	game.camera_rig.camera.global_position=Vector3(8,5,204)
	game.camera_rig.camera.look_at(Vector3(0,1,195))
	game.hud.banner_time=0;game.hud.toast_time=0
	await capture("castle")
	game.show_main_menu();await process_frame
	check(game.barracks.living_count()==0 and not game.barracks.active,"Leaving the run clears the companion roster")
	game.start_defense(true);await process_frame
	await key(KEY_1)
	check(game.encounters.money==650 and game.encounters.base_hp==50,"Hard mode retains its limited opening resources")
	await key(KEY_H)
	await click(game.menu.find_child("HeroSummon_sen",true,false))
	check(game.barracks.living_count()==1 and game.barracks.dogs[0].profile_id=="sen" and game.encounters.money==350,"Hard mode can summon Sen from its 650-gold budget")
	game.show_main_menu();await process_frame
	print("PACKAGED_HERO_RESULT passes=",passed," failures=",failed)
	game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	var deadline=Time.get_ticks_msec()+300
	while Time.get_ticks_msec()<deadline:await process_frame
	quit(1 if failed else 0)
