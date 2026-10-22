extends SceneTree
## Capture the current production Ninja without changing game assets.
const Actor = preload("res://assets/rogue/scripts/actor.gd")
var actor
var skeleton: Skeleton3D
var initial_inverse: Transform3D
var output = {"fps":60,"character":"ninja","bones":[],"clips":[]}

func _initialize():call_deferred("capture_all")

func state():
	return {"isPlayer":true,"grounded":true,"vertical":0.0,"motionSpeed":0.0,"localMotion":Vector3.ZERO,"attack":null,"travel":null,"roll":0.0,"flip":-1.0,"blocking":false,"charging":false,"shot":0.0,"drinkGesture":0.0,"guardTime":0.0}

func matrix(t: Transform3D):
	return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0,0,0,1]]

func reset_actor():
	if actor != null:actor.free()
	actor=Actor.new();root.add_child(actor);actor.setup("ninja");actor.seed=0.0
	skeleton=actor.cosplay_rig.skeleton
	initial_inverse=skeleton.global_transform.affine_inverse()
	actor.reset_motion()

func sample(s: Dictionary,t: float,dt: float):
	actor.animate_pose(s,dt,t,0.0)
	var transforms=[]
	for i in range(skeleton.get_bone_count()):
		var p=initial_inverse*skeleton.global_transform*skeleton.get_bone_global_pose(i)
		var rest=skeleton.get_bone_global_rest(i)
		transforms.append({"position":[p.origin.x,p.origin.y,p.origin.z],"delta":matrix(Transform3D(p.basis*rest.basis.inverse(),Vector3.ZERO))})
	return {"bones":transforms,"right_blade":matrix(initial_inverse*actor.joints.Weapon_Cutlass.node.global_transform),"left_blade":matrix(initial_inverse*actor.joints.Weapon_Pistol.node.global_transform)}

func unpack_matrix(a: Array)->Transform3D:
	return Transform3D(Basis(Vector3(a[0][0],a[1][0],a[2][0]),Vector3(a[0][1],a[1][1],a[2][1]),Vector3(a[0][2],a[1][2],a[2][2])),Vector3(a[0][3],a[1][3],a[2][3]))

func blend_pose(a: Dictionary,b: Dictionary,t: float)->Dictionary:
	var result=a.duplicate(true)
	for i in range(result.bones.size()):
		var av=a.bones[i];var bv=b.bones[i]
		result.bones[i].position=[lerpf(av.position[0],bv.position[0],t),lerpf(av.position[1],bv.position[1],t),lerpf(av.position[2],bv.position[2],t)]
		result.bones[i].delta=matrix(unpack_matrix(av.delta).interpolate_with(unpack_matrix(bv.delta),t))
	for key in ["right_blade","left_blade"]:result[key]=matrix(unpack_matrix(a[key]).interpolate_with(unpack_matrix(b[key]),t))
	return result

func capture_all():
	reset_actor()
	for i in range(skeleton.get_bone_count()):output.bones.append(skeleton.get_bone_name(i))
	for spec in [["01_Idle",216],["02_Run",40],["03_Cross_Slash_RMB",36]]:
		reset_actor()
		var s=state()
		var clip={"name":spec[0],"frames":[],"markers":{}}
		if spec[0]=="01_Idle":
			actor.cosplay_rig.idle_breath.weight=1.0
			actor.cosplay_rig.idle_breath.phase=0.0
			clip.markers={"Start":1,"Breathe in":55,"Breathe out":163,"Loop":217}
		elif spec[0]=="02_Run":
			s.motionSpeed=10.2;s.localMotion=Vector3.BACK*10.2
			for warmup in 180:sample(s,warmup/60.0,1.0/60.0)
			actor.locomotion.phase=0.0
			clip.markers={"Stride A":1,"Passing A":11,"Stride B":21,"Passing B":31,"Loop":41}
		else:
			clip.markers={"Ready":1,"Windup":6,"Cut":10,"Follow through":18,"End dash":26,"Recover":37}
		var idle=sample(state(),0.0,0.0)
		var last_cut={}
		for f in range(spec[1]+1):
			var t=f/60.0
			if spec[0]=="03_Cross_Slash_RMB":
				s.rollDuration=.42;s.rollStyle="dash-cut";s.roll=maxf(.0001,.42-t);s.rollDir=Vector3.BACK
				s.dashAttack={"style":"dash-cut","weaponScale":1.0}
				if f<=25:
					last_cut=sample(s,t,0.0 if f==0 else 1.0/60.0)
					clip.frames.append(last_cut)
				else:
					clip.frames.append(blend_pose(last_cut,idle,smoothstep(0.0,1.0,(f-25)/11.0)))
			else:
				clip.frames.append(sample(s,t,0.0 if f==0 else 1.0/60.0))
		if spec[0] in ["01_Idle","02_Run"]:clip.frames[-1]=clip.frames[0].duplicate(true)
		output.clips.append(clip)
	var file=FileAccess.open("res://docs/ninja-motion-workbench/game_pose_samples.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output))
	print("NINJA_CAPTURE_OK clips=",output.clips.size()," bones=",output.bones.size())
	actor.free();quit()
