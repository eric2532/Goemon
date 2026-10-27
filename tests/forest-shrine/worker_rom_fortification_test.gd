extends SceneTree
const Art=preload("res://scripts/forest/forest_art.gd")
const Model=preload("res://tests/forest-shrine/reference/forest_model.gd")
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
	var body=worker.get_node("WorkerBody")
	check(body.get_meta("source_model","").ends_with("peasant/peasant.glb"),"Worker uses the exact Human Peasant source")
	check(body.find_children("*","Skeleton3D",true,false).is_empty() and body.find_children("*","AnimationPlayer",true,false).is_empty(),"Workers stay lightweight without per-worker skeletons")
	check(body.multimesh.mesh==other.get_node("WorkerBody").multimesh.mesh,"Workers share their prepared skin")
	for state_ in ["idle","move","mine","repair","garrison","wounded"]:
		Art.animate_worker(worker,{"id":1,"state":state_},.3)
		check(body.clip==({"move":"walk"}.get(state_,state_)),"Worker state selects the prepared native motion: "+state_)
		check(is_finite(body.row),"Pose row remains finite")
		if state_=="garrison":check((worker.get_node("Bow").position+Profile.BOW_LOCAL_GRIP).distance_to(Profile.TOWER_MUZZLE_OFFSET)<.001,"Tower targeting and arrows share the native bow grip")
	Art.animate_worker(worker,{"id":1,"state":"mine"},.1);var old=body.row
	Art.animate_worker(worker,{"id":1,"state":"mine"},.3)
	check(body.row!=old,"Mining advances the original motion")
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
	check(Model.HP.gate==2500,"Gate matches the stronger fortification durability")
	gate.free();worker.free();other.free()
	print("WORKER_ROM_FORTIFICATION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
