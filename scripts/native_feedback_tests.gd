extends SceneTree
var game
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if ok:print("PASS: ",message)
	else:failures+=1;push_error(message)
func meshes(node: Node)->Array:
	var out=[]
	if node is MeshInstance3D:out.append(node)
	for child in node.get_children():out.append_array(meshes(child))
	return out
func feedback_since(before: Array)->Array:
	var out=[]
	for child in game.get_children():
		if child not in before:out.append_array(meshes(child))
	return out
func frames(count: int):
	for i in range(count):await physics_frame
func run():
	game=load("res://scenes/main.tscn").instantiate();game.smoke_test=true;root.add_child(game)
	game.tuning.freeze_ai=true;game.tuning.invincible=true;game.start_mode("defense")
	game.encounters.set_physics_process(false);game.kennel.set_physics_process(false);game.barracks.set_physics_process(false)
	game.encounters.update_start_input(0,false);game.encounters.update_start_input(3.1,true);game.encounters._spawn_due(24)
	game.player.smoke_mode=true
	for e in game.enemies:e.hp=10000;e.max_hp=10000;e.set_physics_process(false)
	for quality in [0,1,2]:
		game.settings.quality=quality;await frames(35)
		var before=game.get_children();var health=[]
		for e in game.enemies:health.append(e.hp)
		for e in game.enemies:
			e.take_hit(10,Vector3.FORWARD,true)
			game.confirm_impact(e,e.global_position,Vector3.FORWARD,2,false)
		var all_damaged=true
		for i in game.enemies.size():all_damaged=all_damaged and is_equal_approx(game.enemies[i].hp,health[i]-10)
		check(all_damaged,"All 24 victims retain exactly ten damage with native feedback budgeting at quality %d" % quality)
		var visuals=feedback_since(before)
		check(visuals.size()<=[3,8,12][quality]*9,"Native impacts cap presentation per frame at quality %d" % quality)
		for i in range(10):
			await frames(1)
			for j in range(24):game.impact_effect(Vector3.ZERO,Vector3.FORWARD,2)
		check(feedback_since(before).size()<=[12,24,36][quality]*9,"Native impacts bound concurrent scene geometry at quality %d" % quality)
		await frames(35)
		check(feedback_since(before).is_empty(),"Native impacts release their geometry at quality %d" % quality)
		before=game.get_children();game.burst(Vector3.ZERO,Color.ORANGE,100)
		visuals=feedback_since(before)
		check(visuals.size()<=[12,24,36][quality],"Native particle bursts cap allocation per frame at quality %d" % quality)
		var no_shadows=true
		for visual in visuals:no_shadows=no_shadows and visual.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		check(no_shadows,"Native feedback particles do not add shadow passes at quality %d" % quality)
		for i in range(10):
			await frames(1);game.burst(Vector3.ZERO,Color.ORANGE,100)
		check(feedback_since(before).size()<=[48,96,144][quality],"Native burst geometry stays bounded under repeated contacts at quality %d" % quality)
		await frames(40)
		check(feedback_since(before).is_empty(),"Native burst geometry releases after its animation at quality %d" % quality)
	game.sound_library.cancel();game.music.stop();game.queue_free();await frames(4)
	print("NATIVE_FEEDBACK_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
