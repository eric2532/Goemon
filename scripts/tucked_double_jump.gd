extends RefCounted
## Approved tucked 360-degree second jump. Collision and combat own gameplay.
const SOURCE="res://assets/animations/tucked_double_jump.json"
static var data: Dictionary={}
var skeleton: Skeleton3D
var indices: Array[int]=[]
var frames: Array=[]
var grips: Dictionary={}
var active=false
var age=0.0
var previous_flip=-1.0
var last_frame=1.0
var bow_grip_basis=Basis.IDENTITY

func _init(sk: Skeleton3D):
	skeleton=sk
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	for name_ in data.bones:indices.append(sk.find_bone(name_))
	for sample in data.frames:
		var globals: Dictionary={};var locals: Dictionary={}
		for i in indices.size():
			var index=indices[i];var value=unpack(sample.bones[i])
			value.basis=value.basis*sk.get_bone_global_rest(index).basis;globals[index]=value
		for index in indices:
			var parent=sk.get_bone_parent(index)
			locals[index]=globals[parent].affine_inverse()*globals[index] if parent>=0 else globals[index]
		if frames.size()==8:
			var root=sk.find_bone("Root")
			var turn: Basis=globals[root].basis*sk.get_bone_global_rest(root).basis.inverse()
			# Bow stays upright at the outside hand instead of spanning the knees.
			bow_grip_basis=globals[sk.find_bone("Hand_R")].basis.inverse()*turn*Basis(Vector3.BACK,Vector3.UP,Vector3.LEFT)
		frames.append(locals)

func unpack(v: Array)->Transform3D:
	return Transform3D(Basis(Quaternion(v[3],v[4],v[5],v[6]).normalized()).scaled(Vector3(v[7],v[8],v[9])),Vector3(v[0],v[1],v[2]))

func reset():
	active=false;age=0;previous_flip=-1;last_frame=1;grips.clear()

func apply(actor,state: Dictionary,delta: float)->bool:
	var flip=float(state.get("flip",-1))
	var launch=flip>=0 and (previous_flip<0 or flip<previous_flip-.05)
	previous_flip=flip
	var busy=state.get("attack")!=null or state.get("blocking",false) or state.get("charging",false) or float(state.get("chargeTime",0))>0 or float(state.get("guardTime",0))>0 or float(state.get("shot",0))>0 or float(state.get("drinkGesture",0))>0 or float(state.get("roll",0))>0 or state.get("travel")!=null or state.get("dive")!=null or state.get("crouched",false)
	if bool(state.get("grounded",true)) or busy:
		active=false;return false
	if launch:
		active=true;age=0;grips.clear()
		for side in ["R","L"]:
			var weapon_name="Weapon_Cutlass" if side=="R" else "Weapon_Pistol"
			if not actor.joints.has(weapon_name):continue
			var hand=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Hand_"+side))
			grips[side]=unpack(data.frames[0].grips[side]) if actor.id=="explorer" else hand.affine_inverse()*actor.joints[weapon_name].node.global_transform
			if actor.id=="ranger" and side=="R":grips[side].basis=bow_grip_basis.scaled(grips[side].basis.get_scale())
	elif active:age+=maxf(0,delta)
	if not active:return false
	if age>=.94:active=false;return false
	last_frame=1+minf(.8,age)*60
	var t=clampf(last_frame-1,0,frames.size()-1);var a=int(t);var b=mini(a+1,frames.size()-1)
	var weight=smoothstep(0,.07,age)*(1-smoothstep(.8,.94,age))
	var old: Dictionary={};var target: Dictionary={};var old_grips: Dictionary={}
	for index in indices:old[index]=skeleton.get_bone_global_pose(index)
	for side in grips:
		var hand=skeleton.global_transform*old[skeleton.find_bone("Hand_"+side)]
		old_grips[side]=hand.affine_inverse()*actor.joints["Weapon_Cutlass" if side=="R" else "Weapon_Pistol"].node.global_transform
	actor.model.position=actor.model.position.lerp(Vector3.ZERO,weight)
	actor.model.quaternion=actor.model.quaternion.slerp(Quaternion.IDENTITY,weight)
	for index in indices:
		var parent=skeleton.get_bone_parent(index)
		var native: Transform3D=old[parent].affine_inverse()*old[index] if parent>=0 else old[index]
		var local: Transform3D=frames[a][index].interpolate_with(frames[b][index],t-a)
		local=native.interpolate_with(local,weight)
		target[index]=target[parent]*local if parent>=0 else local
	for index in indices:skeleton.set_bone_global_pose(index,target[index])
	for side in grips:
		var hand=skeleton.global_transform*target[skeleton.find_bone("Hand_"+side)]
		actor.joints["Weapon_Cutlass" if side=="R" else "Weapon_Pistol"].node.global_transform=hand*old_grips[side].interpolate_with(grips[side],weight)
	return true
