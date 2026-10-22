extends SceneTree
## Real input, native models and forest damage integration for Chief's loadout.
var checks=0
var failures=0
var game
func _initialize():
	create_timer(150).timeout.connect(func():printerr("FAIL: weapons timeout");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func frames(count:int=3):
	for i in count:await physics_frame
func key(slot:int):
	var event=InputEventKey.new();event.physical_keycode=KEY_1+slot-1;event.pressed=true
	Input.parse_input_event(event);Input.flush_buffered_events();await frames(1)
	event=InputEventKey.new();event.physical_keycode=KEY_1+slot-1;event.pressed=false
	Input.parse_input_event(event);Input.flush_buffered_events()
func press(down:bool):
	var event=InputEventAction.new();event.action="light_attack";event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()
func spawn(at:Vector3):
	var data=game.model.waves.spawn_enemy(0,at)
	data.hp=10000;data.max_hp=10000;data.stun=100
	game.sync_enemies();await frames();game.model.update_vision(game.player.position)
	var actor=game.actors[data.id];actor.set_physics_process(false)
	return actor
func place(actor,at:Vector3,reset_hp:bool=false):
	var data=game.model.enemies[actor.forest_id];data.pos=at
	actor.position=at
	if reset_hp:data.hp=10000;actor.hp=10000
	game.model.visible_cells[game.model.cell_of(at)]=true
	actor._sync_fitted_pose()
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate()
	game.settings_path="user://chief-weapons-test-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames()
	var hero=game.player;hero.select_character(18)
	game.start_wave();game.model.waves.spawn_clock=10000;game.tuning.invincible=true;game.tuning.critical_chance=0
	game.set_physics_process(false)
	hero.position=Vector3(0,100,110);hero.velocity=Vector3.ZERO
	hero.set_physics_process(false)
	game.camera_rig.yaw=0;game.camera_rig.pitch=0;game.camera_rig.update_camera(0)
	await frames()
	var combat=hero.active_ability
	check(combat.has_method("select_slot"),"Chief supports selectable weapons")
	if not combat.has_method("select_slot"):await finish();return
	var view=game.camera_rig.first_person_viewmodel
	var helper_commands=[]
	game.forest_ui.loadout_slot_selected.connect(func(slot):helper_commands.append(slot))
	var helper_count=game.explorer_helpers.summon_serial
	for slot in [1,2,3,4]:
		await key(slot)
		check(combat.weapon_slot==slot,"Physical %d selects its weapon"%slot)
		check(view.weapon_slot==slot and view.animations.has_animation("firing"),"Slot %d displays its recovered animated first-person model"%slot)
		check(view.native_sample!=null,"Slot %d has original Halo firing audio"%slot)
	check(game.explorer_helpers.summon_serial==helper_count and helper_commands.is_empty(),"Weapon hotkeys do not summon allies")
	await key(5)
	check(combat.weapon_slot==5 and helper_commands.is_empty(),"Chief equips the sword on key 5 without issuing an ally command")
	var target=await spawn(Vector3(0,100,98))
	await key(2);combat.cooldown=0
	var before=target.hp
	combat.fire_shot()
	check(target.hp<before,"Pistol damages an enemy along the crosshair")
	var after=target.hp
	combat.fire_shot()
	check(target.hp==after,"Pistol respects its firing interval")
	var wall=StaticBody3D.new();wall.collision_layer=1
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(8,6,.4)
	wall.add_child(shape);game.add_child(wall);wall.position=Vector3(0,102,104);await frames()
	combat.cooldown=0;combat.fire_shot()
	check(target.hp==after,"World geometry blocks pistol fire")
	await key(3);combat.cooldown=0;combat.fire_shot()
	check(target.hp==after,"World geometry blocks shotgun pellets")
	# Put the enemy within the blast radius on the opposite side of this wall.
	place(target,Vector3(0,100,99.5))
	await key(1);combat.cooldown=0;before=target.hp;combat.fire_shot()
	check(combat.live_rocket_count()==1 and target.hp==before,"Rocket launch creates a travelling projectile without instant damage")
	for i in 20:combat.advance_projectiles(.02)
	check(combat.live_rocket_count()==0 and target.hp==before,"Rocket hits the nearer wall and its splash cannot pass through it (HP %.1f -> %.1f, hit %s, bounds %s)"%[before,target.hp,combat.last_hit_point,target.combat_bounds()])
	wall.queue_free();await frames();place(target,Vector3(0,100,98))
	var nearby=await spawn(Vector3(2,100,98))
	await key(1);combat.cooldown=0;before=target.hp;var nearby_before=nearby.hp
	combat.fire_shot();await key(2)
	for i in 30:combat.advance_projectiles(.02)
	check(target.hp<before and nearby.hp<nearby_before,"Rocket deals splash damage to multiple nearby enemies after switching weapons")
	check(combat.live_rocket_count()==0,"An exploded rocket releases its pooled projectile")
	# Compare the same target at near/far distance, resetting all combo bonuses.
	place(nearby,Vector3(30,100,98))
	place(target,Vector3(0,100,106),true)
	await key(3);combat.cooldown=0;hero.attack_chain.reset();combat.fire_shot()
	var near_damage=10000-target.hp
	place(target,Vector3(0,100,84),true)
	combat.cooldown=0;hero.attack_chain.reset();combat.fire_shot()
	check(near_damage>0 and near_damage>10000-target.hp,"Shotgun's spread and falloff reward close-range hits (near %.1f, far %.1f)"%[near_damage,10000-target.hp])
	press(true);combat.tick(0);await key(1)
	check(not combat.primary_held,"Weapon switching releases the previous held trigger")
	var count=combat.shots_fired;combat.tick_timers(2);combat.tick(2)
	check(combat.shots_fired==count,"Weapon switching never fires the new weapon until LMB is pressed again")
	press(false);combat.cooldown=0;combat.fire_shot()
	await key(2);await key(1)
	count=combat.shots_fired;combat.fire_shot()
	check(combat.shots_fired==count,"Switching away and back cannot bypass rocket recovery time")
	combat.cancel()
	check(combat.live_rocket_count()==0,"Session interruption clears live rockets")
	check(combat.ammo_infinite,"All four weapons retain infinite ammo")
	await key(4);combat.cooldown=0;combat.primary_held=true;combat.tick(0)
	count=combat.shots_fired
	for i in 50:combat.tick_timers(.02);combat.tick(.02)
	check(combat.shots_fired-count==15,"Assault rifle sustains the original 15 rounds per second at 50 Hz")
	combat.cancel()
	await finish()
func finish():
	Input.action_release("light_attack")
	if is_instance_valid(game):game.queue_free()
	paused=false;await frames();await create_timer(.2).timeout
	print("MASTER_CHIEF_WEAPONS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
