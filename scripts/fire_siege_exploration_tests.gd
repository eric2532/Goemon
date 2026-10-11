extends SceneTree
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
func run():
	var world=TowerDefenseWorld.new();world.redesign_mode=true
	if world.get("expanded_mode")==null:
		check(false,"Expanded world can opt into explorable bounds");world.free();finish();return
	world.set("expanded_mode",true);root.add_child(world);world.set_process(false)
	check(world.playable_bounds==Rect2(-160,50,320,480),"Expanded field includes side districts")
	check(world.lanes[1][0]==Vector3(0,0,110) and world.lanes[1][-1]==Vector3(0,0,220),"Enemy approach is 110 metres")
	check(world.cannon_sites.size()==12 and world.mine_sites.size()==4,"Twelve towers and four mines retained")
	check(world.height_at(95,400)==0,"Exploration keeps flat movement contract")
	await physics_frame
	var clear=true
	for x in [-5.5,0,5.5]:
		clear=clear and root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,1,110),Vector3(x,1,218),1)).is_empty()
	check(clear,"Physical approach remains clear through both walls")
	for site in world.cannon_sites:
		check(world.playable_bounds.has_point(Vector2(site.build_position.x,site.build_position.z)),"Tower work pad stays in bounds")
	check(world.exploration_caches.size()==3,"Each district has an exploration reward")
	world.free()
	var legacy=TowerDefenseWorld.new();legacy.beta_mode=true;root.add_child(legacy);legacy.set_process(false)
	check(legacy.playable_bounds==Rect2(-80,50,160,310) and legacy.cannon_sites.size()==8,"Compact legacy layout stays intact")
	legacy.free()
	if ResourceLoader.exists("res://scripts/fire_siege_exploration.gd"):await cache_rules()
	finish()
func cache_rules():
	var game=load("res://scenes/main.tscn").instantiate();game.smoke_test=true;root.add_child(game)
	game.tuning.freeze_ai=true;game.tuning.invincible=true;game.start_mode("defense")
	game.encounters.set_physics_process(false);game.player.set_physics_process(false)
	await physics_frame
	var run=game.encounters
	game.player.position=game.world.base_position+Vector3(0,.15,10);game.camera_rig.yaw=0
	check(run.shrine_guidance().get("screen_direction",Vector2.ZERO).is_equal_approx(Vector2.UP),"Shrine compass points ahead relative to camera")
	game.player.position=game.world.base_position+Vector3(-10,.15,0);game.camera_rig.yaw=-PI/2
	check(run.shrine_guidance().get("screen_direction",Vector2.ZERO).is_equal_approx(Vector2.UP),"Shrine compass rotates with the camera")
	var gold=run.money
	for cache in game.world.exploration_caches:
		game.player.position=cache.position
		run.exploration.tick(.2);run.exploration.tick(.2)
	check(is_equal_approx(run.money,gold+9) and run.exploration.collected_count()==3,"Three caches reward once per run")
	run.exploration.reset()
	var point: Vector3=game.world.exploration_caches[0].position
	game.player.position=point+Vector3(-2,0,0)
	var barrier=StaticBody3D.new();var shape=CollisionShape3D.new();var block=BoxShape3D.new()
	block.size=Vector3(.4,2,2);shape.shape=block;barrier.add_child(shape);barrier.position=point+Vector3(-1,1,0);game.add_child(barrier)
	await physics_frame;run.exploration.tick(.2)
	check(is_equal_approx(run.money,gold+9),"Cache cannot be collected through a wall")
	barrier.free();await physics_frame
	game.player.position=game.world.exploration_caches[-1].position
	game.paused=true;run.exploration.tick(.2);game.paused=false
	check(is_equal_approx(run.money,gold+9),"Paused cache cannot reward")
	game.player.hp=0;run.exploration.tick(.2);game.player.hp=game.player.max_hp
	check(is_equal_approx(run.money,gold+9),"Dead hero cannot collect")
	run.phase="spawning";run.exploration.tick(.2);run.phase="setup"
	check(is_equal_approx(run.money,gold+9),"Combat cache cannot reward")
	run.exploration.tick(.2)
	check(is_equal_approx(run.money,gold+12),"Accessible cache grants reward after reset")
	run.begin();game.player.position=point;run.exploration.tick(.2)
	check(run.exploration.collected_count()==1 and is_equal_approx(run.money,13),"Real new run resets collection and starting funds")
	run.tick(600)
	check(run.total_spawned==0 and run.base_hp==100 and run.phase=="setup","Preparation stays safe without a timer")
	var cap=CapsuleShape3D.new();cap.radius=.5;cap.height=2
	var paths: Array=game.world.get_meta("exploration_paths",[])
	check(paths.size()>=5,"Districts have loop and return routes")
	for path in paths:
		for i in range(path.size()-1):
			var q=PhysicsShapeQueryParameters3D.new();q.shape=cap;q.collision_mask=1
			q.transform=Transform3D(Basis.IDENTITY,path[i]+Vector3.UP*1.1);q.motion=path[i+1]-path[i]
			var sweep=game.get_world_3d().direct_space_state.cast_motion(q)
			if sweep[0]<=.99:
				var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(path[i]+Vector3.UP*1.1,path[i+1]+Vector3.UP*1.1,1))
				print("PATH_BLOCK ",path[i]," -> ",path[i+1]," fraction=",sweep[0]," collider=",hit.get("collider").get_path() if hit.has("collider") else "none"," point=",hit.get("position"))
			check(sweep[0]>.99,"Hero-sized district path is clear")
	game.sound_library.cancel();game.music.stop();game.queue_free()
	await process_frame
func finish():
	print("EXPLORATION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
