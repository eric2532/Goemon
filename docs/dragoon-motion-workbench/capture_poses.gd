extends SceneTree
const Actor = preload("res://assets/rogue/scripts/actor.gd")
var actor
var skeleton: Skeleton3D
var initial_inverse: Transform3D
var output = {"fps":60,"bones":[],"clips":[]}

func _initialize():
	call_deferred("capture_all")

func state():
	return {"isPlayer":true,"grounded":true,"vertical":0.0,"motionSpeed":0.0,"localMotion":Vector3.ZERO,"attack":null,"travel":null,"roll":0.0,"flip":-1.0,"blocking":false,"charging":false,"shot":0.0,"drinkGesture":0.0,"guardTime":0.0}

func matrix(t: Transform3D):
	return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0,0,0,1]]

func reset_actor():
	if actor != null: actor.free()
	actor=Actor.new();root.add_child(actor);actor.setup("dragoon");actor.seed=0.0
	skeleton=actor.cosplay_rig.skeleton
	initial_inverse=skeleton.global_transform.affine_inverse()
	actor.reset_motion()

func sample(pose_state: Dictionary, time: float, dt: float):
	actor.animate_pose(pose_state,dt,time,0.0)
	var transforms=[]
	for i in range(skeleton.get_bone_count()):
		var p=initial_inverse*skeleton.global_transform*skeleton.get_bone_global_pose(i)
		var rest=skeleton.get_bone_global_rest(i)
		transforms.append({"position":[p.origin.x,p.origin.y,p.origin.z],"delta":matrix(Transform3D(p.basis*rest.basis.inverse(),Vector3.ZERO))})
	return {"bones":transforms,"lance":matrix(initial_inverse*actor.joints.Weapon_Cutlass.node.global_transform)}

func capture_all():
	reset_actor()
	for i in range(skeleton.get_bone_count()):output.bones.append(skeleton.get_bone_name(i))
	for spec in [["01_Idle",216],["02_Jump",90],["03_Lance_Thrust_1",22],["04_Lance_Thrust_2",22],["05_Lance_Thrust_3",22],["06_Azure_Leap",44],["07_Azure_Plunge",44]]:
		reset_actor()
		var s=state()
		var clip={"name":spec[0],"frames":[],"markers":{}}
		if spec[0]=="01_Idle":
			actor.cosplay_rig.idle_breath.weight=1.0
			actor.cosplay_rig.idle_breath.phase=0.0
			clip.markers={"Breathe in":1,"Breathe out":109,"Loop":217}
		elif spec[0]=="02_Jump":clip.markers={"Ready":1,"Takeoff":10,"Apex":43,"Landing":76,"Settle":91}
		elif "Thrust" in spec[0]:clip.markers={"Windup":1,"Contact":7,"Recover":16,"End":23}
		else:clip.markers={"Launch" if "Leap" in spec[0] else "Drop":1,"Dive":25,"Impact":45}
		for f in range(spec[1]+1):
			var t=f/60.0
			if spec[0]=="02_Jump":
				s.grounded=f<9 or f>=75
				s.vertical=0.0 if s.grounded else 10.7-19.6*(f-9)/60.0
			elif "Thrust" in spec[0]:
				s.attack={"primary":true,"index":int(spec[0].substr(0,2))-3,"time":minf(t,.36),"duration":.36,"contact":.10,"style":"thrust"}
			elif "Azure" in spec[0]:
				s.grounded=false
				s.travel={"time":minf(t,.72),"duration":.72,"height":0.0,"kind":"lance-leap","phase":"drop" if "Plunge" in spec[0] else "arc"}
			clip.frames.append(sample(s,t,0.0 if f==0 else 1.0/60.0))
		if spec[0]=="01_Idle":clip.frames[-1]=clip.frames[0].duplicate(true)
		output.clips.append(clip)
	var file=FileAccess.open("res://docs/dragoon-motion-workbench/game_pose_samples.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output))
	print("DRAGOON_CAPTURE_OK clips=",output.clips.size()," bones=",output.bones.size())
	actor.free();quit()
