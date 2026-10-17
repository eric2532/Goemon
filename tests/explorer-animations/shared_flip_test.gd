extends SceneTree
## Catches missing shared flip, detached grips, stale flips, and combat overrides.
const Actor=preload("res://assets/rogue/scripts/actor.gd")
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label_: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label_)
func difference(a: Transform3D,b: Transform3D)->float:
	return maxf(a.origin.distance_to(b.origin),maxf((a.basis.x-b.basis.x).length(),maxf((a.basis.y-b.basis.y).length(),(a.basis.z-b.basis.z).length())))
func hand_grip(actor,side: String)->Transform3D:
	var sk: Skeleton3D=actor.cosplay_rig.skeleton
	return (sk.global_transform*sk.get_bone_global_pose(sk.find_bone("Hand_"+side))).affine_inverse()*actor.joints["Weapon_Cutlass" if side=="R" else "Weapon_Pistol"].node.global_transform
func run():
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/tucked_double_jump.json"))
	if "--packaged" in OS.get_cmdline_user_args():check(not FileAccess.file_exists("res://tools/export_tucked_double_jump.py"),"Shared flip runs from packaged resources")
	for id in ["ninja","ranger","explorer"]:
		var actor=Actor.new();root.add_child(actor);actor.setup(id);actor.seed=0
		actor.reset_motion()
		actor.animate_pose({"grounded":false,"vertical":8.0},.1,0)
		actor.animate_pose({"grounded":false,"vertical":7.0,"flip":0.0},1.0/60,0)
		for i in 21:actor.animate_pose({"grounded":false,"vertical":4.0,"flip":float(i+1)/60/.48},1.0/60,0)
		var sk: Skeleton3D=actor.cosplay_rig.skeleton;var index=sk.find_bone("Root")
		var turn=sk.get_bone_global_pose(index).basis*sk.get_bone_global_rest(index).basis.inverse()
		check((turn*Vector3.UP).dot(Vector3.UP)<-.95,id+" has the approved inverted body at half-turn")
		check(actor.model.position.length()<.001 and actor.model.quaternion.angle_to(Quaternion.IDENTITY)<.001,id+" has no duplicate legacy somersault")
		var motion=actor.cosplay_rig.get("double_jump")
		check(motion!=null,id+" has the shared double-jump clip")
		if motion==null:actor.free();continue
		check(motion.active,id+" keeps the tucked flip active")
		if id=="ranger":
			var bow: Node3D=actor.joints.Weapon_Cutlass.node
			var local_up=sk.global_basis.inverse()*bow.global_basis.y.normalized()
			check(local_up.dot((turn*Vector3.UP).normalized())>.95,"Ranger carries the bow upright beside the tucked body")
		var grips={"R":hand_grip(actor,"R")}
		if actor.joints.has("Weapon_Pistol"):grips.L=hand_grip(actor,"L")
		for i in 20:
			actor.animate_pose({"grounded":false,"vertical":-2.0,"flip":-1.0},1.0/60,0)
			for side in ["R","L"]:
				if actor.joints.has("Weapon_Cutlass" if side=="R" else "Weapon_Pistol"):
					check(difference(hand_grip(actor,side),grips[side])<.002,id+" "+side+" grip stays fixed through the turn")
		check(motion.active,id+" completes the preview after the old 0.48-second timer expires")
		for i in 30:actor.animate_pose({"grounded":false,"vertical":-8.0,"flip":-1.0},1.0/60,0)
		check(not motion.active,id+" opens back to ordinary airborne movement")
		actor.animate_pose({"grounded":false,"vertical":12.0,"flip":0.0},1.0/60,0)
		actor.animate_pose({"grounded":false,"vertical":8.0,"flip":.2,"shot":.2},.05,0)
		check(not motion.active,id+" yields to weapon actions")
		actor.animate_pose({"grounded":false,"vertical":6.0,"flip":.3},.05,0)
		check(not motion.active,id+" does not resume an interrupted flip mid-turn")
		actor.animate_pose({"grounded":false,"vertical":12.0,"flip":0.0},1.0/60,0)
		check(motion.active,id+" accepts a new launch after interruption")
		actor.animate_pose({"grounded":true,"vertical":0.0,"flip":.1},1.0/60,0)
		check(not motion.active,id+" ends the flip at actual floor contact")
		actor.reset_motion();check(not motion.active,id+" clears the flip on reset")
		actor.animate_pose({"grounded":false,"vertical":10.0,"flip":-1.0},1.0/60,0)
		check(not motion.active,id+" leaves the first jump unchanged")
		actor.reset_motion();actor.rotation.y=.65;actor.scale=Vector3.ONE*1.4
		actor.animate_pose({"grounded":false,"vertical":10.0},.1,0)
		var previous_angle=0.0;var total_turn=0.0
		for frame in range(1,50):
			actor.animate_pose({"grounded":false,"vertical":7.0,"flip":float(frame-1)/60/.48 if frame<=29 else -1.0},1.0/60,0)
			var actual=sk.get_bone_global_pose(index).basis*sk.get_bone_global_rest(index).basis.inverse()
			var angle=atan2(actual.y.z,actual.y.y);total_turn+=wrapf(angle-previous_angle,-PI,PI);previous_angle=angle
			if frame>=6:
				var worst=0.0
				for i in source.bones.size():
					var bone_index=sk.find_bone(source.bones[i]);var v: Array=source.frames[frame-1].bones[i]
					var expected=Transform3D(Basis(Quaternion(v[3],v[4],v[5],v[6])).scaled(Vector3(v[7],v[8],v[9])),Vector3(v[0],v[1],v[2]))
					expected.basis=expected.basis*sk.get_bone_global_rest(bone_index).basis
					worst=maxf(worst,difference(sk.get_bone_global_pose(bone_index),expected))
				check(worst<.002,id+" scaled/turned body matches Blender frame %d"%frame)
		check(absf(total_turn)>6.2 and absf(total_turn)<6.35,id+" completes exactly one full somersault")
		actor.free()
	print("SHARED_FLIP_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
