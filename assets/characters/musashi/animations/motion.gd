class_name MusashiMotion
extends RefCounted
# Same model adapter contract as HeroLocomotion; dedicated unarmed full-body poses.
var model: MusashiModel
var jump_compression=0.0
var free_feet=false
var step_events=0
var phase=0.0
var speed=0.0
var grounded=true
var vertical=0.0
var dodge=false
var dt=0.016
var rest={}
var poses={}
var rotations={}
var dirty=true
var blended={}
func _init(m):
	model=m
	for i in range(m.skeleton.get_bone_count()):rest[m.skeleton.get_bone_name(i)]=m.skeleton.get_bone_global_rest(i)
func update(delta,velocity,on_ground,vy,_attack,is_dodging):
	dt=delta;speed=Vector2(velocity.x,velocity.z).length();grounded=on_ground;vertical=vy;dodge=is_dodging
	var old=int(phase/PI);phase+=delta*(2.0+speed*1.15)
	if grounded and speed>1 and int(phase/PI)!=old:step_events+=1
	dirty=true
func set_rot(name: String,v: Vector3):
	# The arm rest vector points down; positive X raises the fist toward -Z.
	if name.begins_with("Arm_") or name.begins_with("Forearm_"):v.x=-v.x
	rotations[name]=Basis.from_euler(v)
func casting_pose(_combat) -> Variant:
	return null
func evaluate():
	if not dirty:return
	dirty=false;rotations.clear();poses.clear()
	var move=clampf(speed/9,0,1);var wave=sin(phase);var sprint=clampf((speed-10)/8,0,1)
	set_rot("Hips",Vector3(-.05*sprint,.12*wave*move,.035*wave*move))
	set_rot("Chest",Vector3(-.12*sprint,-.20*wave*move,0))
	set_rot("Head",Vector3(.08*sprint,.05*wave*move,0))
	for side in ["L","R"]:
		var s=1.0 if side=="L" else -1.0
		set_rot("Leg_"+side,Vector3(wave*s*.62*move,0,0))
		set_rot("Shin_"+side,Vector3(maxf(0,-wave*s)*.75*move,0,0))
		set_rot("Foot_"+side,Vector3(-maxf(0,-wave*s)*.35*move,0,0))
		set_rot("Arm_"+side,Vector3(-.10-wave*s*.48*move,0,s*.17))
		set_rot("Forearm_"+side,Vector3(-.26-.30*move,0,0))
	if not grounded:
		set_rot("Leg_L",Vector3(-.55,0,0));set_rot("Leg_R",Vector3(.3,0,0));set_rot("Shin_L",Vector3(.8,0,0))
	if dodge:
		set_rot("Chest",Vector3(-.5,0,0))
		set_rot("Arm_L",Vector3(1.1,0,0));set_rot("Arm_R",Vector3(1.1,0,0))
	var c=model.combat
	var dip=0.0
	var custom_pose=casting_pose(c) if c and not dodge else null
	if custom_pose!=null:
		dip=float(custom_pose)
	elif c and not dodge:
		if c.is_charging():
			var q=c.charge_ratio();set_rot("Hips",Vector3(0,-.25,0));set_rot("Chest",Vector3(.04,-.42,0))
			set_rot("Arm_R",Vector3(-.7,-.45,-.65));set_rot("Forearm_R",Vector3(-1.25,0,0))
			set_rot("Arm_L",Vector3(-.65,0,.25));set_rot("Forearm_L",Vector3(-1.1,0,0));dip=-.04-q*.035
		elif c.is_casting_meteors():
			# Raise the right hand overhead, drive it down, then recover from a crouch.
			var t=c.progress();var lift=smoothstep(0,.20,t)
			var slam=smoothstep(.43,.64,t);var recover=smoothstep(.78,1,t)
			var weight=1-recover
			set_rot("Arm_R",Vector3(lerpf(-.3-2.7*lift,-.45,slam)*weight,0,-.4*weight))
			set_rot("Forearm_R",Vector3(lerpf(-.25,-.15,slam)*weight,0,0))
			set_rot("Arm_L",Vector3(-.65*weight,.15*weight,.55*weight))
			set_rot("Forearm_L",Vector3(-1.1*weight,0,0))
			set_rot("Hips",Vector3(-.28*slam*weight,0,0))
			set_rot("Chest",Vector3(lerpf(.14*lift,-.7,slam)*weight,0,0))
			set_rot("Head",Vector3((-.22*lift+.45*slam)*weight,0,0))
			for side in ["L","R"]:
				set_rot("Leg_"+side,Vector3(-.55*slam*weight,0,.12*weight if side=="L" else -.12*weight))
				set_rot("Shin_"+side,Vector3(.9*slam*weight,0,0))
			dip=-.22*slam*weight
		elif c.state==c.State.BEAM:
			set_rot("Hips",Vector3(-.10,0,0));set_rot("Chest",Vector3(-.15,0,0));set_rot("Head",Vector3(.12,0,0))
			set_rot("Arm_R",Vector3(-1.35,0,-.12));set_rot("Forearm_R",Vector3(-.18,0,0))
			set_rot("Arm_L",Vector3(-1.15,-.15,.25));set_rot("Forearm_L",Vector3(-.55,0,0))
			set_rot("Shin_L",Vector3(.18,0,0));set_rot("Leg_L",Vector3(-.14,0,0));dip=-.04
		elif c.state==c.State.HIT_REACTION:
			set_rot("Chest",Vector3(.22,0,.08));set_rot("Head",Vector3(.10,0,0))
		elif c.is_attacking():
			var t=c.progress();var hook=c.state==c.State.HEAVY_HOOK
			var throwing=c.state==c.State.FIREBALL
			var side="R" if hook or throwing or c.stage==2 else "L"
			var s=1.0 if side=="L" else -1.0
			var swing=smoothstep(.16,.40,t);var recover=smoothstep(.58,1,t);var amount=1.0-recover
			var twist=lerpf(-.42,.65*(1.0+c.power*.3) if hook else .42,swing)*s*amount
			set_rot("Hips",Vector3(-.08*amount,twist*.65,0));set_rot("Chest",Vector3(-.1*amount,twist,0))
			set_rot("Head",Vector3(0,-twist*.65,0))
			set_rot("Arm_"+side,Vector3(lerpf(-.65,-1.5,swing)*amount,lerpf(-.8,.85,swing)*s*amount,s*(.65 if hook else .38)*amount))
			set_rot("Forearm_"+side,Vector3(lerpf(-1.25,-.5 if hook else -.20,swing)*amount,0,0))
			var other="R" if side=="L" else "L"
			set_rot("Arm_"+other,Vector3(-.7*amount,0,-s*.18));set_rot("Forearm_"+other,Vector3(-1.1*amount,0,0))
			set_rot("Leg_"+side,Vector3(-.15*amount,-twist*.3,0));set_rot("Shin_"+side,Vector3(.23*amount,0,0))
			set_rot("Foot_"+other,Vector3(-.16*sin(t*PI),twist*.35,0));dip=-.05*sin(t*PI)
	var sk=model.skeleton
	for i in range(sk.get_bone_count()):
		var n=sk.get_bone_name(i);var r: Transform3D=rest[n];var parent=sk.get_bone_parent(i)
		var desired: Basis=rotations.get(n,Basis.IDENTITY)
		var previous: Basis=blended.get(n,Basis.IDENTITY)
		var cast_speed=c.hero.attack_speed_multiplier() if c and c.is_attacking() else 1.0
		var delta_basis=previous.slerp(desired,1.0-exp(-dt*30.0*cast_speed))
		blended[n]=delta_basis
		var p=r.origin;var b=delta_basis
		if parent>=0:
			var pn=sk.get_bone_name(parent);var pp: Transform3D=poses[pn];var pr: Transform3D=rest[pn]
			var inherited=pp.basis*pr.basis.inverse()
			p=pp.origin+inherited*(r.origin-pr.origin);b=inherited*delta_basis
		elif grounded:p.y+=absf(wave)*.026*move+dip-jump_compression*.04
		var pose=Transform3D(b*r.basis,p);poses[n]=pose;sk.set_bone_global_pose(i,pose)

func reset():
	phase=0;speed=0;dirty=true
