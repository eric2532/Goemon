extends RefCounted
## Authored Knight carries in model coordinates (+Z forward, left is +X).
## Cloth advances on real animation delta; contact probes leave its clock alone.
const Strike=preload("res://scripts/goemon_reference_strike.gd")
const Combo=preload("res://scripts/goemon_rogue_combo.gd")
var cape: MeshInstance3D
var cloth_time=0.0
var wind=0.0
var flutter=0.0
var shield_corners=PackedVector3Array()
func _init(model: Node3D):
	cape=model.find_child("Knight_Long_Dark_Navy_Cape",true,false)
	var shield=model.find_child("Weapon_Pistol",true,false)
	if shield!=null and cape!=null:
		var geometry=shield.find_child("Weapon_Pistol_Geometry",true,false)
		if geometry!=null:
			for i in 8:shield_corners.append(shield.to_local(geometry.to_global(geometry.get_aabb().get_endpoint(i))))
func reset():
	cloth_time=0;wind=0;flutter=0
func basis_for(axis: Vector3,face: Vector3)->Basis:
	var y=axis.normalized();var z=(face-y*face.dot(y)).normalized()
	return Basis(y.cross(z).normalized(),y,z)
func hand_and_weapon(actor,rig,side: String,grip: Vector3,basis_: Basis,visual_scale: float=1.0):
	var sk: Skeleton3D=rig.skeleton
	var inverse=sk.global_transform.affine_inverse()
	var axis=basis_.y.normalized()
	var size_: float=sk.global_basis.get_scale().y
	Strike.arm(sk,side,inverse*(grip-axis*.135*size_),1)
	var hand: Transform3D=rig.pose("Hand_"+side)
	# The palm's long axis follows the hilt; roll follows the blade/shield face.
	hand.basis=sk.global_basis.orthonormalized().inverse()*basis_
	rig.set_pose("Hand_"+side,hand)
	var weapon_name="Weapon_Cutlass" if side=="R" else "Weapon_Pistol"
	var weapon: Node3D=actor.joints[weapon_name].node
	var scale_: Vector3=actor.joints[weapon_name].scale*sk.global_basis.get_scale()*visual_scale
	weapon.global_transform=Transform3D(basis_.scaled(scale_),sk.global_transform*(hand*Vector3(0,.135,0)))
func apply(actor,rig,state: Dictionary):
	var sk: Skeleton3D=rig.skeleton
	var chest: Transform3D=rig.pose("Chest")
	var frame=sk.global_transform*chest*sk.get_bone_global_rest(sk.find_bone("Chest")).affine_inverse()*sk.global_transform.affine_inverse()*actor.model.global_transform
	var carry=smoothstep(0,.3,actor.locomotion.weight)
	var shield_face=Vector3(.5,0,.866).lerp(Vector3.RIGHT,carry).normalized()
	var shield_grip=Vector3(.90,1.40,.22).lerp(Vector3(.72,1.41,0),carry)
	var sword_grip=Vector3(-.69,1.07,.24).lerp(Vector3(-.74,1.05,.07),carry)
	var sword_axis=Vector3(-.32,.941,-.11).lerp(Vector3(-.22,.907,-.36),carry).normalized()
	var sword_basis=frame.basis.orthonormalized()*basis_for(sword_axis,Vector3.LEFT)
	var attack=state.get("attack")
	var primary=attack is Dictionary and bool(attack.get("primary",false))
	var guarding=bool(state.get("blocking",false)) or float(state.get("guardTime",0))>0 or bool(state.get("charging",false)) or float(state.get("chargeTime",0))>0
	var special=attack is Dictionary and not primary or float(state.get("drinkGesture",0))>0 or float(state.get("shot",0))>0
	var visual_scale=1.0
	var sword_world: Vector3=frame*sword_grip
	if primary:
		var stage=1+int(attack.index)%3;var contact=maxf(.001,float(attack.contact))
		var elapsed=Combo.CONTACT_TIME*float(attack.time)/contact if float(attack.time)<=contact else Combo.CONTACT_TIME+(Combo.duration(stage)-Combo.CONTACT_TIME)*(float(attack.time)-contact)/maxf(.001,float(attack.duration)-contact)
		var weight: float=Combo.sample(stage,elapsed).weight
		var sword: Node3D=actor.joints.Weapon_Cutlass.node
		sword_world=sword_world.lerp(sword.global_position,weight)
		sword_basis=sword_basis.slerp(sword.global_basis.orthonormalized(),weight)
		visual_scale=lerpf(1.0,float(state.get("meleeVisualScale",1)),weight)
		shield_face=Vector3(0,0,1);shield_grip=Vector3(.52,1.40,.37)
	elif special:
		# Keep native shield bash, flask and skill trajectories, closing their grips.
		sword_basis=actor.joints.Weapon_Cutlass.node.global_basis.orthonormalized()
		sword_world=sk.global_transform*rig.pose("Hand_R").origin+sword_basis.y*.135*sk.global_basis.get_scale().y
	if guarding:
		shield_face=Vector3.BACK;shield_grip=Vector3(.42,1.40,.48)
	hand_and_weapon(actor,rig,"R",sword_world,sword_basis,visual_scale)
	var shield_basis=frame.basis.orthonormalized()*basis_for(Vector3.UP,shield_face)
	var shield_world: Vector3=frame*shield_grip
	if special:
		shield_basis=actor.joints.Weapon_Pistol.node.global_basis.orthonormalized()
		shield_world=sk.global_transform*rig.pose("Hand_L").origin+shield_basis.y*.135*sk.global_basis.get_scale().y
	if state.get("grounded",true) and float(state.get("roll",0))<=0 and float(state.get("flip",-1))<0:
		# Raise the centered grip when crouching/leaning would plant the wall
		# shield through the ground. Solve the arm after this correction.
		var size_: Vector3=actor.joints.Weapon_Pistol.scale*sk.global_basis.get_scale()
		var lowest=INF
		for corner in shield_corners:lowest=minf(lowest,(shield_world+shield_basis.scaled(size_)*corner).y)
		shield_world.y+=maxf(0,actor.global_position.y+.035*sk.global_basis.get_scale().y-lowest)
	hand_and_weapon(actor,rig,"L",shield_world,shield_basis)
func animate_cloth(actor,state: Dictionary,delta: float):
	if cape==null:return
	cloth_time+=maxf(0,delta)
	var moving=clampf(actor.locomotion.speed/10.2,0,1)
	wind=lerpf(wind,moving,1-exp(-maxf(0,delta)*6))
	var action=float(state.get("attack")!=null or not state.get("grounded",true))
	flutter=lerpf(flutter,action,1-exp(-maxf(0,delta)*9))
	var phase=cloth_time*4.4
	var values=[lerpf(.10+.045*sin(phase),.64+.16*sin(phase-.65),wind)+flutter*.08,
		lerpf(.14+.10*sin(phase-.7),.30+.27*sin(phase*2-.9),wind),
		lerpf(.14+.10*sin(phase+1.2),.30+.27*sin(phase*2+1.1),wind),
		lerpf(.35*sin(phase-.5),.68*sin(phase-.8),wind)]
	for i in 4:cape.set_blend_shape_value(i,values[i])
