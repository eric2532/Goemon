extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Exercise the real forest player, kit, visible grip and lifecycle.
func run():
	await setup_fixture()
	var p=game.player;p.select_character(12)
	var ability=p.active_ability
	check(ability.class_id=="master-thief" and is_instance_valid(p.model.actor.rom_thief),"Forest selection installs the ROM Master Thief with his native class kit")
	var actor=p.model.actor;var visual=actor.rom_thief
	check(p.model.hand_position().distance_to(visual.weapon.global_position)<.001,"Hero hand socket follows the new visible wrist")
	check(p.model.cape_skeleton()==visual.equipment_skeleton,"Optional cloth follows the new body skeleton")
	p.facing=Vector3.FORWARD;ability.player.angle=PI;ability.aim=p.position+Vector3.FORWARD*5
	var dummy=game.training_dummy;dummy.position=ORIGIN+Vector3.FORWARD*1.5;dummy.hp=10000
	contacts.clear();tap("light_attack")
	check(ability.player.attack!=null,"LMB begins the existing Master Thief attack")
	await step(60)
	check(not contacts.is_empty(),"The new visible pipe registers a real training target contact")
	var guard_press=InputEventAction.new();guard_press.action="heavy_attack";guard_press.pressed=true;p._unhandled_input(guard_press)
	ability._animate(.016,0)
	check(ability.player.blocking,"RMB still activates the fire guard")
	game.tuning.invincible=false;p.invuln=0;var hp=p.hp;p.take_hit(10,Vector3.BACK,true)
	check(p.hp==hp and ability.player.blocking,"Fire guard still blocks incoming projectiles")
	ability.secondary_held=false;ability.player.blocking=false
	tap("equip");ability.tick_timers(.016);ability._animate(.016,0)
	check(ability.player.crouched,"E still toggles Get Down")
	ability.player.cooldowns.roll=0;tap("equip");ability.tick_timers(.016)
	tap("surge");ability._animate(.016,0)
	check(ability.player.buffTime>0,"R still activates Grand Smoke")
	var grown=visual.weapon.global_basis.get_scale().length()
	ability.player.buffTime=0;ability._animate(0,0)
	check(is_equal_approx(grown,visual.weapon.global_basis.get_scale().length()*3),"Grand Smoke enlarges the visible fitted pipe threefold about its grip")
	p.select_character(1);p.select_character(12)
	check(ability.player.attack==null and not ability.player.blocking and ability.player.buffTime==0,"Switching fighters clears transient skill and attack state")
	if "--visual" in OS.get_cmdline_user_args():
		p.position=ORIGIN+Vector3(0,0,-8);ability.player.pos=p.position;ability._animate(.016,0)
		game.camera_rig.camera.global_position=p.position+Vector3(5,3,-8)
		game.camera_rig.camera.look_at(p.position+Vector3.UP*1.6)
		await frames(3);await RenderingServer.frame_post_draw
		var path="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/ROM Goemon Blender Base/master-thief-gameplay.png"
		check(root.get_texture().get_image().save_png(path)==OK,"Capture the new Master Thief in the current painterly game")
	game.sound_library.cancel();game.music.stop()
	game.show_main_menu()
	await frames(18)
	print("MASTER_THIEF_ROM_GAMEPLAY_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
