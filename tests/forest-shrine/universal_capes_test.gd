extends SceneTree
var game
var checks=0
var failures=0
var cfg="user://universal-capes-%d.cfg"%OS.get_process_id()
func _initialize():
	create_timer(90,true,false,true).timeout.connect(func():printerr("FAIL: Cape fixture timed out");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func frames(n=2):
	for i in n:await process_frame
func key(code:int,echo_:bool=false,ctrl:bool=false):
	var e=InputEventKey.new();e.physical_keycode=code;e.pressed=true;e.echo=echo_;e.ctrl_pressed=ctrl;root.push_input(e,true)
	e.pressed=false;e.echo=false;root.push_input(e,true);await frames()
func reset_body():
	var p=game.player
	if p.is_rogue_character():p.active_ability.reset_run()
	elif p.active_ability!=null:p.active_ability.cancel()
	p.global_position=Vector3(0,.15,70);p.jump_buffer=0;p.jump_windup=0;p.dodge_time=0;p.attack_left=0;p.impact_pause=0;p.air_turn=0;p.jumps_used=0;p.flying=false
	p.attack_chain.reset();p.auto_attack_enabled=false;p.smoke_mode=true;p.smoke_move=Vector2.ZERO
	for i in 8:p.velocity=Vector3.DOWN*2;p.move_and_slide()
	p.velocity=Vector3.ZERO;p.coyote=.13
func step(n:int):
	for i in n:game.player._physics_process(1.0/60)
func walk()->float:
	reset_body();game.player.smoke_move=Vector2.RIGHT;step(60)
	return game.player.position.x
func run():
	var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
	var p=game.player
	for id in range(1,13):
		p.select_character(id);p.set_scarf_equipped(false)
		await key(KEY_Z)
		var cape=p.model.ronin_scarf
		check(p.scarf_equipped and not p.gold_cloak and is_instance_valid(cape) and cape.is_visible_in_tree(),"Z equips the real red cape in preparation for character %d"%id)
		await key(KEY_Z,true);check(p.scarf_equipped,"Held-key echoes cannot unequip character %d's cape"%id)
		await key(KEY_X,false,true);check(not p.gold_cloak,"Modified X does not trigger a cape shortcut")
		await key(KEY_X)
		check(p.gold_cloak and is_instance_valid(cape) and cape.cloth.get_shader_parameter("gold_cloak"),"X switches character %d to the original gold cloth material"%id)
		p.select_character(1 if id==12 else id+1)
		check(p.gold_cloak and is_instance_valid(p.model.ronin_scarf) and p.model.ronin_scarf.is_visible_in_tree(),"Equipped gold follows character switching from %d"%id)
		await key(KEY_X);check(not p.scarf_equipped and not p.gold_cloak,"Pressing X again removes cape and powers")
	check(game.explorer_helpers.active_units().is_empty(),"Cape shortcuts never summon or replace army slots")
	await key(KEY_Z);game.show_pause();await key(KEY_X);check(p.scarf_equipped and not p.gold_cloak,"Pause blocks cape switching")
	game.resume();game.show_building_balance();await key(KEY_X);check(not p.gold_cloak,"Settings block cape switching")
	game.resume();game.open_map_editor();await key(KEY_X);check(not p.gold_cloak,"Map editor keeps its keyboard ownership")
	game.map_editor.close_discard();await frames()
	var red_button=game.forest_ui.find_child("CapeRed",true,false);var gold_button=game.forest_ui.find_child("CapeGold",true,false)
	check(red_button!=null and gold_button!=null,"Compact HUD exposes both cape keys and current selection")
	if gold_button!=null:gold_button.pressed.emit();check(p.gold_cloak,"Building-view cape button equips gold")
	game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000;game.set_physics_process(false);game.set_process(false);p.set_physics_process(false)
	game.camera_rig.yaw=0;game.camera_rig.set_process(false)
	for u in game.gate_defenders.units.values():u.set_physics_process(false)
	for id in range(1,13):
		p.select_character(id);p.set_scarf_equipped(false);var normal=walk();p.set_scarf_equipped(true);var red=walk()
		check(red>normal*2.4 and red<normal*3.3,"Red cape triples actual movement for character %d (%s / %s)"%[id,normal,red])
		reset_body();p.position.y=12;p.velocity=Vector3.ZERO;p.move_and_slide();p.jumps_used=1;p.coyote=0
		var jumps=true
		for count in [2,3,4]:
			p.jump_buffer=.15;step(4);jumps=jumps and p.jumps_used==count and p.velocity.y>0
		p.jump_buffer=.15;step(4)
		check(jumps and p.jumps_used==4,"Red cape permits four real jumps without unlimited midair resets for character %d"%id)
		p.set_gold_cloak(true);reset_body();Input.action_press("jump");step(60)
		check(p.flying and p.position.y>10 and p.velocity.y>17,"Gold cape ascends with held Jump for character %d"%id)
		Input.action_press("sprint");p.smoke_move=Vector2.RIGHT;step(60)
		check(p.velocity.x>60 and p.velocity.y>31,"Gold cape boosts horizontal travel and ascent for character %d"%id)
		Input.action_release("sprint");Input.action_release("jump");p.smoke_move=Vector2.ZERO;step(50)
		check(p.flying and p.velocity.y< -9,"Releasing Jump descends for character %d"%id)
		var uses=p.jumps_used;p.set_scarf_equipped(false)
		check(not p.can_fly() and p.jumps_used==uses,"Removing cape disables flight without refreshing jumps")
	p.set_scarf_equipped(false);reset_body();p.select_character(5);await key(KEY_Z)
	check(p.scarf_equipped,"Cape hotkeys also work during combat for native characters")
	game.sound_library.cancel();game.music.stop()
	for kind in ["AudioStreamPlayer","AudioStreamPlayer3D","AudioStreamPlayer2D"]:
		for v in game.find_children("*",kind,true,false):v.stop()
	OS.delay_msec(120);game.queue_free();paused=false;await frames()
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("UNIVERSAL_CAPES_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
