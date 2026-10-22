extends SceneTree
## Real game integration: reject missing roster wiring, silent attacks, leaked
## held inputs, and source motion that stops when the controller moves.
var failures=0
var checks=0
var game
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",message)
func frames(count: int):
	for i in count:await physics_frame
func button(pressed: bool,heavy: bool=false):
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_RIGHT if heavy else MOUSE_BUTTON_LEFT;event.pressed=pressed
	Input.parse_input_event(event);Input.flush_buffered_events()
	await frames(1)
func run():
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path="user://recovered-musashi-test-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game
	await frames(5)
	check(game.player.ROSTER.has(13),"Recovered Musashi is a separate selectable fighter")
	if not game.player.ROSTER.has(13):quit(1);return
	game.begin_forest()
	var card=game.find_child("RogueFighter_musashi",true,false)
	check(card!=null,"Character gallery contains Musashi's portrait and controls")
	game.choose_rogue_character(13)
	var p=game.player
	check(p.character_id==13 and game.selected_rogue_id==13,"Gallery selection equips and remembers Musashi")
	check(p.character_models.has(2) and p.character_models[2]!=p.model,"Edo remains a separate character")
	check(p.model.skeleton.get_bone_count()==32,"Playable model retains the recovered 32-bone rig")
	check(p.model.animation_player.get_animation_list().size()>=64,"Recovered motion library is available in game")
	var ally=load("res://scripts/forest/forest_gate_defender.gd").new()
	ally.game=game;game.add_child(ally);ally.select_character(13)
	check(game.gate_defenders.primary_range(ally)>1.0,"Musashi can also use the gate defender's melee path")
	ally.queue_free()
	game.start_wave()
	game.player.smoke_mode=true;game.tuning.freeze_ai=true;game.tuning.critical_chance=0
	game.character_tuning={};game.tuning.invincible=true
	await frames(10)
	var before=p.position
	p.smoke_move=Vector2(1,0);await frames(20);p.smoke_move=Vector2.ZERO
	check(p.position.distance_to(before)>.4,"Musashi moves through the real character controller")
	check(p.model.current_clip in [p.model.WALK,p.model.RUN,p.model.SPRINT],"Running selects recovered movement animation")
	await frames(20)
	p.jump_buffer=.15;await frames(8)
	check(p.jumps_used==1 and p.velocity.y>0,"Musashi uses the shared jump physics")
	p.jump_buffer=.15;await frames(8)
	check(p.jumps_used==2,"Musashi can double jump")
	await frames(65)
	game.player.set_physics_process(false);p.velocity=Vector3.ZERO
	p.position=Vector3(0,.05,18);p.facing=Vector3.FORWARD;p.model.rotation=Vector3.ZERO
	game.camera_rig.yaw=0
	game.model.waves.spawn_one()
	var target=game.model.enemies.values().back()
	target.pos=p.position+Vector3.FORWARD*1.3;target.hp=1000;target.max_hp=1000;target.stun=100
	game.model.update_vision(p.position);game.sync_enemies()
	var enemy=game.actors[target.id]
	var combat=p.active_ability
	combat.cancel();await button(true);await button(false)
	check(combat.is_attacking(),"Left click begins a real sword attack")
	combat.tick(.04,false)
	check(enemy.hp==1000,"Sword damage waits for contact rather than button press")
	combat.tick(.30,false)
	check(enemy.hp<1000,"Recovered sword attack damages the existing enemy actor")
	var after=enemy.hp;combat.tick(.04,false)
	check(enemy.hp==after,"Each swing damages a target at most once")
	combat.cancel();await button(true,true);await button(false,true)
	check(combat.is_attacking() and p.attack_heavy,"Right click selects the heavy sword move")
	var evade=InputEventAction.new();evade.action="dodge";evade.pressed=true
	Input.parse_input_event(evade);Input.flush_buffered_events();await frames(1)
	evade.pressed=false;Input.parse_input_event(evade);Input.flush_buffered_events()
	check(p.dodge_time==0,"Musashi ignores the shared game's added evade input")
	combat.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT);combat.tick(1.0,false)
	check(enemy.hp==after and not combat.is_attacking(),"Focus loss cancels pending sword contact")
	var guard=InputEventAction.new();guard.action="surge";guard.pressed=true;p._unhandled_input(guard)
	check(combat.guarding(),"Musashi's R input reaches the dedicated guard state")
	guard.pressed=false;p._input(guard)
	combat.cancel();p.dodge_time=0;await button(true)
	combat.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not combat.primary_held and not combat.is_attacking(),"Losing application focus releases held sword intent")
	await button(false)
	await button(true);p.select_character(1);await button(false)
	check(p.character_id==1 and not combat.primary_held and not combat.is_attacking(),"Switching away cancels attacks and held input")
	p.select_character(13);combat.tick(1.0,false)
	check(p.attack_left==0,"Returning to Musashi does not replay a stale held attack")
	p.select_character(2)
	check(p.model is MusashiModel and p.active_ability is MusashiCombat,"Edo's firecaster kit is preserved")
	p.select_character(3)
	check(p.is_rogue_character() and p.active_ability.class_id=="pirate","Native class selection still works")
	print("RECOVERED_MUSASHI_RESULT checks=",checks," failures=",failures)
	paused=false;current_scene=null;game.queue_free()
	await process_frame
	await process_frame
	game=null
	await create_timer(.35).timeout
	quit(1 if failures else 0)
