extends "res://scripts/robe_coin_tests.gd"

func clean_orbs():
	await fresh_robe(false)
	game.orb_system.reset();game.orb_system.active=true;game.orb_system.magnet_clock=9999
	game.tuning.freeze_ai=true
	await wait(.05)

func orb_at(kind: String,offset: Vector3)->EnergyPickup:
	var orb=EnergyPickup.new();orb.game=game;orb.kind=kind
	orb.position=game.player.position+offset;game.add_child(orb);return orb

func screenshot_orbs(label: String):
	if not visual:return
	game.hud.toast_time=0;game.hud.banner_time=0
	game.camera_rig.set_process(false);game.camera_rig.camera.global_position=game.player.position+Vector3(8,11,15)
	game.camera_rig.camera.look_at(game.player.position+Vector3.UP)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/elemental-orbs/"+label+".png")

func run():
	visual="--elemental-orbs-visual" in OS.get_cmdline_user_args()
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var p=game.player;var system=game.orb_system
	await clean_orbs()
	check(EnergyPickup.DROP_KINDS==["attack_speed","ice","fire"] and EnergyPickup.COLORS.attack_speed==Color("ffe35c"),"Prototype drops are yellow speed, blue ice and red fire")
	var near=orb_at("ice",Vector3(6,0,0));var far=orb_at("fire",Vector3(12,0,0))
	await wait(.7)
	check(not is_instance_valid(near) and p.elemental_orbs.ice==1,"An orb six metres away flies into the player automatically")
	check(is_instance_valid(far) and not far.attracted and p.elemental_orbs.fire==0,"Orbs outside the eight-metre attraction radius remain on the floor")
	var yellow=orb_at("attack_speed",Vector3(0,0,-5));await wait(.7)
	check(not is_instance_valid(yellow) and p.attack_speed_multiplier()==1.5 and p.powerups.damage==0,"Yellow pickup increases attack speed, not damage")
	await clean_orbs();near=orb_at("ice",Vector3(7,0,0));await wait(.05)
	check(near.attracted,"Attraction latches during the drop animation, before a fast runner can leave")
	p.position+=Vector3(18,0,0);await wait(1)
	check(not is_instance_valid(near) and p.elemental_orbs.ice==1,"A latched orb follows the hero beyond the initial pickup radius")
	await clean_orbs();var all_counts={};var total=0
	for i in range(40):
		var before=get_tree().get_nodes_in_group("energy_pickups").size()
		game.drop_powerup(p.position+Vector3(0,0,-20))
		var amount=get_tree().get_nodes_in_group("energy_pickups").size()-before
		all_counts[amount]=true;total+=amount
	var valid=true
	for amount in all_counts:valid=valid and amount>=1 and amount<=5
	for orb in get_tree().get_nodes_in_group("energy_pickups"):valid=valid and orb.kind in EnergyPickup.DROP_KINDS
	check(valid and all_counts.size()==5,"Enemy drop routine produces every count from one through five, using only the new orb types")
	check(total>48 and get_tree().get_nodes_in_group("energy_pickups").size()==total,"Drop counts survive beyond the previous 48-orb cap")
	await clean_orbs();var enemy=target(Vector3(0,0,-4));enemy.training_dummy=false
	var outside=target(Vector3(0,0,-11));game.tuning.freeze_ai=false
	for i in range(4):p.collect_powerup("ice")
	check(p.elemental_orbs.ice==4 and system.pending.is_empty() and enemy.frozen_left==0,"Four ice orbs accumulate without triggering an attack")
	p.collect_powerup("ice");await wait(.05)
	check(p.elemental_orbs.ice==0 and system.ice_bursts==1 and enemy.frozen_left>1.8 and outside.frozen_left==0,"The fifth ice orb triggers a nearby freeze with a seven-metre limit")
	await screenshot_orbs("00-ice-burst")
	var at=enemy.position;var timer=enemy.frozen_left
	game.show_pause();await wait(.3)
	check(enemy.position.is_equal_approx(at) and enemy.frozen_left==timer,"Pause freezes the freeze duration and enemy position")
	game.resume();await wait(.85);enemy.take_hit(1,Vector3.RIGHT,true)
	await wait(.85)
	check(enemy.frozen_left>0 and enemy.position.is_equal_approx(at),"Ordinary hits and heavy knockback cannot shorten or move a frozen enemy")
	await screenshot_orbs("01-ice-freeze")
	await wait(.45)
	check(enemy.frozen_left==0 and not enemy.frozen_visual.visible,"Ice wears off after two gameplay seconds")
	await clean_orbs();enemy=target(Vector3(0,0,-4));outside=target(Vector3(0,0,-11))
	for i in range(5):p.collect_powerup("fire")
	await wait(.12);await screenshot_orbs("02-fire-explosion")
	check(system.fire_bursts==1 and enemy.hp==9900 and outside.hp==10000 and p.elemental_orbs.fire==0,"Five fire orbs explode for 100 damage nearby, excluding distant enemies")
	await clean_orbs();enemy=target(Vector3(0,0,-6))
	var wall=Geo.box(game,p.position+Vector3(0,1.5,-3),Vector3(8,4,.4),Geo.mat("777777"),true)
	await wait(.05)
	for kind in ["ice","fire"]:
		for i in range(5):p.collect_powerup(kind)
	await wait(.4)
	check(enemy.hp==10000 and enemy.frozen_left==0,"Solid cover blocks elemental damage and freezing")
	wall.queue_free()
	await clean_orbs()
	for i in range(12):p.collect_powerup("ice")
	for i in range(3):p.collect_powerup("fire")
	await wait(.35)
	check(system.ice_bursts==2 and p.elemental_orbs.ice==2 and p.elemental_orbs.fire==3,"Each group of five triggers once and keeps independent leftover elemental counts")
	await clean_orbs();var distant=[]
	for i in range(11):distant.append(orb_at("ice",Vector3(200+i*5,0,0)))
	for i in range(9):distant.append(orb_at("fire",Vector3(-180-i*5,0,0)))
	for orb in distant:orb.remaining=.12
	var magnet=preload("res://scripts/orb_magnet.gd").new();magnet.game=game;magnet.position=p.position;game.add_child(magnet)
	await wait(.05)
	var pulled=true
	for orb in distant:pulled=pulled and is_instance_valid(orb) and orb.magnetized
	check(pulled and not is_instance_valid(magnet),"Touching a magnet attracts every distant orb on both sides of the map")
	await wait(2.8)
	check(get_tree().get_nodes_in_group("energy_pickups").is_empty() and p.elemental_orbs.ice==1 and p.elemental_orbs.fire==4,"Magnet flight preserves expiring orbs and absorbs all twenty exactly once")
	check(system.ice_bursts==2 and system.fire_bursts==1,"Mass collection retains every complete elemental set")
	await clean_orbs();game.pursuit.refresh_field(p.position)
	var spawned=system.spawn_magnet()
	check(spawned and get_tree().get_nodes_in_group("orb_magnets").size()==1,"A random magnet spawns on valid reachable ground")
	var magnets=get_tree().get_nodes_in_group("orb_magnets")
	check(magnets[0].position.distance_to(p.position)>=12,"Map magnets require exploration instead of spawning on top of the hero")
	for i in range(5):system.spawn_magnet()
	check(get_tree().get_nodes_in_group("orb_magnets").size()==3,"At most three map magnets remain active")
	var s=game.encounters;s.begin();s.enabled=false
	var bins={};var safe=true;var samples=0
	for i in range(96):
		s.total_spawned=i;var point=s.wave_spawn_point()
		if point==null:continue
		var offset=point-p.position;bins[posmod(floori(atan2(offset.z,offset.x)/TAU*8),8)]=true
		safe=safe and Vector2(offset.x,offset.z).length()>=21.9;samples+=1
	check(samples==96 and safe and bins.size()>=5,"Coastal spawns cover all available land sides without spawning in the sea (%s sectors)" % bins.size())
	game.reset_player_at(Vector3(-195,game.world.height_at(-195,-155)+.12,-155));await wait(.05)
	game.pursuit.refresh_field(p.position);bins.clear();samples=0
	for i in range(96):
		s.total_spawned=i;var point=s.wave_spawn_point()
		if point==null:continue
		var offset=point-p.position;bins[posmod(floori(atan2(offset.z,offset.x)/TAU*8),8)]=true;samples+=1
	check(samples==96 and bins.size()>=7,"Open-ground waves surround the hero across at least seven of eight directions (%s sectors)" % bins.size())
	var approaches={}
	for i in range(16):
		var direction=game.pursuit.direction(p.position+Vector3(0,0,20),i)
		approaches[roundi(direction.x*100)]=true
	check(approaches.size()>=6,"Swarm approach lanes vary instead of sharing one straight pursuit line (%s lanes)" % approaches.size())
	await clean_orbs();orb_at("ice",Vector3(-3,0,-3));orb_at("fire",Vector3(0,0,-3));orb_at("attack_speed",Vector3(3,0,-3))
	var display=preload("res://scripts/orb_magnet.gd").new();display.game=game;display.position=p.position+Vector3(5,0,-4);game.add_child(display)
	p.elemental_orbs.ice=3;p.elemental_orbs.fire=2
	await screenshot_orbs("03-orbs-and-magnet")
	game.restart_area();game.encounters.enabled=false;await wait(.1)
	check(p.elemental_orbs.ice==0 and p.elemental_orbs.fire==0 and system.pending.is_empty() and get_tree().get_nodes_in_group("energy_pickups").is_empty() and get_tree().get_nodes_in_group("orb_magnets").is_empty(),"Restart clears orb counts, pending bursts, old drops and magnets")
	system.burst("fire");system.burst("ice")
	game.show_main_menu();await wait(.05)
	check(get_tree().get_nodes_in_group("elemental_vfx").is_empty(),"Returning to the menu clears both ice and fire burst visuals")
	print("ELEMENTAL_ORBS_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
