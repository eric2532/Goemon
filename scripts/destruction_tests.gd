extends "res://scripts/attack_chain_tests.gd"
var fixtures: Array=[]
func frames(n: int):
	for i in range(n):await get_tree().physics_frame
func fixture(offset=Vector3(0,0,-4))->BreakableBuilding:
	var root=Node3D.new();game.world.add_child(root);root.global_position=game.player.global_position+offset
	Geo.box(root,Vector3.UP*4,Vector3(6,8,4),Geo.mat("ab805a"),true)
	var part=BreakableBuilding.attach(root,game.world);fixtures.append(part)
	return part
func fresh_site():
	for part in fixtures:
		game.world.breakable_buildings.erase(part);part.building.queue_free()
	fixtures.clear()
	await clean();game.player.buildings_broken=0;game.player.scale=Vector3.ONE
	await frames(2)
func prime_links(count: int):
	game.player.attack_chain.reset()
	for i in range(count):game.player.attack_chain.confirm(game.player.attack_chain.begin("pipe"))
func screenshot(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/destruction/"+label+".png")
func run():
	visual="--destruction-visual" in OS.get_cmdline_user_args()
	if visual:DirAccess.make_dir_recursive_absolute("res://tests/destruction")
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.child_entered_tree.connect(observe_projectile);game.child_entered_tree.connect(observe_energy)
	var p=game.player
	check(game.world.breakable_buildings.filter(func(b):return b.objective_island<0).size()==157,"All 48 town houses, 96 furnished buildings and 13 temples are destructible")
	await fresh_site();var part=fixture();part.hp=48;await frames(2)
	await screenshot("01-before")
	await mouse(true,true);await mouse(false,true);await drain()
	check(part.destroyed and not part.building.visible and p.buildings_broken==1,"A real heavy pipe hit destroys a building and awards growth once")
	check(p.attack_chain.count==1 and is_equal_approx(p.growth_multiplier(),1.02) and p.scale.is_equal_approx(Vector3.ONE*1.02),"Building hits count toward the combo and a destruction grows the character two percent")
	var ray=PhysicsRayQueryParameters3D.create(part.bounds.get_center()+Vector3.BACK*10,part.bounds.get_center()+Vector3.FORWARD*10,1)
	check(game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Destroyed building collision disappears instead of leaving an invisible wall")
	part.take_hit(10000,p.attack_chain.begin("pipe"),part.bounds.get_center())
	check(p.buildings_broken==1,"A destroyed building cannot grant repeated growth")
	await screenshot("02-after")
	await fresh_site();part=fixture(Vector3(0,0,-8));await frames(2)
	press_melee("weapon_coin");press_melee("weapon_coin");await drain();await wait(.5)
	check(is_equal_approx(part.hp,BreakableBuilding.HEALTH-20) and p.attack_chain.count==1,"A real coin projectile damages the building it collides with")
	await fresh_site();part=fixture();await frames(2)
	var cover=Geo.box(game,p.position+Vector3(0,2,-1),Vector3(8,6,.3),Geo.mat("888888"),true);await frames(2)
	BreakableBuilding.hit_area(game,p.position+Vector3.UP,8,100,p.attack_chain.begin("pipe"),Vector3.FORWARD)
	check(part.hp==BreakableBuilding.HEALTH and p.attack_chain.count==0,"Solid cover blocks building damage and prevents false combo credit")
	cover.queue_free()
	await fresh_site();part=fixture();await frames(2)
	p.struck_targets.clear();p.attack_ticket=p.attack_chain.begin("heavy");p.attack_heavy=true;p.attack_charged=false;p.hit_done=false
	p.strike();p.strike();p.strike()
	check(is_equal_approx(part.hp,BreakableBuilding.HEALTH-48) and p.attack_chain.count==1,"Repeated contact samples cannot damage the same building more than once per melee swing")
	await fresh_site();var enemy=target(Vector3(0,0,-7));enemy.set_physics_process(false)
	press_melee("heavy_attack");await drain()
	check(enemy.hp==10000,"A normal-sized heavy swing cannot reach a distant enemy")
	for i in range(100):p.grow_from_building()
	check(p.growth_multiplier()==2 and p.range_multiplier()==2 and p.scale==Vector3.ONE*2,"Growth caps at double size and doubles melee range")
	press_melee("heavy_attack");await drain()
	check(enemy.hp==9952,"The larger character can hit that same distant enemy")
	await frames(20)
	check(p.is_on_floor(),"The enlarged physical character remains grounded")
	var coin=game.spawn_gold_coin(p.position+Vector3.UP*2.5,Vector3.FORWARD)
	check(is_equal_approx(coin.velocity.length()*coin.lifetime,128) and is_equal_approx(coin.hit_radius,.6),"Growth doubles projectile travel distance and hit width")
	await screenshot("03-grown")
	await fresh_site();enemy=target(Vector3(0,0,-2.4));enemy.hp=100000;enemy.max_hp=100000;enemy.set_physics_process(false)
	prime_links(99);check(not p.attack_chain.unleashed(),"Ninety-nine links do not unlock instant casting")
	p.attack_chain.confirm(p.attack_chain.begin("pipe"));check(p.attack_chain.unleashed(),"Exactly one hundred confirmed links unlock instant casting")
	var immediate=true;var hp=enemy.hp
	for action in ["weapon_pipe","weapon_coin","weapon_chain","light_attack","heavy_attack"]:
		press_melee(action)
		immediate=immediate and p.attack_left==0 and p.quick_attacks.pending.is_empty() and not p.chain_pipe_combat.active
	check(immediate and enemy.hp<hp and shots.size()==1,"1, 2, 3, LMB and RMB all release in the input frame without queues or recovery locks")
	var prior=shots.size()
	for i in range(5):press_melee("weapon_coin")
	check(shots.size()==prior+2 and p.attack_left==0 and not p.quick_attacks.coins_enabled,"Unleashed key 2 still toggles, with one immediate cast for each OFF-to-ON press")
	await screenshot("04-unleashed")
	game.show_pause();prior=shots.size();press_melee("weapon_coin")
	check(shots.size()==prior,"Pause still prevents unleashed attacks")
	game.resume();p.attack_chain.tick(AttackChain.GRACE+.1,false);prior=shots.size();press_melee("weapon_coin")
	check(not p.attack_chain.unleashed() and shots.size()==prior+1 and p.attack_left==0,"Expired combo retains the independent coin toggle without adding ranged red slashes")
	await fresh_site();await key(KEY_Q);prime_links(100)
	for action in ["weapon_pipe","weapon_coin","weapon_chain"]:press_melee(action)
	check(get_tree().get_nodes_in_group("edo_fireballs").size()==4 and get_tree().get_nodes_in_group("edo_meteor_rains").size()==1 and p.attack_left==0 and p.musashi.meteor_pending==0,"Edo's 1, 2 and 3 instantly release volley, giant fireball and meteor rain at 100 links")
	press_melee("heavy_attack");press_melee("light_attack")
	check(get_tree().get_nodes_in_group("edo_fireballs").size()==8 and p.attack_left==0,"Edo mouse attacks also release immediately after number-key spells")
	p.musashi.shield_cooldown=99;press_melee("surge")
	check(p.musashi.empowered() and p.musashi.shield_cooldown==0,"Unleashed shield ignores and clears its cooldown")
	await fresh_site();await key(KEY_Q);part=fixture(Vector3(0,0,-8));await frames(2)
	p.musashi.cast_fireball(true);await attack_frames();await wait(.5)
	check(is_equal_approx(part.hp,BreakableBuilding.HEALTH-96),"Giant fireball damages a building once, without duplicating its direct hit in the explosion")
	await fresh_site();part=fixture();await frames(2)
	press_melee("equip");await wait(.3)
	check(is_equal_approx(part.hp,BreakableBuilding.HEALTH-4),"A collision-aware dash damages the building it reaches only once")
	await fresh_site();enemy=target(Vector3(0,0,-6));enemy.set_physics_process(false);prime_links(100)
	press_melee("sky_strike")
	check(enemy.hp==9760 and not p.sky_strike.active and p.attack_left==0,"Unleashed Sky Strike resolves immediately without its leap windup")
	p.dodge_cooldown=99;var dash_origin=p.position;press_melee("equip")
	check(p.dodge_cooldown==0 and not p.forward_dash.active and p.position.distance_to(dash_origin)>3.5,"Unleashed dash bypasses cooldown and completes its collision-aware movement immediately: distance=%s cooldown=%s active=%s" % [p.position.distance_to(dash_origin),p.dodge_cooldown,p.forward_dash.active])
	await fresh_site();await key(KEY_Q);part=fixture(Vector3(0,0,-8));await frames(2)
	p.musashi.activate_shield();p.musashi.start_beam();p.musashi.beam.damage_tick()
	check(part.hp<BreakableBuilding.HEALTH,"Piercing beam damages buildings along its path")
	p.musashi.stop_hold_beam()
	await fresh_site();await key(KEY_Q);part=fixture();await frames(2)
	p.musashi.activate_shield();p.musashi.shield_damage()
	check(part.hp<BreakableBuilding.HEALTH,"Shield pulses can damage a nearby building")
	await fresh_site();await key(KEY_Q);part=fixture();await frames(2)
	var meteor=EdoMeteorRain.new();meteor.game=game;meteor.hero=p;meteor.attack_ticket=p.attack_chain.begin("meteors");game.add_child(meteor)
	meteor.impact(part.nearest(p.position+Vector3.UP));meteor.queue_free()
	check(part.destroyed and part.hp==0,"Meteor impact applies its area damage to a building")
	var complete=game.encounters.completed;game.encounters.completed=true;prime_links(100);p.dodge_cooldown=99
	press_melee("equip")
	check(p.dodge_cooldown==0 and not p.musashi.teleport.active and p.model.visible,"Unleashed fire dodge has no cooldown or disappearance windup")
	game.encounters.completed=complete
	var furnished=game.world.breakable_buildings.filter(func(b):return b.building.get_parent()==game.world.furnished_town)[0]
	furnished.take_hit(10000,p.attack_chain.begin("pipe"),furnished.bounds.get_center());await frames(3)
	game.world.furnished_town.update_cutaway(furnished.bounds.get_center(),0)
	check(furnished.destroyed and not furnished.building.visible,"Destroyed furnished rooms stay hidden when the camera updates its interior cutaway")
	var original_count=game.world.breakable_buildings.size();game.restart_area();await frames(10)
	check(p.buildings_broken==0 and p.scale==Vector3.ONE and p.attack_chain.count==0 and game.world.breakable_buildings.filter(func(b):return b.objective_island<0).size()==157,"Restart restores buildings and resets growth and the 100-link state")
	check(get_tree().get_nodes_in_group("building_rubble").is_empty(),"Restart removes old destruction rubble")
	print("DESTRUCTION_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
