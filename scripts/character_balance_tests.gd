extends SceneTree
## Real Forest menus + player: catches lost legacy preferences, shared hero edits,
## and menu exits that accidentally resume or leave an invisible menu active.
var checks=0
var failures=0
var game
var config_path="user://character-balance-test-%s.cfg" % OS.get_process_id()

func _initialize():call_deferred("run")
func settle():
	for i in range(5):await process_frame
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",message)
func button(name_: String):return game.menu.find_child(name_,true,false)
func frames(count: int):
	for i in range(count):await physics_frame

func run():
	var legacy=ConfigFile.new()
	legacy.set_value("settings","volume",.37)
	legacy.set_value("prototype","max_hp",120.0)
	legacy.set_value("prototype","damage_mult",1.4)
	legacy.set_value("prototype","walk_speed",11.0)
	legacy.set_value("unrelated","keep","old preference")
	legacy.save(config_path)
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path=config_path
	root.add_child(game);current_scene=game
	game.tuning.critical_chance=0.0
	await settle()
	check(button("ForestSettings")!=null,"Forest title restores Settings access")
	check(game.has_method("balance_value"),"Game supports independent character balance")
	if failures:await finish();return
	button("ForestSettings").pressed.emit();await settle()
	check(button("CharacterBalanceButton")!=null and button("SoundStudioButton")!=null,"Settings exposes character balance and recording controls")
	check(is_equal_approx(game.settings.volume,.37) and is_equal_approx(game.balance_value(1,"max_hp"),120),"Legacy saved volume and player balance survive loading")
	check(is_equal_approx(game.balance_value(7,"max_hp"),150),"Untouched Knight keeps its native health ratio on the legacy baseline")
	button("CharacterBalanceButton").pressed.emit();await settle()
	var picker=button("BalanceCharacter")
	check(picker!=null and picker.item_count==12,"Balance editor offers all twelve characters")
	game.tuning.max_hp=100
	game.show_character_balance(false,5);await settle()
	check(button("Balance_max_hp").value==85,"Ninja's 85 HP is displayed without rounding it to 90")
	game.show_character_balance(false,7);await settle()
	check(button("Balance_max_hp").value==125,"Knight's 125 HP is displayed without rounding it to 130")
	game.show_character_balance(false,10);await settle()
	check(absf(button("Balance_jump_speed").value-21.99102089)<.00051,"Native elevated jump values retain three-decimal precision in the editor")
	game.tuning.max_hp=2000;game.show_character_balance(false,7);await settle()
	check(button("Balance_max_hp").value==2500,"High legacy balance values retain the native health ratio in the editor")
	game.tuning.max_hp=120;game.show_character_balance(false,1);await settle()
	picker=button("BalanceCharacter")
	var hp=button("Balance_max_hp")
	hp.value=240
	button("Balance_damage_mult").value=2.0
	check(game.player.max_hp==240 and game.player.damage_multiplier()==2.0,"Editing Goemon updates real health and outgoing damage")
	picker.select(1);picker.item_selected.emit(1);await settle()
	check(button("Balance_max_hp").value==120 and button("Balance_beam_width")!=null,"Edo opens with independent values and beam controls")
	button("Balance_max_hp").value=180
	button("Balance_beam_width").value=4.0
	check(game.player.max_hp==240,"Editing a different character does not alter the current hero")
	game.player.select_character(2)
	check(game.player.max_hp==180 and is_equal_approx(game.player.damage_multiplier(),1.4),"Switching Goemon to Edo applies Edo health and damage")
	game.update_character_tuning(3,"walk_speed",14.0)
	game.update_character_tuning(3,"damage_mult",2.5)
	game.player.select_character(3)
	check(game.hero_tuning("walk_speed")==14 and game.player.damage_multiplier()==2.5,"Native classes consume their own movement and damage values")
	game.save_settings();game.character_tuning.clear();game.load_settings()
	check(game.balance_value(1,"max_hp")==240 and game.balance_value(2,"max_hp")==180 and game.balance_value(3,"walk_speed")==14,"All edited character profiles survive save and reload")
	legacy.load(config_path)
	check(legacy.get_value("unrelated","keep")=="old preference" and legacy.get_value("prototype","max_hp")==120,"Saving profiles preserves the legacy baseline and unrelated preferences")
	game.reset_character_tuning(2)
	check(game.balance_value(2,"max_hp")==120 and game.balance_value(1,"max_hp")==240,"Reset affects only the selected character and restores the saved baseline")
	game.update_character_tuning(1,"max_hp",NAN)
	check(game.balance_value(1,"max_hp")==240,"Invalid numeric edits cannot poison an existing profile")
	game.show_settings(false);await settle();button("SoundStudioButton").pressed.emit();await settle()
	check(game.menu.find_child("SoundStudio",true,false)!=null,"Existing Sound Studio opens from the restored Settings menu")
	check(not game.sound_library.recording and (game.sound_library.mic==null or not game.sound_library.mic.playing),"Opening the studio leaves the microphone off")
	var saved_count=game.sound_library.custom.size()
	game.show_settings(false);await settle()
	check(game.sound_library.custom.size()==saved_count,"Leaving recording settings retains all loaded custom recordings")
	game.show_title();game.begin_forest();game.choose_rogue_character(1);await settle()
	game.show_pause();await settle()
	check(game.forest_ui.find_child("ForestPauseSettings",true,false)!=null,"Preparation pause restores Settings access")
	game.show_settings(true);await settle()
	game.show_pause();await settle()
	check(game.menu==null and game.forest_ui.visible and game.ordinary_pause,"Back from settings restores the visible pause menu")
	game.resume();await settle()
	check(not game.ordinary_pause and paused and game.model.phase=="preparing","Closing settings preserves preparation's paused simulation")
	game.start_wave();game.show_pause();game.show_settings(true);await settle()
	check(paused and game.model.phase=="wave","Wave gameplay stays paused while changing settings")
	game.resume();await settle()
	check(not paused and game.menu==null and game.forest_ui.visible,"Resume removes settings and restores live wave gameplay")
	game.model.waves.spawn_clock=10000
	var hero=game.player
	hero.smoke_mode=true;hero.select_character(3);hero.active_ability.reset_run()
	hero.position=Vector3(0,.1,70);hero.velocity=Vector3.ZERO;hero.smoke_move=Vector2.UP;game.camera_rig.yaw=0
	await frames(45)
	check(absf(Vector2(hero.velocity.x,hero.velocity.z).length()-14.0)<.15,"Pirate's saved run speed drives actual character movement")
	hero.smoke_move=Vector2.ZERO;hero.position=Vector3(0,.1,70);hero.velocity=Vector3.ZERO;await frames(20)
	game.update_character_tuning(3,"jump_speed",20.0);hero.jump_buffer=.15
	await frames(2)
	check(hero.velocity.y>18 and hero.velocity.y<=20,"Pirate's saved jump setting changes the physical jump impulse")
	hero.position=Vector3(0,.1,70);hero.velocity=Vector3.ZERO;await frames(20)
	game.model.waves.spawn_one()
	var enemy=game.model.enemies.values().back();enemy.pos=Vector3(0,0,67);enemy.hp=1000;enemy.max_hp=1000;enemy.stun=100
	game.model.update_vision(hero.position);game.sync_enemies();await frames(2)
	var actor=game.actors[enemy.id]
	hero.active_ability.hit({"node":actor,"pos":actor.global_position,"hp":actor.hp,"type":"ninja"},20)
	check(is_equal_approx(actor.hp,950),"Pirate's own damage multiplier changes damage to a real forest enemy")
	hero.select_character(1);game.update_character_tuning(1,"coin_damage",33.0);game.update_character_tuning(1,"coin_speed",45.0)
	var coin=game.spawn_gold_coin(hero.position+Vector3.UP,Vector3.FORWARD,false,false,1.0)
	check(is_equal_approx(coin.damage,66.0) and is_equal_approx(coin.velocity.length(),45.0),"Goemon's saved coin settings affect the actual projectile")
	coin.queue_free();hero.select_character(2);game.update_character_tuning(2,"beam_width",4.0);game.update_character_tuning(2,"beam_length",45.0)
	hero.musashi.shield_left=10;hero.musashi.start_beam("surge")
	check(is_instance_valid(hero.musashi.beam) and is_equal_approx(hero.musashi.beam.balance.beam_radius,2.0) and is_equal_approx(hero.musashi.beam.balance.beam_length,45.0),"Edo's saved dimensions reach the actual beam")
	hero.musashi.cancel();hero.select_character(1)
	if "--visual" in OS.get_cmdline_user_args():
		game.show_pause();game.show_settings(true);await capture("settings")
		game.show_character_balance(true,3);await capture("pirate-balance")
		game.show_character_balance(true,1);await capture("goemon-balance")
		game.show_character_balance(true,2);await capture("edo-balance")
		game.show_sound_studio(true);await capture("recording")
		game.show_pause();await capture("pause")
		game.show_title();await capture("title")
	await finish()

func capture(label_: String):
	await settle();await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/character-settings")
	root.get_texture().get_image().save_png("res://docs/character-settings/"+label_+".png")

func finish():
	# Let the last captured menu's asynchronous Metal shaders finish before teardown.
	if "--visual" in OS.get_cmdline_user_args():await create_timer(1.0).timeout
	game.queue_free();current_scene=null;paused=false;await settle()
	await create_timer(.3).timeout
	DirAccess.remove_absolute(config_path)
	print("CHARACTER_BALANCE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
