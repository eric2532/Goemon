extends RefCounted
## Shared source pose geometry for fitted contacts and offline comparisons.
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const HEIGHTS=Roles.HEIGHTS
const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
static func walking_foot_offset(phase: float,stride: float,lift: float)->Vector3:
	var cycle=fposmod(phase,TAU)/TAU
	if cycle<.5:return Vector3(0,0,(cycle-.25)*stride)
	var swing=(cycle-.5)*2.0;var eased=swing*swing*(3.0-2.0*swing)
	return Vector3(0,sin(swing*PI)*lift,(.25-.5*eased)*stride)

static func _fist_contact(kind: int,left: bool)->Vector3:
	if kind==2:return Vector3(-10.637 if left else 10.637,6.0,-4.20)
	if kind==0:return Vector3(-1.05 if left else 1.05,2.0,-.75)
	return Vector3(-1.0 if left else 1.0,1.6,-.5)

static func part_pose(group: String,data: Dictionary)->Transform3D:
	if Soldier.supports(int(data.variant)):return Transform3D.IDENTITY
	if int(data.get("variant",0))==Roles.BOSS:return Transform3D.IDENTITY
	if data.get("frozen",0.0)>0 and data.has("frozen_pose"):data=data.frozen_pose
	if group in ["foot_l","foot_r"] and data.get("walk_feet",{}).has(group):return data.walk_feet[group]
	var kind=clampi(int(data.get("variant",0)),0,3)
	var phase=float(data.get("walk_phase",0.0))
	var progress=float(data.get("attack_progress",0.0))
	var action=str(data.get("action","walk"))
	var moving=1.0 if absf(phase)>.00001 else 0.0
	if data.has("velocity"):
		var velocity: Vector3=data.velocity
		moving=clampf(Vector2(velocity.x,velocity.z).length()/float(Roles.DATA[kind].speed),0,1)
	var motion=float(data.get("pose_motion",moving))
	var recoil=float(data.get("hit_recoil",0.0))
	if recoil>0:motion=0.0
	if action=="windup":motion*=1.0-smoothstep(0.0,.2,maxf(0,progress))
	elif action=="recover":motion=0.0
	# Zero motion leaves these parts at their exact authored rest transform.
	# Anchored feet and frozen poses were handled above; recoil and bow draws
	# still pass through their full evaluation below.
	if motion==0.0 and (recoil<=0.0 or kind==2):
		if group in ["body","foot_l","foot_r"] or kind==3 or absf(progress)<=.00001:return Transform3D.IDENTITY
	var pose=Transform3D.IDENTITY
	var giant=kind==2
	if group=="foot_l" or group=="foot_r":
		var offset_phase=phase+(PI if group=="foot_r" else 0)
		pose.origin=walking_foot_offset(offset_phase,float(Roles.DATA[kind].stride),.7 if giant else (.6 if kind==3 else .26))*motion
		return pose
	if recoil>0 and not giant:
		# Tilt the body and carried weapon around the hips while the feet stay
		# grounded. Contact queries consume this exact same rigid transform.
		var direction: Vector3=Basis(Vector3.UP,float(data.get("facing",0))).inverse()*Vector3(data.get("hit_direction",Vector3.BACK))
		var axis=Vector3.UP.cross(direction)
		if axis.length_squared()>.001:
			var age=maxf(0,.28-recoil)
			var weight=sin(minf(1,age/.045)*PI*.5)*clampf(recoil/.28,0,1)
			var pivot=Vector3(0,HEIGHTS[kind]*.35,0)
			var basis=Basis(axis.normalized(),weight*(.27 if data.get("hit_heavy",false) else .18))
			return Transform3D(basis,pivot-basis*pivot+direction*weight*.08)
	var rock=sin(phase)*(.022 if giant else .018)*motion
	var pivot=Vector3(0,HEIGHTS[kind]*.35,0)
	pose.basis=Basis(Vector3.FORWARD,rock)
	pose.origin=pivot-pose.basis*pivot+Vector3(0,absf(sin(phase))*HEIGHTS[kind]*.003*motion,0)
	if kind==3:
		pose.origin.y+=absf(sin(phase))*.2*motion
		return pose
	if group=="body":return pose
	var left=group.ends_with("_l")
	var shoulder=Vector3((-8.5 if left else 8.5) if giant else (-.72 if left else .72),12.0 if giant else HEIGHTS[kind]*.59,0)
	var swing=-sin(phase+(0 if left else PI))*(.06 if giant else .24)*motion
	var rotation=Basis(Vector3.RIGHT,swing)
	var arm_pose=Transform3D(rotation,shoulder-rotation*shoulder)
	if kind==1 and absf(progress)>.00001:
		# Ranged contact remains at the worker; the hands draw the local bowstring.
		var draw=smoothstep(0,1,absf(progress))
		return Transform3D(Basis.IDENTITY,Vector3(.18,.75,-.75)*draw if left else Vector3(-1.3,.8,-.15)*draw)
	if not left and absf(progress)>.00001 and data.has("attack_point"):
		# Lift/retract through most of the windup, then drive to exact visible contact.
		var contact=_fist_contact(kind,false)
		var wind=clampf(progress,0,1)
		var extension=smoothstep(.62,1.0,wind) if progress>=0 else smoothstep(0,1,clampf(-progress,0,1))
		var local_target=Basis(Vector3.UP,float(data.get("facing",0))).inverse()*(Vector3(data.attack_point)-Vector3(data.get("pos",Vector3.ZERO)))
		var lift=sin(wind*PI)*(.9 if giant else .35)
		var delta=(local_target-contact)*extension+Vector3(0,lift,(1.0-extension)*sin(wind*PI)*(.7 if giant else .15))
		# Preserve painted fist geometry; only the short connecting arm extends.
		if group=="arm_r" and giant:
			var rest=contact-shoulder;var next=rest+delta
			var align=Basis(Quaternion(rest.normalized(),next.normalized()))
			var axis=rest.normalized();var stretch=next.length()/rest.length()
			var scale_along=Basis.IDENTITY
			scale_along.x+=axis*axis.x*(stretch-1);scale_along.y+=axis*axis.y*(stretch-1);scale_along.z+=axis*axis.z*(stretch-1)
			var basis=align*scale_along
			return Transform3D(basis,shoulder-basis*shoulder)
		arm_pose=Transform3D(Basis.IDENTITY,delta)
		return arm_pose
	return pose*arm_pose
