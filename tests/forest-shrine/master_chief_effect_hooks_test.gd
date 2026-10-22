extends SceneTree
## Exercises projectile FX events through real camera fire and world contacts.
var checks=0
var failures=0
var game
var shots:Array[Dictionary]=[]
func _initialize():
	create_timer(150).timeout.connect(func():printerr("FAIL: effect hooks timeout");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1;print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func frames(count:int=3):
	for i in count:await physics_frame
func verify_viewmodel()->bool:
	var camera=Camera3D.new();camera.position=Vector3(3,4,5);camera.rotation.y=.7;root.add_child(camera)
	var view=load("res://scripts/master_chief_viewmodel.gd").new();camera.add_child(view);await frames()
	check(view.has_method("marker_transform"),"First-person effects expose animated native muzzle and ejection markers")
	if not view.has_method("marker_transform"):
		camera.queue_free();await frames();return false
	var positions={1:Vector3(.24506888,-.00241360,.53448749),2:Vector3(.06429405,-.09570773,-.49401050),3:Vector3(.14612230,-.14646246,-.30308094),4:Vector3(.15526871,-.09715342,-.06153899)}
	for slot in [1,2,3,4]:
		view.select_slot(slot,true);view.animations.play("idle");view.animations.advance(0)
		await frames(1);view.animations.pause()
		var marker:Transform3D=view.marker_transform("primary ejection")
		check(marker.origin.distance_to(positions[slot])<.003,"Slot %d uses its recovered ejection marker in converted metres"%slot)
		check(absf(marker.basis.determinant()-1.0)<.001,"Slot %d marker removes the source rig's centimetre scale"%slot)
		var world:Transform3D=view.marker_transform("primary ejection",true)
		check(world.origin.distance_to(camera.global_transform*marker.origin)<.0001,"Slot %d world casing marker follows the player's real camera"%slot)
	view.select_slot(3);view.animations.play("idle");view.animations.advance(0);await frames(1)
	view.animations.pause();var idle:Transform3D=view.marker_transform("primary ejection")
	view.animations.play("firing");view.animations.advance(.4);await frames(1);view.animations.pause()
	check(view.marker_transform("primary ejection").origin.distance_to(idle.origin)>.001,"Ejection marker follows native firing animation instead of a fixed screen offset")
	view.fire_shot()
	check(view.native_fx.live_count()>0,"Firing dispatches the recovered first-person flash and smoke graph")
	view.select_slot(4);var samples={};var recovered=true
	for i in 24:
		view.fire_shot();view.native_fx.clear()
		var voice=view.audio_pool[posmod(view.audio_cursor-1,view.audio_pool.size())]
		samples[voice.stream.resource_path]=true
		recovered=recovered and voice.stream.resource_path.begins_with("res://assets/characters/master_chief/effects/sound/")
	check(recovered and samples.size()>1,"Assault rifle chooses recovered firing permutations instead of repeating one WAV")
	view.native_fx.set_process(false);view.fire_shot()
	var flashes=view.native_fx.particles.snapshot().filter(func(p):return str(p.bitmap.get("path","")).ends_with("flash h ar fp"))
	var attached=false
	if not flashes.is_empty():
		var initial:Transform3D=view.marker_transform("primary trigger")
		var offset:Vector3=initial.affine_inverse()*flashes[0].position
		var pivot:Transform3D=view.weapon_pivot.transform
		view.weapon_pivot.position+=Vector3(.15,.08,0);view.native_fx.advance(.001)
		var moved=view.native_fx.particles.snapshot().filter(func(p):return p.id==flashes[0].id)
		attached=not moved.is_empty() and moved[0].position.distance_to(view.marker_transform("primary trigger")*offset)<.0001
		view.weapon_pivot.transform=pivot
	check(attached,"Native attached rifle flashes follow the moving barrel for their full lifetime")
	view.native_fx.set_process(true)
	view.select_slot(3)
	view.stop()
	check(view.native_fx.live_count()==0 and view.native_fx.pending_count()==0,"Stopping the viewmodel clears native effects and delayed mechanical events")
	var world_fx=load("res://scripts/halo_weapon_effects.gd").new();root.add_child(world_fx);world_fx.set_process(false)
	view.animations.play("idle");view.animations.advance(0);await frames(1);view.animations.pause()
	var args=[3,view.marker_transform("primary trigger",true),view.marker_transform("primary ejection",true)]
	for method in world_fx.get_method_list():
		if method.name=="fire_ejection" and method.args.size()>=4:args.append(view.marker_transform.bind(true));break
	world_fx.callv("fire_ejection",args)
	check(world_fx.live_count()==0 and world_fx.pending_count()>0,"Shotgun retains its native half-second delayed shell ejection")
	world_fx.advance(.49)
	camera.position.x+=6
	view.animations.play("firing");view.animations.advance(.4);await frames(1);view.animations.pause()
	var expected:Transform3D=view.marker_transform("primary ejection",true)
	world_fx.advance(.01)
	var shells:Array=world_fx.particles.snapshot()
	check(shells.size()==1 and shells[0].position.distance_to(expected.origin)<.01,"Delayed shell samples the current camera and animated ejection marker at emission")
	world_fx.clear();world_fx.callv("fire_ejection",args);world_fx.cancel_ejection();world_fx.advance(.6)
	check(world_fx.live_count()==0 and world_fx.pending_count()==0,"Weapon switching cancels the pending shotgun shell job")
	var native=world_fx.data.resolve({"class":"particle","path":"effects\\particles\\solid\\casing h shotgun"})
	var emission={"flags":8,"relative_direction_vector":{"x":1},"radius":{"from":.02,"to":.02},"tint_lower_bound":{"r":1,"g":0,"b":0,"a":1},"tint_upper_bound":{"r":0,"g":1,"b":0,"a":1}}
	world_fx._particle(native,emission,world_fx._context(Vector3.ZERO))
	var particle:Dictionary=world_fx.particles.snapshot()[0]
	check(particle.rotation==0.0,"Native emissions randomize their initial angle only when the original flag permits it")
	check(is_equal_approx(maxf(particle.tint.r,particle.tint.g),1.0) and particle.tint.b<.0001,"Native HSV tint emissions preserve saturation between red and green")
	world_fx.queue_free()
	camera.queue_free();await frames();return true
func run():
	if not await verify_viewmodel():await finish();return
	game=load("res://scenes/forest_shrine.tscn").instantiate()
	game.settings_path="user://chief-effects-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames()
	var hero=game.player;hero.select_character(18)
	game.start_wave();game.model.waves.spawn_clock=10000;game.tuning.invincible=true
	game.set_physics_process(false);hero.set_physics_process(false)
	hero.position=Vector3(0,100,110);hero.velocity=Vector3.ZERO
	game.camera_rig.yaw=0;game.camera_rig.pitch=0;game.camera_rig.update_camera(0)
	await frames();var combat=hero.master_chief_combat
	check(combat.has_signal("world_shot"),"Real projectile emission exposes original-effect contacts")
	if not combat.has_signal("world_shot"):await finish();return
	combat.world_shot.connect(func(slot,from,to,contact,tracer):shots.append({"slot":slot,"from":from,"to":to,"contact":contact,"tracer":tracer}))
	combat.select_slot(3);combat.cooldown=0;combat.fire_shot()
	check(shots.size()==15,"One shotgun round emits fifteen independently traced pellets")
	var distinct={};var max_angle=0.0
	var origin:Vector3=game.camera_rig.camera.global_position
	for shot in shots:
		distinct[shot.to]=true
		max_angle=maxf(max_angle,Vector3.FORWARD.angle_to((shot.to-origin).normalized()))
	check(distinct.size()==15 and max_angle<=deg_to_rad(10.001),"Shotgun traces stay inside the recovered ten degree error cone")
	var first_pattern=[]
	for shot in shots:first_pattern.append(shot.to)
	var angles=[]
	for burst in 20:
		shots.clear();combat.tick_timers(1.1);combat.fire_shot()
		var axis:Vector3=-game.camera_rig.camera.global_basis.z
		for shot in shots:angles.append(rad_to_deg(axis.angle_to((shot.to-origin).normalized())))
	var changed=false
	for i in 15:
		if shots[i].to.distance_to(first_pattern[i])>.001:changed=true
	var mean=0.0
	for angle in angles:mean+=angle/float(angles.size())
	check(changed and mean>4.2 and mean<5.8,"Shotgun independently samples native uniform cone angles instead of repeating a disk pattern")
	shots.clear();combat.fire_shot()
	check(shots.is_empty(),"Cooldown rejection emits no extra pellets or effects")
	combat.select_slot(4);combat.cooldown=0;combat.primary_held=true
	for i in 13:
		combat.tick(0)
		combat.fire_shot() # Rejected by recovery; must not consume a tracer turn.
		combat.tick_timers(1.0/15.0)
	var flags=[]
	for shot in shots:flags.append(shot.tracer)
	check(flags==[true,false,false,false,true,false,false,false,true,false,false,false,true],"Native AR counter emits first shot and then every fourth projectile")
	# Native rate reaches full value after one second and needs 0.1s to decay.
	combat.tick_timers(.2)
	var release=InputEventAction.new();release.action="light_attack";release.pressed=false
	combat.release_input(release);combat.tick_timers(.01)
	combat.primary_held=true;shots.clear();combat.tick(0)
	check(shots.size()==1 and not shots[0].tracer,"Brief trigger release preserves the native tracer counter while rate is nonzero")
	combat.release_input(release);combat.tick_timers(.11)
	combat.primary_held=true;shots.clear();combat.tick(0)
	check(shots.size()==1 and shots[0].tracer,"Resting for native deceleration makes the next AR shot a tracer")
	combat.cancel()
	var wall=StaticBody3D.new();wall.collision_layer=1;wall.set_meta("halo_material","wood")
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(8,6,.4)
	wall.add_child(shape);game.add_child(wall);wall.position=Vector3(0,102,104);await frames()
	combat.select_slot(2);combat.cooldown=0;shots.clear();combat.fire_shot()
	var hit:Dictionary=shots[0].contact
	check(hit.impact and hit.get("collider")==wall and hit.normal.z>.99,"Effects receive the actual collision surface and outward normal")
	check(hit.get("material")=="wood","Effects receive the authored material of the collider")
	var children=combat.get_child_count()
	for i in 30:
		combat.tick_timers(.3);combat.fire_shot()
	check(combat.get_child_count()==children,"Repeated impacts retain bounded combat child pools")
	combat.select_slot(1);combat.cooldown=0;combat.fire_shot()
	check(combat.live_rocket_count()==1,"Native trail lifecycle starts with a live pooled rocket")
	combat.cancel()
	check(combat.live_rocket_count()==0,"Cancellation retires every rocket and its native trail")
	wall.queue_free();await frames()
	var data=game.model.waves.spawn_enemy(0,Vector3(0,100,98))
	data.hp=10000;data.max_hp=10000;data.stun=100
	game.model.visible_cells[game.model.cell_of(data.pos)]=true
	game.sync_enemies();await frames()
	var target=game.actors[data.id];target.set_physics_process(false);target._sync_fitted_pose()
	combat.select_slot(2);combat.cooldown=0;shots.clear();combat.fire_shot()
	hit=shots[0].contact
	check(hit.target==target and hit.get("collider")==target and hit.get("material")=="human_skin","Fitted enemy hits carry flesh contacts through the same effect hook")
	check(target.hp<10000,"Effect routing retains the ordinary authoritative damage path")
	await finish()
func finish():
	if InputMap.has_action("light_attack"):Input.action_release("light_attack")
	if is_instance_valid(game):game.queue_free()
	paused=false;await frames();await create_timer(.2).timeout
	print("MASTER_CHIEF_EFFECT_HOOKS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
