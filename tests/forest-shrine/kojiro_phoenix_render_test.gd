extends SceneTree
const Shot=preload("res://scripts/kojiro_projectile.gd")
var output="res://build/Other Files/Asset Toolkit/Kojiro/Phoenix Rise/Phoenix/"
var failures=0
var checks=0

func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",label_)

func run():
	var homing="--homing" in OS.get_cmdline_user_args()
	if homing:output="res://build/Other Files/Asset Toolkit/Kojiro/Phoenix Rise/Homing/"
	if DisplayServer.get_name()=="headless":
		printerr("Bird shader checks require a rendered desktop run");quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var viewport=SubViewport.new();viewport.size=Vector2i(480,480);viewport.own_world_3d=true
	viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera=Camera3D.new();viewport.add_child(camera);camera.fov=63;camera.current=true
	if homing:camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=18
	var bird=Shot.new();bird.kind="homing" if homing else "wave";bird.unit=.04 if homing else .025;viewport.add_child(bird);bird.set_physics_process(false)
	bird.effect_material=bird.effect_material.duplicate();bird.visual.material_override=bird.effect_material
	var original=bird.effect_material.get_shader_parameter("atlas")
	# Marker pixels check the GPU transform; saved captures also show the real artwork.
	var marker=Image.create(80,64,false,Image.FORMAT_RGBA8);marker.fill(Color.TRANSPARENT)
	# The approved phoenix flies head-first toward image -Y; the upper plume trails.
	marker.fill_rect(Rect2i(30,44,20,16),Color.RED);marker.fill_rect(Rect2i(30,4,20,16),Color.BLUE)
	if homing:
		# ROM homing art has its beak at lower right and tail at upper left.
		marker=Image.create(32,32,false,Image.FORMAT_RGBA8);marker.fill(Color.TRANSPARENT)
		marker.fill_rect(Rect2i(22,22,8,8),Color.RED);marker.fill_rect(Rect2i(2,2,8,8),Color.BLUE)
	var marker_texture=ImageTexture.create_from_image(marker)
	var label="before" if "--before" in OS.get_cmdline_user_args() else "after"
	var results=[]
	var views=[Vector3(.65,1.4,10),Vector3(0,6,10),Vector3(10,6,0),Vector3(-8,6,-8)]
	for view in views:
		camera.position=view;camera.look_at(Vector3.ZERO)
		for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT,Vector3(1,.7,-1).normalized(),Vector3.UP,Vector3.DOWN,-view.normalized()]:
			bird.velocity=direction*20;bird.restart_visual()
			if label=="before":
				bird.visual.basis=Basis.IDENTITY
				if homing:
					bird.quaternion=Quaternion(Vector3.BACK,direction)
					bird.effect_material.set_shader_parameter("billboard",true)
					bird.effect_material.set_shader_parameter("directional_billboard",true)
					bird.effect_material.set_shader_parameter("sprite_forward",Vector2(1,-1).normalized())
				else:
					var upright=bird.visual.mesh.duplicate();upright.center_offset.y=32;bird.visual.mesh=upright
			var nose=bird.visual.global_basis*(Vector3(1,-1,0) if homing else Vector3.DOWN)
			var wing=bird.visual.global_basis*(Vector3(1,1,0) if homing else Vector3.RIGHT)
			check(nose.normalized().dot(direction)>.999,"Bird flies head-first along world velocity")
			check(absf(wing.normalized().dot(Vector3.UP))<.001,"Bird wings stay level across travel")
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
			var expected=camera.unproject_position(direction)-camera.unproject_position(Vector3.ZERO)
			var alignment=-1.0
			if red>0 and blue>0:alignment=(tip/red-tail/blue).normalized().dot(expected.normalized())
			# Physical sprites can be edge-on; check visible markers against their world-plane projection.
			if absf(bird.visual.global_basis.z.normalized().dot((camera.position-bird.position).normalized()))>.08:
				check(red>3 and blue>3,"Visible bird retains both orientation markers")
				if expected.length()>.01:check(alignment>.99 if homing else alignment>.98,"Rendered bird follows its intended orientation")
			results.append({"camera":str(view),"flight":str(direction),"red_pixels":red,"blue_pixels":blue,"alignment":alignment})
	if not homing:
		camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=28
		camera.position=Vector3(10,18,20);camera.look_at(Vector3.ZERO)
		bird.velocity=Vector3.FORWARD*20;bird.restart_visual()
		bird.effect_material.set_shader_parameter("atlas",original);bird.effect_material.set_shader_parameter("frames",8)
		for age in [0.0,.5,1.0,1.5,2.0,2.9]:
			bird.age=age;bird.update_visual()
			check(is_equal_approx((-bird.visual.global_basis.y.normalized()).dot(bird.velocity.normalized()),cos(deg_to_rad(15)*minf(age/2.0,1))),"Rendered phoenix pose gradually lifts its head fifteen degrees")
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(output+label+"-growth-%.1f.png"%age)
	FileAccess.open(output+label+"-render.json",FileAccess.WRITE).store_string(JSON.stringify({"kind":bird.kind,"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"views":results},"  "))
	viewport.queue_free();await process_frame;await process_frame
	print("PHOENIX_RENDER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
