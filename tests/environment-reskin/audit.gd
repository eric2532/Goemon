extends SceneTree

var game
var report={}
var label="after"
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):label=arg.trim_prefix("--label=")
	call_deferred("run")
func shapes(node: Node, result: Array):
	if node is CollisionShape3D:
		var s=node.shape
		var data=str(s.get_faces()) if s is ConcavePolygonShape3D else str(s)
		result.append([str(node.global_transform),data.sha256_text(),node.disabled])
	for child in node.get_children():shapes(child,result)
func run():
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.smoke_test=true
	game.start_game()
	game.encounters.set_physics_process(false)
	game.player.smoke_mode=true
	game.player.set_physics_process(false)
	game.camera_rig.set_process_unhandled_input(false)
	game.tuning.freeze_ai=true
	for area in range(4):
		if area>0 or "--baseline" in OS.get_cmdline_user_args():
			game.world.free()
			if "--baseline" in OS.get_cmdline_user_args():
				game.world=load("res://tests/environment-reskin/baseline/"+("world.gd" if area==0 else "expedition_area.gd")).new()
			else:game.world=ExpeditionArea.new()
			game.world.area_index=area
			game.world.generation_seed=90824
			game.add_child(game.world)
			if area==0:WorldExpansion.walls(game.world,Geo.mat("405d68"))
		game.world.set_process(false)
		await physics_frame
		var collision=[]
		shapes(game.world,collision)
		collision.sort_custom(func(a,b):return str(a)<str(b))
		var heights=[]
		for x in range(-280,281,7):
			for z in range(-440,280,7):heights.append(game.world.height_at(x,z))
		report[str(area)]={"collisions":collision,"heights":str(heights).sha256_text(),"bounds":str(game.world.playable_bounds),"outposts":str(game.world.outposts),"rng_state":str(game.world.rng.state)}
		var views=[["spawn",Vector3(0,0,41),0.0],["temple",Vector3(-10,0,-18),0.0],["bridge",Vector3(13,0,-8),-PI/2],["grotto",Vector3(-44,0,12),0.0],["outpost",Vector3(0,0,-130),0.0]] if area==0 else [["spawn",game.world.spawn_point,0.0],["court",game.world.centers[4]+Vector3(0,0,12),0.0],["outpost",game.world.outposts[1]+Vector3(0,0,20),0.0]]
		if not "--audit-only" in OS.get_cmdline_user_args():
			for v in views:
				game.player.position=v[1]
				game.player.position.y=game.world.height_at(v[1].x,v[1].z)+.2
				game.camera_rig.yaw=v[2]
				game.camera_rig.reset_follow()
				game.hud.banner_time=0
				for i in range(8):await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://tests/environment-reskin/%s-area%d-%s.png" % [label,area,v[0]])
				print("CAPTURE ",label," ",area," ",v[0])
	FileAccess.open("res://tests/environment-reskin/"+label+"-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ENVIRONMENT_AUDIT_COMPLETE ",label)
	game.quit_clean()
