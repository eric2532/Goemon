extends "res://scripts/combat_tests.gd"
# Runtime contract for the opt-in battle view. Every attack uses the real input
# path, collision bodies, hit attribution, and existing character abilities.
var visual=false
var launches: Array[Dictionary]=[]
var impacts: Array=[]

func frames(count: int):
	for i in range(count):await get_tree().physics_frame

func press(action: String,down: bool=true):
	var event=InputEventAction.new();event.action=action;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()

func tap(action: String):
	press(action);press(action,false)

func capture(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0;game.player.invuln=0;game.player.model.show()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/rogue-battle/"+label+".png")

func observe_projectile(node: Node):
	if node is GoldCoin and not node.hostile:
		launches.append({"direction":node.velocity.normalized(),"damage":node.damage,"fireball":node is MusashiFireball})

func observe_impact(victim,_strength,_duration):
	impacts.append(victim)

func aim_world(point: Vector3):
	var screen=game.camera_rig.camera.unproject_position(point)
	var motion=InputEventMouseMotion.new();motion.position=screen;motion.global_position=screen
	Input.parse_input_event(motion);Input.flush_buffered_events()
	game.rogue_view.aim_at(screen);game.rogue_view.update_aim()

func fixture(offset: Vector3)->Ninja:
	var enemy=dummy(offset);enemy.hp=10000;enemy.max_hp=10000
	enemy.set_physics_process(false)
	return enemy

func clean():
	press("light_attack",false);press("heavy_attack",false)
	if game.paused:game.resume()
	var p=game.player
	p.smoke_move=Vector2.ZERO;p.select_character(1);p.set_scarf_equipped(false)
	p.cancel_charge();p.end_surge();p.clear_powerups()
	p.run_upgrades={"damage":0,"vitality":0,"tempo":0}
	p.buildings_broken=0;p.scale=Vector3.ONE
	for enemy in game.enemies:
		if is_instance_valid(enemy):enemy.queue_free()
	game.enemies.clear()
	for effect in get_tree().get_nodes_in_group("projectiles"):effect.queue_free()
	game.reset_player_at(game.world.sky_islands.islands[0]+Vector3(0,.06,0))
	p.facing=Vector3.FORWARD;p.soft_target=true;p.select_weapon(1)
	p.invuln=0;p.hp=p.max_hp
	game.rogue_feedback.clear();game.rogue_view.reset()
	await frames(8)
	aim_world(p.position+Vector3(7,0,0))
	launches.clear();impacts.clear()

func drain(limit: int=180)->int:
	var count=0
	while (game.player.attack_left>0 or game.player.quick_attacks.active or not game.player.quick_attacks.pending.is_empty()) and count<limit:
		await frames(1);count+=1
	return count

func mode_and_camera_rules():
	var rogue_button: Button
	for child in game.menu.find_children("*","Button",true,false):
		if "ROGUE" in child.text.to_upper():rogue_button=child;break
	check(is_instance_valid(rogue_button),"Main menu exposes a separate Rogue Battle mode")
	await capture("01-mode-selection")
	if is_instance_valid(rogue_button):rogue_button.pressed.emit()
	else:game.start_mode("rogue")
	await frames(12)
	var camera=game.camera_rig.camera;var sky=game.world.sky_islands
	check(game.playing and game.rogue_battle_mode and game.descent_mode and not game.tower_defense_mode,"Menu selection starts the optional battle mode on Sky Descent")
	check(sky.islands.size()==784 and sky.clouds.size()>150 and game.encounters.current_island==0,"Rogue Battle retains the existing island world and encounter director")
	check(game.player.progression.level==1 and game.player.max_hp==100 and Hero.ROSTER.size()==2,"Starting roster, progression, and health remain unchanged")
	check(game.rogue_view.enabled and game.rogue_feedback.enabled and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Battle mode enables its view and feedback with a visible cursor")
	var down=-camera.global_basis.z.y
	check(camera.projection==Camera3D.PROJECTION_ORTHOGONAL and down<-.35 and down>-.95 and camera.size>=18,"Battle camera uses a wide elevated orthographic projection")
	var direction=-camera.global_basis.z
	var motion=InputEventMouseMotion.new();motion.position=get_viewport().get_visible_rect().size*.6;motion.relative=Vector2(450,-300)
	Input.parse_input_event(motion);Input.flush_buffered_events();await frames(3)
	check(direction.dot(-camera.global_basis.z)>.999,"Moving the visible cursor does not orbit the battle camera")
	await capture("02-battle-overview")
	game.encounters.enabled=false
	await clean()
	var p=game.player;var aim=p.position+Vector3(7,0,0)
	aim_world(aim)
	check(game.rogue_view.aim_direction().dot(Vector3.RIGHT)>.97,"Projected cursor position determines the ground attack direction")
	check(Vector2(game.rogue_view.aim.x-aim.x,game.rogue_view.aim.z-aim.z).length()<.3 and game.rogue_view.reticle.visible and game.rogue_view.heading.visible,"Visible ground marker matches the cursor ray and shows attack heading")
	await capture("03-ground-cursor")
	var original=p.position
	p.smoke_move=Vector2(0,-1);await frames(20);p.smoke_move=Vector2.ZERO
	var travel=p.position-original;travel.y=0
	var expected=Vector3.FORWARD.rotated(Vector3.UP,game.camera_rig.yaw)
	check(travel.length()>1 and travel.normalized().dot(expected)>.97,"Movement retains the existing camera-relative controller while aiming independently")
	await clean()
	var floor_height=p.position.y
	tap("jump");await frames(10)
	check(p.position.y>floor_height+.7 and p.jumps_used==1,"Normal jump still launches from the island in battle view")
	tap("jump");await frames(6)
	check(p.jumps_used==2 and p.velocity.y>0,"Normal second jump remains available")

func attack_rules():
	await clean()
	var p=game.player
	var intended=fixture(Vector3(2.4,0,0));var distraction=fixture(Vector3(-1.1,0,-.2))
	aim_world(p.position+Vector3(7,0,0));tap("heavy_attack")
	check(p.attack_left>0 and not p.hit_done and intended.hp==10000,"A heavy input starts windup without applying damage early")
	check(p.facing.dot(Vector3.RIGHT)>.97,"Cursor direction overrides soft targeting toward a nearer enemy")
	await frames(9)
	check(intended.hp==10000 and impacts.is_empty(),"The early windup has no hit event or impact animation")
	for i in range(80):
		if intended.hp<10000:break
		await frames(1)
	check(is_equal_approx(intended.hp,9952) and distraction.hp==10000,"Heavy contact keeps its original 48 damage and excludes the opposite side")
	check(impacts.size()==1 and intended.recoil_strength>=.48 and game.rogue_feedback.active_count>0,"A confirmed hit triggers one recoil and a visible Rogue impact animation")
	await capture("04-heavy-contact")
	await drain();await frames(18)
	check(intended.hp==9952 and impacts.size()==1,"Remaining contact frames never damage the same target twice")
	check(game.rogue_feedback.active_count==0,"Short impact animations return to their bounded pool after fading")
	await clean();intended=fixture(Vector3(2.4,0,0))
	aim_world(p.position+Vector3(7,0,0));tap("light_attack")
	await drain();await frames(8)
	check(intended.hp==9978 and impacts.size()==1,"A single light click produces one deliberate 22-damage strike")
	await clean();tap("light_attack")
	for i in range(50):
		if p.attack_left<=.10:break
		await frames(1)
	tap("light_attack");await frames(10)
	check(p.combo==2 and p.attack_left>0,"A late light tap is buffered into the next alternating combo stage")
	await drain()
	await clean();tap("light_attack");await frames(3);tap("light_attack")
	await frames(55)
	check(p.combo==1 and p.attack_left==0,"An early released tap expires instead of causing a delayed phantom attack")
	await clean();tap("light_attack")
	for i in range(50):
		if p.attack_left<=.10:break
		await frames(1)
	tap("heavy_attack");await frames(10)
	check(p.attack_heavy and p.attack_left>0,"A late secondary tap transitions from recovery into a heavy strike")
	await drain()
	await clean();intended=fixture(Vector3(2.4,0,0))
	aim_world(p.position+Vector3(7,0,0));press("light_attack")
	await frames(100);press("light_attack",false);await drain()
	check(impacts.size()>1 and impacts.size()<15,"Holding primary repeats a bounded sequence of real attacks")
	var after_release=impacts.size();await frames(45)
	check(impacts.size()==after_release and p.attack_left==0,"Releasing primary stops further attacks after the current sequence")
	await clean();intended=fixture(Vector3(2.4,0,0));p.collect_powerup("damage")
	aim_world(p.position+Vector3(7,0,0));tap("heavy_attack");await drain()
	check(is_equal_approx(intended.hp,9928),"Existing damage pickups still multiply a heavy strike to 72 damage")
	await clean();p.collect_powerup("attack_speed");intended=fixture(Vector3(2.4,0,0))
	aim_world(p.position+Vector3(7,0,0));tap("heavy_attack")
	check(p.attack_left>0 and not p.hit_done,"Attack speed upgrades retain a real windup")
	await drain();check(intended.hp==9952 and impacts.size()==1,"Attack speed changes timing without duplicating contact damage")
	await clean();aim_world(p.position+Vector3(7,0,0));tap("heavy_attack");await frames(4);tap("dodge")
	check(p.dodge_time>0 and p.attack_left==0,"Evade can cancel a winding-up attack")
	var resumed_after_utility=[]
	for utility in ["dodge","equip"]:
		await clean();press("light_attack");await frames(3);tap(utility)
		var resumed=false
		for i in range(50):
			await frames(1)
			if p.dodge_time<=0 and not p.forward_dash.active and p.attack_left>0:
				resumed=true;break
		resumed_after_utility.append(resumed)
		press("light_attack",false);await drain()
	check(resumed_after_utility==[true,true],"Holding primary resumes attacks after both evade and the forward dash")

func projectile_and_character_rules():
	await clean()
	var p=game.player;var model=p.model
	aim_world(p.position+Vector3(7,0,0));tap("weapon_coin");tap("weapon_coin")
	check(launches.size()==1 and launches[0].direction.dot(Vector3.RIGHT)>.97 and launches[0].damage==20,"Goemon coins use the cursor while retaining their normal 20 damage")
	await clean();p.buildings_broken=50;p.scale=Vector3.ONE*p.growth_multiplier()
	game.rogue_view.reset();await frames(6)
	var normal_target=fixture(Vector3(8,0,0));p.select_weapon(2)
	aim_world(normal_target.position);tap("light_attack")
	for i in range(70):
		if not launches.is_empty():break
		aim_world(normal_target.position);await frames(1)
	await frames(40)
	check(launches.size()==1 and launches[0].direction.y<-.1 and normal_target.hp==9980,"A fully grown hero aims a manual coin downward and hits a normal enemy at the cursor")
	await clean();p.collect_powerup("damage");var multiplier=p.damage_multiplier()
	tap("character_toggle");await frames(2)
	check(p.character_id==2 and p.model==p.character_models[2] and p.damage_multiplier()==multiplier,"Character switching keeps Edo and existing upgrade rules")
	aim_world(p.position+Vector3(7,0,0));tap("heavy_attack")
	for i in range(70):
		if not launches.is_empty():break
		await frames(1)
	check(launches.size()==1 and launches[0].fireball and launches[0].direction.dot(Vector3.RIGHT)>.97,"Edo's giant fireball follows the same cursor direction")
	await capture("05-edo-cursor-cast")
	p.cancel_charge();tap("character_toggle");await frames(2)
	check(p.character_id==1 and p.model==model,"Switching back restores the original Goemon model")

func world_view_rules():
	await clean()
	var p=game.player
	# Sample the same ground and a real furnished interior with the battle rig.
	game.reset_player_at(game.world.sky_islands.ground_point+Vector3.UP*.15)
	await frames(20)
	aim_world(p.position+Vector3(4,0,-3))
	var camera=game.camera_rig.camera
	check(camera.projection==Camera3D.PROJECTION_ORTHOGONAL and not camera.is_position_behind(p.position+Vector3.UP),"Ground arrival retains battle framing and a visible hero")
	await capture("06-tidefall-ground")
	var room=game.world.furnished_town.rooms[0]
	game.reset_player_at(room.root.to_global(Vector3(0,.42,1.7)))
	await frames(30)
	check(game.world.furnished_town.indoor and not room.meshes.Roof.visible and not camera.is_position_behind(p.position+Vector3.UP),"Battle view retains furnished interior cutaways and keeps the hero in front of the camera")
	aim_world(p.position+Vector3(2,0,1))
	await capture("07-furnished-interior")
	await clean()
	p.set_gold_cloak(true);p.set_physics_process(false)
	var visible_hero=true
	for i in range(90):
		p.position+=Vector3(64,32,0)/60.0;p.velocity=Vector3(64,32,0)
		game.rogue_view.update_camera(1.0/60.0)
		var screen=camera.unproject_position(p.position+Vector3.UP)
		visible_hero=visible_hero and get_viewport().get_visible_rect().grow(-20).has_point(screen)
	check(visible_hero,"Fast horizontal flight and ascent stay inside the battle camera frame")
	await capture("08-flight-framing")
	p.velocity=Vector3.ZERO;p.set_physics_process(true);p.set_scarf_equipped(false)

func lifecycle_rules():
	await clean()
	var p=game.player;var victim=fixture(Vector3(2.4,0,0))
	aim_world(p.position+Vector3(7,0,0));tap("heavy_attack")
	for i in range(80):
		if game.rogue_feedback.active_count>0:break
		await frames(1)
	game.show_pause()
	var camera_transform=game.camera_rig.camera.global_transform
	var ages=[]
	for slot in game.rogue_feedback.slots:ages.append(slot.age)
	await frames(12)
	var frozen=true
	for i in range(ages.size()):frozen=frozen and game.rogue_feedback.slots[i].age==ages[i]
	check(game.paused and frozen and game.camera_rig.camera.global_transform==camera_transform,"Pause freezes the battle camera and active hit animations")
	check(not game.rogue_view.reticle.visible and not game.rogue_view.heading.visible,"Pause hides the ground cursor and attack-direction marker")
	game.resume();await frames(2)
	check(not game.paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and game.rogue_view.enabled and game.rogue_view.reticle.visible,"Resume restores battle control and its visible ground cursor")
	var layout=game.world.sky_islands.islands.duplicate();var seed=game.run_seed
	game.restart_area();await frames(10);game.encounters.enabled=false
	check(game.rogue_battle_mode and game.run_seed==seed and game.world.sky_islands.islands==layout,"Restart retains Rogue Battle and the exact seeded island layout")
	check(game.rogue_feedback.active_count==0 and p.attack_chain.count==0 and p.attack_left==0,"Restart clears feedback, queued attacks, and hit-chain state")
	game.show_main_menu();await frames(2)
	check(not game.playing and not game.rogue_view.enabled and not game.rogue_feedback.enabled and not game.rogue_view.reticle.visible and not game.rogue_view.heading.visible,"Main menu disables battle-only cursor and feedback")
	check(game.camera_rig.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Main menu restores its original perspective framing")
	game.start_mode("descent");await frames(10)
	check(not game.rogue_battle_mode and game.descent_mode and game.camera_rig.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Normal Sky Descent keeps the original third-person camera")
	check(not game.rogue_view.enabled and not game.rogue_feedback.enabled,"Normal Sky Descent excludes all battle-only overlays")
	# The headless display server cannot capture a mouse; verify capture in the rendered suite.
	if DisplayServer.get_name()!="headless":check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Normal Sky Descent restores captured mouse control")
	game.encounters.enabled=false
	p.smoke_move=Vector2.ZERO;p.cancel_charge();p.clear_powerups()
	for enemy in game.enemies:
		if is_instance_valid(enemy):enemy.queue_free()
	game.enemies.clear()
	game.reset_player_at(game.world.sky_islands.islands[0]+Vector3(0,.06,0));p.soft_target=false
	game.camera_rig.yaw=0;await frames(5)
	victim=fixture(Vector3(0,0,-2.4));tap("light_attack");await drain();await frames(5)
	check(is_equal_approx(victim.hp,9867.6),"Original mode retains the complete automatic triplet and its existing combo bonuses")

func run():
	visual="--rogue-battle-visual" in OS.get_cmdline_user_args()
	if visual:DirAccess.make_dir_recursive_absolute("res://tests/rogue-battle")
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.player.smoke_mode=true
	game.child_entered_tree.connect(observe_projectile);game.impact_confirmed.connect(observe_impact)
	await mode_and_camera_rules()
	await attack_rules()
	await projectile_and_character_rules()
	await world_view_rules()
	await lifecycle_rules()
	print("ROGUE_BATTLE_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
