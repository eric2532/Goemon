extends "res://scripts/combat_tests.gd"
var capture=false
var frame=0
var capture_clock=0.0
func _process(delta):
	if not capture:return
	capture_clock+=delta
	if capture_clock<0.05:return
	capture_clock=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/feel-frames/%04d.png"%frame)
	frame+=1
func run():
	original_tuning=game.tuning.duplicate()
	game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.start_game()
	game.player.smoke_mode=true
	game.tuning.freeze_ai=true
	game.tuning.invincible=true
	await wait(0.6)
	await reset()
	if "--feel-visual" in OS.get_cmdline_user_args():
		get_window().size=Vector2i(960,600)
		DirAccess.make_dir_recursive_absolute("res://tests/feel-frames")
		game.camera_rig.distance=8
		game.camera_rig.yaw=0.65
		capture=true
	var e=dummy(Vector3(0,0,-2.5))
	# A miss has no impact feedback, and contact is what starts local hit stop.
	game.player.facing=Vector3.BACK
	game.player.start_attack(false)
	await wait(0.15)
	check(e.hp==1000 and game.player.impact_pause==0,"A missed swing never creates damage or hit-stop")
	game.player.attack_left=0
	game.player.facing=Vector3.FORWARD
	game.player.start_attack(true)
	var limit=0.7
	while e.hp==1000 and limit>0:
		await get_tree().physics_frame
		limit-=1.0/60.0
	check(e.hp<1000 and e.impact_pause>0,"Confirmed contact starts victim hit-stop")
	check(game.player.impact_pause>0 and Engine.time_scale==1,"Attacker freezes locally while world and camera retain real time")
	var attack_before=game.player.attack_left
	await wait(0.035)
	check(is_equal_approx(game.player.attack_left,attack_before),"Contact pose holds briefly during heavy impact")
	await wait(0.5)
	check(game.player.impact_pause==0 and e.impact_pause==0,"Hit-stop releases without leaving actors frozen")
	check(e.hp==952,"Active contact window damages each victim only once")
	# Recoil follows world-space hit direction, including lateral blows.
	e.take_hit(1,Vector3.RIGHT,false);e.apply_recoil()
	var right=e.model.body.rotation.z
	e.model.animate(0,0,true,0,0,false,0,false)
	e.take_hit(1,Vector3.LEFT,true);e.apply_recoil()
	check(right*e.model.body.rotation.z<0,"Opposite impacts reverse torso recoil")
	check(e.recoil_strength>0.4,"Heavy hit produces a stronger recoil")
	await wait(0.7)
	game.player.start_attack(false)
	await wait(1.6)
	game.player.select_weapon(2)
	game.camera_rig.yaw=0
	game.player.start_attack(true)
	await wait(0.9)
	game.player.select_weapon(1)
	game.player.start_attack(true,1,true,1)
	await wait(1)
	# Immediate evade cancels recovery rather than waiting for visual follow-through.
	game.player.start_attack(true)
	await key(KEY_C)
	check(game.player.attack_left==0 and game.player.dodge_time>0,"Evade cancels attacks immediately")
	await wait(0.5)
	await reset()
	game.player.smoke_move=Vector2(0,-1)
	await wait(0.12)
	check(Vector2(game.player.velocity.x,game.player.velocity.z).length()>1 and Vector2(game.player.velocity.x,game.player.velocity.z).length()<10,"Starting movement accelerates quickly without instant full speed")
	await wait(0.5)
	game.camera_rig.yaw=PI
	await wait(0.4)
	game.player.smoke_move=Vector2.ZERO
	await wait(0.3)
	check(Vector2(game.player.velocity.x,game.player.velocity.z).length()<0.1,"Braking settles promptly to planted idle")
	await key(KEY_SPACE)
	await wait(0.12)
	check(game.player.velocity.y>0 and not game.player.is_on_floor(),"Short jump compression launches responsively")
	await wait(1.5)
	check(game.player.is_on_floor(),"Jump returns to grounded locomotion")
	capture=false
	game.tuning=original_tuning
	print("GAME_FEEL_RESULT failures=",failures," frames=",frame)
	get_tree().quit(1 if failures else 0)
