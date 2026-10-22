extends SceneTree
## Pure clock tests: no scenes, meshes, or imported assets are loaded.
var failures: Array[String] = []
var checks := 0
var combat: Script

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func events_of(events: Array, kind: String) -> Array:
	return events.filter(func(event): return event.kind == kind)

func run_attack(role: int, dt: float, context: Dictionary = {}) -> Array:
	var enemy = {"variant": role}
	combat.begin(enemy)
	var events: Array = []
	for step in range(1000):
		events.append_array(combat.advance(enemy, dt, context))
		if not combat.active(enemy): break
	return events

func _initialize() -> void:
	if not ResourceLoader.exists("res://scripts/forest/forest_thirstquencher_combat.gd"):
		check(false, "Soldier attack clock must exist before source event timing can run")
		quit(1); return
	combat = load("res://scripts/forest/forest_thirstquencher_combat.gd")
	if combat == null: quit(1); return
	# A skipped frame/event, incorrect shot cadence, or lost residual time breaks these fixtures.
	for dt in [1.0/60.0, 1.0/30.0, 1.0/20.0, 10.0]:
		var red = run_attack(0, dt)
		var red_hits = events_of(red, "melee")
		check(red_hits.size() == 2, "Red performs two melee attacks at dt=%s" % dt)
		if red_hits.size() == 2:
			check(red_hits[0].source_tick == 13.0 and red_hits[1].source_tick == 44.0, "Red source contact ticks are 13 and 44")
			check(red_hits[0].local_from == Vector3(0,-30,0) and red_hits[0].local_to == Vector3(0,-30,-80) and red_hits[0].damage == 11, "Melee uses original root-space segment and damage")
		check(events_of(red,"done").size() == 1 and red.back().source_tick == 54.0, "Red carries residual time through 20+10+24 ticks")
		var blue = run_attack(1, dt)
		var bullets = events_of(blue, "bullet")
		var flashes = events_of(blue, "muzzle")
		check(bullets.size() == 3 and flashes.size() == 3, "Blue fires exactly three bullets and flashes")
		if bullets.size() == 3:
			check(bullets[0].source_tick == 18.0 and bullets[1].source_tick == 48.0 and bullets[2].source_tick == 78.0, "Blue projectile ticks are 18,48,78")
			check(bullets[0].damage == 25, "Blue uses original bullet base damage25")
			check(bullets[0].local_origin == Vector3(0,-80,-48), "Gun socket uses original actor root-space origin")
		if flashes.size() == 3: check(flashes[0].source_tick == 15.0 and flashes[2].source_tick == 75.0, "Muzzle effects precede projectile events by three ticks")
		check(blue.back().source_tick == 120.0, "Blue finishes three shots and 30-tick reload")
		var green = run_attack(3, dt)
		check(events_of(green, "melee").size() == 1 and events_of(green, "bullet").is_empty() and green.back().source_tick == 20.0, "Green thrusts once without inventing javelin projectiles")
	var boundary = {"variant": 3}
	combat.begin(boundary)
	check(combat.advance(boundary, (13.0 - 0.0000001) / 30.0).is_empty(), "Contact does not occur just before its source tick")
	check(events_of(combat.advance(boundary, 0.0000002 / 30.0),"melee").size() == 1, "A tiny interval crossing the exact contact emits once")
	check(events_of(combat.advance(boundary, 0.0000002 / 30.0),"melee").is_empty(), "Contact does not duplicate just after its source tick")
	var no_combo = run_attack(0, 10.0, {"continue_combo": false})
	check(events_of(no_combo,"melee").size() == 1 and no_combo.back().source_tick == 20.0, "Red follow-up can stop when target is no longer close")
	var enemy = {"variant": 1}
	combat.begin(enemy); combat.advance(enemy, 0.5)
	check(enemy.soldier_clip == "Source__801b0d50" and enemy.soldier_tick == 15.0, "Renderer receives source clip and independent pose clock")
	combat.cancel(enemy)
	check(not combat.active(enemy) and combat.advance(enemy, 10.0).is_empty(), "Cancellation prevents pending bullets")
	combat.begin(enemy)
	var restarted = combat.advance(enemy, 10.0)
	check(events_of(restarted,"bullet").size() == 3 and events_of(restarted,"muzzle").size() == 3, "Restart clears previous attack event history")
	for role in [2,4]:
		var giant = {"variant":role}; combat.begin(giant)
		check(not combat.active(giant) and combat.advance(giant,10.0).is_empty(), "Giant and boss stay outside ordinary soldier attack clock")
	print("THIRSTQUENCHER_COMBAT_TESTS ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
