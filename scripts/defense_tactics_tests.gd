extends "res://scripts/defense_fire_tests.gd"

# Real game objects and input paths are used throughout. Forced draft fixtures
# below skip roster time only; selection, eligibility and card effects stay live.
var role_totals={"runner":0,"brute":0,"shield":0,"boss":0}
var boss_rows=[]

func capture_beta(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/defense-tactics/"+label+".png")

func tactics_setup(hard: bool=false):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/defense-tactics"))
	Input.use_accumulated_input=false
	get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	game.camera_rig.set_process_unhandled_input(false)
	game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.defense_tactics=true;game.start_defense(hard)
	game.encounters.set_physics_process(false);game.player.smoke_mode=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await frames(3)

func valid_offer(s)->bool:
	var seen={}
	for id in s.card_offer:
		if seen.has(id) or not s.card_eligible(id):return false
		seen[id]=true
	return seen.size()==3

func click_card(index: int):
	await get_tree().process_frame
	var button=game.menu.find_child("DefenseCard_%d" % index,true,false)
	if button==null:
		check(false,"The intended card button exists before pointer activation");return
	var point: Vector2=button.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	get_viewport().push_input(motion,true)
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
		event.position=point;event.global_position=point;event.pressed=down
		get_viewport().push_input(event,true)
		await get_tree().process_frame
	await frames(1)

func campaign_state(s,seen: Dictionary,cycles: int)->Dictionary:
	return {"wave":s.wave,"seen":seen.size(),"phase":s.phase,"pending":s.pending,"alive":s.alive_count,"active_count":game.active_enemy_count(),"paused":game.paused,"tree_paused":get_tree().paused,"active":s.active,"enabled":s.enabled,"playing":game.playing,"transitioning":game.transitioning,"player_hp":game.player.hp,"base_hp":s.base_hp,"spawned":s.total_spawned,"scheduled":s.total_scheduled,"cycles":cycles,"last_spawn_count":s.last_spawn_count,"last_spawn_usec":s.last_spawn_usec,"chosen_wave":s.chosen_wave,"offer":s.card_offer}

func forced_choice(s,id: String)->bool:
	# A separate effect fixture supplies the requested eligible card as one
	# choice. Never bypass the production choose_card validation/application.
	s.wave=s.chosen_wave;s.pending=0;s.alive_count=0;s.phase="draft"
	s.card_choice_wave=s.wave+1;s.card_offer.clear();s.card_offer.append(id)
	for other in s.eligible_cards():
		if other!=id and s.card_offer.size()<3:s.card_offer.append(other)
	game.show_defense_cards()
	return s.choose_card(id)

func clear_fixture():
	for enemy in game.enemies:
		if is_instance_valid(enemy):enemy.queue_free()
	game.enemies.clear();await frames(2)

func fixture_enemy(role: String="runner",point: Vector3=Vector3(0,.1,80),boss_tier: int=0):
	var actor=Ninja.new();actor.game=game;actor.swarm=true
	actor.defense_lane=1;actor.defense_role=role;actor.defense_boss_tier=boss_tier
	actor.defense_scale=4.0 if boss_tier==2 else (3.2 if boss_tier==1 else 1.0)
	actor.variant={"runner":1,"shield":0,"brute":2,"boss":2}.get(role,0)
	actor.encounter_id="tactics_fixture_%d" % Time.get_ticks_usec()
	actor.position=point;actor.state="chase";actor.alerted=true
	game.add_child(actor);game.enemies.append(actor)
	actor.hp=20000;actor.max_hp=20000
	return actor

func draft_and_campaign():
	await tactics_setup()
	var s=game.encounters;var p=game.player
	check(s.beta_mode and s.tactics_enabled and not s.hard_mode,"Normal tactics starts with card choices enabled")
	var world=game.world;var bounds: Rect2=world.playable_bounds
	check(bounds==Rect2(-80,-400,160,760),"Fire Siege uses a compact 160-by-760 battlefield around its single approach")
	var floor_body=world.get_node("DefenseFloor")
	var floor_shape: CollisionShape3D=floor_body.find_children("*","CollisionShape3D",true,false)[0]
	var floor_center: Vector3=floor_shape.global_position
	check(floor_shape.shape is BoxShape3D and is_equal_approx(floor_shape.shape.size.x,bounds.size.x) and is_equal_approx(floor_shape.shape.size.z,bounds.size.y) and Vector2(floor_center.x,floor_center.z).is_equal_approx(bounds.get_center()),"The actual collision floor matches the compact playable bounds")
	var contained_routes=0
	for path in world.lanes:
		if not path.is_empty() and path.all(func(point):return bounds.has_point(Vector2(point.x,point.z))):contained_routes+=1
	check(contained_routes==1 and world.lanes[1].all(func(point):return is_zero_approx(point.x)) and bounds.has_point(Vector2(world.spawn_point.x,world.spawn_point.z)) and bounds.has_point(Vector2(world.base_position.x,world.base_position.z)),"One straight center route connects the distant entrance to the shrine inside the compact map")
	var roads=world.find_children("*","MeshInstance3D",true,false).filter(func(mesh):return mesh.has_meta("defense_lane") and int(mesh.get_meta("defense_lane"))>=0)
	var gate_posts=world.find_children("ApproachGatePost_*","",true,false)
	check(world.active_lane_indices()==[1] and not roads.is_empty() and roads.all(func(mesh):return int(mesh.get_meta("defense_lane"))==1) and gate_posts.size()==2 and gate_posts.all(func(post):return String(post.name).begins_with("ApproachGatePost_1_")),"Rendered roads and gate posts belong only to the single active center approach")
	var sites_fit=world.cannon_sites.size()==24;var stations={}
	for site in world.cannon_sites:
		sites_fit=sites_fit and site.lane==1 and bounds.has_point(Vector2(site.position.x,site.position.z)) and bounds.has_point(Vector2(site.build_position.x,site.build_position.z))
		stations[site.position.z]=int(stations.get(site.position.z,0))+1
	check(sites_fit and stations.size()==6 and stations.values().all(func(count):return count==4),"All 24 mounts and purchase positions fit six stations along the one active road")
	check(s.tower_count("fire")==12 and s.tower_count("cannon")==12 and s.money==12000 and s.base_hp==100,"Normal mode retains 24 built defenses, 12,000 gold and 100 shrine integrity")
	check(s.phase=="draft" and s.wave==0 and game.paused and get_tree().paused,"The initial card draft pauses the world before any enemies arrive")
	check(valid_offer(s) and s.card_offer==["ice_shells","hot_flames","supply_cache"],"Opening draft offers exactly three distinct valid ice, fire, and gold choices")
	check(game.menu.find_children("DefenseCard_*","Button",true,false).size()==3,"The card menu exposes three individually selectable buttons")
	var elapsed=s.elapsed;var offer=s.card_offer.duplicate()
	s.tick(100);s.queue_wave();await frames(20)
	check(s.elapsed==elapsed and s.wave==0 and s.total_spawned==0 and s.phase=="draft","Draft time and enemy scheduling cannot advance without a choice")
	game.resume();await frames(2)
	check(game.paused and s.phase=="draft" and s.card_offer==offer,"Resume returns to the same mandatory draft")
	await key(KEY_ESCAPE)
	var pause_buttons=game.menu.find_children("*","Button",true,false)
	check(game.paused and pause_buttons.any(func(button):return button.text=="Main menu") and pause_buttons.any(func(button):return button.text=="Resume") and game.menu.find_children("DefenseCard_*","Button",true,false).is_empty(),"Esc from the draft opens the real pause menu with Resume and Main menu available")
	await key(KEY_ESCAPE)
	check(game.menu.find_children("DefenseCard_*","Button",true,false).size()==3,"A second Esc returns from pause to the three card buttons")
	check(game.paused and s.phase=="draft" and s.card_offer==offer,"Esc cannot skip the mandatory card choice or reroll its offer")
	check(not s.choose_card("not_a_card") and not s.choose_card("piercing_rounds") and s.card_history.is_empty(),"Invalid and unoffered cards cannot be selected")
	await capture_beta("01-opening-draft")
	await key(KEY_1);await frames(2)
	check(s.upgrade_level("ice_shells")==1 and s.card_history.size()==1 and s.chosen_wave==1 and not game.paused,"Physical key 1 accepts the ice card and resumes preparation")
	check(not p.quick_attacks.active and not p.quick_attacks.coins_enabled and not p.chain_pipe_combat.active,"Card hotkeys are consumed without triggering the hero's numbered abilities")
	check(not s.choose_card("ice_shells") and s.card_history.size()==1,"Repeated selection cannot grant a second card from the same draft")
	check(not s.card_eligible("ice_shells") and s.card_eligible("deep_freeze") and s.card_eligible("shatter"),"The ice pick reaches its stack cap and unlocks its dependent cards")
	s.tick(3.99)
	check(s.wave==0 and s.total_spawned==0,"A selected opening card still leaves the full four-second preparation")
	s.tick(.02)
	for number in range(1,11):
		check(s.wave==number and s.total_scheduled==600*number,"Draft %d releases exactly one 600-enemy wave" % number)
		var seen={};var bosses=0;var central=true;var roles={};var bounded=true;var cycles=0
		while s.phase=="wave" and cycles<1400:
			for actor in living_defenders():
				if not seen.has(actor.encounter_id):
					seen[actor.encounter_id]=true;roles[actor.defense_role]=true
					role_totals[actor.defense_role]+=1;central=central and actor.defense_lane==1
					if actor.defense_boss_tier>0:
						bosses+=1;boss_rows.append({"wave":number,"tier":actor.defense_boss_tier,"scale":actor.defense_scale,"hp":actor.max_hp})
						if number==10:
							var clear=true
							for z in [-170,-100,-30,40,110,180]:clear=clear and not actor.test_move(Transform3D(Basis.IDENTITY,Vector3(0,.1,z-5)),Vector3(0,0,10))
							check(clear,"The final boss's real collision capsule fits all six center wall openings")
				actor.take_hit(1000000000,Vector3.FORWARD,false,{"tower":true,"armor_piercing":true})
			var before=s.total_spawned;s.tick(0)
			bounded=bounded and s.total_spawned-before<=8 and game.active_enemy_count()<=180
			cycles+=1;await frames(1)
			if cycles%200==0:print("TACTICS_WAVE_PROGRESS ",JSON.stringify(campaign_state(s,seen,cycles)))
		print("TACTICS_WAVE_DONE ",JSON.stringify(campaign_state(s,seen,cycles)))
		check(seen.size()==600 and central and bounded and roles.has("runner") and roles.has("brute") and roles.has("shield"),"Wave %d delivers all center-lane roles within its finite roster and per-frame spawn budget" % number)
		check(bosses==(1 if number in [5,10] else 0),"Wave %d includes exactly its intended number of bosses inside the 600-actor roster" % number)
		if number<10:
			check(s.phase=="draft" and game.paused and s.card_choice_wave==number+1 and valid_offer(s),"Wave %d ends in a fresh paused draft of three valid, unique choices" % number)
			if s.phase!="draft" or s.card_offer.is_empty():return
			var choice=String(s.card_offer[0]);var spawned=s.total_spawned
			s.tick(999);s.queue_wave()
			check(s.wave==number and s.total_spawned==spawned and not game.won,"Wave %d cannot continue or win while its next card is unchosen" % number)
			await click_card(0)
			check(s.card_history.size()==number+1 and s.card_history[-1].id==choice and is_equal_approx(s.prep_left,12),"Card %d is recorded once and grants the twelve-second rebuild window" % (number+1))
			if s.phase=="draft":
				print("TACTICS_POINTER_FAILED ",JSON.stringify(campaign_state(s,seen,cycles)));return
			s.tick(11.99);check(s.wave==number,"The rebuild countdown prevents an early following wave")
			s.tick(.02)
	check(s.wave==10 and s.phase=="complete" and game.won and game.paused and not s.active and s.total_spawned==6000,"Victory waits for all ten drafted waves and all 6,000 enemies")
	check(s.card_history.size()==10 and s.card_history.map(func(entry):return entry.wave)==range(1,11),"The run records exactly one card before each wave and no eleventh choice")
	s.request_card_choice();s.queue_wave();s.tick(999)
	check(s.card_offer.is_empty() and s.card_history.size()==10 and not s.choose_card("supply_cache"),"Victory cannot reopen the draft or grant another upgrade")
	await capture_beta("02-ten-drafts-victory")
	FileAccess.open("res://tests/defense-tactics/campaign.json",FileAccess.WRITE).store_string(JSON.stringify({"roles":role_totals,"bosses":boss_rows,"cards":s.card_history},"\t"))

func hard_and_card_rules():
	await tactics_setup(true)
	var s=game.encounters
	check(s.hard_mode and s.money==650 and s.base_hp==50 and s.base_max_hp==50 and s.cannons.size()==4,"Hard mode begins with four defenses, 650 gold and 50 shrine integrity")
	check(s.tower_count("fire")==2 and s.tower_count("cannon")==2 and s.site_states.slice(4).all(func(site):return site.level==0),"Hard mode leaves five later stations unbuilt while retaining both tower types")
	await click_card(2)
	check(s.money==1650 and s.upgrade_level("supply_cache")==1,"A clicked War Chest card grants exactly 1,000 usable gold")
	await move_to(game.world.cannon_sites[4].build_position)
	var money=s.money;await key(KEY_F)
	check(s.site_states[4].level==1 and s.cannons.size()==5 and s.money==money-s.BUILD_COST,"Hard-mode gold purchases a real defense at an empty wall pad")
	game.restart_area();s=game.encounters;s.set_physics_process(false);await frames(2)
	check(s.hard_mode and game.defense_hard and s.money==650 and s.cannons.size()==4 and s.upgrades.is_empty() and s.card_history.is_empty() and s.phase=="draft","Retry preserves hard difficulty and clears run cards, towers, gold and draft state")
	check(not s.card_eligible("deep_freeze") and not s.card_eligible("shatter") and not s.card_eligible("shrine_repair"),"Dependent cards and unnecessary full-health repairs are excluded from offers")
	check(forced_choice(s,"siege_payload") and s.cannon_path=="siege","Siege Shells chooses and stores the cannon specialization")
	check(not s.card_eligible("piercing_rounds") and not s.card_eligible("siege_payload"),"A selected cannon path excludes both mutually exclusive path cards")
	check(not forced_choice(s,"piercing_rounds") and s.cannon_path=="siege","An injected opposite-path offer is rejected again by the selection handler")
	check(forced_choice(s,"wide_flames") and s.fire_path=="wide" and not s.card_eligible("burning_ground"),"Wildfire selects an independent fire path and excludes Burning Ground")
	check(not forced_choice(s,"burning_ground") and s.fire_path=="wide","An injected opposite fire path cannot overwrite the chosen branch")
	check(forced_choice(s,"fortified_shrine") and s.base_max_hp==75 and s.base_hp==75,"Stone Sanctuary increases both current and maximum shrine integrity")
	s.base_hp=20;game.player.hp=game.player.max_hp-50
	check(s.card_eligible("shrine_repair") and forced_choice(s,"shrine_repair") and s.base_hp==50 and is_equal_approx(game.player.hp,game.player.max_hp-10),"Second Wind applies its real 30 shrine and 40 hero health repair")
	check(forced_choice(s,"rapid_reload") and forced_choice(s,"rapid_reload") and forced_choice(s,"rapid_reload") and not s.card_eligible("rapid_reload"),"Stacked cards stop being eligible at their stated maximum")
	await capture_beta("03-hard-build")

func run_tactics_functional():
	await draft_and_campaign()
	await hard_and_card_rules()
	await tactics_effect_checks()
	await tactics_setup();game.encounters.choose_card("supply_cache")
	var identity=game.player.get_instance_id()
	await shared_controls()
	check(game.player.get_instance_id()==identity,"Tactical defense keeps the original hero instance and shared moveset")
	game.show_main_menu()
	print("DEFENSE_TACTICS_RESULT failures=",failures)
	await finish_beta(1 if failures else 0)

func tactics_effect_checks():
	await tactics_setup();var s=game.encounters
	s.choose_card("ice_shells")
	var cannon=s.site_states[0].cannon;var flame=s.site_states[1].cannon
	await move_to(Vector3(6,0,-150))
	var target=fixture_enemy("runner",Vector3(0,.1,-193));target.set_physics_process(false)
	var traits=target.defense_traits;var hp=target.hp
	cannon.fire_at(target)
	check(cannon.shells.size()==1 and cannon.shells[0].ice and cannon.shells[0].node!=null and cannon.shells[0].node.mesh==DefenseCannon.ice_shell_mesh,"Frost Battery launches a real blue crystal projectile with ice payload")
	var color: Color=cannon.shells[0].node.material_override.albedo_color
	check(color.b>color.r and "ICE" in cannon.badge.text,"The chosen ice element visibly changes cannon trim, label and projectile color")
	for i in range(50):cannon.tick_shells(.05)
	check(target.hp<hp and is_equal_approx(traits.slow_factor,.6) and is_equal_approx(traits.slow_left,2),"A landed ice projectile deals damage and applies its two-second 40% slow")
	check(traits.slow_visual!=null and traits.slow_visual.visible and target.frozen_left==0,"Chill shows a blue enemy status ring while allowing continued movement")
	traits.apply_slow(.7,1)
	check(is_equal_approx(traits.slow_factor,.6) and is_equal_approx(traits.slow_left,2),"Repeated chill keeps the strongest slow without adding durations")
	var remaining=traits.slow_left;game.show_pause();target._physics_process(5);await frames(5)
	check(traits.slow_left==remaining,"Pause freezes the enemy's remaining chill duration")
	game.resume();traits.tick_status(2.01)
	check(traits.slow_left==0 and traits.slow_factor==1 and not traits.slow_visual.visible,"Expired chill fully restores movement and hides the status ring")
	await move_to(Vector3(65,0,-270))
	var march_origin=Vector3(0,.1,-300)
	target.position=march_origin;target.velocity=Vector3.ZERO;target.stun=0;target.impact_pause=0;target.walk_clock=0
	target.defense_offset=Vector3.ZERO;target.defense_waypoint=1;target.state="chase"
	game.tuning.freeze_ai=false;target.set_physics_process(true);await frames(90)
	var normal_distance=target.position.z-march_origin.z
	target.position=march_origin;target.velocity=Vector3.ZERO;target.stun=0;target.walk_clock=0;target.defense_waypoint=1
	traits.apply_slow(.6,6);await frames(90)
	var chilled_distance=target.position.z-march_origin.z
	check(normal_distance>10 and chilled_distance>0 and chilled_distance<normal_distance*.8 and chilled_distance>normal_distance*.4,"Real ice-chilled lane movement is slower but never stops (normal %.2fm, chilled %.2fm)" % [normal_distance,chilled_distance])
	game.tuning.freeze_ai=true;target.set_physics_process(false);traits.tick_status(10)
	target.position=Vector3(0,.1,-193);target.velocity=Vector3.ZERO
	await move_to(Vector3(6,0,-150))
	traits.apply_slow(.01,1000)
	check(traits.slow_factor>=.25 and traits.slow_left<=6,"Even extreme slow input stays bounded and cannot create permanent freeze")
	traits.tick_status(6.1)
	check(forced_choice(s,"deep_freeze") and forced_choice(s,"deep_freeze") and not s.card_eligible("deep_freeze"),"Deep Winter stacks exactly twice after its ice prerequisite")
	cannon.explode(target.position+Vector3.UP,10,3)
	check(is_equal_approx(traits.slow_factor,.4) and is_equal_approx(traits.slow_left,3),"Two Deep Winter picks produce the advertised 60% three-second slow")
	check(forced_choice(s,"shatter"),"Shatter is selectable after ice")
	hp=target.hp;cannon.explode(target.position+Vector3.UP,100,3)
	check(is_equal_approx(hp-target.hp,140),"Shatter increases a real cannon hit on an already chilled target by 40%")
	traits.tick_status(4);hp=target.hp;cannon.explode(target.position+Vector3.UP,100,3)
	check(is_equal_approx(hp-target.hp,100),"The first ice hit chills without retroactively applying Shatter")
	await capture_beta("04-ice-cannon-and-chill")
	await clear_fixture()
	check(forced_choice(s,"cannon_power") and forced_choice(s,"hot_flames") and forced_choice(s,"rapid_reload") and forced_choice(s,"long_sights"),"Damage, reload and sight cards apply through real card selections")
	check(is_equal_approx(cannon.damage(),137.5) and is_equal_approx(flame.damage(),250),"Cannon and fire cards raise only their intended base damage by 25%")
	check(is_equal_approx(cannon.fire_interval(),1.53) and is_equal_approx(flame.fire_interval(),1.7),"Rapid Reload reduces the actual firing intervals of both tower types")
	check(is_equal_approx(cannon.attack_range(),120.75) and is_equal_approx(flame.attack_range(),48.3),"Eagle Watch extends real cannon and flame acquisition ranges by 15%")
	cannon.upgrade(3);flame.upgrade(3)
	check(is_equal_approx(cannon.damage(),300) and is_equal_approx(flame.damage(),525) and cannon.ice_enabled(),"Gold-funded tower levels retain selected run-wide card effects")
	await branch_effect_checks()
	await role_and_boss_checks()
	await tactics_setup();s=game.encounters
	check(forced_choice(s,"bounty_hunters"),"Bounty Charter is eligible and applies to the run")
	s.queue_wave();s.spawn_pending();var victim=living_defenders()[0];var cash=s.money
	victim.take_hit(1000000,Vector3.ZERO,false,{"tower":true,"armor_piercing":true})
	check(s.money==cash+16,"A real owned-enemy kill pays the base bounty plus the selected four-gold bonus")
	victim.take_hit(1000000,Vector3.ZERO,false,{"tower":true})
	check(s.money==cash+16,"A dead enemy cannot pay the upgraded bounty twice")

func branch_effect_checks():
	await tactics_setup();var s=game.encounters
	check(forced_choice(s,"siege_payload"),"The siege branch can be selected independently of ice")
	var cannon=s.site_states[0].cannon;var flame=s.site_states[1].cannon
	check(is_equal_approx(cannon.damage(),126.5) and is_equal_approx(cannon.splash_radius(),10.5),"Siege changes actual shell damage and blast radius by the advertised amounts")
	check(forced_choice(s,"wide_flames") and is_equal_approx(flame.cone_factor(),1.6) and is_equal_approx(flame.attack_range(),37.8),"Wildfire widens the real flame cone while shortening its reach")
	await move_to(Vector3(6,0,70))
	flame.flame_origin=Vector3(0,1,80)
	var side=fixture_enemy("runner",Vector3(6,.1,60));side.set_physics_process(false)
	var hp=side.hp;flame.burn_cone(Vector3.FORWARD,.1)
	check(is_equal_approx(hp-side.hp,20),"The wide flame cone burns an actual side target outside the ordinary cone")
	await tactics_setup();s=game.encounters
	check(forced_choice(s,"piercing_rounds") and forced_choice(s,"burning_ground"),"Piercing and Burning Ground can form the alternate independent tower paths")
	cannon=s.site_states[0].cannon;flame=s.site_states[1].cannon
	check(is_equal_approx(cannon.damage(),154) and is_equal_approx(cannon.splash_radius(),3.5),"Armor Piercer trades half-sized splash for 40% extra shell damage")
	await move_to(Vector3(6,0,70));var brute=fixture_enemy("brute",Vector3(0,.1,60));brute.set_physics_process(false)
	hp=brute.hp;cannon.explode(brute.position+Vector3.UP,100,3)
	check(is_equal_approx(hp-brute.hp,100),"A piercing cannon blast bypasses a real brute's armor mitigation")
	await clear_fixture();var target=fixture_enemy("runner",Vector3(0,.1,60));target.set_physics_process(false)
	flame.flame_origin=Vector3(0,1,80);flame.pool_pending=true
	flame.burn_cone(Vector3.FORWARD,.1)
	check(flame.pool_left==3 and flame.pool_visual!=null and flame.pool_visual.visible and is_equal_approx(flame.attack_range(),33.6),"An unobstructed real flame hit creates the three-second ground pool and applies the path's range tradeoff")
	hp=target.hp;flame.tick_pool(.25)
	check(is_equal_approx(hp-target.hp,12.5) and flame.pool_damage_pulses==1,"Burning Ground deals its actual periodic 50 DPS to a target in the pool")
	var pool_id=flame.pool_visual.get_instance_id();flame.ignite_pool(target.position)
	check(flame.pool_visual.get_instance_id()==pool_id,"Successive ground bursts reuse one pool visual per tower")
	await survey("05-ground-fire",Vector3(14,12,82),Vector3(0,0,60))
	var left=flame.pool_left;hp=target.hp;game.show_pause();flame.tick(5);await frames(5)
	check(flame.pool_left==left and target.hp==hp,"Pause freezes burning-ground lifetime and damage")
	game.resume();flame.tick_pool(3.1);hp=target.hp;flame.tick_pool(10)
	check(flame.pool_left==0 and not flame.pool_visual.visible and target.hp==hp,"The pool expires after its finite lifetime and cannot continue dealing damage")
	flame.ignite_pool(target.position);s.retire_wave_effects()
	check(flame.pool_left==0 and not flame.pool_visual.visible and flame.burst_left==0,"Wave cleanup retires fire jets and pools before the next card draft")

func role_and_boss_checks():
	await tactics_setup();var s=game.encounters;s.choose_card("supply_cache")
	await move_to(Vector3(0,0,86))
	var runner=fixture_enemy("runner",Vector3(-10,.1,65))
	var brute=fixture_enemy("brute",Vector3(10,.1,65))
	var shield=fixture_enemy("shield",Vector3(0,.1,65))
	for actor in [runner,brute,shield]:actor.set_physics_process(false)
	check(runner.defense_health_multiplier==.7 and is_equal_approx(runner.defense_speed_multiplier,1.45) and brute.defense_health_multiplier==1.8 and is_equal_approx(brute.defense_speed_multiplier,.78),"Runner and brute roles apply distinct real health and movement multipliers")
	check(runner.defense_traits.accents!=null and brute.defense_traits.accents!=null and shield.defense_traits.shield.visible,"Enemy roles have visible runner, armor and shield silhouettes")
	var hp=brute.hp;brute.take_hit(100,Vector3.BACK,false,{"tower":true})
	check(is_equal_approx(hp-brute.hp,60),"Brute armor reduces a real ordinary hit by 40%")
	shield.model.rotation.y=0;hp=shield.hp;shield.take_hit(100,Vector3.BACK,false,{"tower":true})
	check(is_equal_approx(hp-shield.hp,30),"Shield enemies mitigate 70% of a real frontal hit")
	hp=shield.hp;shield.take_hit(100,Vector3.FORWARD,false,{"tower":true})
	check(is_equal_approx(hp-shield.hp,100),"A real hit from behind bypasses the shield")
	hp=shield.hp;shield.take_hit(100,Vector3.BACK,true,{"tower":true})
	check(is_equal_approx(hp-shield.hp,100) and shield.defense_traits.shield_broken_left>0 and not shield.defense_traits.shield.visible,"A heavy frontal hit breaks the shield and deals full damage")
	shield.defense_traits.tick_status(1.61)
	check(shield.defense_traits.shield_broken_left==0 and shield.defense_traits.shield.visible,"A broken shield recovers after its finite opening")
	await clear_fixture()
	var boss=fixture_enemy("boss",Vector3(0,.1,80),1);boss.set_physics_process(false)
	var traits=boss.defense_traits;var p=game.player
	check(not boss.boss and boss.defense_boss_tier==1 and is_equal_approx(boss.defense_scale,3.2),"The defense boss is larger and independent of the adventure victory flag")
	traits.apply_slow(.4,3)
	check(traits.slow_factor>=.75 and traits.slow_left<=1.5,"Bosses resist strong ice slows and recover from chill sooner")
	traits.begin_slam();var origin=traits.slam_origin
	check(traits.phase=="warning" and traits.tell.visible and not traits.weak_point.visible,"Boss slam begins with a visible warning circle and a closed weak point")
	await survey("06-boss-warning",Vector3(18,13,103),Vector3(0,1,80))
	game.tuning.freeze_ai=false;game.tuning.invincible=false
	p.invuln=0;p.hp=p.max_hp;var hero_hp=p.hp
	traits.tick_attack(1.24)
	check(p.hp==hero_hp and traits.phase=="warning","The boss warning gives the hero time before any slam damage")
	var elapsed=traits.elapsed;game.show_pause();boss._physics_process(3);await frames(10)
	check(traits.phase=="warning" and traits.elapsed==elapsed and p.hp==hero_hp,"Pause freezes the boss warning and prevents the pending impact")
	game.resume();traits.tick_attack(.02)
	check(traits.phase=="impact" and is_equal_approx(hero_hp-p.hp,28*game.tuning.enemy_damage),"The warned slam deals its actual damage through the shared hero health code")
	traits.tick_attack(.26);hp=boss.hp;boss.take_hit(100,Vector3.BACK,false,{"tower":true})
	check(traits.phase=="recovery" and traits.weak_point.visible and is_equal_approx(hp-boss.hp,200),"The glowing recovery weak point takes double real damage")
	await survey("07-boss-weak-point",Vector3(18,13,103),Vector3(0,4,80))
	traits.tick_attack(1.81)
	check(traits.phase=="march" and not traits.weak_point.visible and not traits.tell.visible,"The boss returns to movement when the finite recovery closes")
	p.position=origin+Vector3(0,2.1,4);p.invuln=0;hero_hp=p.hp
	traits.slam_contact();check(p.hp==hero_hp,"Jumping above the ground slam avoids actual damage")
	p.position=origin+Vector3(0,.1,4);p.invuln=.2;traits.slam_contact()
	check(p.hp==hero_hp,"The existing dodge immunity protects against the boss slam")
	boss.position=Vector3(12,.1,-174);p.position=Vector3(12,.1,-166);p.invuln=0
	traits.begin_slam();await frames(2);hero_hp=p.hp;traits.slam_contact()
	check(p.hp==hero_hp,"A real defense parapet shields the hero from a nearby boss slam")
	traits.cancel_attack();boss.position=Vector3(0,.1,80);traits.begin_slam()
	boss.take_hit(100000000,Vector3.ZERO,false,{"tower":true})
	check(boss.dead and not traits.tell.visible and not traits.weak_point.visible and traits.slow_left==0 and not game.won,"Boss death clears warning, weak-point and chill effects without ending the ten-wave campaign")
	game.tuning.freeze_ai=true;game.tuning.invincible=true;p.hp=p.max_hp

func run_tactics_benchmark():
	if DisplayServer.get_name()=="headless":
		check(false,"Tactics performance evidence requires an actual renderer");get_tree().quit(1);return
	visual=true
	game.settings.quality=1;game.settings.fullscreen=false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_window().size=Vector2i(1280,800);game.apply_quality()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var report={"date":"2026-10-04","renderer":RenderingServer.get_current_rendering_method(),"resolution":"1280x800","quality":1,"vsync":"disabled","fixture":"Synthetic maximum-card stress case exceeds a normal ten-pick build. Real AI, wave-10 roles and boss, 180 durable targets, 24 level-3 towers, ice/siege/shatter/pools and all numeric card stacks; no combat work is stubbed."}
	report.overview=await measure_tactics(false)
	report.frontline=await measure_tactics(true)
	FileAccess.open("res://tests/defense-tactics/performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("DEFENSE_TACTICS_PROFILE ",JSON.stringify(report))
	game.show_main_menu();print("DEFENSE_TACTICS_BENCHMARK failures=",failures)
	await finish_beta(1 if failures else 0)

func measure_tactics(close_view: bool)->Dictionary:
	await tactics_setup();var s=game.encounters;s.choose_card("ice_shells")
	# This intentionally harsher-than-obtainable build tests the renderer and
	# combat budget. Legal ten-card progression is tested separately above.
	s.upgrades={"ice_shells":1,"deep_freeze":2,"shatter":1,"rapid_reload":3,"cannon_power":3,"hot_flames":3,"long_sights":2,"siege_payload":1,"burning_ground":1}
	s.cannon_path="siege";s.fire_path="pool"
	for site in s.site_states:site.level=3;site.cannon.upgrade(3)
	s.wave=9;s.chosen_wave=10;s.phase="rest";s.prep_left=0;s.tick(0)
	await fill_live_cap(s,180)
	var actors=living_defenders();var stations=[-170.0,-100.0,-30.0,40.0,110.0,180.0]
	for i in range(actors.size()):
		var actor=actors[i];var station=i/30;var slot=i%30
		actor.position=Vector3((float(slot%6)-2.5)*1.3,.1,stations[station]-26-float(slot/6)*1.8)
		if close_view:actor.position=Vector3((float(i%9)-4)*1.05,.1,-184-float(i/9)*1.15)
		if actor.defense_boss_tier>0:actor.position=Vector3(0,.1,-180 if close_view else -124)
		actor.defense_offset=Vector3(actor.position.x,0,0);actor.defense_waypoint=1
		actor.hp=2000000;actor.max_hp=2000000;actor.velocity=Vector3.ZERO;actor.stun=0
	await move_to(Vector3(9,0,-164) if close_view else Vector3(35,0,10))
	var eye=Vector3(23,14,-147) if close_view else Vector3(90,200,270)
	var aim=Vector3(0,3,-189) if close_view else Vector3(0,0,-15)
	game.camera_rig.set_process(false);game.camera_rig.camera.global_position=eye
	game.camera_rig.camera.look_at(aim);game.camera_rig.camera.fov=64
	game.tuning.freeze_ai=false;s.set_physics_process(true)
	var warm_until=Time.get_ticks_msec()+2200
	while Time.get_ticks_msec()<warm_until:await get_tree().process_frame
	var samples={"frame_ms":[],"process_ms":[],"physics_ms":[],"render_cpu_ms":[],"gpu_ms":[],"draw_calls":[]}
	var peak_nodes=0;var peak_shells=0;var peak_flames=0;var peak_pools=0;var peak_chilled=0;var minimum=180;var maximum=0
	var firing={};var initial_shots={};var damage_before=0;var pools_before=0;var animation_before=0.0
	for tower in s.cannons:
		initial_shots[tower.get_instance_id()]=tower.shots_fired
		if tower is DefenseFlameTower:damage_before+=tower.damage_pulses;pools_before+=tower.pool_damage_pulses;animation_before+=tower.animation_seconds
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
		var shells=0;var flames=0;var pools=0;var chilled_count=0
		for actor in living_defenders():
			if actor.defense_traits!=null and actor.defense_traits.slow_left>0:chilled_count+=1
		for tower in s.cannons:
			shells+=tower.shells.size()
			if tower.shots_fired>initial_shots[tower.get_instance_id()]:firing[tower.get_instance_id()]=tower is DefenseFlameTower
			if tower is DefenseFlameTower:
				if tower.burst_left>0:flames+=1
				if tower.pool_left>0:pools+=1
		peak_nodes=maxi(peak_nodes,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		peak_shells=maxi(peak_shells,shells);peak_flames=maxi(peak_flames,flames);peak_pools=maxi(peak_pools,pools);peak_chilled=maxi(peak_chilled,chilled_count)
		var active=game.active_enemy_count();minimum=mini(minimum,active);maximum=maxi(maximum,active)
		count+=1
	var flame_fired=0;var cannon_fired=0;var pulses=0;var pool_pulses=0;var animation_time=0.0;var bounded=true
	for key in firing:
		if firing[key]:flame_fired+=1
		else:cannon_fired+=1
	for tower in s.cannons:
		bounded=bounded and tower.shell_pool.size()<=4 and tower.blast_pool.size()<=2
		if tower is DefenseFlameTower:pulses+=tower.damage_pulses;pool_pulses+=tower.pool_damage_pulses;animation_time+=tower.animation_seconds
	var row={"sample_frames":count,"live_enemies_min":minimum,"live_enemies_max":maximum,"flame_towers_firing":flame_fired,"cannons_firing":cannon_fired,"peak_nodes":peak_nodes,"peak_shells":peak_shells,"peak_active_flames":peak_flames,"peak_pools":peak_pools,"peak_chilled":peak_chilled,"flame_damage_pulses":pulses-damage_before,"pool_damage_pulses":pool_pulses-pools_before,"blender_animation_seconds":animation_time-animation_before,"camera_eye":[eye.x,eye.y,eye.z],"camera_target":[aim.x,aim.y,aim.z]}
	for metric in samples:row[metric]=summary_stats(samples[metric])
	row.gpu_timing_available=row.gpu_ms.max>0
	check(minimum==180 and maximum==180 and s.wave==10,"The rendered tactics benchmark retains 180 real wave-10 attackers")
	check(flame_fired>=2 and cannon_fired>=4 if close_view else flame_fired==12 and cannon_fired==12,"The measured tactics battlefield includes active fire towers and ice artillery")
	check(row.flame_damage_pulses>0 and row.pool_damage_pulses>0 and peak_chilled>0 and bounded,"The sample exercises actual fire, pools, ice status and bounded projectile visuals")
	await capture_beta("benchmark-frontline" if close_view else "benchmark-overview")
	s.set_physics_process(false);game.tuning.freeze_ai=true;game.camera_rig.set_process(true)
	return row

func run():
	visual="--defense-tactics-visual" in OS.get_cmdline_user_args()
	if "--defense-tactics-benchmark" in OS.get_cmdline_user_args():await run_tactics_benchmark()
	else:await run_tactics_functional()
