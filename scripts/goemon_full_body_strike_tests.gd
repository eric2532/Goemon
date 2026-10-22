extends "res://scripts/goemon_unified_run_tests.gd"
## Inspect the final production skeleton, after ground IK and weapon attachment.
const MELEE_IDS=["goemon","goemon-rogue","goemon-heavy","pirate","samurai","ninja","knight","dragoon","magic-swordsman","explorer","master-thief"]
const Strike=preload("res://scripts/goemon_reference_strike.gd")

func snapshot(sk: Skeleton3D)->Array[Transform3D]:
	var values: Array[Transform3D]=[]
	for bone in range(sk.get_bone_count()):values.append(sk.get_bone_global_pose(bone))
	return values

func restore_pose(sk: Skeleton3D,values: Array[Transform3D]):
	for bone in range(values.size()):sk.set_bone_global_pose(bone,values[bone])

func pose_error(sk: Skeleton3D,values: Array[Transform3D])->float:
	var error=0.0
	for bone in range(values.size()):
		var current=sk.get_bone_global_pose(bone)
		error=maxf(error,current.origin.distance_to(values[bone].origin))
		for axis in range(3):error=maxf(error,current.basis[axis].distance_to(values[bone].basis[axis]))
	return error

func check_endpoints(model: Node3D):
	model.animate(1.0/60,0,false,5,0,false,0,false);model.sync_skeleton()
	var sk: Skeleton3D=model.skeleton
	var tilted=pose(sk,"Foot_L");tilted.basis=Basis(Vector3.RIGHT,.45)*tilted.basis;sk.set_bone_global_pose(sk.find_bone("Foot_L"),tilted)
	var before=snapshot(sk);var p=Strike.REST.duplicate()
	Strike.arm(sk,"R",p.wrist,0);Strike.feet(sk,p,false)
	check(pose_error(sk,before)<.00001,"zero-weight strike preserves every incoming airborne bone origin and basis")
	restore_pose(sk,before);p.weight=.0001
	Strike.arm(sk,"R",p.wrist,p.weight);Strike.feet(sk,p,false)
	check(pose_error(sk,before)<.002,"near-zero strike blends continuously into a tilted airborne pose")
	model.animate(1.0/60,0,true,0,.66,false,1,false);model.sync_skeleton();before=snapshot(sk)
	for repeat in range(16):model.locomotion.dirty=true;model.sync_skeleton()
	check(pose_error(sk,before)<.0001,"repeated zero-time skeleton sync does not accumulate strike offsets")
	model.animate(1.0/60,0,true,0,0,false,1,true);model.sync_skeleton()
	check(model.pipe_combo_pose.is_empty(),"dodge interrupts the strike without retaining its stepped foot targets")
	model.charge_slot=2;model.animate(1.0/60,0,true,0,.53,true,1,false);model.sync_skeleton()
	check(not model.pipe_combo_pose.has("left_foot"),"heavy coin throw keeps its own ranged pose")

func check_native_cycle(model: Node3D,id: String,sk: Skeleton3D):
	var worst_grip=0.0;var worst_drift=0.0
	for index in range(3):
		for t in [.08,.15,.22]:
			var state={"grounded":true,"attack":{"primary":true,"index":index,"time":t,"duration":.48,"contact":.15,"swingSide":1}}
			model.animate_pose(state,0,0,0);var before=snapshot(sk)
			for repeat in range(4):model.animate_pose(state,0,0,0)
			worst_drift=maxf(worst_drift,pose_error(sk,before))
			if id in ["dragoon","magic-swordsman"]:
				var weapon: Node3D=model.joints.Weapon_Cutlass.node
				var aim=(weapon.global_basis*model.WEAPON_AXES[id]).normalized()
				worst_grip=maxf(worst_grip,(weapon.global_position-aim*.18).distance_to(sk.global_transform*pose(sk,"Hand_L").origin))
	check(worst_drift<.0001,id+" has stable zero-time contact probes across all three swings")
	if id in ["dragoon","magic-swordsman"]:check(worst_grip<.045,id+" holds its two-handed grip through wind-up, contact and follow-through")
func attack_pose(model: Node3D,id: String,t: float):
	if id.begins_with("goemon"):
		model.pipe_combo_active=id!="goemon-heavy";model.rogue_pipe_combo_active=id=="goemon-rogue"
		model.charge_slot=1;model.equipped=true;model.locomotion_velocity=Vector3.ZERO
		model.animate(1.0/120,0,true,0,1.0-t,id=="goemon-heavy",1,false);model.sync_skeleton()
	else:
		model.animate_pose({"grounded":true,"motionSpeed":0.0,"attack":{"primary":true,"index":0,"time":t*.48,"duration":.48,"contact":.15,"swingSide":1}},1.0/120,t,0)
func run():
	stage=Node3D.new();root.add_child(stage)
	var floor_body=StaticBody3D.new();stage.add_child(floor_body)
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(100,.2,100);shape.position.y=-.1;floor_body.add_child(shape)
	await physics_frame
	for id in MELEE_IDS:
		var model: Node3D=HeroModel.new() if id.begins_with("goemon") else Actor.new()
		stage.add_child(model);model.set_process(false)
		if not id.begins_with("goemon"):model.setup(id)
		var sk: Skeleton3D=model.skeleton if id.begins_with("goemon") else model.cosplay_rig.skeleton
		var contact=.47 if id=="goemon-heavy" else (.34 if id=="goemon" else .15/.48)
		for frame in range(30):attack_pose(model,id,.001)
		attack_pose(model,id,contact*.52)
		var head_before=(pose(sk,"Head").basis*rest(sk,"Head").basis.inverse()).get_euler().y
		attack_pose(model,id,contact)
		var right=pose(sk,"Arm_R").origin;var left=pose(sk,"Arm_L").origin
		var hips=pose(sk,"Pelvis").origin;var head=pose(sk,"Head").origin
		var lead=pose(sk,"Foot_L").origin;var rear=pose(sk,"Foot_R").origin
		print("STRIKE_POSE ",id," shoulder_delta=",right-left," head_from_hips=",head-hips," foot_delta=",rear-lead," left_hand=",pose(sk,"Hand_L").origin-hips)
		check(right.z<left.z-.20,id+" drives its right shoulder forward and left shoulder back")
		check(head.z<hips.z-.20 and right.y<left.y-.04,id+" leans its whole body forward and toward the striking side")
		check(lead.z<rear.z-.25,id+" plants the left foot ahead of the trailing right foot")
		# The lance keeps a closer two-handed grip while its shaft supplies reach.
		check(pose(sk,"Hand_R").origin.z<hips.z-(.30 if id=="dragoon" else .45),id+" reaches forward through the strike")
		if id=="samurai":
			var sheath=model.model.find_child("SamuraiRedScabbard",true,false)
			var aim=(sheath.global_basis*model.WEAPON_AXES.samurai).normalized()
			check((sheath.global_position+aim*.22).distance_to(sk.global_transform*pose(sk,"Hand_L").origin)<.045,"samurai supports the sheath with his left hand while striking")
		elif id not in ["dragoon","magic-swordsman"]:
			check(pose(sk,"Hand_L").origin.z>hips.z+.13,id+" pulls the free arm behind the body")
		else:
			var weapon: Node3D=model.joints.Weapon_Cutlass.node
			var aim=(weapon.to_global(model.WEAPON_AXES[id])-weapon.global_position).normalized()
			var support=weapon.global_position-aim*.18
			check(support.distance_to(sk.global_transform*pose(sk,"Hand_L").origin)<.045,id+" keeps the support hand on the two-handed weapon grip")
		var length_error=0.0
		for side in ["L","R"]:
			for pair in [["Arm_","Forearm_"],["Forearm_","Hand_"],["Leg_","Shin_"],["Shin_","Foot_"]]:
				var a=pair[0]+side;var b=pair[1]+side
				length_error=maxf(length_error,absf(pose(sk,a).origin.distance_to(pose(sk,b).origin)-rest(sk,a).origin.distance_to(rest(sk,b).origin)))
		check(length_error<.015,id+" preserves original arm and leg lengths in its full-body pose")
		attack_pose(model,id,contact+.20)
		var head_after=(pose(sk,"Head").basis*rest(sk,"Head").basis.inverse()).get_euler().y
		check(absf(angle_difference(head_before,head_after))>.30,id+" swings its head with the body's follow-through")
		if id=="goemon":check_endpoints(model)
		elif id=="explorer":
			model.animate_pose({"grounded":true,"attack":{"primary":true,"index":1,"time":.15,"duration":.48,"contact":.15,"swingSide":-1}},0,0,0)
			check(pose(sk,"Arm_L").origin.z<pose(sk,"Arm_R").origin.z-.20 and pose(sk,"Foot_R").origin.z<pose(sk,"Foot_L").origin.z-.25,"Explorer mirrors shoulders and lead foot for the left-handed swing")
			check(model.joints.Weapon_Pistol.node.global_position.distance_to(sk.global_transform*pose(sk,"Hand_L").origin)<.02,"Explorer's alternate blade stays in the left hand")
		if not id.begins_with("goemon"):check_native_cycle(model,id,sk)
		model.free()
	for index in [1,2]:
		for profile in [PipeCombo,preload("res://scripts/goemon_rogue_combo.gd")]:
			var end=profile.sample(index,1.0 if profile==PipeCombo else profile.duration(index))
			var start=profile.sample(index+1,0)
			var continuous=true
			for channel in end:
				continuous=continuous and (end[channel].is_equal_approx(start[channel]) if end[channel] is Vector3 else is_equal_approx(end[channel],start[channel]))
			check(continuous,"every pose channel stays continuous across combo seam %d"%index)
	stage.free()
	print("GOEMON_FULL_BODY_STRIKE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
