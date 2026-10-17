extends SceneTree
## Real character profiles, real hero tickets, real enemy HP and actual menu controls.
var checks=0
var failures=0
var game
var config_path="user://critical-chance-%d.cfg"%OS.get_process_id()
func _initialize():call_deferred("run")
func check(ok: bool,text_: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",text_)
func settle():
	for i in 3:await process_frame
func target()->Ninja:
	var e=Ninja.new();e.game=game;e.training_dummy=true;e.practice=true;e.position=game.player.position+Vector3(0,0,-2)
	game.add_child(e);e.set_physics_process(false);e.hp=100000;e.max_hp=100000;game.enemies.append(e);return e
func run():
	game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=config_path
	root.add_child(game);current_scene=game;await settle()
	for id in range(1,13):check(game.balance_value(id,"critical_chance")==5,"%s defaults to five percent critical chance"%game.CharacterBalance.name_for(id))
	game.show_character_balance(false,9);await settle()
	var control=game.menu.find_child("Balance_critical_chance",true,false)
	check(control!=null,"Character balance includes the editable critical chance statistic")
	if control!=null:
		control.value=73
		check(game.balance_value(9,"critical_chance")==73 and game.balance_value(4,"critical_chance")==5,"Critical chance edits affect only the selected fighter")
	game.save_settings();game.character_tuning.clear();game.load_settings()
	check(game.balance_value(9,"critical_chance")==73,"Critical chance survives save and reload")
	game.update_character_tuning(9,"critical_chance",120)
	check(game.balance_value(9,"critical_chance")==100,"Critical chance clamps at 100 percent")
	game.update_character_tuning(9,"critical_chance",-10)
	check(game.balance_value(9,"critical_chance")==0,"Critical chance clamps at zero percent")
	game.update_character_tuning(9,"critical_chance",NAN)
	check(game.balance_value(9,"critical_chance")==0,"Invalid chance values preserve the previous valid setting")
	game.reset_character_tuning(9)
	check(game.balance_value(9,"critical_chance")==5,"Reset restores the five-percent default")
	game.show_title();game.begin_forest();game.choose_rogue_character(1);await settle()
	game.start_wave();game.set_physics_process(false);game.player.set_physics_process(false)
	game.model.waves.spawn_clock=10000;game.tuning.invincible=true
	var victim=target()
	for id in range(1,13):
		game.player.select_character(id);game.player.set_physics_process(false)
		for chance in [0,100]:
			game.update_character_tuning(id,"critical_chance",chance)
			game.player.attack_chain.reset();var ticket=game.player.attack_chain.begin("critical-test")
			var before=victim.hp;victim.take_hit(10,Vector3.FORWARD,false,ticket)
			check(is_equal_approx(before-victim.hp,10 if chance==0 else 20),"%s %d%% critical chance applies exactly the intended enemy damage"%[game.CharacterBalance.name_for(id),chance])
	game.player.select_character(9);game.player.set_physics_process(false)
	game.update_character_tuning(9,"critical_chance",100);game.player.attack_chain.reset()
	var committed=game.player.attack_chain.begin("wave")
	game.update_character_tuning(9,"critical_chance",0);game.player.select_character(4)
	var before=victim.hp;victim.take_hit(10,Vector3.FORWARD,false,committed)
	check(is_equal_approx(before-victim.hp,20),"An in-flight attack retains its caster's chance after edits or fighter switching")
	before=victim.hp;victim.take_hit(18,Vector3.FORWARD,false,{"tower":true})
	check(is_equal_approx(before-victim.hp,18),"Tower arrows retain their own damage instead of inheriting hero critical chance")
	game.update_character_tuning(4,"critical_chance",5);game.player.attack_chain.reset();seed(20261014)
	var criticals=0
	for i in 600:
		game.player.attack_chain.reset();var ticket=game.player.attack_chain.begin("population")
		before=victim.hp;victim.take_hit(1,Vector3.FORWARD,false,ticket)
		if before-victim.hp>1.5:criticals+=1
	check(criticals>=12 and criticals<=50,"Five-percent critical chance produces occasional criticals, not guaranteed or absent hits")
	var labels=game.find_children("*","Label3D",true,false)
	check(labels.any(func(l):return "CRIT" in l.text),"Critical enemy damage gets an explicit CRIT indicator")
	game.queue_free();paused=false;await settle();await create_timer(.4).timeout
	DirAccess.remove_absolute(config_path)
	print("CRITICAL_CHANCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
