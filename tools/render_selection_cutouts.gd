extends SceneTree
## Rebuild the three formerly opaque portraits from their actual runtime models.
## Transparent viewports preserve dark costume details without color-key removal.
const Roster=preload("res://scripts/rogue_roster.gd")
func _initialize():run.call_deferred()
func run():
	assert(DisplayServer.get_name()!="headless","Portraits require the native renderer")
	for id in [12,14,15]:await render_portrait(id)
	print("SELECTION_CUTOUTS_RENDERED count=3");quit()
func render_portrait(id:int):
	var view=SubViewport.new();view.size=Vector2i(800,500) if id==12 else Vector2i(512,640)
	view.transparent_bg=true;view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_4X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var env=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(0,0,0,0)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("d5dfef");env.environment.ambient_light_energy=.65
	view.add_child(env)
	for point in [Vector3(-4,6,5),Vector3(4,3,2)]:
		var light=DirectionalLight3D.new();view.add_child(light);light.position=point
		light.look_at(Vector3(0,1.5,0));light.light_energy=1.0
	var camera=Camera3D.new();view.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true
	var model:Node3D
	if id==12:
		model=load("res://assets/rogue/scripts/actor.gd").new();view.add_child(model)
		model.setup("master-thief");model.seed=0;model.animate_pose({"grounded":true},0,0,0)
		camera.size=4.6;camera.position=Vector3(7,2,10);camera.look_at(Vector3(0,1.85,0))
	else:
		model=load("res://scripts/recovered_leader_model.gd").new();model.character_id=id;view.add_child(model)
		model.scale=Vector3.ONE*(.375 if id==15 else 1.0)
		model.animate(.1,0,true,0,0,false,0,false)
		camera.keep_aspect=Camera3D.KEEP_WIDTH;camera.size=4.8
		camera.position=Vector3(-2,2,-7);camera.look_at(Vector3.UP*1.6)
		if id==15:
			var offset=-camera.basis.x*.15-Vector3.UP*.16
			camera.position+=offset;camera.look_at(Vector3.UP*1.6+offset)
	for i in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var image=view.get_texture().get_image()
	assert(image.get_pixel(0,0).a==0,"Native render must preserve transparency")
	assert(image.save_png(Roster.selection_portrait_path(id))==OK,"Cannot save selection portrait")
	view.queue_free()
	for i in range(4):await process_frame
