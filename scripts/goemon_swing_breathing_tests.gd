extends "res://scripts/goemon_full_body_strike_tests.gd"
## Inspect production skeletons: visible upper-body breathing, planted soles,
## attached weapons and a broader follow-through, across the playable roster.
func idle_tick(model: Node3D,id: String,delta: float,time: float,speed: float=0):
	if id in ["goemon","edo"]:
		model.locomotion_velocity=Vector3.FORWARD*speed
		model.animate(delta,speed,true,0,0,false,0,false);model.sync_skeleton()
	else:model.animate_pose({"grounded":true,"motionSpeed":speed,"localMotion":Vector3.BACK*speed},delta,time,0)

func run():
	stage=Node3D.new();root.add_child(stage)
	var floor_body=StaticBody3D.new();stage.add_child(floor_body)
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(100,.2,100);shape.position.y=-.1;floor_body.add_child(shape)
	await physics_frame
	for id in IDS:
		var model: Node3D=HeroModel.new() if id=="goemon" else (MusashiModel.new() if id=="edo" else Actor.new())
		stage.add_child(model);model.set_process(false)
		if id not in ["goemon","edo"]:model.setup(id)
		var sk: Skeleton3D=model.skeleton if id in ["goemon","edo"] else model.cosplay_rig.skeleton
		for frame in range(90):idle_tick(model,id,1.0/60,frame/60.0)
		var upper=Vector2(INF,-INF);var feet_y=Vector2(INF,-INF);var grip_error=0.0
		for frame in range(240):
			idle_tick(model,id,1.0/60,(frame+90)/60.0)
			var lift=pose(sk,"Arm_R").origin.y-pose(sk,"Pelvis").origin.y
			upper=Vector2(minf(upper.x,lift),maxf(upper.y,lift))
			var foot=(sk.global_transform*pose(sk,"Foot_L").origin).y
			feet_y=Vector2(minf(feet_y.x,foot),maxf(feet_y.y,foot))
			if id not in ["goemon","edo"]:grip_error=maxf(grip_error,model.joints.Weapon_Cutlass.node.global_position.distance_to(sk.global_transform*pose(sk,"Hand_R").origin))
		print("IDLE_BREATH ",id," upper_travel=",upper.y-upper.x," sole_travel=",feet_y.y-feet_y.x," grip_error=",grip_error)
		check(upper.y-upper.x>.025 and upper.y-upper.x<.10,id+" breathes visibly through the chest and shoulders")
		check(feet_y.y-feet_y.x<.009,id+" keeps the soles planted throughout idle breathing")
		check(grip_error<.22,id+" keeps held equipment with the breathing hands")
		var breath=model.locomotion.idle_breath if id in ["goemon","edo"] else model.cosplay_rig.idle_breath
		var clock_before: float=breath.phase
		for repeat in range(8):idle_tick(model,id,0,5.5)
		check(is_equal_approx(breath.phase,clock_before),id+" does not advance breathing during zero-time pose probes")
		for frame in range(20):idle_tick(model,id,1.0/60,5.5+frame/60.0,10.2)
		check(breath.weight<.001,id+" releases breathing when running begins")
		if id in ["goemon","edo"]:
			model.animate(1.0/60,0,false,8,0,false,0,false);model.sync_skeleton()
		else:model.animate_pose({"grounded":false,"vertical":8,"motionSpeed":0},1.0/60,6,0)
		check(not breath.allowed,id+" suppresses idle breathing in the air")
		if id in ["goemon","edo"]:
			model.animate(1.0/60,0,true,0,0,false,0,true);model.sync_skeleton()
		else:model.animate_pose({"grounded":true,"motionSpeed":0,"blocking":true},1.0/60,6,0)
		check(not breath.allowed,id+" suppresses idle breathing during combat actions")
		if id=="goemon":
			model.locomotion_velocity=Vector3.ZERO
			for frame in range(60):idle_tick(model,id,1.0/60,7+frame/60.0)
			model.pipe_combo_active=true
			model.animate(1.0/60,0,true,0,1.0-(PipeCombo.CONTACT[0]+.27),false,1,false);model.sync_skeleton()
			var shoulder=pose(sk,"Arm_R").origin-pose(sk,"Arm_L").origin
			var yaw=atan2(-shoulder.z,shoulder.x)
			var head_yaw=(pose(sk,"Head").basis*rest(sk,"Head").basis.inverse()).get_euler().y
			check(yaw>1.08 and head_yaw>1.10,"Goemon's shoulders, torso and head turn farther through the weapon follow-through")
			check(pose(sk,"Hand_R").origin.x<-.30,"Goemon carries the weapon hand farther across the front of the body")
		model.free()
	stage.free();print("GOEMON_SWING_BREATHING_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
