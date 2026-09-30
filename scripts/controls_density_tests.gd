extends "res://scripts/musashi_tests.gd"
func jump_peak(id: int,launch: float)->float:
	game.player.select_character(id)
	await reset()
	await wait(.3)
	game.tuning.jump_speed=launch
	var start=game.player.position.y
	await key(KEY_SPACE)
	var peak=start
	for i in range(110):
		await get_tree().physics_frame
		peak=maxf(peak,game.player.position.y)
	return peak-start
func run():
	Input.use_accumulated_input=false
	original_tuning=game.tuning.duplicate();game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.start_game();game.player.smoke_mode=true;game.tuning.freeze_ai=true
	get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	game.camera_rig.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await wait(.5)
	var p=game.player
	await key(KEY_2);check(p.character_id==1 and p.weapon_slot==2,"2 selects Kai coins without changing character")
	await key(KEY_1);check(p.character_id==1 and p.weapon_slot==1,"1 selects Kai pipe without changing character")
	var position_before=p.position;var hp=p.hp;var yaw=game.camera_rig.yaw
	await key(KEY_Q);check(p.character_id==2 and p.dodge_time==0,"Q switches to Musashi without triggering evade")
	var repeat=InputEventKey.new();repeat.physical_keycode=KEY_Q;repeat.pressed=true;repeat.echo=true
	Input.parse_input_event(repeat);Input.flush_buffered_events()
	check(p.character_id==2,"Holding Q does not repeatedly toggle from key repeat")
	await key(KEY_2);check(p.musashi.ranged_mode and p.character_id==2,"2 selects Musashi fireballs")
	await mouse(true);await wait(.2);await key(KEY_1)
	check(not p.musashi.ranged_mode and not p.musashi.is_charging() and p.musashi.charge_effect==null,"1 selects fists and clears pending ranged charge")
	await mouse(false);check(not p.musashi.is_attacking(),"Release after weapon change does not launch a phantom attack")
	await key(KEY_Q);check(p.character_id==1,"Second Q switches back to Kai")
	check(p.position.distance_to(position_before)<.1 and p.hp==hp and game.camera_rig.yaw==yaw,"Switch preserves position, health and camera (distance=%.4f, HP=%.1f, yaw=%.4f)" % [p.position.distance_to(position_before),p.hp-hp,game.camera_rig.yaw-yaw])
	await key(KEY_C);check(p.dodge_time>0 and p.character_id==1,"C retains evade")
	await wait(.8)
	for id in [1,2]:
		var old_peak=await jump_peak(id,12.7)
		var new_peak=await jump_peak(id,PrototypeTuning.DEFAULTS.jump_speed)
		check(new_peak>old_peak*1.45 and new_peak<old_peak*1.55,"Character %d jumps ~50%% higher: %.2fm -> %.2fm" % [id,old_peak,new_peak])
		await reset();await wait(.2);await key(KEY_SPACE);await wait(.12);await key(KEY_SPACE)
		check(p.jumps_used==2 and p.velocity.y>13.4,"Character %d also has stronger second jump" % id)
	game.tuning.jump_speed=PrototypeTuning.DEFAULTS.jump_speed
	for area in range(4):
		game.area_states.clear();game.rebuild_area(area)
		await wait(.3)
		var baseline=18 if area==0 else game.world.enemy_spawns.size()
		var regular=0;var bosses=0;var ids={};var points=[];var clear=true
		for enemy in game.enemies:
			ids[enemy.encounter_id]=true
			if enemy.boss:bosses+=1
			else:
				regular+=1;points.append(enemy.position)
				if int(enemy.encounter_id)>=baseline:
					var query=PhysicsShapeQueryParameters3D.new();var shape=CapsuleShape3D.new();shape.radius=.45;shape.height=1.7
					query.shape=shape;query.collision_mask=1;query.transform=Transform3D(Basis.IDENTITY,enemy.position+Vector3.UP*1.0)
					if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():clear=false
		check(regular==baseline*30 and bosses==1,"Area %d has %d regular enemies (30x base groups) and one boss" % [area,regular])
		check(ids.size()==game.enemies.size(),"Area %d retains unique encounter IDs" % area)
		check(clear,"Area %d extra enemies spawn clear of static obstacles" % area)
		var saved_id=game.enemies[baseline].encounter_id
		game.enemies[baseline].hp=25;game.remember_area();game.rebuild_area(area);await wait(.1)
		var restored=false
		for enemy in game.enemies:
			if enemy.encounter_id==saved_id:restored=enemy.hp==25
		check(restored,"Area %d extra enemy health persists on revisit" % area)
	game.tuning=original_tuning
	print("CONTROLS_DENSITY_RESULT failures=",failures)
	get_tree().call_deferred("quit",1 if failures else 0)
