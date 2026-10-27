extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Warcraft/Melee/"
const Kit=preload("res://scripts/warcraft_kit.gd")
const Effects=preload("res://scripts/warcraft_effects.gd")
func advance(count:int):
	for i in count:
		game.player._physics_process(1.0/60)
		if DisplayServer.get_name()!="headless":
			await physics_frame
		elif i%30==0:await process_frame

func photo(label_:String):
	if DisplayServer.get_name()=="headless":return
	game.forest_ui.sync();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label_+".png")

func target(point:Vector3):
	game.training_dummy.home=ORIGIN+point;game.training_dummy.position=game.training_dummy.home

func run():
	create_timer(180).timeout.connect(func():printerr("WARCRAFT_MELEE_TIMEOUT");quit(1))
	DirAccess.make_dir_recursive_absolute(OUT)
	await setup_fixture();game.tuning.invincible=true
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.player.set_process_input(false);game.player.set_process_unhandled_input(false)
	game.camera_rig.set_process_input(false);game.camera_rig.set_process_unhandled_input(false)
	var p=game.player;var report={}
	game.camera_rig.camera.position=ORIGIN+Vector3(24,20,36);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,7,0))
	check(Kit.profile().primary.all(func(a):return is_equal_approx(a.reach,3.6)),"Native primary profile shares the modest reach increase")
	for id in [31,32]:
		p.select_character(id);fresh();await advance(4)
		var model=p.model;var c=p.active_ability
		check(model.blade_trails.size()==(1 if id==31 else 2),"Prepared trail for every weapon %d"%id)
		for blade in model.blade_trails:
			check(blade.bone>=0 and blade.trail.get_script()==preload("res://scripts/recovered_leader_trail.gd"),"Reuses Kojiro's ribbon on an original weapon bone")
			check(blade.trail.light_color==Effects.energy_color(id),"Blade keeps its character energy color")
			var nearest=INF
			for node in model.meshes:
				var arrays=node.mesh.surface_get_arrays(0)
				for v in arrays[Mesh.ARRAY_VERTEX].size():
					var bind=int(arrays[Mesh.ARRAY_BONES][v*4]);var bone=node.skin.get_bind_bone(bind)
					if bone<0:bone=model.skeleton.find_bone(node.skin.get_bind_name(bind))
					if bone==blade.bone and arrays[Mesh.ARRAY_WEIGHTS][v*4]>.999:
						nearest=minf(nearest,(node.skin.get_bind_pose(bind)*arrays[Mesh.ARRAY_VERTEX][v]).distance_to(blade.tip))
			check(nearest<.001,"Ribbon tip matches the original skinned blade geometry")
		for combo in (3 if id==31 else 2):
			fresh();target(Vector3(0,0,-4.05));c.combo=combo-1;c.combo_timer=.85
			c.start_attack();c.tick((c.contact-.01)/p.attack_speed_multiplier())
			check(contacts.is_empty(),"Reach preserves windup %d/%d"%[id,combo])
			c.tick(.02/p.attack_speed_multiplier())
			check(contacts.size()==1,"Regular cut reaches the newly reachable target %d/%d"%[id,combo])
			c.tick(2);check(contacts.size()==1,"Cut delivers only one hit %d/%d"%[id,combo])
		for point in [Vector3(0,0,-4.5),Vector3(0,0,3)]:
			fresh();target(point);c.start_attack();c.tick(2)
			check(contacts.is_empty(),"Reach still rejects distant/behind targets %d/%s"%[id,point])
		fresh();target(Vector3(0,0,-4.05))
		var wall=StaticBody3D.new();wall.collision_layer=1
		var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(10,8,.2)
		wall.add_child(shape);game.add_child(wall);wall.position=ORIGIN+Vector3(0,3,-2)
		await physics_frame;await physics_frame;c.start_attack();c.tick(2)
		check(contacts.is_empty(),"Extended melee still respects solid cover %d"%id);wall.free()
		fresh();target(Vector3(0,0,-80))
		for combo in (3 if id==31 else 2):
			c.combo=combo-1;c.combo_timer=.85;c.start_attack()
			await advance(ceili((c.contact+.1)/p.base_attack_speed_multiplier()*60))
			check(model.blade_trails.all(func(b):return b.trail.mesh!=null),"Cut draws each attached blade ribbon %d/%d"%[id,combo])
			await photo("%d-cut-%d"%[id,combo])
			c.cancel();check(model.blade_trails.all(func(b):return b.trail.samples.is_empty() and b.trail.mesh==null),"Cancellation immediately clears all ribbons")
		c.start_attack();await advance(70)
		check(model.blade_trails.all(func(b):return b.trail.mesh==null),"Finished cut fades completely")
		if id==32:
			c.demon=true;c.start_attack();await advance(8)
			check(model.blade_trails.all(func(b):return b.trail.samples.is_empty()),"Metamorphosis bolt does not draw a melee ribbon");c.cancel()
		# Five actual native leases reuse the same selected character models and cuts.
		if id==32:p.spell_loadout.equip(id,"sky_strike","blademaster/mirror-image")
		var mirrors=c.mirrors if id==31 else p.spell_loadout.instances["32:blademaster/mirror-image"].controller.mirrors
		check(mirrors.cast() and mirrors.handles.size()==5,"Five native-backed copies prepared %d"%id)
		var bodies=[p]+mirrors.bodies
		for i in bodies.size():
			var body=bodies[i];body.active_ability.cancel();body.position=ORIGIN+Vector3((i%3-1)*17,0,-(i/3)*20)
			body.facing=Vector3.FORWARD;body.ai_aim=body.position+Vector3.FORWARD*50
		game.camera_rig.camera.position=ORIGIN+Vector3(34,36,58);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,6,-10))
		var node_count=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		var resource_count=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
		var profiles={}
		for enabled in [false,true]:
			var work=[];var frame_times=[]
			for body in bodies:
				for blade in body.model.blade_trails:blade.trail.layers=1 if enabled else 0
			for cycle in 6:
				for body in bodies:body.active_ability.start_attack()
				for frame in 32:
					var start=Time.get_ticks_usec()
					for body in bodies:
						body.active_ability.tick(1.0/60);body.model.animate(1.0/60,0,true,0,0,false,0,false)
					work.append((Time.get_ticks_usec()-start)/1000.0)
					if cycle==1 and frame==7 and enabled:
						check(bodies.all(func(b):return b.model.blade_trails.all(func(t):return t.trail.mesh!=null)),"All six fighters draw simultaneous cuts %d"%id)
						await photo("%d-six-cuts"%id)
					if DisplayServer.get_name()!="headless":
						await physics_frame
						if not (cycle==1 and frame==7 and enabled):frame_times.append((Time.get_ticks_usec()-start)/1000.0)
				for body in bodies:body.active_ability.cancel()
			work.sort();frame_times.sort()
			profiles[str(enabled)]={"step_p95_ms":work[int(work.size()*.95)],"step_max_ms":work[-1],"frame_p95_ms":frame_times[int(frame_times.size()*.95)] if not frame_times.is_empty() else null,"frame_max_ms":frame_times[-1] if not frame_times.is_empty() else null}
		check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==node_count,"Repeated simultaneous cuts retain no nodes %d"%id)
		check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resource_count,"Repeated simultaneous cuts retain no resources %d"%id)
		mirrors.clear()
		check(mirrors.bodies.all(func(b):return b.model.blade_trails.all(func(t):return t.trail.mesh==null)),"Retired copies retain no blade trails")
		report[str(id)]=profiles
		p.select_character(1)
		check(model.blade_trails.all(func(b):return b.trail.mesh==null),"Character selection clears blade presentation")
		game.camera_rig.camera.position=ORIGIN+Vector3(24,20,36);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,7,0))
	report.checks=checks;report.failures=failures
	FileAccess.open(OUT+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WARCRAFT_MELEE_RESULT ",JSON.stringify(report))
	game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
