extends "res://scripts/recovered_leaders_tests.gd"
const Model=preload("res://scripts/forest/forest_model.gd")
const Camps=preload("res://scripts/forest/forest_camp_prototype.gd")
const COUNTS=[[1,0,0,0,0,0,0,0,0,0],[0,1,0,0,0,0,0,0,0,0],[0,0,1,0,0,0,0,0,0,0],[0,0,0,1,0,0,0,0,0,0]]
const OUT="res://build/Other Files/Asset Toolkit/Wave Timer/"

func model_checks():
	for layout in [{},Camps.layout()]:
		var model=Model.new();model.reset(42,{"waves":COUNTS},layout,false)
		var waves=model.waves
		check(waves.countdown_text().contains("4 WAVES · 04:00"),"Four configured waves preview four minutes")
		model.start_wave()
		check(waves.released_waves==1 and waves.wave_clock==60 and waves.schedule_left()==240,"START releases wave one with four full minutes remaining")
		waves.tick(0,model.hero_position)
		check(model.enemies.size()==1 and model.wave==1,"Wave one spawns on the first update without waiting")
		check(waves.countdown_text().contains("WAVE 2 / 4 IN 01:00"),"The countdown immediately targets wave two")
		for index in range(2,5):
			waves.tick(60,model.hero_position)
			check(waves.released_waves==index and model.wave==index and model.enemies.size()==index,"Wave %d arrives at minute %d while previous enemies remain"%[index,index-1])
		check(waves.schedule_left()==60 and waves.countdown_text().contains("FINAL WAVE 4 / 4") and model.phase=="wave","The fourth wave starts at three minutes with one minute left")
		waves.tick(60,model.hero_position)
		check(waves.schedule_left()==0 and waves.countdown_text().contains("CLEAR THE ENEMIES"),"Four minutes finishes the timer and asks to clear survivors")
		waves.tick(120,model.hero_position)
		check(waves.spawned==4 and waves.pending==0 and model.phase=="wave","Final mix never repeats")
		model.enemies.clear();waves.tick(0,model.hero_position)
		check(model.phase=="victory" and not model.start_wave(),"Clearing the final enemies wins for finite and castle layouts")
		check(model.balance.waves==COUNTS,"Scheduling preserves configured counts")
	var model=Model.new();var empty=[0,0,0,0,0,0,0,0,0,0]
	model.reset(42,{"waves":[empty,empty,empty,empty]}, {},false);model.start_wave()
	model.waves.tick(180,model.hero_position)
	check(model.phase=="wave" and model.waves.released_waves==4 and model.waves.schedule_left()==60,"Even an empty final wave retains its full minute")
	model.waves.tick(60,model.hero_position)
	check(model.phase=="victory" and model.enemies.is_empty(),"An all-empty four-wave run ends at four minutes")
	model.reset(42,{"waves":COUNTS},{},false);model.start_wave()
	for i in model.waves.active_cap():model.waves.spawn_enemy(0,Vector3.ZERO)
	model.waves.tick(125,model.hero_position)
	check(model.waves.released_waves==3 and model.waves.wave_clock==55 and model.waves.pending==3,"Capacity cannot delay the clock or lose due arrivals")
	model.waves.tick(115,model.hero_position)
	check(model.waves.released_waves==4 and model.waves.pending==4,"A long frame carries every roster across minute boundaries")
	model.enemies.clear();model.waves.tick(0,model.hero_position)
	check(model.enemies.size()==4 and model.waves.spawned==4 and model.waves.pending==0,"Queued arrivals resume with exact totals when capacity clears")
	check(model.waves.clock_text(60)=="01:00" and model.waves.clock_text(.01)=="00:01" and model.waves.clock_text(0)=="00:00","Clock formatting handles minute and final-second boundaries")
	for rate in [30,60,144]:
		model.reset(42,{"waves":COUNTS},{},false);model.start_wave()
		model.waves.tick(0,model.hero_position)
		for step in range(rate*60-1):model.waves.tick(1.0/rate,model.hero_position)
		check(model.enemies.size()==1 and model.waves.released_waves==1,"At %d Hz wave two never arrives early"%rate)
		model.waves.tick(1.0/rate,model.hero_position)
		check(model.waves.released_waves==2 and model.enemies.size()==2,"At %d Hz accumulated steps release wave two at exactly a minute"%rate)
	model.reset(42,{"waves":COUNTS},{},false);model.start_wave()
	check(model.waves.released_waves==1 and model.waves.schedule_left()==240,"A fresh run resets all timing")

func run():
	model_checks()
	if "--visual" in OS.get_cmdline_user_args():await desktop_checks()
	print("WAVE_TIMER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func desktop_checks():
	DirAccess.make_dir_recursive_absolute(OUT)
	set_meta("forest_fighter",1)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://wave-timer-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(5)
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.core_balance.waves=COUNTS.duplicate(true)
	var ui=game.forest_ui;ui.message_left=0;ui.sync()
	check(game.painterly_preview and game.model.terrain_source=="wind_meadow","Desktop launcher uses painterly Wind Meadow")
	await capture("preparation")
	game.start_wave();game.tuning.invincible=true
	var waves=game.model.waves
	ui.sync()
	check(ui.wave_countdown.visible and ui.wave_countdown.text.contains("TOTAL 04:00"),"The countdown appears on starting the real game")
	var before:float=waves.wave_clock
	game.show_pause();game._physics_process(10)
	check(waves.wave_clock==before,"Ordinary pause freezes the countdown")
	game.resume();game.show_rogue_roster();game._physics_process(10)
	check(waves.wave_clock==before,"Fighter selection freezes the countdown")
	game.choose_rogue_character(1)
	for dimensions in [Vector2i(1280,800),Vector2i(960,600)]:
		root.size=dimensions;await frames(3)
		for factor in [1.0,1.25]:
			game.settings.forest_hud_scale=factor;ui.sync();await frames(3)
			var rect:Rect2=ui.wave_countdown.get_global_rect()
			check(absf(rect.get_center().x-ui.size.x*.5)<1 and rect.position.y==16,"Timer stays at the top center at %s, HUD %.2f"%[dimensions,factor])
			check(not rect.intersects(ui.hero_dock.get_global_rect()) and not rect.intersects(ui.resource_hub.get_global_rect()),"Timer clears the character and resources at %s, HUD %.2f"%[dimensions,factor])
			await capture("countdown-%dx%d-%.2f"%[dimensions.x,dimensions.y,factor])
	root.size=Vector2i(1280,800);game.settings.forest_hud_scale=1.0
	for index in range(1,5):
		if index==2:
			var previous:float=game.model.balance.enemy_health_mult
			game.core_balance.enemy_health_mult=previous+1
			check(game.model.balance.enemy_health_mult==previous,"Saved enemy balance stays isolated until the next scheduled wave")
		waves.tick(0 if index==1 else 60,game.player.position)
		game.army_runtime.integration_tick(1.0/60);game.army_runtime.flush_presentation();ui.sync()
		await frames(2)
		check(waves.released_waves==index and game.army_runtime.handles.size()==index,"Scheduled wave %d enters the existing native army"%index)
		check(absf(ui.wave_countdown.get_global_rect().get_center().x-ui.size.x*.5)<1,"Wave %d countdown remains centered after its text changes"%index)
		if index==2:check(game.model.balance.enemy_health_mult==game.core_balance.enemy_health_mult,"Scheduled waves retain next-wave balance updates")
		await capture("wave-%d"%index)
	check(ui.wave_countdown.text.contains("FINAL WAVE 4 / 4") and ui.wave_countdown.text.contains("TOTAL 01:00"),"The final wave retains its full one-minute timer")
	waves.tick(60,game.player.position);ui.sync()
	check(ui.wave_countdown.text.contains("CLEAR THE ENEMIES"),"The four-minute timer ends with the surviving enemies still active")
	await capture("timer-finished")
	var config=game.settings_path
	stop_audio(game);game.move_audio.stop();current_scene=null;game.queue_free();paused=false;await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config))

func capture(label_:String):
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label_+".png")
