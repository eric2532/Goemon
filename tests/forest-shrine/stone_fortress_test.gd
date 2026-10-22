extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const World=preload("res://scripts/forest/forest_world.gd")
const Document=preload("res://scripts/forest/forest_map_document.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func meshes(node:Node)->Array:
	var found=[]
	for child in node.get_children():
		if child is MeshInstance3D:found.append(child)
		found.append_array(meshes(child))
	return found
func bounds(node:Node3D)->AABB:
	var result=AABB();var first=true
	for mesh in meshes(node):
		var box:AABB=node.global_transform.affine_inverse()*mesh.global_transform*mesh.mesh.get_aabb()
		result=box if first else result.merge(box);first=false
	return result
func run():
	var doc=Document.new();doc.load_four_gates();var before=doc.encode()
	var m=Model.new();m.reset(42,{},doc.data);doc.capture(m);before=doc.encode()
	var world=World.new();world.model=m;root.add_child(world)
	await process_frame;await physics_frame
	var walls=m.buildings.values().filter(func(b):return b.kind=="wall")
	var wall=walls[0];var wall_node:Node3D=world.structure_nodes[wall.id]
	check(bounds(wall_node).end.y>=16,"The base wall is at least four times its old height")
	var point=m.center(wall);var ray=PhysicsRayQueryParameters3D.create(point+Vector3(0,12,-8),point+Vector3(0,12,8),1)
	check(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Physical wall collision reaches the raised stone wall")
	check(not m.waves.navigation.line_clear(point+Vector3(0,12,-8),point+Vector3(0,12,8)),"Enemy projectile visibility also respects the higher wall")
	var gates=m.buildings.values().filter(func(b):return b.kind=="gate")
	check(gates.size()==4 and m.portals.size()==8,"The four entrances and eight portal routes are preserved")
	for gate in gates:
		var node:Node3D=world.structure_nodes[gate.id]
		check(bounds(node).end.y>=16,"Stone gate %d matches the tall fort"%gate.id)
		var door=node.get_node("GateDoor")
		check(door.mesh.size.y>=8 and door.material_override is ShaderMaterial,"Gate %d has a large textured stone door"%gate.id)
		m.hero_position=m.center(gate)+Vector3(0,0,4);world.sync(1)
		check(door.position.y-door.mesh.size.y*.5>=8,"Stone door %d opens far enough for normal allied passage"%gate.id)
	var shrine:Node3D=world.structure_nodes[1]
	var statue=shrine.find_child("GoemonStoneStatue",true,false)
	check(statue!=null,"The central base is a Goemon statue instead of the shrine building")
	if statue!=null:
		check(bounds(statue).size.y>=29 and bounds(statue).size.y<=31,"The reused Goemon model stands thirty metres tall")
		check(statue.find_children("*","Skeleton3D",true,false).is_empty() and statue.find_children("*","AnimationTree",true,false).is_empty(),"The static monument carries no active character rig")
		check(not meshes(statue).is_empty() and meshes(statue).all(func(mesh):return range(mesh.mesh.get_surface_count()).all(func(slot):return mesh.get_active_material(slot) is ShaderMaterial)),"Every statue part uses the rock material")
	check(shrine.find_child("ShrineVisual",true,false)==null,"The old roofed shrine visual is removed")
	world.set_painterly_preview(true);await process_frame
	check(bounds(wall_node).end.y>=16 and (statue!=null and shrine.find_child("GoemonStoneStatue",true,false)==statue),"Painterly scenery retains the stone fort and statue")
	doc.capture(m);check(doc.encode()==before,"Stone architecture keeps saved map footprints and routes unchanged")
	check(m.shrine().hp==3000 and walls.all(func(b):return b.hp==b.max_hp),"The art update preserves building health and balance")
	world.queue_free();await process_frame
	print("STONE_FORTRESS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
