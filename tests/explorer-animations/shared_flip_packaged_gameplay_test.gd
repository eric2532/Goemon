extends SceneTree
## Regresses Explorer missing a nearby side target with the real Forest kit.
## Removing close assist must fail side hits; widening it must fail exclusions.
var game
var checks=0
var failures=0
const ORIGIN=Vector3(0,.1,70)
class InvalidGeometryRaider extends "res://scripts/forest/forest_raider.gd":
	var invalid_bounds=false
	var invalid_contact=false
	func combat_bounds()->AABB:
		return AABB(Vector3(NAN,0,0),Vector3.ONE) if invalid_bounds else super.combat_bounds()
	func combat_contact_point(point: Vector3)->Vector3:
		return Vector3(NAN,0,0) if invalid_contact else super.combat_contact_point(point)
func _initialize():
	create_timer(90).timeout.connect(func():printerr("FAIL: Explorer assist timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func frames(n: int=2):
	for i in n:await physics_frame
func press(down: bool):
	var event=InputEventAction.new();event.action="light_attack";event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()
func fresh(hero_id: int=11):
	press(false)
	for actor in game.actors.values():
		if is_instance_valid(actor):actor.queue_free()
	game.actors.clear();game.enemies.clear();game.model.enemies.clear()
	await frames()
	game.player.select_character(hero_id);game.player.set_auto_attack(false)
	game.player.position=ORIGIN;game.player.velocity=Vector3.ZERO
	game.player.attack_chain.reset();game.player.active_ability.reset_run()
	game.player.active_ability.player.pos=ORIGIN
	game.camera_rig.yaw=0
	game.camera_rig.camera.global_position=ORIGIN+Vector3(0,2.4,10)
	game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1.1,-15))
	game.model.update_vision(ORIGIN)
	for i in range(20):game.player.active_ability._move_body(1.0/60)
	game.player.active_ability.player.pos=game.player.global_position
func target(offset: Vector3,variant: int=0):
	var id=9000+game.model.enemies.size()
	var data={"id":id,"variant":variant,"pos":ORIGIN+offset,"hp":10000.0,"max_hp":10000.0,"velocity":Vector3.ZERO,"stun":100.0,"attack":false,"clock":0.0,"facing":0.0,"action":"walk","action_left":0.0,"attack_progress":0.0,"walk_phase":0.0}
	game.model.enemies[id]=data;game.sync_enemies()
	var actor=game.actors[id];actor.set_physics_process(false);actor._sync_fitted_pose()
	game.model.update_vision(ORIGIN)
	return data
func swing_steps(combat,steps: int=5):
	for i in steps:combat.tick(.012,false)
func run():
	if "--packaged" in OS.get_cmdline_user_args():check(not FileAccess.file_exists("res://tools/export_tucked_double_jump.py") and FileAccess.file_exists("res://assets/animations/tucked_double_jump.json"),"Real jumps use packaged flip data")
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://shared-flip-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game
	await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.tuning.critical_chance=0.0
	for id in [5,10,11]:
		for delay in [2,12]:
			await fresh(id)
			var c=game.player.active_ability;var actor=c.visual_actor;actor.reset_motion();c._animate(0,0)
			var motion=actor.cosplay_rig.double_jump;var label_=c.class_id+" delay=%d"%delay
			var floor_y: float=game.player.position.y
			game.player.jump_buffer=.15
			for i in delay:c.physics_step(1.0/60)
			check(not motion.active,label_+" first jump retains its own animation")
			game.player.jump_buffer=.15;c.physics_step(1.0/60)
			check(game.player.jumps_used==2 and game.player.velocity.y>0 and motion.active,label_+" second jump starts the shared flip")
			var saw_inverted=false;var finished_air=false
			for i in 145:
				c.physics_step(1.0/60)
				var sk: Skeleton3D=actor.cosplay_rig.skeleton;var b=sk.find_bone("Root")
				var turn=sk.get_bone_global_pose(b).basis*sk.get_bone_global_rest(b).basis.inverse()
				if (turn*Vector3.UP).dot(Vector3.UP)<-.9:saw_inverted=true
				if not motion.active and not game.player.is_on_floor():finished_air=true
			check(saw_inverted and finished_air,label_+" completes its tuck/turn before landing")
			check(game.player.is_on_floor() and absf(game.player.position.y-floor_y)<.1 and not motion.active,label_+" returns to the collision floor")
		await fresh(id)
		var c=game.player.active_ability;var actor=c.visual_actor;actor.reset_motion();c._animate(0,0)
		game.player.jump_buffer=.15
		for i in 12:c.physics_step(1.0/60)
		game.player.jump_buffer=.15
		for i in 10:c.physics_step(1.0/60)
		check(actor.cosplay_rig.double_jump.active,c.class_id+" is flipping before an airborne attack")
		c.attack();c._animate(1.0/60,0)
		check(not actor.cosplay_rig.double_jump.active and c.player.attack!=null,c.class_id+" native airborne attack interrupts the flip")
		if c.class_id=="ranger":
			check(c.player.attack.style=="bow-fan" and c.player.attack.downward,"Ranger retains his downward second-jump fan")
		for i in 30:c.tick(1.0/60,false);c._animate(1.0/60,0)
		check(not actor.cosplay_rig.double_jump.active,c.class_id+" attack completion does not restart a stale flip")
	game.queue_free();paused=false;await frames(3)
	print("SHARED_FLIP_GAMEPLAY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
