extends SceneTree
var failures=0
var checks=0
func check(ok: bool, message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func run():
	check(ResourceLoader.exists("res://scripts/forest/forest_enemy_crowd.gd"),"Forest has a dedicated renderer for the four approved models")
	check(ResourceLoader.exists("res://scripts/forest/forest_enemy_roles.gd"),"Forest has authoritative enemy role data")
	if failures:finish();return
	var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://enemy-integration-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
	await process_frame;await process_frame
	check(game.crowd.get_script().resource_path=="res://scripts/forest/forest_enemy_crowd.gd","The playable scene uses the approved models")
	check(game.model.gold==1000000 and game.model.SIZES.wall==Vector2i(6,1),"Testing treasury and doubled walls remain intact")
	check(game.model.workers.size()==8,"The automatic miners and ready tower guards remain intact")
	var broad_approaches=true
	for along in range(-39,40):
		for across in range(-2,3):
			if game.model.trees.has(Vector2i(along,across)) or game.model.trees.has(Vector2i(across,along)):broad_approaches=false
	check(broad_approaches,"Authored wide cardinal approaches accommodate giant movement and staging")
	var broad_diagonals=true
	for cell in game.model.trees:
		if abs(abs(cell.x)-abs(cell.y))<5:broad_diagonals=false
	check(broad_diagonals,"Wide corner approaches preserve unseen staging when outer cardinal towers have full vision")
	game.start_wave();game.model.waves.spawn_clock=10000
	var points=[Vector3(-18,0,42),Vector3(-6,0,42),Vector3(48,0,42),Vector3(12,0,42)]
	for variant in range(4):
		var enemy=game.model.waves.spawn_enemy(variant,points[variant]);enemy.stun=100
	game.model.update_vision(game.player.position);game.sync_enemies()
	await physics_frame;await physics_frame
	check(game.actors.size()==4,"All four roles create real combat actors")
	var giant=game.model.enemies.values().filter(func(e):return e.variant==2)[0]
	var actor=game.actors[giant.id]
	check(actor.hp==3000 and actor.max_hp==3000,"The playable giant starts with 3000 actualHP")
	game.model.visible_cells.clear()
	check(not game.forest_enemy_visible(actor),"Fog hides the whole giant when none of its footprint is seen")
	game.model.visible_cells[game.model.cell_of(actor.position+Vector3(-12,0,0))]=true
	check(game.forest_enemy_visible(actor),"Giant enters shared sight when an outstretched fist reaches visible ground")
	game.model.update_vision(game.player.position)
	var before: Vector3=giant.pos;var left: float=giant.get("action_left",0.0)
	game.show_pause();await create_timer(.15,true,false,true).timeout
	check(giant.pos==before and giant.get("action_left",0.0)==left,"Ordinary pause stops authoritative enemy movement and attack timing")
	game.resume()
	actor.freeze_for(.75);giant.stun=0;giant.action="windup";giant.action_left=1.2
	game.model.waves.tick(.1,game.player.position)
	check(giant.action_left==1.2 and giant.pos==before,"A hero freeze pauses the director's giant attack")
	var archer=game.model.enemies.values().filter(func(e):return e.variant==1)[0]
	game.model.visible_cells[game.model.cell_of(archer.pos)]=true
	game.model.waves.projectiles[900]={"id":900,"pos":archer.pos+Vector3.UP*2,"from":archer.pos+Vector3.UP*2,"to":game.player.position+Vector3.UP}
	game.enemy_arrows.launch({"id":900,"from":archer.pos+Vector3.UP*2,"to":game.player.position+Vector3.UP})
	game.enemy_arrows.sync(0)
	check(game.enemy_arrows.visuals.has(900) and game.enemy_arrows.visuals[900].visible,"Archer arrows have a rendered flight in shared vision")
	game.model.visible_cells.clear();game.enemy_arrows.sync(0)
	check(not game.enemy_arrows.visuals[900].visible,"Flying enemy arrows disappear in unseen ground")
	game.model.waves.projectiles.clear();game.model.enemies.clear();game.model.phase="preparing";game.set_phase_view()
	await process_frame
	check(game.enemy_arrows.visuals.is_empty() and game.actors.is_empty(),"Wave cleanup removes enemy arrows and combat actors")
	game.model.reset(42)
	check(game.model.enemies.is_empty() and game.model.wave==0 and game.model.gold==1000000,"Retry resets all enemy state while preserving testing treasury")
	game.queue_free();paused=false;await process_frame;await create_timer(.2).timeout;finish()
func finish():print("FOREST_ENEMY_INTEGRATION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
