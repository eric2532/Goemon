extends RefCounted
## Approved Pirate poses and hand-relative equipment; gameplay owns travel and contacts.
const SOURCE="res://assets/animations/pirate_approved.json"
const RECOVERY=.12
# fire_projectile() owns the live shot timer. Do not change projectile timing.
const SHOT_DURATION=.2
static var cached: Dictionary={}
var skeleton: Skeleton3D
var indices: Array[int]=[]
var clips: Dictionary={}
var air_age=0.0
var landing_age=100.0
var was_air=false
var previous_vertical=0.0
var last_clip=""
var last_frame=0.0
var action_clip=""
var action_frame=0.0
var recovery_age=RECOVERY

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
		clips[key]={"frames":frames,"grips":grips,"start":cached.clips[key].start_frame}

func unpack(v: Array)->Transform3D:
	return Transform3D(Basis(Quaternion(v[3],v[4],v[5],v[6]).normalized()).scaled(Vector3(v[7],v[8],v[9])),Vector3(v[0],v[1],v[2]))

func reset():
	air_age=0;landing_age=100;was_air=false;previous_vertical=0
	last_clip="";last_frame=0;action_clip="";action_frame=0;recovery_age=RECOVERY

static func native_action(state: Dictionary)->bool:
	return state.get("blocking",false) or state.get("charging",false) or float(state.get("chargeTime",0))>0 or float(state.get("guardTime",0))>0 or float(state.get("drinkGesture",0))>0 or float(state.get("roll",0))>0 or state.get("travel")!=null or state.get("dive")!=null or state.get("crouched",false)

func apply(actor,state: Dictionary,delta: float)->bool:
	var dt=maxf(0,delta)
	var airborne=not bool(state.get("grounded",true))
	var vy=float(state.get("vertical",0))
	if was_air and not airborne:landing_age=0
	else:landing_age+=dt
	if airborne and (not was_air or vy>previous_vertical+3):air_age=0
	elif airborne:air_age+=dt
	was_air=airborne;previous_vertical=vy
	if native_action(state):
		landing_age=100;last_clip="";action_clip="";recovery_age=RECOVERY;return false
	var attack=state.get("attack")
	if attack is Dictionary and attack.get("primary",false) and attack.get("style","") in ["sword","cutlass"]:
		var index=clampi(int(attack.get("index",0)),0,2)
		var start=float([0,16,32][index]);var contact=float([13,29,48][index]);var end=float([16,32,72][index])
		var at=clampf(float(attack.get("time",0)),0,float(attack.duration))
		var hit=clampf(float(attack.contact),.001,float(attack.duration)-.001)
		# Forest responsiveness can advance contact. Sample the same authored contact
		# at the actual attack timestamp, rather than shifting damage or weapon travel.
		last_frame=lerpf(start,contact,at/hit) if at<=hit else lerpf(contact,end,(at-hit)/(float(attack.duration)-hit))
		last_clip="slash";action_clip=last_clip;action_frame=last_frame;recovery_age=0
		sample(actor,last_clip,last_frame,1)
		var weapon: Node3D=actor.joints.Weapon_Cutlass.node
		weapon.global_basis=weapon.global_basis.scaled(Vector3.ONE*float(state.get("meleeVisualScale",1)))
		return true
	if float(state.get("shot",0))>0:
		last_clip="shot";last_frame=24*clampf(1-float(state.shot)/SHOT_DURATION,0,1)
		action_clip=last_clip;action_frame=last_frame;recovery_age=0
		sample(actor,last_clip,last_frame,1);return true
	if attack!=null:
		landing_age=100;last_clip="";action_clip="";recovery_age=RECOVERY;return false
	if airborne:
		last_clip="jump";action_clip="";recovery_age=RECOVERY
		last_frame=lerpf(1,22,smoothstep(0,.18,air_age)) if air_age<.18 else (43.0 if vy>=0 else 60.0)
		sample(actor,last_clip,last_frame,1);return true
	var idle_weight=1-smoothstep(.08,2.2,actor.locomotion.stride_speed)
	sample(actor,"idle",0,idle_weight)
	if idle_weight>.001:actor.cosplay_rig.apply_idle_breath(actor)
	last_clip="idle" if idle_weight>.001 else "";last_frame=0
	if landing_age<.32:
		last_clip="jump"
		if landing_age<.08:last_frame=lerpf(60,76,smoothstep(0,.08,landing_age))
		elif landing_age<.14:last_frame=lerpf(76,80,(landing_age-.08)/.06)
		else:last_frame=lerpf(80,91,smoothstep(.14,.32,landing_age))
		sample(actor,"jump",last_frame,1-smoothstep(.08,.28,landing_age)*(1-idle_weight))
	elif not action_clip.is_empty() and recovery_age<RECOVERY:
		recovery_age+=dt
		sample(actor,action_clip,action_frame,1-smoothstep(0,RECOVERY,recovery_age))
		last_clip="recovery";last_frame=action_frame
	return idle_weight>.001 or last_clip!=""

func sample(actor,key: String,frame: float,weight: float):
	if weight<.001:return
	var clip: Dictionary=clips[key]
	var t=clampf(frame-float(clip.start),0,clip.frames.size()-1)
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
		var target: Transform3D=clip.grips[a][side].interpolate_with(clip.grips[b][side],blend)
		weapon.global_transform=skeleton.global_transform*posed[hand]*old_grips[side].interpolate_with(target,weight)
