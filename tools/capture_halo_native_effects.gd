extends SceneTree
const OUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/halo-native-effects"
var fx
func _initialize():run.call_deferred()
func frames(n:int):
	for i in n:await process_frame
func snap(label_:String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"/"+label_+".png")
func run():
	await frames(2)
	if is_instance_valid(current_scene):current_scene.queue_free();await frames(3)
	root.size=Vector2i(1280,800)
	var scene=Node3D.new();root.add_child(scene);current_scene=scene
	var env=WorldEnvironment.new();var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color(.12,.17,.22);environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color(.7,.75,.85);environment.ambient_light_energy=.7;env.environment=environment;scene.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-30,0);scene.add_child(sun)
	var floor_=StaticBody3D.new();floor_.set_meta("halo_material","stone");scene.add_child(floor_)
	var mesh=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(150,.5,150);mesh.mesh=box;floor_.add_child(mesh);floor_.position.y=-.25
	var mat=StandardMaterial3D.new();mat.albedo_color=Color(.4,.42,.39);mesh.material_override=mat
	var shape=CollisionShape3D.new();var bs=BoxShape3D.new();bs.size=box.size;shape.shape=bs;floor_.add_child(shape)
	var camera=Camera3D.new();scene.add_child(camera);camera.position=Vector3(0,13,33);camera.look_at(Vector3(0,4,0));camera.current=true
	fx=load("res://scripts/halo_weapon_effects.gd").new();scene.add_child(fx);fx.set_process(false)
	await frames(3)
	fx.explosion(Vector3(0,.03,0),Vector3.UP,"stone",3)
	for stage in [{"t":.05,"name":"explosion-005"},{"t":.25,"name":"explosion-025"},{"t":.6,"name":"explosion-060"},{"t":1.3,"name":"explosion-130"},{"t":3.0,"name":"explosion-300"}]:
		while fx._clock<float(stage.t):fx.advance(1.0/120)
		await frames(3);await snap(stage.name)
	fx.clear();camera.position=Vector3(0,3.5,6);camera.look_at(Vector3(0,1,0))
	var gun=Transform3D(Basis.IDENTITY,Vector3(0,1.5,0));var eject=Transform3D(Basis(Vector3.UP,-PI/2),Vector3(.2,1.5,0))
	for slot in [2,3,4]:
		fx.fire_ejection(slot,gun,eject)
		for i in 90:fx.advance(1.0/120)
		await frames(3);await snap("casings-%d"%slot)
		fx.clear()
	fx.rocket_start(0,Vector3(-8,3,0),Vector3.RIGHT)
	for i in 90:
		var at=Vector3(-8+float(i)*.16,3,0);fx.rocket_move(0,at,Vector3.RIGHT,1.0/60);fx.advance(1.0/60)
	camera.position=Vector3(0,8,22);camera.look_at(Vector3(0,3,0));await frames(3);await snap("rocket-exhaust")
	fx.clear();camera.position=Vector3(0,5,15);camera.look_at(Vector3(0,1,0))
	for material in ["stone","wood","dirt","human_skin","ice"]:
		var x=float(["stone","wood","dirt","human_skin","ice"].find(material))*3-6
		fx.fire_world(2,Vector3(x,2,8),Vector3(x,.03,0),{"impact":true,"normal":Vector3.UP,"material":material},true)
	fx.advance(.03);await frames(3);await snap("material-impacts-early")
	fx.advance(.17);await frames(3);await snap("material-impacts-smoke")
	fx.clear();scene.queue_free();await frames(3);print("HALO_NATIVE_CAPTURE_COMPLETE");quit()
