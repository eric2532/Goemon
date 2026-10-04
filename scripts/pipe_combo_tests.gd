extends "res://scripts/combat_tests.gd"
var capture=false
var frame=0
var clock=0.0
var arm_error=0.0
var clip_label=""
var max_plant_error=0.0
func _ready():
	process_priority=100 # Sample after HeroModel evaluates its articulated pose.
func _process(delta):
	sample_rig()
	if not capture:return
	clock+=delta
	if clock<0.035:return
	clock=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/combo-frames/%04d.png"%frame)
	frame+=1
func sample_rig():
	if not is_instance_valid(game.player) or game.player.attack_left<=0:return
	var l=game.player.model.locomotion
	for side in ["L","R"]:
		var upper=l.pose("Arm_"+side).origin.distance_to(l.pose("Forearm_"+side).origin)
		var lower=l.pose("Forearm_"+side).origin.distance_to(l.pose("Hand_"+side).origin)
		# Full-length action limbs; bound upper/lower lengths should remain physical.
		if l.action_arm_extension>0.999:arm_error=maxf(arm_error,maxf(absf(upper-0.393335),absf(lower-0.29)))
	for i in range(2):
		if l.contact[i]:max_plant_error=maxf(max_plant_error,l.plant_error[i])
func mouse(down: bool,right: bool=false):
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	event.pressed=down
	game.player._unhandled_input(event)

func run():
	original_tuning=game.tuning.duplicate()
	game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.start_game()
	game.player.smoke_mode=true
	game.tuning.freeze_ai=true
	game.tuning.invincible=true
	await wait(0.6)
	await reset()
	game.player.invuln=0
	game.set_process_unhandled_input(false)
	game.player.set_process_unhandled_input(false)
	game.camera_rig.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var visual="--combo-visual" in OS.get_cmdline_user_args()
	if visual:
		get_window().title="Combo visual verification · closes automatically"
		get_window().set_flag(Window.FLAG_NO_FOCUS,true)
		get_window().size=Vector2i(960,600)
		DirAccess.make_dir_recursive_absolute("res://tests/combo-frames")
		game.camera_rig.distance=8
		game.camera_rig.yaw=0.65
		capture=true
	for stage in [1,2]:
		var a=PipeCombo.sample(stage,1)
		var b=PipeCombo.sample(stage+1,0)
		for channel in a:check(is_equal_approx(a[channel],b[channel]) if a[channel] is float else a[channel].is_equal_approx(b[channel]),"Stage %d → %d continuous %s"%[stage,stage+1,channel])
	check(PipeCombo.DURATIONS[0]<PipeCombo.DURATIONS[1] and PipeCombo.DURATIONS[1]<PipeCombo.DURATIONS[2],"Opener, sweep and finisher use increasing duration")
	check(PipeCombo.CONTACT[2]*PipeCombo.DURATIONS[2]>PipeCombo.CONTACT[1]*PipeCombo.DURATIONS[1],"Finisher has a readable anticipation")
	var e=dummy(Vector3(0,0,-2.4))
	var impacts=[]
	var pauses=[]
	var observer=func(victim,strength,duration):
		if victim==e:
			impacts.append(game.player.combo)
			pauses.append(duration)
	game.impact_confirmed.connect(observer)
	await mouse(true);await wait(0.04);await mouse(false)
	await wait(1.65)
	game.impact_confirmed.disconnect(observer)
	check(impacts==[1,2,2,3,3] and is_equal_approx(e.hp,867.6),"One click executes three ordered weapon hits plus two independent red follow-ups")
	check(pauses.size()==5 and pauses[0]<pauses[1] and pauses[1]<pauses[3],"Original weapon contacts retain increasing impact strength alongside bonus contacts")
	check(e.recoil_strength>0.4,"Finisher uses powerful enemy recoil")
	await wait(0.35)
	check(game.player.attack_left==0,"Finisher completes its committed recovery")
	await reset()
	game.player.invuln=0
	var target=dummy(Vector3(0,0,-2.4))
	await mouse(true);await wait(0.04);await mouse(false)
	await wait(0.10)
	await mouse(true);await mouse(false)
	check(game.player.combo==1 and game.player.queued,"Early extra click buffers without skipping opener")
	await wait(1.65)
	check(is_equal_approx(target.hp,867.6) and game.player.combo==3,"Buffered click does not duplicate or restart the automatic combo or its red follow-ups")
	await reset()
	game.player.invuln=0
	# Free target demonstrates physical knockback rather than stationary dummy behavior.
	target=dummy(Vector3(0,0,-2.4));target.training_dummy=false
	game.tuning.freeze_ai=false
	target.cooldown=10
	game.player.start_attack(false,3)
	while target.hp==1000:await get_tree().physics_frame
	check(Vector2(target.velocity.x,target.velocity.z).length()>10 and target.velocity.y>0,"Finisher launches a living target with stronger knockback")
	await wait(0.8)
	game.tuning.freeze_ai=true
	await reset()
	game.player.invuln=0
	if visual:
		game.camera_rig.distance=14
		game.camera_rig.yaw=0
		dummy(Vector3(0,0,-2.4))
		await mouse(true);await wait(0.04);await mouse(false)
		await wait(1.8)
	check(arm_error<0.003,"Choreography keeps full-length arm segments within 3 mm")
	check(max_plant_error<0.025,"Full-body combo preserves grounded support within 2.5 cm")
	capture=false
	if visual:
		game.clear_practice()
		game.player.set_physics_process(false)
		game.player.model.rotation=Vector3.ZERO
		game.camera_rig.set_process(false)
		game.camera_rig.camera.global_position=game.player.position+Vector3(4,3.1,-6)
		game.camera_rig.camera.look_at(game.player.position+Vector3.UP*1.25)
		for sample in [[1,0.20],[1,0.45],[1,0.99],[2,0.0],[2,0.38],[2,0.80],[3,0.25],[3,0.48],[3,0.68]]:
			game.player.combo=sample[0]
			game.player.model.pipe_combo_active=true
			game.player.model.locomotion_velocity=Vector3.ZERO
			game.player.model.locomotion.action_arm_extension=1
			game.player.model.animate(0.016,0,true,0,1-sample[1],false,sample[0],false)
			game.player.model.sync_skeleton()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://tests/combo-pose-%d-%02d.png"%[sample[0],sample[1]*100])
	game.tuning=original_tuning
	print("PIPE_COMBO_RESULT failures=",failures," frames=",frame," plant_error=",max_plant_error," arm_error=",arm_error)
	get_tree().quit(1 if failures else 0)
