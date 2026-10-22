extends "res://scripts/combat_tests.gd"

func frames(count: int):
	for i in range(count):await get_tree().physics_frame

func run():
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true
	game.start_game();game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await frames(20)
	game.encounters.active=false
	var remote=game.enemies[-1]
	var before=remote.position
	await frames(120)
	check(remote.position.distance_to(before)>1,"Distant patrols keep moving with amortized collision checks")
	var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(remote.position+Vector3.UP,remote.position-Vector3.UP,1))
	check(not hit.is_empty() and absf(remote.position.y-hit.position.y)<.15,"Interpolated patrols remain on the real island floor")
	before=remote.position;remote.take_hit(1,Vector3.RIGHT,true)
	await frames(8)
	check(remote.position.y>before.y+.2 and remote.position.x>before.x+.2,"Knockback exits patrol interpolation and uses real airborne collision")
	remote.freeze_for(.4);before=remote.position;await frames(10)
	check(remote.position.distance_to(before)<.01,"Frozen distant enemies stop moving immediately")
	game.tuning.freeze_ai=true
	var terrain=game.world.get_node("TerrainChunks")
	var bounded=true
	for tile in terrain.get_children():
		bounded=bounded and tile.get_aabb().size.x<=80.01 and tile.get_aabb().size.z<=80.01
		for body in tile.get_children():
			if body is StaticBody3D:body.set_collision_layer_value(21,true)
	check(bounded and terrain.get_child_count()>100,"Terrain sections have bounded camera and shadow-culling volumes")
	await frames(2)
	var seamless=true;var probes=0
	var edge=game.world.playable_bounds.grow(5)
	for tile in terrain.get_children():
		var center=tile.position+tile.get_aabb().get_center()
		var crossings=[]
		if tile.position.x>edge.position.x+.1:crossings.append([Vector3(tile.position.x,0,center.z),Vector3.RIGHT])
		if tile.position.z>edge.position.y+.1:crossings.append([Vector3(center.x,0,tile.position.z),Vector3.BACK])
		for crossing in crossings:
			var heights=[]
			for sign_value in [-1,1]:
				var point=crossing[0]+crossing[1]*.02*sign_value
				var floor_hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*100,point-Vector3.UP*100,1<<20))
				seamless=seamless and not floor_hit.is_empty()
				if not floor_hit.is_empty():heights.append(floor_hit.position.y)
				probes+=1
			if heights.size()==2:seamless=seamless and absf(heights[0]-heights[1])<.2
	for tile in terrain.get_children():
		for body in tile.get_children():
			if body is StaticBody3D:body.set_collision_layer_value(21,false)
	check(seamless and probes>500,"Both sides of every internal terrain seam have continuous physical ground")
	var seam=Vector3(edge.position.x+6*80,0,edge.position.y+7*80+40)
	seam.y=game.world.height_at(seam.x,seam.z)
	game.reset_player_at(seam+Vector3(-3,.3,0));game.camera_rig.yaw=0;await frames(30)
	game.player.smoke_move=Vector2.RIGHT;await frames(45);game.player.smoke_move=Vector2.ZERO
	check(game.player.position.x>seam.x+2 and game.player.is_on_floor(),"Real player controller crosses a terrain seam without snagging or falling")
	var room=game.world.furnished_town.rooms[0]
	var furniture=room.meshes.get("Interior")
	check(furniture!=null and furniture.visibility_range_end<=100 and room.meshes.Roof.visibility_range_end>=400,"Nearby furniture stays detailed while building silhouettes remain visible farther away")
	# A one-microsecond budget must yield, then resume to exactly the synchronous field.
	game.pursuit.configure()
	var started=game.pursuit.start_build(game.world.outposts[0])
	game.pursuit.advance_build(1)
	check(started and game.pursuit.building and game.pursuit.build_index==1,"Navigation yields after an expensive cell rather than overrunning sixteen cells")
	var seed=game.pursuit.build_target
	while game.pursuit.building:game.pursuit.advance_build(10000000)
	var distances=game.pursuit.distances.duplicate()
	game.pursuit.configure();game.pursuit.refresh_field(game.world.outposts[0])
	check(game.pursuit.target_cell==seed and game.pursuit.distances==distances,"Time-sliced navigation produces the complete original route field")
	print("WORLD_PERFORMANCE_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
