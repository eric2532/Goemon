extends "res://tests/forest-shrine/illidan_shooter_test.gd"
const ROCK_OUT="res://build/Other Files/Asset Toolkit/Illidan Rock/"

func photo(name_:String):
	game.forest_ui.sync();await frames(2);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ROCK_OUT+name_+".png")==OK,"Rendered "+name_)

func run():
	if DisplayServer.get_name()=="headless":printerr("Rock review requires the desktop renderer");quit(1);return
	create_timer(180).timeout.connect(func():printerr("ILLIDAN_ROCK_TIMEOUT");quit(1))
	DirAccess.make_dir_recursive_absolute(ROCK_OUT)
	var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
	await setup_fixture(doc.data);game.tuning.invincible=true
	driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
	game.set_process_input(false);game.set_process_unhandled_input(false)
	var p=game.player;var rig=game.camera_rig;var pool=Pool.service(game)
	p.set_process_input(false);p.set_process_unhandled_input(false);rig.set_process_unhandled_input(false)
	p.select_character(32);fresh();p.position=ORIGIN+Vector3.UP*40;p.active_ability.demon=true
	rig.yaw=0;rig.pitch=.1;rig.reset_follow();rig.update_camera(1)
	var shots=[]
	pool.launched.connect(func(shot):
		if shot.get_script()==Shot:shot.set_physics_process(false);shots.append(shot))
	press("light_attack");press("light_attack",false);await step_shooter(12,true)
	check(shots.size()==1,"First-person cast launches one pooled meteor")
	var shot=shots[0]
	check(shot.rock.visible and shot.core_flames.emitting and shot.visual.visible and shot.particles[2].emitting,"Spinning core travels fully covered in purple flames")
	await photo("first-person-near")
	await step_shooter(12,true);await photo("first-person-travel")
	check(shot.damage==640 and is_equal_approx(shot.velocity.length(),28),"Core preserves existing meta damage and speed")
	shot.retire();rig.meta_viewmodel.hide();rig.meta_viewmodel.overlay.hide()
	shot=pool.launch(p,Shot,"demon",{"position":ORIGIN+Vector3(12,18,8)})
	rig.camera.position=shot.position+Vector3(7,4,11);rig.camera.look_at(shot.position)
	await step_shooter(1);rig.meta_viewmodel.hide();rig.meta_viewmodel.overlay.hide()
	rig.camera.position=shot.position+Vector3(7,4,11);rig.camera.look_at(shot.position)
	shot.rock.hide();shot.core_flames.hide();await photo("before-glow-only")
	shot.rock.show();shot.core_flames.show();await photo("after-rock-and-purple-fire")
	var first_rotation=shot.rock.quaternion
	shot._physics_process(.167);await photo("original-spin-quarter-turn")
	check(first_rotation.angle_to(shot.rock.quaternion)>1,"Native animation visibly turns the irregular rock")
	shot.explode(shot.position);await photo("impact")
	check(not shot.rock.visible and not shot.visual.visible,"Impact removes the solid core without a stale stone")
	shot.retire();shots.clear()
	for i in 24:pool.launch(p,Shot,"demon",{"position":ORIGIN+Vector3((i%6-2.5)*6,12+(i/6)*6,0)})
	rig.camera.position=ORIGIN+Vector3(35,35,55);rig.camera.look_at(ORIGIN+Vector3(0,20,0))
	var baseline=[Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),pool.created,pool.misses]
	var samples={}
	for enabled in [false,true]:
		for bolt in shots:bolt.rock.visible=enabled;bolt.core_flames.visible=enabled;bolt.age=0
		await frames(15)
		var elapsed=[];var work=[];var last=[Time.get_ticks_usec()]
		await driver.advance(90,func(dt):
			elapsed.append((Time.get_ticks_usec()-last[0])/1000.0);last[0]=Time.get_ticks_usec()
			var start=Time.get_ticks_usec()
			for bolt in shots:bolt._physics_process(dt)
			work.append((Time.get_ticks_usec()-start)/1000.0))
		elapsed.sort();work.sort()
		samples[str(enabled)]={"frame_p95_ms":elapsed[85],"frame_max_ms":elapsed[-1],"projectile_p95_ms":work[85]}
		await photo("24-cores-"+str(enabled))
	check(baseline==[Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),pool.created,pool.misses],"24 simultaneous spinning cores retain stable resources and warmed leases")
	check(shots.all(func(bolt):return bolt.rock.visible and bolt.rock.mesh==Shot.rock_mesh),"Every simultaneous bolt shares the original rock geometry")
	for bolt in shots:bolt.retire()
	var report={"checks":checks,"failures":failures,"rock_dimensions":str(Shot.rock_mesh.get_aabb().size),"samples":samples,"pool_misses":pool.misses}
	FileAccess.open(ROCK_OUT+"desktop.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ILLIDAN_ROCK_RESULT ",JSON.stringify(report))
	game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
