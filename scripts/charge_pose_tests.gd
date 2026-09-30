extends "res://scripts/combat_tests.gd"
var max_length_error=0.0
var min_elbow=PI
var visual=false
func _ready():process_priority=100
func _process(_delta):
	if not is_instance_valid(game.player):return
	var m=game.player.model
	if m.charge_pose_weight<0.999:return
	var l=m.locomotion
	var a=l.pose("Arm_R").origin
	var b=l.pose("Forearm_R").origin
	var c=l.pose("Hand_R").origin
	max_length_error=maxf(max_length_error,maxf(absf(a.distance_to(b)-0.393335),absf(b.distance_to(c)-0.29)))
	min_elbow=minf(min_elbow,acos(clampf((b-a).normalized().dot((c-b).normalized()),-1,1)))
func mouse(down: bool,right: bool=false):
	var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT;e.pressed=down
	game.player._unhandled_input(e)
func shot(label: String):
	if not visual:return
	if not game.camera_rig.is_processing():
		game.camera_rig.camera.global_position=game.player.position+Vector3(4,3,-6)
		game.camera_rig.camera.look_at(game.player.position+Vector3.UP*1.25)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/charge-"+label+".png")
func run():
	original_tuning=game.tuning.duplicate()
	game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.start_game();game.player.smoke_mode=true
	game.tuning.freeze_ai=true;game.tuning.invincible=true
	await wait(0.5);await reset();game.player.invuln=0
	game.set_process_unhandled_input(false);game.player.set_process_unhandled_input(false);game.camera_rig.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	visual="--charge-visual" in OS.get_cmdline_user_args()
	if visual:
		get_window().title="Charge pose verification · closes automatically"
		get_window().set_flag(Window.FLAG_NO_FOCUS,true)
		get_window().size=Vector2i(960,600)
		game.camera_rig.set_process(false)
		game.camera_rig.camera.global_position=game.player.position+Vector3(4,3,-6)
		game.camera_rig.camera.look_at(game.player.position+Vector3.UP*1.25)
	for slot in [1,2]:
		game.player.select_weapon(slot)
		await mouse(true)
		await wait(0.6)
		var m=game.player.model
		check(m.charge_pose_weight>0.99,"Charge stance fully blends for slot "+str(slot))
		var right=game.player.model.global_basis.x
		check((-m.pipe.global_basis.z).normalized().dot(right)>0.90,"Charge weapon points to character's right")
		check(m.locomotion.pose("Hand_R").origin.x>m.locomotion.pose("Arm_R").origin.x,"Wrist stays outside shoulder")
		await shot("hold-"+str(slot))
		game.player.smoke_move=Vector2(1,0)
		await wait(0.25)
		game.player.smoke_move=Vector2.ZERO
		await mouse(false)
		await wait(0.20)
		await shot("release-"+str(slot))
		await wait(1.0)
		check(m.charge_pose_weight<0.001 and game.player.attack_left==0,"Release returns to ordinary locomotion")
	game.player.select_weapon(1);await mouse(true);await wait(0.5)
	game.player.cancel_charge();await wait(0.4)
	check(game.player.model.charge_pose_weight<0.001,"Cancelled charge clears pose")
	game.player.activate_surge();await mouse(true);await wait(0.5)
	await shot("gold-hold")
	if visual:
		game.camera_rig.set_process(true)
		game.camera_rig.reset_follow()
		await wait(0.2)
		await shot("gameplay")
	game.player.select_weapon(2);await wait(0.4)
	check(not game.player.primary_down and game.player.model.charge_pose_weight<0.001,"Weapon switch safely cancels charge")
	check(max_length_error<0.003,"Charging and release preserve upper/forearm lengths within 3 mm")
	check(min_elbow>deg_to_rad(50),"Charged arm maintains a visibly bent elbow")
	game.player.end_surge();game.tuning=original_tuning
	print("CHARGE_POSE_RESULT failures=",failures," arm_error=",max_length_error," minimum_elbow_degrees=",rad_to_deg(min_elbow))
	get_tree().quit(1 if failures else 0)
