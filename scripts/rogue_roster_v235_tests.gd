extends "res://scripts/fire_siege_controls_tests.gd"
## Real input, collision and damage checks for the approved roster update.

func run():
	Input.use_accumulated_input=false
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
	game.start_mode("defense");pause_fixture_director();game.encounters.choose_card("supply_cache")
	await frames(3)
	if not "--lifecycle-only" in OS.get_cmdline_user_args():
		await extended_primary_rules()
		await piercing_rules()
		await energy_rules()
		await jump_height_rules()
		await dive_rules()
	await lifecycle_rules()
	await bullet_cover_rules()
	game.show_main_menu();game.sound_library.cancel();game.music.stop()
	await frames(3)
	stop_audio(game)
	var shared_audio=game.get_node_or_null("RogueSharedClassAudio")
	if is_instance_valid(shared_audio):shared_audio.cache.clear()
	await frames(20)
	print("ROGUE_ROSTER_V235_RESULT checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)

func stop_audio(node: Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		node.stop();node.stream=null
	for child in node.get_children():stop_audio(child)

func wall_at(offset: Vector3)->StaticBody3D:
	var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
	var shape=CollisionShape3D.new();var box=BoxShape3D.new()
	box.size=Vector3(.5,18,20);shape.shape=box;wall.add_child(shape)
	game.add_child(wall);wall.global_position=game.player.global_position+offset
	return wall

func extended_primary_rules():
	var reaches=[2.85,3.3,2.45,28.0,4.8,6.2,3.5,20.0,2.65,4.8]
	for index in range(10):
		await fresh_class(index);var a=game.player.active_ability
		if index in [3,7]:
			var victim=fixture(Vector3(reaches[index]*2.3,0,0))
			var off_path: Ninja=null
			if index==7:seed(103) # A repeatable, slightly upward Ranger release.
			tap("light_attack")
			await frames(10)
			check(not a.projectiles.is_empty() and a.projectiles[0].life*a.projectiles[0].vel.length()>reaches[index]*2.7,"%s primary projectile travels three times its old range" % CLASS_IDS[index])
			if index==7 and not a.projectiles.is_empty():
				# Ranger deliberately scatters its release angle. Test actual long
				# flight and narrow contact along the visible shot, not perfect aim.
				var arrow: Dictionary=a.projectiles[0]
				var direction: Vector3=arrow.vel.normalized()
				var contact: Vector3=arrow.mesh.global_position+direction*46.0
				victim.global_position+=contact-AttackChain.aim_point(victim)
				var lateral=Vector3(-direction.z,0,direction.x).normalized()
				off_path=fixture(victim.global_position-game.player.global_position+lateral*3.0)
			await frames(230 if index==3 else 110)
			check(victim.hp<10000,"%s basic projectile damages a real target beyond twice its old range" % CLASS_IDS[index])
			if index==7:check(is_instance_valid(off_path) and off_path.hp==10000,"Ranger's long-travel arrow excludes a target beside its visible flight path")
		else:
			# Hand-placed fixtures sit inside the visible weapon stroke and well
			# beyond it. Do not derive either target from the attack's hit radius.
			var near=fixture(Vector3(2.4 if index in [5,6] else 1.5,0,0))
			var distant=fixture(Vector3(reaches[index]*2.3,0,0))
			tap("light_attack");await frames(42)
			check(near.hp<10000,"%s primary damages a real target inside its visible weapon stroke" % CLASS_IDS[index])
			check(distant.hp==10000,"%s primary cannot ghost-hit the former extended melee distance" % CLASS_IDS[index])
	await fresh_class(1);var a=game.player.active_ability
	tap("light_attack")
	var base_reach: float=a.player.attack.reach
	var base_weapon_scale: float=a.visual_actor.joints.Weapon_Cutlass.node.global_basis.get_scale().length()
	await fresh_class(1);a=game.player.active_ability
	for count in range(4):game.player.grow_from_building()
	var scale=game.player.range_multiplier()
	tap("light_attack")
	var weapon_growth: float=a.visual_actor.joints.Weapon_Cutlass.node.global_basis.get_scale().length()/base_weapon_scale
	check(absf(weapon_growth-scale)<.01 and absf(a.player.attack.reach/base_reach-weapon_growth)<.01,"Growth scales the visible weapon and melee contact together exactly once")
	a.cancel();a.player.cooldowns.flintlock=0;tap("heavy_attack")
	check(a.projectiles.size()==1 and a.projectiles[0].kind=="crimson-arrow" and is_equal_approx(a.projectiles[0].life*a.projectiles[0].vel.length(),28*scale),"Samurai's current secondary arrow receives growth once, without the primary range multiplier")
	await fresh_class(9)
	var wall=wall_at(Vector3(4,4,0));var hidden=fixture(Vector3(7,0,0));await frames(2)
	tap("light_attack");await frames(40)
	check(hidden.hp==10000,"Extended basic melee still respects solid cover")
	wall.queue_free();await frames(2)

func piercing_rules():
	for tier in range(5):
		await fresh_class(0 if tier==0 else 3);var a=game.player.active_ability
		var first=fixture(Vector3(3,0,0));var second=fixture(Vector3(6,0,0));var last=fixture(Vector3(9,0,0));var side=fixture(Vector3(6,0,5))
		if tier==0:tap("heavy_attack")
		else:
			press("light_attack");a.player.chargeTime=tier-1;press("light_attack",false)
		check(a.projectiles.size()==1 and a.projectiles[0].get("pierce",false),"%s releases one enemy-piercing projectile" % ("Pirate" if tier==0 else "Mage tier %d" % (tier-1)))
		if tier==0 and not a.projectiles.is_empty():
			check(a.projectiles[0].kind=="bullet" and is_equal_approx(a.projectiles[0].visualScale,10),"Pirate fires a visible bullet at ten times the old shot diameter")
		await frames(45)
		var damage=82 if tier==0 else [36,70,120,190][tier-1]
		check(is_equal_approx(first.hp,10000-damage) and is_equal_approx(second.hp,10000-damage) and is_equal_approx(last.hp,10000-damage) and side.hp==10000,"%s hits each aligned target once and excludes targets off the straight path" % ("Pirate" if tier==0 else "Mage tier %d" % (tier-1)))
		await fresh_class(0 if tier==0 else 3);a=game.player.active_ability
		var wall=wall_at(Vector3(4,4,0));var hidden=fixture(Vector3(7,0,0));await frames(2)
		if tier==0:tap("heavy_attack")
		else:
			press("light_attack");a.player.chargeTime=tier-1;press("light_attack",false)
		await frames(30)
		check(hidden.hp==10000 and a.projectiles.is_empty(),"Piercing projectile tier %d stops at terrain cover" % tier)
		wall.queue_free();await frames(2)

func complete_light(a):
	a.player.cooldowns.cutlass=0;tap("light_attack")
	await frames(23)

func energy_rules():
	for index in [2,8]:
		await fresh_class(index);var a=game.player.active_ability
		for count in range(5):
			await complete_light(a)
			check(a.player.get("energy",0)==(count+1)*20,"%s completed light %d charges exactly 20 energy" % [CLASS_IDS[index],count+1])
		await complete_light(a)
		check(a.player.get("energy",0)==100,"%s stores at most one free heavy" % CLASS_IDS[index])
		a.player.cooldowns.flintlock=2.0;tap("weapon_chain")
		check(a.player.dashAttack!=null and a.player.get("energy",0)==0 and is_equal_approx(a.player.cooldowns.flintlock,2),"%s key3 spends one full meter and bypasses rather than resets normal cooldown" % CLASS_IDS[index])
		await frames(34);a.player.cooldowns.flintlock=2;press("heavy_attack");await frames(160)
		check(a.player.dashAttack==null and a.player.roll<=0,"%s holding heavy does not repeat a free heavy" % CLASS_IDS[index])
		press("heavy_attack",false)
		await fresh_class(index);a=game.player.active_ability
		tap("light_attack");a.cancel();await frames(25)
		check(a.player.get("energy",0)==0,"%s cancelled light awards no energy" % CLASS_IDS[index])
		a.player.cooldowns.cutlass=1;tap("light_attack");await frames(25)
		check(a.player.get("energy",0)==0,"%s blocked light input awards no energy" % CLASS_IDS[index])
		a.player.cooldowns.flintlock=0;tap("heavy_attack");await frames(34)
		check(a.player.get("energy",0)==0 and a.player.cooldowns.flintlock>0,"%s normal heavy remains available without energy and earns none" % CLASS_IDS[index])
		for count in range(5):await complete_light(a)
		a.reset_run()
		check(a.player.get("energy",0)==0,"%s restart clears energy" % CLASS_IDS[index])

func measured_jump(index: int,second: bool)->float:
	await fresh_class(index)
	var p=game.player
	if second:
		game.reset_player_at(TEST_ORIGIN+Vector3.UP*30);await frames(2)
		p.jumps_used=1;p.coyote=0;p.velocity=Vector3.ZERO
	var start=p.position.y;var apex=start
	tap("jump")
	for count in range(100):
		await frames(1);apex=maxf(apex,p.position.y)
		if count>3 and p.velocity.y<=0:break
	return apex-start

func jump_height_rules():
	for second in [false,true]:
		var baseline=await measured_jump(0,second);var higher=await measured_jump(5,second)
		check(baseline>1 and absf(higher/baseline-2)<.09,"Dragoon %s jump has twice the measured clear-flight apex with unchanged gravity" % ("second" if second else "first"))

func dive_rules():
	await fresh_class(6);var p=game.player;var a=p.active_ability
	tap("jump");await frames(4);tap("light_attack")
	check(a.player.get("dive")==null and a.player.attack!=null,"Magic Swordsman first-jump light remains a normal swing")
	await fresh_class(6);a=p.active_ability
	tap("jump");await frames(6);tap("jump");await frames(6)
	var start=p.position;var victim=fixture(Vector3(7,-p.position.y+.06,0))
	tap("light_attack")
	check(a.player.get("dive")!=null and p.velocity.y< -20,"Double-jump light commits a fast downward Magic Swordsman dive")
	game.camera_rig.yaw=PI;p.smoke_move=Vector2.LEFT
	await frames(42);p.smoke_move=Vector2.ZERO
	check(p.position.x>start.x+2 and a.player.get("dive")==null,"Dive preserves committed forward direction and completes at landing")
	check(10000-victim.hp>=250,"Dive landing delivers massive area damage")
	var hp=victim.hp;await frames(24)
	check(victim.hp==hp,"Dive landing impact cannot damage a target twice")
	await fresh_class(6);a=p.active_ability
	game.reset_player_at(TEST_ORIGIN+Vector3.UP*8);await frames(2);p.jumps_used=2
	var wall=wall_at(Vector3(3,0,0));var hidden=fixture(Vector3(7,-8,0));await frames(2)
	tap("light_attack");await frames(40)
	check(p.position.x<TEST_ORIGIN.x+3 and hidden.hp==10000,"Dive body stops at cover and its impact cannot hit through the wall")
	wall.queue_free();await frames(2)
	await fresh_class(6);a=p.active_ability
	game.reset_player_at(TEST_ORIGIN+Vector3.UP*8);await frames(2);p.jumps_used=2
	tap("light_attack");a.cancel();await frames(50)
	check(a.player.get("dive")==null,"Cancelling an airborne dive clears the pending landing impact")

func lifecycle_rules():
	for index in [2,8]:
		await fresh_class(index);var p=game.player;var a=p.active_ability
		a.player.energy=100;tap("dodge");tap("weapon_chain")
		check(a.player.energy==100 and a.player.dashAttack==null,"%s blocked heavy preserves a full energy credit" % CLASS_IDS[index])
		await frames(26)
		check(a.player.energy==100 and a.player.dashAttack==null and a.player.secondaryBuffer==null,"%s expired press buffer cannot spend energy after evade" % CLASS_IDS[index])
		game.show_pause();tap("light_attack");tap("heavy_attack");game.resume()
		check(a.player.energy==100 and a.player.attack==null and a.player.dashAttack==null,"%s pause preserves earned energy and rejects attack inputs" % CLASS_IDS[index])
		press("heavy_attack");press("weapon_chain");await frames(34)
		check(a.player.energy==0 and a.player.dashAttack==null and a.player.cooldowns.flintlock==0,"%s simultaneous RMB and 3 spend one credit without queuing another heavy" % CLASS_IDS[index])
		press("heavy_attack",false);press("weapon_chain",false)
		a.player.energy=80;tap("heavy_attack")
		check(a.player.energy==80 and a.player.cooldowns.flintlock>0,"%s normal heavy preserves partial energy" % CLASS_IDS[index])
		await frames(34);press("heavy_attack")
		await complete_light(a)
		check(a.player.energy==100 and a.player.dashAttack==null,"%s reaching full energy while heavy is held does not auto-cast" % CLASS_IDS[index])
		press("heavy_attack",false)
		p.select_character(3);p.select_character(index+3)
		check(a.player.energy==0,"%s switching away and back clears energy" % CLASS_IDS[index])
		a.player.energy=100;game.encounters.hero_died()
		check(a.player.energy==0 and p.hp==0,"%s real siege death clears energy" % CLASS_IDS[index])
		game.encounters.runtime.revive_left=0;game.encounters.revive_now()
	await fresh_class(6);var p=game.player;var a=p.active_ability
	game.reset_player_at(TEST_ORIGIN+Vector3.UP*8);await frames(2);p.jumps_used=2
	tap("light_attack");var heading=a.player.dive.direction if a.player.get("dive")!=null else Vector3.ZERO
	game.camera_rig.yaw=PI;p.smoke_move=Vector2.LEFT;await frames(2)
	check(a.player.get("dive")!=null and a.player.dive.direction.is_equal_approx(heading) and p.velocity.x>20,"Dive commits its heading while camera and movement input change")
	tap("jump")
	check(p.jump_buffer==0,"Jump input during a committed dive cannot queue an automatic landing bounce")
	tap("dodge");tap("equip");tap("heavy_attack")
	check(a.player.get("dive")!=null and a.player.roll==0 and a.player.travel==null and a.player.cooldowns.flintlock==0,"A committed dive rejects evades and other attacks without queuing delayed movement")
	game.show_pause();game.resume();p.smoke_move=Vector2.ZERO
	check(a.player.get("dive")==null,"Pause cancellation discards a pending dive impact")
	await fresh_class(6);a=p.active_ability
	game.reset_player_at(TEST_ORIGIN+Vector3.UP*8);await frames(2);p.jumps_used=2
	var victim=fixture(Vector3(5,-8,0));tap("light_attack");p.select_character(3);await frames(40)
	check(a.player.get("dive")==null and victim.hp==10000,"Hero swap cannot leave a delayed dive landing hit")
	for index in [0,2,5,8]:
		await fresh_class(index);a=p.active_ability
		game.reset_player_at(TEST_ORIGIN+Vector3.UP*8);await frames(2);p.jumps_used=2;tap("light_attack")
		check(a.player.get("dive")==null,"%s cannot trigger Magic Swordsman's second-jump dive" % CLASS_IDS[index])

func bullet_cover_rules():
	for muzzle in [false,true]:
		await fresh_class(0);var a=game.player.active_ability
		var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
		var shape=CollisionShape3D.new();var box=BoxShape3D.new()
		box.size=Vector3(.3,1,6);shape.shape=box;wall.add_child(shape)
		game.add_child(wall);wall.global_position=game.player.global_position+Vector3(.85 if muzzle else 4,.5,0)
		var hidden=fixture(Vector3(7,0,0));await frames(2)
		tap("heavy_attack");await frames(25)
		check(hidden.hp==10000 and a.projectiles.is_empty(),"Pirate's enlarged round bullet respects low cover %s" % ("at its muzzle" if muzzle else "along its travel"))
		wall.queue_free();await frames(2)
