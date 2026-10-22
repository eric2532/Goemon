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
func run():
	stage=Node3D.new();root.add_child(stage)
	var ground=StaticBody3D.new();stage.add_child(ground)
	var collider=CollisionShape3D.new();collider.shape=BoxShape3D.new();collider.shape.size=Vector3(100,.2,100);collider.position.y=-.1;ground.add_child(collider)
	await physics_frame
	var actor=Actor.new();stage.add_child(actor);actor.setup("ranger");actor.seed=0
	var sk: Skeleton3D=actor.cosplay_rig.skeleton
	for speed in [5.1,10.2,18.0]:
		for direction in [Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3(1,0,1).normalized()]:
			actor.reset_motion();var low=Vector3.INF;var high=-Vector3.INF
			var hands_low=[Vector3.INF,Vector3.INF];var hands_high=[-Vector3.INF,-Vector3.INF]
			var grip=0.0;var bow_turn=0.0;var prior_axis=Vector3.ZERO
			var foot_low=Vector3.INF;var foot_high=-Vector3.INF
			for frame in 180:
				actor.animate_pose({"grounded":true,"motionSpeed":speed,"localMotion":direction*speed},1.0/60,frame/60.0,1)
				if frame<60:continue
				var chest=bone(sk,"Chest");var angles=(chest.basis*sk.get_bone_global_rest(sk.find_bone("Chest")).basis.inverse()).get_euler()
				low=low.min(angles);high=high.max(angles)
				for i in 2:
					var h=chest.affine_inverse()*bone(sk,"Hand_"+(["R","L"][i])).origin
					hands_low[i]=hands_low[i].min(h);hands_high[i]=hands_high[i].max(h)
				var bow: Node3D=actor.joints.Weapon_Cutlass.node
				grip=maxf(grip,bow.global_position.distance_to(sk.global_transform*bone(sk,"Hand_R").origin))
				var axis=(bow.global_basis*Vector3.UP).normalized()
				if prior_axis.length_squared()>.5:bow_turn=maxf(bow_turn,prior_axis.angle_to(axis))
				prior_axis=axis
				var foot=bone(sk,"Foot_R").origin
				foot_low=foot_low.min(foot);foot_high=foot_high.max(foot)
			var label_="Ranger speed=%.1f direction=%s"%[speed,str(direction)]
			print("RANGER_CARRY ",label_," chest=",high-low," hand_motion=",hands_high[0]-hands_low[0]," / ",hands_high[1]-hands_low[1]," grip=",grip)
			check((high-low).y<.002 and (high-low).z<.002,label_+" has no periodic torso swing")
			check((hands_high[0]-hands_low[0]).length()<.025 and (hands_high[1]-hands_low[1]).length()<.025,label_+" holds both arms ready instead of pumping them")
			check(grip<.025 and bow_turn<.003,label_+" keeps the actual bow gripped and stable")
			# Sideways/backward native steps need not differ in height, but their
			# feet still travel through the original three-dimensional stride.
			check((foot_high-foot_low).length()>.15,label_+" keeps stepping with the legs")
	actor.free();stage.free();await create_timer(.2).timeout
	print("RANGER_CARRY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
