extends "res://scripts/defense_tactics_tests.gd"

var dog_asset_rows=[]
var expected_ids=["kogane","daigo","kage","arashi","haku","suzu","maboro","iwa","mine","hayate"]

func capture_defense(label: String):
	await capture_beta(label)

func capture_beta(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/defense-dogs/"+label+".png")

func dog_setup(hard: bool=false):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/defense-dogs"))
	await tactics_setup(hard)
	game.kennel.set_physics_process(false)
	game.encounters.choose_card("supply_cache")
	await frames(2)

func click_named_button(button_name: String):
	await get_tree().process_frame
	var button=game.menu.find_child(button_name,true,false)
	if button==null:
		check(false,"Requested kennel UI button exists: "+button_name);return
	var point: Vector2=button.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	get_viewport().push_input(motion,true)
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
		event.position=point;event.global_position=point;event.pressed=down
		get_viewport().push_input(event,true)
		await get_tree().process_frame
	await frames(1)

func summon_fixture(id: String):
	var kennel=game.kennel
	kennel.tick(kennel.cooldown_left+.01)
	if not kennel.summon(id):
		check(false,"Fixture can summon "+id+": "+kennel.reason(id));return null
	var dog=kennel.dogs[-1];dog.set_physics_process(false)
	return dog

func owned_targets(role: String,count: int)->Array:
	var s=game.encounters
	if s.wave==0:s.queue_wave()
	var candidates=[]
	for iteration in range(50):
		candidates=living_defenders().filter(func(actor):return actor.defense_role==role)
		if candidates.size()>=count:break
		s.spawn_pending();await frames(1)
	check(candidates.size()>=count,"The combat fixture receives real owned "+role+" raiders from the wave roster")
	var chosen=candidates.slice(0,count)
	for actor in living_defenders():
		if not chosen.has(actor):actor.queue_free()
	s.pending=0
	for i in range(chosen.size()):
		var actor=chosen[i];actor.position=Vector3(float(i)*1.1,.15,78)
		actor.velocity=Vector3.ZERO;actor.hp=10000;actor.max_hp=10000
		actor.set_physics_process(false)
	await frames(2)
	return chosen

func scene_pose(scene: Node)->Dictionary:
	var values={}
	for node in scene.find_children("*","Node3D",true,false):
		values[str(scene.get_path_to(node))]=node.transform
		if node is Skeleton3D:
			for index in range(node.get_bone_count()):values[str(scene.get_path_to(node))+":%d" % index]=node.get_bone_pose(index)
	return values

func inspect_dog_assets():
	var definitions=DefenseDogCatalog.definitions()
	check(definitions.size()==10 and definitions.map(func(profile):return profile.id)==expected_ids,"The kennel catalog exposes all ten requested named dog designs")
	var hashes={}
	for profile in definitions:
		var resource=load(profile.asset)
		check(resource is PackedScene and ResourceLoader.exists(profile.portrait),"%s has its own imported Blender model and roster portrait" % profile.name)
		if not resource is PackedScene:continue
		hashes[FileAccess.get_sha256(profile.asset)]=true
		var scene=resource.instantiate();add_child(scene)
		var animators=scene.find_children("*","AnimationPlayer",true,false)
		var triangles=0;var mesh_count=0
		for mesh_node in scene.find_children("*","MeshInstance3D",true,false):
			if mesh_node.mesh==null:continue
			mesh_count+=1
			for surface in range(mesh_node.mesh.get_surface_count()):
				var arrays=mesh_node.mesh.surface_get_arrays(surface);var indices=arrays[Mesh.ARRAY_INDEX]
				triangles+=(indices.size() if indices!=null and indices.size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
		var complete=not animators.is_empty();var lengths={};var moving_attack=false
		if complete:
			var animator: AnimationPlayer=animators[0]
			animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			for clip in ["idle","run","attack","hurt","death"]:
				complete=complete and animator.has_animation(clip)
				if animator.has_animation(clip):
					var animation=animator.get_animation(clip)
					lengths[clip]=animation.length;complete=complete and animation.length>0 and animation.get_track_count()>0
			if animator.has_animation("attack"):
				animator.play("attack");animator.seek(0,true);animator.advance(0)
				var before=scene_pose(scene);animator.advance(.45)
				moving_attack=scene_pose(scene)!=before
		check(complete and mesh_count>0 and triangles>0,"%s imports visible meshes and all five keyed idle/run/attack/hurt/death clips" % profile.name)
		check(moving_attack and is_equal_approx(lengths.get("attack",0),profile.attack_duration) and profile.hit_time>0 and profile.hit_time<profile.attack_duration,"%s attack animation visibly changes its pose and matches the combat timing contract" % profile.name)
		dog_asset_rows.append({"id":profile.id,"meshes":mesh_count,"triangles":triangles,"clips":lengths})
		scene.queue_free();await frames(1)
	check(hashes.size()==10,"The roster instantiates ten distinct exported model files")
	FileAccess.open("res://tests/defense-dogs/asset-qa.json",FileAccess.WRITE).store_string(JSON.stringify(dog_asset_rows,"\t"))

func summoning_and_lifecycle():
	await tactics_setup();var kennel=game.kennel;kennel.set_physics_process(false)
	var s=game.encounters;var p=game.player
	check(not kennel.can_summon("kogane") and not kennel.summon("kogane"),"The mandatory wave-card draft cannot be bypassed by summoning a dog")
	await key(KEY_G)
	check(s.phase=="draft" and game.paused and not kennel.menu_open,"G preserves the mandatory card draft and does not replace its menu")
	s.choose_card("supply_cache")
	check(kennel.living_count()==0 and kennel.cooldown_left==0,"A fresh defense run starts with an empty kennel and ready summon cooldown")
	var money=s.money
	check(not kennel.summon("not_a_dog") and s.money==money and kennel.living_count()==0,"Invalid dog IDs cannot spend gold or create an ally")
	await move_to(Vector3(65,0,-250))
	await key(KEY_G)
	check(game.paused and get_tree().paused and kennel.menu_open and game.menu.find_children("DogSummon_*","Button",true,false).size()==10,"Physical G opens a paused ten-dog roster")
	check(game.menu.find_child("DogRosterClose",true,false)!=null,"The kennel roster provides its own close control")
	await key(KEY_G)
	check(not game.paused and not kennel.menu_open and kennel.living_count()==0,"Pressing G again closes the roster without spending gold or creating a dog")
	await key(KEY_G);await click_named_button("DogRosterClose")
	check(not game.paused and not kennel.menu_open and s.money==money,"The roster's real close button resumes the same battle without changing gold")
	await key(KEY_G)
	await capture_beta("01-ten-dog-roster")
	await click_named_button("DogSummon_kogane")
	check(kennel.living_count()==1 and s.money==money-DefenseDogCatalog.get_dog("kogane").cost and not game.paused and not kennel.menu_open,"A real roster click purchases the selected dog exactly once and resumes battle")
	var dog=kennel.dogs[0];dog.set_physics_process(false)
	check(dog.profile_id=="kogane" and dog.position.z>180 and absf(dog.position.x)<6 and dog.position.distance_to(p.position)>300,"The chosen dog emerges from the castle gateway even when the hero is far away")
	var enemy_count=game.active_enemy_count();var capacity=game.enemy_spawn_capacity()
	game.crowd._process(.1)
	check(not game.enemies.any(func(actor):return actor==dog) and game.active_enemy_count()==enemy_count and game.enemy_spawn_capacity()==capacity and dog.model.visible,"Friendly dogs keep their model and do not join the enemy crowd or consume enemy capacity")
	money=s.money
	check(not kennel.summon("daigo") and s.money==money and kennel.living_count()==1,"Summon cooldown rejects repeated requests without spending additional gold")
	var cooldown=kennel.cooldown_left;game.show_pause();kennel.tick(10);dog.tick(10);await frames(5)
	check(kennel.cooldown_left==cooldown and not kennel.summon("daigo") and kennel.living_count()==1,"Ordinary pause freezes cooldown and rejects summons outside the roster")
	game.resume();kennel.tick(2.99)
	check(kennel.cooldown_left>0 and not kennel.can_summon("daigo"),"Summoning observes the complete three-second simulation cooldown")
	kennel.tick(.02);money=s.money;s.money=DefenseDogCatalog.get_dog("daigo").cost-1
	check(not kennel.summon("daigo") and kennel.living_count()==1 and s.money==DefenseDogCatalog.get_dog("daigo").cost-1,"Insufficient gold blocks a summon without altering the roster or balance")
	s.money=money
	for id in expected_ids.slice(1,8):await summon_fixture(id)
	check(kennel.living_count()==8 and kennel.dogs.filter(func(ally):return is_instance_valid(ally) and not ally.dead).size()==8,"The kennel can field eight living dogs with distinct selected profiles")
	kennel.tick(3.01);money=s.money
	check(not kennel.summon("mine") and kennel.living_count()==8 and s.money==money,"The eight-dog cap prevents extra allies and extra charges")
	var fallen=kennel.dogs[0];var kills=game.kills;var xp=p.progression.total_kills
	fallen.take_hit(1000000,Vector3.ZERO)
	check(fallen.dead and kennel.living_count()==7 and s.money==money and game.kills==kills and p.progression.total_kills==xp,"An allied dog's death releases its living slot without enemy gold, kill or XP rewards")
	check(kennel.summon("mine") and kennel.living_count()==8,"A fallen dog's slot can be filled while its death effect is retiring")
	var old_dogs=kennel.dogs.duplicate();game.restart_area();s=game.encounters;s.set_physics_process(false);kennel.set_physics_process(false)
	var retired=true
	for old in old_dogs:
		if is_instance_valid(old):retired=retired and old.dead and not old.visible and not old.is_physics_processing()
	check(retired and kennel.living_count()==0 and kennel.cooldown_left==0 and s.phase=="draft","Retry immediately retires old dogs and resets kennel slots/cooldown before the next draft")
	await frames(3)
	check(old_dogs.all(func(old):return not is_instance_valid(old)),"Old dog nodes are disposed after retry instead of leaking into the new run")
	s.choose_card("supply_cache");dog=await summon_fixture("kogane")
	s.base_hp=0;game.defeat();cooldown=kennel.cooldown_left
	kennel.tick(10)
	if is_instance_valid(dog):dog.tick(10)
	await frames(5)
	check(not kennel.summon("kage") and kennel.cooldown_left==cooldown and kennel.living_count()==0 and not is_instance_valid(dog),"Shrine defeat retires the pack and cannot be escaped by summoning")
	game.restart_area();s=game.encounters;s.set_physics_process(false);s.choose_card("supply_cache")
	game.defense_victory()
	check(game.won and not kennel.summon("kogane") and not kennel.can_summon("kogane"),"A completed defense cannot create new allies")
	await dog_setup();dog=await summon_fixture("kogane");game.show_main_menu();await frames(2)
	check(kennel.living_count()==0 and not is_instance_valid(dog) and not kennel.can_summon("kogane"),"Returning to the main menu clears the allied roster and disables summoning")
	game.start_mode("survival");game.encounters.set_physics_process(false)
	await key(KEY_G)
	check(not kennel.menu_open and kennel.living_count()==0 and not kennel.can_summon("kogane"),"Other game modes cannot open or use the castle kennel")

func dog_combat_and_traits():
	await dog_setup()
	var actors=await owned_targets("runner",1);var target=actors[0]
	var dog=await summon_fixture("kogane");dog.position=Vector3(0,.15,80)
	var hp=target.hp
	check(dog.begin_attack(target) and dog.state=="attack" and dog.animation_name=="attack","A close owned opponent starts the selected dog's authored attack animation")
	dog.tick(.37)
	check(target.hp==hp and dog.hits_landed==0,"The attack windup cannot damage an enemy before the authored 0.38-second contact")
	var age=dog.attack_age;var animation_time=dog.animator.current_animation_position
	game.show_pause();dog.tick(10);await frames(5)
	check(dog.attack_age==age and dog.animator.current_animation_position==animation_time and target.hp==hp,"Pause freezes the attack pose and pending bite together")
	game.resume();dog.tick(.02)
	check(is_equal_approx(hp-target.hp,dog.profile.damage) and dog.hits_landed==1,"Crossing the animation contact applies exactly one real bite for the catalog damage")
	dog.attack_contact();dog.tick(.25)
	check(dog.hits_landed==1 and is_equal_approx(hp-target.hp,dog.profile.damage),"Repeated contact polling cannot hit again within the same attack")
	await survey("02-animated-bite",Vector3(8,5,85),Vector3(0,1,79))
	dog.state="idle";dog.cooldown_left=0;dog.position=Vector3(0,.15,80)
	dog.begin_attack(target);dog.tick(.2);hp=target.hp
	dog.take_hit(10,Vector3.RIGHT);dog.tick(.3)
	check(target.hp==hp and dog.hit_done and dog.animation_name=="hurt","A real incoming hit cancels the pending bite and plays the hurt clip")
	dog.state="idle";dog.hurt_left=0;dog.cooldown_left=0;dog.position=Vector3(0,.15,80)
	var cover=Geo.box(game,Vector3(0,1,79),Vector3(5,2,.25),Geo.mat("627274"),true)
	await frames(2)
	check(not dog.begin_attack(target),"Solid cover blocks a dog's attack even when the enemy is within bite range")
	cover.queue_free();await frames(2)
	var s=game.encounters;var money=s.money;var kills=s.wave_kills;var xp=game.player.progression.total_kills
	game.player.hp=game.player.max_hp-25;var hero_hp=game.player.hp
	target.hp=1;dog.begin_attack(target);dog.tick(.39);dog.attack_contact()
	check(target.dead and s.money==money+12 and s.wave_kills==kills+1,"A dog killing its real wave opponent awards the enemy bounty exactly once")
	check(game.player.progression.total_kills==xp and game.player.hp==hero_hp,"An allied kill preserves the hero's personal XP and on-hit healing rules")
	dog.take_hit(100000,Vector3.ZERO)
	check(dog.dead and dog.animation_name=="death" and dog.collision_layer==0,"A defeated dog plays its death clip and immediately stops blocking actors")
	dog.tick(1);await frames(2)
	check(not is_instance_valid(dog),"The completed dog death retires its scene node")

	# Each distinct catalog trait is exercised against actual game objects.
	await dog_setup()
	for id in ["daigo","maboro","iwa","mine"]:
		dog=await summon_fixture(id);hp=dog.hp;dog.take_hit(100,Vector3.RIGHT)
		check(is_equal_approx(hp-dog.hp,100*(1.0-float(dog.profile.armor))),"%s applies its stated armor reduction to real received damage" % dog.profile.name)
	for id in ["kage","iwa"]:
		for role in ["brute","shield"]:
			await dog_setup();actors=await owned_targets(role,1);target=actors[0]
			dog=await summon_fixture(id);dog.position=Vector3(0,.15,80);target.model.rotation.y=PI
			hp=target.hp;dog.begin_attack(target);dog.tick(.39)
			check(is_equal_approx(hp-target.hp,dog.profile.damage),"%s's actual bite pierces %s mitigation" % [dog.profile.name,role])
	for id in ["arashi","maboro"]:
		await dog_setup();actors=await owned_targets("runner",1);target=actors[0]
		dog=await summon_fixture(id);dog.position=Vector3(0,.15,80)
		dog.begin_attack(target);dog.tick(.39)
		var traits=target.defense_traits
		check(is_equal_approx(traits.slow_factor,dog.profile.slow_factor) and is_equal_approx(traits.slow_left,dog.profile.slow_duration) and traits.slow_visual.visible,"%s's bite applies its real, visible movement slow" % dog.profile.name)
		traits.tick_status(float(dog.profile.slow_duration)+.01)
		check(traits.slow_left==0 and traits.slow_factor==1 and not traits.slow_visual.visible,"%s's slow expires completely instead of freezing an opponent indefinitely" % dog.profile.name)
	for id in ["haku","hayate"]:
		await dog_setup();actors=await owned_targets("runner",4);target=actors[0]
		for index in range(actors.size()):actors[index].position=Vector3((index%2)*.8,.15,78-float(index/2)*.8)
		dog=await summon_fixture(id);dog.position=Vector3(0,.15,80);dog.begin_attack(target);dog.tick(.39)
		var hit=actors.filter(func(actor):return actor.hp<10000)
		check(hit.size()==int(dog.profile.cleave) and dog.hits_landed==int(dog.profile.cleave),"%s's sweeping bite respects its total victim cap of %d" % [dog.profile.name,dog.profile.cleave])
		check(is_equal_approx(10000-target.hp,dog.profile.damage) and hit.filter(func(actor):return actor!=target).all(func(actor):return is_equal_approx(10000-actor.hp,float(dog.profile.damage)*.55)),"%s applies full primary and 55%% secondary bite damage" % dog.profile.name)
	await dog_setup()
	var healer=await summon_fixture("suzu");var near=await summon_fixture("kogane");var far=await summon_fixture("daigo");var fallen=await summon_fixture("mine")
	healer.position=Vector3(0,.15,80);near.position=Vector3(2,.15,80);far.position=Vector3(15,.15,80);fallen.position=Vector3(-2,.15,80)
	healer.hp-=20;near.hp-=5;far.hp-=30;fallen.take_hit(1000000,Vector3.ZERO)
	hero_hp=game.player.hp;hp=near.hp;healer.tick_healing(2.99)
	check(near.hp==hp and healer.healing_done==0,"Suzu waits the full three seconds before healing the pack")
	game.show_pause();var heal_clock=healer.heal_left;healer.tick_healing(10);await frames(3)
	check(healer.heal_left==heal_clock and near.hp==hp,"Paused healing neither advances its timer nor changes allied health")
	game.resume();healer.tick_healing(.02)
	check(near.hp==near.max_hp and is_equal_approx(healer.hp,healer.max_hp-8) and is_equal_approx(healer.healing_done,17),"Suzu heals nearby living dogs for 12 HP each, capped at their maximum health")
	check(far.hp==far.max_hp-30 and fallen.dead and fallen.hp==0 and game.player.hp==hero_hp,"Pack healing leaves distant dogs, dead dogs and the hero unchanged")
	await survey("03-pack-support",Vector3(10,6,88),Vector3(0,1,80))

func dog_route_and_enemy_retaliation():
	await dog_setup()
	var actors=await owned_targets("runner",1);var enemy=actors[0]
	enemy.position=Vector3(0,.15,145)
	await move_to(Vector3(65,0,250))
	var dog=await summon_fixture("kogane");dog.set_physics_process(true)
	var previous=dog.position;var continuous=true;var ran=false;var inside_gate=true
	for tick in range(600):
		if dog.hits_landed>0:break
		await frames(1)
		continuous=continuous and dog.position.distance_to(previous)<3;previous=dog.position
		ran=ran or dog.animation_name=="run"
		if dog.position.z>179 and dog.position.z<183:inside_gate=inside_gate and absf(dog.position.x)<5.5
	dog.set_physics_process(false)
	check(dog.hits_landed>0 and dog.position.z<150 and ran and continuous and inside_gate,"An actual summoned dog runs continuously out of the castle gateway and attacks an approaching raider")
	await survey("04-castle-companion",Vector3(15,9,188),Vector3(0,1,152))
	dog.position=Vector3(85,-8,130);dog.velocity=Vector3.ZERO;dog.tick(.01)
	check(absf(dog.position.x)<6 and dog.position.y>-1 and dog.position.z<180,"A dog displaced beyond the compact floor recovers to the road without falling forever")

	await dog_setup();actors=await owned_targets("runner",1);enemy=actors[0]
	dog=await summon_fixture("daigo");dog.position=Vector3(0,.15,80)
	await move_to(Vector3(65,0,80));game.tuning.freeze_ai=false
	enemy.stun=0;enemy.impact_pause=0;enemy.cooldown=0
	enemy.refresh_defense_dog_target(1);enemy.tick_defense_dog(.01)
	check(enemy.defense_dog_target==dog and enemy.defense_dog_state=="windup","A nearby raider deliberately targets the friendly dog and starts a telegraphed retaliation")
	var hp=dog.hp;var hero_hp=game.player.hp;var windup=enemy.defense_dog_timer
	enemy.tick_defense_dog(windup-.01)
	check(dog.hp==hp and enemy.defense_dog_hits==0,"Enemy retaliation cannot damage the dog during its windup")
	game.show_pause();var timer=enemy.defense_dog_timer;enemy._physics_process(5);await frames(3)
	check(dog.hp==hp and enemy.defense_dog_timer==timer,"Pause preserves a pending enemy-to-dog strike and its timer")
	game.resume();game.player.position=enemy.position+Vector3(.5,0,0)
	enemy.refresh_defense_dog_target(1)
	check(enemy.defense_dog_target==dog,"A windup keeps its original dog target even if the hero moves closer before impact")
	enemy.tick_defense_dog(.02);enemy.dog_attack_contact()
	var expected=8.0*enemy.defense_damage_multiplier*game.tuning.enemy_damage*(1.0-float(dog.profile.armor))
	check(enemy.defense_dog_hits==1 and is_equal_approx(hp-dog.hp,expected) and game.player.hp==hero_hp,"A real retaliation contact damages its locked dog once, respects armor, and does not hit the hero")
	# Cover is introduced after windup to prove the contact itself rechecks LOS.
	game.player.position=Vector3(65,.15,80)
	dog.hurt_left=0;dog.state="idle";enemy.clear_defense_dog();enemy.stun=0;enemy.cooldown=0
	enemy.position=Vector3(0,.15,78);dog.position=Vector3(0,.15,80)
	enemy.refresh_defense_dog_target(1);enemy.tick_defense_dog(.01)
	var cover=Geo.box(game,Vector3(0,1,79),Vector3(5,2,.25),Geo.mat("687578"),true);await frames(2)
	hp=dog.hp;enemy.tick_defense_dog(1)
	check(dog.hp==hp,"A wall erected between windup and contact blocks enemy damage to the dog")
	cover.queue_free();await frames(2)
	enemy.clear_defense_dog();enemy.state="windup";enemy.defense_dog_clock=0;enemy.refresh_defense_dog_target(1)
	check(enemy.defense_dog_target==null,"An already-started hero attack cannot be redirected into a dog attack")
	enemy.state="chase";enemy.cooldown=0;enemy.refresh_defense_dog_target(1);enemy.tick_defense_dog(.01)
	dog.take_hit(1000000,Vector3.ZERO);enemy.tick_defense_dog(1)
	check(enemy.defense_dog_target==null and enemy.defense_dog_state.is_empty(),"A dead allied target cancels the raider's pending retaliation cleanly")

	await dog_setup();var s=game.encounters
	s.wave=9;s.chosen_wave=10;s.phase="rest";s.prep_left=0;s.queue_wave()
	for iteration in range(80):
		if living_defenders().any(func(actor):return actor.defense_boss_tier==2):break
		s.spawn_pending();await frames(1)
	var bosses=living_defenders().filter(func(actor):return actor.defense_boss_tier==2)
	check(bosses.size()==1,"The dog boss fixture receives the actual wave-ten boss from the roster")
	if bosses.is_empty():return
	enemy=bosses[0]
	for actor in living_defenders():
		if actor!=enemy:actor.queue_free()
	s.pending=0;enemy.set_physics_process(false);enemy.position=Vector3(0,.15,80);enemy.velocity=Vector3.ZERO
	dog=await summon_fixture("kogane");dog.position=Vector3(0,.15,84);dog.max_hp=1000;dog.hp=1000
	await move_to(Vector3(65,0,80));game.tuning.freeze_ai=false
	var traits=enemy.defense_traits;traits.slam_cooldown=0;enemy.cooldown=0
	# Target acquisition is deliberately staggered. Let its bounded scan clock
	# find the newly positioned dog before expecting the warning animation.
	for tick in range(40):
		if traits.phase=="warning":break
		enemy._physics_process(1.0/60.0);await frames(1)
	check(traits.phase=="warning" and traits.tell.visible,"A boss can begin its visible ground slam against a nearby dog while the hero is far away")
	hp=dog.hp;var elapsed=traits.elapsed;game.show_pause();enemy._physics_process(5);await frames(3)
	check(traits.elapsed==elapsed and dog.hp==hp,"Pause freezes the boss warning and prevents damage to the pack")
	game.resume();await survey("05-boss-versus-pack",Vector3(15,12,93),Vector3(0,3,82))
	enemy._physics_process(1.25)
	expected=38*enemy.defense_damage_multiplier*game.tuning.enemy_damage
	check(traits.phase=="impact" and is_equal_approx(hp-dog.hp,expected),"The boss's actual warning-to-impact transition damages a nearby dog")
	hp=dog.hp;enemy._physics_process(.05)
	check(dog.hp==hp,"A boss slam cannot repeatedly damage a dog during the same impact phase")
	traits.cancel_attack();enemy.position=Vector3(0,.15,80);dog.position=Vector3(0,.15,84)
	cover=Geo.box(game,Vector3(0,1.5,82),Vector3(6,3,.3),Geo.mat("687578"),true);await frames(2)
	traits.begin_slam();enemy._physics_process(1.26)
	check(dog.hp==hp,"Solid cover blocks the boss's ground-slam contact with a dog")
	cover.queue_free();game.tuning.freeze_ai=true

func run_dog_benchmark():
	if DisplayServer.get_name()=="headless":
		check(false,"Dog performance evidence requires an actual renderer");get_tree().quit(1);return
	visual=true
	game.settings.quality=1;game.settings.fullscreen=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_window().size=Vector2i(1280,800);game.apply_quality()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var report={"date":"2026-10-04","renderer":RenderingServer.get_current_rendering_method(),"resolution":"1280x800","quality":1,"vsync":"disabled","environment":"Paired samples share the same process and desktop environment; background applications are not stopped or isolated.","fixture":"180 durable real wave-10 attackers including the boss, 24 level-1 mixed defenses. The second sample adds eight durable distinct dogs, with normal movement, animation, bites, healing and enemy retaliation. Durability retains population for measurement; combat work is not stubbed."}
	report.baseline=await measure_dogs(0)
	report.eight_dogs=await measure_dogs(8)
	report.frame_mean_ratio=report.eight_dogs.frame_ms.mean/report.baseline.frame_ms.mean
	report.physics_mean_ratio=report.eight_dogs.physics_ms.mean/maxf(.001,report.baseline.physics_ms.mean)
	FileAccess.open("res://tests/defense-dogs/performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("DEFENSE_DOG_PROFILE ",JSON.stringify(report))
	game.show_main_menu();print("DEFENSE_DOG_BENCHMARK failures=",failures)
	await finish_beta(1 if failures else 0)

func measure_dogs(population: int)->Dictionary:
	await dog_setup();var s=game.encounters;var kennel=game.kennel
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
	# Keep the hero off the road but central: EnemyCrowd's 360 m defense
	# visibility radius must include all six stations for both measurements.
	await move_to(Vector3(65,0,10))
	var eye=Vector3(90,210,270);var aim=Vector3(0,0,-15)
	game.camera_rig.set_process(false);game.camera_rig.camera.global_position=eye
	game.camera_rig.camera.look_at(aim);game.camera_rig.camera.fov=64
	game.tuning.freeze_ai=false;s.set_physics_process(true);kennel.set_physics_process(true)
	var warm_until=Time.get_ticks_msec()+2200
	while Time.get_ticks_msec()<warm_until:await get_tree().process_frame
	var samples={"frame_ms":[],"process_ms":[],"physics_ms":[],"render_cpu_ms":[],"gpu_ms":[],"draw_calls":[]}
	var peak_nodes=0;var peak_shells=0;var peak_flames=0;var minimum=180;var maximum=0;var peak_dogs=0;var minimum_visible=180
	var firing={};var initial_shots={};var bites_before=0;var retaliation_before=0
	for dog in kennel.dogs:bites_before+=dog.hits_landed
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
		peak_shells=maxi(peak_shells,shells);peak_flames=maxi(peak_flames,flames);peak_dogs=maxi(peak_dogs,kennel.living_count())
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
	for actor in actors:retaliation+=actor.defense_dog_hits
	var row={"sample_frames":count,"live_enemies_min":minimum,"live_enemies_max":maximum,"visible_enemies_min":minimum_visible,"living_dogs":kennel.living_count(),"peak_dogs":peak_dogs,"visible_animated_dogs":dog_models,"dogs_landed_attacks":dog_attackers,"dog_contacts_during_sample":bites-bites_before,"enemy_retaliations_during_sample":retaliation-retaliation_before,"dog_hits_received_total":hurt,"dog_healing_total":healed,"flame_towers_firing":flame_fired,"cannons_firing":cannon_fired,"peak_nodes":peak_nodes,"peak_shells":peak_shells,"peak_active_flames":peak_flames,"camera_eye":[eye.x,eye.y,eye.z],"camera_target":[aim.x,aim.y,aim.z]}
	for metric in samples:row[metric]=summary_stats(samples[metric])
	row.gpu_timing_available=row.gpu_ms.max>0
	check(minimum==180 and maximum==180 and minimum_visible==180 and s.wave==10,"The %d-dog rendered sample retains all 180 visible real late-wave enemies" % population)
	check(kennel.living_count()==population and peak_dogs==population and dog_models==population and bounded,"The %d-dog sample retains a bounded pack and projectile pool" % population)
	check(flame_fired>0 and cannon_fired>0,"The %d-dog sample includes active real fire towers and artillery" % population)
	if population>0:
		check(dog_attackers==population and bites>bites_before and retaliation>retaliation_before,"Every stress-fixture dog attacks, with real bites and enemy retaliation during the measured sample")
	await capture_beta("benchmark-eight-dogs" if population else "benchmark-baseline")
	s.set_physics_process(false);kennel.set_physics_process(false);game.tuning.freeze_ai=true;game.camera_rig.set_process(true)
	return row

func run_dog_functional():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/defense-dogs"))
	await inspect_dog_assets()
	await summoning_and_lifecycle()
	await dog_combat_and_traits()
	await dog_route_and_enemy_retaliation()
	await dog_setup();await shared_controls()
	game.show_main_menu();print("DEFENSE_DOG_RESULT failures=",failures)
	await finish_beta(1 if failures else 0)

func run():
	visual="--defense-dog-visual" in OS.get_cmdline_user_args()
	if "--defense-dog-benchmark" in OS.get_cmdline_user_args():await run_dog_benchmark()
	else:await run_dog_functional()
