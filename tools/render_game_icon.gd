extends SceneTree
## Offline icon render from the playable Goemon head; no authored assets change.
func _initialize():run.call_deferred()

func run():
	assert(DisplayServer.get_name()!="headless","Game icon requires the native renderer")
	var launcher="--launcher" in OS.get_cmdline_user_args()
	var name_="Play Goemon" if launcher else "Goemon"
	var destination="res://build/Other Files/Game Icon/Play Goemon" if launcher else "res://icon"
	var view=SubViewport.new();view.size=Vector2i(1024,1024)
	view.transparent_bg=true;view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_4X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var environment=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0,0,0,0)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("d5dfef");environment.environment.ambient_light_energy=.65
	view.add_child(environment)
	var model=preload("res://scripts/recovered_goemon_model.gd").new();view.add_child(model)
	model.set_process(false);model.apply_native_pose(0,0)
	var head=model.native_parts[RecoveredGoemonBody.HEAD_POINTER]
	for part in model.native_parts.values():part.visible=part==head
	model.pipe.hide();model.coin.hide();model.chain_pipe.hide()
	var points:Array[Vector3]=[];model._mesh_points(head,Transform3D.IDENTITY,points)
	assert(not points.is_empty(),"Goemon head must contain geometry")
	var bounds=AABB(model.rig_visual.global_transform*points[0],Vector3.ZERO)
	for point in points:bounds=bounds.expand(model.rig_visual.global_transform*point)
	var center=bounds.get_center()
	for position in [Vector3(-4,6,-6),Vector3(4,3,-4)]:
		var light=DirectionalLight3D.new();view.add_child(light)
		light.position=center+position;light.look_at(center);light.light_energy=.9
	var camera=Camera3D.new();view.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true
	camera.size=maxf(bounds.size.x,bounds.size.y)*1.12
	camera.position=center+(Vector3(-3.8,.7,-6) if launcher else Vector3(.25,.08,-6));camera.look_at(center)
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	var icon=view.get_texture().get_image()
	assert(icon.get_pixel(0,0).a==0 and icon.get_pixel(512,512).a>.9,"Icon must show Goemon on transparency")
	assert(icon.save_png(destination+".png")==OK,"Cannot save game icon")
	var iconset=ProjectSettings.globalize_path("res://build/Other Files/Game Icon/"+name_+".iconset")
	assert(DirAccess.make_dir_recursive_absolute(iconset)==OK,"Cannot create native icon staging folder")
	for size in [16,32,128,256,512]:
		for density in [1,2]:
			var scaled=icon.duplicate();scaled.resize(size*density,size*density,Image.INTERPOLATE_LANCZOS)
			assert(scaled.save_png(iconset.path_join("icon_%dx%d%s.png"%[size,size,"@2x" if density==2 else ""]))==OK,"Cannot save native icon size")
	var output=[]
	assert(OS.execute("/usr/bin/iconutil",["-c","icns",iconset,"-o",ProjectSettings.globalize_path(destination+".icns")],output,true)==0,"Cannot package macOS icon: "+str(output))
	view.queue_free();await process_frame;await process_frame
	print("GAME_ICON_RENDERED size=1024 source=playable_goemon_head destination=",destination);quit()
