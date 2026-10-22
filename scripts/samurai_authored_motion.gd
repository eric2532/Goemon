extends RefCounted
## Approved two-handed katana poses, retimed to the native five damage contacts.
## Physics, hit tickets, cooldowns, bow and evasion remain owned by combat.
const SOURCE="res://assets/animations/samurai_approved.json"
const STARTS=[1,20,38,56,74]
const CONTACTS=[12,30,48,66,87]
const ENDS=[20,38,56,74,105]
const RECOVERY=.14
static var data: Dictionary={}
static var prepared: Dictionary={}
var skeleton: Skeleton3D
var indices: Array[int]=[]
var hand: int
var idle_time=0.0
var last_clip=""
var last_frame=1.0
var recovery_age=RECOVERY
var was_attacking=false
var recovery_frame=1.0
var scarf: Node3D
var scarf_rest: Transform3D
var hilt: Node3D
var blade_base: Vector3
var ready_pose: Dictionary={}
var ready_weapon: Transform3D
var entry_active=false
var support_grip: Transform3D

func _init(sk: Skeleton3D,model: Node3D):
	skeleton=sk;hand=sk.find_bone("Hand_R")
	scarf=model.find_child("ScarfTail",true,false)
	if scarf!=null:scarf_rest=sk.get_bone_global_rest(sk.find_bone("Head")).affine_inverse()*sk.global_transform.affine_inverse()*scarf.global_transform
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	hilt=model.find_child("Katana_Hilt",true,false)
	blade_base=Vector3(data.blade_base[0],data.blade_base[1],data.blade_base[2])
	for name_ in data.bones:indices.append(sk.find_bone(name_))
	var reference: Dictionary=data.clips.idle.frames[0]
	var left=unpack(reference.bones[data.bones.find("Hand_L")])
	left.basis*=sk.get_bone_global_rest(sk.find_bone("Hand_L")).basis
	support_grip=unpack(reference.weapon).affine_inverse()*left
	if not prepared.is_empty():return
	# All Samurai share the same original bind skeleton; decode the samples once.
	for key in data.clips:
		var frames: Array=[];var grips: Array=[]
		for sample_ in data.clips[key].frames:
			var globals: Dictionary={};var locals: Array[Transform3D]=[]
			for i in indices.size():
				var value=unpack(sample_.bones[i])
				value.basis*=sk.get_bone_global_rest(indices[i]).basis
				globals[indices[i]]=value
			for index in indices:
				var parent=sk.get_bone_parent(index)
				locals.append(globals[parent].affine_inverse()*globals[index] if parent>=0 else globals[index])
			frames.append(locals)
			grips.append(globals[hand].affine_inverse()*unpack(sample_.weapon))
		prepared[key]={"frames":frames,"grips":grips}

static func unpack(v: Array)->Transform3D:
	return Transform3D(Basis(Quaternion(v[3],v[4],v[5],v[6]).normalized()).scaled(Vector3(v[7],v[8],v[9])),Vector3(v[0],v[1],v[2]))

func reset():
	idle_time=0;last_clip="";last_frame=1;recovery_age=RECOVERY;was_attacking=false;recovery_frame=1
	ready_pose.clear();entry_active=false

func apply(actor,state: Dictionary,delta: float):
	var dt=maxf(0,delta)
	hilt.transform=Transform3D.IDENTITY
	idle_time=fposmod(idle_time+dt,2.0)
	var interrupt=float(state.get("roll",0))>0 or state.get("travel")!=null or state.get("dive")!=null or float(state.get("shot",0))>0 or float(state.get("drinkGesture",0))>0 or state.get("blocking",false) or state.get("charging",false) or state.get("crouched",false)
	if interrupt:
		if dt>0:was_attacking=false;recovery_age=RECOVERY;entry_active=false;ready_pose.clear()
		last_clip="";return
	var attack=state.get("attack")
	if attack is Dictionary and attack.get("primary",false):
		var stage=posmod(int(attack.index),5)
		var contact=maxf(.001,float(attack.contact));var duration=maxf(contact+.001,float(attack.duration))
		var t=clampf(float(attack.time),0,duration)
		var frame=lerpf(STARTS[stage],CONTACTS[stage],t/contact) if t<=contact else lerpf(CONTACTS[stage],ENDS[stage],(t-contact)/(duration-contact))
		if dt>0 and not was_attacking:entry_active=not ready_pose.is_empty()
		var entry=1.0
		if entry_active and t<contact*.5:
			for index in indices:skeleton.set_bone_global_pose(index,ready_pose[index])
			actor.model.transform=Transform3D.IDENTITY
			actor.joints.Weapon_Cutlass.node.global_transform=skeleton.global_transform*ready_weapon
			entry=smoothstep(0,contact*.5,t)
		elif dt>0:entry_active=false
		sample(actor,"combo",frame,entry)
		var amount=maxf(.01,float(state.get("meleeVisualScale",1.0)))
		var extension=Transform3D(Basis.from_scale(Vector3.ONE*amount),blade_base*(1-amount))
		actor.joints.Weapon_Cutlass.node.transform*=extension
		hilt.transform=extension.affine_inverse()
		fit_support(actor)
		last_clip="combo";last_frame=frame
		# Zero-delta reach/trail probes are pure pose queries, not animation time.
		if dt>0:was_attacking=true;recovery_frame=frame;recovery_age=RECOVERY
		return
	if attack!=null or not bool(state.get("grounded",true)) or float(state.get("flip",-1))>=0:
		if dt>0:was_attacking=false;recovery_age=RECOVERY;entry_active=false;ready_pose.clear()
		last_clip="";return
	if dt>0:
		if was_attacking:recovery_age=0;was_attacking=false
		else:recovery_age+=dt
	last_clip="idle";last_frame=1+idle_time*30
	sample(actor,"idle",last_frame,1)
	var run_weight=smoothstep(.08,2.2,actor.locomotion.stride_speed)
	if run_weight>.001:
		last_clip="run";last_frame=1+fposmod(actor.locomotion.phase/TAU,1.0)*24
		sample(actor,"run",last_frame,run_weight)
	if recovery_age<RECOVERY:
		sample(actor,"combo",recovery_frame,1-smoothstep(0,RECOVERY,recovery_age))
		last_clip="recovery"
	fit_support(actor)
	if dt>0 or ready_pose.is_empty():
		for index in indices:ready_pose[index]=skeleton.get_bone_global_pose(index)
		ready_weapon=skeleton.global_transform.affine_inverse()*actor.joints.Weapon_Cutlass.node.global_transform

func fit_support(actor):
	# FK crossfades curve each arm independently. Refit only when the support
	# wrist leaves the final hilt; untouched full-weight Blender poses stay exact.
	var target=skeleton.global_transform.affine_inverse()*hilt.global_transform*support_grip
	var index=skeleton.find_bone("Hand_L")
	if skeleton.get_bone_global_pose(index).origin.distance_to(target.origin)<.001:return
	actor.cosplay_rig.solve_arm("L",target.origin)
	var hand_pose=skeleton.get_bone_global_pose(index);hand_pose.basis=target.basis
	skeleton.set_bone_global_pose(index,hand_pose)

func sync_scarf():
	if scarf!=null:scarf.global_transform=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Head"))*scarf_rest

func sample(actor,key: String,frame: float,weight: float):
	if weight<.001:return
	var clip: Dictionary=prepared[key]
	var t=clampf(frame-1,0,clip.frames.size()-1)
	var a=int(t);var b=mini(a+1,clip.frames.size()-1);var blend=t-a
	actor.model.position=actor.model.position.lerp(Vector3.ZERO,weight)
	actor.model.quaternion=actor.model.quaternion.slerp(Quaternion.IDENTITY,weight)
	var before: Dictionary={};var posed: Dictionary={}
	for index in indices:before[index]=skeleton.get_bone_global_pose(index)
	var weapon: Node3D=actor.joints.Weapon_Cutlass.node
	var old_grip=(skeleton.global_transform*before[hand]).affine_inverse()*weapon.global_transform
	for i in indices.size():
		var index=indices[i];var parent=skeleton.get_bone_parent(index)
		var native: Transform3D=before[parent].affine_inverse()*before[index] if parent>=0 else before[index]
		var target: Transform3D=clip.frames[a][i].interpolate_with(clip.frames[b][i],blend)
		var local=native.interpolate_with(target,weight)
		posed[index]=posed[parent]*local if parent>=0 else local
	for index in indices:skeleton.set_bone_global_pose(index,posed[index])
	var grip: Transform3D=clip.grips[a].interpolate_with(clip.grips[b],blend)
	weapon.global_transform=skeleton.global_transform*posed[hand]*old_grip.interpolate_with(grip,weight)
