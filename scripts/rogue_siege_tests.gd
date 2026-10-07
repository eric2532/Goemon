extends "res://scripts/combat_tests.gd"
# Real menu/mode, Hero input, native Rogue state and actual Ninja collision.
# The existing Fire Siege director is only paused while owned combat fixtures run.
const CLASS_IDS=["pirate","samurai","ninja","mage","knight","dragoon","magic-swordsman","ranger","explorer","master-thief"]
const PRIMARY_DAMAGE=[25,34,18,64,42,37,42,67,19,62]
const PRIMARY_STYLE=["sword","katana","ninja","staff","heavy","thrust","claymore","bow","twin","pipe"]
const TEST_ORIGIN=Vector3(0,.06,100)
var visual=false
var checks=0
var output_dir="res://tests/rogue-siege"
var native_projectiles: Dictionary={}
var class_results: Array=[]
var goemon_impacts: Array=[]

func check(ok: bool,message: String):
	checks+=1
	super.check(ok,message)

func frames(count: int):
	for i in range(count):await get_tree().physics_frame

func press(action: String,down: bool=true):
	var event=InputEventAction.new();event.action=action;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events()
	record_projectiles()

func tap(action: String):
	press(action);press(action,false)

func record_projectiles():
	if not is_instance_valid(game) or not game.player.is_rogue_character():return
	var ability=game.player.active_ability
	if not is_instance_valid(ability):return
	for projectile in ability.projectiles:
		if is_instance_valid(projectile.get("mesh")):
			native_projectiles[projectile.mesh.get_instance_id()]={"kind":projectile.get("kind",""),"damage":projectile.get("damage",0),"pierce":projectile.get("pierce",false)}

func _physics_process(_delta):record_projectiles()

func observe_impact(victim,_strength,duration):
	if game.player.uses_rogue_pipe_profile():goemon_impacts.append({"victim":victim,"duration":duration})

func capture(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0;game.player.invuln=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_dir.path_join(label+".png"))

func aim_world(point: Vector3):
	var screen=game.camera_rig.camera.unproject_position(point)
	var motion=InputEventMouseMotion.new();motion.position=screen;motion.global_position=screen
	Input.parse_input_event(motion);Input.flush_buffered_events()
	game.rogue_view.aim_at(screen);game.rogue_view.update_aim()

func clear_enemies():
	for enemy in game.enemies:
		if is_instance_valid(enemy):enemy.queue_free()
	game.enemies.clear()
	await frames(2)

func fixture(offset: Vector3)->Ninja:
	var enemy=dummy(offset);enemy.hp=10000;enemy.max_hp=10000
	enemy.set_physics_process(false)
	return enemy

func fresh_class(index: int):
	press("light_attack",false);press("heavy_attack",false)
	if game.paused:game.resume()
	var p=game.player
	p.smoke_move=Vector2.ZERO;p.cancel_charge();p.clear_powerups()
	p.buildings_broken=0;p.scale=Vector3.ONE
	p.run_upgrades={"damage":0,"vitality":0,"tempo":0}
	p.select_character(index+3);p.active_ability.reset_run()
	await clear_enemies()
	game.reset_player_at(TEST_ORIGIN);p.hp=p.max_hp;p.invuln=0
	game.rogue_view.reset();game.rogue_feedback.clear()
	await frames(6)
	aim_world(p.position+Vector3(8,0,0));await frames(12);native_projectiles.clear()

func fresh_goemon():
	press("light_attack",false);press("heavy_attack",false)
	if game.paused:game.resume()
	# The owned-enemy bounty fixture produces real loot. Prevent its delayed
	# attraction from granting a speed upgrade after this timing fixture resets.
	for pickup in get_tree().get_nodes_in_group("energy_pickups"):
		pickup.set_physics_process(false);pickup.queue_free()
	var p=game.player
	p.smoke_move=Vector2.ZERO;p.cancel_charge();p.clear_powerups()
	if p.surge_left>0:p.end_surge()
	p.buildings_broken=0;p.scale=Vector3.ONE
	p.run_upgrades={"damage":0,"vitality":0,"tempo":0}
	p.select_character(1);p.weapon_slot=1;p.model.equipped=true
	p.attack_heavy=false;p.attack_charged=false;p.combo=0;p.combo_window=0
	await clear_enemies()
	game.reset_player_at(TEST_ORIGIN);p.hp=p.max_hp;p.invuln=0
	game.rogue_view.reset();game.rogue_feedback.clear()
	await frames(6)
	aim_world(p.position+Vector3(8,0,0));await frames(12)

func settle_goemon(limit: int=120):
	for i in range(limit):
		var p=game.player
		if p.attack_left<=0 and p.impact_pause<=0 and p.rogue_controls.primary_buffer<=0 and p.rogue_controls.secondary_buffer<=0:
			await frames(2);return
		await frames(1)
	check(false,"Goemon's current attack and released input buffers finish within their bounded lifetime")

func settle_attack(limit: int=180):
	for i in range(limit):
		var a=game.player.active_ability;var p=a.player
		if p.attack==null and p.travel==null and p.roll<=0 and p.burst==null and a.projectiles.is_empty() and a.attack_buffer<=0 and p.secondaryBuffer==null:
			await frames(2);return
		await frames(1)
	check(false,"Native action and its projectiles complete within their bounded lifetime")

func pose_snapshot(actor)->Array:
	var result=[]
	for name_ in ["Body","Arm_R","Arm_L","Weapon_Cutlass","Weapon_Pistol"]:
		if actor.joints.has(name_):result.append(actor.joints[name_].node.transform)
	return result

func model_geometry_hash(model: Node3D)->String:
	# Exported GLBs are remapped to imported scenes. Hash the geometry actually
	# loaded by both builds, without class names or paths making it appear unique.
	var digest=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
	var surfaces=0
	for instance in model.find_children("*","MeshInstance3D",true,false):
		if instance.mesh==null:continue
		for surface in range(instance.mesh.get_surface_count()):
			var arrays=instance.mesh.surface_get_arrays(surface)
			if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX]==null or arrays[Mesh.ARRAY_VERTEX].is_empty():continue
			digest.update(var_to_bytes([instance.mesh.surface_get_primitive_type(surface),arrays]))
			surfaces+=1
	var result=digest.finish().hex_encode()
	return result if surfaces>0 else ""

func pause_fixture_director():
	game.encounters.set_physics_process(false)
	game.kennel.set_physics_process(false);game.barracks.set_physics_process(false)
	for tower in game.encounters.cannons:tower.set_physics_process(false)

func button_with_prefix(prefix: String)->Button:
	for button in game.menu.find_children("*","Button",true,false):
		if button.text.begins_with(prefix):return button
	return null

func pregame_rules():
	game.defense_beta=true;game.defense_tactics=true;game.defense_hard=false
	await capture("00-main-menu")
	var entry=game.menu.find_child("RogueSiegeButton",true,false)
	check(entry!=null,"Main menu exposes a separate Rogue Siege launch button")
	entry.pressed.emit();await frames(2)
	check(button_with_prefix("BETA")!=null and button_with_prefix("HARD")!=null,"Rogue Siege offers both existing defense difficulties")
	await capture("01-difficulty-choice")
	button_with_prefix("BETA").pressed.emit();await frames(2)
	check(game.rogue_pick_start and game.menu.find_children("RogueFighter_*","Button",true,false).size()==11 and game.menu.find_child("RogueFighter_goemon",true,false)!=null,"Starting a siege offers Goemon alongside all ten native Rogue fighters")
	await capture("02-starting-fighter-picker")
	game.menu.find_child("RogueFighter_goemon",true,false).pressed.emit()
	pause_fixture_director();await frames(3)

func mode_rules():
	pause_fixture_director();await frames(3)
	var s=game.encounters
	check(game.rogue_roster_mode and game.rogue_battle_mode and game.tower_defense_mode and not game.descent_mode,"Rogue Siege combines the battle camera with the real tower-defense mode")
	check(s is TowerDefense and s.MAX_WAVES==10 and s.BETA_ENEMIES==600 and s.beta_mode and s.tactics_enabled,"The existing ten-wave, 600-enemy Fire Siege director remains in charge")
	check(game.world.playable_bounds==Rect2(-80,-400,160,760) and game.world.cannon_sites.size()==24 and s.tower_count("fire")==12 and s.tower_count("cannon")==12,"Original battlefield, 24 mounts, twelve fire towers and twelve cannons are preserved")
	check(s.money==12000 and s.base_hp==100 and s.phase=="draft" and game.paused,"Original gold, shrine health, and mandatory opening draft are preserved")
	check(s.card_offer==["ice_shells","hot_flames","supply_cache"] and game.menu.find_children("DefenseCard_*","Button",true,false).size()==3,"The same three opening upgrade cards are available")
	check(game.player.character_id==1 and game.player.model==game.player.character_models[1],"Selecting Goemon before launch preserves his original model in the opening draft")
	check(game.camera_rig.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and game.rogue_view.enabled,"Rogue Siege uses the elevated battle camera")
	await capture("03-opening-draft")
	check(s.choose_card("supply_cache") and s.money==13000 and s.chosen_wave==1 and not game.paused,"The real card-choice path still grants its gold and starts preparation")
	await goemon_first_selection_rules()
	await clear_enemies()
	game.show_rogue_roster();await frames(2)
	var found=0
	for id in CLASS_IDS:
		if game.menu.find_child("RogueFighter_"+id,true,false)!=null:found+=1
	check(game.paused and found==10 and game.menu.find_child("RogueFighter_goemon",true,false)!=null and game.menu.find_children("RogueFighter_*","Button",true,false).size()==11,"The paused fighter picker includes Goemon and all ten native Rogue classes")
	await capture("04-in-game-fighter-picker")
	game.menu.find_child("RogueFighter_pirate",true,false).pressed.emit();await frames(2)
	check(not game.paused and game.player.character_id==3,"Choosing a playable class returns to the ongoing defense run")
	check(game.player.active_ability.fx==game.player.rogue_pipe_combo.fx and game.player.active_ability.sound==game.player.rogue_pipe_combo.sound and game.find_children("RogueSharedClassEffects","",true,false).size()==1 and game.find_children("RogueSharedClassAudio","",true,false).size()==1,"Goemon-first selection and native switching reuse one shared Rogue effects and audio owner")
	check(game.kennel.summon("kogane") and game.barracks.summon("sen") and game.kennel.living_count()==1 and game.barracks.living_count()==1,"Original dogs and humanoid summons remain independent usable companion systems")
	check(game.kennel.dogs[0]!=game.player and game.barracks.heroes[0]!=game.player,"Controllable Rogue heroes remain separate from purchased companion actors")
	game.kennel.reset();game.barracks.reset();game.kennel.begin();game.barracks.begin()
	pause_fixture_director()
	# A class attack resolves a director-owned enemy through the real bounty path.
	s.tick(s.prep_left+.01);await frames(2)
	check(s.wave==1 and s.total_scheduled==600 and s.pending>0 and game.active_enemy_count()>0,"The unchanged first wave schedules real tower-defense attackers")
	var victim=game.enemies[0];victim.set_physics_process(false)
	game.reset_player_at(TEST_ORIGIN);game.rogue_view.reset();await frames(3)
	victim.position=game.player.position+Vector3(2.2,0,0);victim.hp=1
	var money=s.money;var kills=s.wave_kills
	aim_world(victim.position);tap("light_attack");await frames(25)
	check(victim.dead and s.wave_kills==kills+1 and s.money==money+12,"A native Rogue attack earns exactly the existing enemy bounty and wave kill")

func goemon_first_selection_rules():
	await fresh_goemon()
	var p=game.player;var original_model=p.model
	var target=fixture(Vector3(2.4,0,0));aim_world(target.position)
	goemon_impacts.clear();tap("light_attack")
	check(p.uses_rogue_pipe_profile() and is_equal_approx(p.attack_duration,.48) and p.model==original_model and not p.is_rogue_character(),"Goemon's first siege input uses the new pipe rhythm with his original model and kit")
	for i in range(30):
		if target.hp<10000:break
		await frames(1)
	var fx=p.rogue_pipe_combo.fx
	check(target.hp==9978 and goemon_impacts.size()==1 and is_instance_valid(fx) and fx.items.any(func(effect):return effect.kind=="slash" and effect.node.name=="AttackSlash_magic"),"Goemon can create the native Rogue slash and one real 22-damage contact before any native fighter is selected")
	await capture("05-goemon-first-contact")
	await settle_goemon()

func goemon_combo_rules():
	await fresh_goemon()
	var p=game.player;var original_model=p.model
	var previous_volume=game.settings.volume;game.settings.volume=.5
	var target=fixture(Vector3(2.4,0,0));var rear=fixture(Vector3(-2.4,0,0))
	for stage in range(1,4):
		p.attack_chain.reset();target.hp=10000;target.position=p.position+Vector3(2.4,0,0);rear.position=p.position+Vector3(-2.4,0,0)
		aim_world(target.position);goemon_impacts.clear();tap("light_attack")
		var tempo=p.attack_speed_multiplier()
		check(p.combo==stage and is_equal_approx(p.attack_duration,[.48,.48,.576][stage-1]) and is_equal_approx(p.combo_window,1.05) and is_equal_approx(tempo,1),"Goemon tap %d starts its intended duration and combo window at base speed (speed=%.3f)" % [stage,tempo])
		await frames(6)
		check(target.hp==10000 and p.model.rogue_pipe_combo_active and p.model==original_model,"Goemon stage %d retains a visible windup without early contact or replacing his rig (speed=%.3f)" % [stage,p.attack_speed_multiplier()])
		for i in range(35):
			if target.hp<10000:break
			await frames(1)
		var elapsed=p.attack_duration-p.attack_left
		check(target.hp==10000-[22,22,30][stage-1] and rear.hp==10000 and elapsed>=.145 and elapsed<=.185 and goemon_impacts.size()==1,"Goemon stage %d contacts near 0.15 seconds once, in the cursor direction, with unchanged base damage (clock=%.3f, speed=%.3f)" % [stage,elapsed,p.attack_speed_multiplier()])
		if stage==3:await capture("06-goemon-third-contact")
		await settle_goemon();await frames(3)
		check(target.hp==10000-[22,22,30][stage-1] and goemon_impacts.size()==1 and p.attack_left==0,"Goemon stage %d finishes without an automatic extra strike" % stage)
	check(p.rogue_pipe_combo.sound.cache.has("blade-magic-swordsman-0") and p.rogue_pipe_combo.sound.cache.has("blade-magic-swordsman-1") and p.rogue_pipe_combo.sound.cache.has("blade-magic-swordsman-2"),"All three Goemon stages play the corresponding native Magic Swordsman blade sounds")
	game.settings.volume=previous_volume
	await frames(70);tap("light_attack")
	check(p.combo==1,"Goemon restarts at stage one after the combo window expires")
	await settle_goemon()
	await fresh_goemon();tap("light_attack")
	for i in range(50):
		if p.attack_left<=.10:break
		await frames(1)
	tap("light_attack");await frames(12)
	check(p.combo==2 and p.attack_left>0,"A late Goemon tap survives recovery in the 170-millisecond primary buffer")
	await settle_goemon()
	await fresh_goemon();tap("light_attack");await frames(3);tap("light_attack");await frames(45)
	check(p.combo==1 and p.attack_left==0,"An early released Goemon tap expires without a delayed phantom swing")
	await fresh_goemon();press("light_attack")
	var stages=[p.combo];var durations=[p.attack_duration]
	for i in range(130):
		await frames(1)
		if p.attack_left>0 and p.combo!=stages[-1]:
			stages.append(p.combo);durations.append(p.attack_duration)
			if stages.size()==4:break
	press("light_attack",false);await settle_goemon();await frames(35)
	check(stages==[1,2,3,1] and is_equal_approx(durations[0],.48) and is_equal_approx(durations[2],.576) and p.attack_left==0 and not p.rogue_controls.held,"Holding Goemon primary follows the three-stage cadence and releasing stops after the current swing")
	await fresh_goemon();tap("heavy_attack")
	check(not p.uses_rogue_pipe_profile() and is_equal_approx(p.attack_duration,.74),"Goemon's heavy attack retains its existing timing outside the plain-pipe profile")
	await settle_goemon()

func siege_camera_rules():
	await fresh_class(0)
	var p=game.player;var view=game.rogue_view;var camera=game.camera_rig.camera
	var forward=Vector3.FORWARD.rotated(Vector3.UP,game.camera_rig.yaw)
	var idle_screen=camera.unproject_position(p.position+Vector3.UP)
	var angle=-camera.global_basis.z
	check(view.movement_lead.length()<.01 and p.model.actor.scale.is_equal_approx(Vector3.ONE*1.15) and p.scale==Vector3.ONE,"Native fighters are visually 15 percent larger while the idle camera and physical Hero scale remain stable")
	await capture("07-siege-camera-idle")
	p.smoke_move=Vector2(0,-1);await frames(65)
	var walking_screen=camera.unproject_position(p.position+Vector3.UP)
	check(view.movement_lead.dot(forward)>3.3 and (view.focus-p.position).dot(forward)>.6 and walking_screen.y>idle_screen.y+8 and angle.dot(-camera.global_basis.z)>.999,"Walking screen-forward smoothly places the battle view ahead without changing its angle")
	await capture("08-siege-camera-forward")
	p.smoke_move=Vector2.ZERO;await frames(72)
	check(view.movement_lead.length()<.03,"Releasing movement eases the camera lead back to its idle framing")
	await fresh_goemon();tap("light_attack");await frames(12)
	check(view.movement_lead.length()<.01,"A cursor-directed Goemon lunge does not create walking camera lead")
	await settle_goemon()

func goemon_lifecycle_rules():
	await fresh_class(0)
	var p=game.player;var pirate=p.active_ability
	p.hp=p.max_hp*.5;tap("surge");var cooldown=pirate.player.cooldowns.drink
	game.show_rogue_roster();await frames(2)
	game.menu.find_child("RogueFighter_goemon",true,false).pressed.emit();await frames(2)
	check(p.character_id==1 and p.model==p.character_models[1] and p.active_ability==null and not pirate.active and is_equal_approx(p.hp/p.max_hp,.5),"The real picker switches a native fighter to Goemon without free healing or an active native combat controller")
	var fx=p.rogue_pipe_combo.fx;var fx_time=fx.time
	tap("light_attack");await frames(12)
	check(p.uses_rogue_pipe_profile() and fx.time>fx_time and fx==pirate.fx,"Goemon resumes ticking the same shared native effect pool after a fighter swap")
	game.show_rogue_roster();await frames(2)
	game.menu.find_child("RogueFighter_pirate",true,false).pressed.emit();await frames(2)
	check(p.active_ability==pirate and pirate.active and pirate.player.cooldowns.drink>cooldown-.7 and is_equal_approx(p.hp/p.max_hp,.5) and fx.items.is_empty(),"Returning from Goemon restores the cached native kit and cooldown while clearing interrupted shared effects")
	await fresh_goemon();press("light_attack");await frames(4);game.show_pause();press("light_attack",false)
	var remaining=p.attack_left;var pose=p.model.pipe_combo_pose.duplicate(true);fx_time=fx.time
	await frames(15)
	check(p.attack_left==remaining and p.model.pipe_combo_pose==pose and fx.time==fx_time and not p.rogue_controls.held,"Pause freezes Goemon's attack pose and shared effects while releasing held input")
	game.resume();await settle_goemon();await frames(35)
	check(p.attack_left==0 and p.combo==1 and not p.rogue_controls.held,"Resuming finishes Goemon's interrupted swing without replaying a held attack")
	tap("light_attack");await frames(2);game.restart_area();pause_fixture_director();await frames(3)
	check(game.rogue_roster_mode and p.character_id==1 and game.selected_rogue_id==1 and game.encounters.phase=="draft" and p.attack_left==0 and p.rogue_controls.primary_buffer==0 and not p.rogue_controls.held and fx.items.is_empty(),"Restart keeps the selected Goemon, resets his pending combat and shared effects, and returns to the original opening draft")
	check(game.encounters.choose_card("supply_cache") and not game.paused,"The restarted Goemon run can choose the original opening card and resume")
	pause_fixture_director()

func primary_rules():
	var geometry_hashes={};var source_hashes={}
	for index in range(CLASS_IDS.size()):
		await fresh_class(index)
		var p=game.player;var a=p.active_ability;var model=p.model;var id=CLASS_IDS[index]
		var expected_path="res://assets/rogue/styled/models/%s.glb" % id
		var loaded=is_instance_valid(model.actor) and model.actor.id==id and is_instance_valid(model.actor.model) and model.actor.model.scene_file_path==expected_path
		check(loaded and p.character_id==index+3 and a.class_id==id,"%s loads its actual native model and dedicated class kit" % id)
		if not loaded:continue
		var geometry_hash=model_geometry_hash(model.actor.model)
		var source_hash=FileAccess.get_sha256(expected_path) if OS.has_feature("editor") else ""
		geometry_hashes[geometry_hash]=true
		if OS.has_feature("editor"):source_hashes[source_hash]=true
		check(model.actor.joints.has("Body") and model.actor.joints.has("Weapon_Cutlass") and not model.actor.model.find_children("*","MeshInstance3D",true,false).is_empty(),"%s retains its authored body joints, weapon, and visible mesh" % id)
		var target=fixture(Vector3(2.2,0,0));var rear=fixture(Vector3(-2.2,0,0))
		var idle=pose_snapshot(model.actor)
		aim_world(target.position);tap("light_attack")
		var native_attack=a.player.attack
		check(native_attack!=null and native_attack.style==PRIMARY_STYLE[index] and target.hp==10000 and not p.quick_attacks.active and not p.chain_pipe_combat.active,"%s starts its own primary windup without a Goemon fallback" % id)
		await frames(2)
		check(pose_snapshot(model.actor)!=idle and model.actor.scale.is_equal_approx(Vector3.ONE*1.15),"%s animates the authored joints while keeping its 15 percent visual size increase" % id)
		for i in range(100):
			if target.hp<10000:break
			await frames(1)
		check(is_equal_approx(10000-target.hp,PRIMARY_DAMAGE[index]) and rear.hp==10000,"%s primary applies its native %d damage in the aimed direction" % [id,PRIMARY_DAMAGE[index]])
		await capture("primary-%02d-%s" % [index+1,id])
		await settle_attack();var health=target.hp;await frames(12)
		check(is_equal_approx(target.hp,health) and a.player.attack==null,"%s one tap finishes without repeated contact or extra attacks" % id)
		class_results.append({"id":id,"model":expected_path,"sha256":source_hash,"geometry_sha256":geometry_hash,"primary_damage":10000-target.hp,"primary_style":native_attack.style})
	var distinct=geometry_hashes.size()==10 and not geometry_hashes.has("")
	if OS.has_feature("editor"):distinct=distinct and source_hashes.size()==10 and not source_hashes.has("")
	check(distinct,"All ten playable classes use distinct native model geometry and available source assets")

func secondary_rules():
	var expected_kinds={"samurai":"arrow","ninja":"star","mage":"bolt","magic-swordsman":"wave","ranger":"arrow"}
	for index in range(CLASS_IDS.size()):
		await fresh_class(index)
		var p=game.player;var a=p.active_ability;var id=CLASS_IDS[index]
		var target=fixture(Vector3(2.2,0,0));aim_world(target.position)
		if id=="master-thief":
			game.tuning.invincible=false;press("heavy_attack");await frames(2)
			var before=p.hp
			for i in range(3):p.invuln=0;p.take_hit(10,Vector3.LEFT,true)
			check(p.hp==before and a.player.blockMeter>=100 and a.player.blocking,"Master Thief blocks real incoming projectiles and fills the fire meter")
			press("heavy_attack",false);await frames(2);tap("heavy_attack")
			game.tuning.invincible=true
		else:tap("heavy_attack")
		var starting_cooldown=a.player.cooldowns.flintlock
		await settle_attack();await frames(12)
		var valid=target.hp<10000 and starting_cooldown>0
		if expected_kinds.has(id):
			var expected_count=5 if id=="ninja" else (4 if id=="ranger" else 1)
			valid=valid and native_projectiles.size()==expected_count and native_projectiles.values().all(func(pr):return pr.kind==expected_kinds[id])
		elif id=="pirate":valid=valid and is_equal_approx(10000-target.hp,82)
		elif id=="knight":valid=valid and is_equal_approx(10000-target.hp,31)
		elif id=="dragoon":valid=valid and is_equal_approx(10000-target.hp,85)
		elif id=="explorer":valid=valid and is_equal_approx(10000-target.hp,53)
		elif id=="master-thief":valid=target.hp<=9880 and a.player.blockMeter==0
		check(valid,"%s secondary preserves its distinct shot, volley, bash, leap, spin or charged fire behavior" % id)
		if id=="magic-swordsman":check(native_projectiles.values().all(func(pr):return pr.pierce),"Magic Swordsman's energy wave retains its piercing behavior")

func utility_and_skill_rules():
	for index in range(CLASS_IDS.size()):
		await fresh_class(index)
		var p=game.player;var a=p.active_ability;var id=CLASS_IDS[index]
		var hook_target=fixture(Vector3(8,0,0));aim_world(hook_target.position)
		var origin=p.position;tap("dodge");await frames(45)
		if id=="master-thief":
			check(a.player.crouched and p.position.distance_to(origin)<.3,"Master Thief utility toggles its persistent low stance")
			game.tuning.invincible=false;p.invuln=0;var hp=p.hp;p.take_hit(10,Vector3.LEFT,true);game.tuning.invincible=true
			check(p.hp==hp,"Master Thief's low stance avoids an actual incoming projectile")
		else:
			var offset=p.position-origin;offset.y=0
			check(offset.length()>1.2 and (offset.x<-.5 if id=="dragoon" else offset.x>.5),"%s utility performs its own directional movement with Dragoon retreating backward" % id)
		await fresh_class(index);a=p.active_ability
		var target=fixture(Vector3(2.2,0,0));aim_world(target.position);tap("surge")
		var skill_active=false
		if id=="pirate":skill_active=a.player.drink>4.8
		elif id=="samurai":skill_active=a.player.attack!=null and a.player.attack.style=="iaijutsu"
		else:skill_active=a.player.buffTime>7.8 and not String(a.player.buffName).is_empty()
		check(skill_active and a.player.cooldowns.drink>10,"%s activates its named native skill and real cooldown" % id)
		if id=="samurai":
			await settle_attack();check(is_equal_approx(10000-target.hp,115),"Samurai Iaijutsu applies its full 115-damage draw-cut")
		elif id=="explorer":
			tap("light_attack");await settle_attack();check(is_equal_approx(10000-target.hp,38),"Explorer Blood Lust doubles the real primary hit")
		elif id=="mage":
			tap("light_attack");check(a.player.attack!=null and a.player.attack.duration<.31,"Mage Overflow accelerates the actual primary cast")
		elif id=="master-thief":
			await frames(2)
			var weapon=p.model.actor.joints.Weapon_Cutlass
			check(weapon.node.scale.is_equal_approx(weapon.scale*3),"Grand Smoke visibly grows the actual authored pipe threefold")
		elif id=="pirate":
			game.tuning.invincible=false;p.invuln=0;var hp=p.hp;p.take_hit(15,Vector3.LEFT,false);game.tuning.invincible=true
			check(p.hp==hp and p.rogue_untargetable(),"Pirate Drink makes the actual Hero untargetable during its native window")
			var guards=[]
			for boss in [false,true]:
				var guard=Ninja.new();guard.game=game;guard.swarm=true;guard.defense_lane=1
				guard.defense_role="boss" if boss else "runner";guard.defense_boss_tier=1 if boss else 0
				guard.defense_scale=3.2 if boss else 1.0;guard.variant=2 if boss else 1
				guard.position=p.position+Vector3(2.2,0,0);game.add_child(guard);game.enemies.append(guard)
				guard.set_physics_process(false);guard.state="chase";guard.cooldown=0;guards.append(guard)
			game.tuning.freeze_ai=false;guards[0]._physics_process(.016)
			guards[1].defense_traits.slam_cooldown=0
			var boss_started=guards[1].defense_traits.tick_attack(.016)
			game.tuning.freeze_ai=true
			check(guards[0].state=="march" and not boss_started and guards[1].defense_traits.phase=="march","An untargetable Pirate does not draw a new raider attack or boss slam")

func knight_defense_rules():
	await fresh_class(4)
	var p=game.player;var a=p.active_ability
	press("heavy_attack");await frames(28)
	game.tuning.invincible=false;p.invuln=0
	var health=p.hp
	p.take_hit(10,Vector3.LEFT,true);var front_blocked=p.hp==health
	p.invuln=0;p.take_hit(10,Vector3.RIGHT,true)
	p.invuln=0;p.take_hit(10,Vector3.LEFT,false)
	check(front_blocked and p.hp==health-20,"Knight blocks frontal projectiles while rear shots and melee strikes still cause damage")
	press("heavy_attack",false);game.tuning.invincible=true
	await fresh_class(4);a=p.active_ability;tap("surge")
	game.tuning.invincible=false;p.invuln=0;health=p.hp
	p.take_hit(20,Vector3.LEFT,false);var resilient=p.hp==health-10
	p.invuln=0;press("heavy_attack");await frames(28)
	p.take_hit(10,Vector3.LEFT,true);var charged=a.player.riposte>0
	press("heavy_attack",false);game.tuning.invincible=true;await frames(2)
	var target=fixture(Vector3(2.2,0,0));aim_world(target.position)
	tap("light_attack");await settle_attack()
	check(resilient and charged and is_equal_approx(10000-target.hp,76),"Knight's Code halves incoming damage and a real block empowers the next sword strike (resilience=%s, riposte=%s, damage=%.1f)" % [resilient,charged,10000-target.hp])

func utility_cover_rules():
	for index in [2,3,5]:
		await fresh_class(index)
		var p=game.player
		var origin=p.position
		var wall=Geo.box(game,p.position+Vector3(2.5,5,0),Vector3(.35,12,14),Geo.mat("657278"),true)
		await frames(2);aim_world(p.position+Vector3(8,0,0))
		tap("heavy_attack" if index==5 else "dodge");await frames(70)
		check(p.position.x-origin.x<2.3,"Solid tall cover blocks %s's real dash, blink or lance leap" % CLASS_IDS[index])
		wall.queue_free();await frames(2)

func range_pickup_rules():
	await fresh_class(0)
	var p=game.player;var target=fixture(Vector3(4,0,0))
	aim_world(target.position);tap("light_attack");await settle_attack()
	check(target.hp==10000,"Native Pirate melee retains its base range before collecting an upgrade")
	var upgraded=true
	for growth in [1,2]:
		await fresh_class(0)
		p.buildings_broken=0 if growth==1 else 50;p.scale=Vector3.ONE*p.growth_multiplier()
		p.collect_powerup("range");game.rogue_view.reset();await frames(3)
		target=fixture(Vector3(4 if growth==1 else 7,0,0))
		aim_world(target.position);tap("light_attack")
		var attack=p.active_ability.player.attack
		for i in range(50):
			if target.hp<10000:break
			await frames(1)
		var radius=0.0
		for effect in p.active_ability.fx.items:
			if effect.kind!="slash" or not is_instance_valid(effect.node):continue
			var mesh: MeshInstance3D=effect.node.get_child(0)
			for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				radius=maxf(radius,Vector2(vertex.x,vertex.z).length())
			break
		upgraded=upgraded and target.hp==9975 and is_equal_approx(attack.reach,2.85*1.5*growth) and absf(radius-attack.reach)<.01
		if growth==1:await capture("18-range-pickup-span")
	check(upgraded,"Range pickups and growth extend both real native melee contact and the matching rendered slash span")

func impact_and_muzzle_rules():
	await fresh_class(0)
	var p=game.player;var origin=p.position;var health=p.hp
	game.tuning.invincible=false;p.invuln=0;p.take_hit(20,Vector3.LEFT,false)
	await frames(14);game.tuning.invincible=true
	check(p.hp==health-20 and p.position.x<origin.x-.25,"An actual incoming hit keeps horizontal knockback through native movement updates")
	await fresh_class(3)
	var target=fixture(Vector3(5,0,0))
	var wall=Geo.box(game,p.position+Vector3(.55,2,0),Vector3(.2,5,10),Geo.mat("657278"),true)
	await frames(2);aim_world(target.position);tap("heavy_attack");await settle_attack();await frames(12)
	check(target.hp==10000,"A wall inside the projectile's initial muzzle offset prevents a shot from spawning through cover")
	wall.queue_free();await frames(2)

func cover_and_lifecycle_rules():
	for index in [0,3,6]:
		await fresh_class(index)
		var p=game.player;var target=fixture(Vector3(5,0,0))
		var wall=Geo.box(game,p.position+Vector3(2.5,2,0),Vector3(.35,5,10),Geo.mat("657278"),true)
		await frames(2);aim_world(target.position);tap("heavy_attack");await settle_attack();await frames(15)
		check(target.hp==10000,"Solid cover blocks %s secondary damage, including piercing effects" % CLASS_IDS[index])
		wall.queue_free();await frames(2)
	await fresh_class(0)
	var p=game.player;var first=p.active_ability
	p.hp=p.max_hp*.5;tap("surge");var cooldown=first.player.cooldowns.drink
	p.select_character(7);check(is_equal_approx(p.hp/p.max_hp,.5),"Switching to a higher-health Knight preserves health fraction without free healing")
	p.select_character(3)
	check(p.active_ability==first and first.player.cooldowns.drink>cooldown-.1 and is_equal_approx(p.hp/p.max_hp,.5),"Switching back reuses the class instance and preserves its spent cooldown and health")
	await fresh_class(8);var a=p.active_ability;tap("surge");tap("heavy_attack");await frames(2)
	game.show_pause();var cooldowns=a.player.cooldowns.duplicate();var buff=a.player.buffTime;var pose=pose_snapshot(p.model.actor)
	await frames(15)
	check(a.player.cooldowns==cooldowns and a.player.buffTime==buff and pose_snapshot(p.model.actor)==pose,"Pause freezes native class cooldowns, buffs and authored poses")
	game.resume();await frames(3)
	check(a.player.cooldowns.drink<cooldowns.drink and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Resume continues the same class timers with cursor combat")
	game.restart_area();pause_fixture_director();await frames(3)
	check(game.rogue_roster_mode and game.tower_defense_mode and game.encounters.phase=="draft" and game.encounters.money==12000,"Restart preserves Rogue Siege while resetting the original defenses, gold and card draft")
	var clean_state=true
	for id in range(3,13):
		if not p.character_abilities.has(id):continue
		var cached=p.character_abilities[id]
		clean_state=clean_state and cached.player.attack==null and cached.player.buffTime==0 and cached.player.cooldowns.values().all(func(value):return value==0) and cached.projectiles.is_empty()
	check(clean_state,"Restart resets every cached native class's attacks, buffs, projectiles and cooldowns")
	game.show_main_menu();await frames(2)
	check(not game.rogue_roster_mode and not game.rogue_battle_mode and not game.rogue_view.enabled,"Leaving the mode retires the playable Rogue roster and battle overlays")
	game.start_mode("defense");pause_fixture_director();await frames(2)
	check(not game.rogue_roster_mode and not game.rogue_battle_mode and p.character_id in [1,2] and game.camera_rig.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Original Fire Siege restores its existing heroes and third-person camera")
	check(game.encounters.phase=="draft" and game.encounters.cannons.size()==24 and game.menu.find_children("DefenseCard_*","Button",true,false).size()==3,"Original Fire Siege still opens with its unchanged defenses and cards")
	game.encounters.choose_card("supply_cache");p.select_character(1)
	await clear_enemies();game.reset_player_at(TEST_ORIGIN);p.soft_target=false;game.camera_rig.yaw=0;await frames(3)
	var normal=fixture(Vector3(0,0,-2.4));tap("light_attack");await frames(115)
	check(is_equal_approx(10000-normal.hp,132.4),"Original Goemon retains his full automatic triplet and existing combo damage")

func hard_and_configuration_rules():
	game.show_main_menu();await frames(2)
	game.menu.find_child("RogueSiegeButton",true,false).pressed.emit();await frames(2)
	button_with_prefix("HARD").pressed.emit();await frames(2)
	game.menu.find_child("RogueFighter_knight",true,false).pressed.emit();pause_fixture_director();await frames(3)
	check(game.rogue_roster_mode and game.player.character_id==7 and game.encounters.hard_mode and game.encounters.money==650 and game.encounters.cannons.size()==4 and game.encounters.base_hp==50,"The real Hard launch preserves its selected Knight, four defenses, 650 gold and 50 shrine health")
	await capture("20-hard-opening-draft")
	game.show_main_menu();game.player.select_character(2)
	game.defense_beta=false;game.defense_tactics=false
	game.start_mode("rogue_defense");pause_fixture_director();await frames(2)
	var required_configuration=game.defense_beta and game.defense_tactics
	game.player.select_character(1)
	game.show_main_menu();await frames(2)
	check(required_configuration and not game.defense_beta and not game.defense_tactics and game.player.character_id==2 and game.selected_rogue_id==1,"Leaving Rogue Siege with Goemon restores the previous Edo hero and defense settings while remembering the siege pick")
	game.defense_beta=true;game.defense_tactics=true

func run():
	visual="--rogue-siege-visual" in OS.get_cmdline_user_args()
	output_dir="res://tests/rogue-siege" if OS.has_feature("editor") else "user://tests/rogue-siege"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.player.smoke_mode=true
	game.impact_confirmed.connect(observe_impact)
	await pregame_rules();await mode_rules();await goemon_combo_rules();await siege_camera_rules();await goemon_lifecycle_rules();await primary_rules();await secondary_rules();await utility_and_skill_rules();await knight_defense_rules();await utility_cover_rules();await range_pickup_rules();await impact_and_muzzle_rules();await cover_and_lifecycle_rules();await hard_and_configuration_rules()
	FileAccess.open(output_dir.path_join("class-qa.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"classes":class_results},"\t"))
	print("ROGUE_SIEGE_RESULT checks=",checks," failures=",failures," output=",ProjectSettings.globalize_path(output_dir))
	game.show_main_menu();game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	await frames(18)
	get_tree().quit(1 if failures else 0)
