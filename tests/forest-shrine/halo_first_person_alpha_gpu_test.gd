extends SceneTree
## Run with a real rendering backend, not --headless (the dummy GPU cannot read pixels).
const Data=preload("res://scripts/halo_effect_data.gd")
const Particles=preload("res://scripts/halo_effect_particles.gd")
const OUTPUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/halo-native-effects"
var checks:int=0
var failures:int=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	print("PASS: " if ok else "FAIL: ",label_)
	if not ok:failures+=1
func image_counts(image:Image)->Dictionary:
	var visible:int=0
	var opaque_black:int=0
	for y:int in image.get_height():
		for x:int in image.get_width():
			var color:Color=image.get_pixel(x,y)
			var brightness:float=maxf(color.r,maxf(color.g,color.b))
			if brightness>.1 and color.a>.01:visible+=1
			if brightness<.0001 and color.a>.01:opaque_black+=1
	return {"visible":visible,"opaque_black":opaque_black}
func frames():
	for i:int in 4:await process_frame
	await RenderingServer.frame_post_draw
func run():
	root.size=Vector2i(320,320)
	var view:SubViewport=SubViewport.new()
	view.size=Vector2i(256,256);view.transparent_bg=true;view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.msaa_3d=Viewport.MSAA_2X
	root.add_child(view)
	var camera:Camera3D=Camera3D.new();camera.fov=78;camera.near=.025;camera.far=5;view.add_child(camera)
	var environment:WorldEnvironment=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;view.add_child(environment)
	var renderer=Particles.new();view.add_child(renderer)
	var data=Data.new();renderer.configure(data,camera)
	var native:Dictionary=data.resolve("effects\\particles\\flash\\flash h ar","particle")
	for first_person:bool in [false,true]:
		renderer.clear();seed(421)
		renderer.emit_particle(native,Transform3D(Basis.IDENTITY,Vector3(0,0,-1)),1,{"radius":.25,"first_person":first_person,"frame_rate":0})
		renderer.tick(0)
		await frames()
		var image:Image=view.get_texture().get_image()
		var counts:Dictionary=image_counts(image)
		var label_:String="first-person" if first_person else "world-control"
		image.save_png(OUTPUT+"/alpha-"+label_+".png")
		print(label_," GPU pixels ",counts)
		check(counts.visible>5,label_+" original muzzle flash remains visible")
		if first_person:check(counts.opaque_black==0,"Transparent weapon viewport has no opaque black atlas background pixels")
		else:check(counts.opaque_black>100,"World additive material remains unchanged as a regression control")
	view.queue_free();await process_frame
	print("HALO_FIRST_PERSON_ALPHA_GPU_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
