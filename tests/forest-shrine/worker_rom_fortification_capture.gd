extends SceneTree
const Art=preload("res://scripts/forest/forest_art.gd")
var out="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Worker ROM and Fortifications"
var camera:Camera3D
var stage:Node3D
func _initialize():run.call_deferred()
func frames(n:int=6):
	for i in n:await process_frame
func shot(label_:String,point:Vector3,look:Vector3):
	camera.position=point;camera.look_at(look);await frames();await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(out.path_join(label_+".png"))==OK)
func run():
	if DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1280,900)
	stage=Node3D.new();root.add_child(stage)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("3e4e58");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("c3d9c7");env.environment.ambient_light_energy=.65;stage.add_child(env)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.4;sun.shadow_enabled=true;stage.add_child(sun)
	Geo.box(stage,Vector3(0,-.1,0),Vector3(160,.2,90),Geo.mat("77866b"))
	camera=Camera3D.new();camera.current=true;camera.fov=43;stage.add_child(camera)
	var worker=Art.worker(1);stage.add_child(worker)
	for state_ in ["idle","move","mine","repair","garrison"]:
		Art.animate_worker(worker,{"id":1,"state":state_},.3);worker.get_node("Bow").visible=state_=="garrison"
		await shot("worker-"+state_,Vector3(4.3,2.8,6.0),Vector3(0,1.7,0))
	Art.animate_worker(worker,{"id":1,"state":"idle"},.3)
	await shot("worker-side",Vector3(6,2.5,0),Vector3(0,1.7,0))
	await shot("worker-back",Vector3(3.5,2.5,-6),Vector3(0,1.7,0))
	worker.position=Vector3(1,0,6)
	for x in [-24,24]:
		var wall=Art.building({"kind":"wall","id":int(x),"rotation":0});stage.add_child(wall);wall.position.x=x
	var gate=Art.building({"kind":"gate","id":100,"rotation":0});stage.add_child(gate)
	await shot("thick-walls-plain-gate",Vector3(57,29,54),Vector3(0,7,0))
	await shot("plain-gate-front",Vector3(17,13,36),Vector3(0,8,0))
	stage.free();await frames(2);print("WORKER_FORTIFICATION_CAPTURE_RESULT captures=9");quit()
