extends "res://scripts/recovered_leader_projectile_tests.gd"
## Real source arc, hold/fuse, shuriken travel and world collision.
func run():
	projectile_script=load("res://scripts/recovered_leader_projectile.gd")
	arena=Arena.new();root.add_child(arena);caster=Hero.new();caster.character_id=15;arena.player=caster
	var p=projectile_script.new();p.game=arena;p.hero=caster;p.source_character=15;p.bomb=true
	p.position=Vector3(0,3,0);p.bomb_target=Vector3(6,3,0);p.lifetime=160.0/30.0;arena.add_child(p);p.set_physics_process(false)
	p._physics_process(.2)
	check(p.position.distance_to(Vector3(3,4.28,0))<.001,"Bomb reaches the midpoint of its shortened arc at0.2seconds")
	p._physics_process(.2)
	check(p.position.distance_to(Vector3(6,3,0))<.001 and not p.resolved,"Bomb reaches its target at0.4seconds without premature damage")
	p._physics_process(.59)
	check(not p.resolved,"Bomb remains armed just before one second")
	p._physics_process(.01)
	check(p.resolved and p.bomb_effect.terminal_started,"Damage and visible explosion both start one second after release")
	check(arena.sounds.has(["ben_bomb_explosion",15]),"One-second detonation retains the original explosion sound")
	await process_frame;arena.sounds.clear()
	p=projectile_script.new();p.game=arena;p.hero=caster;p.source_character=15;p.shuriken=true
	p.position=Vector3(0,3,0);p.velocity=Vector3(7.2,0,0);arena.add_child(p);p.set_physics_process(false)
	p._physics_process(.2)
	check(p.position.distance_to(Vector3(1.44,3,0))<.001,"Ben's four-point shuriken travels at source speed without fireball gravity")
	var victim=target(Vector3(3,3,0));p._physics_process(.4)
	check(victim.hp==72 and p.resolved,"The shuriken sweeps a real fitted enemy and resolves once")
	check(not arena.sounds.has(["ben_bomb_explosion",15]),"A shuriken hit never borrows the blue bomb's explosion sound")
	await process_frame;clear_targets()
	var barrier=wall(Vector3(2,3,0),Vector3(.2,5,8));await physics_frame;await physics_frame
	p=projectile_script.new();p.game=arena;p.hero=caster;p.source_character=15;p.bomb=true
	p.position=Vector3(0,3,0);p.bomb_target=Vector3(6,3,0);p.lifetime=160.0/30.0;arena.add_child(p);p.set_physics_process(false)
	p._physics_process(.7)
	check(not p.resolved and p.bomb_arrived and p.position.x<2.1,"World cover stops the shortened arc while preserving the one-second fuse")
	await process_frame;barrier.free()
	var covered=target(Vector3(2,3,0));barrier=wall(Vector3(1,3,0),Vector3(.2,5,6));await physics_frame;await physics_frame
	p=shot(Vector3(0,3,0),Vector3(20,0,0),true);p._physics_process(.2)
	check(p.position.x<.91 and not p.resolved,"An enlarged bomb cannot snap through cover toward an overlapping fitted target")
	p._physics_process(.8)
	check(p.resolved and covered.hp==100,"Enlarged blast respects nearby cover at one-second detonation")
	await process_frame;barrier.free();clear_targets()
	p=shot(Vector3(0,3,0),Vector3.ZERO,true);p.bomb_arrived=true
	var crossing=target(Vector3(1.7,3,0))
	for tick in 4:
		p._physics_process(.1);crossing.position.x+=.2
	check(p.position.is_equal_approx(Vector3(0,3,0)),"A resting enlarged bomb cannot follow a passing victim")
	p.queue_free();await process_frame;clear_targets();caster.free();arena.free();await process_frame
	print("LEADER_PATTERN_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
