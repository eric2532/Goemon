extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Catches missing Hero input/pose contacts and a shield that blocks melee too.
func run():
	await setup_fixture()
	var p=game.player
	check(p.ROSTER.has(17),"The live Forest hero can equip Yae's native combat kit")
	if not p.ROSTER.has(17):
		game.queue_free();paused=false;await frames();quit(1);return
	p.select_character(17)
	var combat=p.active_ability
	p.position=Vector3(0,-.01,60);p.velocity=Vector3.DOWN;p.move_and_slide();p.velocity=Vector3.ZERO
	check(p.is_on_floor(),"Yae's contact fixture begins on physical floor collision")
	combat.cancel();tap("light_attack");await step(180)
	check(not contacts.is_empty(),"Real LMB and the post-pose tick land Yae's katana on a fitted target")
	combat.cancel();var target_hp=game.training_dummy.hp;tap("heavy_attack");var launched=false
	for i in 55:
		p._physics_process(1.0/60)
		launched=launched or not get_nodes_in_group("yae_projectiles").is_empty()
		p.position=ORIGIN;p.velocity=Vector3.ZERO
		if i%40==0:await process_frame
	check(launched or game.training_dummy.hp<target_hp,"Real RMB releases a bazooka projectile or confirms its target impact: mode=%s elapsed=%s"%[combat.mode,combat.elapsed])
	combat.cancel()
	var held=InputEventAction.new();held.action="equip";held.pressed=true;p._unhandled_input(held)
	await step(60)
	p.hp=p.max_hp;p.invuln=0;game.tuning.invincible=false
	var before=p.hp
	p.take_hit(5,Vector3.BACK,true)
	check(p.hp==before,"Sword Shield blocks a real incoming projectile damage event")
	p.smoke_mode=true;p.smoke_move=Vector2(1,0)
	var origin=p.position
	for i in 12:p._physics_process(1.0/60)
	check(Vector2(p.position.x-origin.x,p.position.z-origin.z).length()<.05,"Sword Shield prevents horizontal travel despite live movement input")
	p.smoke_move=Vector2.ZERO;p.invuln=0
	p.take_hit(5,Vector3.BACK,false)
	check(p.hp<before,"Sword Shield still permits ordinary melee damage")
	held.pressed=false;p._input(held);combat.cancel();p.invuln=0
	before=p.hp;p.take_hit(5,Vector3.BACK,true)
	check(p.hp<before,"Releasing Sword Shield restores projectile damage")
	combat.cancel();p.invuln=0;p.hp=p.max_hp
	tap("surge");tap("sky_strike")
	check(not combat.is_attacking() and p.surge_left<=0 and not p.sky_strike.active,"Excluded exploration powers do not activate Goemon's shared skills")
	combat.cancel();p.impact_pause=0;p.position=Vector3(0,-.01,60);p.velocity=Vector3.DOWN;p.move_and_slide();p.velocity=Vector3.ZERO
	p.model.locomotion.reset();p.last_foot_events=0;p.smoke_move=Vector2(.1,0)
	for voice in game.voices:voice.stop()
	var heard_slow_step=false
	for i in 120:
		p._physics_process(1.0/60)
		heard_slow_step=heard_slow_step or game.voices.any(func(voice):return voice.playing and voice.get_meta("kind","")=="step")
	check(heard_slow_step,"Slow native walking dispatches the original footfall through the real Hero: events=%s speed=%s floor=%s"%[p.model.locomotion.step_events,p.model.locomotion.actual_speed,p.is_on_floor()])
	p.smoke_move=Vector2.ZERO
	held.action="heavy_attack";held.pressed=true;p._unhandled_input(held);await step(20)
	p.select_character(1)
	check(not combat.active and not combat.is_attacking(),"Switching fighters cancels Yae's pending charged shot")
	held.pressed=false;p._input(held)
	var ally=load("res://scripts/forest/forest_gate_defender.gd").new();ally.game=game;game.add_child(ally);ally.select_character(17)
	check(game.gate_defenders.primary_range(ally)>1.0,"Gate defender Yae approaches within her native katana reach")
	ally.queue_free();p.select_character(17);p.invuln=0;p.hp=1
	p.take_hit(5,Vector3.FORWARD)
	check(p.hp<=0 and game.last_sound_voice.stream==game.sound_library.original_for(17,"death"),"A fatal hit plays Yae's original death voice")
	check(p.model.source_action==0x2d,"Defeat displays Yae's native death pose before the game freezes")
	game.queue_free();paused=false;await frames();await create_timer(.15).timeout
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("YAE_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
