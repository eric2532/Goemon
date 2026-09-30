extends "res://scripts/scarf_tests.gd"

var frame_number=0
func pose_frame():
	var p=game.player
	game.camera_rig.camera.global_position=p.position+Vector3(6,3,-6)
	game.camera_rig.camera.look_at(p.position+Vector3(0,1.5,.2))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/ronin-cloak/motion/%03d.png" % frame_number)
	frame_number+=1

func run():
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);game.camera_rig.set_process(false)
	get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.camera_rig.camera.fov=43
	game.hud.hide()
	DirAccess.make_dir_recursive_absolute("res://tests/ronin-cloak/motion")
	var p=game.player
	await fresh();p.set_scarf_equipped(true);p.invuln=0
	for i in range(8):await wait(.05);await pose_frame()
	p.smoke_move=Vector2(0,-1)
	for i in range(20):await wait(.05);await pose_frame()
	check(p.model.ronin_scarf.flow>.8,"Full cloak streams during forward running")
	p.smoke_move=Vector2.ZERO
	for i in range(6):await wait(.05);await pose_frame()
	await fresh();p.set_scarf_equipped(true);p.invuln=0;p.smoke_move=Vector2.RIGHT
	await wait(.35)
	for i in range(12):await wait(.05);await pose_frame()
	check(sin(p.model.ronin_scarf.wind_angle)<-.8,"Cloak trails against actual sideways travel")
	await fresh();p.set_scarf_equipped(true);p.invuln=0
	var upright=true
	for jump in range(4):
		await key(KEY_SPACE)
		for i in range(6):
			await wait(.05);await pose_frame()
			if jump==0:upright=upright and absf(p.model.body.rotation.x)<.2
	check(upright and p.jumps_used==4,"Four jumps play while the first retains the upright lift")
	# Compare measured phase advance at base and boosted actual travel speeds.
	var rates=[]
	for equipped in [false,true]:
		await fresh();p.set_scarf_equipped(equipped);p.smoke_move=Vector2.RIGHT
		await wait(.35)
		var phase_sum=0.0;var previous=p.model.locomotion.phase
		for i in range(24):
			await get_tree().physics_frame
			var current=p.model.locomotion.phase
			phase_sum+=fposmod(current-previous,1.0);previous=current
		rates.append(phase_sum)
	check(rates[1]/rates[0]>.85 and rates[1]/rates[0]<1.15,"Measured stride cadence stays natural at 3× travel speed: "+str(rates))
	print("CLOAK_MOTION_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
