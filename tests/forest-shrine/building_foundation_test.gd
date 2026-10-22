extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Art=preload("res://scripts/forest/forest_art.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func bottom(node:Node3D,collisions:bool=false)->float:
	var lowest=INF
	for child in node.find_children("*","CollisionShape3D" if collisions else "MeshInstance3D",true,false):
		var bounds=child.shape.get_debug_mesh().get_aabb() if collisions else child.mesh.get_aabb()
		lowest=minf(lowest,child.position.y+bounds.position.y)
	return lowest
func run():
	var model=Model.new();model.reset(42,{},JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_kai_highway.json")),false)
	var cell=Vector2i(21,17)
	check(model.placement_error("tower",cell,0).is_empty(),"The downhill Kai regression fixture is a legal tower site")
	var built=model.build("tower",cell,0)
	if built.is_empty():finish();return
	var world=load("res://scripts/forest/forest_world.gd").new();world.model=model;world.painterly_preview_enabled=true;root.add_child(world);await process_frame
	var tower=world.structure_nodes[built.id]
	var support=tower.get_node_or_null("TerrainFoundation")
	check(support!=null,"A placed tower has a foundation on the newly allowed downhill shoulder")
	if support!=null:
		# This native fixture has base y=6.9871 and downhill ground y=5.8974.
		check(tower.position.y+bottom(support)<=5.8975,"Visible masonry reaches the downhill ground without moving the tower")
		check(tower.position.y+bottom(support,true)<=5.8975,"Foundation collision reaches the same ground")
		check(support.get_child(0).is_visible_in_tree(),"The foundation remains visible with painterly masonry enabled")
	var highest=-INF
	for x in range(cell.x*6-3,cell.x*6+10):
		for z in range(cell.y*6-3,cell.y*6+10):highest=maxf(highest,model.surface_height(x,z))
	check(tower.position.y>=highest-.001,"The building base clears the highest supported ground instead of burying the uphill side")
	world.show_preview("tower",cell,0,true)
	var preview_support=world.ghost_art.get_node_or_null("TerrainFoundation")
	check(preview_support!=null,"The build preview shows its eventual foundation")
	check(world.preview.position.is_equal_approx(tower.position),"Preview and placed building have identical grounded positions")
	if support!=null and preview_support!=null:check(is_equal_approx(bottom(support),bottom(preview_support)),"Preview and placed tower use the same foundation depth")
	world.show_preview("tower",Vector2i(3,-3),0,true)
	check(world.ghost_art.get_node_or_null("TerrainFoundation")==null,"Moving the preview onto level ground removes its old downhill foundation")
	for kind in ["tower","barracks","wall","gate"]:
		var plain=Art.building({"id":-1,"kind":kind,"rotation":0})
		check(plain.get_node_or_null("TerrainFoundation")==null,"Flat %s geometry remains unchanged"%kind);plain.free()
	var gate=Art.building({"id":-1,"kind":"gate","rotation":1,"foundation_depth":1.1})
	var gate_support=gate.get_node_or_null("TerrainFoundation")
	var door=gate.get_node("GateDoor")
	check(door.position.y+door.mesh.get_aabb().position.y<=-1.099,"A closed sloping gate extends its door down to the foundation bottom")
	var door_shape=door.get_node("GateDoorCollider").get_child(0)
	check(door.position.y+door_shape.position.y-door_shape.shape.size.y*.5<=-1.099,"A closed sloping gate has no collision gap below its door")
	check(gate_support!=null,"A sloping gate gets supporting feet")
	if gate_support!=null:
		var feet=gate_support.find_children("*","CollisionShape3D",true,false)
		check(feet.size()==2,"Gate foundations keep two separate pier colliders")
		for foot in feet:check(absf(foot.position.x)-foot.shape.size.x*.5>=4.79,"Gate footing leaves the original central passage clear")
	gate.free();world.queue_free();await process_frame
	finish()
func finish():
	print("BUILDING_FOUNDATION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
