extends SceneTree
const Art=preload("res://scripts/forest/forest_art.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const Pose=preload("res://scripts/recovered_goemon_pose.gd")
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func meshes(n:Node)->Array:
	var out=[]
	for c in n.get_children():
		if c is MeshInstance3D:out.append(c)
		out.append_array(meshes(c))
	return out
func run():
	var worker=Art.worker(1);root.add_child(worker)
	var other=Art.worker(2);root.add_child(other)
	var body=worker.get_node("GoemonBody")
	check(body.get_meta("rom_base","")=="assets/blender/characters/rom_goemon_base/worker.blend","Worker uses the fitted ROM Blender body")
	check(body.find_children("*","Skeleton3D",true,false).is_empty() and body.find_children("*","AnimationPlayer",true,false).is_empty(),"Workers stay lightweight without per-worker skeletons")
	if body.has_method("update_worker"):
		check(body.parts.size()==13,"Worker retains all thirteen original separate parts")
		check(meshes(body)[0].mesh==meshes(other.get_node("GoemonBody"))[0].mesh,"Workers share source meshes")
		for state_ in ["idle","move","mine","repair","garrison","wounded"]:
			Art.animate_worker(worker,{"id":1,"state":state_},.3)
			check(body.source_action==(15 if state_=="move" else 104 if state_ in ["mine","repair"] else 0),"State selects original motion: "+state_)
			check(body.pickaxe.visible==(state_ not in ["garrison","wounded"]),"Job tool visibility: "+state_)
			if state_=="garrison":
				check((worker.get_node("Bow").position+Profile.BOW_LOCAL_GRIP).distance_to(body.pickaxe.position)<.001,"Garrison bow grip meets the raised weapon hand")
				check(Profile.TOWER_MUZZLE_OFFSET.distance_to(body.pickaxe.position)<.001,"Tower targeting and arrows originate at the held bow")
			if state_ in ["idle","move","mine","repair"]:
				var native:Dictionary=body.source_pose()
				var expected:Transform3D=native.get("0x9002518",native["0x9005868"]*body.rom_grip)
				check(body.pickaxe.transform.origin.distance_to(expected.origin*body.source_scale+body.source_offset)<.001,"Pickaxe sits at Goemon's native pipe grip: "+state_)
				check((body.pickaxe.basis*Vector3.UP).normalized().dot((expected.basis*Vector3.FORWARD*-1).normalized())>.999,"Pickaxe follows native pipe direction: "+state_)
		Art.animate_worker(worker,{"id":1,"state":"mine"},.1);var old=body.pickaxe.transform
		Art.animate_worker(worker,{"id":1,"state":"mine"},.3)
		check(not body.pickaxe.transform.is_equal_approx(old),"Mining moves the pickaxe through a real swing")
		for p in body.parts.values():check(p.transform.is_finite(),"Rigid part transform remains finite")
	var model=Model.new();model.reset(42)
	var wall=model._make_building("wall",Vector2i(18,18),0)
	check(is_equal_approx(wall.max_hp,7500),"Full wall has five times its former 1500 health")
	var short=model._make_building("wall",Vector2i(18,20),0,2)
	check(is_equal_approx(short.max_hp,2500),"Short wall keeps proportional durability")
	model.phase="wave";model.damage_building(wall.id,1500)
	check(model.buildings.has(wall.id) and is_equal_approx(wall.hp,6000),"Former lethal damage no longer breaks the wall")
	model.damage_building(wall.id,6000)
	check(not model.buildings.has(wall.id),"Stronger walls remain destructible")
	for rotation in range(4):
		var visual=Art.building({"kind":"wall","id":-1,"rotation":rotation});root.add_child(visual)
		var shapes=visual.find_children("*","CollisionShape3D",true,false)
		check(shapes[0].shape.size.z>=5.6 and shapes[0].shape.size.z<=Model.CELL,"Thicker wall collision stays in its occupied row")
		check(is_equal_approx(meshes(visual)[0].mesh.size.z,5.6),"Visible wall has double depth")
		visual.free()
	var gate=Art.building({"kind":"gate","id":-2,"rotation":0});root.add_child(gate)
	check(gate.get_node("GateDoor").get_child_count()==0,"Gate door has no cross emblem")
	check(Model.HP.gate==2000,"Gate matches the stronger fortification durability")
	gate.free();worker.free();other.free()
	print("WORKER_ROM_FORTIFICATION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
