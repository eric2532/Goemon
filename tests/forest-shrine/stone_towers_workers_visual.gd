extends SceneTree
const Art=preload("res://scripts/forest/forest_art.gd")
const World=preload("res://scripts/forest/forest_world.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const Document=preload("res://scripts/forest/forest_map_document.gd")
var stage:Node3D
var camera:Camera3D
var folder="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/tall-towers-capes-20261019"
func _initialize():run.call_deferred()
func frames(count:int):
	for i in count:await process_frame
func capture(label_:String,point:Vector3,look:Vector3):
	camera.position=point;camera.look_at(look);await frames(8);await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder+"/"+label_+".png")==OK)
func run():
	if DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,900)
	stage=Node3D.new();root.add_child(stage)
	var environment_=WorldEnvironment.new();var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("738e8b");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_energy=.65;env.ambient_light_color=Color("c3d9c7");environment_.environment=env;stage.add_child(environment_)
	var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-35,0);sun.light_color=Color("ffe2b5");sun.light_energy=1.5;sun.shadow_enabled=true;stage.add_child(sun)
	Geo.box(stage,Vector3(0,-.2,0),Vector3(80,.4,80),Geo.mat("839956"))
	camera=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=45
	var tower=Art.building({"kind":"tower","id":1,"rotation":0});stage.add_child(tower)
	var guard=Art.worker(3);stage.add_child(guard);guard.position=Vector3(0,20,0);guard.get_node("Bow").show();Art.animate_worker(guard,{"id":3,"state":"garrison"},.5)
	await capture("stone-tower",Vector3(26,30,32),Vector3(0,12,0))
	for state_ in ["idle","move","mine","repair"]:
		var worker=Art.worker(1);stage.add_child(worker);worker.position=Vector3(-9,0,8)
		Art.animate_worker(worker,{"id":1,"state":state_},.5)
		if state_=="move":worker.get_node("Cargo").show();worker.get_node("Selected").show()
		await capture("worker-"+state_,worker.position+Vector3(3.8,2.8,5.5),worker.position+Vector3(0,1.7,0))
		worker.queue_free();await frames(1)
	stage.queue_free();await frames(2)
	var doc=Document.new();doc.load_four_gates();var model=Model.new();model.reset(42,{},doc.data)
	var world=World.new();world.model=model;world.painterly_preview_enabled=true;root.add_child(world)
	camera=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=50
	await capture("settlement",Vector3(70,78,105),Vector3(0,9,2))
	world.queue_free();await frames(2)
	print("STONE_TOWERS_WORKERS_VISUAL_RESULT captures=6");quit()
