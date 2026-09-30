extends SceneTree
var failures=0
func check(ok: bool,message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func descendants(node: Node)->Array:
	var result=[node]
	for child in node.get_children():result.append_array(descendants(child))
	return result
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.smoke_test=true;game.start_game();game.encounters.set_physics_process(false)
	game.player.smoke_mode=true;game.player.set_physics_process(false);game.tuning.freeze_ai=true
	await physics_frame
	var town=game.world.get_node("TidefallTown")
	var kit=town.get_node("TidefallProps")
	check(kit.get_child_count()==7,"Gate, two stalls, shrine, offering box and two stone lanterns placed")
	var sources={};var actor_nodes=0
	for node in descendants(town):
		if node is Node3D and node.scene_file_path.contains("/town_props/"):sources[node.scene_file_path.get_file()]=true
		if node is Skeleton3D or node is Light3D or node is GPUParticles3D:actor_nodes+=1
	check(sources.size()==9,"All nine original prop exports integrated")
	check(actor_nodes==0,"Town dressing adds no skeletons, dynamic lights or particles")
	var routes=[[Vector2(0,44),Vector2(-8,-29)],[Vector2(-4,-8),Vector2(16,-8)],[Vector2(-7,8),Vector2(-43,-5)],[Vector2(-43,-5),Vector2(-23,-36)],[Vector2(-2,53),Vector2(-2,-19)],[Vector2(-2,39),Vector2(-52,39)]]
	var blocked=0;var space=game.get_world_3d().direct_space_state
	var capsule=CapsuleShape3D.new();capsule.radius=.72;capsule.height=1.85
	var query=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1
	for route in routes:
		for i in range(61):
			var p=route[0].lerp(route[1],i/60.0);query.transform=Transform3D(Basis.IDENTITY,Vector3(p.x,game.world.height_at(p.x,p.y)+1.1,p.y))
			for hit in space.intersect_shape(query,32):
				if kit.is_ancestor_of(hit.collider):blocked+=1
	check(blocked==0,"366 capsule samples across original routes and gate opening avoid prop collision")
	print("TOWN_PROPS_RESULT failures=",failures)
	game.quit_clean()
