extends "res://scripts/goemon_unified_run_tests.gd"
## Measure real pose cycles at fixed time steps, independent of preview playback.

func phase_of(model: Node3D,id: String) -> float:
	return fposmod(model.locomotion.phase if id == "goemon" else model.locomotion.phase/TAU,1.0)

func tick_run(model: Node3D,id: String,speed: float,dt: float,time: float):
	var heading = Vector3.FORWARD if id in ["goemon","edo"] else Vector3.BACK
	model.position += heading * speed * dt
	if id in ["goemon","edo"]:
		model.locomotion_velocity = heading * speed
		model.animate(dt,speed,true,0,0,false,0,false);model.sync_skeleton()
	else:model.animate_pose({"grounded":true,"motionSpeed":speed,"localMotion":Vector3.BACK*speed},dt,time,clampf(speed/6,0,1))

func run():
	stage = Node3D.new();root.add_child(stage)
	var floor_body = StaticBody3D.new();stage.add_child(floor_body)
	var collision = CollisionShape3D.new();collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(300,.2,300);collision.position.y = -.1;floor_body.add_child(collision)
	await physics_frame
	var reference_rates = {}
	for id in IDS:
		var model: Node3D = HeroModel.new() if id == "goemon" else (MusashiModel.new() if id == "edo" else Actor.new())
		stage.add_child(model);model.set_process(false)
		if id not in ["goemon","edo"]:model.setup(id)
		else:model.equipped = false
		var sk: Skeleton3D = model.skeleton if id in ["goemon","edo"] else model.cosplay_rig.skeleton
		for speed in [10.2,18.0]:
			model.position = Vector3.ZERO
			model.locomotion.reset()
			for frame in range(60):tick_run(model,id,speed,1.0/60,frame/60.0)
			var cycles = 0.0
			var front_height = [-INF,-INF];var rear_height = [-INF,-INF]
			var inward = [INF,INF];var outward = [-INF,-INF];var swing_pairs = [0,0]
			var foot_slip = 0.0;var foot_samples = 0
			var old_feet = [Vector3.ZERO,Vector3.ZERO];var old_low = [false,false]
			for frame in range(120):
				var previous = phase_of(model,id)
				tick_run(model,id,speed,1.0/60,1+frame/60.0)
				cycles += fposmod(phase_of(model,id)-previous,1.0)
				var chest = (pose(sk,"Chest").basis*rest(sk,"Chest").basis.inverse()).orthonormalized()
				var front_swing = [false,false];var back_swing = [false,false]
				for i in range(2):
					var side = "L" if i == 0 else "R"
					var hand = chest.inverse()*(pose(sk,"Hand_"+side).origin-pose(sk,"Arm_"+side).origin)
					if hand.z < -.25:front_height[i] = maxf(front_height[i],hand.y)
					if hand.z > .25:rear_height[i] = maxf(rear_height[i],hand.y)
					var lateral = hand.x*(-1.0 if i == 0 else 1.0)
					if hand.z<-.25:
						inward[i]=minf(inward[i],lateral)
						front_swing[i]=lateral<-.12
					if hand.z>.25 and hand.y>-.10:
						outward[i]=maxf(outward[i],lateral)
						back_swing[i]=lateral>.25
					var foot = sk.global_transform*pose(sk,"Foot_"+side).origin
					# Costume body offsets (notably Ninja's crouch) must not make
					# us count a recovering foot as a planted one.
					var local_foot = pose(sk,"Foot_"+side).origin
					var other = pose(sk,"Foot_"+("R" if i == 0 else "L")).origin
					var low = absf(local_foot.y-rest(sk,"Foot_"+side).origin.y)<.09 and local_foot.y<other.y-.2
					if id == "goemon":low = model.locomotion.contact[i]
					if low and old_low[i]:
						var delta: Vector3 = foot-old_feet[i]
						foot_slip += Vector2(delta.x,delta.z).length();foot_samples += 1
					old_low[i] = low;old_feet[i] = foot
				if front_swing[0] and back_swing[1]:swing_pairs[0]+=1
				if front_swing[1] and back_swing[0]:swing_pairs[1]+=1
			var rate = cycles/2.0
			print("RUN_PACING ",id," speed=",speed," cycles_per_second=",rate," front_hand=",front_height," rear_hand=",rear_height," contact_slip_per_frame=",foot_slip/maxf(1,foot_samples)," contact_samples=",foot_samples)
			check(rate>=1.4 and rate<=1.9 if speed<12 else rate>=1.85 and rate<=2.35,id+" has a readable full-body cadence at "+str(speed))
			check(front_height.min()>.04,id+" raises both forward hands above the shoulder line at "+str(speed))
			check(rear_height.min()>-.05,id+" raises both rear swings close to the shoulder line at "+str(speed))
			print("RUN_ARM_SWEEP ",id," speed=",speed," inward=",inward," outward=",outward," paired_frames=",swing_pairs)
			check(inward.max()<-.12,id+" sweeps each forward hand inward across the chest at "+str(speed))
			check(outward.min()>.25,id+" opens each trailing arm outward behind the shoulder at "+str(speed))
			check(swing_pairs.min()>5,id+" alternates front-inward and rear-outward arms together at "+str(speed))
			check(foot_samples>4 and foot_slip/maxf(1,foot_samples)<.04,id+" keeps the planted foot synchronized with ground travel at "+str(speed))
			if id == "goemon":reference_rates[speed] = rate
			else:check(absf(rate-reference_rates[speed])<.03,id+" matches Goemon's stride clock at "+str(speed))
		if id != "goemon":check_stopping(model,sk,id)
		model.free()
	check_fallback_motion()
	stage.free()
	print("GOEMON_RUN_PACING_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func check_fallback_motion():
	var explicit = Actor.new();stage.add_child(explicit);explicit.setup("pirate")
	var fallback = Actor.new();stage.add_child(fallback);fallback.setup("pirate")
	explicit.seed=0;fallback.seed=0
	var error = 0.0
	for frame in range(120):
		explicit.animate_pose({"grounded":true,"motionSpeed":5.0},1.0/60,frame/60.0,1)
		fallback.animate_pose({"grounded":true},1.0/60,frame/60.0,1)
		for side in ["L","R"]:
			error = maxf(error,pose(explicit.cosplay_rig.skeleton,"Foot_"+side).origin.distance_to(pose(fallback.cosplay_rig.skeleton,"Foot_"+side).origin))
	check(error<.001,"Movement input without an explicit speed keeps the same foot timing")
	explicit.free();fallback.free()

func check_stopping(model: Node3D,sk: Skeleton3D,id: String):
	var largest = 0.0
	for phase in [.15,.25,.35]:
		for frame in range(60):tick_run(model,id,10.2,1.0/60,frame/60.0)
		var gait = model.locomotion.gait if id == "edo" else model.locomotion
		gait.phase = (phase-preload("res://scripts/goemon_reference_run_body.gd").cadence(10.2)/60)*TAU
		tick_run(model,id,10.2,1.0/60,1)
		var before = [pose(sk,"Foot_L").origin,pose(sk,"Foot_R").origin]
		tick_run(model,id,0,1.0/60,1+1.0/60)
		largest = maxf(largest,before[0].distance_to(pose(sk,"Foot_L").origin))
		largest = maxf(largest,before[1].distance_to(pose(sk,"Foot_R").origin))
	print("RUN_PACING_STOP ",id," foot_motion=",largest)
	check(largest<.23,id+" releases a running stride without snapping the feet when blocked")
