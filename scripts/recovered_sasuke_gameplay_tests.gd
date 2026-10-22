extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Exercises the real Hero/Forest boundaries omitted by isolated contact fixtures.
func run():
	await setup_fixture()
	var p=game.player
	p.select_character(16)
	var combat=p.active_ability
	check(p.character_id==16 and combat!=null,"The live Forest hero equips Sasuke's native combat kit")
	p.position=Vector3(0,-.01,60);p.velocity=Vector3.DOWN;p.move_and_slide();p.velocity=Vector3.ZERO
	check(p.is_on_floor(),"Sasuke test begins on physical floor collision")
	combat.cancel();tap("light_attack")
	check(combat.is_attacking() and p.attack_left>0,"Real mouse input starts Sasuke's native kunai action")
	await step(180)
	check(not contacts.is_empty(),"Sasuke's native gold kunai damages the real fitted training target")
	combat.cancel();tap("heavy_attack");await step(60)
	check(get_nodes_in_group("sasuke_projectiles").size()>0,"Real RMB launches Sasuke's firecracker projectile")
	combat.cancel()
	var held=InputEventAction.new();held.action="equip";held.pressed=true;p._unhandled_input(held)
	await step(125)
	held.pressed=false;p._input(held);await step(50)
	var ice=get_nodes_in_group("sasuke_projectiles").filter(func(shot):return shot.kind=="hail")
	check(ice.size()>=3,"Holding and releasing E launches the charged three-direction Hail Beam")
	combat.cancel();p.position=Vector3(0,-.01,60);p.velocity=Vector3.DOWN;p.move_and_slide();p.velocity=Vector3.ZERO
	var before=p.position.y
	tap("surge");p.set_physics_process(true)
	await frames(30)
	check(p.position.y>before+1.0,"R Super Jump lifts the real character through native collision movement")
	combat.cancel();p.set_physics_process(false);p.velocity=Vector3.ZERO
	held.pressed=true;p._unhandled_input(held)
	p.select_character(1)
	check(not combat.active and not combat.is_attacking(),"Character switch cancels Sasuke's pending charged action")
	held.pressed=false;p._input(held)
	var ally=load("res://scripts/forest/forest_gate_defender.gd").new();ally.game=game;game.add_child(ally);ally.select_character(16)
	check(game.gate_defenders.primary_range(ally)>1.0,"Sasuke can also serve as a gate defender with a valid native attack range")
	ally.queue_free();p.select_character(16);p.invuln=0;p.hp=1;game.tuning.invincible=false
	p.take_hit(5,Vector3.FORWARD)
	check(p.hp<=0 and game.last_sound_voice.stream==game.sound_library.original_for(16,"death"),"A fatal hit uses Sasuke's original death voice rather than the ordinary hurt cue")
	check(p.model.source_action==0x2d,"Defeat displays Sasuke's original knocked-down death pose")
	game.queue_free();paused=false;await frames();await create_timer(.15).timeout
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("SASUKE_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
