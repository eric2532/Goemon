extends "res://scripts/goemon_run_pacing_tests.gd"
## Observe final bone positions, including the shared turn and terrain leg IK.
func run():
	stage=Node3D.new();root.add_child(stage)
	var floor_body=StaticBody3D.new();stage.add_child(floor_body)
	var collision=CollisionShape3D.new();collision.shape=BoxShape3D.new()
	collision.shape.size=Vector3(300,.2,300);collision.position.y=-.1;floor_body.add_child(collision)
	await physics_frame
	for id in IDS:
		var model: Node3D=HeroModel.new() if id=="goemon" else (MusashiModel.new() if id=="edo" else Actor.new())
		stage.add_child(model);model.set_process(false)
		if id not in ["goemon","edo"]:model.setup(id)
		else:model.equipped=false
		var sk: Skeleton3D=model.skeleton if id in ["goemon","edo"] else model.cosplay_rig.skeleton
		var shoulder_turn=[0.0,0.0];var hip_turn=[0.0,0.0]
		var together=0;var samples=0;var clearance=[INF,INF]
		var inward=[INF,INF];var feet_separation=INF
		for frame in range(240):
			tick_run(model,id,10.2,1.0/120,frame/120.0)
			if frame<60:continue
			var shoulders=pose(sk,"Arm_R").origin-pose(sk,"Arm_L").origin
			var hips=pose(sk,"Leg_R").origin-pose(sk,"Leg_L").origin
			var shoulder_yaw=atan2(-shoulders.z,shoulders.x)
			var hip_yaw=atan2(-hips.z,hips.x)
			var hand_difference=pose(sk,"Hand_R").origin.z-pose(sk,"Hand_L").origin.z
			var foot_difference=pose(sk,"Foot_R").origin.z-pose(sk,"Foot_L").origin.z
			var peak=sin(TAU*(phase_of(model,id)-.12))
			if absf(peak)>.92:
				var side_index=0 if peak>0 else 1
				shoulder_turn[side_index]=maxf(shoulder_turn[side_index],absf(shoulder_yaw))
				hip_turn[side_index]=maxf(hip_turn[side_index],absf(hip_yaw))
				samples+=1
				if shoulder_yaw*hand_difference<0 and hip_yaw*foot_difference<0 and shoulder_yaw*hip_yaw<0:together+=1
			var chest=(pose(sk,"Chest").basis*rest(sk,"Chest").basis.inverse()).orthonormalized()
			for i in range(2):
				var side="L" if i==0 else "R"
				var sign_=-1.0 if i==0 else 1.0
				var hand=chest.inverse()*(pose(sk,"Hand_"+side).origin-pose(sk,"Arm_"+side).origin)
				if hand.y<-.35 and absf(hand.z)<.10:clearance[i]=minf(clearance[i],hand.x*sign_)
				var foot=pose(sk,"Foot_"+side).origin
				var step=fposmod(phase_of(model,id)+i*.5,1.0)
				if foot.y>rest(sk,"Foot_"+side).origin.y+.08 and step>.55 and step<.90:
					inward[i]=minf(inward[i],foot.x*sign_)
			feet_separation=minf(feet_separation,pose(sk,"Foot_R").origin.x-pose(sk,"Foot_L").origin.x)
		print("RUN_COORDINATION ",id," shoulder_turn=",shoulder_turn," hip_turn=",hip_turn," together=",together,"/",samples," hip_pass_clearance=",clearance," inward_foot=",inward," foot_separation=",feet_separation)
		check(shoulder_turn.min()>.53 and shoulder_turn.max()<.80,id+" visibly turns both shoulders with each arm swing")
		check(hip_turn.min()>.30 and hip_turn.max()<.48,id+" carries the opposite stride through the waist")
		check(samples>20 and together>samples*.85,id+" coordinates shoulder, opposite hip and limb travel")
		check(clearance.min()>.10 and clearance.max()<.25,id+" clears both hips as the hands pass the body")
		check(inward.min()>.08 and inward.max()<.24,id+" curves both airborne feet slightly inward")
		check(feet_separation>.22,id+" keeps the feet separated instead of crossing the stride")
		model.free()
	stage.free()
	print("GOEMON_RUN_COORDINATION_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
