extends "res://scripts/power_combat_tests.gd"

func fresh():
	game.player.set_scarf_equipped(false)
	await prepare(1)
	game.player.smoke_move=Vector2.ZERO
	await wait(.15)

func scarf_capture(label: String,angle: float=0.7,close: bool=true):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0;game.player.invuln=0
	game.camera_rig.set_process(false)
	game.camera_rig.camera.fov=42 if close else 63
	var p=game.player.position
	var offset=Vector3(5.3,3.1,6.5).rotated(Vector3.UP,angle) if close else Vector3(0,5.0,12)
	game.camera_rig.camera.global_position=p+offset
	game.camera_rig.camera.look_at(p+Vector3(0,1.55,.25))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/ronin-cloak/"+label+".png")

func jump_tap():
	await key(KEY_SPACE);await wait(.1)

func run():
	visual="--scarf-visual" in OS.get_cmdline_user_args()
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var p=game.player
	await fresh()
	check(not p.scarf_equipped and not p.model.ronin_scarf.visible and p.maximum_jumps()==2 and p.movement_multiplier()==1,"Goemon begins without the scarf and retains normal movement and double jump")
	await key(KEY_4)
	check(p.scarf_equipped and p.model.ronin_scarf.visible and p.weapon_slot==1,"4 equips the separate scarf without changing weapons")
	check(p.movement_multiplier()==3 and p.maximum_jumps()==4,"Equipped scarf grants triple movement speed and four jumps")
	var cloth=p.model.ronin_scarf
	check(cloth.find_children("*","MeshInstance3D",true,false).size()==6 and cloth.chest_bone>=0,"Six Blender garment meshes include a full body wrap and shoulder mantle")
	await wait(.25);await scarf_capture("01-ronin-back")
	await scarf_capture("02-ronin-front",PI)
	var before=cloth.clock;await wait(.1)
	check(cloth.clock>before,"Cloth flutters even while idle")
	game.show_pause();before=cloth.clock;await wait(.15)
	check(cloth.clock==before and p.scarf_equipped,"Pause freezes cloth motion and retains the equipped outfit")
	game.resume()
	await key(KEY_3);check(p.scarf_equipped and p.model.ronin_scarf.visible and p.weapon_slot==3,"Scarf coexists with the chain pipe")
	await key(KEY_R);await scarf_capture("03-golden-ronin",.7)
	check(p.surge_left>0 and p.model.hair_gold.visible and cloth.visible,"Golden Surge keeps the red scarf")
	await key(KEY_4)
	check(not p.scarf_equipped and not cloth.visible and p.maximum_jumps()==2 and p.movement_multiplier()==1,"4 removes both scarf and movement bonuses")

	# Measure actual collision-body movement, including run/sprint/slow walk.
	for action in ["run","sprint","walk_modifier"]:
		var speeds=[]
		for equipped in [false,true]:
			await fresh();p.set_scarf_equipped(equipped)
			p.smoke_move=Vector2.RIGHT
			if action!="run":Input.action_press(action)
			await wait(.65)
			speeds.append(Vector2(p.velocity.x,p.velocity.z).length())
			if equipped and action=="run":await scarf_capture("04-scarf-running",.55,false)
			p.smoke_move=Vector2.ZERO
			if action!="run":Input.action_release(action)
		check(absf(speeds[1]/speeds[0]-3.0)<.03,"Actual %s movement is 3× with the scarf: %s" % [action,str(speeds)])
	await fresh();await key(KEY_4);p.smoke_move=Vector2.RIGHT;await wait(.65)
	check(cloth.flow>.7,"Scarf streams behind Goemon at boosted running speed")
	check(p.model.locomotion.ronin_speed_scale()==3 and p.model.locomotion.move_blend.length()<.75,"Boosted run retains normal run cadence instead of overspeed sprint animation")
	await key(KEY_4)
	check(Vector2(p.velocity.x,p.velocity.z).length()<=game.tuning.walk_speed+.1,"Removing scarf immediately removes excess speed")
	p.smoke_move=Vector2.ZERO
	await fresh();await key(KEY_4)
	var wall_origin=p.position
	var wall=Geo.box(game,p.position+Vector3(4,1.5,0),Vector3(.4,5,8),Geo.mat("888888"),true)
	await wait(.05);p.smoke_move=Vector2.RIGHT;Input.action_press("sprint");await wait(.6)
	p.smoke_move=Vector2.ZERO;Input.action_release("sprint")
	check(p.position.x-wall_origin.x<3.5,"Even at 3× sprint speed, the body cannot tunnel through a wall")
	wall.queue_free()

	await fresh();await jump_tap();check(p.jumps_used==1 and not p.is_on_floor(),"First jump launches from the ground")
	await jump_tap();check(p.jumps_used==2 and p.velocity.y>0,"Normal second jump refreshes upward velocity")
	await wait(.15);var velocity_before=p.velocity.y;await jump_tap()
	check(p.jumps_used==2 and p.velocity.y<velocity_before,"Without scarf a third press cannot add another jump")
	await fresh();await key(KEY_4);await jump_tap();await jump_tap();await wait(.2);await jump_tap()
	check(p.jumps_used==3 and p.velocity.y>10,"Scarf enables a real third airborne jump")
	check(absf(p.model.body.rotation.y)>.1 and absf(p.model.body.rotation.x)<.15,"Third cloaked jump begins a rising vertical spin")
	await scarf_capture("05-triple-jump",.8,false)
	await wait(.1);velocity_before=p.velocity.y;await jump_tap()
	check(p.jumps_used==4 and p.velocity.y>10,"Fourth jump launches the forward flip")
	await wait(.1);velocity_before=p.velocity.y;await jump_tap()
	check(p.jumps_used==4 and p.velocity.y<velocity_before,"A fifth jump remains blocked")
	await key(KEY_4);await key(KEY_4);velocity_before=p.velocity.y;await jump_tap()
	check(p.jumps_used==4 and p.velocity.y<velocity_before,"Toggling the scarf in midair cannot refill jumps")
	for i in range(180):
		if p.is_on_floor():break
		await get_tree().physics_frame
	await wait(.05);check(p.is_on_floor() and p.jumps_used==0,"Landing replenishes all four jump uses")
	await jump_tap();await jump_tap();await key(KEY_4);velocity_before=p.velocity.y;await jump_tap()
	check(p.jumps_used==2 and p.velocity.y<velocity_before,"Removing the scarf after jump two disables jump three")

	await fresh();await key(KEY_4);await key(KEY_Q)
	check(p.character_id==2 and p.movement_multiplier()==3 and p.maximum_jumps()==4 and not cloth.is_visible_in_tree() and p.model.ronin_scarf.visible,"Edo inherits the equipped cape's powers on his own animated rig")
	await key(KEY_4);check(p.scarf_equipped and p.character_id==2,"Edo ignores the Goemon outfit key")
	await key(KEY_Q);check(cloth.is_visible_in_tree() and p.movement_multiplier()==3,"Switching back restores Goemon's equipped scarf")
	game.restart_area();game.encounters.enabled=false
	check(p.scarf_equipped and cloth.visible and p.jumps_used==0,"Restart retains outfit choice and resets jump uses")
	await fresh();await key(KEY_4);var origin=p.position;await key(KEY_E);await wait(.23)
	check(absf(origin.z-p.position.z-4)<.15 and not p.forward_dash.active,"Scarf keeps E as the requested short four-metre dash")
	await fresh();await key(KEY_4);var enemy=target(Vector3(0,0,-6));origin=p.position
	await key(KEY_T);await wait(.1);await scarf_capture("06-scarf-sky-strike",.5,false);await attack_frames()
	check(enemy.hp==9840 and p.position.distance_to(origin)<.15 and cloth.visible,"Scarf works throughout T's leap, hit and return")
	await fresh();await key(KEY_4);enemy=target(Vector3(0,0,-2.4));await mouse(true);await mouse(false);await attack_frames()
	check(enemy.hp<9926 and cloth.visible,"Cloaked pipe combo adds coin damage to its three melee hits")
	await fresh();await key(KEY_4);await scarf_capture("07-final-outfit",1.7)
	print("SCARF_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
