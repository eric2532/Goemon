extends SceneTree
## Catch omitted classes, overrides of the shared pose, or changed exceptions.
const Actor=preload("res://assets/rogue/scripts/actor.gd")
const Baseline=preload("res://scripts/user_stride_exclusion_fixture.gd")
## Explorer now has a dedicated approved run, covered by explorer-animations.
const SHARED=["pirate","ninja","mage","dragoon","ranger","master-thief"]
var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/goemon_edo_run.json"))
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func state_for(speed: float)->Dictionary:return {"grounded":true,"motionSpeed":speed,"localMotion":Vector3.BACK*speed}
func run():
	for id in SHARED:
		var actor=Actor.new();root.add_child(actor);actor.setup(id);actor.seed=0
		var sk: Skeleton3D=actor.cosplay_rig.skeleton
		for speed in [10.2,18.0]:
			var state=state_for(speed)
			for frame in range(120):actor.animate_pose(state,1.0/60,frame/60.0,1)
			for frame in range(61):
				actor.locomotion.phase=float(frame)/60*TAU
				actor.animate_pose(state,0,.75,1)
				var error=0.0
				for b in range(source.bones.size()):
					var index=sk.find_bone(source.bones[b]);var v: Array=source.frames[frame][b]
					var expected=Vector3(v[0],v[1]+source.floor_offset,v[2])
					var actual=sk.get_bone_global_pose(index)
					error=maxf(error,actual.origin.distance_to(expected))
					var rotation=Basis(Quaternion(v[3],v[4],v[5],v[6]).normalized())*sk.get_bone_global_rest(index).basis
					error=maxf(error,actual.basis.get_rotation_quaternion().angle_to(rotation.get_rotation_quaternion()))
				check(error<.003,"%s speed %s matches shared Blender frame %s (error %s)"%[id,speed,frame,error])
				check(actor.model.position.length()<.001 and actor.model.rotation.length()<.001,id+" has no extra class bounce or tilt over the shared run")
			# All bodies must advance at the same full left/right cadence.
			var before: float=actor.locomotion.phase
			actor.animate_pose(state,1.0/60,0,1)
			var want_rate=1.5 if speed==10.2 else 1.9
			check(absf((actor.locomotion.phase-before)/TAU*60-want_rate)<.0001,id+" shares the approved cadence")
		for slow in [[0.0,0.0],[.5,.25],[1.0,.5],[2.2,1.1]]:
			actor.reset_motion()
			actor.animate_pose(state_for(slow[0]),1.0/60,0,0)
			check(absf(actor.locomotion.phase/TAU*60-slow[1])<.0001,id+" preserves idle/slow-walk cadence at speed %s"%slow[0])
		actor.animate_pose({"grounded":true,"attack":{"primary":true,"index":0,"time":.15,"duration":.48,"contact":.15}},1.0/60,0,0)
		check(sk.get_bone_global_pose(sk.find_bone("Hand_R")).is_finite(),id+" keeps its native attack available")
		actor.free()
	# Captured before this rollout: all 22 bones, four moments, both speeds.
	for id in Baseline.POSES:
		var sample=0
		for speed in [10.2,18.0]:
			var actor=Actor.new();root.add_child(actor);actor.setup(id);actor.seed=0
			for frame in range(120):
				actor.animate_pose(state_for(speed),1.0/60,frame/60.0,1)
				if frame in [60,75,90,105]:
					var error=0.0
					for bone in range(actor.cosplay_rig.skeleton.get_bone_count()):
						var t=actor.cosplay_rig.skeleton.get_bone_global_pose(bone)
						var actual=[t.origin.x,t.origin.y,t.origin.z,t.basis.x.x,t.basis.x.y,t.basis.x.z,t.basis.y.x,t.basis.y.y,t.basis.y.z,t.basis.z.x,t.basis.z.y,t.basis.z.z]
						var expected: Array=Baseline.POSES[id][sample][bone]
						for i in range(actual.size()):error=maxf(error,absf(actual[i]-expected[i]))
					check(error<.00001,id+" keeps its previous pose at speed %s frame %s"%[speed,frame])
					sample+=1
			actor.free()
	print("USER_STRIDE_ROSTER_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
