extends SceneTree
const Weapons=preload("res://scripts/master_chief_weapons.gd")
var checks=0
var failures=0
var game
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1;print("PASS: " if ok else "FAIL: ",label_)
	if not ok:failures+=1
func frames(count:int=3):
	for i in count:await physics_frame
func key(number:int):
	for down in [true,false]:
		var event=InputEventKey.new();event.physical_keycode=KEY_1+number-1;event.pressed=down
		Input.parse_input_event(event);Input.flush_buffered_events();await frames(1)
func spawn(at:Vector3):
	var data=game.model.waves.spawn_enemy(0,at);data.hp=10000;data.max_hp=10000;data.stun=100
	game.model.visible_cells[game.model.cell_of(at)]=true;game.sync_enemies();await frames()
	var actor=game.actors[data.id];actor.set_physics_process(false);actor._sync_fitted_pose();return actor
func place(actor,at:Vector3):
	game.model.enemies[actor.forest_id].pos=at;actor.position=at
	game.model.visible_cells[game.model.cell_of(at)]=true;actor._sync_fitted_pose()
func reset_swing():
	game.player.master_chief_combat.cancel();game.player.master_chief_combat.cooldown=0;game.player.attack_chain.reset()
func run():
	check(Weapons.SLOTS.has(5) and Weapons.data(5).key=="energy_sword","Slot 5 defines the Energy Sword")
	if failures:finish();return
	check(Weapons.data(5).get("melee",false) and Weapons.data(5).range<5,"Energy Sword is a close-range melee weapon")
	check(ResourceLoader.exists(Weapons.model_path(5)) and ResourceLoader.exists(Weapons.sound_path(5)),"Sword model and native swing audio are available")
	if failures:finish();return
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://chief-sword-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames()
	var hero=game.player;hero.select_character(18);game.start_wave();game.model.waves.spawn_clock=10000
	game.tuning.invincible=true;game.tuning.critical_chance=0;game.set_physics_process(false)
	hero.set_physics_process(false);hero.position=Vector3(0,100,110);hero.velocity=Vector3.ZERO
	game.camera_rig.yaw=0;game.camera_rig.pitch=0;game.camera_rig.set_process(false);game.camera_rig.update_camera(0)
	# Use one fitted soldier for directional/occlusion fixtures, rather than a
	# whole formation whose front rank can extend across the player's position.
	game.crowd.low_fidelity=false;game.crowd.set_process(false);await frames()
	var combat=hero.master_chief_combat;var view=game.camera_rig.first_person_viewmodel;var commands=[]
	game.forest_ui.loadout_slot_selected.connect(func(slot):commands.append(slot))
	await key(5)
	check(combat.weapon_slot==5 and view.weapon_slot==5,"Physical 5 equips the sword and first-person hands")
	check(commands.is_empty(),"Chief's sword hotkey does not issue the old ally command")
	check(view.animations.has_animation("firing") and view.animations.has_animation("idle"),"Sword has visible swing and idle animation")
	check(view.sword_visual.blade_surfaces==2 and view.sword_visual.glow.multimesh.instance_count==128,"Both native blade surfaces and their two bounded glow paths are present")
	check(preload("res://scripts/sound_library.gd").moves_for(18).has("energy_sword"),"Sword swing remains editable through Sound Studio")
	var target=await spawn(Vector3(0,100,104.5))
	reset_swing();var before=target.hp;combat.fire_shot()
	check(target.hp==before,"Sword damage waits for the swing contact window")
	combat.tick(.05);check(target.hp==before,"Sword wind-up cannot deal early damage")
	combat.tick(.30);var first_damage=before-target.hp
	check(first_damage>0 and is_equal_approx(game.model.enemies[target.forest_id].hp,target.hp),"Close-range swing hits authoritative enemy HP")
	combat.tick(.20);check(is_equal_approx(before-target.hp,first_damage),"One swing cannot repeatedly damage the same enemy")
	combat.fire_shot();check(is_equal_approx(before-target.hp,first_damage),"Sword respects recovery time")
	place(target,Vector3(0,100,102));reset_swing();before=target.hp;combat.fire_shot();combat.tick(.4)
	check(target.hp==before,"Sword cannot hit a distant enemy")
	place(target,Vector3(0,100,118));reset_swing();before=target.hp;combat.fire_shot();combat.tick(.4)
	check(target.hp==before,"Sword cannot hit an enemy behind the player")
	place(target,Vector3(0,100,104.5));var wall=StaticBody3D.new();wall.collision_layer=1
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(8,8,.3);wall.add_child(shape);game.add_child(wall);wall.position=Vector3(0,102,108.7);await frames()
	reset_swing();before=target.hp;combat.fire_shot();combat.tick(.4)
	check(target.hp==before,"Walls block the blade's contact sweep")
	place(target,Vector3(0,100,104));shape.shape.size=Vector3(8,8,.04);wall.position.z=107.576;await frames()
	reset_swing();before=target.hp;combat.fire_shot();combat.tick(.4)
	check(target.hp==before,"Blade width cannot reach a victim immediately behind a thin wall")
	wall.queue_free();await frames()
	reset_swing();before=target.hp;combat.fire_shot();combat.select_slot(2);combat.tick(.4)
	check(target.hp==before,"Switching weapons cancels a pending sword hit")
	combat.select_slot(5);reset_swing();combat.fire_shot();combat.cancel();combat.tick(.4)
	check(target.hp==before,"Session cancellation clears the pending sword contact")
	combat.select_slot(5);combat.primary_held=true;await key(4)
	check(combat.weapon_slot==4 and not combat.primary_held,"Switching from the sword releases held attack input")
	hero.select_character(14);await key(5)
	check(commands.is_empty(),"Other characters leave unassigned key 5 empty")
	finish()
func finish():
	if is_instance_valid(game):game.queue_free()
	paused=false;await frames()
	print("MASTER_CHIEF_SWORD_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
