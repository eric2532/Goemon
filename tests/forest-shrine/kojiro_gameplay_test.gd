extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Shot=preload("res://scripts/kojiro_projectile.gd")
const OUT="res://build/Other Files/Asset Toolkit/Kojiro/Phoenix Rise/"
var launches=[]
var release_data=[]
var timings=[]
var rendered_intervals=[]
var realtime=true
var focus_losses=0
var step_recoil=false
var recoil_handle=0
func mouse_click():
	var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
	event.position=root.get_visible_rect().size*.5;event.global_position=event.position
	event.pressed=true;Input.parse_input_event(event);Input.flush_buffered_events()
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events()
func advance(count:int):
	var previous_frame=Time.get_ticks_usec()
	for i in count:
		var start=Time.get_ticks_usec()
		game.player._physics_process(1.0/60)
		if step_recoil:
			game.army_runtime.step(1.0/60,{"goal_handles":PackedInt64Array([recoil_handle]),"goal_positions":PackedVector3Array([ORIGIN+Vector3(0,0,-2)]),"goal_speeds":PackedFloat32Array([0])})
			game.army_runtime.sync_targets()
		for nodes in Pool.service(game).all.values():
			for shot in nodes:
				if shot.pool_live and shot.get_script()==Shot:shot._physics_process(1.0/60)
		timings.append((Time.get_ticks_usec()-start)/1000.0)
		if DisplayServer.get_name()!="headless" and realtime:
			await physics_frame
			var now=Time.get_ticks_usec();rendered_intervals.append((now-previous_frame)/1000.0);previous_frame=now
		elif i%30==0:await process_frame
func capture(label_:String):
	if DisplayServer.get_name()=="headless":return
	game.player.model.show()
	game.forest_ui.sync()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label_+".png")
func run():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	create_timer(180).timeout.connect(func():printerr("KOJIRO_TIMEOUT");quit(1))
	if DisplayServer.get_name()!="headless":
		root.set_flag(Window.FLAG_NO_FOCUS,true) # Desktop focus changes must not cancel manually stepped casts.
	root.focus_exited.connect(func():focus_losses+=1)
	await setup_fixture()
	game.tuning.invincible=true # This fixture measures outgoing attacks, not survival.
	var p=game.player;p.select_character(28);fresh();await advance(12)
	var combat=p.active_ability;var model=p.model;var pool=Pool.service(game)
	pool.launched.connect(func(shot):
		if shot.get_script()==Shot:
			shot.set_physics_process(false);launches.append(shot.kind)
			release_data.append({"kind":shot.kind,"damage":shot.damage,"size":shot.visual.scale.x/shot.unit/(2 if shot.kind=="spark" else 3 if shot.kind=="dust" else .5 if shot.kind=="wave" else 1),"velocity":shot.velocity,"position":shot.position,"caster_position":p.global_position}))
	game.camera_rig.camera.position=ORIGIN+Vector3(6,4,10);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1.5,-2))
	check(p.character_id==28 and model.parts.size()==15,"Kojiro selects the complete body and sword through the shared roster")
	model.pose(model.data().semantics.idle,0,true)
	var body_bounds=AABB()
	for i in 14:
		var part=model.parts[i] as MeshInstance3D
		var box=model.global_transform.affine_inverse()*part.global_transform*part.get_aabb()
		body_bounds=box if i==0 else body_bounds.merge(box)
	check(absf(body_bounds.size.y-3.2206185*.9)<.001,"Kojiro's standing body is exactly 10% shorter than its previous Goemon-height fit")
	check(absf(body_bounds.position.y)<.001,"Resizing keeps Kojiro's feet on the ground")
	check(is_equal_approx(p.body_shape.shape.height,1.85*.9) and is_equal_approx(p.body_shape.shape.radius,.38*.9) and is_equal_approx(p.body_shape.position.y,.95*.9),"Kojiro's capsule follows the smaller body")
	check(is_equal_approx(p.contact_size_multiplier(),.9) and p.scale==Vector3.ONE,"Kojiro uses intrinsic size without consuming building growth")
	check(model.data().semantics.values().all(func(clip):return model.animation_player.has_animation(clip)),"All mapped original clips are imported")
	check(model.source_unit()>.03 and model.source_unit()<.05,"Effects use the inner ROM root scale, excluding Godot’s wrapper")
	check(p.is_on_floor(),"Shared player movement grounds Kojiro")
	game.forest_ui.sync()
	check(game.forest_ui.hero_name.text=="Kojiro" and game.forest_ui.hero_portrait.texture==p.RogueRoster.portrait(28),"HUD shows Kojiro’s own name and portrait")
	check(game.forest_ui.spell_summary.text.contains("Homing") and game.forest_ui.spell_summary.text.contains("Wind"),"Default skills are visible in the shared HUD")
	await capture("idle")
	model.clock=100;model.move_clock=0
	model.animate(.1,7,true,0,0,false,0,false)
	check(model.current_clip=="Source__801e22a0","Forward movement uses the ROM forward run, not the lateral run")
	model.animate(.1,14,true,0,0,false,0,false)
	check(is_equal_approx(model.move_clock,.3),"Acceleration advances the stride continuously instead of rescaling its history")
	model.animate(.1,3,true,0,0,false,0,false)
	check(model.current_clip=="Source__801e21f8","Slow movement retains the recovered walk")
	model.animate(.1,0,true,0,0,false,0,false)
	check(model.move_clock==0,"Stopping resets the next stride cleanly")
	p.smoke_move=Vector2(1,0)
	for phase in 3:
		await advance(8);await capture("run-%d"%phase)
	await capture("run");p.smoke_move=Vector2.ZERO
	check(model.current_clip=="Source__801e22a0","Actual player movement selects the corrected run")
	fresh();await advance(12)
	tap("light_attack");await advance(14)
	check(contacts.is_empty(),"Sword keeps its windup at twice the playback speed")
	await advance(2);check(contacts.size()==1,"Source contact tick hits a real target exactly once")
	await capture("sword")
	await advance(20);check(contacts.size()==1 and not combat.is_attacking(),"One click stops after the main cut")
	tap("light_attack")
	check(combat.combo==1 and combat.clip=="Ground__turning_cut" and p.is_on_floor(),"Second grounded click uses the distinct recovered turning cut without jumping")
	await advance(14);check(contacts.size()==1,"Turning cut waits for its own contact marker")
	await advance(2);check(contacts.size()==2,"Turning cut has exactly one independent contact")
	check(model.current_clip=="Ground__turning_cut","Second section plays its prepared motion instead of replaying or reversing the first slash")
	await capture("turning-cut");await advance(20)
	check(contacts.size()==2 and not combat.is_attacking(),"Two taps stop after two attacks")
	tap("light_attack")
	check(combat.combo==2 and combat.clip=="Ground__somersault_cut" and p.is_on_floor(),"Third grounded click starts the recovered somersault without a jump input")
	await advance(12);await capture("somersault-windup")
	await advance(4);check(contacts.size()==3 and p.is_on_floor(),"Somersault has one independent contact while the shared controller stays grounded")
	await capture("somersault-contact");await advance(14);await capture("somersault-recovery")
	await advance(90)
	check(contacts.size()==3 and not combat.is_attacking(),"Three clicks stop after three distinct attacks")
	tap("light_attack");check(combat.combo==0,"Expired combo restarts at the first section");combat.cancel()
	contacts.clear();tap("light_attack");await advance(6);tap("light_attack");await advance(30)
	check(combat.combo==1 and combat.is_attacking() and not combat.queued,"Buffered tap advances exactly one section")
	await advance(40);check(contacts.size()==2 and not combat.is_attacking(),"Buffered tap cannot repeat the whole animation")
	tap("light_attack");check(combat.combo==2,"Ground combo keeps its third section available after a buffered second cut")
	await advance(6);tap("light_attack");await advance(60)
	check(combat.combo==0 and contacts.size()==4 and not combat.is_attacking(),"A fourth deliberate click wraps the three-section combo once")
	combat.cancel();contacts.clear()
	var held=InputEventAction.new();held.action="light_attack";held.pressed=true;combat.input(held);await advance(75)
	check(contacts.size()==1 and not combat.is_attacking(),"Holding LMB alone does not repeat or advance the combo")
	held.pressed=false;combat.input(held);combat.cancel()
	for action in ["homing","wave","wind"]:
		fresh();await advance(12);launches.clear();release_data.clear();p.auto_attack_enabled=true;p.auto_lock_target=game.training_dummy;p.auto_lock_refresh=100;combat.start_skill(action);p.auto_attack_enabled=false
		check(is_equal_approx(p.attack_duration,float(combat.spec.ticks)/60),"Faster shared skill duration: "+action)
		await advance(14 if action!="wind" else 39)
		check(launches.count(action)==0,"Faster skill still waits for its release marker: "+action)
		await advance(2 if action!="wind" else 8)
		check(launches.count(action)==(3 if action=="homing" else 4 if action=="wind" else 1),"Original projectile count: "+action)
		var released=release_data.filter(func(item):return item.kind==action)
		for i in released.size():
			check(is_equal_approx(released[i].size,3.0*(float(combat.spec.scales[i]) if action=="wind" else 1.0)),"Spell retains its base size multiplier and launch growth: "+action)
			check(is_equal_approx(released[i].damage,96.0 if action=="homing" else 144.0),"Spell damage is tripled once: "+action)
			check(is_equal_approx(released[i].velocity.length(),(24 if action=="homing" else 32 if action=="wave" else 16)*30*model.source_unit()),"Phoenix is twice as fast; other spells retain speed: "+action)
		if action=="homing":
			for i in [0,2]:check(is_equal_approx(released[i].velocity.normalized().dot(released[1].velocity.normalized()),cos(PI/4)),"Three birds retain the ROM's 45-degree fan")
		await capture(action);await advance(230)
		check(not contacts.is_empty(),"Recovered "+action+" damages the shared target")
		var children=release_data.filter(func(item):return item.kind in ["spark","dust"])
		check(children.all(func(item):return is_equal_approx(item.size,3.0)),"All child effects are three times their original size: "+action)
	var homing=pool.launch(p,Shot,"homing",{"kind":"homing","position":ORIGIN+Vector3.UP*10000,"velocity":Vector3.RIGHT*20,"target":game.training_dummy,"unit":model.source_unit()})
	check((homing.visual.global_basis*Vector3(1,-1,0)).normalized().dot(homing.velocity.normalized())>.999,"White bird flies head-first along its launch direction")
	check(homing.effect_material.get_shader_parameter("atlas").resource_path.ends_with("homing.png"),"Small birds retain their original white artwork")
	for i in 10:
		homing._physics_process(1.0/60)
		check((homing.visual.global_basis*Vector3(1,-1,0)).normalized().dot(homing.velocity.normalized())>.999,"White bird turns head-first with steering in the same tick")
	check(homing.velocity.normalized().dot(Vector3.RIGHT)<.99 and is_equal_approx(homing.velocity.length(),20),"Homing still bends toward its target without changing speed")
	homing.retire()
	# Match the actual sprite's head axis, not the quad's surface normal.
	for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.RIGHT,Vector3.LEFT,Vector3(1,.7,-1).normalized(),Vector3.UP,Vector3.DOWN]:
		var bird=pool.launch(p,Shot,"wave",{"kind":"wave","position":ORIGIN+Vector3.UP*10,"velocity":direction*20,"unit":model.source_unit()})
		check((-bird.visual.global_basis.y.normalized()).dot(direction)>.999,"Phoenix flies head-first along flight: "+str(direction))
		check(absf(bird.visual.global_basis.x.normalized().y)<.001,"Phoenix wings stay level")
		check(absf(bird.visual.global_basis.z.normalized().dot(direction))<.001 and bird.visual.mesh.center_offset==Vector3.ZERO,"Phoenix lies centered in its flight plane")
		check(not bird.effect_material.get_shader_parameter("billboard") and not bird.effect_material.get_shader_parameter("directional_billboard"),"Camera cannot rotate the phoenix away from its physical heading")
		var base_scale=bird.unit*Shot.SPELL_SCALE
		for sample in [[0.0,.5,1.0],[.5,1.375,1.9375],[1.0,2.25,2.875],[1.5,3.125,3.8125],[2.0,4.0,4.0],[2.9,4.0,4.0]]:
			bird.age=sample[0];bird.update_visual()
			check(is_equal_approx(bird.visual.scale.x/base_scale,sample[1]),"Phoenix grows gradually to its existing maximum at age %.1f"%bird.age)
			check(is_equal_approx(bird.contact_scale/base_scale,sample[2]),"Phoenix preserves hit growth at age %.1f"%bird.age)
			check(is_equal_approx((-bird.visual.global_basis.y.normalized()).dot(bird.velocity.normalized()),cos(deg_to_rad(15)*minf(bird.age/2.0,1))),"Phoenix gradually lifts its head fifteen degrees over two seconds")
		bird.attack_ticket={"skill_size":2.0,"skill_hit_area":.5};bird.update_visual()
		check(is_equal_approx(bird.visual.scale.x,base_scale*8) and is_equal_approx(bird.contact_scale,base_scale*4),"Visual tuning remains independent of phoenix hit growth")
		bird.attack_ticket={};bird.restart_visual()
		check(is_equal_approx(bird.visual.scale.x,base_scale*.5),"Restart restores the small phoenix instead of its previous full size")
		var start=bird.global_position
		bird._physics_process(1.0/60)
		check(bird.global_position.is_equal_approx(start+direction*20/60+Vector3.UP/3600.0),"Phoenix begins a gentle upward curve without sideways drift")
		bird.retire()
	for delta in [1.0/20,1.0/30,1.0/60,.5]:
		var bird=pool.launch(p,Shot,"wave",{"kind":"wave","position":ORIGIN+Vector3.UP*10000,"velocity":Vector3.FORWARD*32*30*model.source_unit(),"unit":model.source_unit()})
		var start=bird.global_position;var initial_velocity=bird.velocity
		for i in roundi(2.0/delta):bird._physics_process(delta)
		check(bird.pool_live and bird.global_position.distance_to(start+initial_velocity*2+Vector3.UP*4)<.03,"Phoenix rises four metres in two seconds at delta %.4f"%delta)
		check(bird.velocity.distance_to(initial_velocity+Vector3.UP*4)<.001,"The upward curve preserves doubled forward speed")
		bird.retire()
	var camera_transform=game.camera_rig.camera.transform
	for direction in [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT]:
		fresh();await advance(12);release_data.clear()
		game.camera_rig.yaw=atan2(-direction.x,-direction.z)
		game.camera_rig.camera.position=p.position-direction*10+Vector3.UP*6
		game.camera_rig.camera.look_at(p.position+direction*15+Vector3.UP)
		combat.start_skill("wave");await advance(16)
		var released=release_data.filter(func(item):return item.kind=="wave")
		check(released.size()==1,"Aimed phoenix releases once before checking its trajectory")
		if released.is_empty():continue
		var launch=released[0]
		check(launch.velocity.normalized().dot(direction)>.999,"Phoenix uses actual player crosshair aim: "+str(direction))
		# Compare at release; the player's subsequent floor settling must not move the expected muzzle.
		check(launch.position.distance_to(launch.caster_position+Vector3.UP*1.3*preload("res://scripts/forest/dark_lumina_3_kit.gd").SCALE*p.growth_multiplier()+launch.velocity.normalized()*.9*p.contact_size_multiplier())<.001,"Phoenix matches Lumina's second-wave height and keeps its forward muzzle")
		await advance(12);await capture("phoenix-heading-%d"%int(game.camera_rig.yaw*100));await advance(228)
	game.camera_rig.camera.transform=camera_transform;game.camera_rig.yaw=0
	realtime=false
	var created=pool.created
	for kind in ["homing","wave","wind","spark","dust"]:
		for i in 50:
			var shot=pool.launch(p,Shot,kind,{"kind":kind,"target":game.training_dummy,"attack_ticket":{"sample":i}})
			if i==0:check(not shot.effect_material.get_shader_parameter("directional_billboard") and shot.effect_material.get_shader_parameter("billboard")== (kind not in ["wind","wave","homing"]),"Pooled effects retain their own flight presentation: "+kind)
			shot.hit_targets[123]=true;shot.age=5;shot.retire()
			shot=pool.launch(p,Shot,kind,{"kind":kind})
			check(shot.age==0 and shot.target==null and shot.hit_targets.is_empty() and shot.attack_ticket.is_empty(),"Lease resets "+kind)
			if kind=="wave" and i==0:check(is_equal_approx(shot.visual.rotation.x,-PI/2) and shot.velocity==Vector3.ZERO,"Reused phoenix clears its previous lift and raised-head pose")
			shot.retire()
	check(pool.created==created,"Repeated shots reuse prepared nodes without growth")
	var flight_nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var flight_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for volley in 3:
		var birds=[]
		for i in 12:
			var direction=Vector3.FORWARD.rotated(Vector3.UP,i*TAU/12)
			birds.append(pool.launch(p,Shot,"wave",{"kind":"wave","position":ORIGIN+Vector3.UP*10000,"velocity":direction*20,"unit":model.source_unit()}))
		for bird in birds:
			check(is_equal_approx(bird.visual.scale.x,bird.unit*Shot.SPELL_SCALE*.5),"Every reused simultaneous phoenix launches small")
			var start=bird.global_position;var velocity=bird.velocity
			for i in 12:bird._physics_process(1.0/60)
			check(bird.global_position.distance_to(start+velocity*.2+Vector3.UP*.04)<.01 and (-bird.visual.global_basis.y.normalized()).dot(bird.velocity.normalized())>cos(deg_to_rad(15))-.0001,"Simultaneous reused phoenixes retain independent rising flight")
			check(is_equal_approx(bird.visual.scale.x,bird.unit*Shot.SPELL_SCALE*.85),"Simultaneous phoenixes grow during real flight steps")
			bird.retire()
	check(pool.created==created,"Three volleys of twelve phoenixes retain the prepared pool")
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==flight_nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==flight_resources,"Repeated phoenix growth creates no nodes or resources")
	game.training_dummy.home=ORIGIN+Vector3(0,0,-100);game.training_dummy.position=game.training_dummy.home
	for action in ["homing","wave","wind"]:
		fresh();await advance(12)
		p.position=ORIGIN+Vector3.UP*10000 # Keep every shot clear of arena walls for its full lifetime.
		for i in 8:
			combat.start_skill(action);await advance(int(model.data().actions[action].ticks)+2)
		await advance(240)
		check(pool.created==created,"Back-to-back accelerated casts fit the prepared pool: "+action)
	print("KOJIRO_POOL_CAPACITY ",pool.all.keys().map(func(key):return [key,pool.all[key].size()]))
	game.training_dummy.home=ORIGIN+Vector3(0,0,-2);game.training_dummy.position=game.training_dummy.home
	for trail in [model.trail,model.blade_trail]:
		trail.clear()
		for i in 240:trail.advance(1.0/120,PackedVector3Array([Vector3(i*.01,0,0),Vector3(i*.01,1,0)]),true,false)
		check(trail.samples.size()<=17,"Each sword layer stays at source cadence on a 120 Hz display");trail.clear()
	# The ROM contact coordinates must reach native proxies without bypassing walls.
	fresh();await advance(12)
	var owner=game.army_runtime
	owner.set_navigation(9230,{"width":0});step_recoil=true
	var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3(0,0,-2));row.hp=1000;row.max_hp=1000
	owner.import_arrivals();owner.sync_targets()
	var actor=game.actors[row.id];var hp=actor.hp;recoil_handle=actor.handle
	mouse_click();await advance(6);mouse_click();await advance(60)
	print("KOJIRO_NATIVE_COMBO ",{"before":hp,"after":actor.hp,"floor":p.is_on_floor(),"mode":combat.mode,"combo":combat.combo,"position":p.position,"target":actor.global_position,"multiplier":p.damage_multiplier()})
	check(is_equal_approx(hp-actor.hp,72.0*(1.0+1.05)) and p.is_on_floor() and combat.combo==1,"Native opponent receives the main and turning cuts from two grounded mouse clicks")
	p.position=actor.position+Vector3(0,.1,2);p.velocity=Vector3.DOWN;await advance(2)
	hp=actor.hp;mouse_click();await advance(60)
	print("KOJIRO_NATIVE_LATER ",{"before":hp,"after":actor.hp,"floor":p.is_on_floor(),"combo":combat.combo})
	check(is_equal_approx(hp-actor.hp,72.0*1.1) and combat.combo==2 and p.is_on_floor(),"Third mouse click delivers the somersault's tripled damage and chain bonus without jumping")
	check(actor.position.z<ORIGIN.z-2,"Native recoil moves the target and the grounded follow-up still connects")
	step_recoil=false
	owner.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
	preload("res://tests/forest-shrine/training_dummy_fixture.gd").install(game)
	game.training_dummy.home=ORIGIN+Vector3(0,0,-9);game.training_dummy.position=game.training_dummy.home
	var wall=StaticBody3D.new();wall.collision_layer=1
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(18,12,.5)
	wall.add_child(shape);game.add_child(wall);wall.position=ORIGIN+Vector3(0,4,-4);await physics_frame
	for action in ["homing","wave","wind"]:
		fresh();await advance(12);combat.start_skill(action);await advance(300)
		check(contacts.is_empty(),"A wall blocks "+action+" damage")
	wall.queue_free();await physics_frame
	game.training_dummy.home=ORIGIN+Vector3(0,0,-2);game.training_dummy.position=game.training_dummy.home
	realtime=true # Physical jumps need actual physics frames after the bulk lease checks.
	fresh();await advance(12);tap("jump");await advance(8);tap("light_attack")
	print("STATE_TRACE hp=",p.hp," playing=",game.playing," paused=",game.paused," transitioning=",game.transitioning," position=",p.position," mode=",combat.mode," floor=",p.is_on_floor()," jumps=",p.jumps_used)
	check(combat.mode=="air_cut","Jump attack selects original aerial slash")
	await capture("air-cut");await advance(120)
	combat.start_skill("wind");p.select_character(1);check(not combat.is_attacking(),"Switching cancels pending wind releases")
	for action in ["homing","wave","wind"]:
		fresh();await advance(12);launches.clear();release_data.clear()
		check(p.spell_loadout.equip(1,"equip","kojiro/"+action),"Shared skill catalog equips "+action)
		tap("equip");await advance(150)
		check(launches.has(action) and p.character_id==1,"Goemon casts Kojiro’s "+action+" with his own character intact")
		check(release_data.any(func(item):return item.kind==action and is_equal_approx(item.size,3.0) and item.damage==(96.0 if action=="homing" else 144.0)*p.damage_multiplier()),"Borrowed skill keeps tripled base damage with the receiving fighter's multiplier: "+action)
		p.spell_loadout.cancel();await advance(180)
	p.spell_loadout.equip(1,"equip","");p.select_character(28);fresh();await advance(12)
	combat.start_skill("wind");combat.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not combat.is_attacking(),"Focus loss clears unreleased effects")
	tap("light_attack");tap("light_attack");combat.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not combat.queued and combat.combo_timer==0 and combat.combo==-1,"Focus loss clears buffered sections and combo progress")
	check(SoundLibrary.original_for(28,"kojiro_wind_voice")!=null and SoundLibrary.original_for(28,"death")!=null,"Original voices resolve through shared audio")
	check(game.sound_preview(28,"hit")==SoundLibrary.BLADE_IMPACTS.hit,"Kojiro contacts reuse the shared prepared sword impact")
	combat.hit();model.animate(0,0,true,0,0,false,0,false)
	check(model.current_clip==model.data().semantics.hurt,"Damage uses the recovered hurt motion")
	combat.die();check(model.current_clip==model.data().semantics.death,"Defeat holds the recovered source pose");combat.cancel()
	fresh();await advance(12)
	var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p)
	check(mirrors.cast(),"Five native-owned Kojiro allies can cast together")
	var mirror_shots=[]
	var record_mirror=func(shot):
		if shot.get_script()==Shot and shot.kind in ["wave","homing"] and shot.hero in mirrors.bodies:mirror_shots.append(shot)
	pool.launched.connect(record_mirror)
	for i in mirrors.bodies.size():
		var body=mirrors.bodies[i]
		body.ai_aim=body.global_position+Vector3.FORWARD.rotated(Vector3.UP,i*TAU/5)*40+Vector3.UP*1.5
		body.active_ability.start_skill("wave")
	for i in 30:
		owner.step(1.0/60,{"targets":[]});await advance(1)
	check(mirror_shots.size()==5,"Each simultaneous native ally releases one phoenix")
	for shot in mirror_shots:
		check((-shot.visual.global_basis.y.normalized()).dot(shot.velocity.normalized())>cos(deg_to_rad(15)*minf(shot.age/2.0,1))-.0001 and absf(shot.visual.global_basis.x.normalized().y)<.001,"Native ally phoenix rises head-first with level wings")
	await capture("phoenix-native-allies")
	mirror_shots.clear()
	for body in mirrors.bodies:
		body.active_ability.cancel();body.active_ability.start_skill("homing")
	for i in 30:
		owner.step(1.0/60,{"targets":[]});await advance(1)
	check(mirror_shots.size()==15,"Five simultaneous native allies each release three white birds")
	for shot in mirror_shots:
		check((shot.visual.global_basis*Vector3(1,-1,0)).normalized().dot(shot.velocity.normalized())>.999,"Native ally white bird steers head-first in its flight plane")
	await capture("homing-native-allies")
	pool.launched.disconnect(record_mirror);mirrors.dispose();await frames(2)
	var profiles=[]
	for id in [1,28]:
		p.select_character(id);fresh();await advance(60)
		var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
		var start=timings.size();await advance(120);var samples=timings.slice(start);samples.sort()
		profiles.append({"fighter":id,"cpu_p50_ms":samples[60],"cpu_p95_ms":samples[114],"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources})
	var picker=load("res://scripts/rogue_roster_picker.gd").new();picker.game=game;game.ui.add_child(picker)
	check(picker.find_child("RogueFighter_kojiro",true,false)!=null,"Kojiro has a selectable gallery card")
	picker.queue_free();await frames(2)
	await capture("gameplay")
	timings.sort();FileAccess.open(OUT+"gameplay-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"focus_losses":focus_losses,"pool_created":pool.created,"pool_misses":pool.misses,"scope":"One player and an isolated target; manually timed player and Kojiro projectile CPU steps, not an army stress test or total frame time.","cpu_p50_ms":timings[timings.size()/2],"cpu_p95_ms":timings[int(timings.size()*.95)],"idle_comparison":profiles},"  "))
	if not rendered_intervals.is_empty():
		rendered_intervals.sort()
		FileAccess.open(OUT+"rendered-intervals.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":rendered_intervals.size(),"median_ms":rendered_intervals[rendered_intervals.size()/2],"p95_ms":rendered_intervals[int(rendered_intervals.size()*.95)],"max_ms":rendered_intervals[-1],"scope":"Wall intervals between manual player/projectile steps awaiting rendered physics frames; isolated fixture, excludes PNG save pauses and bulk lifecycle tests."},"  "))
	game.queue_free();paused=false;await frames(3)
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("KOJIRO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
