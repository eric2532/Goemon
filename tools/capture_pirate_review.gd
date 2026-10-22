extends SceneTree
## Read-only production pose capture for Blender review copies.
const Actor=preload("res://assets/rogue/scripts/actor.gd")
var actor
var skeleton: Skeleton3D
var initial_inverse: Transform3D
var output={"fps":60,"character":"pirate","bones":[],"clips":[]}

func _initialize():call_deferred("capture")

func state():
	return {"isPlayer":true,"grounded":true,"vertical":0.0,"motionSpeed":0.0,"localMotion":Vector3.ZERO,"attack":null,"travel":null,"roll":0.0,"flip":-1.0,"blocking":false,"charging":false,"shot":0.0,"drinkGesture":0.0,"guardTime":0.0}

func matrix(t: Transform3D):
	return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0,0,0,1]]

func reset_actor():
	if actor!=null:actor.free()
	actor=Actor.new();root.add_child(actor);actor.setup("pirate");actor.seed=0
	skeleton=actor.cosplay_rig.skeleton
	initial_inverse=skeleton.global_transform.affine_inverse()
	actor.reset_motion()

func sample(s: Dictionary,t: float):
	actor.animate_pose(s,1.0/60,t,0.0)
	var transforms=[]
	for i in range(skeleton.get_bone_count()):
		var p=initial_inverse*skeleton.global_transform*skeleton.get_bone_global_pose(i)
		var rest=skeleton.get_bone_global_rest(i)
		transforms.append({"position":[p.origin.x,p.origin.y,p.origin.z],"delta":matrix(Transform3D(p.basis*rest.basis.inverse(),Vector3.ZERO))})
	return {"bones":transforms,"right":matrix(initial_inverse*actor.joints.Weapon_Cutlass.node.global_transform),"left":matrix(initial_inverse*actor.joints.Weapon_Pistol.node.global_transform)}

func capture():
	reset_actor()
	for i in range(skeleton.get_bone_count()):output.bones.append(skeleton.get_bone_name(i))
	for spec in [["02_Jump",90],["03_Gun_Shot",60],["04_Sword_Slash",48]]:
		reset_actor()
		var clip={"name":spec[0],"frames":[]}
		for f in range(spec[1]+1):
			var s=state()
			if spec[0]=="02_Jump":
				s.grounded=f<9 or f>=75
				s.vertical=0.0 if s.grounded else 10.7-19.6*(f-9)/60.0
			elif spec[0]=="03_Gun_Shot" and f>=12 and f<=28:
				s.shot=maxf(.0001,.28-(f-12)/60.0)
			elif spec[0]=="04_Sword_Slash" and f>=10 and f<=28:
				s.attack={"primary":true,"style":"cutlass","index":0,"duration":.29,"contact":.075,"time":minf(.29,(f-10)/60.0),"weapon":"cutlass"}
			clip.frames.append(sample(s,f/60.0))
		output.clips.append(clip)
	var file=FileAccess.open("res://build/Other Files/Pirate Weapons/game-motion-samples.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output))
	print("PIRATE_REVIEW_CAPTURE_OK clips=",output.clips.size()," bones=",output.bones.size())
	actor.free();quit()
