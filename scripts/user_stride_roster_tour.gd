extends SceneTree
const Actor=preload("res://assets/rogue/scripts/actor.gd")
const Shared=preload("res://scripts/user_stride_run.gd")
const IDS=["goemon","edo","pirate","ninja","mage","dragoon","ranger","explorer","master-thief","magic-swordsman","knight","samurai"]
var models=[]
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1200,900)
	root.content_scale_size=Vector2i(1200,900)
	var stage=Node3D.new();root.add_child(stage)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("344251");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;stage.add_child(env)
	var light=DirectionalLight3D.new();stage.add_child(light);light.rotation_degrees=Vector3(-45,-30,0);light.light_energy=1.3
	var grid=GridContainer.new();grid.columns=4;grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);grid.add_theme_constant_override("h_separation",0);grid.add_theme_constant_override("v_separation",0);root.add_child(grid)
	for i in range(IDS.size()):
		var id=IDS[i]
		var model: Node3D=HeroModel.new() if id=="goemon" else MusashiModel.new() if id=="edo" else Actor.new()
		stage.add_child(model);model.set_process(false)
		if i>=2:model.setup(id);model.rotation.y=PI;model.seed=0
		for visual in model.find_children("*","VisualInstance3D",true,false):visual.layers=1<<i
		model.position.x=i*10.0;models.append(model)
		for warm in range(120):
			if i<2:
				model.locomotion_velocity=Vector3.FORWARD*10.2;model.animate(1.0/60,10.2,true,0,0,false,0,false);model.sync_skeleton()
			else:model.animate_pose({"grounded":true,"motionSpeed":10.2,"localMotion":Vector3.BACK*10.2},1.0/60,warm/60.0,1)
		var panel=SubViewportContainer.new();panel.stretch=true;panel.custom_minimum_size=Vector2(300,300);grid.add_child(panel)
		var view=SubViewport.new();view.size=Vector2i(300,300);view.world_3d=stage.get_world_3d();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.msaa_3d=Viewport.MSAA_2X;panel.add_child(view)
		var camera=Camera3D.new();view.add_child(camera);camera.cull_mask=1<<i;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.1;camera.position=model.position+Vector3(-7,2.2,1.0);camera.look_at(model.position+Vector3(0,1.45,0))
		var label=Label.new();label.text=id.to_upper()+ (" — SHARED" if Shared.enabled(id) else " — OWN RUN");label.position=Vector2(8,8);label.add_theme_font_size_override("font_size",15);panel.add_child(label)
	var out="res://docs/run-pose-practice/roster-preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for frame in range(20):
		for i in range(models.size()):
			var model=models[i];var motion=model.locomotion
			var phase_=float(frame)/30.0*(1.5 if Shared.enabled(IDS[i]) else 1.85)
			motion.phase=fposmod(phase_,1.0)*(1.0 if i==0 else TAU)
			if i<2:motion.dt=0;motion.dirty=true;model.sync_skeleton()
			else:model.animate_pose({"grounded":true,"motionSpeed":10.2,"localMotion":Vector3.BACK*10.2},0,frame/30.0,1)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("%03d.png"%frame))
	await create_timer(.2).timeout
	print("USER_STRIDE_ROSTER_TOUR frames=20 output=",out);quit()
