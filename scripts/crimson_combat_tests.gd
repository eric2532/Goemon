extends "res://scripts/rogue_equipment_combat_tests.gd"
## Real input/contact/pose tests: missing fifth cut, doubled speed scaling,
## repeated piercing damage, or interrupted buffs must fail these fixtures.
func run():
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true;game.player.smoke_mode=true
	game.start_mode("defense");pause_fixture_director();await frames(3)
	await combo_rules()
	await arrow_rules()
	await ultimate_rules()
	await damage_feedback_rules()
	game.show_main_menu();game.sound_library.cancel();game.music.stop();stop_audio(game)
	await frames(5)
	print("CRIMSON_COMBAT_RESULT checks=",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)

func damage_label_count()->int:
	var count=0
	for child in game.get_children():
		if child is Label3D:count+=1
	return count

func damage_feedback_rules():
	await fresh_class(1);await frames(50)
	var targets=[]
	for i in range(24):targets.append(fixture(Vector3(2,0,float(i)*.05)))
	var original_quality=game.settings.quality
	for quality in [1,0,2]:
		game.settings.quality=quality;await frames(50)
		var before=targets[0].hp
		for target in targets:target.take_hit(10,Vector3.RIGHT,false)
		var damaged=true
		for target in targets:damaged=damaged and target.hp<before
		check(damaged,"All 24 crowd victims retain real damage with quality %d feedback budgeting" % quality)
		check(damage_label_count()<=([3,8,12][quality]),"Crowd damage numbers are bounded per frame at quality %d" % quality)
		for i in range(20):
			await frames(1)
			for target in targets:target.take_hit(1,Vector3.RIGHT,false)
		check(damage_label_count()<=([16,32,48][quality]),"Sustained crowd contacts bound live number labels at quality %d" % quality)
		await frames(50)
		check(damage_label_count()==0,"Crowd feedback expires cleanly at quality %d" % quality)
	game.settings.quality=original_quality

func combo_rules():
	await fresh_class(1)
	var p=game.player;var a=p.active_ability
	var poses=[]
	for stage in range(6):
		a.player.cooldowns.cutlass=0;tap("light_attack")
		var cut=a.player.attack
		check(cut!=null and cut.index==stage%5,"Samurai advances cut %d through a five-hit combo" % (stage+1))
		if cut==null:continue
		var actor=p.model.actor;var pose=a.player.duplicate(true)
		pose.attack.time=pose.attack.contact
		actor.animate_pose(pose,0,0,0)
		if stage<5:poses.append(actor.model.global_transform.affine_inverse()*actor.joints.Weapon_Cutlass.node.global_transform)
		if stage==4:
			var axis=actor.global_basis.inverse()*(actor.joints.Weapon_Cutlass.node.global_basis*actor.WEAPON_AXES.samurai)
			check(axis.normalized().dot(Vector3.BACK)>.85,"Finisher sword contact matches the forward damage and VFX hemisphere")
			pose.attack.time=pose.attack.duration*.82
			actor.animate_pose(pose,0,0,0)
			check(absf(actor.model.rotation.y)>2.8 and absf(actor.model.rotation.y)<3.3,"Fifth cut visibly turns the body 180 degrees")
		for frame in range(100):
			await frames(1)
			if a.player.attack==null:break
		check(a.player.attack==null,"Each committed cut finishes without leaving combat locked")
	var unique=true
	for i in poses.size():
		for j in range(i):
			unique=unique and (poses[i].origin.distance_to(poses[j].origin)>.02 or not poses[i].basis.is_equal_approx(poses[j].basis))
	check(unique and poses.size()==5,"All five cuts have distinct actual sword poses")
	await fresh_class(1);a=p.active_ability;a.combo=4;a.combo_timer=1
	var left=fixture(Vector3(1,0,5));var right=fixture(Vector3(1,0,-5));var behind=fixture(Vector3(-5,0,0))
	tap("light_attack");await frames(50)
	check(left.hp<10000 and right.hp<10000 and behind.hp==10000,"Half-turn finisher hits both forward sides and excludes targets behind")
	await fresh_class(1);a=p.active_ability
	p.set_auto_attack(true)
	var maximum=0
	for i in range(160):
		await frames(1)
		maximum=maxi(maximum,a.combo)
	check(maximum==5,"Automatic Samurai primary reaches the fourth and fifth cuts")
	p.set_auto_attack(false)

func arrow_rules():
	await fresh_class(1)
	var a=game.player.active_ability
	var first=fixture(Vector3(6,0,0));var next=fixture(Vector3(10,0,0));var side=fixture(Vector3(6,0,3))
	tap("heavy_attack")
	check(a.projectiles.size()==1 and a.projectiles[0].kind=="crimson-arrow","Right click launches a red energy arrow")
	if not a.projectiles.is_empty():
		check(a.projectiles[0].mesh.scale.x>=3 and a.projectiles[0].color.r>.8 and a.projectiles[0].color.g<.2,"Energy arrow is huge and crimson")
	await frames(35)
	check(is_equal_approx(first.hp,9850) and is_equal_approx(next.hp,9850) and side.hp==10000,"Energy arrow pierces aligned enemies once each without damaging distant side targets")
	await frames(150)
	check(a.projectiles.is_empty(),"Missed or piercing energy arrows have a finite lifetime")
	await fresh_class(1);a=game.player.active_ability
	var wall=obstacle(Vector3(3,1,0),Vector3(.4,4,4));await frames(2)
	var protected=fixture(Vector3(6,0,0));tap("heavy_attack");await frames(40)
	check(protected.hp==10000 and a.projectiles.is_empty(),"Solid cover stops the huge energy arrow")
	wall.queue_free()

func ten_cuts_time(a)->float:
	var count=0;var elapsed=0.0
	a.primary_held=true
	while count<10 and elapsed<10:
		var before=a.player.attack
		a.tick(.001)
		if before!=null and before.time>=before.duration:count+=1
		elapsed+=.001
	a.primary_held=false
	return elapsed

func ultimate_rules():
	await fresh_class(1)
	var p=game.player;var a=p.active_ability
	p.set_physics_process(false)
	var base=ten_cuts_time(a)
	a.reset_run();tap("surge")
	check(a.player.buffTime>9.9 and a.player.attack==null,"Ultimate activates a ten-second speed buff rather than a draw-cut")
	var fast=ten_cuts_time(a)
	check(absf(fast/base-.2)<.006,"Ultimate repeats the same five cuts at five times base cadence (%.3fs vs %.3fs)" % [fast,base])
	p.set_physics_process(true)
	await frames(3)
	check(p.model.actor.ultimate_aura.visible,"Active ultimate displays the actual crimson aura")
	a.player.cooldowns.flintlock=2.4;a.player.cooldowns.roll=1.2
	a.tick_timers(.1)
	check(is_equal_approx(a.player.cooldowns.flintlock,2.3) and is_equal_approx(a.player.cooldowns.roll,1.1),"Overdrive keeps secondary and utility cooldown rates unchanged")
	game.show_pause();var remaining=a.player.buffTime;var clock=p.model.actor.ultimate_aura.clock;await frames(20)
	check(is_equal_approx(a.player.buffTime,remaining) and p.model.actor.ultimate_aura.clock==clock,"Pause freezes the speed buff and aura shader clock")
	game.resume();pause_fixture_director()
	a.player.buffTime=.001;await frames(25)
	check(a.player.buffTime==0 and not p.model.actor.ultimate_aura.visible,"Expiration removes the ultimate aura and restores normal speed")
	a.cancel();a.player.cooldowns.drink=0;tap("surge");p.select_character(3)
	check(a.player.buffTime==0 and not a.visual_actor.ultimate_aura.visible,"Switching heroes clears Samurai's speed buff and aura")
	await fresh_class(1);a=p.active_ability;tap("surge")
	game.encounters.hero_died()
	check(a.player.buffTime==0,"Death clears the Samurai ultimate")
	game.encounters.runtime.revive_left=0;game.encounters.revive_now();p.hp=p.max_hp
