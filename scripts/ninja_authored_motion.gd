extends RefCounted
## User-authored idle and RMB endpoints. Combat physics owns dash travel/timing.
const SOURCE="res://assets/animations/ninja_approved.json"
const RECOVERY=.16
static var cached: Dictionary={}
var skeleton: Skeleton3D
var indices: Array[int]=[]
var clips: Dictionary={}
var idle_time=0.0
var was_dash=false
var recovery_age=RECOVERY
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
	idle_time=0;was_dash=false;recovery_age=RECOVERY;last_clip="";last_frame=1

func apply(actor,state: Dictionary,delta: float,shared_landing: bool=false)->bool:
	var dt=maxf(0,delta)
	idle_time=fposmod(idle_time+dt,3.6)
	var dash=state.get("dashAttack")
	var cutting=float(state.get("roll",0))>0 and state.get("rollStyle","")=="dash-cut" and dash is Dictionary
	if cutting:
		var duration=maxf(.001,float(state.get("rollDuration",.42)))
		var progress=clampf(1-float(state.roll)/duration,0,1)
		last_clip="slash";last_frame=1+smoothstep(0,1,progress)
		sample(actor,"slash",last_frame,1)
		was_dash=true;recovery_age=RECOVERY
		return true
	if was_dash:recovery_age=0;was_dash=false
	else:recovery_age+=dt
	var busy=state.get("attack")!=null or state.get("blocking",false) or state.get("charging",false) or float(state.get("chargeTime",0))>0 or float(state.get("guardTime",0))>0 or float(state.get("shot",0))>0 or float(state.get("drinkGesture",0))>0 or float(state.get("roll",0))>0 or state.get("travel")!=null or state.get("dive")!=null or state.get("crouched",false) or not bool(state.get("grounded",true)) or float(state.get("flip",-1))>=0 or shared_landing
	if busy:
		recovery_age=RECOVERY;last_clip="";return false
	var idle_weight=1-smoothstep(.08,2.2,actor.locomotion.stride_speed)
	last_clip="idle" if idle_weight>.001 else ""
	last_frame=1+idle_time*60
	sample(actor,"idle",last_frame,idle_weight)
	if recovery_age<RECOVERY:
		var amount=1-smoothstep(0,RECOVERY,recovery_age)
		sample(actor,"slash",2,amount)
		last_clip="recovery";last_frame=2
	return idle_weight>.001 or recovery_age<RECOVERY

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
		var target: Transform3D=clip.grips[a][side].interpolate_with(clip.grips[b][side],blend)
		weapon.global_transform=skeleton.global_transform*posed[hand]*old_grips[side].interpolate_with(target,weight)
