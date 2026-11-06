extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Lion=preload("res://scripts/knight_lion.gd")
const Shot=preload("res://scripts/knight_lion_projectile.gd")
const OUT="res://build/Other Files/Asset Toolkit/Knight Lion/"
var origin=Vector3(0,30.1,60)
var visual=false

func spawn_target(offset:Vector3):
	var row=game.model.waves.spawn_enemy(0,origin+offset);row.hp=10000;row.max_hp=10000
	game.army_runtime.import_arrivals();game.army_runtime.sync_targets()
	return game.actors[row.id]

func press(action:String,down:bool=true):
	var event=InputEventAction.new();event.action=action;event.pressed=down
	if down:game.player._unhandled_input(event)
	else:game.player._input(event)

func render_capture(label_:String):
	if not visual:return
	game.crowd.army.present(game.army_runtime.render_snapshot(),game.army_runtime.presentation_events)
	game.army_runtime.presentation_events.clear()
	await physics_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label_+".png")

func run():
	create_timer(150).timeout.connect(func():printerr("FAIL: Knight lion timeout");quit(1))
	visual=DisplayServer.get_name()!="headless"
	await setup_fixture()
	game.set_process(false);game.army_runtime.set_physics_process(false)
	var p:Hero=game.player;p.select_character(7);p.set_auto_attack(false)
	var runtime=game.army_runtime
	runtime.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
	runtime.set_navigation(6000,{"width":2,"spacing":1000.0,"origin":Vector3(-500,0,-500),"heights":PackedFloat32Array([30,30,30,30]),"covered":PackedByteArray([1,1,1,1])})
	game.training_dummy.hide();game.training_dummy.position=Vector3(0,-100,0)
	var platform=StaticBody3D.new();platform.collision_layer=1
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(1000,1,1000)
	platform.add_child(shape);game.add_child(platform);platform.position=origin-Vector3.UP*.6
	p.position=origin;p.velocity=Vector3.DOWN;p.move_and_slide();p.facing=Vector3.FORWARD
	game.camera_rig.yaw=0
	game.camera_rig.camera.global_position=origin+Vector3(11,7,10)
	game.camera_rig.camera.look_at(origin+Vector3(0,1,-3))
	game.model.update_vision(origin)
	var loadout=p.spell_loadout
	var instance=loadout.instances["7:knight/lion"];var c=instance.controller
	var pool=Lion.Pool.service(game)
	pool.launched.connect(func(shot):
		if shot is Shot:shot.set_physics_process(false))
	await physics_frame;await physics_frame
	check(loadout.spell_for(7,"sky_strike")=="knight/lion","Knight T defaults to Royal Lion Rush")
	check(loadout.Catalog.all()["knight/lion"].source==7,"Lion is available in the existing spell catalogue")
	check(pool.all[pool.key_for(p,Shot,"knight-lion")].size()==2,"Selection prepares two reusable lions")
	check(loadout.filter_damage(100,Vector3.BACK,true)==100,"Charging lion does not silently grant shield protection")
	press("sky_strike");press("sky_strike",false)
	check(c.is_attacking() and c.charge_fx.visible and get_nodes_in_group("knight_lions").is_empty(),"A tap gathers energy before releasing a lion")
	var direction:Vector3=c.direction
	var side=direction.cross(Vector3.UP)
	var victims=[spawn_target(direction*5),spawn_target(direction*14+side*.8),spawn_target(direction*30)]
	var outside=spawn_target(direction*12+side*6)
	var rear=spawn_target(-direction*5)
	for i in 24:loadout.tick(1.0/60)
	check(get_nodes_in_group("knight_lions").is_empty(),"No damage projectile before charge completes")
	await render_capture("charge")
	for i in 25:loadout.tick(1.0/60)
	var shot=c.shots.back()
	check(shot.pool_live and not c.is_attacking() and not c.charge_fx.visible,"Charge releases exactly one prepared lion")
	check(not instance.can_cast() and instance.cooldown_remaining()>13,"Fourteen-second cooldown prevents retriggering")
	check(shot.animator.is_playing() and shot.animator.current_animation=="run","Lion plays the reused quadruped run animation")
	shot._physics_process(.12)
	await render_capture("lion")
	if visual:
		var camera=game.camera_rig.camera;var saved=camera.global_transform
		camera.global_position=shot.global_position+direction*5+side*6+Vector3.UP*3.5
		camera.look_at(shot.global_position+Vector3.UP*1.8)
		await render_capture("lion-closeup")
		camera.global_transform=saved
	shot._physics_process(.5)
	for victim in victims:check(is_equal_approx(victim.hp,10000-Shot.DAMAGE*p.damage_multiplier()),"Swept lion hits a native victim once, including a long frame")
	check(outside.hp==10000 and rear.hp==10000,"Enemies beside or behind the lane are untouched")
	var first_position:Vector3=runtime.unit_state(victims[0].handle).position
	runtime.step(1.0/60,{})
	print("LION_RECOIL ",first_position," -> ",runtime.unit_state(victims[0].handle))
	check((runtime.unit_state(victims[0].handle).position-first_position).dot(direction)>.25,"Native movement applies the strong forward knockback")
	var hp:float=victims[0].hp
	shot.position=origin;shot._physics_process(.12)
	check(victims[0].hp==hp,"Re-entering an already-hit victim cannot duplicate damage")
	shot.retire()
	# An isolated elevated lane tests the full lifetime without scenery terminating it.
	var lifetime_origin=origin+Vector3.UP*1000
	shot=pool.launch(p,Shot,"knight-lion",{"position":lifetime_origin,"direction":direction})
	shot._physics_process(4.99)
	check(shot.pool_live and is_equal_approx(shot.age,4.99),"Lion remains alive for the requested five seconds")
	check(absf((shot.global_position-lifetime_origin).dot(direction)-299.4)<.02,"Travel remains 60 metres per second without homing")
	shot._physics_process(.2)
	check(not shot.pool_live and is_equal_approx(shot.age,5.0),"Lifetime clamps the final step at five seconds")
	check(shot.hit_targets.is_empty() and shot.attack_ticket.is_empty() and shot.hero==null,"Retirement clears hit history and caster ownership")
	var large=pool.launch(p,Shot,"knight-lion",{"position":origin,"direction":direction,"size":2.0,"damage":720.0})
	var normal=pool.launch(p,Shot,"knight-lion",{"position":origin+side*8,"direction":direction})
	check(large!=normal and large.material!=normal.material and normal.hit_targets.is_empty(),"Overlapping lions own independent hit lists and effect parameters")
	check(is_equal_approx(large.ornament.scale.x,3.3) and is_equal_approx(normal.ornament.scale.x,1.65) and normal.damage==360,"A new lease resets size and damage instead of inheriting growth")
	large.retire();normal.retire()
	var wall=StaticBody3D.new();wall.collision_layer=1
	var wall_shape=CollisionShape3D.new();wall_shape.shape=BoxShape3D.new();wall_shape.shape.size=Vector3(12,8,.5)
	wall.add_child(wall_shape);game.add_child(wall);wall.position=origin+direction*3+Vector3.UP*3;wall.rotation.y=atan2(direction.x,direction.z)
	await physics_frame;await physics_frame
	hp=victims[1].hp
	shot=pool.launch(p,Shot,"knight-lion",{"position":origin,"direction":direction})
	shot._physics_process(.4)
	check(not shot.pool_live and victims[1].hp==hp,"Solid cover stops a lion before enemies behind it")
	wall.queue_free();await physics_frame;await physics_frame
	var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var created=pool.created;var misses=pool.misses
	for i in 12:
		c.cooldown=0;p.position=origin;p.velocity=Vector3.ZERO;p.attack_chain.reset()
		press("sky_strike");press("sky_strike",false)
		for frame in 49:loadout.tick(1.0/60)
		shot=c.shots.back();shot._physics_process(.25);shot.retire()
	check(pool.created==created and pool.misses==misses,"Repeated casts reuse existing lions without pool misses")
	print("LION_RESOURCES nodes=",nodes," -> ",Performance.get_monitor(Performance.OBJECT_NODE_COUNT)," resources=",resources," -> ",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated casts do not grow nodes or resources")
	c.cooldown=0;press("sky_strike");press("sky_strike",false);press("dodge");press("dodge",false)
	check(not c.is_attacking() and not c.charge_fx.visible,"Dodging cancels an unfinished charge")
	p.active_ability.cancel();c.cooldown=0;press("sky_strike");press("sky_strike",false)
	loadout.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not c.is_attacking() and not c.charge_fx.visible,"Focus loss clears energy without a delayed launch")
	press("heavy_attack")
	check(p.active_ability.player.blocking,"Knight still raises his original shield with RMB")
	press("heavy_attack",false)
	check(not p.active_ability.player.blocking,"Releasing RMB still lowers the original shield")
	loadout.equip(7,"sky_strike","goemon/dash")
	check(loadout.spell_for(7,"sky_strike")=="goemon/dash","A saved custom T assignment overrides the new default")
	loadout.equip(7,"sky_strike","")
	check(loadout.spell_for(7,"sky_strike")=="knight/lion" and loadout.cooldown_for("sky_strike")>0,"Restore original returns the lion without resetting its cooldown")
	p.select_character(1);p.position=origin;p.velocity=Vector3.ZERO
	loadout.equip(1,"equip","knight/lion")
	var weapon=p.weapon_slot;press("equip");press("equip",false)
	for i in 49:loadout.tick(1.0/60)
	check(p.character_id==1 and p.weapon_slot==weapon and get_nodes_in_group("knight_lions").size()==1,"A borrowed lion retains the receiving fighter and weapon")
	loadout.cancel()
	check(get_nodes_in_group("knight_lions").is_empty(),"Cancellation retires released lions")
	if visual:await profile_lion(pool,p,direction)
	game.queue_free();game=null;paused=false;await frames(3)
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("KNIGHT_LION_RESULT checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)

func profile_lion(pool,p,direction:Vector3):
	var results=[]
	root.grab_focus()
	for i in 60:await process_frame
	# Alternating the same rendered fixture measures incremental spell cost, not a full battle.
	for active in [false,true,false,true]:
		var shot=pool.launch(p,Shot,"knight-lion",{"position":origin,"direction":direction}) if active else null
		var times=[];var cpu=[];var focused=0;var before=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
		var last=Time.get_ticks_usec()
		for i in 180:
			await process_frame
			var now=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
			var start=Time.get_ticks_usec()
			if active:
				shot.position=origin+direction*4;shot._physics_process(1.0/60)
			cpu.append((Time.get_ticks_usec()-start)/1000.0)
			if root.has_focus():focused+=1
		times.sort();cpu.sort()
		results.append({"active":active,"frames":180,"focused":focused,"frame_p95_ms":times[171],"frame_p99_ms":times[178],"max_ms":times.back(),"projectile_cpu_p95_ms":cpu[171],"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-before})
		if active:shot.retire()
	FileAccess.open(OUT+"profile.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"Small paused-world fixture, alternating idle and one lion; no army-performance claim","renderer":RenderingServer.get_video_adapter_name(),"samples":results},"\t"))
