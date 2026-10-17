extends SceneTree
## Actual Forest combat facades: early input, contact, recovery and kit identity.
const ORIGIN=Vector3(0,.1,70)
const IDS=[3,4,5,7,8,9,12]
var game
var checks=0
var failures=0
var config_path="user://melee-responsiveness-%d.cfg"%OS.get_process_id()
func _initialize():
	create_timer(60).timeout.connect(func():printerr("FAIL: melee responsiveness timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func frames(n: int=3):
	for i in range(n):await physics_frame
func fresh(id: int):
	for actor in game.actors.values():
		if is_instance_valid(actor):actor.queue_free()
	game.actors.clear();game.enemies.clear();game.model.enemies.clear()
	game.player.select_character(id);game.player.cancel_charge(true)
	game.player.position=ORIGIN;game.player.velocity=Vector3.ZERO
	game.player.attack_chain.reset();game.player.invuln=0;game.player.hp=game.player.max_hp
	game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
	if id>2:
		var c=game.player.active_ability;c.reset_run();c.player.pos=ORIGIN;c.aim=ORIGIN+Vector3.FORWARD*20
	await frames()
	game.player.velocity=Vector3.DOWN*10;game.player.move_and_slide();game.player.velocity=Vector3.ZERO
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
	await frames();game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.tuning.critical_chance=0;game.character_tuning={};game.tuning.invincible=false
	var actions=preload("res://assets/rogue/scripts/class_actions.gd")
	for id in IDS:
		await fresh(id)
		var c=game.player.active_ability;c.action("cutlass")
		var first: Dictionary=c.player.attack
		check(first.contact<=.095,"%s produces contact within 95 ms"%c.class_id)
		var original: Dictionary=c.COMBO[0] if id==3 else actions.PRIMARY[c.class_id]
		if id==4:original=actions.SAMURAI_CUTS[0].merged(actions.PRIMARY.samurai,false)
		check(is_equal_approx(first.duration,original.duration) and first.damage==original.damage,"%s retains base damage and sustained attack cadence"%c.class_id)
		first.time=first.contact;c.visual_actor.animate_pose(c.player,0,0,0)
		check(c.visual_actor.joints.Weapon_Cutlass.node.global_transform.origin.is_finite(),"%s contact pose remains valid"%c.class_id)
		if "--visual" in OS.get_cmdline_user_args():
			for pose in ["windup","contact","follow"]:
				first.time=first.contact*.5 if pose=="windup" else (first.contact if pose=="contact" else first.contact+(first.duration-first.contact)*.22)
				c._animate(0,0);await shot(c.class_id+"-"+pose)
		# Queue a short second tap early in the first stroke, then release it.
		first.time=.015;c.action("cutlass");c.primary_held=false
		for i in range(ceili((first.duration+.04)/.005)):
			c.tick(.005)
		check(c.player.attack!=null and c.player.attack.index==1,"%s consumes an early tap once after recovery"%c.class_id)
		for i in range(150):c.tick(.005)
		check(c.player.attack==null and c.attack_buffer<=0,"%s does not repeat a released queued tap"%c.class_id)
		c.action("cutlass");var a: Dictionary=c.player.attack
		game.player.invuln=0;c.player.invuln=0
		a.time=maxf(0,a.contact-.01);var hp=game.player.hp
		game.player.take_hit(10,Vector3.RIGHT)
		check(game.player.hp==hp,"%s briefly protects the committed contact"%c.class_id)
		a.time=a.duration-.03;game.player.invuln=0;c.player.invuln=0
		game.player.take_hit(10,Vector3.RIGHT)
		check(game.player.hp<hp,"%s remains vulnerable during recovery"%c.class_id)
		c.hit_stop=0;game.player.invuln=0;c.player.invuln=0;c.player.attack=a;c.action("cutlass");c.standard_evade()
		check(c.player.attack==null and c.attack_buffer==0,"%s evasion cancels both swing and queued follow-up"%c.class_id)
	# All five Samurai strokes and the heavier three-hit finishers survive.
	for id in IDS:
		await fresh(id);var c=game.player.active_ability;var count=5 if id==4 else 3;var strokes=[];var damage=[];var duration=[]
		for stage in count:
			c.attack();var a: Dictionary=c.player.attack;strokes.append(a.index);damage.append(a.damage);duration.append(a.duration)
			check(a.contact<=.12,"%s stage %d has a readable, responsive windup"%[c.class_id,stage+1])
			c.tick(a.duration+.001)
		check(strokes==range(count),"%s preserves its complete combo sequence"%c.class_id)
		check(damage.back()>damage[0] and duration.back()>duration[0],"%s retains a stronger, more deliberate finisher"%c.class_id)
	await fresh(4);var samurai=game.player.active_ability;samurai.player.buffTime=10
	for stage in range(5):
		samurai.attack();var a: Dictionary=samurai.player.attack
		check(a.contact<=actions.SAMURAI_CUTS[stage].contact/5.0+.000001,"Samurai Overdrive never gains a slower windup (%d)"%stage)
		a.time=a.duration-.002;game.player.invuln=0;samurai.player.invuln=0
		check(not samurai.protects_player(),"Samurai Overdrive retains vulnerable recovery (%d)"%stage)
		samurai.tick(a.duration+.001)
	# Secondary attacks keep their own contact, travel and recovery rules.
	await fresh(9);var swordsman=game.player.active_ability;swordsman.action("flintlock")
	check(swordsman.player.attack.style=="energy-wave" and is_equal_approx(swordsman.player.attack.contact,.12) and not swordsman.player.attack.get("responsiveMelee",false),"Magic Swordsman's energy wave retains its separate release")
	await fresh(8);var dragoon=game.player.active_ability;dragoon.action("flintlock")
	check(dragoon.player.attack.style=="dragoon-sweep" and is_equal_approx(dragoon.player.attack.contact,.22) and not dragoon.player.attack.get("responsiveMelee",false),"Dragoon retains his three-hit lance sweep timing")
	dragoon.action("cutlass");dragoon.primary_held=false
	for i in range(180):dragoon.tick(.005)
	check(dragoon.player.attack==null and dragoon.attack_buffer<=0,"An early released tap during a special keeps its original expiry")
	# Resolve actual contact against a fitted Forest raider, not just a timer.
	for id in IDS:
		await fresh(id);var c=game.player.active_ability;c.attack();var a: Dictionary=c.player.attack
		var data=game.model.waves.spawn_enemy(0,game.player.position+c.front(a.angle)*2.2)
		data.hp=10000;data.max_hp=10000;data.stun=100
		game.sync_enemies();game.actors[data.id].set_physics_process(false);game.actors[data.id]._sync_fitted_pose();game.model.update_vision(game.player.position)
		c.tick(a.contact-.001,false)
		check(data.hp==10000,"%s cannot damage before its retimed contact"%c.class_id)
		c.tick(.002,false)
		check(data.hp<10000,"%s real weapon connects on its retimed contact"%c.class_id)
		check(c.hit_stop<=.045001 and game.actors[data.id].impact_pause>=.04,"%s retains enemy impact while keeping attacker pause short"%c.class_id)
	await fresh(11);var explorer=game.player.active_ability;explorer.attack()
	check(is_equal_approx(explorer.player.attack.contact,.055) and is_equal_approx(explorer.player.attack.duration,.23) and explorer.player.attack.damage==19,"Explorer reference timing and damage remain unchanged")
	var first_side=explorer.player.attack.swingSide;explorer.tick(.3);explorer.attack()
	check(explorer.player.attack.swingSide==-first_side,"Explorer retains alternating evasive slashes")
	await fresh(10);var ranger=game.player.active_ability;ranger.attack()
	check(is_equal_approx(ranger.player.attack.contact,.11/3) and ranger.player.attack.damage==67,"Ranger projectile cadence and damage remain unchanged")
	await fresh(1);var hero=game.player
	hero.start_attack(false,1)
	# Expose the actual contact phase used by physics and the articulated pipe.
	check(hero.has_method("attack_contact_phase"),"Goemon shares a contact phase between gameplay and animation")
	if hero.has_method("attack_contact_phase"):
		for stage in range(1,4):
			hero.start_attack(false,stage)
			check(hero.attack_contact_phase()*hero.attack_duration<=.12,"Goemon pipe stage %d contacts within 120 ms"%stage)
			check(is_equal_approx(hero.model.pipe_contact_phase,hero.attack_contact_phase()),"Goemon stage %d visual and damage contact agree"%stage)
			if "--visual" in OS.get_cmdline_user_args():
				hero.attack_left=hero.attack_duration*(1-hero.attack_contact_phase())
				hero.model.pipe_combo_active=true;hero.model.rogue_pipe_combo_active=false
				hero.model.animate(0,0,true,0,hero.attack_left/hero.attack_duration,false,stage,false);hero.model.sync_skeleton()
				await shot("goemon-stage-%d-contact"%stage)
			hero.attack_left=hero.attack_duration*(1-hero.attack_contact_phase());hero.invuln=0;var hp=hero.hp
			hero.take_hit(10,Vector3.RIGHT);check(hero.hp==hp,"Goemon pipe stage %d protects its contact"%stage)
	game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("MELEE_RESPONSIVENESS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func shot(name_: String):
	var directory=OS.get_environment("SONIC_MELEE_CAPTURE_DIR")
	if directory.is_empty():directory="/tmp/sonic-melee-poses"
	DirAccess.make_dir_recursive_absolute(directory)
	game.camera_rig.camera.global_position=game.player.position+Vector3(5,3.4,6)
	game.camera_rig.camera.look_at(game.player.position+Vector3.UP*1.1)
	game.forest_ui.notify(name_)
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory+"/"+name_+".png")
