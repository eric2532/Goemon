extends SceneTree
const Castle=preload("res://scripts/forest/forest_enemy_castle.gd")
func _initialize():run.call_deferred()
func run():
	var mesh:Mesh=Castle.STATUE;var path:String=mesh.get_meta("source_model")
	assert(mesh.get_meta("source_sha256")==FileAccess.get_sha256(path),"Rebake the statue after editing Skullpion")
	var source=load(path).instantiate();root.add_child(source)
	var player:AnimationPlayer=source.find_child("AnimationPlayer",true,false)
	player.play(mesh.get_meta("source_clip"));player.seek(0,true);player.pause()
	var fit:Transform3D=mesh.get_meta("source_fit");var vertices:PackedVector3Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var offset=0;var parts=source.find_children("*","MeshInstance3D",true,false)
	assert(parts.size()==22 and mesh.get_surface_count()==1)
	for part:MeshInstance3D in parts:
		for slot in part.mesh.get_surface_count():
			var arrays=part.mesh.surface_get_arrays(slot)
			for index in arrays[Mesh.ARRAY_INDEX]:
				assert(vertices[offset].distance_to(fit*part.global_transform*arrays[Mesh.ARRAY_VERTEX][index])<.001,"Statue must preserve every source triangle and prepared pose")
				offset+=1
	assert(offset==vertices.size() and offset==mesh.get_meta("source_triangles")*3)
	for rotation_ in 4:
		var holder=Node3D.new();root.add_child(holder);Castle.build_statue(holder,{"rotation":rotation_})
		var statue:MeshInstance3D=holder.get_node("SkullpionStatue/CarvedSkullpion")
		var boxes=Castle.statue_boxes({"rotation":rotation_})
		for vertex in vertices:assert(boxes.any(func(box):return box.grow(.01).has_point(statue.global_transform*vertex)),"Rotated physical boxes must cover statue geometry")
		holder.free()
	source.free();preload("res://scripts/forest/forest_stone_fort.gd").materials.clear();Geo.mats.clear()
	for i in 3:await process_frame
	print("ENEMY_STATUE_MODEL_RESULT triangles=",offset/3," rotations=4 source_preserved=true");quit()
