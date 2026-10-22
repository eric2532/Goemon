extends SceneTree
## Render the actual Goemon and Edo gameplay rigs using the imported stride.
var models: Array[Node3D]=[]
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1050,600)
	var stage=Node3D.new();root.add_child(stage)
	var environment=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("344251")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.7;stage.add_child(environment)
	var light=DirectionalLight3D.new();stage.add_child(light);light.rotation_degrees=Vector3(-45,-40,0);light.light_energy=1.4;light.shadow_enabled=true
	var ground=StaticBody3D.new();stage.add_child(ground)
	var collision=CollisionShape3D.new();collision.shape=BoxShape3D.new();collision.shape.size=Vector3(100,.2,100);collision.position.y=-.1;ground.add_child(collision)
	var floor_mesh=MeshInstance3D.new();floor_mesh.mesh=PlaneMesh.new();floor_mesh.mesh.size=Vector2(100,100)
	var material=StandardMaterial3D.new();material.albedo_color=Color("60717e");floor_mesh.material_override=material;stage.add_child(floor_mesh)
	for edo in [false,true]:
		var model=MusashiModel.new() if edo else HeroModel.new();stage.add_child(model);model.set_process(false)
		model.position.z=1.65 if edo else -1.65
		models.append(model);model.locomotion_velocity=Vector3.FORWARD*10.2
		for i in range(180):model.animate(1.0/120,10.2,true,0,0,false,0,false);model.sync_skeleton()
	var camera=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.2
	camera.position=Vector3(-9,2.6,0);camera.look_at(Vector3(0,1.35,0))
	var row=HBoxContainer.new();row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);root.add_child(row)
	for text_ in ["GOEMON — YOUR RUN","EDO — YOUR RUN"]:
		var label=Label.new();label.text=text_;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.add_theme_font_size_override("font_size",24);row.add_child(label)
	var out="res://docs/run-pose-practice/game-preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await physics_frame
	for frame in range(30):
		for i in range(2):
			var motion=models[i].locomotion;motion.dt=0
			motion.phase=float(frame)/30*(TAU if i==1 else 1.0);motion.dirty=true;models[i].sync_skeleton()
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("%03d.png"%frame))
	await create_timer(.3).timeout
	print("USER_STRIDE_TOUR frames=30 output=",out)
	quit()
