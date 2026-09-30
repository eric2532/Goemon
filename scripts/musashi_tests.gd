extends "res://scripts/combat_tests.gd"
var visual=false
func wait(seconds: float):
	# Match gameplay simulation, even while a cold exported renderer compiles shaders.
	for frame in range(ceili(seconds*Engine.physics_ticks_per_second)):
		await get_tree().physics_frame
func mouse(down: bool,right: bool=false):
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT;event.pressed=down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().physics_frame
func key(code: Key):
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event)
	var release=event.duplicate();release.pressed=false;Input.parse_input_event(release)
	Input.flush_buffered_events()
	await get_tree().physics_frame
func shot(label: String):
	if not visual:return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/musashi/"+label+".png")
func fresh():
	game.player.select_character(1)
	await reset()
	game.player.select_character(2)
	game.player.musashi.cancel();game.player.musashi.ranged_mode=false
	game.player.invuln=0;game.player.dodge_cooldown=0
	await wait(.2)
func click():
	await mouse(true);await mouse(false)
func run():
	Input.use_accumulated_input=false
	original_tuning=game.tuning.duplicate();game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.start_game();game.player.smoke_mode=true;game.tuning.freeze_ai=true
	get_window().set_flag(Window.FLAG_NO_FOCUS,true)
	visual="--musashi-visual" in OS.get_cmdline_user_args()
	if visual:
		get_window().size=Vector2i(1200,800)
		game.camera_rig.set_process(false)
		game.camera_rig.camera.global_position=game.player.position+Vector3(-4,2.8,-6)
		game.camera_rig.camera.look_at(game.player.position+Vector3.UP*1.25)
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await wait(.4)
	var p=game.player;var position_before=p.position;var yaw=game.camera_rig.yaw;var enemy_count=game.enemies.size()
	for i in range(4):await key(KEY_Q);await key(KEY_Q)
	check(p.character_id==1 and p.position.distance_to(position_before)<.1 and game.enemies.size()==enemy_count and game.camera_rig.yaw==yaw,"Repeated Q switches preserve player, camera, enemies")
	await key(KEY_Q);await wait(.3)
	check(p.character_id==2 and p.model is MusashiModel and p.model.skeleton.get_bone_count()==16,"Q selects imported Musashi rig")
	await shot("01-idle")
	p.smoke_move=Vector2(0,-1);var before=p.position;await wait(.35);p.smoke_move=Vector2.ZERO
	check(p.position.distance_to(before)>1,"Shared movement moves Musashi")
	await key(KEY_SPACE);await wait(.15);check(p.jumps_used==1,"Musashi jumps")
	await key(KEY_SPACE);await wait(.15);check(p.jumps_used==2,"Musashi double jumps")
	await key(KEY_C);check(p.dodge_time>0,"Musashi evades (remaining=%s, cooldown=%s)" % [p.dodge_time,p.dodge_cooldown])
	await fresh();var e=dummy(Vector3(0,0,-2));await click();await wait(1.5)
	check(is_equal_approx(e.hp,926),"Single click completes three punches (74)")
	await fresh();e=dummy(Vector3(0,0,-2));await click();await wait(.18);await click();await wait(1.5)
	check(is_equal_approx(e.hp,926),"Extra clicks during combo do not duplicate its three hits")
	await fresh();e=dummy(Vector3(0,0,-2));await click();await wait(.18);await shot("02-left-punch");await click();await wait(.40);await click();await wait(.16);await shot("03-finisher");await wait(.8)
	check(is_equal_approx(e.hp,926),"Three timed clicks deliver left/right/left finisher (74)")
	await fresh();e=dummy(Vector3(0,0,-2));await click();await key(KEY_C);await wait(.6)
	check(e.hp==1000,"Evade cancels pending punch contact")
	for charge in [.05,.5,1.2]:
		await fresh();e=dummy(Vector3(0,0,-2));var e2=dummy(Vector3(1.5,0,-2))
		await mouse(true,true);await wait(charge)
		check(e.hp==1000,"Hook hold does not auto-attack")
		await shot("04-hook-charge" if charge>1 else "04-hook-windup")
		await mouse(false,true);await wait(.22);await shot("05-hook-contact");await wait(.65)
		var dmg=72 if charge>1 else (52 if charge>.3 else 38)
		check(is_equal_approx(e.hp,1000-dmg) and is_equal_approx(e2.hp,1000-dmg),"Hook charge stage %s hits multiple enemies once" % charge)
	for charge in [.08,1.15]:
		await fresh();e=dummy(Vector3(0,0,-6));var adjacent=dummy(Vector3(1.4,0,-6));p.soft_target=true
		await key(KEY_E);await mouse(true);await wait(charge);await shot("06-fireball-charge")
		await mouse(false);await wait(.24);await shot("07-fireball-flight");await wait(.65)
		check(e.hp<976 if charge>1 else is_equal_approx(e.hp,976),"Normal fireball / sustained charged beam damage: "+str(charge))
		check(adjacent.hp<1000 if charge>1 else adjacent.hp==1000,"Only the thick charged beam reaches adjacent targets")
	await fresh();p.musashi.shield_cooldown=0;e=dummy(Vector3(0,0,-1.9))
	await key(KEY_R);var hp=p.hp;p.take_hit(30,Vector3.BACK)
	check(p.hp==hp and p.musashi.shield_left>0,"Fire shield grants actual damage immunity (state=%s, shield=%s)" % [p.musashi.state,p.musashi.shield_left])
	await wait(1.3);await shot("08-fire-shield")
	check(e.hp>=970 and e.hp<=980,"Shield damages on 0.6 second ticks, not rendered frames")
	p.musashi.shield_left=.1;await wait(.4);check(p.musashi.shield_left==0 and p.musashi.shield==null,"Shield expires and removes VFX")
	p.invuln=0;p.take_hit(10,Vector3.BACK);check(p.hp<hp,"Damage resumes after shield")
	for mode in ["hook","fireball","punch","shield"]:
		await fresh()
		match mode:
			"hook":await mouse(true,true)
			"fireball":await key(KEY_E);await mouse(true)
			"punch":await click()
			"shield":p.musashi.shield_cooldown=0;await key(KEY_R)
		await wait(.12);await key(KEY_Q);await wait(.3)
		check(p.character_id==1 and not p.musashi.active and p.musashi.shield_left==0 and p.musashi.charge_effect==null and p.attack_left==0,"Switch cancels "+mode+" and attached effects")
		await mouse(false);await mouse(false,true);await key(KEY_Q)
		check(p.musashi.available(),"Return has valid idle state after "+mode)
	await fresh();e=dummy(Vector3(0,0,-6));e.hp=15;p.soft_target=true;p.musashi.ranged_mode=true
	await click();await wait(.8);check(e.dead,"Fireball kills through existing enemy/death system")
	await fresh();e=dummy(Vector3(0,0,-6));p.soft_target=true;p.musashi.ranged_mode=true
	var wall=Geo.box(game,p.position+Vector3(0,1.5,-3),Vector3(5,3,.3),Geo.mat("888888"),true)
	await wait(.1);await click();await wait(.7);check(e.hp==1000,"Solid wall blocks swept fireball collision");wall.queue_free()
	# Identical elapsed time at two update rates produces identical shield damage.
	for rate in [20,120]:
		await fresh();e=dummy(Vector3(0,0,-1.5));p.set_physics_process(false)
		p.musashi.shield_cooldown=0;p.musashi.activate_shield()
		for i in range(rate*2):p.musashi.tick(1.0/rate)
		check(e.hp==960,"Shield tick damage independent of update rate: "+str(rate))
		p.musashi.cancel();p.set_physics_process(true)
	await fresh();p.musashi.begin_charge(MusashiCombat.State.CHARGING_HOOK)
	await mouse(true);check(p.musashi.state==MusashiCombat.State.CHARGING_HOOK,"Incompatible simultaneous charge is blocked")
	p.musashi.cancel();p.invuln=0;p.take_hit(1,Vector3.BACK)
	check(p.musashi.state==MusashiCombat.State.HIT_REACTION,"Damage enters explicit hit reaction state")
	await key(KEY_Q);await reset();e=dummy(Vector3(0,0,-2));await click();await wait(1.6)
	check(e.hp==926,"Kai original automatic pipe combo remains 22/22/30")
	await key(KEY_2);check(p.weapon_slot==2,"Kai coins remain selectable on 2")
	await key(KEY_1);check(p.weapon_slot==1,"Kai pipe remains selectable on 1")
	await shot("09-kai-regression")
	if visual:
		await fresh();game.hud.hide();p.soft_target=false
		game.camera_rig.camera.global_position=p.position+Vector3(-2.3,2.2,-4.3)
		game.camera_rig.camera.look_at(p.position+Vector3.UP*1.25)
		await wait(.4);await shot("10-musashi-ready")
		await mouse(true,true);await wait(1.12);await shot("11-hook-charge")
		await mouse(false,true);await wait(.17);await shot("12-full-body-hook")
		await wait(.8);p.musashi.shield_cooldown=0;await key(KEY_R);await wait(.4);await shot("13-fire-shield")
		p.musashi.cancel();game.hud.show()
	game.tuning=original_tuning
	print("MUSASHI_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
