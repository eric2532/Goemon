extends SceneTree
# Focused physical checks for the final castle defense line.
# godot --headless --path . --script tests/defense-tactics/castle-wall-check.gd --fixed-fps 60
var game
var failures=0
var checks=0

func _initialize():call_deferred("run")
func frames(count: int):
	for i in range(count):await physics_frame
func check(ok: bool,message: String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func key(code: Key):
	for down in [true,false]:
		var event=InputEventKey.new();event.physical_keycode=code;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events()
		await frames(1)
func living()->Array:
	return game.enemies.filter(func(actor):return is_instance_valid(actor) and not actor.dead and actor.defense_lane>=0)

func setup():
	game.defense_beta=true;game.defense_tactics=true;game.start_defense(false)
	var s=game.encounters;s.set_physics_process(false);s.choose_card("supply_cache")
	game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
	game.camera_rig.yaw=0;game.camera_rig.set_process_unhandled_input(false)
	Input.use_accumulated_input=false
	await frames(3)
	return s

func inspect_geometry():
	var world=game.world;var main=world.get_node_or_null("MainCastleWall")
	check(main!=null,"The final station has one dedicated main castle wall")
	if main==null:return
	check(world.playable_bounds==Rect2(-80,-400,160,760) and world.cannon_sites.size()==24,"The castle retains the compact battlefield and all 24 tower sites")
	var tower_levels=true;var z_values=[]
	for i in range(world.cannon_sites.size()):
		var site=world.cannon_sites[i]
		tower_levels=tower_levels and is_equal_approx(site.position.y,6.85 if i>=20 else 2.65)
		if i%4==0:z_values.append(site.position.z)
	check(tower_levels and z_values==[-170.0,-100.0,-30.0,40.0,110.0,180.0],"Only the final four guns are elevated; all six defense station positions remain intact")
	var space=game.get_world_3d().direct_space_state
	var wall_width=true
	for x in [-76,-55,-30,30,55,76]:
		var ray=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,3,170),Vector3(x,3,190),1))
		wall_width=wall_width and not ray.is_empty() and (ray.collider==main or main.is_ancestor_of(ray.collider))
	check(wall_width,"The stone wall physically spans both sides of the 160-metre field")
	var clear=true
	for x in [-5.5,0,5.5]:
		for y in [.3,7.2,11.9]:
			clear=clear and space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,y,172),Vector3(x,y,188),1)).is_empty()
	check(clear,"The gateway provides a clear 12-metre-wide opening with at least 12 metres of headroom")
	var cover=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(30,7.1,183),Vector3(30,7.1,174),1))
	check(not cover.is_empty() and main.is_ancestor_of(cover.collider),"Battlement cover blocks a real chest-height ray across the wall front")
	var hud=FileAccess.get_file_as_string("res://scripts/hud.gd")
	var section=hud.get_slice("func draw_defense",1).get_slice("func draw_descent",0)
	check(not "BATTLEFIELD  /" in section and not "map_scale" in section and "siege_boss" in section,"Defense HUD retains boss information without restoring the removed minimap")

func hero_and_purchases(s):
	var p=game.player
	p.position=Vector3(46,.15,219);p.velocity=Vector3.ZERO
	p.facing=Vector3.FORWARD;game.camera_rig.yaw=0
	await frames(20)
	var start=p.position;p.smoke_move=Vector2.UP
	var reached=false
	for i in range(240):
		await frames(1)
		if p.position.y>6.2 and p.position.z<184:reached=true;break
	p.smoke_move=Vector2.ZERO;await frames(8)
	print("CASTLE_RAMP ",JSON.stringify({"start":str(start),"finish":str(p.position),"grounded":p.is_on_floor()}))
	check(reached and p.is_on_floor() and p.position.y<7,"The existing hero walks from ground level up the rear ramp onto the battlement")
	p.smoke_move=Vector2.UP;await frames(90);p.smoke_move=Vector2.ZERO
	check(p.position.z>176 and p.position.y>6,"Battlement cover stops normal walking from crossing the front parapet")
	for i in range(20,24):
		var site=game.world.cannon_sites[i]
		p.position=site.build_position+Vector3.UP*.1;p.velocity=Vector3.ZERO
		await frames(15)
		var before=s.money;var cost=s.site_cost(i)
		check(p.is_on_floor() and p.position.distance_to(site.build_position)<.5 and s.nearest_site()==i,"Castle purchase pad %d is reachable on solid ground and selects its own gun" % (i-19))
		await key(KEY_F)
		check(s.site_states[i].level==2 and s.money==before-cost,"Physical F upgrades elevated castle gun %d and charges its normal cost" % (i-19))

func gun_damage(s):
	var actor=Ninja.new();actor.game=game;actor.swarm=true;actor.defense_lane=1
	actor.defense_role="runner";actor.variant=1;actor.position=Vector3(0,.15,145)
	game.add_child(actor);game.enemies.append(actor);actor.set_physics_process(false)
	actor.hp=100000;actor.max_hp=100000
	game.player.position=Vector3(0,.15,199);game.player.velocity=Vector3.ZERO
	await frames(2)
	for target_z in [145.0,180.0,198.0]:
		for i in range(20,24):
			actor.position=Vector3(0,.15,target_z);actor.velocity=Vector3.ZERO
			var gun=s.site_states[i].cannon;var hp=actor.hp
			gun.target_clock=999;gun.cooldown=999
			gun.fire_at(actor)
			for frame in range(40):
				gun.tick(.05);await frames(1)
			check(actor.hp<hp,"Elevated %s at x%.0f deals real damage to a ground target at z%.0f" % ["flame tower" if gun is DefenseFlameTower else "cannon",gun.position.x,target_z])
			print("CASTLE_GUN ",JSON.stringify({"site":i,"type":"fire" if gun is DefenseFlameTower else "cannon","at":str(gun.position),"target_z":target_z,"damage":hp-actor.hp,"shots":gun.shots_fired}))
			s.retire_wave_effects()
	actor.queue_free();game.enemies.erase(actor);await frames(2)

func boss_gateway(s):
	game.player.set_physics_process(false);game.player.position=Vector3(65,.15,250)
	s.wave=9;s.chosen_wave=10;s.phase="rest";s.queue_wave()
	while s.total_spawned<41:s.spawn_pending();await frames(1)
	var boss
	for actor in living():
		if actor.defense_boss_tier==2:boss=actor
		else:actor.queue_free()
	s.pending=0;await frames(2)
	check(boss!=null,"The gateway fixture uses the real final boss from the wave-10 roster")
	if boss==null:return
	boss.position=Vector3(0,.15,162);boss.velocity=Vector3.ZERO
	boss.defense_waypoint=3;boss.walk_clock=0;boss.stun=0;boss.defense_traits.cancel_attack()
	var shape: CollisionShape3D=boss.find_children("*","CollisionShape3D",true,false)[0]
	check(is_equal_approx(shape.shape.height,7.2) and is_equal_approx(boss.defense_scale,4),"Gateway clearance is tested with the final boss's full physical capsule")
	game.tuning.freeze_ai=false
	for i in range(600):
		if not is_instance_valid(boss) or boss.position.z>197:break
		await frames(1)
	print("CASTLE_BOSS ",JSON.stringify({"position":str(boss.position),"waypoint":boss.defense_waypoint,"height":shape.shape.height}))
	check(boss.position.z>197 and absf(boss.position.x)<1 and boss.position.y>-.5 and not boss.dead,"The full-size final boss physically marches through the castle gateway without teleporting or getting stuck")
	game.tuning.freeze_ai=true

func run():
	game=load("res://scenes/main.tscn").instantiate();game.descent_mode=false;game.smoke_test=true
	root.add_child(game);await process_frame
	var s=await setup()
	inspect_geometry()
	await hero_and_purchases(s)
	await gun_damage(s)
	await boss_gateway(s)
	print("CASTLE_WALL_CHECK checks=",checks," failures=",failures)
	game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	var deadline=Time.get_ticks_msec()+300
	while Time.get_ticks_msec()<deadline:await process_frame
	quit(1 if failures else 0)
