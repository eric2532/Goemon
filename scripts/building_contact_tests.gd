extends "res://scripts/destruction_tests.gd"
func run():
	visual="--building-contact-visual" in OS.get_cmdline_user_args()
	if visual:DirAccess.make_dir_recursive_absolute("res://tests/destruction")
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await fresh_site()
	var p=game.player
	var seen={};var samples=[];var demolition={}
	for part in game.world.breakable_buildings:
		var id=part.building.get_meta("town_variant",part.building.scene_file_path if not part.building.scene_file_path.is_empty() else "temple")
		if not seen.has(id):seen[id]=true;samples.append(part)
	if visual:samples=samples.filter(func(b):return b.building.has_meta("town_variant") and b.building.get_meta("town_variant")!="open_teahouse").slice(0,1)
	for part in samples:
		for outward in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
			var center=part.bounds.get_center();center.y=part.building.global_position.y+1.2
			var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center+outward*45,center,1))
			if hit.is_empty() or BreakableBuilding.from_collider(hit.collider)!=part:continue
			p.cancel_charge();p.attack_chain.reset();p.buildings_broken=0;p.scale=Vector3.ONE
			p.global_position=hit.position+outward*.75-Vector3.UP
			p.velocity=Vector3.ZERO;p.facing=-outward
			p.set_physics_process(true)
			game.camera_rig.yaw=atan2(outward.x,outward.z)
			part.hp=BreakableBuilding.HEALTH
			await frames(20)
			if demolition.is_empty() and part.building.has_meta("town_variant"):
				demolition={"part":part,"position":p.position,"outward":outward,"contact":hit.position}
			press_melee("heavy_attack");await drain()
			check(part.hp<BreakableBuilding.HEALTH,"Melee contacts real %s from %s: hp=%s distance to visual bounds=%.2f" % [part.building.name,outward,part.hp,part.nearest(p.position+Vector3.UP).distance_to(p.position+Vector3.UP)])
	check(not demolition.is_empty(),"A regular town house is reachable through its actual collider")
	if not demolition.is_empty():
		var part=demolition.part
		p.cancel_charge();p.attack_chain.reset();p.buildings_broken=0;p.scale=Vector3.ONE
		p.global_position=demolition.position;p.velocity=Vector3.ZERO
		game.camera_rig.yaw=atan2(demolition.outward.x,demolition.outward.z)
		game.camera_rig.camera.global_position=p.position+demolition.outward*22+Vector3.UP*10
		game.camera_rig.camera.look_at(demolition.contact+Vector3.UP*6)
		part.hp=BreakableBuilding.HEALTH
		press_melee("weapon_coin");await drain();await wait(.3)
		check(part.hp<BreakableBuilding.HEALTH,"A normal key-2 projectile damages the actual house")
		check(game.hud.building_target==part and game.hud.building_target_time>0,"A connected hit shows the building health on the HUD")
		await screenshot("05-real-house-hit")
		var presses=0
		while not part.destroyed and presses<8:
			press_melee("heavy_attack");await drain();presses+=1
			if not part.destroyed and presses in [1,2]:
				game.camera_rig.camera.global_position=p.position+demolition.outward*42+Vector3.UP*25
				game.camera_rig.camera.look_at(part.bounds.get_center())
				await screenshot("07-cracked-house" if presses==1 else "08-roof-damaged")
		check(part.destroyed and not part.building.visible and p.buildings_broken==1,"Normal right-click inputs demolish the real house and award growth once (%d presses)" % presses)
		await frames(2);await screenshot("06-real-house-broken")
	print("BUILDING_CONTACT_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
