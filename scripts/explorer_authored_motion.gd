extends RefCounted
## Explorer's approved body poses and both blade grips. Physics owns travel.
const SOURCE="res://assets/animations/explorer_approved.json"
static var cached: Dictionary={}
var skeleton: Skeleton3D
var indices: Array[int]=[]
var clips: Dictionary={}
var idle_time=0.0
var air_age=0.0
var landing_age=100.0
var was_air=false
var previous_vertical=0.0
var previous_flip=-1.0
var last_clip=""
var last_frame=1.0

func _init(sk: Skeleton3D):
	skeleton=sk
	if cached.is_empty():cached=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	for name_ in cached.bones:indices.append(sk.find_bone(name_))
	for key in cached.clips:
		var frames: Array=[]
		var grips: Array=[]
		for sample in cached.clips[key].frames:
			var globals: Dictionary={}
			var locals: Array[Transform3D]=[]
			for b in indices.size():
				var value=unpack(sample.bones[b])
				value.basis=value.basis*sk.get_bone_global_rest(indices[b]).basis
				globals[indices[b]]=value
			for index in indices:
				var parent=sk.get_bone_parent(index)
				locals.append(globals[parent].affine_inverse()*globals[index] if parent>=0 else globals[index])
			frames.append(locals)
			grips.append({"right":globals[sk.find_bone("Hand_R")].affine_inverse()*unpack(sample.weapons.right),"left":globals[sk.find_bone("Hand_L")].affine_inverse()*unpack(sample.weapons.left)})
		clips[key]={"frames":frames,"grips":grips,"period":cached.clips[key].period_frames}

func unpack(v: Array)->Transform3D:
	return Transform3D(Basis(Quaternion(v[3],v[4],v[5],v[6]).normalized()).scaled(Vector3(v[7],v[8],v[9])),Vector3(v[0],v[1],v[2]))

func reset():
	idle_time=0;air_age=0;landing_age=100;was_air=false;previous_vertical=0;previous_flip=-1;last_clip="";last_frame=1

func apply(actor,state: Dictionary,delta: float)->bool:
	var dt=maxf(0,delta)
	var airborne=not bool(state.get("grounded",true))
	var vy=float(state.get("vertical",0))
	var flip=float(state.get("flip",-1))
	var second_launch=airborne and flip>=0 and (previous_flip<0 or flip<previous_flip-.05)
	if was_air and not airborne:landing_age=0
	else:landing_age+=dt
	if airborne and (not was_air or second_launch or vy>previous_vertical+3):air_age=0
	elif airborne:air_age+=dt
	was_air=airborne;previous_vertical=vy;previous_flip=flip
	idle_time=fposmod(idle_time+dt,3.6)
	var busy=state.get("attack")!=null or state.get("blocking",false) or state.get("charging",false) or float(state.get("chargeTime",0))>0 or float(state.get("guardTime",0))>0 or float(state.get("shot",0))>0 or float(state.get("drinkGesture",0))>0 or float(state.get("roll",0))>0 or state.get("travel")!=null or state.get("dive")!=null or state.get("crouched",false)
	if busy:
		landing_age=100;last_clip="";return false
	if airborne:
		last_clip="jump"
		last_frame=lerpf(1,22,smoothstep(0,.18,air_age)) if air_age<.18 else (43.0 if vy>=0 else 60.0)
		sample(actor,"jump",last_frame,1.0)
		return true
	var run_weight=smoothstep(.08,2.2,actor.locomotion.stride_speed)
	sample(actor,"idle",1+idle_time*60,1.0)
	var run_frame=1+fposmod(actor.locomotion.phase/TAU,1.0)*clips.run.period
	if run_weight>.001:sample(actor,"run",run_frame,run_weight)
	last_clip="run" if run_weight>.001 else "idle"
	last_frame=run_frame if run_weight>.001 else 1+idle_time*60
	if landing_age<.32:
		last_clip="jump"
		if landing_age<.08:last_frame=lerpf(60,76,smoothstep(0,.08,landing_age))
		elif landing_age<.14:last_frame=lerpf(76,80,(landing_age-.08)/.06)
		else:last_frame=lerpf(80,91,smoothstep(.14,.32,landing_age))
		var weight=1-smoothstep(.08,.28,landing_age)*run_weight
		sample(actor,"jump",last_frame,weight)
	return true

func sample(actor,key: String,frame: float,weight: float):
	if weight<.001:return
	var clip: Dictionary=clips[key]
	var t=clampf(frame-1,0,clip.frames.size()-1)
	var a=int(t);var b=mini(a+1,clip.frames.size()-1);var blend=t-a
	actor.model.position=actor.model.position.lerp(Vector3.ZERO,weight)
	actor.model.quaternion=actor.model.quaternion.slerp(Quaternion.IDENTITY,weight)
	var before: Dictionary={}
	var old_grips: Dictionary={}
	var posed: Dictionary={}
	for index in indices:before[index]=skeleton.get_bone_global_pose(index)
	for side in ["right","left"]:
		var hand=skeleton.find_bone("Hand_R" if side=="right" else "Hand_L")
		var weapon: Node3D=actor.joints["Weapon_Cutlass" if side=="right" else "Weapon_Pistol"].node
		old_grips[side]=(skeleton.global_transform*before[hand]).affine_inverse()*weapon.global_transform
	for i in indices.size():
		var index=indices[i];var parent=skeleton.get_bone_parent(index)
		var native: Transform3D=before[parent].affine_inverse()*before[index] if parent>=0 else before[index]
		var target: Transform3D=clip.frames[a][i].interpolate_with(clip.frames[b][i],blend)
		var local=native.interpolate_with(target,weight)
		posed[index]=posed[parent]*local if parent>=0 else local
	for index in indices:skeleton.set_bone_global_pose(index,posed[index])
	for side in ["right","left"]:
		var hand=skeleton.find_bone("Hand_R" if side=="right" else "Hand_L")
		var weapon: Node3D=actor.joints["Weapon_Cutlass" if side=="right" else "Weapon_Pistol"].node
		var target: Transform3D=old_grips[side] if actor.id=="ninja" else clip.grips[a][side].interpolate_with(clip.grips[b][side],blend)
		weapon.global_transform=skeleton.global_transform*posed[hand]*old_grips[side].interpolate_with(target,weight)
