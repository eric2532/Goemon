extends Node
var game: Node
var failures=0
var recording=false
var clip=""
var frame_id=0
var capture_clock=0.0
var capture_pending=false
var samples=0
var max_plant_error=0.0
var max_anchor_drift=0.0
var max_joint_stretch=0.0
var contact_samples=0
var last_anchors=[Vector3.ZERO,Vector3.ZERO]
var had_contact=[false,false]
var old_tuning: Dictionary
var visual=false
var metrics: Dictionary={}
var observe=false
var orbit=false
var max_elbow_bend=0.0
var max_root_drift=0.0
var max_grip_error=0.0
var torso_motion={}
var opposed_samples=0
var running_samples=0
var head_yaw_sum=0.0
var head_yaw_samples=0
var idle_low=Vector3(INF,INF,INF)
var idle_high=Vector3(-INF,-INF,-INF)
var idle_arm_clearance=INF
var idle_elbow=INF

func check(ok: bool,text: String):
	if ok: print("LOCOMOTION PASS: ",text)
	else:
		failures+=1
		push_error("LOCOMOTION FAIL: "+text)

func key(code: Key,pressed: bool):
	var ev=InputEventKey.new();ev.physical_keycode=code;ev.pressed=pressed
	Input.parse_input_event(ev)

func _process(delta):
	if not is_instance_valid(game.player) or not observe:return
	var m=game.player.model
	var l=m.locomotion
	if orbit:
		game.camera_rig.camera.global_position=game.player.global_position+Vector3(5,3.5,-7)
		game.camera_rig.camera.look_at(game.player.global_position+Vector3.UP*1.4)
	for i in range(2):
		if l.contact[i]:
			contact_samples+=1
			max_plant_error=maxf(max_plant_error,l.plant_error[i])
			if had_contact[i] and last_anchors[i].distance_to(l.anchor[i])<0.02:
				max_anchor_drift=maxf(max_anchor_drift,last_anchors[i].distance_to(l.anchor[i]))
		last_anchors[i]=l.anchor[i]
		had_contact[i]=l.contact[i]
		var side="L" if i==0 else "R"
		var a=l.pose("Leg_"+side).origin
		var b=l.pose("Shin_"+side).origin
		var c=l.pose("Foot_"+side).origin
		var length1=l.rest["Leg_"+side].origin.distance_to(l.rest["Shin_"+side].origin)
		var length2=l.rest["Shin_"+side].origin.distance_to(l.rest["Foot_"+side].origin)
		var segment_error=maxf(absf(a.distance_to(b)-length1),absf(b.distance_to(c)-length2))
		if segment_error>.012 and segment_error>max_joint_stretch:
			print("LEG_TRANSITION_ERROR ",clip," side=",side," grounded=",l.grounded," air_blend=",l.air_blend," contact=",l.contact," error=",segment_error)
		max_joint_stretch=maxf(max_joint_stretch,segment_error)
	if clip=="Idle":
		var hip=l.pose("Leg_L").origin;var knee=l.pose("Shin_L").origin;var ankle=l.pose("Foot_L").origin
		var bend=acos(clampf((knee-hip).normalized().dot((ankle-knee).normalized()),-1,1))
		var state=Vector3(l.pose("Pelvis").origin.y,l.pose("Head").origin.y,bend)
		idle_low=idle_low.min(state);idle_high=idle_high.max(state)
		idle_arm_clearance=minf(idle_arm_clearance,absf(l.pose("Hand_R").origin.x-l.pose("Arm_R").origin.x))
	var shoulder=l.pose("Arm_R").origin
	var elbow=l.pose("Forearm_R").origin
	var wrist=l.pose("Hand_R").origin
	max_elbow_bend=maxf(max_elbow_bend,acos(clampf((elbow-shoulder).normalized().dot((wrist-elbow).normalized()),-1,1)))
	if clip=="Idle":idle_elbow=minf(idle_elbow,acos(clampf((elbow-shoulder).normalized().dot((wrist-elbow).normalized()),-1,1)))
	max_root_drift=maxf(max_root_drift,l.pose("Root").origin.length())
	var expected_grip=m.skeleton.global_transform*(l.pose("Hand_R")*l.rest.Hand_R.affine_inverse()*Vector3(1.335,1.285,-0.015))
	max_grip_error=maxf(max_grip_error,m.pipe.global_position.distance_to(expected_grip))
	if l.actual_speed>8.0:
		head_yaw_sum+=(l.pose("Head").basis*l.rest.Head.basis.inverse()).get_euler().y
		head_yaw_samples+=1
	if l.grounded and l.actual_speed>8.0:
		running_samples+=1
		for bone in ["Pelvis","Spine","SpineMid","Chest","Clavicle_L","Clavicle_R","Neck","Head","Hand_L","Hand_R"]:
			var rotation=(l.pose(bone).basis*l.rest[bone].basis.inverse()).get_euler()
			if not torso_motion.has(bone):torso_motion[bone]={"min":rotation,"max":rotation}
			torso_motion[bone].min=torso_motion[bone].min.min(rotation)
			torso_motion[bone].max=torso_motion[bone].max.max(rotation)
		var hips=(l.pose("Pelvis").basis*l.rest.Pelvis.basis.inverse()).get_euler().y
		var chest_yaw=(l.pose("Chest").basis*l.rest.Chest.basis.inverse()).get_euler().y
		if hips*chest_yaw<0:opposed_samples+=1
	samples+=1
	if visual and recording:
		capture_clock-=delta
		if capture_clock<=0 and not capture_pending:
			capture_clock=1.0/20.0
			capture.call_deferred()

func capture():
	capture_pending=true
	await RenderingServer.frame_post_draw
	var img=get_viewport().get_texture().get_image()
	img.resize(768,480,Image.INTERPOLATE_LANCZOS)
	img.save_png("res://tests/locomotion-frames/%04d.png"%frame_id)
	frame_id+=1
	capture_pending=false

func segment(name: String,input: Vector2,seconds: float):
	clip=name
	head_yaw_sum=0;head_yaw_samples=0
	game.hud.toast_time=seconds
	game.hud.toast_text=name
	max_plant_error=0;max_anchor_drift=0;max_joint_stretch=0;contact_samples=0
	had_contact=[false,false]
	game.player.smoke_move=input
	await get_tree().create_timer(seconds).timeout
	metrics[name]={"plant_error_m":max_plant_error,"anchor_drift_m":max_anchor_drift,"bone_length_error_m":max_joint_stretch,"contacts":contact_samples,"speed":game.player.model.locomotion.actual_speed,"grounded":game.player.is_on_floor(),"vertical":game.player.velocity.y}
	metrics[name]["mean_head_yaw_degrees"]=rad_to_deg(head_yaw_sum/maxi(1,head_yaw_samples))
	print("LOCOMOTION METRIC ",name," ",metrics[name])
	check(max_plant_error<0.025,name+": reachable foot targets (under 2.5 cm error)")
	check(max_anchor_drift<0.001,name+": stance anchors remain stationary")
	check(max_joint_stretch<0.012,name+": limb segment lengths preserved")

func reset():
	game.player.smoke_move=Vector2.ZERO
	game.reset_player_at(Vector3(0,game.world.height_at(0,41)+0.05,41))
	game.player.invuln=0
	game.player.model.locomotion.initialized=false
	game.player.model.rotation.y=0
	game.player.facing=Vector3.FORWARD
	game.camera_rig.yaw=0
	await get_tree().create_timer(0.25).timeout

func run():
	process_priority=100
	visual="--locomotion-visual" in OS.get_cmdline_user_args()
	if visual: DirAccess.make_dir_recursive_absolute("res://tests/locomotion-frames")
	old_tuning=game.tuning.duplicate()
	game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.tuning.freeze_ai=true;game.tuning.invincible=true
	game.start_game()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.set_process_unhandled_input(false)
	game.camera_rig.set_process_unhandled_input(false)
	game.player.smoke_mode=true
	game.player.soft_target=false
	game.hud.banner_time=0
	await get_tree().create_timer(0.5).timeout
	check(game.player.model.skeleton.get_bone_count()==22,"Articulated skeleton imported")
	check(game.player.model.locomotion.tree.active,"AnimationTree is active")
	observe=true
	orbit=visual
	if orbit:game.camera_rig.set_process(false)
	recording=visual
	await segment("Idle",Vector2.ZERO,5.0)
	print("IDLE_BREATH_EXTENT ",idle_high-idle_low," ARM_CLEARANCE ",idle_arm_clearance," ELBOW ",idle_elbow)
	check(idle_high.x-idle_low.x>0.008,"Idle pelvis breathes while feet stay planted")
	check(idle_high.y-idle_low.y>0.015,"Idle head follows the torso breathing rise")
	check(idle_high.z-idle_low.z>0.02,"Idle knees flex and recover with breathing")
	check(idle_arm_clearance>0.09 and idle_elbow>0.48,"Idle arms are gently bent and held away from torso")
	var locomotion=game.player.model.locomotion
	check(locomotion.pose("Arm_L").origin.distance_to(locomotion.pose("Arm_R").origin)>locomotion.rest.Arm_L.origin.distance_to(locomotion.rest.Arm_R.origin)*1.03,"Shoulder stance is subtly broader")
	for side in ["L","R"]:
		var upper_length=locomotion.pose("Arm_"+side).origin.distance_to(locomotion.pose("Forearm_"+side).origin)
		var lower_length=locomotion.pose("Forearm_"+side).origin.distance_to(locomotion.pose("Hand_"+side).origin)
		var upper_rest=locomotion.rest["Arm_"+side].origin.distance_to(locomotion.rest["Forearm_"+side].origin)
		var lower_rest=locomotion.rest["Forearm_"+side].origin.distance_to(locomotion.rest["Hand_"+side].origin)
		print("ARM_SCALE ",side," ",upper_length/upper_rest," ",lower_length/lower_rest," hand=",locomotion.pose("Hand_"+side).basis.get_scale())
		check(absf(upper_length/upper_rest-0.81)<0.004 and absf(lower_length/lower_rest-0.81)<0.004,"Idle arm "+side+" is 81% of original length along its segments")
		check(locomotion.pose("Hand_"+side).basis.get_scale().distance_to(Vector3.ONE)<0.003,"Idle hand size is preserved")
	clip="Idle attack reach"
	game.player.start_attack(false)
	await get_tree().create_timer(0.14).timeout
	check(locomotion.pose("Arm_R").basis.y.length()>0.99,"Stationary attacks regain full arm reach")
	await get_tree().create_timer(1.45).timeout
	check(locomotion.pose("Arm_R").basis.y.length()<0.82,"Arms settle back to short idle after attack")
	key(KEY_CTRL,true)
	await segment("Walk",Vector2(0,-1),1.4)
	key(KEY_CTRL,false)
	await segment("Walk to run",Vector2(0,-1),1.2)
	key(KEY_SHIFT,true)
	await segment("Run to sprint",Vector2(0,-1),0.85)
	key(KEY_SHIFT,false)
	await segment("Braking to idle",Vector2.ZERO,0.5)
	await reset()
	await segment("Backward run",Vector2(0,1),0.9)
	check(game.player.facing.dot(Vector3.BACK)>0.95,"Backward input turns the body toward travel")
	await reset()
	await segment("Left run",Vector2(-1,0),1.2)
	check(game.player.facing.dot(Vector3.LEFT)>0.95,"Left input turns the body toward travel")
	await segment("Right turn",Vector2(1,0),1.4)
	check(game.player.facing.dot(Vector3.RIGHT)>0.95,"Reversing sideways turns the body toward travel")
	await reset()
	game.player.smoke_move=Vector2(0,-1)
	for i in range(18):
		game.camera_rig.yaw+=PI/36
		await get_tree().create_timer(1.0/60).timeout
	await segment("Turning",Vector2(0,-1),0.7)
	await reset()
	key(KEY_SPACE,true);key(KEY_SPACE,false)
	await segment("Jump start / rise",Vector2(0,-1),0.30)
	check(game.player.model.locomotion.air_blend>0.8,"Ground-to-air blend reaches jump state")
	await segment("Fall / landing",Vector2(0,-1),0.8)
	await segment("Landing recovery",Vector2.ZERO,0.35)
	check(game.player.model.locomotion.air_blend<0.05,"Landing returns smoothly to ground locomotion")
	# Terrain contacts on the temple approach slope with the actual player collider.
	game.reset_player_at(Vector3(-8,game.world.height_at(-8,-21)+0.05,-21))
	game.camera_rig.yaw=0
	await segment("Temple slope",Vector2(0,-1),0.8)
	await reset()
	# A collider blocks motion: velocity intent must not animate running in place.
	var wall=StaticBody3D.new();wall.collision_layer=1
	var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(4,5,0.3);collision.shape=box;wall.add_child(collision)
	game.add_child(wall);wall.global_position=game.player.global_position+Vector3(0,1,-1)
	await segment("Blocked movement",Vector2(0,-1),0.8)
	check(game.player.model.locomotion.actual_speed<0.15,"Wall contact uses actual displacement, not requested velocity")
	wall.queue_free()
	if visual:
		# A second pass uses the untouched, collision-aware gameplay camera.
		orbit=false
		game.camera_rig.set_process(true)
		await reset()
		game.camera_rig.distance=14
		game.camera_rig.pitch=0.36
		await segment("Gameplay camera / run",Vector2(0,-1),1.3)
		key(KEY_SHIFT,true)
		await segment("Gameplay camera / sprint",Vector2(0,-1),0.75)
		key(KEY_SHIFT,false)
		await segment("Gameplay camera / stop",Vector2.ZERO,0.55)
		await reset()
		await segment("Gameplay camera / left run",Vector2(-1,0),1.0)
		await segment("Gameplay camera / right turn",Vector2(1,0),1.3)
		await reset()
		await segment("Gameplay camera / breathing idle",Vector2.ZERO,5.0)
	for bone in ["Pelvis","Spine","SpineMid","Chest","Clavicle_L","Clavicle_R","Neck","Head"]:
		var extent: Vector3=torso_motion[bone].max-torso_motion[bone].min
		print("ANIME MOTION ",bone," range_degrees=",extent*180/PI)
		check(extent.length()>0.035,bone+": participates in the stride")
	check((torso_motion.Chest.max.y-torso_motion.Chest.min.y)>0.50,"Chest twist exceeds 28 degrees across the running cycle")
	check(opposed_samples>running_samples*0.55,"Chest visibly counter-rotates against the pelvis")
	check(max_elbow_bend>0.6,"Running uses visibly bent, articulated elbows")
	check(max_root_drift<0.0001,"Locomotion clips stay in place; controller exclusively owns root movement")
	check(max_grip_error<0.002,"Pipe remains attached to the animated hand")
	recording=false;observe=false
	game.player.smoke_move=Vector2.ZERO
	game.tuning=old_tuning
	if visual:
		var file=FileAccess.open("res://tests/locomotion-metrics.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"\t"))
	print("LOCOMOTION_TEST_RESULT failures=",failures," frames=",frame_id," samples=",samples)
	game.quit_clean()
