extends SceneTree
# Standalone real-clock check; never calls encounter.tick() or accelerates time.
var game: Node
var failures=0
func check(ok: bool,message: String):
	print("PASS: " if ok else "FAIL: ",message)
	if not ok:failures+=1
func _initialize():
	call_deferred("run")
func run():
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.smoke_test=true
	game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true
	game.tuning.freeze_ai=false
	game.start_game()
	game.player.smoke_mode=true
	game.player.select_character(1)
	var s=game.encounters
	var started=Time.get_ticks_usec()
	var frames=0
	var maximum=0
	var seen=[]
	var killed=false
	var killed_at=0.0
	var pre_four_stable=true
	var saturation_clear=true
	var total_before_kills=0
	while s.elapsed<35.0 and Time.get_ticks_usec()-started<90000000:
		await physics_frame
		frames+=1
		var alive=game.active_enemy_count()
		maximum=maxi(maximum,alive)
		if not seen.has(s.wave):
			seen.append(s.wave)
			print("SUSTAINED_WAVE wave=",s.wave," elapsed=",s.elapsed," active=",alive," pending=",s.pending," total_spawned=",s.total_spawned)
		if alive>200:failures+=1;break
		if s.wave>=3 and not killed and s.elapsed>=21.0:
			check(alive==200 and s.pending==0,"Third wave saturates at 200 without pending debt")
			total_before_kills=s.total_spawned
			var count=0
			for enemy in game.enemies:
				if enemy.dead:continue
				# Suppress random drops so fire-orb chains cannot add unrelated kills.
				enemy.training_dummy=true
				enemy.take_hit(10000,Vector3.FORWARD,true)
				count+=1
				if count==10:break
			killed=true;killed_at=s.elapsed
			check(game.active_enemy_count()==190,"Ten controlled kills release exactly ten active slots")
		if killed and s.wave==3:
			pre_four_stable=pre_four_stable and s.total_spawned==total_before_kills and s.pending==0 and game.active_enemy_count()==190
		if s.wave>=2 and game.active_enemy_count()==200:
			saturation_clear=saturation_clear and s.pending==0
	check(s.elapsed>=35.0 and seen==[1,2,3,4],"Real physics clock spans 35 gameplay seconds and four scheduled waves")
	check(maximum==200,"Every observed physics frame stays at or below 200 active enemies")
	check(killed and killed_at>=21.0 and pre_four_stable,"No backlog refill between third-wave kills and fourth wave")
	check(saturation_clear,"Saturated population never retains pending spawn debt")
	check(s.total_spawned-total_before_kills==10 and game.active_enemy_count()==200 and s.pending==0,"Fourth wave replaces only the ten available slots")
	print("SUSTAINED_CAP elapsed_game_s=",s.elapsed," wall_s=",(Time.get_ticks_usec()-started)/1000000.0," observed_frames=",frames," max_active=",maximum," waves=",seen," total_spawned=",s.total_spawned," skipped=",s.total_skipped," kills=",game.kills)
	game.show_main_menu()
	print("SUSTAINED_CAP_RESULT failures=",failures)
	quit(1 if failures else 0)
