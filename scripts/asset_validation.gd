extends Node
var game: Node
var failures=0
func check(value: bool,message: String):
	if value: print("ASSET PASS: ",message)
	else:
		failures+=1
		push_error("ASSET FAIL: "+message)
func frame():
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
func shot(view: Viewport,name: String):
	await frame()
	view.get_texture().get_image().save_png("res://tests/blender-"+name+".png")
func run():
	game.start_game()
	game.tuning.freeze_ai=true
	game.player.smoke_mode=true
	game.hud.banner_time=0
	game.hud.toast_time=0
	await get_tree().create_timer(1.5).timeout
	check(game.player.model.skeleton.get_bone_count()==22,"Hero has twenty-two articulated skeleton bones")
	check(game.player.model.hair_normal is MeshInstance3D and game.player.model.hair_gold is MeshInstance3D,"Both imported hair variants are independently switchable")
	var gold_mesh=game.player.model.hair_gold as MeshInstance3D
	check(gold_mesh.mesh.get_faces().size()==190*3,"R hair uses the supplied 190-triangle Sudden Impact geometry")
	check(gold_mesh.mesh.get_aabb().size.y>game.player.model.hair_normal.mesh.get_aabb().size.y,"Supplied gold hair has its distinct taller silhouette")
	var animation=game.player.model.rig_visual.find_child("AnimationPlayer",true,false) as AnimationPlayer
	check(animation!=null and animation.get_animation_list().size()>=24,"Core editable Blender skeletal actions import into Godot")
	print("IMPORTED_ACTIONS ",animation.get_animation_list() if animation else [])
	await shot(get_viewport(),"gameplay")
	var view=SubViewport.new()
	view.size=Vector2i(800,800)
	view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	view.msaa_3d=Viewport.MSAA_4X
	add_child(view)
	var studio=Node3D.new()
	view.add_child(studio)
	var environment=WorldEnvironment.new()
	var env=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("283e50")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color.WHITE
	env.ambient_light_energy=0.6
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.environment=env
	studio.add_child(environment)
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-35,0)
	sun.light_energy=1.3
	studio.add_child(sun)
	var fill=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-20,140,0)
	fill.light_energy=0.65
	studio.add_child(fill)
	var camera=Camera3D.new()
	camera.fov=37
	studio.add_child(camera)
	camera.current=true
	var model=HeroModel.new()
	studio.add_child(model)
	model.animate(0,0,true,0,0,false,0,false)
	# Imported source T pose, using the same camera as the Blender comparison.
	model.locomotion.reference_pose=true
	model.locomotion.dirty=true
	model.arms[0].rotation=Vector3(0,0,-PI/2)
	model.arms[1].rotation=Vector3(0,0,PI/2)
	model.head.rotation=Vector3.ZERO
	model.pipe.hide()
	view.size=Vector2i(480,416)
	camera.fov=rad_to_deg(2*atan((36.0*416.0/480.0)/(2*70.0)))
	camera.position=Vector3(3.5,2.15,-7.4)
	camera.look_at(Vector3(0,1.65,0))
	await shot(view,"reference-import-tpose")
	model.locomotion.reference_pose=false
	model.locomotion.dirty=true
	check(model.locomotion.bones.has("Hand_R"),"Pipe follows articulated hand bone")
	model.animate(0,0,true,0,0,false,0,false)
	view.size=Vector2i(800,800)
	camera.fov=37
	var angles={"front":0.0,"back":PI,"left":PI/2,"right":-PI/2,"three-quarter":PI/4}
	for golden in [false,true]:
		model.set_surge(golden)
		for label in angles:
			var a=angles[label]
			camera.position=Vector3(sin(a)*6.8,2.8,-cos(a)*6.8)
			camera.look_at(Vector3(0,1.8,0))
			await shot(view,("gold-" if golden else "hero-")+label)
	model.queue_free()
	await frame()
	var coin=GoldCoin.make_mesh(studio,3)
	coin.position.y=1.8
	camera.position=Vector3(1.5,2.4,-6.0)
	camera.look_at(Vector3(0,1.8,0))
	await shot(view,"koban")
	coin.queue_free()
	await frame()
	for variant in range(-1,4):
		var enemy=HeroModel.new(true,variant>=0,maxi(0,variant))
		studio.add_child(enemy)
		camera.position=Vector3(3.8,2.8,-6)
		camera.look_at(Vector3(0,1.8,0))
		await shot(view,"enemy-"+str(variant))
		enemy.queue_free()
		await frame()
	for asset in ["environments/cherry_tree","environments/green_tree","environments/palm","environments/moss_rock","props/paper_lantern","architecture/torii","architecture/temple_roof","weapons/golden_pipe"]:
		var prop=GameAssets.place(studio,asset)
		var small=asset in ["environments/moss_rock","props/paper_lantern","weapons/golden_pipe"]
		var target=Vector3(0,0,0) if small else Vector3(0,2.7,0)
		for reverse in [false,true]:
			camera.position=target+Vector3(2,1.4,-3)*(1 if small else 6.5)*(-1 if reverse else 1)
			if reverse: camera.position.y=target.y+(1.4 if small else 7)
			camera.look_at(target)
			await shot(view,asset.get_file()+("-rear" if reverse else "-detail"))
		prop.queue_free()
		await frame()
	view.queue_free()
	game.player.activate_surge()
	await get_tree().create_timer(0.5).timeout
	await shot(get_viewport(),"surge-gameplay")
	for e in game.enemies:
		if is_instance_valid(e): e.set_physics_process(false)
	# Actual posing and attachment under controller-driven attack states.
	game.player.start_attack(false)
	await get_tree().create_timer(0.18).timeout
	await shot(get_viewport(),"attack")
	game.player.attack_left=0
	game.player.select_weapon(2)
	game.player.primary_down=true
	game.player.charge_elapsed=1.1
	await get_tree().create_timer(0.05).timeout
	await shot(get_viewport(),"charged-coin")
	game.player.cancel_charge()
	print("ASSET_VALIDATION_RESULT failures=",failures," FPS=",Engine.get_frames_per_second()," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	game.quit_clean()
