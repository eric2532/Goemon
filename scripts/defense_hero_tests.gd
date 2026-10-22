extends "res://scripts/defense_dog_tests.gd"

var hero_ids=["sen","raku","izumi","gaku","shiro","banji","touma","roan","nagi","kuren"]
var hero_asset_rows=[]

func capture_defense(label: String):
	await capture_beta(label)

func capture_beta(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/defense-heroes/"+label+".png")

func hero_setup():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/defense-heroes"))
	await dog_setup()
	game.barracks.set_physics_process(false)

func summon_hero_fixture(id: String):
	var barracks=game.barracks
	barracks.tick(barracks.cooldown_left+.01)
	if not barracks.summon(id):
		check(false,"Fixture can summon "+id+": "+barracks.reason(id));return null
	var ally=barracks.heroes[-1];ally.set_physics_process(false)
	return ally

func hero_assets_and_pose():
	await hero_setup();var b=game.barracks
	var definitions=DefenseHeroCatalog.definitions()
	check(definitions.size()==10 and definitions.map(func(profile):return profile.id)==hero_ids,"The humanoid catalog contains all ten characters from the GitHub concept pack")
	check(definitions.all(func(profile):return profile.cost==300 and profile.hp==500 and profile.damage==50 and profile.speed==7 and is_equal_approx(profile.attack_duration,1.18)),"All ten first-pass profiles share the stated price, health, movement and Goemon-combo timing")
	var actors=await owned_targets("runner",1);var target=actors[0];var hashes={}
	for profile in definitions:
		b.reset();b.begin();b.set_physics_process(false);await frames(2)
		check(ResourceLoader.exists(profile.asset) and ResourceLoader.exists(profile.portrait),"%s has its imported humanoid model and roster portrait" % profile.name)
		if not ResourceLoader.exists(profile.asset):continue
		hashes[FileAccess.get_sha256(profile.asset)]=true
		var ally=await summon_hero_fixture(profile.id);ally.position=Vector3(0,.15,79.5)
		var model=ally.model;var skeleton=model.skeleton;var meshes=0;var triangles=0;var skinned=0
		for node in model.rig_visual.find_children("*","MeshInstance3D",true,false):
			if node.mesh==null:continue
			meshes+=1
			if node.skin!=null:skinned+=1
			for surface in range(node.mesh.get_surface_count()):
				var arrays=node.mesh.surface_get_arrays(surface);var indices=arrays[Mesh.ARRAY_INDEX]
				triangles+=(indices.size() if indices!=null and indices.size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
		var bones=[]
		for index in range(skeleton.get_bone_count()):bones.append(String(skeleton.get_bone_name(index)))
		check(model is HeroModel and model.locomotion is HeroLocomotion and meshes>0 and skinned>0 and ["Root","Pelvis","Chest","Arm_R","Forearm_R","Hand_R","Leg_L","Shin_L","Foot_L"].all(func(bone):return bones.has(bone)),"%s uses the actual Goemon model/locomotion controller and a skinned articulated rig" % profile.name)
		var clips=["Idle","Walk","Run","Sprint","Back_Walk","Back_Run","Strafe_L_Walk","Strafe_L_Run","Strafe_R_Walk","Strafe_R_Run","JumpStart","JumpLoop","Fall","Land"]
		check(clips.all(func(clip):return model.locomotion.player.has_animation(clip)),"%s retains every authored gait and air clip required by Goemon's shared controller" % profile.name)
		var before=scene_pose(model);target.hp=10000
		check(ally.begin_attack(target),"%s can start the production three-hit combo against a real owned raider" % profile.name)
		ally.tick(.10)
		var shared=PipeCombo.sample(ally.combo_stage,ally.combo_clock)
		check(pose_matches(model.pipe_combo_pose,shared) and scene_pose(model)!=before and ally.hits_landed==1 and is_equal_approx(10000-target.hp,50),"%s applies the shared Goemon pose to moving bones and lands the first real 50-damage contact" % profile.name)
		hero_asset_rows.append({"id":profile.id,"source_sha256":FileAccess.get_sha256(profile.asset),"meshes":meshes,"skinned_meshes":skinned,"triangles":triangles,"bones":bones.size(),"combo_duration":ally.attack_duration()})
	check(hashes.size()==10,"The ten humanoid designs use distinct exported model files")
	FileAccess.open("res://tests/defense-heroes/asset-qa.json",FileAccess.WRITE).store_string(JSON.stringify(hero_asset_rows,"\t"))

func pose_matches(actual: Dictionary,expected: Dictionary)->bool:
	if actual.size()!=expected.size():return false
	for key in expected:
		if not actual.has(key):return false
		if expected[key] is Vector3:
			if not actual[key].is_equal_approx(expected[key]):return false
		elif not is_equal_approx(float(actual[key]),float(expected[key])):return false
	return true

func hero_rosters_and_lifecycle():
	await tactics_setup();var s=game.encounters;var b=game.barracks;var k=game.kennel
	b.set_physics_process(false);k.set_physics_process(false)
	await key(KEY_H)
	check(game.paused and s.phase=="draft" and not b.menu_open and not k.menu_open and game.menu.find_children("DefenseCard_*","Button",true,false).size()==3,"H preserves the mandatory three-card draft")
	check(not b.summon("sen") and not k.summon("kogane"),"Neither companion roster can bypass the mandatory wave choice")
	s.choose_card("supply_cache");var money=s.money
	check(b.living_count()==0 and k.living_count()==0 and b.cooldown_left==0 and k.cooldown_left==0,"A fresh run starts both separate companion rosters empty and ready")
	check(not b.summon("not_a_hero") and s.money==money,"An invalid humanoid ID cannot spend gold or spawn an actor")
	await move_to(Vector3(65,0,-250));await key(KEY_H)
	check(game.paused and get_tree().paused and b.menu_open and not k.menu_open and game.menu.find_children("HeroSummon_*","Button",true,false).size()==10,"Physical H opens a paused roster of all ten humanoid characters")
	check(game.menu.find_child("HeroRosterClose",true,false)!=null and game.menu.find_children("DogSummon_*","Button",true,false).is_empty(),"The H roster has its own close button and distinct humanoid purchase controls")
	await key(KEY_G)
	check(game.paused and k.menu_open and not b.menu_open and game.menu.find_children("DogSummon_*","Button",true,false).size()==10,"G switches from the paused humanoid roster to the original ten-dog roster")
	await key(KEY_H)
	check(game.paused and b.menu_open and not k.menu_open and game.menu.find_children("HeroSummon_*","Button",true,false).size()==10,"H switches back from dogs without resuming or duplicating a roster")
	await click_named_button("HeroRosterClose")
	check(not game.paused and not b.menu_open and s.money==money,"The real humanoid close button resumes battle without spending gold")
	await key(KEY_H);await capture_beta("01-ten-hero-roster")
	await click_named_button("HeroSummon_sen")
	check(b.living_count()==1 and k.living_count()==0 and s.money==money-300 and not game.paused and not b.menu_open,"A real Sen roster click purchases one humanoid for 300 gold and resumes battle")
	var ally=b.heroes[0];ally.set_physics_process(false)
	check(ally.profile_id=="sen" and ally.position.z>=200 and absf(ally.position.x)<6 and ally.position.distance_to(game.player.position)>400,"A summoned humanoid emerges behind the castle gateway instead of beside a distant player")
	check(not game.enemies.any(func(actor):return actor==ally) and game.active_enemy_count()==0 and ally.model.visible,"A humanoid remains visibly independent of the enemy roster and live-enemy capacity")
	var hero_cooldown=b.cooldown_left
	await key(KEY_G);await click_named_button("DogSummon_kogane")
	var dog=k.dogs[0];dog.set_physics_process(false)
	check(b.living_count()==1 and k.living_count()==1 and b.cooldown_left==hero_cooldown and is_equal_approx(k.cooldown_left,3),"Dogs can be summoned during the separate humanoid cooldown")
	money=s.money
	check(not b.summon("raku") and not k.summon("daigo") and s.money==money,"Each roster blocks repeated purchases on its own cooldown without extra charges")
	game.show_pause();b.tick(10);k.tick(10);ally.tick(10);dog.tick(10);await key(KEY_H)
	check(game.paused and not b.menu_open and not k.menu_open and b.cooldown_left==hero_cooldown and k.cooldown_left==3,"Ordinary pause freezes both rosters and H cannot replace it with a purchasing menu")
	game.resume();b.tick(2.99)
	check(not b.can_summon("raku") and b.cooldown_left>0 and k.cooldown_left==3,"The humanoid cooldown runs for the full three simulation seconds independently of the kennel")
	b.tick(.02);s.money=299
	check(not b.summon("raku") and s.money==299 and b.living_count()==1,"Insufficient gold rejects a humanoid purchase without mutating the roster")
	s.money=money
	for id in hero_ids.slice(1,8):await summon_hero_fixture(id)
	for id in expected_ids.slice(1,8):await summon_fixture(id)
	check(b.living_count()==8 and k.living_count()==8 and b.heroes.size()==8 and k.dogs.size()==8,"Eight humanoids and eight dogs coexist in distinct bounded companion rosters")
	b.tick(3.01);k.tick(3.01);money=s.money
	check(not b.summon("nagi") and not k.summon("mine") and s.money==money,"Each full eight-ally roster rejects its own ninth purchase")
	var kills=s.wave_kills;var xp=game.player.progression.total_kills
	ally.take_hit(1000000,Vector3.ZERO)
	check(ally.dead and b.living_count()==7 and k.living_count()==8 and s.money==money and s.wave_kills==kills and game.player.progression.total_kills==xp,"A humanoid death releases only its own slot and awards no enemy bounty or hero XP")
	check(b.summon("nagi") and b.living_count()==8 and k.living_count()==8,"A fallen humanoid can be replaced without affecting the dog pack")
	var retired=b.heroes.duplicate()+k.dogs.duplicate();game.restart_area();s=game.encounters
	s.set_physics_process(false);b.set_physics_process(false);k.set_physics_process(false)
	check(retired.all(func(actor):return not is_instance_valid(actor) or (actor.dead and not actor.visible and not actor.is_physics_processing())) and b.living_count()==0 and k.living_count()==0,"Retry immediately retires both companion populations and cancels their attacks")
	check(s.phase=="draft" and b.cooldown_left==0 and k.cooldown_left==0,"Retry resets both summon cooldowns before the mandatory opening draft")
	await frames(3)
	check(retired.all(func(actor):return not is_instance_valid(actor)),"Retired dog and humanoid scene trees are disposed after retry")
	s.choose_card("supply_cache");ally=await summon_hero_fixture("sen");dog=await summon_fixture("kogane")
	s.base_hp=0;game.defeat();await frames(3)
	check(not is_instance_valid(ally) and not is_instance_valid(dog) and b.living_count()==0 and k.living_count()==0 and not b.can_summon("sen") and not k.can_summon("kogane"),"Shrine defeat disposes both ally types and blocks new summons")
	await hero_setup();ally=await summon_hero_fixture("sen");dog=await summon_fixture("kogane");game.defense_victory();await frames(3)
	check(game.won and not is_instance_valid(ally) and not is_instance_valid(dog) and not b.can_summon("sen"),"Victory retires both populations and cannot be bypassed through H")
	await hero_setup();ally=await summon_hero_fixture("sen");dog=await summon_fixture("kogane");game.show_main_menu();await frames(3)
	check(not is_instance_valid(ally) and not is_instance_valid(dog) and not b.active and not k.active,"Returning to the main menu clears both companion systems")
	game.start_mode("survival");game.encounters.set_physics_process(false);await key(KEY_H);await key(KEY_G)
	check(not b.menu_open and not k.menu_open and not b.can_summon("sen") and not k.can_summon("kogane"),"H and G cannot summon castle companions in the original survival mode")

func hero_combat_and_route():
	await hero_setup();var actors=await owned_targets("runner",1);var target=actors[0]
	var ally=await summon_hero_fixture("sen");ally.position=Vector3(0,.15,79.5)
	var hp=target.hp;ally.begin_attack(target);ally.tick(.094)
	check(target.hp==hp and ally.hits_landed==0,"The humanoid combo does not damage before Goemon's first authored contact")
	var age=ally.attack_age;var pose=ally.model.pipe_combo_pose.duplicate(true)
	game.show_pause();ally.tick(10);await frames(3)
	check(ally.attack_age==age and ally.model.pipe_combo_pose==pose and target.hp==hp,"Pause freezes the shared Goemon attack pose and all pending humanoid contacts")
	game.resume();var previous=.094
	for entry in [[.097,1],[.408,1],[.412,2],[.887,2],[.891,3]]:
		ally.tick(entry[0]-previous);previous=entry[0]
		check(ally.hits_landed==entry[1] and is_equal_approx(hp-target.hp,50.0*entry[1]),"The real combo timeline at %.3fs has exactly %d contacts and matching damage" % [entry[0],entry[1]])
		check(pose_matches(ally.model.pipe_combo_pose,PipeCombo.sample(ally.combo_stage,ally.combo_clock)),"The current humanoid attack stage uses Goemon's exact shared pose sample")
	await survey("02-shared-goemon-combo",Vector3(7,5,84),Vector3(0,1,78))
	ally.tick(.4);ally.attack_contact()
	check(ally.hits_landed==3 and ally.combo_contacts_emitted==3 and ally.state!="attack","The completed combo emits exactly three contacts and returns to normal locomotion")
	ally.state="idle";ally.cooldown_left=0;ally.position=Vector3(0,.15,79.5);ally.begin_attack(target);ally.tick(.04);hp=target.hp
	ally.take_hit(10,Vector3.RIGHT);ally.tick(.8)
	check(target.hp==hp and ally.hit_done and ally.attack_target==null,"An incoming hit interrupts the whole humanoid combo and cancels all remaining damage")
	ally.state="idle";ally.hurt_left=0;ally.cooldown_left=0;ally.position=Vector3(0,.15,79.5)
	var cover=Geo.box(game,Vector3(0,1,78.75),Vector3(5,2,.25),Geo.mat("687578"),true);await frames(2)
	check(not ally.begin_attack(target),"Solid world cover blocks an in-range humanoid attack")
	cover.queue_free();await frames(2)
	var s=game.encounters;var money=s.money;var kills=s.wave_kills;var xp=game.player.progression.total_kills
	game.player.hp=game.player.max_hp-20;var hero_hp=game.player.hp
	target.hp=1;ally.begin_attack(target);ally.tick(.11);ally.tick(1.2)
	check(target.dead and s.money==money+12 and s.wave_kills==kills+1 and game.player.progression.total_kills==xp and game.player.hp==hero_hp,"A humanoid kill pays one owned enemy bounty while preserving the hero's personal XP and healing rules")
	ally.take_hit(1000000,Vector3.ZERO);ally.tick(1.2);await frames(3)
	check(not is_instance_valid(ally),"A defeated humanoid retires its complete rig scene after its death presentation")
	await mixed_castle_route()

func mixed_castle_route():
	await hero_setup();var actors=await owned_targets("runner",1);var target=actors[0];target.position=Vector3(0,.15,150)
	await move_to(Vector3(65,0,250));var ally=await summon_hero_fixture("sen");var dog=await summon_fixture("kogane")
	ally.set_physics_process(true);dog.set_physics_process(true)
	var last_h=ally.position;var last_d=dog.position;var continuous=true;var gate_clear=true;var gate_captured=false
	for tick in range(750):
		if ally.hits_landed>0 and dog.hits_landed>0:break
		await frames(1)
		continuous=continuous and ally.position.distance_to(last_h)<3 and dog.position.distance_to(last_d)<3
		last_h=ally.position;last_d=dog.position
		for actor in [ally,dog]:
			if actor.position.z>179 and actor.position.z<183:gate_clear=gate_clear and absf(actor.position.x)<5.5
		if visual and not gate_captured and ally.position.z<182:
			gate_captured=true;await survey("03-castle-gateway",Vector3(16,10,197),Vector3(0,1,176))
	var minimum_spacing=ally.position.distance_to(dog.position)
	for tick in range(90):
		await frames(1)
		minimum_spacing=minf(minimum_spacing,ally.position.distance_to(dog.position))
	ally.set_physics_process(false);dog.set_physics_process(false)
	check(ally.hits_landed>0 and dog.hits_landed>0 and ally.position.z<156 and dog.position.z<156 and continuous and gate_clear,"A humanoid and dog travel continuously from their separate castle spawn rows through the real gate to attack the same enemy")
	check(minimum_spacing>=1.0,"A humanoid and dog keep at least one metre of center spacing while continuing to fight the same target")
	print("MIXED_ALLY_ROUTE ",JSON.stringify({"humanoid_position":[ally.position.x,ally.position.y,ally.position.z],"dog_position":[dog.position.x,dog.position.y,dog.position.z],"separation":ally.position.distance_to(dog.position),"minimum_combat_spacing":minimum_spacing,"humanoid_hits":ally.hits_landed,"dog_hits":dog.hits_landed}))
	await survey("04-mixed-close-combat",Vector3(-6,4,156),Vector3(0,1,151))
	ally.position=Vector3(85,-8,130);ally.velocity=Vector3.ZERO;ally.tick(.01)
	check(absf(ally.position.x)<6 and ally.position.y>-1,"A humanoid knocked beyond the compact floor recovers to the active road")

func mixed_retaliation_and_boss():
	await hero_setup();var actors=await owned_targets("runner",1);var enemy=actors[0]
	var ally=await summon_hero_fixture("sen");var dog=await summon_fixture("kogane")
	ally.position=Vector3(0,.15,80);dog.position=Vector3(5,.15,80)
	await move_to(Vector3(65,0,80));game.tuning.freeze_ai=false
	enemy.stun=0;enemy.impact_pause=0;enemy.cooldown=0;enemy.defense_dog_clock=0
	enemy.refresh_defense_dog_target(1);enemy.tick_defense_dog(.01)
	check(enemy.defense_dog_target==ally and enemy.defense_dog_state=="windup","An enemy can select the closer humanoid from the mixed ally population and wind up against it")
	var hp=ally.hp;var dog_hp=dog.hp;var hero_hp=game.player.hp
	dog.position=Vector3(0,.15,79);enemy.refresh_defense_dog_target(1)
	check(enemy.defense_dog_target==ally,"An enemy's windup remains locked to the humanoid even when a dog moves closer")
	game.show_pause();var timer=enemy.defense_dog_timer;enemy._physics_process(5);await frames(3)
	check(ally.hp==hp and dog.hp==dog_hp and enemy.defense_dog_timer==timer,"Pause freezes a mixed-population enemy strike without damaging either ally type")
	game.resume();enemy.tick_defense_dog(1);enemy.dog_attack_contact()
	check(is_equal_approx(hp-ally.hp,8*enemy.defense_damage_multiplier*game.tuning.enemy_damage) and dog.hp==dog_hp and game.player.hp==hero_hp,"Actual retaliation damages its locked humanoid exactly once and leaves the dog and player untouched")
	ally.position=Vector3(20,.15,80);dog.position=Vector3(0,.15,80)
	enemy.clear_defense_dog();enemy.position=Vector3(0,.15,78);enemy.cooldown=0;enemy.defense_dog_clock=0
	enemy.refresh_defense_dog_target(1);enemy.tick_defense_dog(.01);enemy.tick_defense_dog(1)
	check(enemy.defense_dog_target==dog and dog.hp<dog_hp,"The same enemy still acquires and damages a dog after the humanoid leaves range")
	dog.take_hit(1000000,Vector3.ZERO);enemy.tick_defense_dog(1)
	check(enemy.defense_dog_target==null and enemy.defense_dog_state.is_empty(),"A defeated dog still cancels its pending strike after mixed-population integration")
	ally.position=Vector3(0,.15,80);ally.state="idle";ally.hurt_left=0;enemy.cooldown=0;enemy.defense_dog_clock=0
	enemy.refresh_defense_dog_target(1);enemy.tick_defense_dog(.01)
	var cover=Geo.box(game,Vector3(0,1,79),Vector3(5,2,.25),Geo.mat("687578"),true);await frames(2)
	hp=ally.hp;enemy.tick_defense_dog(1)
	check(ally.hp==hp,"Retaliation against a humanoid rechecks solid cover at the contact")
	cover.queue_free();await frames(2)
	var old_ally=ally;enemy.clear_defense_dog();enemy.cooldown=0;enemy.defense_dog_clock=0
	enemy.refresh_defense_dog_target(1);enemy.tick_defense_dog(.01)
	game.barracks.reset();enemy.dog_attack_contact();enemy.tick_defense_dog(1)
	check(old_ally.dead and enemy.defense_dog_target==null,"Resetting the humanoid manager invalidates a stale enemy attack before the retired actor is freed")

	await hero_setup();var s=game.encounters
	s.wave=9;s.chosen_wave=10;s.phase="rest";s.prep_left=0;s.queue_wave()
	for iteration in range(80):
		if living_defenders().any(func(actor):return actor.defense_boss_tier==2):break
		s.spawn_pending();await frames(1)
	var bosses=living_defenders().filter(func(actor):return actor.defense_boss_tier==2)
	check(bosses.size()==1,"The mixed ally slam fixture uses the actual roster-owned final boss")
	if bosses.is_empty():return
	enemy=bosses[0]
	for actor in living_defenders():
		if actor!=enemy:actor.queue_free()
	s.pending=0;enemy.set_physics_process(false);enemy.position=Vector3(0,.15,80);enemy.velocity=Vector3.ZERO
	ally=await summon_hero_fixture("sen");dog=await summon_fixture("kogane")
	ally.position=Vector3(0,.15,84);dog.position=Vector3(3,.15,83)
	await move_to(Vector3(65,0,80));game.tuning.freeze_ai=false
	var traits=enemy.defense_traits;traits.slam_cooldown=0;enemy.cooldown=0
	for tick in range(40):
		if traits.phase=="warning":break
		enemy._physics_process(1.0/60.0);await frames(1)
	check(traits.phase=="warning" and traits.tell.visible,"A boss visibly warns before slamming a nearby mixed squad while the player is elsewhere")
	hp=ally.hp;dog_hp=dog.hp;game.show_pause();var elapsed=traits.elapsed;enemy._physics_process(10)
	check(traits.elapsed==elapsed and ally.hp==hp and dog.hp==dog_hp,"Pause freezes a boss warning for both humanoids and dogs")
	game.resume();await survey("05-boss-versus-mixed-squad",Vector3(14,12,92),Vector3(0,3,82))
	enemy._physics_process(1.26);var damage=38*enemy.defense_damage_multiplier*game.tuning.enemy_damage
	check(is_equal_approx(hp-ally.hp,damage) and is_equal_approx(dog_hp-dog.hp,damage),"One real boss impact damages each nearby humanoid and dog once through its own manager")
	hp=ally.hp;dog_hp=dog.hp;enemy._physics_process(.05)
	check(ally.hp==hp and dog.hp==dog_hp,"The same boss impact cannot be delivered twice to either companion population")
	traits.cancel_attack();enemy.position=Vector3(0,.15,80);ally.position=Vector3(0,.15,84);dog.position=Vector3(1,.15,84)
	cover=Geo.box(game,Vector3(0,1.5,82),Vector3(7,3,.3),Geo.mat("687578"),true);await frames(2)
	traits.begin_slam();enemy._physics_process(1.26)
	check(ally.hp==hp and dog.hp==dog_hp,"The same physical wall protects both ally types from the boss's actual ground slam")
	cover.queue_free();game.tuning.freeze_ai=true

func run_hero_benchmark():
	if DisplayServer.get_name()=="headless":
		check(false,"Humanoid performance evidence requires an actual renderer");get_tree().quit(1);return
	visual=true
	game.settings.quality=1;game.settings.fullscreen=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_window().size=Vector2i(1280,800);game.apply_quality()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var report={"date":"2026-10-04","renderer":RenderingServer.get_current_rendering_method(),"resolution":"1280x800","quality":1,"vsync":"disabled","environment":"Paired samples share the same process and desktop environment; background applications are not stopped or isolated.","fixture":"180 durable real wave-ten attackers including the boss,24 mixed defenses and8 distinct dogs in both samples. The second adds8 durable humanoids with actual HeroModel/HeroLocomotion rigs and the canonical Goemon three-hit combo. All targeting, movement, hit reactions, ally damage and boss retaliation stay live."}
	report.dogs_only=await measure_mixed(0)
	report.mixed_squad=await measure_mixed(8)
	report.frame_mean_ratio=report.mixed_squad.frame_ms.mean/report.dogs_only.frame_ms.mean
	report.physics_mean_ratio=report.mixed_squad.physics_ms.mean/maxf(.001,report.dogs_only.physics_ms.mean)
	FileAccess.open("res://tests/defense-heroes/performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("DEFENSE_HERO_PROFILE ",JSON.stringify(report))
	game.show_main_menu();print("DEFENSE_HERO_BENCHMARK failures=",failures)
	await finish_beta(1 if failures else 0)

func measure_mixed(humans: int)->Dictionary:
	await hero_setup();var s=game.encounters;var kennel=game.kennel;var barracks=game.barracks
	var population=8
	var stress_ids=hero_ids.duplicate()
	if FileAccess.file_exists("res://tests/defense-heroes/asset-qa.json"):
		var measured=JSON.parse_string(FileAccess.get_file_as_string("res://tests/defense-heroes/asset-qa.json"))
		if measured is Array and measured.size()==10:
			measured.sort_custom(func(a,b):return int(a.triangles)>int(b.triangles))
			stress_ids=measured.map(func(row):return String(row.id))
	s.wave=9;s.chosen_wave=10;s.phase="rest";s.prep_left=0;s.tick(0)
	await fill_live_cap(s,180)
	var actors=living_defenders();var stations=[-170.0,-100.0,-30.0,40.0,110.0,180.0]
	for i in range(actors.size()):
		var actor=actors[i];var station=i/30;var slot=i%30
		actor.position=Vector3((float(slot%6)-2.5)*1.3,.1,stations[station]-27-float(slot/6)*1.8)
		if actor.defense_boss_tier>0:actor.position=Vector3(0,.1,-124)
		actor.defense_offset=Vector3(actor.position.x,0,0);actor.defense_waypoint=1
		actor.hp=2000000;actor.max_hp=2000000;actor.velocity=Vector3.ZERO;actor.stun=0
	for index in range(population):
		var dog=await summon_fixture(expected_ids[index])
		dog.position=Vector3(-2.7 if index<6 else 2.7,.15,stations[index%6]-21)
		dog.hp=200000;dog.max_hp=200000;dog.set_physics_process(true)
	for index in range(humans):
		var ally=await summon_hero_fixture(stress_ids[index])
		ally.position=Vector3(2.7 if index<6 else -2.7,.15,stations[index%6]-20)
		ally.hp=200000;ally.max_hp=200000;ally.set_physics_process(true)
	# Keep the hero off the road but central: EnemyCrowd's 360 m defense
	# visibility radius must include all six stations for both measurements.
	await move_to(Vector3(65,0,10))
	var eye=Vector3(90,210,270);var aim=Vector3(0,0,-15)
	game.camera_rig.set_process(false);game.camera_rig.camera.global_position=eye
	game.camera_rig.camera.look_at(aim);game.camera_rig.camera.fov=64
	game.tuning.freeze_ai=false;s.set_physics_process(true);kennel.set_physics_process(true);barracks.set_physics_process(true)
	var warm_until=Time.get_ticks_msec()+2200
	while Time.get_ticks_msec()<warm_until:await get_tree().process_frame
	var samples={"frame_ms":[],"process_ms":[],"physics_ms":[],"render_cpu_ms":[],"gpu_ms":[],"draw_calls":[]}
	var peak_nodes=0;var peak_shells=0;var peak_flames=0;var minimum=180;var maximum=0;var peak_dogs=0;var peak_heroes=0;var minimum_visible=180
	var firing={};var initial_shots={};var bites_before=0;var retaliation_before=0;var hero_hits_before=0
	for dog in kennel.dogs:bites_before+=dog.hits_landed
	for ally in barracks.heroes:hero_hits_before+=ally.hits_landed
	for actor in actors:retaliation_before+=actor.defense_dog_hits
	for tower in s.cannons:initial_shots[tower.get_instance_id()]=tower.shots_fired
	var until=Time.get_ticks_usec()+4000000;var last=Time.get_ticks_usec();var count=0
	var viewport=get_viewport().get_viewport_rid()
	while count<480 and (Time.get_ticks_usec()<until or count<120):
		await get_tree().process_frame
		var now=Time.get_ticks_usec();samples.frame_ms.append((now-last)/1000.0);last=now
		samples.process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		samples.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		samples.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport)+RenderingServer.get_frame_setup_time_cpu())
		samples.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var shells=0;var flames=0
		for tower in s.cannons:
			shells+=tower.shells.size()
			if tower.shots_fired>initial_shots[tower.get_instance_id()]:firing[tower.get_instance_id()]=tower is DefenseFlameTower
			if tower is DefenseFlameTower and tower.burst_left>0:flames+=1
		peak_nodes=maxi(peak_nodes,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		peak_shells=maxi(peak_shells,shells);peak_flames=maxi(peak_flames,flames);peak_dogs=maxi(peak_dogs,kennel.living_count());peak_heroes=maxi(peak_heroes,barracks.living_count())
		minimum=mini(minimum,game.active_enemy_count());maximum=maxi(maximum,game.active_enemy_count());count+=1
		minimum_visible=mini(minimum_visible,actors.filter(func(actor):return actor.visible).size())
	var bites=0;var dog_attackers=0;var hurt=0;var retaliation=0;var healed=0.0;var dog_models=0
	var flame_fired=0;var cannon_fired=0;var bounded=true
	for key in firing:
		if firing[key]:flame_fired+=1
		else:cannon_fired+=1
	for tower in s.cannons:bounded=bounded and tower.shell_pool.size()<=4 and tower.blast_pool.size()<=2
	for dog in kennel.dogs:
		bites+=dog.hits_landed;hurt+=dog.hits_received;healed+=dog.healing_done
		if dog.hits_landed>0:dog_attackers+=1
		if dog.model.visible and dog.animator!=null:dog_models+=1
	var hero_hits=0;var hero_attackers=0;var hero_models=0;var hero_hurt=0
	for ally in barracks.heroes:
		hero_hits+=ally.hits_landed;hero_hurt+=ally.hits_received
		if ally.hits_landed>0:hero_attackers+=1
		if ally.model.visible and ally.model.locomotion!=null:hero_models+=1
	for actor in actors:retaliation+=actor.defense_dog_hits
	var row={"sample_frames":count,"live_enemies_min":minimum,"live_enemies_max":maximum,"visible_enemies_min":minimum_visible,"living_humanoids":barracks.living_count(),"peak_humanoids":peak_heroes,"visible_animated_humanoids":hero_models,"humanoids_landed_attacks":hero_attackers,"humanoid_contacts_during_sample":hero_hits-hero_hits_before,"humanoid_hits_received_total":hero_hurt,"living_dogs":kennel.living_count(),"peak_dogs":peak_dogs,"visible_animated_dogs":dog_models,"dogs_landed_attacks":dog_attackers,"dog_contacts_during_sample":bites-bites_before,"enemy_retaliations_during_sample":retaliation-retaliation_before,"dog_hits_received_total":hurt,"dog_healing_total":healed,"flame_towers_firing":flame_fired,"cannons_firing":cannon_fired,"peak_nodes":peak_nodes,"peak_shells":peak_shells,"peak_active_flames":peak_flames,"camera_eye":[eye.x,eye.y,eye.z],"camera_target":[aim.x,aim.y,aim.z]}
	for metric in samples:row[metric]=summary_stats(samples[metric])
	row.humanoid_ids=stress_ids.slice(0,humans)
	row.gpu_timing_available=row.gpu_ms.max>0
	check(minimum==180 and maximum==180 and minimum_visible==180 and s.wave==10,"The eight-dog plus %d-humanoid sample retains 180 visible real late-wave enemies" % humans)
	check(kennel.living_count()==population and peak_dogs==population and dog_models==population and bounded,"The eight-dog plus %d-humanoid sample retains its bounded dog pack and projectile pool" % humans)
	check(flame_fired>0 and cannon_fired>0,"The eight-dog plus %d-humanoid sample includes active fire towers and artillery" % humans)
	check(bites>bites_before and retaliation>retaliation_before,"Dogs still bite and enemies really retaliate during the %d-humanoid measurement" % humans)
	check(barracks.living_count()==humans and peak_heroes==humans and hero_models==humans,"The humanoid rig population remains at its intended separate cap")
	if humans>0:check(hero_attackers==humans and hero_hits>hero_hits_before and hero_hurt>0,"All eight real humanoid rigs attack, land actual combo contacts and receive enemy retaliation")
	await capture_beta("benchmark-mixed-squad" if humans else "benchmark-eight-dogs")
	s.set_physics_process(false);kennel.set_physics_process(false);barracks.set_physics_process(false);game.tuning.freeze_ai=true;game.camera_rig.set_process(true)
	return row


func run_hero_functional():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/defense-heroes"))
	await hero_assets_and_pose()
	await hero_rosters_and_lifecycle()
	await hero_combat_and_route()
	await mixed_retaliation_and_boss()
	await hero_setup();await shared_controls()
	game.show_main_menu();print("DEFENSE_HERO_RESULT failures=",failures)
	await finish_beta(1 if failures else 0)

func run():
	var arguments=OS.get_cmdline_user_args()
	visual="--defense-hero-visual" in arguments or "--defense-hero-route-visual" in arguments
	if "--defense-hero-route-test" in arguments or "--defense-hero-route-visual" in arguments:
		await mixed_castle_route();game.show_main_menu();print("DEFENSE_HERO_ROUTE failures=",failures)
		await finish_beta(1 if failures else 0)
	elif "--defense-hero-benchmark" in arguments:await run_hero_benchmark()
	else:await run_hero_functional()
