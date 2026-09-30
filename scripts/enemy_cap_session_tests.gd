extends SceneTree
# Accelerated encounter schedule, real actor creation and physics cleanup.
# This is an invariant test, not a rendered or CPU performance benchmark.
var game: Node
var failures=0
var sampled_frames=0
var maximum=0
func check(ok: bool, message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func sample():
	var n=game.active_enemy_count()
	maximum=maxi(maximum,n);sampled_frames+=1
	if n>game.active_enemy_limit:
		check(false,"Hard cap exceeded: %d > %d" % [n,game.active_enemy_limit])
func frames(n: int):
	for i in range(n):
		await physics_frame
		sample()
func drain():
	for i in range(600):
		if game.encounters.pending==0:return
		game.encounters.tick(0)
		await frames(1)
	check(false,"Current-wave demand drains within 600 physics frames")
func _initialize():call_deferred("run")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true
	var start=Time.get_ticks_usec()
	for limit in [32,200,400]:
		maximum=0;sampled_frames=0
		game.tuning.max_active_enemies=limit;game.start_game()
		game.player.smoke_mode=true;game.player.select_character(1)
		var s=game.encounters;s.set_physics_process(false)
		await frames(12);await drain()
		var deaths=0;var peaks=0;var clean=true;var no_debt=true
		for wave in range(1,61):
			if wave>1:s.tick(10.0);await drain()
			check(s.wave==wave and s.pending==0,"Limit %d wave %d advances and drains without debt" % [limit,wave])
			if game.active_enemy_count()==limit:
				peaks+=1
				check(game.spawn_practice(true)==0,"Practice blocked at shared saturation (%d wave %d)" % [limit,wave])
				var legacy=EndlessEncounters.new();legacy.game=game
				legacy.slots={"0":{"home":game.player.position+Vector3(0,0,-25),"actor":null,"remaining":0.0}}
				legacy.tick(1)
				check(legacy.respawn_count==0,"Legacy replacement blocked at saturation")
				legacy.free()
			if wave%5==0 and wave<60:
				var before=s.total_spawned;var alive=game.active_enemy_count();var killed=[]
				for enemy in game.enemies:
					if enemy.dead:continue
					enemy.training_dummy=true;killed.append(weakref(enemy));enemy.take_hit(10000,Vector3.FORWARD,true)
					if killed.size()==7:break
				deaths+=killed.size()
				s.tick(0);await frames(70);s.tick(0)
				no_debt=no_debt and s.total_spawned==before and s.pending==0 and game.active_enemy_count()==alive-killed.size()
				for ref in killed:clean=clean and ref.get_ref()==null
				clean=clean and game.enemies.size()==game.active_enemy_count()
			if wave==17:
				var elapsed=s.elapsed;var total=s.total_spawned
				game.show_pause();s.tick(30);await frames(3)
				check(s.elapsed==elapsed and s.total_spawned==total,"Pause rejects schedule and spawn advancement")
				game.resume()
		check(s.wave==60 and is_equal_approx(s.elapsed,590.0) and s.total_scheduled==8700,"Limit %d traverses every full-session wave" % limit)
		check(maximum<=limit and peaks>0,"Limit %d reaches saturation and never exceeds cap" % limit)
		check(deaths==77 and clean,"77 deaths release references and bodies across eleven cleanup cycles")
		check(no_debt,"Repeated deaths never replay skipped waves")
		s.tick(10)
		check(game.won and game.paused and s.elapsed==600 and not s.active and s.pending==0,"600 seconds triggers victory with no 61st wave")
		s.tick(60);check(s.wave==60 and s.elapsed==600,"Post-victory ticks cannot create arrivals")
		print("SESSION_CAP limit=",limit," simulated_seconds=",s.elapsed," waves=",s.wave," max_active=",maximum," sampled_physics_frames=",sampled_frames," controlled_deaths=",deaths," total_spawned=",s.total_spawned," skipped=",s.total_skipped)
		var previous=[]
		for e in game.enemies:previous.append(weakref(e))
		game.restart_area();s.set_physics_process(false);await frames(3)
		var released=true
		for ref in previous:released=released and ref.get_ref()==null
		check(released and game.enemies.is_empty() and s.wave==1 and s.total_spawned==0 and s.pending==mini(100,limit),"Restart frees prior population and resets schedule at same configured bound")
		await drain()
		check(game.active_enemy_count()==mini(100,limit),"Restart opening wave respects configured bound")
		game.show_main_menu()
	print("SESSION_CAP_RESULT failures=",failures," wall_seconds=",(Time.get_ticks_usec()-start)/1000000.0)
	quit(1 if failures else 0)
