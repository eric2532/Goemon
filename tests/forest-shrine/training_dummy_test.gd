extends SceneTree
# The target must accept real attacks forever without entering wave accounting.
var game
var checks=0
var failures=0
var config_path="user://training-dummy-%d.cfg"%OS.get_process_id()
func _initialize():
	create_timer(60).timeout.connect(func():printerr("FAIL: training dummy timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func frames(n: int=3):
	for i in range(n):await physics_frame
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await frames()
	var dummy=game.get_node_or_null("TrainingDummy")
	check(dummy is Ninja,"A hittable training dummy exists in the playable forest")
	if dummy==null:await finish();return
	var home: Vector3=dummy.position
	check(home.distance_to(game.model.center(game.model.shrine()))<20 and home.length()>10,"Dummy stands beside the shrine with space to approach")
	check(dummy.visible and dummy.training_dummy and dummy.practice,"Dummy is visible during building and marked as a practice target")
	check(game.enemies.has(dummy) and game.model.enemies.is_empty(),"Combat can target the dummy without counting a wave enemy")
	var label=dummy.find_child("DummyLabel",true,false)
	check(label is Label3D and "∞" in label.text,"Dummy clearly displays infinite health")
	check(not game.model.placement_error("tower",game.model.cell_of(home),0).is_empty(),"Construction cannot cover the dummy")
	if "--visual" in OS.get_cmdline_user_args():await shot("building")
	game.start_wave();game.model.waves.spawn_clock=10000;game.set_physics_process(false);game.player.set_physics_process(false);await frames()
	game.player.select_character(1);game.tuning.critical_chance=0;game.character_tuning={}
	check(not AttackChain.segment_contact(dummy,home+Vector3(0,2.7,4),home+Vector3(0,2.7,-4),.05).is_empty(),"A projectile aimed at the dummy's head hits its full-height collider")
	check(AttackChain.segment_contact(dummy,home+Vector3(2,2.7,4),home+Vector3(2,2.7,-4),.05).is_empty(),"Projectiles outside the dummy still miss")
	var kills=game.kills;var hp=dummy.hp;var player_hp=game.player.hp
	for amount in [1.0,100.0,1000000000000.0]:
		var ticket=game.player.attack_chain.begin("pipe")
		dummy.take_hit(amount,Vector3.RIGHT,true,ticket)
		check(not dummy.dead and dummy.hp==hp and is_finite(dummy.hp) and dummy.collision_layer==4,"Even a lethal hit preserves a finite, alive, targetable dummy (%s)"%amount)
		check(dummy.recoil_age==0 and game.player.attack_chain.count==0,"Goemon hits still trigger reaction without the retired attack-chain bonuses")
	await frames(90)
	check(dummy.position.is_equal_approx(home) and dummy.velocity==Vector3.ZERO,"Repeated heavy hits cannot move the dummy")
	check(game.kills==kills and game.player.hp==player_hp,"Dummy grants no kills or kill healing and never retaliates")
	dummy.freeze_for(.1);await frames(15)
	check(not dummy.dead and dummy.frozen_left<=0 and not dummy.frozen_visual.visible,"Freeze expires without disabling the target")
	# Real primary paths cover native pipe/fireballs plus all ten Rogue kits.
	for id in range(1,13):
		game.player.select_character(id);var p=game.player;p.cancel_charge(true);p.attack_chain.reset();dummy.reset_pose()
		p.position=home+Vector3(0,.1,6 if id in [2,6,10] else 2);p.velocity=Vector3.DOWN*10;p.move_and_slide();p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD
		game.model.update_vision(p.position);game.camera_rig.set_process(false)
		game.camera_rig.camera.global_position=p.position+Vector3(0,3,10);game.camera_rig.camera.look_at(home+Vector3.UP*1.2)
		if id==1:
			p.start_attack(false,1);p.attack_left=p.attack_duration*(1-p.attack_contact_phase());p.strike()
		elif id==2:
			p.model.animate(0,0,true,0,0,false,1,false);p.model.sync_skeleton()
			p.musashi.cast_fireball(false);p.musashi.launch();await frames(45)
		else:
			var c=p.active_ability;c.reset_run();c.player.pos=p.position;c.aim=home+Vector3.UP*1.1;c.attack();c.primary_held=false
			if id==6:
				var release=InputEventAction.new();release.action="light_attack";release.pressed=false;c.release_input(release)
			for i in range(160):c.tick(.005)
		check((dummy.recoil_age==0 and p.attack_chain.count==0) if id==1 else p.attack_chain.count>0,"Fighter %d's actual primary attack connects with the dummy"%id)
		check(not dummy.dead and dummy.hp==hp and dummy.position.is_equal_approx(home),"Fighter %d leaves the dummy ready for another hit"%id)
		if id==11 and "--visual" in OS.get_cmdline_user_args():
			p.position=home+Vector3(-2,.1,3);p.active_ability.player.pos=p.position;p.active_ability._animate(0,0)
			game.camera_rig.camera.global_position=home+Vector3(6,4,9);game.camera_rig.camera.look_at(home+Vector3.UP*1.5)
			dummy.reset_pose();await frames(40);await shot("combat")
	# A normal enemy still takes damage; only the practice target is immortal.
	var e=game.model.waves.spawn_enemy(0,Vector3(0,0,75));game.sync_enemies()
	var enemy=game.actors[e.id];var before=e.hp;enemy.take_hit(10,Vector3.RIGHT,false,{"tower":true})
	check(e.hp==before-10,"Normal wave enemies still lose health")
	game.model.enemies.clear();game.model.waves.pending=0;game.model.waves.tick(.01,game.player.position)
	check(game.model.phase=="preparing","An immortal dummy cannot prevent wave completion")
	game.set_phase_view();await frames()
	check(game.get_node("TrainingDummy")==dummy and game.enemies.has(dummy),"Returning to preparation keeps exactly the same dummy registered")
	game.start_wave();await frames()
	check(game.get_node("TrainingDummy")==dummy and game.enemies.count(dummy)==1,"Next wave keeps one target without duplication")
	game.show_rogue_roster();game.choose_rogue_character(7);await frames()
	check(game.get_node("TrainingDummy")==dummy and not dummy.dead,"Switching characters preserves the dummy")
	await finish()
func shot(label: String):
	for i in range(3):await process_frame
	await RenderingServer.frame_post_draw
	var folder=OS.get_environment("SONIC_DUMMY_CAPTURE_DIR")
	if folder.is_empty():folder="/tmp"
	root.get_texture().get_image().save_png(folder+"/training-dummy-"+label+".png")
func finish():
	game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	game.queue_free();paused=false;await frames();await create_timer(.35).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("TRAINING_DUMMY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
