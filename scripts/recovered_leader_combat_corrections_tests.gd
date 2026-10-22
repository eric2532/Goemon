extends "res://scripts/recovered_leaders_tests.gd"
## Regression: hold beam, three distinct Ben attacks, correct source throw poses.
func event(action: String,pressed: bool=true)->InputEventAction:
	var e=InputEventAction.new();e.action=action;e.pressed=pressed;return e
func projectiles()->Array:
	return get_nodes_in_group("leader_projectiles").filter(func(p):return not p.is_queued_for_deletion())
func clear_projectiles():
	for p in get_nodes_in_group("leader_projectiles"):p.free()
func run():
	game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="user://leader-corrections-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(5)
	game.begin_forest();game.choose_rogue_character(15);game.start_wave()
	game.tuning.invincible=true;game.tuning.freeze_ai=true;game.tuning.critical_chance=0;game.character_tuning={}
	await frames(10)
	var p=game.player;p.set_physics_process(false)
	p.position=Vector3(0,.05,18);p.velocity=Vector3.DOWN;p.move_and_slide();p.velocity=Vector3.ZERO
	var c=p.active_ability
	p._unhandled_input(event("equip"))
	check("source_14" in c.clip,"Ben E starts the original ground projectile-throw animation")
	c.tick(.34)
	check(projectiles().size()==3,"Ben E releases the ROM's three-projectile fan at frame10")
	if projectiles().size()==3:
		var shots=projectiles()
		check(shots.all(func(s):return s.get("shuriken")==true and not s.bomb),"Ben's E fan uses distinct four-point projectiles, not bombs")
		check(absf(rad_to_deg(shots[0].velocity.normalized().angle_to(shots[2].velocity.normalized()))-45)<1,"The E fan preserves the original45-degree total spread")
	check(SoundLibrary.moves_for(15).has("utility"),"Ben's third move has its own studio weapon and voice slots")
	c.cancel();clear_projectiles()
	p._unhandled_input(event("heavy_attack"))
	check("source_18" in c.clip,"Grounded Ben begins the ROM propeller deployment before bombing")
	c.tick(.2)
	check(projectiles().is_empty(),"Ben does not throw while opening his propeller on the ground")
	check(c.bomb_vertical_velocity(1.0/60.0,false,false)<=0,"The original deployment holds ground until tick14")
	c.tick(.3)
	check(c.bomb_vertical_velocity(1.0/60.0,false,false)>0,"Bomb deployment lifts Ben into his original airborne attack")
	c.tick(.3)
	check(c.bomb_phase=="barrage" and "source_19" in c.clip,"The ascent transitions into the original source19 barrage")
	c.tick(.6);c.tick(.9)
	check(projectiles().size()>=5,"Holding Ben RMB releases many bombs within the first1.5seconds")
	if not projectiles().is_empty():
		check(projectiles()[0].find_child("SourceBombSprite",true,false) is Sprite3D,"Bombs display the recovered blue-bomb sprite")
	var count=projectiles().size();p._unhandled_input(event("heavy_attack",false));c.tick(.8)
	check(projectiles().size()==count,"Releasing Ben RMB stops additional bombs")
	check(c.bomb_phase=="land" and "source_17" in c.clip,"Release returns Ben through his original descent and retraction")
	c.cancel();clear_projectiles();c.input(event("heavy_attack"));c.input(event("heavy_attack",false));c.tick(2.0)
	check(projectiles().size()==1,"A quick RMB tap still completes its first bomb throw")
	c.cancel();clear_projectiles();c.input(event("heavy_attack"));c.tick(6.0)
	check(projectiles().size()==20,"The complete held bomb pattern releases the original twenty targets")
	var targets=[]
	for shot in projectiles():
		if not targets.has(shot.bomb_target):targets.append(shot.bomb_target)
	check(targets.size()==20,"The bomb barrage uses twenty distinct source grid destinations")
	c.cancel();clear_projectiles();p._unhandled_input(event("light_attack"));c.tick(.35)
	check(not p.attack_heavy and not c.clip.is_empty() and projectiles().is_empty(),"Ben LMB retains a separate polearm attack")
	c.cancel();c.start_attack(false);c.input(event("equip"));c.input(event("heavy_attack"));c.tick(3.0)
	check(c.mode=="bombs","A newer RMB request replaces an earlier queued E fan")
	c.cancel();p._unhandled_input(event("heavy_attack"));c.tick(.6);count=projectiles().size()
	c._notification(NOTIFICATION_APPLICATION_FOCUS_OUT);c.tick(1)
	check(projectiles().size()==count and not c.is_attacking(),"Focus loss cancels the held bomb barrage")
	clear_projectiles();c.cancel();p.select_character(14);c=p.active_ability
	p._unhandled_input(event("light_attack"));c.tick(.04)
	check("source_06" in c.clip,"Ed uses the original looping beam pose")
	c.tick(.31)
	var beam=c.get("beam")
	check(is_instance_valid(beam),"Holding Ed LMB creates a sustained beam effect")
	if is_instance_valid(beam):
		var ticket=p.attack_ticket;c.tick(2)
		check(c.is_attacking() and c.get("beam")==beam and p.attack_ticket==ticket,"Ed holds one cast continuously beyond several source-animation loops")
		check(beam.length_now>9 and beam.is_visible_in_tree(),"Ed's source-sized beam stays visibly active")
		p._unhandled_input(event("light_attack",false))
		check(not beam.active and not c.is_attacking(),"Releasing LMB immediately stops Ed's damaging attack")
		beam.set_process(false);p.model.animate(0,0,true,0,0,false,0,false)
		check(p.model.state=="release" and "source_06" in p.model.current_clip,"Normal release retains Ed's original crossed-arm source06 pose")
		# The held age is2.35s, deliberately between source06's16-tick loops.
		check(is_zero_approx(p.model.animation_player.current_animation_position),"8017E4AC resets source06 to its first pose when normal release begins")
		beam._process(15.0/30.0);c.tick(0);p.model.animate(0,0,true,0,0,false,0,false)
		check(beam.releasing and "source_06" in p.model.current_clip,"The casting pose remains through the fifteenth source release tick")
		check(is_equal_approx(p.model.animation_player.current_animation_position,.5),"The restarted source06 advances through its own fifteen release ticks")
		beam._process(1.0/30.0);c.tick(0);p.model.animate(0,0,true,0,0,false,0,false)
		check(not beam.releasing and "source_05" in p.model.current_clip,"The sixteenth release tick transitions Ed into original source05 recovery")
		c.start_attack(false);c.tick(.2);var interrupted=c.beam;c.finish_attack(true);c.start_attack(true)
		check(not interrupted.releasing and c.mode=="fireballs","A new attack can immediately interrupt the visual release")
	c.cancel();p._unhandled_input(event("light_attack"));c.tick(.35);p.select_character(1)
	check(not c.is_attacking() and not is_instance_valid(c.get("beam")),"Switching heroes cancels Ed's held beam")
	stop_audio(game);game.move_audio.stop();current_scene=null;game.queue_free();await frames(3)
	await create_timer(.35).timeout
	print("LEADER_COMBAT_CORRECTIONS_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
