extends SceneTree
## Real saved menu edits, articulated weapons and enemy contacts, isolated from user settings.
const Balance=preload("res://scripts/character_balance.gd")
# Rogue melee uses articulated reach; native Goemon has swept-mesh coverage in
# goemon_extended_reach_test.gd instead of the retired radial-contact fixture.
const MELEE=[3,4,5,7,8,9,11,12]
const ORIGIN=Vector3(0,.05,70)
var game
var checks=0
var failures=0
var config_path="user://melee-reach-stat-%d.cfg"%OS.get_process_id()
func _initialize():
	create_timer(90).timeout.connect(func():printerr("FAIL: reach test timed out");quit(1))
	run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func frames(n: int=3):
	for i in n:await physics_frame
func prepare(id: int):
	for actor in game.actors.values():actor.queue_free()
	game.actors.clear();game.enemies.clear();game.model.enemies.clear()
	await frames()
	game.player.cancel_charge();game.player.select_character(id)
	game.player.set_physics_process(false);game.player.set_auto_attack(false)
	game.player.position=ORIGIN;game.player.velocity=Vector3.ZERO
	game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
	game.player.attack_left=0;game.player.weapon_slot=1;game.player.attack_chain.reset()
	game.player.surge_left=0;game.player.buildings_broken=0;game.player.scale=Vector3.ONE
	game.player.facing=Vector3.FORWARD;game.camera_rig.yaw=0
	var c=game.player.active_ability;c.reset_run()
	for i in 20:c._move_body(1.0/60)
	# Ground the body for Dragoon, then restore the fixture above the floor.
	# A frozen actor must not keep the settling step's below-floor contact.
	game.player.position=ORIGIN
	c.player.pos=game.player.position;c.aim=game.player.position+Vector3.FORWARD*30
	game.model.update_vision(game.player.position)
func swing(id: int,stage: int=0)->Dictionary:
	var h=game.player;h.attack_chain.reset();h.melee_assist.reset()
	var c=h.active_ability;c.player.attack=null;c.player.cooldowns.cutlass=0
	c.combo=stage;c.combo_timer=1;c.attack()
	var a: Dictionary=c.player.attack
	var sample: Dictionary=c.player.duplicate();sample.attack=a.duplicate();sample.attack.time=a.contact;sample.meleeVisualScale=a.meleeVisualScale
	c.visual_actor.animate_pose(sample,0,c.time,0)
	var weapon_name="Weapon_Pistol" if c.class_id=="explorer" and int(a.get("swingSide",1))<0 else "Weapon_Cutlass"
	var weapon: Node3D=c.visual_actor.joints[weapon_name].node
	var axis: Vector3=c.visual_actor.LEFT_BLADE if weapon_name=="Weapon_Pistol" else c.visual_actor.WEAPON_AXES[c.class_id]
	var tip: Vector3=weapon.to_global(axis);var origin: Vector3=h.global_position
	var visible=maxf(Vector2(tip.x-origin.x,tip.z-origin.z).length(),Vector2(weapon.global_position.x-origin.x,weapon.global_position.z-origin.z).length())+.12*h.growth_multiplier()
	return {"reach":a.reach,"visual":visible,"duration":a.duration,"contact":a.contact,"damage":a.damage,"arc":a.arc,"body":h.scale,"range":c.range_scale()}
func target(surface_distance: float):
	var origin: Vector3=game.player.position
	var data=game.model.waves.spawn_enemy(0,origin+Vector3.FORWARD*(surface_distance+1))
	data.hp=10000.0;data.max_hp=10000.0;game.sync_enemies()
	var actor=game.actors[data.id];actor.set_physics_process(false)
	for i in 6:
		var contact: Vector3=actor.combat_contact_point(origin+Vector3.UP)
		actor.position.z+=origin.z-surface_distance-contact.z;data.pos=actor.position;actor._sync_fitted_pose()
	game.model.update_vision(origin)
	return data
func contact(id: int):
	var c=game.player.active_ability;var a: Dictionary=c.player.attack
	a.time=a.contact-.001;a.hit=false;c.tick(.002,false)
func secondary(id: int,multiplier: float)->Dictionary:
	await prepare(id);game.update_character_tuning(id,"melee_reach",multiplier)
	var c=game.player.active_ability;c.action("flintlock")
	if id==8:
		c.player.attack.time=c.player.attack.contact
		c._animate(0,0)
		return {"reach":c.player.attack.reach,"weapon":c.visual_actor.joints.Weapon_Cutlass.node.global_basis.get_scale().length(),"duration":c.player.attack.duration,"damage":c.player.attack.damage}
	c._animate(0,0)
	return {"reach":c.player.dashAttack.width,"weapon":c.visual_actor.joints.Weapon_Cutlass.node.global_basis.get_scale().length(),"duration":c.player.roll,"speed":c.player.rollSpeed,"damage":c.player.dashAttack.damage}
func run():
	check(Balance.sanitized({"melee_reach":1.5},5).get("melee_reach",0)==1.5,"Ninja accepts the editable reach stat")
	if failures:finish();return
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
	await frames();game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.tuning.critical_chance=0
	for id in MELEE:
		check(game.balance_value(id,"melee_reach")==1,"Legacy/default profile retains 1× reach (%d)"%id)
		for stage in range(3):
			await prepare(id);game.update_character_tuning(id,"melee_reach",1)
			var original=swing(id,stage)
			game.update_character_tuning(id,"melee_reach",2)
			var longer=swing(id,stage)
			check(longer.reach>original.reach+.4 and longer.visual>original.visual+.4,"Stat lengthens visible weapon and actual reach (%d, stage %d)"%[id,stage+1])
			check(longer.duration==original.duration and longer.contact==original.contact and longer.body==original.body,"Timing and body size stay unchanged (%d, stage %d)"%[id,stage+1])
			check(longer.damage==original.damage and longer.arc==original.arc and longer.range==original.range,"Damage, swing style and projectile range scale stay unchanged (%d, stage %d)"%[id,stage+1])
			check(absf(longer.reach-longer.visual*1.12)<.025,"Longer contact remains fitted to the visible weapon (%d, stage %d)"%[id,stage+1])
		# A distant real enemy must miss at 1× and connect at 2×, without movement.
		await prepare(id);game.update_character_tuning(id,"melee_reach",1);var original=swing(id)
		game.update_character_tuning(id,"melee_reach",2);var longer=swing(id)
		var distance=(original.reach+longer.reach)*.5+.5
		var victim=target(distance)
		game.update_character_tuning(id,"melee_reach",1);swing(id);contact(id)
		check(victim.hp==10000,"Enemy beyond default reach is missed (%d)"%id)
		game.update_character_tuning(id,"melee_reach",2);swing(id);contact(id)
		check(victim.hp<10000,"Longer strike damages that same real enemy (%d)"%id)
	for id in [5,8,11]:
		var original=await secondary(id,1);var longer=await secondary(id,2)
		check(is_equal_approx(longer.reach,original.reach*2) and is_equal_approx(longer.weapon,original.weapon*2),"Physical secondary extends both weapon and contact (%d)"%id)
		check(longer.duration==original.duration and longer.damage==original.damage and longer.get("speed",0)==original.get("speed",0),"Physical secondary keeps damage, timing and dash travel (%d)"%id)
	for mode in ["cover","fog"]:
		await prepare(5);swing(5);var victim=target(3.0);var wall: StaticBody3D
		if mode=="fog":game.model.visible_cells.clear()
		else:
			wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
			var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(8,6,.2);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.position=game.player.position+Vector3(0,1,-1);await frames()
		contact(5);check(victim.hp==10000,"Extended melee respects "+mode)
		if is_instance_valid(wall):wall.queue_free();await frames()
	await prepare(5);game.update_character_tuning(5,"melee_reach",3);var old_max=swing(5)
	game.update_character_tuning(5,"melee_reach",10);var new_max=swing(5)
	check(new_max.reach>old_max.reach*2 and new_max.visual>old_max.visual*2,"Tenfold reach extends the real weapon beyond the old threefold maximum")
	var distant=target((old_max.reach+new_max.reach)*.5+.5)
	game.update_character_tuning(5,"melee_reach",3);swing(5);contact(5)
	check(distant.hp==10000,"Enemy outside threefold reach remains unharmed")
	game.update_character_tuning(5,"melee_reach",10);swing(5);contact(5)
	check(distant.hp<10000,"Tenfold strike damages that same distant enemy")
	game.show_character_balance(true,5);await frames()
	var spin=game.menu.find_child("Balance_melee_reach",true,false)
	check(spin!=null and spin.value==10,"Character balance exposes the full tenfold reach")
	if spin!=null:spin.value=8.5
	game.character_tuning.clear();game.load_settings()
	check(game.balance_value(5,"melee_reach")==8.5,"Menu saves and reloads extended reach above the old cap")
	if spin!=null:spin.value=1.5
	game.character_tuning.clear();game.load_settings()
	check(game.balance_value(5,"melee_reach")==1.5 and game.balance_value(7,"melee_reach")==2,"Menu edit saves and reloads independently per fighter")
	for id in [10]:
		game.show_character_balance(true,id);await frames()
		check(game.menu.find_child("Balance_melee_reach",true,false)==null and Balance.sanitized({"melee_reach":2},id).is_empty(),"Pure ranged kit has no misleading melee stat (%d)"%id)
	for id in [2,6]:check(Balance.sanitized({"melee_reach":2},id).is_empty(),"Hidden ranged kit still rejects melee overrides (%d)"%id)
	game.update_character_tuning(5,"melee_reach",NAN)
	check(game.balance_value(5,"melee_reach")==1.5,"Non-finite edits retain the last valid value")
	game.update_character_tuning(5,"melee_reach",999)
	check(game.balance_value(5,"melee_reach")==10,"Oversized saved values clamp to the new supported maximum")
	game.reset_character_tuning(5)
	check(game.balance_value(5,"melee_reach")==1 and game.balance_value(7,"melee_reach")==2,"Reset restores only the selected fighter's original reach")
	if "--visual" in OS.get_cmdline_user_args():
		game.show_character_balance(true,5);await capture("ninja-reach-settings")
		game.show_character_balance(true,1);await capture("goemon-reach-settings")
		game.resume();await prepare(7);swing(7,0)
		game.camera_rig.camera.position=game.player.position+Vector3(5,5,7);game.camera_rig.camera.look_at(game.player.position+Vector3(0,1,-1.5));game.world.update_fog()
		await capture("knight-extended-strike")
	await finish()
func capture(label_: String):
	await frames();await RenderingServer.frame_post_draw
	var directory=OS.get_environment("SONIC_REACH_CAPTURES")
	if directory.is_empty():directory="/tmp/sonic-melee-reach"
	DirAccess.make_dir_recursive_absolute(directory)
	check(root.get_texture().get_image().save_png(directory+"/"+label_+".png")==OK,"Native capture: "+label_)
func finish():
	if is_instance_valid(game):game.queue_free();paused=false;await frames()
	await create_timer(.4).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("MELEE_REACH_STAT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
