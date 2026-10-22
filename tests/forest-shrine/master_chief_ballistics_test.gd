extends SceneTree
## Real barrel paths, camera convergence, swept rockets and arena lethality.
var checks=0
var failures=0
var game
var shots:Array[Dictionary]=[]
func _initialize():
	create_timer(150).timeout.connect(func():printerr("FAIL: ballistics timeout");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1;print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func frames(count:int=3):
	for i in count:await physics_frame
func aim(point:Vector3):
	var rig=game.camera_rig
	var d=(point-(game.player.position+Vector3.UP*1.68)).normalized()
	rig.yaw=atan2(-d.x,-d.z);rig.pitch=-asin(d.y);rig.first_person_recoil=0;rig.update_camera(0)
func ready_weapon(slot:int):
	var hero=game.player;var combat=hero.master_chief_combat
	combat.cancel();combat.select_slot(slot);combat.cooldown=0;hero.attack_chain.reset()
	var view=game.camera_rig.first_person_viewmodel
	view.set_process(false);view.animations.play("idle");view.animations.advance(0)
	await frames(1);view.animations.pause()
	# fire_shot refreshes the camera and the recoil/bob pivot before reading
	# the marker. Sample that same current pose, not the previous gun's kick.
	game.camera_rig.update_camera(0)
	shots.clear()
func spawn(at:Vector3,kind:int=0):
	var data=game.model.waves.spawn_enemy(kind,at)
	data.hp=10000;data.max_hp=10000;data.stun=100
	game.model.visible_cells[game.model.cell_of(at)]=true
	game.sync_enemies();await frames()
	var actor=game.actors[data.id];actor.set_physics_process(false);actor._sync_fitted_pose()
	return actor
func place(actor,at:Vector3):
	actor.position=at;actor.hp=10000
	var data=game.model.enemies[actor.forest_id];data.pos=at;data.hp=10000
	game.model.visible_cells[game.model.cell_of(at)]=true;actor._sync_fitted_pose()
func wall(at:Vector3,size:Vector3)->StaticBody3D:
	var body=StaticBody3D.new();body.collision_layer=1
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=size
	body.add_child(shape);game.add_child(body);body.position=at
	return body
func live_rocket()->Dictionary:
	for rocket in game.player.master_chief_combat.rockets:
		if rocket.live:return rocket
	return {}
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate()
	game.settings_path="user://chief-ballistics-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames()
	var hero=game.player;hero.select_character(18);game.start_wave()
	game.model.waves.spawn_clock=10000;game.tuning.critical_chance=0;game.tuning.invincible=true
	game.set_physics_process(false);hero.set_physics_process(false)
	game.crowd.set_process(false);game.camera_rig.set_process(false)
	hero.position=Vector3(0,100,110);hero.velocity=Vector3.ZERO
	var combat=hero.master_chief_combat;var camera=game.camera_rig.camera
	combat.world_shot.connect(func(slot,from,to,contact,tracer):shots.append({"slot":slot,"from":from,"to":to,"contact":contact,"tracer":tracer}))
	var target=await spawn(Vector3(0,100,98))
	# Base damage is observed through the authoritative actor pipeline, with no
	# critical or chain bonus. The beefiest default soldier has 240 HP.
	for row in [[2,168.0],[4,84.0]]:
		place(target,Vector3(0,100,98));aim(target.position+Vector3.UP*2)
		await ready_weapon(row[0]);combat.fire_shot()
		check(is_equal_approx(10000-target.hp,row[1]),"Slot %d delivers powerful base body damage (%.1f)"%[row[0],10000-target.hp])
		check(shots.size()==1 and shots[0].contact.target==target,"Precision shot and visible endpoint agree on the same fitted victim")
	place(target,Vector3(0,100,106));aim(target.position+Vector3.UP*2)
	await ready_weapon(3);seed(71013);combat.fire_shot()
	check(10000-target.hp>600,"Close shotgun blast decisively kills a full-health 240 HP soldier")
	# Eye sees the target while a narrow obstruction crosses the physical
	# barrel path. Camera-only traces used to shoot straight through this.
	place(target,Vector3(0,100,98));aim(target.position+Vector3.UP*2)
	for slot in [2,3,4]:
		await ready_weapon(slot)
		var muzzle:Vector3=game.camera_rig.first_person_viewmodel.muzzle_position()
		var cover=wall(camera.global_position.lerp(muzzle,.5),Vector3(.025,.05,.08));await frames()
		check(not combat.trace(camera.global_position,target.position+Vector3.UP*2).impact or combat.trace(camera.global_position,target.position+Vector3.UP*2).target==target,"Fixture leaves the crosshair clear for slot %d"%slot)
		var before=target.hp;combat.fire_shot()
		check(target.hp==before,"Slot %d respects cover between eyes and barrel"%slot)
		var hits_cover=not shots.is_empty()
		for shot in shots:hits_cover=hits_cover and shot.contact.get("collider")==cover
		check(hits_cover,"Slot %d reports barrel obstruction to its visible impact"%slot)
		cover.queue_free();await frames()
	# Cover beyond the muzzle can also intersect the barrel line while leaving
	# the eye ray clear. Both phases of the shot must use real world geometry.
	for slot in [2,4]:
		await ready_weapon(slot)
		var muzzle:Vector3=game.camera_rig.first_person_viewmodel.muzzle_position()
		var sight=combat.trace(camera.global_position,camera.global_position-camera.global_basis.z*140)
		var cover=wall(muzzle.lerp(sight.point,.2),Vector3(.025,.06,.08));await frames()
		check(combat.trace(camera.global_position,sight.point+Vector3.FORWARD*.02).target==target,"Fixture keeps the eye ray clear beyond slot %d's muzzle"%slot)
		var before=target.hp;combat.fire_shot()
		check(target.hp==before and shots[0].contact.get("collider")==cover,"Slot %d's actual barrel line hits off-centre cover instead of the visible target"%slot)
		cover.queue_free();await frames()
	# Open launch originates at the animated muzzle and converges on the
	# actual crosshair surface rather than flying parallel beside a close aim.
	place(target,Vector3(0,100,98));aim(target.position+Vector3.UP*2)
	await ready_weapon(1)
	var muzzle:Vector3=game.camera_rig.first_person_viewmodel.muzzle_position()
	var aim_hit:Dictionary=combat.trace(camera.global_position,camera.global_position-camera.global_basis.z*160)
	combat.fire_shot();var rocket=live_rocket()
	check(not rocket.is_empty() and rocket.position.distance_to(muzzle)<.001,"Rocket launches at the animated launcher muzzle (%s vs %s)"%[rocket.get("position"),muzzle])
	if not rocket.is_empty():
		check((aim_hit.point-rocket.position).normalized().dot(rocket.direction)>.999999,"Rocket trajectory converges on the crosshair surface")
		var initial:Vector3=rocket.position;var d:Vector3=rocket.direction
		combat.advance_projectiles(.05)
		check(rocket.position.distance_to(initial+d*1.9)<.001,"Rocket flies a straight 38 m/s path without lateral jumps")
		var before=target.hp
		combat.advance_projectiles(.8)
		check(combat.live_rocket_count()==0 and is_equal_approx(before-target.hp,720),"Long-frame swept direct rocket delivers 720 damage without tunnelling")
	# The launch cannot skip a wall by spawning beyond it. Splash is blocked
	# toward the enemy on the far side, even at zero travel time.
	await ready_weapon(1);aim(target.position+Vector3.UP*2)
	var close_wall=wall(camera.global_position-camera.global_basis.z*.3,Vector3(8,8,.08));await frames()
	var before=target.hp;combat.fire_shot();combat.advance_projectiles(.01)
	check(combat.live_rocket_count()==0,"Close wall obstructs the rocket before it can spawn past the surface")
	check(target.hp==before,"Obstructed launch splash cannot damage through cover")
	close_wall.queue_free();await frames()
	# Pitch and yaw still govern the ballistic line when aiming vertically or
	# away from the old forward axis; no homing/snap to the previous victim.
	place(target,Vector3(60,100,98))
	for point in [Vector3(12,112,95),Vector3(-12,90,92),Vector3(0,140,110)]:
		aim(point);await ready_weapon(1)
		var end:Vector3=camera.global_position-camera.global_basis.z*160
		muzzle=game.camera_rig.first_person_viewmodel.muzzle_position()
		combat.fire_shot();rocket=live_rocket()
		check(not rocket.is_empty() and rocket.direction.dot((end-muzzle).normalized())>.999999,"Rocket follows pitched/yawed aim toward %s"%point)
	await finish()
func finish():
	if is_instance_valid(game):game.queue_free()
	paused=false;await frames();await create_timer(.2).timeout
	print("MASTER_CHIEF_BALLISTICS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
