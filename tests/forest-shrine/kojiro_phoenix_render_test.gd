extends SceneTree
const Shot=preload("res://scripts/kojiro_projectile.gd")
var output="res://build/Other Files/Asset Toolkit/Kojiro/Phoenix Flight/"
var failures=0
var checks=0

func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",label_)

func run():
	var homing="--homing" in OS.get_cmdline_user_args()
	if homing:output="res://build/Other Files/Asset Toolkit/Kojiro/Homing Review/"
	if DisplayServer.get_name()=="headless":
		printerr("Bird shader checks require a rendered desktop run");quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var viewport=SubViewport.new();viewport.size=Vector2i(480,480);viewport.own_world_3d=true
	viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera=Camera3D.new();viewport.add_child(camera);camera.fov=63;camera.current=true
	if homing:camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=18
	var bird=Shot.new();bird.kind="homing" if homing else "wave";bird.unit=.04 if homing else .025;viewport.add_child(bird);bird.set_physics_process(false)
	var original=bird.effect_material.get_shader_parameter("atlas")
	# Marker pixels check the GPU transform; saved captures also show the real artwork.
	var marker=Image.create(80,64,false,Image.FORMAT_RGBA8);marker.fill(Color.TRANSPARENT)
	marker.fill_rect(Rect2i(30,4,20,16),Color.RED);marker.fill_rect(Rect2i(30,44,20,16),Color.BLUE)
	if homing:
		# ROM homing art has its beak at lower right and tail at upper left.
		marker=Image.create(32,32,false,Image.FORMAT_RGBA8);marker.fill(Color.TRANSPARENT)
		marker.fill_rect(Rect2i(22,22,8,8),Color.RED);marker.fill_rect(Rect2i(2,2,8,8),Color.BLUE)
	var marker_texture=ImageTexture.create_from_image(marker)
	var label="before" if "--before" in OS.get_cmdline_user_args() else "after"
	var results=[]
	var views=[Vector3(0,6,10),Vector3(10,6,0),Vector3(-8,6,-8)]
	if not homing:views.push_front(Vector3(.65,1.4,10))
	for view in views:
		camera.position=view;camera.look_at(Vector3.ZERO)
		for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT,Vector3(1,.7,-1).normalized(),Vector3.UP,Vector3.DOWN,-view.normalized()]:
			bird.velocity=direction*20;bird.restart_visual()
			if not homing:
				# Reproduce the previous camera-facing rotation for the before capture.
				if label=="before":
					bird.quaternion=Quaternion(Vector3.BACK,direction)
					bird.effect_material.set_shader_parameter("billboard",true)
					bird.effect_material.set_shader_parameter("directional_billboard",true)
				check(bird.visual.global_basis.z.normalized().dot(direction)>.999,"Phoenix faces its world flight direction")
				check(absf(bird.visual.global_basis.x.normalized().dot(Vector3.UP))<.001,"Phoenix wings stay level")
			bird.effect_material.set_shader_parameter("atlas",original);bird.effect_material.set_shader_parameter("frames",1 if homing else 8)
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(output+"%s-%02d.png"%[label,results.size()])
			bird.effect_material.set_shader_parameter("atlas",marker_texture);bird.effect_material.set_shader_parameter("frames",1)
			await RenderingServer.frame_post_draw
			var pixels=viewport.get_texture().get_image()
			var tip=Vector2.ZERO;var tail=Vector2.ZERO;var red=0;var blue=0
			for y in pixels.get_height():
				for x in pixels.get_width():
					var color=pixels.get_pixel(x,y)
					if color.r>.2 and color.b<.05:tip+=Vector2(x,y);red+=1
					if color.b>.2 and color.r<.05:tail+=Vector2(x,y);blue+=1
			var expected=camera.unproject_position(direction)-camera.unproject_position(Vector3.ZERO) if homing else camera.unproject_position(bird.visual.to_global(Vector3(0,52,0)))-camera.unproject_position(bird.visual.to_global(Vector3(0,12,0)))
			var alignment=-1.0
			if red>0 and blue>0:alignment=(tip/red-tail/blue).normalized().dot(expected.normalized())
			# Physical sprites can be edge-on; check visible markers against their world-plane projection.
			if homing or absf(bird.visual.global_basis.z.normalized().dot((camera.position-bird.position).normalized()))>.08:
				check(red>(100 if homing else 3) and blue>(100 if homing else 3),"Visible bird retains both orientation markers")
				if expected.length()>.01:check(alignment>.99 if homing else alignment>.98,"Rendered bird follows its intended orientation")
			results.append({"camera":str(view),"flight":str(direction),"red_pixels":red,"blue_pixels":blue,"alignment":alignment})
	if not homing:
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=28
		camera.position=Vector3(0,10,24);camera.look_at(Vector3(0,10,0))
		bird.velocity=Vector3.FORWARD*20;bird.restart_visual()
		bird.effect_material.set_shader_parameter("atlas",original);bird.effect_material.set_shader_parameter("frames",8)
		for age in [0.0,.5,1.0,1.5,2.0,2.9]:
			bird.age=age;bird.update_visual()
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(output+label+"-growth-%.1f.png"%age)
	FileAccess.open(output+label+"-render.json",FileAccess.WRITE).store_string(JSON.stringify({"kind":bird.kind,"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"views":results},"  "))
	viewport.queue_free();await process_frame;await process_frame
	print("PHOENIX_RENDER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
