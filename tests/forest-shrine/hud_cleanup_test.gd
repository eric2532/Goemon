extends SceneTree
# Catches stale hero art/health after switching and unwanted HUD clutter.
var failures=0
var checks=0
var game
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	create_timer(45).timeout.connect(func():printerr("FAIL: HUD timeout");quit(1))
	run.call_deferred()
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://hud-cleanup-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
	await process_frame;await process_frame
	var ui=game.forest_ui
	check(ui.get("player_health_bar") is ProgressBar,"Selected character has a visible health bar")
	check(ui.find_child("HeroPortrait",true,false) is TextureRect,"Selected character has a portrait")
	check(ui.find_child("EnemyHub",true,false)==null,"Enemy-count panel is absent during preparation")
	if failures:await finish();return
	game.set_process(false)
	game.player.hp=37;ui.sync()
	check(ui.player_health_bar.value==37 and ui.player_health_bar.max_value==game.player.max_hp,"Health bar follows live player health")
	var previous=null
	for id in range(1,13):
		game.show_rogue_roster();game.choose_rogue_character(id);ui.sync();await process_frame
		check(ui.hero_portrait.texture!=null and ui.hero_portrait.texture!=previous,"Portrait changes with selected fighter %d"%id)
		previous=ui.hero_portrait.texture
		check(ui.primary_icon.texture!=null and ui.secondary_icon.texture!=null,"Both main attack icons exist for fighter %d"%id)
		check(ui.player_health_bar.max_value==game.player.max_hp,"Health maximum follows fighter %d"%id)
		check(not "LMB" in ui.hint.text and not "Q " in ui.hint.text,"Switching fighter %d does not restore control paragraphs"%id)
	game.player.select_character(3);ui.sync()
	check(ui.primary_icon.texture.resource_path.ends_with("/sword.svg") and ui.secondary_icon.texture.resource_path.ends_with("/flintlock.svg"),"Pirate hub shows his actual attacks")
	game.model.wave=2;game.start_wave();game.model.waves.spawn_clock=10000;ui.sync()
	check(ui.find_child("EnemyHub",true,false)==null,"Starting combat does not restore enemy counts")
	game.model.phase="preparing";ui.sync();await process_frame
	check(not ui.hero_dock.get_global_rect().intersects(ui.bar_paper.get_global_rect()),"Character hub stays clear of preparation controls")
	game.model.workers.values()[0].state="wounded";ui.sync()
	check(ui.worker_count.text==str(game.model.workers.size()-1) and ui.gold_count.text==ui.skin.format_gold(game.model.gold),"Resource icons follow available workers and treasury")
	for node in game.world.structure_nodes.values():
		check(node.find_children("*","Label3D",true,false).is_empty(),"Structures have no floating name labels")
	await finish()
func finish():
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
	await process_frame;await create_timer(.35).timeout
	print("FOREST_HUD_CLEANUP_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
