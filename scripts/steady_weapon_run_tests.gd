extends SceneTree
const Actor=preload("res://assets/rogue/scripts/actor.gd")
var checks=0
var failures=0
var stage: Node3D
func _initialize():call_deferred("run")
func check(ok: bool,label_: String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",label_)
func bone(sk: Skeleton3D,name_: String)->Transform3D:
	return sk.get_bone_global_pose(sk.find_bone(name_))
func sample(id: String,speed: float,direction: Vector3)->Dictionary:
	var actor=Actor.new();stage.add_child(actor);actor.setup(id);actor.seed=0
	var sk: Skeleton3D=actor.cosplay_rig.skeleton
	var low=Vector3.INF;var high=-Vector3.INF;var foot_low=INF;var foot_high=-INF
	var hip_low=INF;var hip_high=-INF;var grip=0.0;var support=0.0
	var begin_phase=0.0
	for frame in 240:
		actor.animate_pose({"grounded":true,"motionSpeed":speed,"localMotion":direction*speed},1.0/60,frame/60.0,1)
		if frame==60:begin_phase=actor.locomotion.phase
		if frame<60:continue
		var chest=bone(sk,"Chest").basis*sk.get_bone_global_rest(sk.find_bone("Chest")).basis.inverse()
		var angles=chest.get_euler();low=low.min(angles);high=high.max(angles)
		var hips=bone(sk,"Pelvis").basis*sk.get_bone_global_rest(sk.find_bone("Pelvis")).basis.inverse()
		hip_low=minf(hip_low,hips.get_euler().z);hip_high=maxf(hip_high,hips.get_euler().z)
		var foot=bone(sk,"Foot_R").origin;foot_low=minf(foot_low,foot.y);foot_high=maxf(foot_high,foot.y)
		var weapon: Node3D=actor.joints.Weapon_Cutlass.node
		grip=maxf(grip,weapon.global_position.distance_to(sk.global_transform*bone(sk,"Hand_R").origin))
		if id=="magic-swordsman":
			var aim=(weapon.global_basis*actor.WEAPON_AXES[id]).normalized()
			support=maxf(support,(weapon.global_position-aim*.18).distance_to(sk.global_transform*bone(sk,"Hand_L").origin))
		elif id=="samurai":
			var sheath=actor.model.find_child("SamuraiRedScabbard",true,false)
			var aim=(sheath.global_basis*actor.WEAPON_AXES[id]).normalized()
			support=maxf(support,(sheath.global_position+aim*.22).distance_to(sk.global_transform*bone(sk,"Hand_L").origin))
	var result={"chest":high-low,"hip_bank":hip_high-hip_low,"leg_lift":foot_high-foot_low,"phase":actor.locomotion.phase-begin_phase,"grip":grip,"support":support}
	actor.free();return result
func run():
	stage=Node3D.new();root.add_child(stage)
	var ground=StaticBody3D.new();stage.add_child(ground)
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(100,.2,100);shape.position.y=-.1;ground.add_child(shape)
	await physics_frame
	for speed in [5.1,10.2,18.0]:
		for direction in [Vector3.BACK,Vector3.RIGHT,Vector3(1,0,1).normalized()]:
			var reference=sample("pirate",speed,direction)
			for id in ["samurai","magic-swordsman"]:
				var values=sample(id,speed,direction)
				var label_="%s speed=%.1f direction=%s"%[id,speed,str(direction)]
				print("STEADY_RUN ",label_," chest=",values.chest," reference=",reference.chest," bank=",values.hip_bank," leg=",values.leg_lift)
				check(values.chest.y<=reference.chest.y*.13+.001 and values.chest.z<=reference.chest.z*.15+.002,label_+" has about 90% less torso twist and side sway")
				check(values.hip_bank<=reference.hip_bank*.15+.002,label_+" has restrained waist banking")
				check(values.leg_lift>reference.leg_lift*.90,label_+" keeps the full stepping leg movement")
				check(absf(values.phase-reference.phase)<.0001,label_+" retains the original stride clock")
				check(values.grip<.045 and values.support<.045,label_+" keeps both hands on the sword or sheath")
	stage.free();await create_timer(.2).timeout
	print("STEADY_WEAPON_RUN_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
