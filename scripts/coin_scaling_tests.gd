extends "res://scripts/destruction_tests.gd"
var records: Array=[]
var arena=Vector3(0,850,0)
var impacts=0

func observe_coin(node: Node):
	if node is GoldCoin and not node.hostile:
		records.append({"count":node.coin_count,"energy":node.combo_energy,"ticket":node.attack_ticket,"piercing":node.piercing,"node":node})

func fresh_coins(level: int=1):
	await fresh_site();records.clear()
	var p=game.player;p.progression.reset(true);p.progression.award_kills(level-1);p.refresh_max_health(true)
	game.reset_player_at(arena+Vector3.UP*.1);await frames(8);aim_camera()

func toss():
	press_melee("weapon_coin");press_melee("weapon_coin")

func capture_coins_level(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0;game.player.invuln=0;game.player.model.show()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/coin-scaling/"+label+".png")

func run():
	visual="--coin-scaling-visual" in OS.get_cmdline_user_args()
	if visual:DirAccess.make_dir_recursive_absolute("res://tests/coin-scaling")
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	Geo.box(game,arena-Vector3.UP,Vector3(100,2,100),Geo.mat("527978"),true)
	game.child_entered_tree.connect(observe_coin)
	var p=game.player;var curve=preload("res://scripts/level_progression.gd").new();curve.reset(true)
	var levels=true
	for level in range(1,100):
		levels=levels and curve.coin_count()==level;curve.award_kills()
	check(levels and curve.coin_count()==99,"Every earned level adds one coin, from 1 through the level-99 cap")
	for level in [1,2,10,50,99]:
		await fresh_coins(level);toss()
		check(records.size()==1 and records[0].count==level and not records[0].energy,"Level %d emits exactly %d real coins without a red projectile" % [level,level])
		if level>1:
			var volley=records[0].node
			check(volley.batches.size()>0 and volley.batches.size()<=4 and volley.batches[0].multimesh.instance_count==level,"Level %d shares instanced meshes instead of per-coin scenes" % level)
			check(volley.velocities[0].is_equal_approx(volley.velocity),"The center of the level-%d fan retains the exact aim direction" % level)
		await frames(12)
		if level in [10,99]:await capture_coins_level("01-level-%d-volley" % level)
	await fresh_coins(2)
	var enemy=target(Vector3(0,0,-6));enemy.set_physics_process(false);toss();await frames(35)
	check(enemy.hp==9960 and p.attack_chain.count==1,"Both level-2 coins deal real damage while the volley earns one combo link")
	check(get_tree().get_nodes_in_group("coin_volleys").is_empty(),"A spent volley releases its controller and instances")
	await fresh_coins(99);enemy=target(Vector3(0,0,-6));enemy.body_radius=3.1;enemy.hp=100000;enemy.max_hp=100000;enemy.set_physics_process(false)
	impacts=0;var observer=func(_victim,_strength,_duration):impacts+=1
	game.impact_confirmed.connect(observer);toss();await frames(40);game.impact_confirmed.disconnect(observer)
	check(enemy.hp==98020 and p.attack_chain.count==1,"All 99 coins can hit for their full 1980 base damage without farming combo links")
	check(impacts<15,"Dense hits merge their feedback by victim/frame instead of producing 99 impact effects")
	await fresh_coins(10);enemy=await prime();enemy.position=p.position+Vector3(0,0,-6);enemy.set_physics_process(false);var before=enemy.hp
	records.clear();toss();await frames(35)
	check(enemy.hp<before and p.attack_chain.count==2 and records.size()==1 and not records[0].energy and get_tree().get_nodes_in_group("combo_bonus_attacks").is_empty(),"Heavy → coins keeps hit-based combo damage but never triggers a red slash")
	enemy.position=p.position+Vector3(0,0,-2.4);before=enemy.hp;press_melee("weapon_pipe")
	check(p.hit_done and enemy.hp<before and p.attack_chain.count==4 and not get_tree().get_nodes_in_group("combo_bonus_attacks").is_empty(),"A following melee spin still triggers its immediate red bonus hit")
	await drain();await fresh_coins(10)
	p.attack_chain.confirm(p.attack_chain.begin("heavy"));p.select_weapon(2);press_melee("light_attack");await drain()
	check(records.size()==1 and records[0].count==1 and not records[0].energy,"Manual coin attacks also lose red bonuses while level scaling remains specific to toggle 2")
	await fresh_coins(10);p.set_scarf_equipped(true);p.activate_surge();p.attack_chain.confirm(p.attack_chain.begin("heavy"));toss()
	check(records.size()==2 and records[0].count==10 and records[0].piercing and records[1].count==1 and not records[1].piercing,"R scales the whole giant-coin volley and the robe adds its usual regular coin")
	check(records.all(func(r):return not r.energy),"Even powered, robed combo volleys never create ranged red slashes")
	await fresh_coins(2);p.activate_surge()
	var first=target(Vector3(0,0,-6));var second=target(Vector3(0,0,-12));var covered=target(Vector3(0,0,-20))
	for victim in [first,second,covered]:victim.set_physics_process(false)
	var wall=Geo.box(game,p.position+Vector3(0,2,-16),Vector3(14,8,.5),Geo.mat("888888"),true);await frames(2)
	toss();await frames(50)
	check(first.hp==9860 and second.hp==9860 and covered.hp==10000,"Each giant coin pierces two targets once, then stops at solid cover")
	check(p.attack_chain.count==1,"Piercing multi-target hits share the volley's single combo link")
	wall.queue_free();await fresh_coins(99)
	enemy=target(Vector3(0,0,-12));enemy.set_physics_process(false)
	wall=Geo.box(game,p.position+Vector3(0,2,-5),Vector3(40,8,.5),Geo.mat("888888"),true);await frames(2)
	toss();await frames(60)
	check(enemy.hp==10000 and p.attack_chain.count==0,"A wall blocks the entire 99-coin fan and prevents false combo credit")
	wall.queue_free();await fresh_coins(10)
	var building=fixture(Vector3(0,0,-7));await frames(2);toss();await frames(40)
	check(is_equal_approx(building.hp,40) and p.attack_chain.count==1,"Ten batched coins damage a real building for 200 total and one combo link")
	toss();await frames(30)
	check(building.destroyed and p.buildings_broken==1,"Coin volleys can demolish a building and award growth exactly once")
	await fresh_coins(1);press_melee("weapon_coin");await frames(10)
	p.progression.award_kills(9);await frames(30);press_melee("weapon_coin")
	check(records[0].count==1 and records[-1].count==10,"Leveling during an enabled toggle updates the very next volley")
	await fresh_coins(99);press_melee("weapon_coin");await frames(5)
	var batch=records[0].node;var snapshot=batch.points.duplicate();game.show_pause();await frames(20)
	check(batch.points==snapshot,"Pause freezes every coin in a large volley")
	game.resume();await frames(5);check(batch.points!=snapshot,"The same volley resumes moving after unpause")
	p.quick_attacks.stop_coins();await frames(150)
	check(get_tree().get_nodes_in_group("coin_volleys").is_empty(),"All large volleys expire after automatic fire stops")
	# Stress both longest lifetimes and fastest cast cadence at maximum growth.
	for boosted in [false,true]:
		await fresh_coins(99);p.buildings_broken=50;p.scale=Vector3.ONE*2;p.set_scarf_equipped(true)
		if boosted:
			for i in range(4):p.collect_powerup("attack_speed")
			for i in range(100):p.attack_chain.confirm(p.attack_chain.begin("pipe"))
		press_melee("weapon_coin");var peak_coins=0;var peak_controllers=0;var peak_nodes=0
		for i in range(240):
			await frames(1)
			var count=0;var controllers=0
			for shot in get_tree().get_nodes_in_group("projectiles"):
				if shot is GoldCoin and not shot.hostile:count+=shot.active_count if shot.is_in_group("coin_volleys") else 1;controllers+=1
			peak_coins=maxi(peak_coins,count);peak_controllers=maxi(peak_controllers,controllers);peak_nodes=maxi(peak_nodes,get_tree().get_nodes_in_group("coin_volleys").size())
		press_melee("weapon_coin")
		check(peak_coins<=1100 and peak_controllers<=24 and peak_nodes<=12,"Level-99 sustained fire stays bounded (boost=%s: %d coins, %d controllers, %d batches)" % [boosted,peak_coins,peak_controllers,peak_nodes])
		check(records.all(func(r):return not r.energy),"Sustained maximum-level fire never spawns red slash projectiles")
		if visual:await capture_coins_level("02-level-99-sustained-"+str(boosted))
	await fresh_coins(99);press_melee("weapon_coin");await frames(5);game.restart_area();await frames(20)
	check(p.progression.coin_count()==1 and not p.quick_attacks.coins_enabled and get_tree().get_nodes_in_group("coin_volleys").is_empty(),"Restart restores one coin and removes every old volley")
	print("COIN_SCALING_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
