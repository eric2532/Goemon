extends SceneTree
## Exercise approved Pirate motion against real Forest physics, combat and input.
var game
var checks=0
var failures=0
var ORIGIN=Vector3(0,.1,30) # Flat courtyard; keep jump checks off the ramp.
func _initialize():
	create_timer(90).timeout.connect(func():printerr("FAIL: Pirate gameplay timeout");quit(1))
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
	for i in range(20):
		await physics_frame
		game.player.active_ability._move_body(1.0/60)
	game.player.active_ability.player.pos=game.player.global_position
func target(offset: Vector3,variant: int=0):
	var id=9000+game.model.enemies.size()
	var data={"id":id,"variant":variant,"pos":ORIGIN+offset,"hp":10000.0,"max_hp":10000.0,"velocity":Vector3.ZERO,"stun":100.0,"attack":false,"clock":0.0,"facing":0.0,"action":"walk","action_left":0.0,"attack_progress":0.0,"walk_phase":0.0}
	game.model.enemies[id]=data;game.sync_enemies()
	var actor=game.actors[id];actor.set_physics_process(false);actor._sync_fitted_pose()
	game.model.update_vision(ORIGIN)
	return data
var output="res://build/Other Files/Pirate Weapons/Runtime"
func capture(label_: String):
	if DisplayServer.get_name()=="headless":return
	# Keep the verification character visible in the captured review frames.
	game.crowd.hide()
	for enemy in game.actors.values():enemy.hide()
	for worker in game.world.worker_nodes.values():worker.hide()
	if is_instance_valid(game.training_dummy):game.training_dummy.hide()
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label_+".png"))
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	set_meta("forest_painterly_preview",true)
	if "--packaged" in OS.get_cmdline_user_args():
		check(not FileAccess.file_exists("res://tools/export_pirate_animations.py") and FileAccess.file_exists("res://assets/animations/pirate_approved.json"),"Approved Pirate data ships in the game package")
	root.size=Vector2i(1280,800)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://pirate-animation-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game
	await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=1
	game.set_process(false)
	ORIGIN.y=game.world.height_at(ORIGIN.x,ORIGIN.z)+.1
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.invincible=true;game.tuning.critical_chance=0.0
	await fresh(3)
	game.camera_rig.camera.global_position=game.player.position+Vector3(3.8,2.4,-5.2)
	game.camera_rig.camera.look_at(game.player.position+Vector3(0,1,0))
	var c=game.player.active_ability;var actor=c.visual_actor
	actor.reset_motion();c._animate(0,0)
	var motion=actor.cosplay_rig.get("pirate_motion")
	check(c.class_id=="pirate" and motion!=null,"Playable Pirate uses the approved Blender poses (phase=%s paused=%s)"%[game.model.phase,game.paused])
	if motion==null:quit(1);return
	check(motion.last_clip=="idle" and motion.last_frame==0,"Player starts at user idle frame zero")
	await capture("01-game-idle")
	Input.action_press("move_forward")
	var start: Vector3=game.player.position
	for i in 45:
		await physics_frame
		c.physics_step(1.0/60)
	check(game.player.position.distance_to(start)>2 and motion.last_clip=="","Running retains movement: distance=%f clip=%s speed=%f floor=%s"%[game.player.position.distance_to(start),motion.last_clip,actor.locomotion.stride_speed,game.player.is_on_floor()])
	Input.action_release("move_forward")
	for i in 90:
		await physics_frame
		c.physics_step(1.0/60)
	check(motion.last_clip=="idle" and game.player.velocity.length()<.1,"Movement settles into the approved idle")
	game.camera_rig.camera.global_position=game.player.position+Vector3(3.8,2.4,-5.2)
	game.camera_rig.camera.look_at(game.player.position+Vector3(0,1,0))
	var ground_y: float=game.player.position.y
	game.player.jump_buffer=.15
	var apex=ground_y;var saw_air=false;var saw_landing=false
	for i in 150:
		await physics_frame
		c.physics_step(1.0/60);apex=maxf(apex,game.player.position.y)
		if motion.last_clip=="jump" and motion.last_frame>=22 and motion.last_frame<=60:saw_air=true
		if motion.last_clip=="jump" and motion.last_frame>=76:saw_landing=true
		if i==20:await capture("02-game-jump-air")
		if motion.last_clip=="jump" and motion.last_frame>=76 and motion.last_frame<81:await capture("03-game-jump-land")
	check(saw_air and saw_landing and apex>ground_y+1,"Real jump: air=%s land=%s rise=%f"%[saw_air,saw_landing,apex-ground_y])
	check(game.player.is_on_floor() and absf(game.player.position.y-ground_y)<.1 and motion.last_clip=="idle","Jump returns to the physical floor and approved idle")
	check(actor.model.position.length()<.001,"Blender does not add duplicate jump travel")
	# Use live targets and the combat clock, rather than only probing animation data.
	await fresh(3);c=game.player.active_ability;actor=c.visual_actor;c._animate(0,0);motion=actor.cosplay_rig.pirate_motion
	game.camera_rig.camera.global_position=game.player.position+Vector3(3.8,2.4,-5.2)
	game.camera_rig.camera.look_at(game.player.position+Vector3(0,1,0))
	var e=target(Vector3(0,0,-2));c.aim=ORIGIN+Vector3.FORWARD*10
	for index in 3:
		c.hit_stop=0;c.attack();c._animate(0,0)
		var a=c.player.attack;var contact=float(a.contact);var duration=float(a.duration);var before=float(e.hp)
		var tempo=game.player.attack_speed_multiplier()
		print("COMBAT_PROBE index=",index," tempo=",tempo," contact=",contact," duration=",duration)
		check(a.index==index,"Primary chain selects slash %d"%(index+1))
		c.tick((contact-.001)/tempo,false);c._animate(0,0)
		check(is_equal_approx(e.hp,before),"Slash %d waits for its real damage contact"%(index+1))
		c.tick(.001/tempo,false);c._animate(0,0)
		check(e.hp<before and motion.last_clip=="slash" and absf(motion.last_frame-float([13,29,48][index]))<.01,"Slash %d damage matches its authored blade contact"%(index+1))
		await capture("04-game-slash-%d"%(index+1))
		c.hit_stop=0;c.tick((duration-contact+.002)/tempo,false);c._animate(0,0)
	c.cancel();c.player.cooldowns.flintlock=0;c.aim=ORIGIN+Vector3.FORWARD*10
	c.action("flintlock");c._animate(0,0)
	check(c.projectiles.size()==1 and c.projectiles[0].kind=="bullet" and motion.last_clip=="shot","Flintlock fires a real bullet using the user's aiming pose")
	check(is_equal_approx(motion.last_frame,0),"Real flintlock begins at user frame zero")
	await capture("05-game-gunshot")
	c.tick(.07,false);c._animate(0,0);await capture("06-game-recoil")
	for i in 45:c.tick(1.0/60);c._animate(1.0/60,0)
	check(motion.last_clip=="idle","Gunshot recovers to the approved idle")
	c.cancel();c.player.cooldowns.flintlock=0;c.action("flintlock")
	c.player.cooldowns.roll=0;c.action("roll");c._animate(0,0)
	check(c.player.shot>0 and motion.last_clip=="","Real dodge interrupts an active shot timer")
	c.cancel();c.attack();c.player.cooldowns.drink=0;c.action("drink");c._animate(0,0)
	check(c.player.attack!=null and c.player.drinkGesture>0 and motion.last_clip=="","Real drink gesture interrupts a primary slash")
	c.cancel()
	var reach=[]
	for multiplier in [1.0,2.0]:
		c._ticket={"rogue_range_scale":multiplier,"melee_reach_scale":1.0}
		var a=c.COMBO[0].duplicate(true)
		a.merge({"primary":true,"style":"sword","weapon":"cutlass","index":0,"time":0.0,"angle":c.player.angle},true)
		c.fit_primary_reach(a);reach.append(a.reach)
	check(reach[1]>reach[0]+.3,"Range upgrades extend actual authored-blade combat reach")
	c.cancel()
	game.player.select_character(11);game.player.active_ability._animate(0,0)
	check(game.player.active_ability.visual_actor.cosplay_rig.pirate_motion==null,"Pirate changes leave Explorer isolated")
	game.player.select_character(3);game.player.active_ability._animate(0,0)
	check(game.player.active_ability.visual_actor.cosplay_rig.pirate_motion.last_clip=="idle","Switching back creates a clean Pirate idle")
	Input.action_release("move_forward");game.queue_free();paused=false;await frames(3)
	print("PIRATE_GAMEPLAY_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
