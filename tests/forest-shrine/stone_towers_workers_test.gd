extends SceneTree
const Art=preload("res://scripts/forest/forest_art.gd")
const World=preload("res://scripts/forest/forest_world.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func meshes(node:Node)->Array:
	var result=[]
	for child in node.get_children():
		if child is MeshInstance3D:result.append(child)
		result.append_array(meshes(child))
	return result
func run():
	var tower=Art.building({"kind":"tower","id":1,"rotation":0});root.add_child(tower)
	var base_ray=PhysicsRayQueryParameters3D.create(Vector3(0,4,-7),Vector3(0,4,7),1)
	await physics_frame
	check(not tower.get_world_3d().direct_space_state.intersect_ray(base_ray).is_empty(),"Stone tower has a solid masonry body below its deck")
	var lookout_ray=PhysicsRayQueryParameters3D.create(Vector3(0,30,-4),Vector3(0,20,-4),1)
	var lookout=tower.get_world_3d().direct_space_state.intersect_ray(lookout_ray)
	check(not lookout.is_empty() and is_equal_approx(lookout.position.y,25.0),"Stone lookout rises to a reachable 25m landing")
	var deck=tower.get_node("TowerDeck").get_child(0)
	check(deck.shape.size==Vector3(11,.5,11) and is_equal_approx(deck.position.y,19.75),"Tower deck supports workers at 20m above the 16m walls")
	var stone_meshes=meshes(tower).filter(func(part):return part.material_override is ShaderMaterial and part.material_override.shader==Fort.SHADER)
	check(stone_meshes.size()>=10,"Tower keep and crenellations use the same stone material as the fort")
	var model=Model.new();model.reset(42)
	while model.workers.size()<24 and model.workforce.recruit(true):pass
	var world=World.new();world.model=model;root.add_child(world);await process_frame
	var workers=world.worker_nodes.values()
	check(workers.size()>=24,"All starting workers use the replacement visual")
	var a:Node3D=workers[0];var body=a.get_node_or_null("GoemonBody")
	check(body!=null,"Workers wear the original Goemon body")
	if body!=null:
		check(body.get_meta("source_model","")=="res://assets/characters/recovered_goemon/body/body.json" and body.get_meta("rom_base","")=="assets/blender/characters/rom_goemon_base/worker.blend","Worker body is derived from the approved ROM Blender source")
		check(body.find_children("*","Skeleton3D",true,false).is_empty() and body.find_children("*","AnimationPlayer",true,false).is_empty(),"Workers have no live skeletons or animation players")
		var other=workers[1].get_node_or_null("GoemonBody")
		check(other!=null and meshes(body)[0].mesh==meshes(other)[0].mesh,"Workers share baked source meshes instead of duplicating rig resources")
		check(meshes(body).size()>=5,"Goemon torso and limbs remain segmented for job animation")
	var pickaxe=a.find_child("Pickaxe",true,false)
	check(pickaxe!=null,"Worker carries a small pickaxe")
	check(a.get_node_or_null("WorkerHead")==null and body.parts["0x90050f8"].get_node_or_null("normal")!=null,"Worker preserves the original ROM face and spiky hair")
	var hat_bounds:AABB=body.hat_rest*body.hat.mesh.get_aabb()
	check(hat_bounds.position.y>2.7 and hat_bounds.end.y>3.25,"Straw worker hat sits on Goemon hair")
	var worker:Dictionary=model.workers.values()[0]
	worker.state="mine";worker.cargo=1;worker.follow=true;world.age=0.0;world.sync(.1)
	var start=body.pickaxe.transform;world.sync(.2)
	check(body.pickaxe.transform!=start,"Mining swings the Goemon arm and attached pickaxe")
	check(a.get_node("Cargo").visible and a.get_node("Selected").visible,"Cargo and selection visuals follow their existing state")
	worker.state="garrison";world.sync(.1)
	check(a.get_node("Bow").visible and is_equal_approx(a.position.y,20.0),"Garrison retains the bow on the raised occupied tower deck")
	if pickaxe!=null:check(not pickaxe.is_visible_in_tree(),"Garrison archers stow the mining pickaxe")
	worker.state="wounded";world.sync(.1)
	check(is_equal_approx(a.rotation.z,PI*.5),"Wounded workers retain their readable fallen pose")
	world.queue_free();tower.queue_free();await process_frame
	print("STONE_TOWERS_WORKERS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
