extends SceneTree
## Regresses Explorer missing a nearby side target with the real Forest kit.
## Removing close assist must fail side hits; widening it must fail exclusions.
var game
var checks=0
var failures=0
var config_path="user://explorer-close-assist-%d.cfg"%OS.get_process_id()
const ORIGIN=Vector3(0,.1,70)
class InvalidGeometryRaider extends "res://tests/forest-shrine/reference/forest_raider.gd":
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
	game.army_runtime.clear()
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
	var data=game.model.waves.spawn_enemy(variant,ORIGIN+offset);data.hp=10000;data.max_hp=10000;data.stun=100
	game.sync_enemies()
	var actor=game.actors[data.id];actor.set_physics_process(false);actor._sync_fitted_pose()
	game.model.update_vision(ORIGIN)
	return data
func swing_steps(combat,steps: int=5):
	for i in steps:combat.tick(.012,false)
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
	await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.tuning.critical_chance=0.0
	for side in [-1.0,1.0]:
		await fresh();var data=target(Vector3(side*1.25,0,-2.6));var combat=game.player.active_ability
		press(true);press(false)
		var initial=float(combat.player.attack.angle)
		combat.tick(.012,false)
		var after=float(combat.player.attack.angle)
		check(absf(wrapf(after-initial,-PI,PI))>.05 and absf(wrapf(after-initial,-PI,PI))<.8,"Explorer smoothly begins turning toward a close side enemy (%s)"%side)
		check(is_equal_approx(float(combat.player.angle),after),"Explorer body and attack share the assisted facing")
		swing_steps(combat)
		check(data.hp<10000,"Explorer primary hits a nearby off-angle enemy (%s)"%side)
		check(is_equal_approx(float(combat.player.attack.contact),.055) and is_equal_approx(float(combat.player.attack.damage),19),"Explorer assist preserves contact timing and damage")
	for kind in ["distant","behind","dead","fog","cover","high"]:
		await fresh();var offset=Vector3(1.25,0,-2.6)
		if kind=="distant":offset=Vector3(6,0,-1)
		if kind=="behind":offset=Vector3(1,0,2)
		if kind=="high":offset=Vector3(1.5,8,-.2)
		var data=target(offset);var actor=game.actors[data.id]
		if kind=="dead":data.hp=0;actor.hp=0;actor.dead=true
		if kind=="fog":game.model.visible_cells.clear()
		var wall: StaticBody3D
		if kind=="cover":
			wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
			var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.2,8,8);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.global_position=ORIGIN+Vector3(.75,1,0);await frames()
		var combat=game.player.active_ability
		press(true);press(false);var angle=float(combat.player.attack.angle)
		swing_steps(combat)
		check(absf(wrapf(float(combat.player.attack.angle)-angle,-PI,PI))<.001,"Explorer does not magnet toward %s enemies"%kind)
		if kind not in ["dead"]:check(data.hp==10000,"Explorer cannot damage the %s excluded enemy"%kind)
		if is_instance_valid(wall):wall.queue_free();await frames()
	await fresh();var aligned=target(Vector3(.3,0,-1.8));target(Vector3(1.1,0,-.2))
	var combat=game.player.active_ability;press(true);press(false);swing_steps(combat)
	check(aligned.hp<10000 and absf(wrapf(float(combat.player.attack.angle)-PI,-PI,PI))<.5,"Explorer prefers the nearby enemy under the aim direction")
	await fresh(5);target(Vector3(1.25,0,-2.6));combat=game.player.active_ability
	press(true);press(false);var angle=float(combat.player.attack.angle);swing_steps(combat)
	check(absf(wrapf(float(combat.player.attack.angle)-angle,-PI,PI))>.03,"Ninja shares the gentle hidden melee assistance")
	# The current native boss has a distant root and a nearby fitted surface.
	await fresh()
	var boss_bounds=preload("res://scripts/forest/forest_enemy_contact.gd").shapes(4,false,game.army_runtime.enemy_size)[0].bounds
	var giant=target(Vector3(1.0-boss_bounds.position.x,0,-1.8-boss_bounds.end.z),4);combat=game.player.active_ability
	var foot: Vector3=game.actors[giant.id].combat_contact_point(game.player.position+Vector3.UP)
	var toward=foot-game.player.position
	game.camera_rig.yaw=atan2(-toward.x,-toward.z);combat.aim=foot;combat.attack()
	check(giant.pos.distance_to(ORIGIN)>20 and Vector2(toward.x,toward.z).length()<combat.player.attack.reach,"Boss fixture keeps the root distant and its fitted surface inside weapon reach")
	swing_steps(combat)
	check(giant.hp<10000,"Explorer assists toward a native boss's nearby fitted surface despite its distant root")
	for side in [-1.0,1.0]:
		await fresh();var nearby=target(Vector3(side*1.25,0,-2.6))
		game.player.set_physics_process(true)
		press(true);press(false);await frames(10)
		game.player.set_physics_process(false)
		check(nearby.hp<10000,"Explorer real body physics and primary input hit a close side target (%s)"%side)
		check(game.player.position.distance_to(ORIGIN)<.6,"Assisted attack retains only its short authored movement")
	await fresh();target(Vector3(1.25,0,-2.6));combat=game.player.active_ability
	press(true);press(false);combat.tick(.012,false)
	var committed=float(combat.player.attack.angle)
	game.model.visible_cells.clear();swing_steps(combat)
	check(absf(wrapf(float(combat.player.attack.angle)-committed,-PI,PI))<.001,"Losing sight during windup immediately releases assistance")
	await fresh();target(Vector3(1.25,0,-2.6));combat=game.player.active_ability
	press(true);press(false);swing_steps(combat)
	committed=float(combat.player.attack.angle)
	game.model.enemies.values()[0].pos=ORIGIN+Vector3(-1.25,0,-2.6)
	game.army_runtime.native.set_pose(game.actors.values()[0].handle,game.model.enemies.values()[0].pos,0);game.army_runtime.sync_compatibility()
	combat.tick(.012,false)
	check(absf(wrapf(float(combat.player.attack.angle)-committed,-PI,PI))<.001,"Assistance ends at contact instead of tracking through recovery")
	await fresh();var removed=target(Vector3(1.25,0,-2.6));combat=game.player.active_ability
	press(true);press(false)
	var removed_actor=game.actors[removed.id]
	game.army_runtime.despawn(removed_actor.handle);removed_actor.queue_free();game.model.enemies.erase(removed.id);await frames()
	combat.tick(.012,false)
	check(game.player.melee_assist.target()==null,"Freeing a target during windup releases its cached reference safely")
	var remaining=InvalidGeometryRaider.new();remaining.game=game;remaining.position=ORIGIN+Vector3(1.25,0,-2.6);remaining.variant=0
	game.add_child(remaining);remaining.set_physics_process(false);game.enemies.append(remaining)
	combat.player.attack=null;combat.attack()
	check(game.player.melee_assist.target()==remaining,"Acquisition skips a stale freed entry and still selects the next living candidate")
	remaining.queue_free()
	await fresh();combat=game.player.active_ability
	check(game.player.melee_assist.point(game.player,null,PI,2.75)==Vector3.INF,"Null candidates are safely rejected")
	var invalid=InvalidGeometryRaider.new();invalid.game=game;invalid.position=ORIGIN+Vector3(1.25,0,-2.6);invalid.variant=0
	game.add_child(invalid);invalid.set_physics_process(false);game.model.update_vision(ORIGIN)
	invalid.invalid_bounds=true
	check(game.player.melee_assist.point(game.player,invalid,PI,2.75)==Vector3.INF,"Nonfinite fitted bounds are safely rejected")
	invalid.invalid_bounds=false;invalid.invalid_contact=true
	check(game.player.melee_assist.point(game.player,invalid,PI,2.75)==Vector3.INF,"Nonfinite fitted contact is safely rejected")
	invalid.queue_free()
	# A near perpendicular wall is in the evasive step's route while leaving
	# the target ray open. Forward assistance must still use native collision.
	await fresh();target(Vector3(1.25,0,-2.6))
	var blocker=StaticBody3D.new();blocker.collision_layer=1;blocker.collision_mask=0
	var collider=CollisionShape3D.new();var bounds=BoxShape3D.new();bounds.size=Vector3(.2,8,8);collider.shape=bounds;blocker.add_child(collider);game.add_child(blocker);blocker.global_position=ORIGIN+Vector3(-.7,1,0)
	await frames();game.player.set_physics_process(true);press(true);press(false);await frames(15)
	game.player.set_physics_process(false)
	check(absf(wrapf(float(game.player.active_ability.player.angle)-PI,-PI,PI))>.03,"Explorer still assists a visible target beside the motion-blocking wall")
	check(game.player.position.x>-.7,"Explorer attack motion cannot cross solid terrain")
	blocker.queue_free()
	game.queue_free();paused=false;await frames(3);await create_timer(.35).timeout
	if FileAccess.file_exists(config_path):DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("FOREST_EXPLORER_ASSIST_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
