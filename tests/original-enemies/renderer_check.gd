extends SceneTree
var failures=0
func check(condition: bool, message: String):
	print(("PASS " if condition else "FAIL ")+message)
	if not condition:failures+=1
func _initialize():call_deferred("run")
func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.start_game();game.encounters.set_physics_process(false);game.encounters.pending=0
	game.tuning.freeze_ai=true;game.player.smoke_mode=true
	for e in game.enemies:
		if is_instance_valid(e):e.queue_free()
	game.enemies.clear()
	await process_frame
	for kind in range(4):
		var enemy=Ninja.new();enemy.game=game;enemy.variant=kind;enemy.practice=true
		enemy.position=game.player.position+Vector3(float(kind)*3-4.5,0,-5)
		game.add_child(enemy);game.enemies.append(enemy)
	await process_frame
	game.crowd._process(.016)
	check(game.crowd.batches.size()>=4,"Four original designs retain their shared batches")
	for kind in range(4,game.crowd.batches.size()):
		check(game.crowd.batches[kind].multimesh.visible_instance_count==0,"Siege-only species %d stays absent from original survival" % kind)
	for kind in range(4):
		var batch=game.crowd.batches[kind]
		check(batch.multimesh.mesh.get_surface_count()==1,"Species %d merges to one material surface" % kind)
		check(batch.multimesh.visible_instance_count==1,"Species %d appears exactly once" % kind)
		check(game.enemies[kind].model.skeleton==null and game.enemies[kind].model.get_child_count()==0,"Species %d allocates no per-actor visual hierarchy" % kind)
		var arrays=batch.multimesh.mesh.surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_VERTEX].size()>0 and arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size(),"Species %d preserves all textured vertices" % kind)
		print("MESH %s triangles=%d" % [EnemyCrowd.ASSET_IDS[kind],arrays[Mesh.ARRAY_VERTEX].size()/3])
	if "--visual" in OS.get_cmdline_user_args():
		game.camera_rig.set_process(false);game.hud.hide();game.player.hide()
		for kind in range(4):
			game.enemies[kind].position=game.player.position+Vector3(3.3-float(kind)*2.2,0,-16)
			game.enemies[kind].position.y=game.world.height_at(game.enemies[kind].position.x,game.enemies[kind].position.z)+.06
			if game.enemies[kind].name_tag!=null:game.enemies[kind].name_tag.hide()
		game.camera_rig.camera.global_position=game.player.position+Vector3(0,4,-25)
		game.camera_rig.camera.look_at(game.player.position+Vector3(0,1,-16))
		for frame in range(8):await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://tests/original-enemies/game-lineup.png")
	game.enemies[0].swarm=true;game.enemies[0].formation_index=1
	check(game.crowd.visual_species(game.enemies[0])==3 and game.enemies[0].variant==0,"Lantern survival appearance preserves standard melee stats")
	game.enemies[0].formation_index=2
	check(game.crowd.visual_species(game.enemies[0])==0,"Standard survival appearance alternates with soldier")
	game.enemies[0].swarm=false
	var frozen=game.enemies[3];frozen.freeze_for(2);game.crowd._process(.016)
	check(game.crowd.actor_data(frozen).a==1,"Freeze is encoded per actor")
	game.enemies[0].state="windup";game.crowd._process(.016)
	check(absf(game.crowd.actor_data(game.enemies[0]).b-.65)<.01,"Windup drives batched pose")
	game.enemies[0].state="strike";game.enemies[0].timer=.15;game.crowd._process(.016)
	check(absf(game.crowd.actor_data(game.enemies[0]).b+.5)<.01,"Strike drives batched pose")
	game.show_main_menu()
	for batch in game.crowd.batches:check(batch.multimesh.visible_instance_count==0,"Menu clears every species")
	print("ORIGINAL ENEMY RENDERER: %d failures" % failures)
	game.queue_free();await process_frame
	quit(1 if failures else 0)
