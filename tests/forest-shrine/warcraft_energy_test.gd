extends "res://tests/forest-shrine/warcraft_characters_test.gd"
const Effects=preload("res://scripts/warcraft_effects.gd")
const EVIDENCE="res://build/Other Files/Asset Toolkit/Illidan Bolt Size/"

func photo(label_:String):
	if DisplayServer.get_name()=="headless":return
	game.forest_ui.sync();await frames(2);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(EVIDENCE+label_+".png")==OK,"Rendered "+label_)

func run():
	create_timer(120).timeout.connect(func():printerr("WARCRAFT_ENERGY_TIMEOUT");quit(1))
	DirAccess.make_dir_recursive_absolute(EVIDENCE)
	var image=Image.create(2,1,false,Image.FORMAT_RGBA8);image.fill(Color(.1,.8,.3,.4))
	image.generate_mipmaps()
	var original=ImageTexture.create_from_image(image);var bytes=original.get_image().get_data()
	var neutral=Effects.energy_texture(original);var pixel=neutral.get_image().get_pixel(0,0)
	check(is_equal_approx(pixel.r,pixel.g) and is_equal_approx(pixel.g,pixel.b) and absf(pixel.r-.8)<.005 and absf(pixel.a-.4)<.005,"Recoloring preserves native intensity and alpha")
	check(original.get_image().get_data()==bytes,"Shared original texture remains untouched")
	var neutral_bytes=neutral.get_image().get_data()
	check(neutral_bytes.size()==bytes.size() and neutral_bytes[8]==neutral_bytes[9] and neutral_bytes[9]==neutral_bytes[10],"Distant mip levels retain the neutral glow color")
	check(Effects.energy_texture(original)==neutral,"Repeated energy setup reuses the prepared texture")
	await setup_fixture();game.tuning.invincible=true
	game.set_process_input(false);game.set_process_unhandled_input(false)
	game.camera_rig.set_process_input(false);game.camera_rig.set_process_unhandled_input(false)
	var p=game.player;var pool=Pool.service(game)
	pool.launched.connect(func(shot):
		if shot.get_script()==Shot:shot.set_physics_process(false))
	game.camera_rig.camera.position=ORIGIN+Vector3(24,17,42);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,6,-5))
	for id in [31,32]:
		p.select_character(id);fresh();await advance(3)
		var model=p.model;model.pose("Stand",.2)
		for i in model.meshes.size():
			var mesh=model.meshes[i];var material=mesh.material_override
			var source=mesh.mesh.surface_get_material(0)
			if int(model.motion.meshes[i].mode) in [3,4]:
				var expected=Effects.energy_color(id);expected.a=material.albedo_color.a
				check(material.albedo_color.is_equal_approx(expected),"Native aura has the requested hue %d/%d"%[id,i])
				check(material.albedo_texture!=source.albedo_texture,"Native aura uses an owned hue-neutral copy")
			else:
				check(material.albedo_texture==source.albedo_texture,"Body, clothing and smoke keep native textures %d/%d"%[id,i])
				if int(model.motion.meshes[i].mode)==1:
					check(material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS,"Cutout skin writes depth before hair/wing blending %d/%d"%[id,i])
				else:
					check(material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"Blended surfaces preserve embedded alternate-form glows %d/%d"%[id,i])
		await photo("aura-%d"%id)
		for emitter in p.active_ability.effects.emitters.values():
			for color in emitter.color_ramp.colors:
				check(color.r>color.g and (color.r>color.b if id==31 else color.b>color.r),"Original skill particles use the character energy hue")
		if id==32:
			model.rotation.y=0;model.body.rotation=Vector3.ZERO
			for angle in [0,45,90]:
				var center=ORIGIN+Vector3(0,13,0)
				game.camera_rig.camera.position=center+Vector3(sin(deg_to_rad(angle))*13,1,-cos(deg_to_rad(angle))*13)
				game.camera_rig.camera.look_at(center);model.pose("Stand",.2)
				await photo("illidan-face-%d"%angle)
			check(is_equal_approx(model.meshes[1].material_override.albedo_color.a,.8),"Original translucent wings retain their authored opacity")
			game.camera_rig.camera.position=ORIGIN+Vector3(0,14,-13);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,13,0))
			model.pose("Stand Alternate",.2);await photo("illidan-meta-face")
			game.camera_rig.camera.position=ORIGIN+Vector3(24,17,42);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,6,-5))
			model.pose("Attack Alternate",.27)
			check(not model.live_particles.is_empty(),"Native transformed attack particles remain active")
			for i in model.live_particles:
				var color:Color=model.particles[i].modulate
				check(color.b>color.r and color.r>color.g,"Native transformed attack energy is purple")
			await photo("illidan-meta-energy")
	# Exercise a real ranged attack, then the same prepared pool under simultaneous use.
	p.active_ability.demon=true;game.training_dummy.home=ORIGIN+Vector3(0,0,-80);game.training_dummy.position=game.training_dummy.home
	tap("light_attack");await advance(12)
	var live_shots=[]
	for nodes in pool.all.values():
		for shot in nodes:
			if shot.pool_live and shot.get_script()==Shot:live_shots.append(shot)
	check(live_shots.size()==1,"A transformed attack launches one prepared bolt")
	if live_shots.size()==1:
		var shot=live_shots[0];var size=shot.visual.pixel_size
		check(is_equal_approx(size,.24*1.5),"Metamorphosis bolt is 50 percent wider and taller than the prior visual")
		check(shot.velocity.length()>27.9 and shot.damage==640,"Meta bolt retains speed and applies the tenfold form damage")
		check(shot.visual.material_override.blend_mode==BaseMaterial3D.BLEND_MODE_ADD,"Enlarged native glow has no opaque black rectangle")
		# Isolate the size comparison from the giant model and nearby wall.
		shot.position=ORIGIN+Vector3(16,5,12);shot.reset_physics_interpolation()
		game.camera_rig.camera.position=shot.global_position+Vector3(9,6,4)
		game.camera_rig.camera.look_at(shot.global_position)
		shot.visual.pixel_size=.24;await photo("bolt-small")
		shot.visual.pixel_size=size;await photo("bolt-large")
		shot.retire()
	var created=pool.created;var misses=pool.misses;var cached=Effects.energy_textures.size()
	var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for cycle in 5:
		var shots=[]
		for i in 12:shots.append(pool.launch(p,Shot,"demon",{"position":ORIGIN+Vector3(i-6,2,-10),"velocity":Vector3.FORWARD*28}))
		check(shots.all(func(shot):return is_equal_approx(shot.visual.pixel_size,.36) and shot.visual.modulate.b>shot.visual.modulate.r and shot.visual.modulate.r>shot.visual.modulate.g),"Simultaneous reused bolts retain the enlarged purple presentation")
		for shot in shots:shot.retire()
	check(pool.created==created and pool.misses==misses,"Simultaneous bolts do not grow the warmed pool")
	check(Effects.energy_textures.size()==cached,"Repeated casts do not create new texture copies")
	check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated casts keep resource count stable")
	if DisplayServer.get_name()!="headless":
		# Same scene and twelve prepared sprites isolate the extra fill cost of the larger art.
		var shots=[];var samples={}
		for i in 12:shots.append(pool.launch(p,Shot,"demon",{"position":ORIGIN+Vector3((i%4-1.5)*7,4+(i/4)*4,-12)}))
		game.camera_rig.camera.position=ORIGIN+Vector3(24,20,42);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,8,-12))
		for size in [.24,.36]:
			for shot in shots:shot.visual.pixel_size=size
			await frames(30)
			var intervals_=[];var last=Time.get_ticks_usec()
			for i in 120:
				await process_frame
				var now=Time.get_ticks_usec();intervals_.append((now-last)/1000.0);last=now
			intervals_.sort();samples[str(size)]={"frame_p95_ms":intervals_[114],"frame_max_ms":intervals_[-1]}
			await photo("twelve-bolts-"+str(size))
		for shot in shots:shot.retire()
		FileAccess.open(EVIDENCE+"bolt-size-profile.json",FileAccess.WRITE).store_string(JSON.stringify(samples,"  "))
	print("WARCRAFT_ENERGY_RESULT checks=%d failures=%d cache=%d pool_misses=%d"%[checks,failures,cached,pool.misses])
	game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
