extends SceneTree
var game
var checks=0
var failures=0
func _initialize():
	create_timer(90).timeout.connect(func():printerr("FAIL: enemy contact timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func frames(n: int=3):
	for i in range(n):await physics_frame
func press(action: String,down: bool=true):
	var event=InputEventAction.new();event.action=action;event.pressed=down;Input.parse_input_event(event);Input.flush_buffered_events()
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game;await frames()
	game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0;game.tuning.invincible=true
	# This fixture counts only the giant; the visible immortal dummy is tested separately.
	game.enemies.erase(game.training_dummy)
	game.set_physics_process(false);game.player.set_physics_process(false)
	var point=Vector3(0,0,70)
	var data={"id":9999,"variant":2,"pos":point,"hp":3000.0,"max_hp":3000.0,"velocity":Vector3.ZERO,"stun":0.0,"attack":false,"clock":0.0,"facing":0.0,"action":"windup","action_left":1.2,"attack_progress":.2,"walk_phase":0.0}
	game.model.enemies[data.id]=data;game.sync_enemies();var actor=game.actors[data.id];actor.set_physics_process(false)
	game.player.position=point+Vector3(4.65,0,-6);game.player.facing=Vector3.BACK;game.model.update_vision(game.player.position)
	check(actor.has_method("combat_segment_hit"),"Forest actors expose fitted compound segment contact")
	if actor.has_method("combat_segment_hit"):
		check(actor.combat_segment_hit(point+Vector3(4.65,1,-5),point+Vector3(4.65,1,-1),.1),"Low melee/projectile sweep hits the visible giant right foot")
		check(actor.combat_segment_hit(point+Vector3(0,12,-12),point+Vector3(0,12,0),.1),"Airborne shot hits the actual giant shell")
		check(not actor.combat_segment_hit(point+Vector3(0,1,-5),point+Vector3(0,1,0),.1),"Shot through empty gap between feet does not hit a giant root capsule")
		check(not actor.combat_segment_hit(point+Vector3(14,12,-12),point+Vector3(14,12,0),.1),"Shot outside shell and fists misses")
		var aim: Vector3=actor.combat_aim_point(game.player.position+Vector3.UP)
		check(aim.y<point.y+3 and aim.distance_to(game.player.position+Vector3.UP)<4,"Ground hero aim reaches visible lower hurt geometry")
		var ability=game.player.active_ability
		game.player.select_character(4);ability=game.player.active_ability
		var snapshots: Array=ability.living()
		check(snapshots.size()==1 and snapshots[0].pos.distance_to(game.player.position)<4,"Native melee snapshots use nearby giant foot rather than distant root")
		var hit_targets: Array=ability._segment_targets(point+Vector3(4.65,1,-5),point+Vector3(4.65,1,-1),.1)
		check(hit_targets.size()==1,"Native projectile broadphase admits giant lower foot")
		check(ability._segment_targets(point+Vector3(0,1,-5),point+Vector3(0,1,0),.1).is_empty(),"Native projectile narrowphase rejects empty foot gap")
	var before: float=data.hp
	actor.take_hit(100,Vector3.RIGHT,true,{"tower":true,"tower_feedback":false})
	check(is_equal_approx(actor.hp,before-100) and is_equal_approx(data.hp,before-100),"Giant normal damage reduces authoritative HP exactly once")
	check(actor.stun==0 and data.stun==0,"Giant ignores routine flinch")
	check(data.get("knockback",Vector3.ZERO).length()<=1.501,"Giant ordinary heavy knockback is reduced by ninety percent")
	actor.freeze_for(2)
	check(data.frozen==2 and data.action_left==1.2,"Freeze preserves giant pending windup")
	data.hp-=18;actor._physics_process(.016)
	check(is_equal_approx(actor.hp,data.hp),"Tower-authoritative damage synchronization does not apply combo bonuses or duplicate HP loss")
	if actor.has_method("combat_contact_point"):
		check(actor.bar.position.y<6,"Giant health bar remains near visible lower body")
	var from=point+Vector3(20,10,-15)
	game.model.workforce.arrows[888]={"id":888,"from":from,"pos":from,"target":data.id,"age":0.0}
	game.model.workforce.tick_arrows(1.0)
	var impacts: Array=game.model.events.filter(func(event):return event.kind=="arrow_impact" and event.id==888)
	check(impacts.size()==1,"Tower arrow reaches and applies one fitted contact")
	if impacts.size()==1:check(impacts[0].to.distance_to(point+Vector3.UP)>5,"Tower feedback occurs on visible giant shell instead of root plus one")
	# Real primary inputs for all twelve kits against the exported giant foot.
	game.player.set_physics_process(true);game.camera_rig.set_process(false);game.camera_rig.yaw=PI
	for hero_id in ([] if "--contact-fast" in OS.get_cmdline_user_args() else range(1,13)):
		press("light_attack",false);game.player.select_character(hero_id)
		game.player.position=point+Vector3(4.65,.1,-5.3);game.player.velocity=Vector3.ZERO
		game.player.facing=Vector3.BACK;game.player.attack_left=0;game.player.impact_pause=0
		game.player.attack_chain.reset()
		if game.player.active_ability!=null and game.player.active_ability.has_method("reset_run"):game.player.active_ability.reset_run()
		if game.player.musashi!=null:game.player.musashi.cancel()
		data.hp=3000.0;actor.hp=3000.0;data.frozen=0.0;actor.frozen_left=0.0;data.action="walk";data.attack_progress=0.0
		actor._sync_fitted_pose();game.model.update_vision(game.player.position)
		game.camera_rig.camera.global_position=game.player.position+Vector3(.65,2.4,-10)
		game.camera_rig.camera.look_at(point+Vector3(4.65,1.1,-2.5))
		press("light_attack");await frames(70);press("light_attack",false);await frames(30)
		check(data.hp<3000.0,"Hero %d real primary damages visible giant foot"%hero_id)
	if "--visual" in OS.get_cmdline_user_args():
		game.player.select_character(1);game.player.position=point+Vector3(4.65,.1,-5.3)
		game.camera_rig.camera.global_position=game.player.position+Vector3(.65,3.4,-10)
		game.camera_rig.camera.look_at(point+Vector3(4.65,3,-1))
		game.crowd._process(0)
		print("CONTACT_NATIVE_DIAGNOSTIC playing=",game.playing," paused=",game.paused," transition=",game.transitioning," actor=",actor.global_position," visible=",game.forest_enemy_visible(actor)," batch=",game.crowd.batches[2].multimesh.visible_instance_count," bounds=",game.crowd.batches[2].multimesh.custom_aabb)
		await frames(5);await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.superpowers/sdd/2026-10-14-forest-enemy-integration")
		root.get_texture().get_image().save_png("res://.superpowers/sdd/2026-10-14-forest-enemy-integration/task3-contact-native.png")
	game.show_pause();game.queue_free();paused=false;await frames();await create_timer(.35).timeout
	print("FOREST_ENEMY_CONTACT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
