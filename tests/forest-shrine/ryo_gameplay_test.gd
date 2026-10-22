extends SceneTree
var game
var checks=0
var failures=0
var cfg="user://ryo-gameplay-%d.cfg"%OS.get_process_id()
func _initialize():
	create_timer(150).timeout.connect(func():printerr("FAIL: ryo gameplay timeout");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func frames(count:int=3):
	for i in count:await physics_frame
func run():
	var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original()
	set_meta("forest_custom_layout",doc.data);set_meta("forest_army_backend","legacy")
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
	await frames()
	var m=game.model;var p=game.player
	check(m.buildings.values().all(func(b):return b.kind!="mine") and m.deposits.is_empty(),"Playable saved maps contain no gold mines or deposits")
	check(not game.forest_ui.build_bar.get_children().any(func(b):return "Gold mine" in b.text),"The build menu does not offer mines")
	check("kills pay automatically" in game.forest_ui.gold_count.tooltip_text,"The treasury tooltip describes automatic rewards")
	check(m.get("ryo")!=null,"The live run owns the bounty ledger")
	if m.get("ryo")==null:await finish();return
	game.start_wave();m.waves.spawn_clock=10000;game.set_physics_process(false);p.set_physics_process(false)
	p.position=Vector3(0,.15,60)
	var gold=m.gold
	var victim=m.waves.spawn_enemy(0,Vector3(0,0,68))
	m.damage_enemy(victim.id,100000)
	check(m.gold==gold+12 and m.ryo.drops.is_empty(),"A real model kill immediately credits twelve ryo without loot")
	game.sync_enemies();await frames()
	check(m.gold==gold+12,"Actor synchronization cannot duplicate the kill bounty")
	for i in range(20):game._tick_ryo(.05)
	check(m.gold==gold+12 and m.ryo.pending_bounty_total==0,"HUD feedback drains without paying twice")
	var distant=m.waves.spawn_enemy(3,Vector3(100,0,100));m.damage_enemy(distant.id,100000)
	check(m.gold==gold+24,"Distant kills pay immediately without a collector")
	game.show_pause();game._tick_ryo(1)
	check(m.gold==gold+24,"Pause preserves the paid balance")
	game.resume();game._tick_ryo(11)
	check(m.gold==gold+24 and m.ryo.drops.is_empty(),"Rewards never expire or create ground money")
	check(not is_instance_valid(game.ryo_visuals),"The playable game allocates no coin renderer")
	# A lingering player projectile still rewards the kill without reviving the player.
	var target=m.waves.spawn_enemy(0,Vector3(0,0,68));game.sync_enemies();await frames()
	p.invuln=0;p.hp=1;game.tuning.invincible=false;p.take_hit(100000,Vector3.RIGHT)
	game.actors[target.id].take_hit(100000,Vector3.FORWARD,false,{})
	check(p.hp<=0 and game.respawn_left>0,"A kill during respawn cannot heal the dead player back to life")
	check(m.gold==gold+36 and m.ryo.drops.is_empty(),"Player-attributed damage credits exactly one bounty during respawn")
	game._tick_ryo(1)
	check(m.gold==gold+36,"Feedback during respawn cannot duplicate rewards")
	game._tick_player_respawn(4)
	m.phase="preparing";game.set_phase_view()
	check(m.gold==gold+36,"Paid money survives the wave transition")
	game.preview_forest_map(doc.data,false)
	check(game.model.ryo.drops.is_empty() and game.model.ryo.claimed_enemies.is_empty(),"Starting a fresh map resets the bounty ledger")
	check(game.model.deposits.is_empty() and game.model.buildings.values().all(func(b):return b.kind!="mine"),"Loading another playable map still omits mines")
	await finish()
func finish():
	print("RYO_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures])
	game.queue_free();paused=false;await frames()
	if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	quit(1 if failures else 0)
