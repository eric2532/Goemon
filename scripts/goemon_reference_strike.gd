extends RefCounted
## Shared full-body strike in Goemon's local frame: forward is -Z.
## Sampled from attack time, so contact probes never advance animation state.
const Body=preload("res://scripts/goemon_reference_run_body.gd")
const REST={"hip":Vector3.ZERO,"chest":Vector3.ZERO,"offset":Vector3.ZERO,"wrist":Vector3(.55,.78,-.12),"guard":Vector3.ZERO,"roll":0.0,"aim":Vector3(0,0,-1),"head":Vector3.ZERO,"offhand":Vector3(-.55,.78,-.12),"left_foot":Vector3.ZERO,"right_foot":Vector3.ZERO,"left_heel":0.0,"right_heel":0.0,"weight":0.0}
const WIND={"hip":Vector3(.03,-.26,.035),"chest":Vector3(.08,-.42,.04),"offset":Vector3(.015,-.07,.025),"wrist":Vector3(.75,1.65,.24),"aim":Vector3(.90,.35,.52),"head":Vector3(-.02,.08,-.025),"offhand":Vector3(-.50,1.10,-.32),"left_foot":Vector3(-.02,.08,-.16),"right_foot":Vector3(.025,0,.10),"weight":1.0}
const CONTACT={"hip":Vector3(-.13,.19,-.09),"chest":Vector3(-.37,.48,-.09),"offset":Vector3(.055,-.15,-.14),"wrist":Vector3(.38,1.02,-.84),"aim":Vector3(-.10,-.06,-1),"head":Vector3(.06,-.04,.025),"offhand":Vector3(-.55,1.12,.39),"left_foot":Vector3(-.025,0,-.36),"right_foot":Vector3(.035,.10,.25),"right_heel":-.24,"weight":1.0}
const FOLLOW={"hip":Vector3(-.10,.42,-.07),"chest":Vector3(-.27,.80,-.10),"offset":Vector3(.035,-.12,-.17),"wrist":Vector3(-.48,.95,-.62),"aim":Vector3(-1,-.10,.03),"head":Vector3(.08,.18,.025),"offhand":Vector3(-.46,1.23,.43),"left_foot":Vector3(-.025,0,-.36),"right_foot":Vector3(.035,.12,.26),"right_heel":-.28,"weight":1.0}

static func key(stage: int,part: String)->Dictionary:
	var p=REST.duplicate();p.merge({"wind":WIND,"contact":CONTACT,"follow":FOLLOW}[part],true)
	if stage==2:
		if part=="wind":
			p.hip.y=.40;p.chest.y=.60;p.wrist=Vector3(-.56,1.44,-.20);p.aim=Vector3(-.99,.18,.10)
		elif part=="contact":p.wrist=Vector3(.26,1.08,-.87);p.aim=Vector3(.08,-.04,-1)
		else:p.hip.y=-.05;p.chest.y=-.30;p.head.y=-.16;p.wrist=Vector3(.80,1.05,-.32);p.aim=Vector3(.99,-.08,.04)
	elif stage>=3:
		if part=="wind":p.wrist=Vector3(.52,1.85,.18);p.aim=Vector3(.38,.86,.34)
		elif part=="contact":p.chest.x=-.42;p.offset.y=-.18;p.wrist=Vector3(.36,.98,-.88);p.aim=Vector3(.10,-.22,-1)
		else:p.chest.y=.90;p.wrist=Vector3(-.47,.84,-.60);p.aim=Vector3(-.99,-.25,.02)
	return p

static func blend(a: Dictionary,b: Dictionary,t: float)->Dictionary:
	var p={}
	for k in a:p[k]=lerp(a[k],b[k],t)
	return p

static func sample(stage: int,t: float,contact: float)->Dictionary:
	t=clampf(t,0,1);contact=clampf(contact,.05,.8)
	var wind_end=contact*.52;var follow_end=contact+minf(.27,(1-contact)*.43)
	if t<wind_end:return blend(REST,key(stage,"wind"),smoothstep(0,wind_end,t))
	if t<contact:return blend(key(stage,"wind"),key(stage,"contact"),pow(inverse_lerp(wind_end,contact,t),2))
	if t<follow_end:return blend(key(stage,"contact"),key(stage,"follow"),1-pow(1-inverse_lerp(contact,follow_end,t),2))
	return blend(key(stage,"follow"),REST,smoothstep(follow_end,1,t))

static func mirrored(p: Dictionary)->Dictionary:
	p=p.duplicate()
	for k in ["hip","chest","head"]:p[k]=Vector3(p[k].x,-p[k].y,-p[k].z)
	for k in ["offset","wrist","offhand","aim"]:p[k].x=-p[k].x
	var left: Vector3=p.left_foot;p.left_foot=p.right_foot;p.right_foot=left
	p.left_foot.x=-p.left_foot.x;p.right_foot.x=-p.right_foot.x
	var heel: float=p.left_heel;p.left_heel=p.right_heel;p.right_heel=heel
	return p

static func pose(sk: Skeleton3D,name_: String)->Transform3D:
	return sk.get_bone_global_pose(sk.find_bone(name_))
static func rest(sk: Skeleton3D,name_: String)->Transform3D:
	return sk.get_bone_global_rest(sk.find_bone(name_))
static func set_pose(sk: Skeleton3D,name_: String,p: Transform3D):
	sk.set_bone_global_pose(sk.find_bone(name_),p)

static func write_chain(sk: Skeleton3D,names: Array,before: Array,after: Array,weight: float):
	# Blend in the connected hierarchy so recovery keeps its incoming knee/elbow
	# bend and foot tilt, without shortening the original limb segments.
	var blended=before[0].interpolate_with(after[0],weight)
	set_pose(sk,names[0],blended)
	for i in range(1,names.size()):
		var from: Transform3D=before[i-1].affine_inverse()*before[i]
		var to: Transform3D=after[i-1].affine_inverse()*after[i]
		var local=from.interpolate_with(to,weight)
		local.origin=Body.direction_blend(from.origin.normalized(),to.origin.normalized(),weight)*lerpf(from.origin.length(),to.origin.length(),weight)
		blended=blended*local;set_pose(sk,names[i],blended)

static func two_hand_target(sk: Skeleton3D,target: Vector3,aim: Vector3)->Vector3:
	# Keep the hilt inside both arms' reach. Turning the left shoulder back must
	# not pull its supporting hand off a two-handed sword or lance.
	for repeat in range(8):
		for side in ["R","L"]:
			var shoulder=pose(sk,"Arm_"+side).origin
			var length=shoulder.distance_to(pose(sk,"Forearm_"+side).origin)+pose(sk,"Forearm_"+side).origin.distance_to(pose(sk,"Hand_"+side).origin)
			var offset=-aim.normalized()*.18 if side=="L" else Vector3.ZERO
			var ray=target+offset-shoulder
			if ray.length()>length*.94:target=shoulder+ray.normalized()*length*.94-offset
	return target

static func arm(sk: Skeleton3D,side: String,target: Vector3,weight: float):
	if weight<=0:return
	var upper=pose(sk,"Arm_"+side);var lower=pose(sk,"Forearm_"+side);var hand=pose(sk,"Hand_"+side)
	var before=[upper,lower,hand]
	var a=upper.origin.distance_to(lower.origin);var b=lower.origin.distance_to(hand.origin)
	var ray=target-upper.origin;var axis=ray.normalized()
	var distance=clampf(ray.length(),.08,(a+b)*.96)
	var pole=Vector3(.8 if side=="R" else -.8,-.6,.25);pole=(pole-axis*pole.dot(axis)).normalized()
	var along=(a*a-b*b+distance*distance)/(2*distance)
	var elbow=upper.origin+axis*along+pole*sqrt(maxf(0,a*a-along*along));var wrist=upper.origin+axis*distance
	var turn=Basis(Quaternion((hand.origin-lower.origin).normalized(),(wrist-elbow).normalized()))
	upper.basis=Basis(Quaternion((lower.origin-upper.origin).normalized(),(elbow-upper.origin).normalized()))*upper.basis
	lower.basis=turn*lower.basis;hand.basis=turn*hand.basis;lower.origin=elbow;hand.origin=wrist
	write_chain(sk,["Arm_"+side,"Forearm_"+side,"Hand_"+side],before,[upper,lower,hand],weight)

static func feet(sk: Skeleton3D,p: Dictionary,grounded: bool):
	if p.weight<=0:return
	# Resolve the stepped stance after locomotion IK, around real support surfaces.
	# The rear heel rises around its toe; original leg lengths are retained.
	for side in ["L","R"]:
		var before=[pose(sk,"Leg_"+side),pose(sk,"Shin_"+side),pose(sk,"Foot_"+side)]
		var foot=rest(sk,"Foot_"+side);var delta: Vector3=p.left_foot if side=="L" else p.right_foot
		var goal=foot.origin+delta
		if grounded:
			var world=sk.global_transform*goal
			var hit=sk.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(world+Vector3.UP*.72,world-Vector3.UP*1.05,1))
			if not hit.is_empty() and hit.normal.y>.6:
				world.y=hit.position.y+(foot.origin.y+delta.y)*sk.global_basis.get_scale().y
				goal=sk.global_transform.affine_inverse()*world
		var hip=pose(sk,"Leg_"+side).origin;var knee0=rest(sk,"Shin_"+side).origin;var hip0=rest(sk,"Leg_"+side).origin
		var a=hip0.distance_to(knee0);var b=knee0.distance_to(foot.origin)
		var ray=goal-hip;var distance=clampf(ray.length(),.08,(a+b)*.998);var axis=ray.normalized()
		var frame=Basis(Vector3.UP,p.hip.y*.35);var pole=frame*Vector3.FORWARD
		pole=(pole-axis*pole.dot(axis)).normalized()
		var along=(a*a-b*b+distance*distance)/(2*distance)
		var knee=hip+axis*along+pole*sqrt(maxf(0,a*a-along*along));var ankle=hip+axis*distance
		var upper=Transform3D(Basis(Quaternion((knee0-hip0).normalized(),(knee-hip).normalized()))*rest(sk,"Leg_"+side).basis,hip)
		var lower=Transform3D(Basis(Quaternion((foot.origin-knee0).normalized(),(ankle-knee).normalized()))*rest(sk,"Shin_"+side).basis,knee)
		var heel: float=p.left_heel if side=="L" else p.right_heel
		var sole=Transform3D(frame*Basis(Vector3.RIGHT,heel)*foot.basis,ankle)
		write_chain(sk,["Leg_"+side,"Shin_"+side,"Foot_"+side],before,[upper,lower,sole],p.weight)
