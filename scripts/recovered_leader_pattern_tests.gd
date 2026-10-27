extends "res://scripts/recovered_leader_projectile_tests.gd"
## Bombs must land before detonating; other leader projectiles retain their travel.
func run():
	projectile_script=load("res://scripts/recovered_leader_projectile.gd")
	arena=Arena.new();root.add_child(arena);caster=Hero.new();caster.character_id=15;arena.player=caster
	var floor_body=wall(Vector3(0,-.1,0),Vector3(30,.2,30));await physics_frame;await physics_frame
	var p=shot(Vector3(0,10,0),Vector3.ZERO,true);p.bomb_target=Vector3(6,10,0);p.lifetime=1.0
	p._physics_process(.2)
	check(p.position.distance_to(Vector3(3,11.28,0))<.001,"Bomb retains the midpoint of its original shortened arc")
	p._physics_process(.2)
	check(p.position.distance_to(Vector3(6,10,0))<.001 and not p.bomb_grounded,"Reaching an airborne target does not count as landing")
	var airborne=target(Vector3(6,9,0));var grounded=target(Vector3(6,1,0))
	p._physics_process(.59)
	check(not p.resolved and not p.bomb_grounded and p.position.y<10 and airborne.hp==100,"Bomb falls through airborne enemies without stopping or dealing damage")
	p._physics_process(.01)
	check(not p.resolved and not p.is_queued_for_deletion() and arena.sounds.is_empty(),"Fuse and lifetime expiry cannot detonate or remove an airborne bomb")
	p._physics_process(.6)
	check(p.resolved and p.bomb_grounded and absf(p.position.y-.035)<.001,"An expired fuse detonates only after actual floor contact")
	check(p.bomb_effect.terminal_started and grounded.hp==72 and airborne.hp==100,"Ground impact synchronizes explosion visuals and nearby damage")
	check(arena.sounds==[["ben_bomb_explosion",15]],"Ground detonation plays Ben's original boom once")
	p.free();clear_targets()
	p=shot(Vector3(0,.3,0),Vector3(0,-5,0),true);p._physics_process(.1)
	check(p.bomb_grounded and not p.resolved,"Early floor contact preserves the existing fuse")
	arena.paused=true;var before=p.position;var age=p.flight_age;p._physics_process(2)
	check(p.position==before and p.flight_age==age and not p.resolved,"Pause freezes a landed bomb and its fuse")
	arena.paused=false;p._physics_process(.9)
	check(p.resolved,"A landed bomb detonates when its fuse expires")
	p.free();clear_targets()
	p=projectile_script.new();p.game=arena;p.hero=caster;p.source_character=15;p.shuriken=true
	p.position=Vector3(0,3,0);p.velocity=Vector3(12,0,0);arena.add_child(p);p.set_physics_process(false)
	p._physics_process(.2)
	check(p.position.distance_to(Vector3(2.4,3,0))<.001,"Ben's faster four-point shuriken travels without gravity")
	var victim=target(Vector3(3,3,0));p._physics_process(.4)
	check(victim.hp==72 and p.resolved,"The shuriken sweeps a fitted enemy and resolves once")
	check(not arena.sounds.has(["ben_bomb_explosion",15]),"A shuriken hit never borrows the bomb explosion sound")
	await process_frame;clear_targets()
	var barrier=wall(Vector3(2,10,0),Vector3(.2,20,8));await physics_frame;await physics_frame
	p=shot(Vector3(0,10,0),Vector3.ZERO,true);p.bomb_target=Vector3(6,10,0)
	p._physics_process(.2)
	check(not p.resolved and not p.bomb_grounded and p.position.x<1.9,"A wall stops the bomb's horizontal arc without counting as ground")
	var wall_height=p.position.y;p._physics_process(.8)
	check(not p.resolved and p.position.y<wall_height and arena.sounds.is_empty(),"A bomb falls down the wall instead of exploding there when its fuse expires")
	p._physics_process(.4)
	check(p.resolved and p.bomb_grounded and p.position.x<1.9,"A wall-blocked bomb detonates only at the floor below it")
	p.free();barrier.free();clear_targets()
	var ceiling=wall(Vector3(0,3,0),Vector3(8,.2,8));await physics_frame;await physics_frame
	p=shot(Vector3(0,2,0),Vector3(0,10,0),true);p._physics_process(.2)
	check(not p.bomb_grounded and not p.resolved and p.velocity==Vector3.ZERO,"A ceiling hit cannot count as landing")
	p._physics_process(.4)
	check(not p.bomb_grounded and p.position.y<2,"A ceiling-blocked bomb resumes falling")
	p.free();ceiling.free()
	var slope=wall(Vector3(8,2,0),Vector3(4,.2,4));slope.rotation.z=.3;await physics_frame;await physics_frame
	p=shot(Vector3(8,3,0),Vector3(0,-5,0),true);p._physics_process(.3)
	check(p.bomb_grounded and not p.resolved,"Walkable slopes count as ground for bombs")
	p._physics_process(.7);check(p.resolved,"A bomb resting on a slope detonates after the fuse")
	p.free();slope.free();floor_body.free();clear_targets();caster.free();arena.free();await process_frame
	print("LEADER_PATTERN_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
