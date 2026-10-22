extends SceneTree
## Automatic bounties must not scan or animate collectors, even under sustained kills.
class CountedGame extends "res://scripts/forest/forest_game.gd":
	var collector_snapshots=0
	func _ryo_collectors()->Array:
		collector_snapshots+=1
		return super._ryo_collectors()
class CountedEconomy extends "res://scripts/forest/forest_ryo_economy.gd":
	var collector_cells=0
	func _collector_cell(point:Vector3)->Vector2i:
		collector_cells+=1
		return super._collector_cell(point)
var game
var checks=0
var failures=0
var cfg="user://ryo-idle-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func frames():
	for i in 3:await process_frame
func run():
	var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original()
	set_meta("forest_custom_layout",doc.data);set_meta("forest_army_backend","legacy")
	game=CountedGame.new();game.settings_path=cfg;root.add_child(game);current_scene=game
	await frames();AudioServer.set_bus_mute(0,true)
	game.set_process(false);game.set_physics_process(false)
	game.model.ryo=CountedEconomy.new(game.model)
	var r=game.model.ryo
	var rows:Array=[]
	for count_ in [240,600,2000]:
		game.model.defenders.clear()
		for i in count_:game.model.defenders[-10000-i]={"id":-10000-i,"pos":Vector3(i%40*3,0,int(i/40)*3),"hp":100}
		game.collector_snapshots=0;r.collector_cells=0
		var gold:int=game.model.gold
		var started=Time.get_ticks_usec()
		for i in 120:
			r.award_enemy_bounty({"id":count_*1000+i,"hp":0,"variant":0})
			game._tick_ryo(1.0/60)
		rows.append({"allies":count_,"tick_us":(Time.get_ticks_usec()-started)/120.0})
		check(game.collector_snapshots==0,"Sustained kills skip collector snapshots with %d allies"%count_)
		check(r.collector_cells==0,"Sustained kills create no collector spatial cells with %d allies"%count_)
		check(r.elapsed==0,"No physical-loot simulation runs with %d allies"%count_)
		check(game.model.gold==gold+120*12,"Every kill pays its full bounty with %d allies"%count_)
		check(r.drops.is_empty() and r.expiry_events.is_empty() and r.moving_drops.is_empty(),"No pickup or expiry allocations with %d allies"%count_)
	print("RYO_IDLE_PROFILE ",JSON.stringify(rows))
	game.model.defenders.clear()
	check(not is_instance_valid(game.ryo_visuals),"The live game creates no coin renderer")
	game.ryo_feedback_left=0;r.award_enemy_bounty({"id":90001,"hp":0,"variant":0})
	var gold:int=game.model.gold
	game.ordinary_pause=true;game._tick_ryo(.2)
	check(r.pending_bounty_total==12 and game.model.gold==gold,"Pause retains feedback without delaying the balance")
	game.ordinary_pause=false;game._tick_ryo(.02)
	check(r.pending_bounty_total==0 and game.ryo_feedback_left>0,"Resuming drains audible reward feedback once")
	game._tick_ryo(.2)
	check(game.model.gold==gold and game.collector_snapshots==0,"Feedback never pays twice or captures collectors")
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	print("RYO_IDLE_WORK_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
