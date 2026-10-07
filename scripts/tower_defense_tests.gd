extends "res://scripts/musashi_tests.gd"

# Integration checks deliberately drive the shared player, real world collision,
# enemy physics and cannon projectiles, rather than replacing them with stubs.
func frames(count: int):
	for i in range(count):await get_tree().physics_frame

func hold(code: Key,down: bool):
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()
	await frames(1)

func capture_defense(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0;game.player.invuln=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/tower-defense/"+label+".png")

func survey(label: String,eye: Vector3,target: Vector3):
	if not visual:return
	game.camera_rig.set_process(false)
	game.camera_rig.camera.global_position=eye
	game.camera_rig.camera.look_at(target)
	game.camera_rig.camera.fov=65
	await frames(2);await capture_defense(label)
	game.camera_rig.set_process(true);game.camera_rig.reset_follow()

func drain_spawns(director):
	for i in range(100):
		if director.pending<=0:return
		director.tick(0)
		await frames(1)
	check(false,"Queued defense arrivals finish within 100 ticks")

func living_defenders()->Array:
	return game.enemies.filter(func(enemy):return is_instance_valid(enemy) and not enemy.dead and enemy.defense_lane>=0)

func move_to(point: Vector3):
	game.player.smoke_move=Vector2.ZERO
	game.reset_player_at(Vector3(point.x,.15,point.z))
	await frames(15)

func full_lane_traversal():
	# Isolate one genuinely spawned actor per lane, then let normal enemy
	# physics traverse the entire route, including the merge into the shrine.
	var director=game.encounters
	director.tick(director.prep_left+.01);await drain_spawns(director)
	var runners=[]
	for actor in living_defenders():
		if runners.size()<3:runners.append(actor)
		else:actor.queue_free()
	await frames(2);director.tick(0)
	await move_to(Vector3(285,0,250))
	var money_before=director.money;var kills_before=game.kills
	# 3x retains a 0.05-second physics step that fits the shared 0.15-second
	# crowd sweep interval; very large steps artificially slow its interpolation.
	game.tuning.freeze_ai=false;Engine.time_scale=3
	var lane_counts=[0,0,0]
	for runner in runners:lane_counts[runner.defense_lane]+=1
	for i in range(3000):
		if director.wave_breaches==3:break
		await frames(1)
	Engine.time_scale=1;game.tuning.freeze_ai=true
	var remaining_positions=[]
	for runner in runners:
		if is_instance_valid(runner):remaining_positions.append({"lane":runner.defense_lane,"at":runner.position,"waypoint":runner.defense_waypoint})
	check(lane_counts==[1,1,1] and director.wave_breaches==3 and director.base_hp==director.base_max_hp-3,"One attacker from each gate traverses the entire physical lane and merged approach to breach the shrine (breaches=%d, remaining=%s)" % [director.wave_breaches,remaining_positions])
	check(director.money==money_before and game.kills==kills_before,"Complete unopposed lane traversal awards no kills or money")
	game.restart_area();game.encounters.set_physics_process(false);await frames(15)

func shared_controls():
	var p=game.player
	p.select_character(1);p.set_gold_cloak(false);p.set_scarf_equipped(false)
	await move_to(Vector3(0,0,100))
	game.camera_rig.yaw=0;p.facing=Vector3.FORWARD;p.soft_target=false
	var start=p.position
	p.smoke_move=Vector2.RIGHT;await frames(30);p.smoke_move=Vector2.ZERO
	check(p.position.x>start.x+2,"The existing hero walks across the defense battlefield")
	await frames(15);await key(KEY_SPACE);await frames(12)
	check(p.jumps_used==1 and p.position.y>1,"The existing jump works on the defense floor")
	await key(KEY_SPACE);await frames(8)
	check(p.jumps_used==2,"The existing double jump remains available")
	await move_to(Vector3(0,0,100));p.dodge_cooldown=0
	await key(KEY_C)
	check(p.dodge_time>0 or p.forward_dash.active,"The existing evade/dash input remains available")
	await frames(45);await move_to(Vector3(0,0,100))
	p.select_weapon(1);p.facing=Vector3.FORWARD
	var target=dummy(Vector3(0,0,-2.5))
	await mouse(true);await mouse(false);await frames(110)
	check(is_equal_approx(target.hp,867.6),"One physical pipe click retains the existing hit-confirmed triplet and red follow-ups (132.4 damage; actual %.1f)" % (1000-target.hp))
	game.clear_practice();await frames(2)
	await move_to(Vector3(0,0,100));target=dummy(Vector3(0,0,-6))
	var origin=p.position
	await key(KEY_T);await frames(55)
	check(target.hp<1000 and p.position.distance_to(origin)<.5,"Sky Strike damages enemies and returns to its origin in defense")
	game.clear_practice();await frames(2)
	await key(KEY_2);check(p.quick_attacks.coins_enabled and p.weapon_slot==1,"2 still toggles automatic coins without replacing the pipe")
	await key(KEY_2);await key(KEY_3)
	check(p.chain_pipe_combat.active and p.chain_pipe_combat.mode=="sweep","3 still performs the existing chain-pipe sweep")
	await frames(90);await key(KEY_1)
	check(p.quick_attacks.active and p.attack_charged,"1 still performs the existing powered wind spin")
	await frames(90);await key(KEY_R)
	check(p.surge_left>0,"The original Goemon surge remains available")
	p.end_surge();await key(KEY_5)
	var altitude=p.position.y
	await hold(KEY_SPACE,true);await frames(60);await hold(KEY_SPACE,false)
	check(p.flying and p.position.y>altitude+8,"Gold cloak flight remains available in the defense mode")
	await capture_defense("05-shared-gold-flight")
	p.set_gold_cloak(false);await move_to(Vector3(0,0,100))
	await key(KEY_Q)
	if game.rogue_roster_mode:
		check(game.rogue_roster_open,"Q opens the shared Fire Siege hero roster")
		game.menu.find_child("RogueFighter_edo",true,false).pressed.emit();await frames(2)
	check(p.character_id==2 and p.musashi.active,"Hero selection preserves the existing Edo character and combat system")
	target=dummy(Vector3(0,0,-6));p.musashi.ranged_mode=true
	await mouse(true);await frames(32);await mouse(false);await frames(50)
	check(target.hp<1000,"Edo's original ranged attack damages a real target in defense")
	game.clear_practice();await frames(2);p.select_character(1)

func cover_checks():
	var walls=game.world.cover_walls
	check(walls.size()>=6,"All three routes provide repeated solid cover positions")
	if walls.is_empty():return
	var wall=walls[0]
	var center=wall.global_position
	# Offset from the decorative center post to test the parapet itself.
	var from=Vector3(center.x+2,1.2,center.z+5)
	var to=Vector3(center.x+2,1.2,center.z-5)
	var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))
	check(not hit.is_empty() and hit.collider==wall,"Cover physically blocks a chest-height line of sight")
	await move_to(from)
	game.camera_rig.yaw=0;game.player.facing=Vector3.FORWARD
	game.player.smoke_move=Vector2.UP;await frames(75);game.player.smoke_move=Vector2.ZERO
	check(game.player.position.z>center.z+1,"Normal hero movement cannot walk through the cover wall")
	await move_to(from)
	game.player.facing=Vector3.FORWARD;game.player.soft_target=false;game.player.select_weapon(2)
	var target=dummy(to-game.player.position)
	game.throw_coin(false);await frames(45)
	check(target.hp==1000,"The real coin projectile cannot damage a target through defense cover")
	await survey("03-solid-cover",from+Vector3(10,9,8),Vector3(center.x,1,center.z))
	game.clear_practice();game.player.select_weapon(1);await frames(2)

func run():
	visual="--tower-defense-visual" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/tower-defense"))
	Input.use_accumulated_input=false
	get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	game.camera_rig.set_process_unhandled_input(false)
	game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.invincible=true;game.tuning.freeze_ai=true
	var mode_buttons=game.menu.find_children("*","Button",true,false)
	check(mode_buttons.any(func(button):return "defense" in button.text.to_lower()),"Main menu exposes a separate tower defense choice")
	await capture_defense("01-main-menu")
	var hero_id=game.player.get_instance_id()
	game.start_mode("defense")
	var s=game.encounters;var p=game.player
	s.set_physics_process(false);p.smoke_mode=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await frames(15)
	var starting_money=s.money
	check(game.tower_defense_mode and not game.descent_mode and game.playing,"Choosing defense enters a separate running mode")
	check(p.get_instance_id()==hero_id,"Defense reuses the original playable character instance")
	check(game.world.playable_bounds.size.x>=600 and game.world.playable_bounds.size.y>=700,"Defense battlefield spans at least 600 by 700 world units")
	check(game.world.cannon_sites.size()>=6 and s.cannons.is_empty(),"Unbuilt cannon sites are provided along the three lanes")
	check(s.base_hp==s.base_max_hp and s.phase=="preparing" and s.wave==0 and living_defenders().is_empty(),"A fresh run starts with a healthy shrine and an enemy-free preparation window")
	var prep=s.prep_left
	s.tick(prep-.1)
	check(s.wave==0 and living_defenders().is_empty(),"Opening enemies wait through the full preparation window")
	s.tick(.11);await drain_spawns(s)
	check(s.wave==1 and living_defenders().size()==s.wave_size(1),"The opening wave creates its complete scheduled swarm")
	var lanes=[0,0,0];var distant=true;var starts={}
	for enemy in living_defenders():
		lanes[enemy.defense_lane]+=1;starts[enemy.get_instance_id()]=enemy.position
		distant=distant and enemy.position.distance_to(p.position)>180
	check(lanes[0]>0 and lanes[1]>0 and lanes[2]>0 and lanes.max()-lanes.min()<=1,"The incoming swarm is evenly divided among all three pathways")
	check(distant,"Every opening attacker begins more than 180 units from the hero")
	await survey("02-three-lane-battlefield",Vector3(420,460,580),Vector3(0,0,-15))
	await move_to(Vector3(280,0,-270));game.tuning.freeze_ai=false
	await frames(180);game.tuning.freeze_ai=true
	var advancing=0;var on_path=true
	for enemy in living_defenders():
		var before: Vector3=starts[enemy.get_instance_id()]
		if enemy.position.z>before.z+2:advancing+=1
		on_path=on_path and absf(enemy.position.x-[-160,0,160][enemy.defense_lane])<14
	check(advancing==living_defenders().size(),"Every lane advances toward the shrine while the hero is far away")
	check(on_path,"Attackers keep their assigned pathway instead of cutting across to the hero")
	var flankers=[living_defenders()[0],living_defenders()[1]]
	for i in range(flankers.size()):
		var flanker=flankers[i]
		flanker.position=Vector3([-160,0,160][flanker.defense_lane]+25,.1,-166 if i==0 else -174)
		flanker.defense_offset=Vector3.ZERO;flanker.defense_waypoint=1;flanker.velocity=Vector3.ZERO
	game.tuning.freeze_ai=false;await frames(360);game.tuning.freeze_ai=true
	var recovered=true
	for flanker in flankers:
		recovered=recovered and absf(flanker.position.x-[-160,0,160][flanker.defense_lane])<6 and flanker.position.z> -162
	check(recovered,"Raiders displaced beside either side of a cover station rejoin their lane and continue downstream (positions %s, %s)" % [flankers[0].position,flankers[1].position])
	var victim=living_defenders()[0];var cash=s.money;var kills=game.kills
	victim.take_hit(1,Vector3.FORWARD,false)
	check(s.money==cash,"Nonlethal damage does not award defense money")
	victim.take_hit(100000,Vector3.FORWARD,true)
	check(s.money>cash and game.kills==kills+1,"A real enemy death awards money and one kill")
	var rewarded=s.money
	victim.take_hit(100000,Vector3.FORWARD,true);s.record_defeat(victim)
	check(s.money==rewarded and game.kills==kills+1,"A corpse cannot pay its bounty twice")
	var practice=dummy(Vector3(0,0,-4));practice.take_hit(100000,Vector3.FORWARD,true)
	check(s.money==rewarded,"Practice enemies cannot be farmed for defense money")
	game.clear_practice();await frames(2)
	var elapsed=s.elapsed;var wave=s.wave;var enemy=living_defenders()[0];var at=enemy.position
	game.show_pause();s.tick(120);await frames(10)
	check(s.elapsed==elapsed and s.wave==wave and enemy.position==at,"Pause freezes defense time, waves, and enemy movement")
	game.resume()
	await cover_checks()
	var site=game.world.cannon_sites[0]
	await move_to(site.position+Vector3(0,0,6))
	s.money=0
	check(not s.try_purchase() and s.cannons.is_empty(),"Insufficient money cannot purchase a cannon")
	s.money=s.site_cost(0);var cost=s.money
	await move_to(Vector3(280,0,280))
	check(not s.try_purchase() and s.money==cost,"A distant cannon site cannot spend money")
	await move_to(site.position+Vector3(0,0,6))
	check(not s.interaction_prompt().is_empty(),"Nearby cover exposes its cannon purchase prompt")
	await key(KEY_F)
	check(s.site_states[0].level==1 and s.cannons.size()==1 and s.money==0,"Physical F builds one cannon and deducts its exact cost")
	check(not s.try_purchase() and s.cannons.size()==1,"Repeated unaffordable interaction does not duplicate a cannon")
	s.money=s.site_cost(0);await key(KEY_F)
	check(s.site_states[0].level==2 and s.cannons.size()==1 and s.money==0,"Physical F upgrades the existing cannon rather than building a duplicate")
	var cannon=s.cannons[0]
	var cannon_target=living_defenders().filter(func(e):return e.defense_lane==site.lane)[0]
	cannon_target.position=Vector3([-160,0,160][site.lane],.1,site.position.z-28)
	cannon_target.velocity=Vector3.ZERO;cannon_target.hp=2000;cannon_target.max_hp=2000
	cannon.cooldown=0
	for i in range(150):
		cannon.tick(1.0/60);await frames(1)
	check(cannon_target.hp<2000 and not cannon_target.dead,"A purchased cannon automatically acquires an incoming enemy and deals real projectile damage")
	check(s.money==0,"A cannon's nonlethal hits do not generate free money")
	cannon.fire_at(cannon_target)
	var shell=cannon.shells[-1];var shell_age=shell.age;var shell_at=shell.node.global_position
	var cannon_cooldown=cannon.cooldown;var target_hp=cannon_target.hp
	game.show_pause();cannon.tick(2);s.tick(2);await frames(10)
	check(shell.age==shell_age and shell.node.global_position==shell_at and cannon.cooldown==cannon_cooldown and cannon_target.hp==target_hp,"Pause also freezes cannon cooldown, an in-flight shell, and its damage")
	game.resume()
	var hero_kills=p.progression.total_kills
	p.hp=p.max_hp-20;var hero_hp=p.hp;var links=p.attack_chain.count
	cannon_target.hp=1;cannon.cooldown=0
	for i in range(80):
		cannon.tick(1.0/60);await frames(1)
	check(s.money==s.KILL_REWARD,"A real cannon projectile kill awards exactly one enemy bounty")
	check(p.hp==hero_hp and p.progression.total_kills==hero_kills and p.attack_chain.count<=links,"Cannon kills do not farm hero healing, personal progression, or attack-chain links")
	await survey("04-purchased-cannon",site.position+Vector3(18,12,22),site.position+Vector3(0,0,-13))
	for remaining in living_defenders():remaining.take_hit(100000,Vector3.FORWARD,true)
	s.tick(0)
	check(s.phase=="rest" and s.next_wave_in()>10,"Clearing the wave grants a meaningful rebuild interval")
	var respite=s.next_wave_in();var settled_wave=s.wave
	s.tick(respite-.1)
	check(s.wave==settled_wave and living_defenders().is_empty(),"The next swarm cannot spawn early during the rebuild interval")
	s.tick(.11);await drain_spawns(s)
	check(s.wave==2 and living_defenders().size()>s.wave_size(1),"The next wave arrives after the interval and increases the challenge")
	var breach_target=living_defenders()[0]
	var base_before=s.base_hp;cash=s.money;kills=game.kills
	breach_target.position=game.world.base_position;breach_target.defense_waypoint=game.world.lanes[breach_target.defense_lane].size()-1
	game.tuning.freeze_ai=false;await frames(5);game.tuning.freeze_ai=true
	check(s.base_hp<base_before and s.wave_breaches==1,"An attacker that reaches the shrine damages the objective")
	check(s.money==cash and game.kills==kills,"A shrine breach awards neither kill credit nor money")
	s.base_hp=1;breach_target=living_defenders()[0]
	breach_target.position=game.world.base_position;breach_target.defense_waypoint=game.world.lanes[breach_target.defense_lane].size()-1
	game.tuning.freeze_ai=false;await frames(5);game.tuning.freeze_ai=true
	check(s.base_hp==0 and game.paused and not s.active and not game.won,"Destroying the shrine ends defense in defeat")
	await capture_defense("06-shrine-defeat")
	game.restart_area();s=game.encounters;s.set_physics_process(false);await frames(15)
	check(game.tower_defense_mode and not game.paused and s.active and s.base_hp==s.base_max_hp and s.money==starting_money and s.cannons.is_empty() and s.wave==0 and game.kills==0,"Retry resets shrine, money, cannon purchases, waves, and kills")
	await full_lane_traversal();s=game.encounters
	await shared_controls()
	game.show_main_menu();check(not game.playing and not s.active,"Returning to the menu stops defense")
	game.start_mode("survival");game.encounters.set_physics_process(false)
	check(not game.tower_defense_mode and not game.descent_mode and game.encounters is SwarmSurvival and game.encounters.active,"The original survival mode still starts after defense")
	check(game.player.get_instance_id()==hero_id,"Changing modes preserves the shared hero controller")
	game.show_main_menu();game.start_mode("descent");game.encounters.set_physics_process(false)
	check(game.descent_mode and not game.tower_defense_mode and game.world.sky_islands!=null and game.encounters.active,"The original sky descent still starts after defense")
	game.show_main_menu()
	print("TOWER_DEFENSE_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
