extends SceneTree
# Catches lost health feedback, stale cooldowns and currency formatting at boundaries.
var game
var checks=0
var failures=0
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize():
	create_timer(45).timeout.connect(func():printerr("FAIL: HUD polish timeout");quit(1))
	run.call_deferred()
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://hud-polish-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
	await process_frame;await process_frame
	var ui=game.forest_ui
	game.set_process(false);game.set_physics_process(false)
	check(ui.gold_count.text=="1,000,000","Large treasury groups digits for readability")
	check(ui.get("health_trail") is ProgressBar,"Damage feedback has a trailing health bar")
	if failures:await finish();return
	ui.set_process(false)
	for entry in [[0,"0"],[999,"999"],[1000,"1,000"],[1000001,"1,000,001"]]:
		game.model.gold=entry[0];ui.sync();check(ui.gold_count.text==entry[1],"Currency updates correctly at %d"%entry[0])
	game.player.hp=100;ui.sync();ui._process(0)
	var healthy=ui.player_health_bar.get_theme_stylebox("fill").bg_color
	game.player.hp=20;ui.sync();ui._process(0)
	check(ui.player_health_bar.value==20 and ui.health_trail.value==100,"Damage updates health immediately while preserving its recent extent")
	var danger=ui.player_health_bar.get_theme_stylebox("fill").bg_color
	check(danger.r>danger.g and danger!=healthy,"Critical health visibly changes to red")
	ui._process(.15);check(ui.health_trail.value>20,"Damage trail remains briefly readable")
	game.show_pause();var trail_before=ui.health_trail.value;ui._process(1.0)
	check(ui.health_trail.value==trail_before,"Pausing preserves the damage animation")
	game.resume()
	ui._process(1.1);check(is_equal_approx(ui.health_trail.value,20),"Old damage trail clears after its short animation")
	game.player.hp=80;ui.sync();check(ui.health_trail.value==80,"Healing snaps the damage trail up without a ghost deficit")
	game.show_rogue_roster();game.choose_rogue_character(3);ui.sync()
	var portrait=ui.hero_portrait.texture
	game.player.active_ability.player.cooldowns.flintlock=1.0;ui.sync()
	check(ui.cooldown_masks[1].visible and ui.secondary_icon.modulate.a<1,"Spent secondary attack is visibly unavailable")
	game.player.active_ability.player.cooldowns.flintlock=0;ui.sync()
	check(not ui.cooldown_masks[1].visible and is_equal_approx(ui.secondary_icon.modulate.a,1),"Ready attack restores its icon")
	ui.sync();check(ui.hero_portrait.texture==portrait,"Unchanged fighter reuses its portrait texture")
	game.show_rogue_roster();game.choose_rogue_character(7);ui.sync()
	check(ui.hero_portrait.texture!=portrait and ui.health_trail.value==game.player.hp,"Switching fighter resets portrait and health feedback together")
	for entry in [[1,false],[2,true]]:
		game.player.select_character(entry[0]);game.player.attack_left=.3;game.player.attack_duration=.6;game.player.attack_heavy=entry[1];ui.sync()
		check(ui.cooldown_masks[1 if entry[1] else 0].visible,"Native fighter %d shows its real attack recovery"%entry[0])
	game.player.attack_left=0;ui.sync()
	check(not ui.cooldown_masks[0].visible and not ui.cooldown_masks[1].visible,"Native attack recovery clears without stale masks")
	game.player.active_ability.shield_left=1;game.player.active_ability.start_beam();ui.sync()
	check(ui.attack_cooldowns[0].text.is_empty() and ui.attack_cooldowns[1].text.is_empty() and not ui.cooldown_masks[0].visible and not ui.cooldown_masks[1].visible,"Sustained Edo beam never invents a frozen recovery countdown")
	check(is_equal_approx(ui.secondary_icon.modulate.a,1),"Edo's interrupting secondary remains visibly ready during his beam")
	game.player.active_ability.stop_hold_beam();ui.sync()
	check(is_equal_approx(ui.primary_icon.modulate.a,1) and ui.attack_cooldowns[0].text.is_empty(),"Releasing the beam restores the ordinary primary display")
	await finish()
func finish():
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
	await process_frame;await create_timer(.35).timeout
	print("FOREST_HUD_POLISH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
