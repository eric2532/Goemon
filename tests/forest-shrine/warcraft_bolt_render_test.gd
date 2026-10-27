extends SceneTree
const Shot=preload("res://scripts/warcraft_projectile.gd")
const OUT="res://build/Other Files/Asset Toolkit/Illidan Meta Attack/"
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	print("PASS: " if ok else "FAIL: ",label_)
	if not ok:failures+=1
func capture(view:SubViewport,name_:String)->Image:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var image=view.get_texture().get_image();image.save_png(OUT+name_+".png");return image
func corner_difference(a:Image,b:Image)->float:
	var error=0.0
	for p in [Vector2i(54,54),Vector2i(201,54),Vector2i(54,201),Vector2i(201,201)]:
		var delta=a.get_pixelv(p)-b.get_pixelv(p)
		error=maxf(error,maxf(absf(delta.r),maxf(absf(delta.g),absf(delta.b))))
	return error
func run():
	if DisplayServer.get_name()=="headless":printerr("This regression needs a desktop renderer");quit(1);return
	DirAccess.make_dir_recursive_absolute(OUT)
	var view=SubViewport.new();view.size=Vector2i(256,256);view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var world=WorldEnvironment.new();var env=Environment.new();world.environment=env;view.add_child(world)
	env.background_mode=Environment.BG_COLOR;env.background_color=Color(.04,.06,.08)
	env.fog_enabled=true;env.fog_density=.025;env.fog_light_color=Color(.5,.65,.8);env.fog_sky_affect=0
	var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=12;camera.position.z=20;view.add_child(camera)
	var shot=Shot.new();view.add_child(shot);shot.set_physics_process(false)
	# Keep the corner probes at the same texture UV when the bolt grows.
	camera.size=shot.visual.texture.get_width()*shot.visual.pixel_size/.64
	var material:StandardMaterial3D=shot.visual.material_override
	shot.hide();var background=await capture(view,"background")
	shot.show();var current=await capture(view,"bolt-current")
	var current_error=corner_difference(current,background)
	check(material.disable_fog,"Bolt preserves Warcraft's Unfogged material flag")
	check(current_error<.02,"Bolt corners stay transparent in fog: %.6f"%current_error)
	check(current.get_pixel(128,128).b>background.get_pixel(128,128).b+.1,"Purple core remains visible")
	material.disable_fog=false;var old=await capture(view,"bolt-with-fog")
	var old_error=corner_difference(old,background)
	check(old_error>.1,"Regression reproduces the old fog-filled square: %.6f"%old_error)
	material.disable_fog=true;var corrected=await capture(view,"bolt-unfogged")
	check(corner_difference(corrected,background)<.02,"Native unfogged rendering removes the square")
	FileAccess.open(OUT+"render.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"current_corner_delta":current_error,"fogged_corner_delta":old_error},"  "))
	print("WARCRAFT_BOLT_RENDER_RESULT failures=",failures)
	view.queue_free();await process_frame;quit(1 if failures else 0)
