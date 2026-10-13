extends SceneTree
var failures=0
var checks=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	create_timer(60).timeout.connect(func():printerr("FAIL: rogue test timeout");quit(1))
	call_deferred("run")
func frames(n: int):
	for i in range(n):await physics_frame
func press(action: String,down: bool=true):
	var e=InputEventAction.new();e.action=action;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func run():
	var game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame
	check(game.camera_rig.camera.size>=100 and game.model.phase=="preparing","Preparation retains the original overhead building view")
	press("character_toggle");press("character_toggle",false);await process_frame
	check(game.rogue_roster_open,"Q opens the full fighter roster during preparation")
	if not game.rogue_roster_open:game.show_rogue_roster()
	check(game.menu.find_children("RogueFighter_*","Button",true,false).size()==11,"Forest Shrine exposes Goemon plus ten Rogue fighters")
	game.choose_rogue_character(3);await process_frame
	check(game.player.character_id==3 and game.paused and game.model.phase=="preparing","Selecting a fighter preserves the paused building phase")
	check(not is_instance_valid(game.menu) or not game.menu.visible,"Choosing a fighter dismisses its menu")
	game.forest_ui.sync();check(game.forest_ui.health.text.contains("Pirate"),"Forest HUD names the active fighter")
	game.start_wave();game.model.waves.spawn_clock=10000;await process_frame
	check(is_equal_approx(game.rogue_view._base_size(),24.0) and game.rogue_view._view_offset()==Vector3(14,28,21),"Wave camera exactly matches Rogue Siege framing")
	if failures>0:await finish(game);return
	for id in game.player.RogueRoster.ids():
		press("light_attack",false);game.show_rogue_roster();game.choose_rogue_character(id)
		check(game.model.phase=="wave" and not game.paused,"Roster selection returns to live combat")
		var p=game.player;p.active_ability.reset_run();p.position=Vector3(0,.1,70);p.velocity=Vector3.ZERO;p.hp=p.max_hp
		for actor in game.actors.values():
			if is_instance_valid(actor):actor.queue_free()
		game.actors.clear();game.enemies.clear();game.model.enemies.clear()
		game.model.waves.spawn_one();var e=game.model.enemies.values()[0];e.pos=Vector3(0,0,67);e.hp=10000;e.max_hp=10000;e.stun=100
		game.model.update_vision(p.position);game.sync_enemies();game.rogue_view.reset();await frames(2)
		var point=game.camera_rig.camera.unproject_position(e.pos+Vector3.UP)
		var motion=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true);game.rogue_view.aim_at(point)
		press("light_attack");await frames(70);press("light_attack",false)
		check(e.hp<10000,"%s uses its real primary attack against a forest raider"%p.RogueRoster.name_for(id))
		p.active_ability.player.cooldowns.drink=5
		var hp_fraction=.45;p.hp=p.max_hp*hp_fraction
		game.show_rogue_roster();await frames(3)
		check(is_equal_approx(p.active_ability.player.cooldowns.drink,5.0),"Roster freezes the current class cooldown")
		game.choose_rogue_character(1);game.show_rogue_roster();game.choose_rogue_character(id)
		check(is_equal_approx(p.hp/p.max_hp,hp_fraction) and is_equal_approx(p.active_ability.player.cooldowns.drink,5.0),"Switching preserves health fraction and spent cooldown")
		game.model.visible_cells.clear()
		check(p.active_ability.living().is_empty(),"Native class targeting excludes enemies in fog")
	game.player.select_character(7);game.player.active_ability.reset_run()
	var e=game.model.enemies.values()[0];var actor=game.actors[e.id]
	e.pos=Vector3(0,0,66);e.stun=0;game.model.update_vision(game.player.position);await frames(2)
	var target=game.player.active_ability.living()[0]
	game.player.active_ability.bash_enemy(target,Vector3.RIGHT)
	var before=e.pos;await frames(10)
	check(e.pos.x>before.x+.2 and e.clock>.8,"Knight bash pushes a forest raider and delays its attack")
	e.pos=Vector3(0,0,60);actor.freeze_for(.4);before=e.pos;await frames(10)
	check(e.pos.is_equal_approx(before),"Freeze arrests authoritative forest enemy movement")
	await frames(20)
	check(actor.frozen_left<=0 and not actor.frozen_visual.visible,"Freeze expires with its native ice visual")
	e.pos=Vector3(0,0,66);e.stun=0;game.model.hero_targetable=true
	actor.apply_defense_slow(.25,.4);before=e.pos;game.model.waves.tick(.1,game.player.position)
	check(e.pos.distance_to(before)<.2,"Elemental slow reduces actual forest movement")
	game.model.update_vision(game.player.position);await frames(2);target=game.player.active_ability.living()[0]
	game.model.visible_cells.clear();var hp_before=e.hp
	game.player.active_ability.hit(target,50)
	check(e.hp==hp_before,"A cached native target cannot be damaged or reveal impacts after losing vision")
	game.player.select_character(3);game.player.active_ability.reset_run();game.player.active_ability.player.untargetable=3
	game.model.enemies.clear();game.model.waves.spawn_one();var stalker=game.model.enemies.values()[0];stalker.pos=game.player.position;stalker.clock=0
	await frames(2)
	check(not stalker.attack,"Untargetable Rogue fighters are not attacked by the forest director")
	game.model.phase="preparing";game.set_phase_view();await process_frame
	check(game.paused and game.camera_rig.camera.size>=100 and game.model.buildings.size()==1,"Wave completion returns to the same overhead settlement")
	await finish(game)
func finish(game):
	game.queue_free();paused=false;await process_frame;await create_timer(.35).timeout
	print("FOREST_ROGUE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
