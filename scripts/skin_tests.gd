extends "res://scripts/musashi_tests.gd"

func capture_skin(label: String):
	if not visual:return
	await wait(.15)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/goemon-skins/"+label+".png")

func run():
	visual="--skins-visual" in OS.get_cmdline_user_args()
	var old_path=game.settings_path
	var old_settings=game.settings.duplicate()
	game.settings_path="user://skin-tests-%s.cfg" % OS.get_process_id()
	game.load_settings()
	var p=game.player
	var hero=p.character_models[1]
	check(game.settings.goemon_skin=="original" and hero.skin_id=="original","New profiles keep original Goemon")
	var config=ConfigFile.new();config.set_value("settings","volume",.37);config.save(game.settings_path)
	game.load_settings()
	check(game.settings.goemon_skin=="original" and is_equal_approx(game.settings.volume,.37),"Legacy settings retain preferences and default to original")
	config.set_value("settings","goemon_skin","missing-skin");config.save(game.settings_path);game.load_settings()
	check(game.settings.goemon_skin=="original","Unknown saved skin falls back to original")
	var rig=hero.skeleton;var locomotion=hero.locomotion;var pipe=hero.pipe;var scarf=hero.ronin_scarf
	var original_meshes={}
	for part in HeroSkins.PARTS:original_meshes[part]=hero.rig_visual.find_child(part,true,false).mesh
	game.show_settings(false)
	check(game.menu.find_child("PlayableSkinsButton",true,false)!=null,"Main Settings exposes playable skins")
	game.menu.find_child("PlayableSkinsButton",true,false).pressed.emit()
	await wait(.15)
	var picker=game.menu.find_child("SkinPicker",true,false)
	check(picker!=null and picker.cards.size()==2,"Skin picker presents both live model previews")
	await capture_skin("01-picker-original")
	picker.find_child("SelectSkin_ren",true,false).pressed.emit()
	check(hero.skin_id=="ren" and game.settings.goemon_skin=="ren","Choosing Ren immediately applies the alternate look")
	check(hero.rig_visual.scale.is_equal_approx(Vector3.ONE*HeroSkins.CATALOG[1].display_scale) and p.scale==Vector3.ONE*1.65,"Skin uses its catalog display scale and leaves the menu player scale intact")
	check(picker.find_child("SelectSkin_ren",true,false).disabled and not picker.find_child("SelectSkin_original",true,false).disabled,"Picker marks the equipped skin")
	await capture_skin("02-picker-ren")
	picker.find_child("SkinSurgePreview",true,false).button_pressed=true
	check(picker.cards[1].preview.hair_gold.visible and not hero.hair_gold.visible,"Golden preview is isolated from live gameplay")
	await capture_skin("03-picker-gold")
	for part in HeroSkins.PARTS:check(hero.rig_visual.find_child(part,true,false).mesh!=original_meshes[part],"Ren replaces visual resource: "+part)
	check(hero.skeleton==rig and hero.locomotion==locomotion and hero.pipe==pipe and hero.ronin_scarf==scarf,"Skin keeps the live rig, animator, weapon and cloak")
	game.settings.goemon_skin="original";hero.apply_skin("original");game.load_settings()
	check(hero.skin_id=="ren" and game.settings.goemon_skin=="ren","Saved skin is restored by settings reload")
	var startup=HeroModel.new();startup.skin_id=game.settings.goemon_skin;add_child(startup)
	check(startup.skin_id=="ren" and startup.hair_normal.mesh==hero.hair_normal.mesh,"A new character loads the saved skin on startup")
	startup.queue_free()
	game.tuning.freeze_ai=true;game.tuning.invincible=true
	game.start_game();game.encounters.enabled=false;p.smoke_mode=true
	await wait(.3)
	if visual:
		game.camera_rig.set_process(false)
		game.camera_rig.camera.global_position=p.position+Vector3(-3,2.5,-6)
		game.camera_rig.camera.look_at(p.position+Vector3.UP*1.7)
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await capture_skin("04-ren-gameplay")
	p.activate_surge();p.set_scarf_equipped(true)
	game.show_pause();game.show_settings(true)
	game.menu.find_child("PlayableSkinsButton",true,false).pressed.emit();await wait(.1)
	picker=game.menu.find_child("SkinPicker",true,false)
	var remaining=p.surge_left;var time_left=game.encounters.remaining()
	var hp=p.hp;var position_before=p.position;var character_before=p.character_id
	picker.select_skin("original");picker.select_skin("ren")
	await wait(.1)
	check(game.paused and get_tree().paused and p.surge_left==remaining and game.encounters.remaining()==time_left,"Skin selection keeps gameplay and Surge timers paused")
	check(hero.hair_gold.visible and not hero.hair_normal.visible and p.scarf_equipped,"Changing skins preserves active Surge and cloak")
	check(p.hp==hp and p.position==position_before and p.character_id==character_before,"Skin selection preserves health, position and active character")
	game.resume();await capture_skin("05-ren-surge-cloak")
	p.end_surge();p.set_scarf_equipped(false)
	p.select_character(2);var edo=p.model
	game.select_goemon_skin("original");game.select_goemon_skin("ren")
	check(p.character_id==2 and p.model==edo,"Selecting a Goemon skin while Edo is active keeps Edo selected")
	p.select_character(1)
	check(p.model==hero and hero.skin_id=="ren","Switching back to Goemon retains the chosen skin")
	game.restart_area();game.encounters.enabled=false
	check(p.character_models[1].skin_id=="ren","Restart retains the chosen skin")
	# Gameplay input runs on the skin's unchanged character controller.
	p.smoke_mode=true;await wait(.2)
	var before=p.position;p.smoke_move=Vector2(0,-1);await wait(.25);p.smoke_move=Vector2.ZERO
	check(p.position.distance_to(before)>.5,"Ren moves through the existing controller")
	await key(KEY_SPACE);await wait(.08);check(p.jumps_used==1,"Ren jumps")
	await key(KEY_SPACE);await wait(.08);check(p.jumps_used==2,"Ren double jumps")
	await wait(.8)
	for code in [KEY_1,KEY_2,KEY_3]:
		await key(code);check(p.attack_left>0 or p.quick_attacks.active,"Ren starts number attack "+str(code));await wait(.9)
	await key(KEY_E);check(p.forward_dash.active,"Ren starts Goemon's dash")
	await wait(.4)
	for i in range(8):game.select_goemon_skin("original");game.select_goemon_skin("ren")
	check(hero.skeleton==rig and hero.locomotion==locomotion and hero.pipe==pipe,"Repeated swaps do not rebuild the animation or attachment nodes")
	game.select_goemon_skin("original")
	check(hero.rig_visual.scale==Vector3.ONE,"Returning to Original restores its exact visual scale")
	for part in HeroSkins.PARTS:check(hero.rig_visual.find_child(part,true,false).mesh==original_meshes[part],"Original restored exactly: "+part)
	game.show_main_menu();game.settings_path=old_path;game.settings=old_settings
	hero.apply_skin(game.settings.goemon_skin);game.apply_music_setting()
	DirAccess.remove_absolute("user://skin-tests-%s.cfg" % OS.get_process_id())
	print("SKIN_TEST_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
