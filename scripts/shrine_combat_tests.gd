extends SceneTree
var failures=0
var checks=0
class Owner extends Node:
	var game: Node
	var generation=10
	var wave=1
	var phase="spawning"
	var health=100
	var contacts: Dictionary={}
	var roster: Dictionary={}
	func _running()->bool:return game.playing and not game.paused
	func owns(actor)->bool:return is_instance_valid(actor) and actor.get_meta("siege_generation",-1)==generation and roster.get(actor.encounter_id)==actor
	func apply_shrine_contact(actor)->bool:
		if not owns(actor) or actor.dead:return false
		health-=1;contacts[actor.encounter_id]=int(contacts.get(actor.encounter_id,0))+1;return true
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
func run():
	if not ResourceLoader.exists("res://scripts/shrine_attack_clock.gd"):
		check(false,"Shrine attack clock is independent from player combat");finish();return
	var Clock=load("res://scripts/shrine_attack_clock.gd")
	var clock=Clock.new()
	check(not clock.advance(2.49,true,false),"First hit waits 2.5 seconds")
	check(clock.advance(.01,true,false),"First hit occurs at 2.5 seconds")
	check(not clock.advance(100,true,true),"Pause cannot accumulate contacts")
	check(clock.advance(100,true,false) and not clock.advance(0,true,false),"Long frame emits one hit without backlog")
	clock.reset();clock.advance(2,true,false);clock.advance(.1,false,false)
	check(not clock.advance(2.49,true,false) and clock.advance(.01,true,false),"Canceled windup needs a fresh full interval")
	for step in [1.0/30,1.0/60,.1]:
		clock.reset();var events=0;var left=10.0
		while left>.0000001:
			var dt=minf(step,left);left-=dt
			if clock.advance(dt,true,false):events+=1
		check(events==4,"Frame partitions preserve attack cadence")
	await slots_rules()
	await integration_rules()
	finish()
func integration_rules():
	InputMap.erase_action("light_attack");InputMap.erase_action("heavy_attack")
	var game=load("res://scenes/main.tscn").instantiate();game.smoke_test=true;root.add_child(game)
	game.tuning.freeze_ai=true;game.tuning.invincible=true;game.start_mode("defense")
	game.encounters.set_physics_process(false);game.player.set_physics_process(false);await physics_frame
	var run=game.encounters
	run.update_start_input(0,false);run.update_start_input(3,true);run.tick(.2)
	var enemy=game.enemies.filter(func(e):return is_instance_valid(e) and not e.dead)[0]
	enemy.set_physics_process(false);enemy.position=game.world.base_position+Vector3(0,.15,-7);enemy.defense_waypoint=3
	run.breach(enemy);run.breach(enemy)
	check(not enemy.dead and run.alive_count==1 and run.base_hp==100,"Both arrivals preserve one living actor and shrine HP")
	if enemy.dead:
		game.sound_library.cancel();game.music.stop();game.queue_free();await process_frame;return
	run.phase="clearance";run.pending=0;run.shrine.tick(.2)
	enemy.position=run.shrine.assignment(enemy).position+Vector3.UP*.15
	var hero_hp=game.player.hp
	run.tick(2.49);check(run.base_hp==100,"Actual shrine waits before first hit")
	run.tick(.01);check(run.base_hp==99 and game.player.hp==hero_hp,"Shrine strike cannot hit the player")
	game.paused=true;run.tick(20);game.paused=false
	check(run.base_hp==99,"Pause freezes actual shrine damage")
	enemy.freeze_for(1);run.tick(2.5);check(run.base_hp==99,"Freeze cancels actual contact")
	enemy.frozen_left=0;run.tick(2.49);check(run.base_hp==99,"Thaw requires full new windup")
	run.tick(.01);check(run.base_hp==98,"Thawed actor attacks again")
	game.player.select_character(10);run.tick(0)
	check(run.alive_count==1 and run.phase=="clearance","Hero switching cannot clear waiting attackers")
	game.tuning.freeze_ai=false;enemy.state="windup";enemy.timer=0;enemy.stun=0
	hero_hp=game.player.hp
	enemy._physics_process(.1);game.tuning.freeze_ai=true
	check(game.player.hp==hero_hp,"Actual shrine pose bypasses player strike damage")
	game.player.hp=0;run.hero_died();run.tick(2.5)
	check(run.hero_dead and run.base_hp==97 and run.alive_count==1,"Shrine siege continues during hero death")
	run.tick(2.5)
	check(not run.hero_dead and game.player.hp>0 and run.alive_count==1,"Revival preserves shrine attackers")
	var before_knockback=run.base_hp
	enemy.position+=Vector3(5,0,0);run.tick(2.5)
	check(run.base_hp==before_knockback and not run.shrine.assignment(enemy).attacking,"Knockback releases a shrine seat")
	enemy.take_hit(10000,Vector3.FORWARD,false,{"tower":true});run.record_defeat(enemy)
	check(run.alive_count==0 and run.wave_kills==1,"Shrine actor death resolves exactly once")
	run.tick(0);check(run.phase=="setup" and run.money==20,"Only actual death clears the wave and pays reward")
	run.hard_mode=true;run.begin();check(run.base_hp==50,"Hard shrine begins with fifty HP")
	var ghost=Ninja.new();ghost.defense_lane=1;ghost.encounter_id="stale";ghost.set_meta("siege_generation",run.generation-1)
	check(not run.apply_shrine_contact(ghost) and run.base_hp==50,"Retired actor cannot damage replacement shrine");ghost.free()
	run.base_hp=0;run.tick(0);check(run.phase=="defeat" and not run.active,"Zero shrine health defeats the run")
	game.sound_library.cancel();game.music.stop();game.queue_free();await process_frame
func slots_rules():
	if not ResourceLoader.exists("res://scripts/fire_siege_shrine.gd"):
		check(false,"Shrine controller manages bounded attack slots");return
	var game=load("res://scenes/main.tscn").instantiate();game.smoke_test=true;root.add_child(game)
	game.tuning.freeze_ai=true;game.start_mode("defense");game.encounters.set_physics_process(false);game.player.set_physics_process(false)
	await physics_frame
	var owner=Owner.new();owner.game=game;game.add_child(owner)
	var controller=load("res://scripts/fire_siege_shrine.gd").new();controller.configure(owner)
	var actors: Array=[]
	for i in range(13):
		var actor=Ninja.new();actor.game=game;actor.defense_lane=1;actor.encounter_id="slot_%d" % i
		actor.set_meta("siege_generation",10);actor.position=game.world.base_position+Vector3(0,.15,-7)
		game.add_child(actor);actor.set_physics_process(false);owner.roster[actor.encounter_id]=actor;actors.append(actor)
		check(controller.admit(actor),"Living owned actor admitted")
		check(controller.admit(actor),"Repeated admission is idempotent")
	controller.tick(0)
	check(controller.waiting_count()==1,"Thirteenth actor waits outside twelve seats")
	for i in range(12):actors[i].position=controller.assignment(actors[i]).position+Vector3.UP*.15
	controller.tick(2.49)
	check(owner.health==100 and controller.attackers()==12,"Twelve actors wait through first interval")
	controller.tick(.01)
	check(owner.health==88,"Twelve simultaneous contacts each remove one HP")
	actors[0].stun=.1;controller.tick(2.5)
	check(owner.contacts["slot_0"]==1,"Stun cancels a pending shrine contact")
	actors[0].stun=0;controller.tick(2.49)
	check(owner.contacts["slot_0"]==1,"Recovery starts a new full interval")
	controller.tick(.01);check(owner.contacts["slot_0"]==2,"Recovered actor can attack again")
	var cover=StaticBody3D.new();var cover_node=CollisionShape3D.new();var cover_shape=BoxShape3D.new()
	cover_shape.size=Vector3(.5,2,2);cover_node.shape=cover_shape;cover.add_child(cover_node)
	cover.position=game.world.base_position+Vector3(2.5,1,0);game.add_child(cover);await physics_frame
	controller.tick(2.5);check(owner.contacts["slot_0"]==2,"Cover blocks shrine contact at impact")
	cover.free();await physics_frame
	controller.tick(2.49);check(owner.contacts["slot_0"]==2,"Removing cover cannot release an old contact")
	controller.tick(.01);check(owner.contacts["slot_0"]==3,"New unobstructed contact resumes normally")
	controller.release(actors[0]);controller.tick(.2)
	check(controller.assignment(actors[12]).attacking,"Freed seat transfers to first waiter")
	var actor=actors[1];actor.dead=true;controller.tick(3)
	check(not controller.handles(actor),"Dead windup actor loses membership")
	owner.generation+=1;controller.tick(3)
	check(controller.attackers()==0 and not controller.handles(actors[2]),"Run replacement invalidates old clocks")
	var base: Vector3=game.world.base_position
	game.world.base_position=Vector3(158,0,220);controller.configure(owner)
	check(controller.slots.size()<12,"Boundary shrine uses only legal positions")
	for slot in controller.slots:check(game.world.playable_bounds.has_point(Vector2(slot.position.x,slot.position.z)),"Custom position remains inside authored bounds")
	game.world.base_position=base
	var barrier=StaticBody3D.new();var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(20,4,20)
	collision.shape=shape;barrier.add_child(collision);barrier.position=base+Vector3.UP*2;game.add_child(barrier);await physics_frame
	controller.configure(owner);check(controller.slots.is_empty(),"Completely blocked shrine has no illegal seats")
	controller.clear();game.sound_library.cancel();game.music.stop();game.queue_free();await process_frame
func finish():
	print("SHRINE_COMBAT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
