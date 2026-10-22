extends SceneTree
## Render the same ROM face and hat used by the live workforce.
func _initialize():
	root.set_flag(Window.FLAG_NO_FOCUS,true);run.call_deferred()
func run():
	var viewport=SubViewport.new();viewport.size=Vector2i(256,256);viewport.transparent_bg=true
	viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var stage=Node3D.new();viewport.add_child(stage)
	var worker=preload("res://scripts/forest/forest_worker_rom.gd").new();stage.add_child(worker);worker.setup();worker.pickaxe.hide()
	var environment=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.TRANSPARENT
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.9;stage.add_child(environment)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-28,-25,0);sun.light_energy=1.1;stage.add_child(sun)
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.8
	stage.add_child(camera);camera.position=Vector3(.65,3.3,6);camera.look_at(Vector3(0,2.05,0));camera.current=true
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	var path="res://assets/ui/forest/worker_goemon.png";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var result=viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("WORKER_PORTRAIT_RESULT error=",result)
	viewport.queue_free();for i in 3:await process_frame
	quit(0 if result==OK else 1)
