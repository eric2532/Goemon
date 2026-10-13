extends SceneTree
var failures=0
func check(ok: bool,message: String):
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func run():
	check(ResourceLoader.exists("res://scripts/forest/forest_world.gd"),"The playable forest world exists")
	if failures:finish();return
	var m=load("res://scripts/forest/forest_model.gd").new();m.reset(42)
	var world=load("res://scripts/forest/forest_world.gd").new();world.model=m;root.add_child(world)
	await process_frame
	check(world.playable_bounds.size==Vector2(336,336),"Allied play space leaves a hidden perimeter inside the 480m forest")
	check(world.structure_nodes.has(1),"The shrine exists in the real battlefield")
	var gate=m.build("gate",Vector2i(0,5),0);world.sync(0)
	check(world.structure_nodes.has(gate.id),"A model purchase appears at its real 3D position")
	check(world.structure_nodes[gate.id].position==m.center(gate),"Grid placement and battle geometry coincide")
	var colliders=world.structure_nodes[gate.id].find_children("*","StaticBody3D",true,false)
	check(colliders.size()>0,"A gate owns real collision")
	check(colliders.any(func(b):return b.collision_layer==32),"Gate passage blocks enemies without blocking friendly actors")
	check(world.worker_nodes.size()==6,"All six workers have visible battlefield models")
	world.queue_free();await process_frame;finish()
func finish():print("FOREST_WORLD_RESULT failures=%d"%failures);quit(1 if failures else 0)
