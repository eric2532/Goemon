extends SceneTree
## Real camera rays, native animated heads, damage pipeline and large blast edges.
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
var checks=0
var failures=0
var game
func _initialize():
	create_timer(150).timeout.connect(func():printerr("FAIL: headshot timeout");quit(1))
	run.call_deferred()
func check(ok:bool,words:String):
	checks+=1;print("PASS: " if ok else "FAIL: ",words)
	if not ok:failures+=1
func frames(count:int=3):
	for i in count:await physics_frame
func key(slot:int):
	for down in [true,false]:
		var event=InputEventKey.new();event.physical_keycode=KEY_1+slot-1;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events();await frames(1)
func spawn(at:Vector3,kind:int=0):
	var data=game.model.waves.spawn_enemy(kind,at)
	data.hp=10000;data.max_hp=10000;data.stun=100
	game.model.visible_cells[game.model.cell_of(at)]=true
	game.sync_enemies();await frames()
	var actor=game.actors[data.id];actor.set_physics_process(false);actor._sync_fitted_pose()
	return actor
func aim(at:Vector3):
	var rig=game.camera_rig
	var direction=(at-(game.player.position+Vector3.UP*1.68)).normalized()
	rig.yaw=atan2(-direction.x,-direction.z);rig.pitch=-asin(direction.y);rig.first_person_recoil=0;rig.update_camera(0)
func reset_target(actor):
	var data=game.model.enemies[actor.forest_id];data.hp=10000;actor.hp=10000
	game.player.attack_chain.reset();game.player.master_chief_combat.cooldown=0
func head_center(actor)->Vector3:
	var data=actor._combat_data();var resource=Soldier.data(actor.variant)
	var state=Soldier.frame_state(data)
	var pose:Transform3D=Transform3D(Basis(Vector3.UP,data.facing),actor.position)*resource.get_meta("poses")[state.row*11+7]
	var bounds:AABB=resource.get_meta("part_bounds")[7]
	return pose*bounds.get_center()
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://chief-headshots-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames()
	var hero=game.player;hero.select_character(18);game.start_wave();game.model.waves.spawn_clock=10000
	game.tuning.critical_chance=0;game.tuning.invincible=true;game.set_physics_process(false)
	hero.set_physics_process(false);hero.position=Vector3(0,100,110)
	game.crowd.set_process(false);game.camera_rig.set_process(false)
	await frames();var combat=hero.master_chief_combat
	await key(4)
	check(combat.weapon_slot==4,"4 equips the assault rifle instead of summoning an ally")
	check(game.camera_rig.first_person_viewmodel.weapon_slot==4,"4 displays the recovered assault rifle and arms")
	check(combat.has_method("head_contact"),"Chief recognizes animated head hit regions")
	if not combat.has_method("head_contact"):await finish();return
	var legacy=Ninja.new();legacy.game=game;legacy.practice=true
	game.add_child(legacy);legacy.set_physics_process(false);legacy.position=Vector3(60,100,90)
	var legacy_head=legacy.position+Vector3.UP*1.98
	check(not combat.head_contact(legacy,legacy_head+Vector3.BACK*10,legacy_head+Vector3.FORWARD*10).is_empty(),"Legacy Ninja head queries work without forest combat_bounds")
	legacy.queue_free()
	var target=await spawn(Vector3(0,100,90))
	# Body ray lies far below the animated head at the same horizontal angle.
	aim(target.position+Vector3.UP*2.0);reset_target(target);combat.fire_shot()
	var body_damage=10000-target.hp
	check(body_damage>0 and target.hp>0,"Assault rifle body shots retain ordinary damage")
	aim(head_center(target));reset_target(target);combat.fire_shot()
	check(is_equal_approx(10000-target.hp,body_damage*2),"Assault rifle headshots deal exactly double body damage")
	# A native pose change/turn must move the head target with the animation.
	var data=game.model.enemies[target.forest_id];data.facing=.7;data.soldier_action="attack";data.soldier_clip=Soldier.data(0).get_meta("semantics").attack[0];data.soldier_tick=7
	target._sync_fitted_pose();aim(head_center(target));reset_target(target);combat.fire_shot()
	check(is_equal_approx(10000-target.hp,body_damage*2),"Headshot volume follows the animated and rotated native head")
	await key(2);aim(target.position+Vector3.UP*2);reset_target(target);combat.fire_shot()
	check(target.hp>0 and target.hp<10000,"A pistol body shot does not become a lethal headshot")
	var wall=StaticBody3D.new();wall.collision_layer=1
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(20,16,.5)
	wall.add_child(shape);game.add_child(wall);wall.position=Vector3(0,106,100);await frames()
	aim(head_center(target));reset_target(target);combat.fire_shot()
	check(target.hp==10000,"A wall prevents a pistol headshot from reaching the enemy")
	wall.queue_free();await frames();reset_target(target);combat.fire_shot()
	check(target.dead and target.hp<=0,"A pistol headshot kills a full-health enemy in one hit through the normal death path")
	check(game.model.enemies[target.forest_id].hp<=0,"Headshot kill reaches authoritative forest HP")
	for kind in [1,3,2]:
		var other=await spawn(Vector3(kind*15,100,70),kind)
		var region=preload("res://scripts/master_chief_hit_zones.gd").region(other)
		aim(region.pose*region.bounds.get_center());reset_target(other);combat.fire_shot()
		check(other.dead,"Pistol headshot is lethal for enemy role %d"%kind)
	# Native 0.5..2 Halo units, converted to metres and 3x arena scale.
	check(is_equal_approx(combat.BLAST_RADIUS,18.288),"Rocket cutoff uses the original 2-unit radius adapted to 3x arena scale")
	var close=await spawn(Vector3(0,100,90))
	var inside=await spawn(Vector3(12,100,90))
	var outside=await spawn(Vector3(25,100,90))
	var center=Vector3(0,103,90)
	hero.attack_chain.reset()
	var ticket=hero.attack_chain.make_ticket("rocket_launcher")
	combat.explode(center,null,{"ticket":ticket,"damage":240.0,"direction":Vector3.FORWARD})
	check(is_equal_approx(10000-close.hp,240.0),"Rocket splash retains full damage in its inner radius")
	check(inside.hp<10000 and inside.hp>close.hp,"Rocket splash damages beyond five metres and falls off with distance")
	check(outside.hp==10000,"Enemies outside the enlarged blast radius take no splash damage")
	await finish()
func finish():
	if is_instance_valid(game):game.queue_free()
	paused=false;await frames();await create_timer(.2).timeout
	print("MASTER_CHIEF_HEADSHOTS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
