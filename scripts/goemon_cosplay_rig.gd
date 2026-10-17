extends RefCounted
## Drive the original weighted Goemon mesh from each class's existing pose pivots.
## Rest geometry, bone lengths, weapons, contact timing and combat stay independent.
var skeleton: Skeleton3D
var joints: Dictionary
var driver_rest: Dictionary = {}
var bone_rest: Array[Transform3D] = []
var bone_driver: Array[String] = []
var bones: Dictionary = {}
var rest: Dictionary = {}
const Combo = preload("res://scripts/goemon_rogue_combo.gd")
const Strike = preload("res://scripts/goemon_reference_strike.gd")
const SamuraiPose=preload("res://scripts/samurai_combo_pose.gd")
const UserRun=preload("res://scripts/user_stride_run.gd")
var user_run: RefCounted
const RunBody = preload("res://scripts/goemon_reference_run_body.gd")
const SteadyRun = preload("res://scripts/steady_weapon_run.gd")
const JumpPose = preload("res://scripts/goemon_reference_jump.gd")
var jump_pose = JumpPose.new()
var idle_breath=preload("res://scripts/goemon_idle_breath.gd").new()
var samurai_scabbard=preload("res://scripts/samurai_scabbard.gd").new()
var knight_equipment: RefCounted
var dragoon_motion: RefCounted
var explorer_motion: RefCounted
var ninja_motion: RefCounted
var double_jump: RefCounted

func _init(model: Node3D, native_joints: Dictionary):
	skeleton = model.find_child("Skeleton3D", true, false)
	joints = native_joints
	knight_equipment=preload("res://scripts/knight_equipment_pose.gd").new(model)
	assert(skeleton != null, "Goemon cosplay requires the original skeleton")
	user_run=UserRun.new(skeleton)
	for key in ["Body", "Head", "Arm_L", "Arm_R", "Leg_L", "Leg_R"]:
		driver_rest[key] = skeleton.global_transform.affine_inverse() * joints[key].node.global_transform
	for i in range(skeleton.get_bone_count()):
		var name_ = skeleton.get_bone_name(i)
		var rest = skeleton.get_bone_global_rest(i)
		var driver = "Body"
		if name_ in ["Head", "Neck"]:
			driver = "Head"
		elif name_.begins_with("Arm_") or name_.begins_with("Forearm_") or name_.begins_with("Hand_"):
			var side = name_.right(1)
			driver = "Arm_" + side
			var shoulder = skeleton.get_bone_global_rest(skeleton.find_bone(driver)).origin
			var turn = Basis(Vector3.BACK, deg_to_rad(75.0 if side == "L" else -75.0))
			rest = Transform3D(turn, shoulder - turn * shoulder) * rest
		elif name_.begins_with("Leg_") or name_.begins_with("Shin_") or name_.begins_with("Foot_"):
			driver = "Leg_" + name_.right(1)
		bone_rest.append(rest)
		bone_driver.append(driver)
		bones[name_] = i
		self.rest[name_] = rest
	update()

func update(actor = null, state: Dictionary = {}, delta: float = 0):
	var inverse = skeleton.global_transform.affine_inverse()
	var deltas = {}
	for key in driver_rest:
		deltas[key] = inverse * joints[key].node.global_transform * driver_rest[key].affine_inverse()
	for i in range(bone_rest.size()):
		skeleton.set_bone_global_pose(i, deltas[bone_driver[i]] * bone_rest[i])
	if actor == null:return
	var attack = state.get("attack")
	var busy=attack!=null or state.get("blocking",false) or state.get("charging",false) or float(state.get("chargeTime",0))>0 or float(state.get("guardTime",0))>0 or float(state.get("shot",0))>0 or float(state.get("drinkGesture",0))>0 or float(state.get("roll",0))>0 or state.get("travel")!=null or state.get("dive")!=null or float(state.get("flip",-1))>=0
	idle_breath.update(delta,actor.locomotion.speed,bool(state.get("grounded",true)),busy)
	if attack is Dictionary and (attack.get("primary",false) or attack.get("style","")=="energy-wave") and actor.id not in ["mage","ranger"]:
		primary_pose(actor,attack,state)
	else:
		articulate_arms(actor)
		var ranger_hold={}
		if actor.id=="ranger" and authored_run_weight(actor,state)<.001 and SteadyRun.enabled(actor.id,state):
			var chest=pose("Chest")
			ranger_hold={"chest":chest,"right":chest.affine_inverse()*pose("Hand_R").origin,"left":chest.affine_inverse()*pose("Hand_L").origin,"bow":actor.joints.Weapon_Cutlass.node.global_transform}
		apply_run(actor,state)
		if not ranger_hold.is_empty():apply_ranger_carry(actor,ranger_hold)
		apply_drag_run(actor,state)
		if actor.id=="knight":knight_equipment.apply(actor,self,state)
		apply_jump(actor,state)
		apply_idle_breath(actor)
	if actor.id=="samurai":samurai_scabbard.apply(actor,self,state)
	if actor.id=="knight":
		if attack is Dictionary and attack.get("primary",false):knight_equipment.apply(actor,self,state)
		knight_equipment.animate_cloth(actor,state,delta)
	if actor.id=="dragoon":
		if dragoon_motion==null:dragoon_motion=preload("res://scripts/dragoon_authored_motion.gd").new(skeleton)
		dragoon_motion.apply(actor,state,delta)
	if actor.id in ["explorer","ninja"]:
		if explorer_motion==null:explorer_motion=preload("res://scripts/explorer_authored_motion.gd").new(skeleton)
		explorer_motion.apply(actor,state,delta)
	if actor.id=="ninja":
		if ninja_motion==null:ninja_motion=preload("res://scripts/ninja_authored_motion.gd").new(skeleton)
		# Initial activation may sample air before the body settles. Only a
		# real observed airborne interval should suppress the custom idle.
		ninja_motion.apply(actor,state,delta,explorer_motion.last_clip=="jump" and explorer_motion.air_age>.01 and bool(state.get("grounded",true)))
	if actor.id in ["ninja","ranger","explorer"]:
		if double_jump==null:double_jump=preload("res://scripts/tucked_double_jump.gd").new(skeleton)
		double_jump.apply(actor,state,delta)
	var dash=state.get("dashAttack")
	if actor.id in ["ninja","explorer"] and dash is Dictionary:
		for weapon_name in ["Weapon_Cutlass","Weapon_Pistol"]:
			var weapon: Node3D=actor.joints[weapon_name].node
			weapon.global_basis=weapon.global_basis.scaled(Vector3.ONE*float(dash.get("weaponScale",1)))

func apply_idle_breath(actor):
	if not idle_breath.allowed or idle_breath.weight<.001:return
	var old_hands={"L":skeleton.global_transform*pose("Hand_L"),"R":skeleton.global_transform*pose("Hand_R")}
	idle_breath.apply(skeleton)
	for side in ["L","R"]:
		var name_="Weapon_Cutlass" if side=="R" else "Weapon_Pistol"
		if actor.joints.has(name_):
			var weapon: Node3D=actor.joints[name_].node
			weapon.global_transform=(skeleton.global_transform*pose("Hand_"+side))*old_hands[side].affine_inverse()*weapon.global_transform

func apply_jump(actor,state: Dictionary):
	var busy=state.get("attack")!=null or state.get("blocking",false) or state.get("charging",false) or float(state.get("shot",0))>0 or float(state.get("drinkGesture",0))>0
	var special=float(state.get("roll",0))>0 or state.get("travel")!=null or state.get("dive")!=null
	var weight: float=actor.locomotion.air * JumpPose.flip_weight(-1.0 if actor.id in ["ninja","ranger","explorer"] else float(state.get("flip",-1)))
	if busy or special or weight<.001:return
	var old_hands={"L":skeleton.global_transform*pose("Hand_L"),"R":skeleton.global_transform*pose("Hand_R")}
	jump_pose.apply(skeleton,float(state.get("vertical",0)),weight,bool(state.get("grounded",true)))
	for side in ["L","R"]:
		var name_="Weapon_Cutlass" if side=="R" else "Weapon_Pistol"
		if actor.joints.has(name_):
			var weapon: Node3D=actor.joints[name_].node
			weapon.global_transform=(skeleton.global_transform*pose("Hand_"+side))*old_hands[side].affine_inverse()*weapon.global_transform

func pose(name_: String)->Transform3D:
	return skeleton.get_bone_global_pose(bones[name_])

func set_pose(name_: String,value: Transform3D):
	skeleton.set_bone_global_pose(bones[name_],value)

func rotate_chain(name_: String,rotation: Basis):
	var pivot=pose(name_).origin
	var transform=Transform3D(rotation,pivot-rotation*pivot)
	var changed={}
	for name in bones:
		var index: int=bones[name]
		while index>=0:
			if index==bones[name_]:changed[name]=transform*pose(name);break
			index=skeleton.get_bone_parent(index)
	for name in changed:set_pose(name,changed[name])

func solve_arm(side: String,target: Vector3):
	var upper=pose("Arm_"+side);var lower=pose("Forearm_"+side);var hand=pose("Hand_"+side)
	var a: float=rest["Arm_"+side].origin.distance_to(rest["Forearm_"+side].origin)
	var b: float=rest["Forearm_"+side].origin.distance_to(rest["Hand_"+side].origin)
	var ray=target-upper.origin
	var axis=ray.normalized()
	if axis.length_squared()<.5:axis=Vector3.DOWN
	var distance=clampf(ray.length(),.08,(a+b)*.96)
	var pole=Vector3(.8 if side=="R" else -.8,-.6,.25)
	pole=(pole-axis*pole.dot(axis)).normalized()
	var along=(a*a-b*b+distance*distance)/(2*distance)
	var elbow=upper.origin+axis*along+pole*sqrt(maxf(0,a*a-along*along))
	var wrist=upper.origin+axis*distance
	upper.basis=Basis(Quaternion((lower.origin-upper.origin).normalized(),(elbow-upper.origin).normalized()))*upper.basis
	lower.basis=Basis(Quaternion((hand.origin-lower.origin).normalized(),(wrist-elbow).normalized()))*lower.basis
	lower.origin=elbow;hand.origin=wrist
	set_pose("Arm_"+side,upper);set_pose("Forearm_"+side,lower);set_pose("Hand_"+side,hand)

func articulate_arms(actor):
	# Even class-specific bow/cast/guard poses use both original arm joints.
	# Keep each weapon's orientation while correcting its grip to the real wrist.
	for side in ["L","R"]:
		var old_hand=pose("Hand_"+side)
		solve_arm(side,old_hand.origin)
		var shift=skeleton.global_basis*(pose("Hand_"+side).origin-old_hand.origin)
		var name_="Weapon_Cutlass" if side=="R" else "Weapon_Pistol"
		if actor.joints.has(name_):actor.joints[name_].node.global_position+=shift

func authored_run_weight(actor,state: Dictionary)->float:
	if not UserRun.enabled(actor.id):return 0.0
	var busy=state.get("attack")!=null or state.get("blocking",false) or state.get("charging",false) or float(state.get("chargeTime",0))>0 or float(state.get("guardTime",0))>0 or float(state.get("shot",0))>0 or float(state.get("drinkGesture",0))>0
	var grounded=state.get("grounded",true) and float(state.get("roll",0))<=0 and state.get("travel")==null and state.get("dive")==null and float(state.get("flip",-1))<0 and not state.get("crouched",false)
	return UserRun.weight(actor.locomotion.stride_speed,actor.locomotion.direction.z)*(1.0-actor.locomotion.air) if grounded and not busy else 0.0

func apply_authored_run(actor,amount: float):
	var old_hands={"L":skeleton.global_transform*pose("Hand_L"),"R":skeleton.global_transform*pose("Hand_R")}
	var held={}
	for name_ in ["Weapon_Cutlass","Weapon_Pistol"]:
		if actor.joints.has(name_):held[name_]=actor.joints[name_].node.global_transform
	# Class idle stances can move the complete model as well as its bones.
	# Fade those extra tilts/bounces out so all selected bodies share this pose.
	actor.model.position=actor.model.position.lerp(Vector3.ZERO,amount)
	actor.model.quaternion=actor.model.quaternion.slerp(Quaternion.IDENTITY,amount)
	user_run.apply(fposmod(actor.locomotion.phase/TAU,1.0),amount)
	for side in ["L","R"]:
		var name_="Weapon_Cutlass" if side=="R" else "Weapon_Pistol"
		if held.has(name_):
			actor.joints[name_].node.global_transform=(skeleton.global_transform*pose("Hand_"+side))*old_hands[side].affine_inverse()*held[name_]

func apply_run(actor,state: Dictionary):
	var authored=authored_run_weight(actor,state)
	if authored>.001:
		apply_authored_run(actor,authored)
		return
	var busy=state.get("attack")!=null or state.get("blocking",false) or state.get("charging",false) or float(state.get("shot",0))>0 or float(state.get("drinkGesture",0))>0
	var grounded=state.get("grounded",true) and float(state.get("roll",0))<=0 and state.get("travel")==null
	var weight: float=actor.locomotion.weight*maxf(0,actor.locomotion.direction.z) if grounded and not busy else 0.0
	if weight<.001:return
	var phase: float=fposmod(actor.locomotion.phase/TAU,1.0)
	var old_hands={"L":skeleton.global_transform*pose("Hand_L"),"R":skeleton.global_transform*pose("Hand_R")}
	# Ready-weapon offsets can move one native shoulder up independently.
	# A forward run starts from the shared body frame so those offsets cannot
	# disconnect the shoulders from the chest or bias every stride to one side.
	var body_delta=skeleton.global_transform.affine_inverse()*joints.Body.node.global_transform*driver_rest.Body.affine_inverse()
	RunBody.blend_base(skeleton,rest,body_delta,weight)
	RunBody.apply(skeleton,phase,weight,SteadyRun.swing_scale(actor.id,state))
	if not (actor.id in ["ranger","knight"] and SteadyRun.enabled(actor.id,state)):RunBody.arms(skeleton,phase,weight)
	for i in range(2):
		var side="L" if i==0 else "R"
		var name_="Weapon_Cutlass" if side=="R" else "Weapon_Pistol"
		if actor.joints.has(name_):
			var weapon: Node3D=actor.joints[name_].node
			weapon.global_transform=(skeleton.global_transform*pose("Hand_"+side))*old_hands[side].affine_inverse()*weapon.global_transform
		var step=fposmod(phase+i*.5,1.0)
		var stance=RunBody.stance_fraction(actor.locomotion.stride_speed,.72)
		var u=clampf((step-stance)/(1.0-stance),0,1)
		var travel=.72*(.5-step/stance) if step<stance else lerpf(-.36,.36,smoothstep(0,1,u))
		var lift=.49*sin(PI*sqrt(u)) if step>=stance else 0.0
		var foot_goal: Vector3=rest["Foot_"+side].origin+Vector3(0,lift,-travel)
		foot_goal.x+=RunBody.swing_inset(side,u)
		var recovery=sin(PI*sqrt(u))*weight
		var frame=Basis.IDENTITY.slerp(RunBody.hip_frame(skeleton),recovery)
		foot_goal=pose("Pelvis").origin+frame*(foot_goal-pose("Pelvis").origin)
		# Turn the recovery around the hips without spending its ground clearance.
		foot_goal.y=rest["Foot_"+side].origin.y+lift
		solve_leg(side,pose("Foot_"+side).origin.lerp(foot_goal,weight),-1.2*sin(PI*sqrt(u))*weight,frame)

func apply_ranger_carry(actor,held: Dictionary):
	# Preserve the authored ready bow plane and hand positions relative to the
	# chest, after running has posed the legs. No arm-pumping reaches the bow.
	var chest=pose("Chest")
	Strike.arm(skeleton,"R",chest*held.right,1.0)
	Strike.arm(skeleton,"L",chest*held.left,1.0)
	var frame=skeleton.global_transform*(chest*held.chest.affine_inverse())*skeleton.global_transform.affine_inverse()
	var bow: Node3D=actor.joints.Weapon_Cutlass.node
	bow.global_transform=frame*held.bow
	bow.global_position=skeleton.global_transform*pose("Hand_R").origin

func apply_drag_run(actor,state: Dictionary):
	if actor.id!="magic-swordsman":return
	var busy=state.get("attack")!=null or state.get("blocking",false) or state.get("charging",false) or float(state.get("shot",0))>0 or float(state.get("drinkGesture",0))>0
	var grounded=state.get("grounded",true) and float(state.get("roll",0))<=0 and state.get("travel")==null and state.get("dive")==null
	var weight: float=actor.locomotion.weight if grounded and not busy else 0.0
	if weight<.001:return
	# Establish the carry even when walking; gait amplitude still follows speed.
	weight=smoothstep(0,.08,weight)
	# Both hands hold a low, trailing blade on the right side.
	# Solve after torso/legs so their banking cannot turn this into an arm swing.
	var local_aim=Vector3(.45,-.39,.80).normalized()
	var target=Strike.two_hand_target(skeleton,Vector3(.42,1.0,-.32),local_aim)
	Strike.arm(skeleton,"R",target,weight)
	var weapon: Node3D=actor.joints.Weapon_Cutlass.node
	var aim=(skeleton.global_basis*local_aim).normalized()
	var basis=Basis(Quaternion(actor.WEAPON_AXES[actor.id].normalized(),aim))
	var scale_: Vector3=actor.joints.Weapon_Cutlass.scale*skeleton.global_basis.get_scale()
	var rotation=weapon.global_basis.orthonormalized().slerp(basis,weight)
	weapon.global_transform=Transform3D(rotation.scaled(scale_),skeleton.global_transform*pose("Hand_R").origin)
	# The support grip follows the final sword transform, including its blend.
	var support=weapon.global_position-(weapon.global_basis*actor.WEAPON_AXES[actor.id]).normalized()*.18
	Strike.arm(skeleton,"L",skeleton.global_transform.affine_inverse()*support,weight)

func solve_leg(side: String,goal: Vector3,heel: float,frame: Basis):
	var hip=pose("Leg_"+side).origin
	var h0: Vector3=rest["Leg_"+side].origin
	var k0: Vector3=rest["Shin_"+side].origin
	var a0: Vector3=rest["Foot_"+side].origin
	var upper=h0.distance_to(k0);var lower=k0.distance_to(a0)
	var ray=goal-hip;var distance=clampf(ray.length(),.08,(upper+lower)*.998)
	var axis=ray.normalized();var pole=frame*Vector3.FORWARD
	pole=(pole-axis*pole.dot(axis)).normalized()
	var along=(upper*upper-lower*lower+distance*distance)/(2*distance)
	var knee=hip+axis*along+pole*sqrt(maxf(0,upper*upper-along*along))
	var ankle=hip+axis*distance
	set_pose("Leg_"+side,Transform3D(frame*Basis(Quaternion((k0-h0).normalized(),frame.inverse()*(knee-hip).normalized()))*rest["Leg_"+side].basis,hip))
	set_pose("Shin_"+side,Transform3D(frame*Basis(Quaternion((a0-k0).normalized(),frame.inverse()*(ankle-knee).normalized()))*rest["Shin_"+side].basis,knee))
	set_pose("Foot_"+side,Transform3D(frame*Basis(Vector3.RIGHT,heel)*rest["Foot_"+side].basis,ankle))

func primary_pose(actor,a: Dictionary,state: Dictionary):
	# Goemon's authored hips/chest/wrist path, retimed to the class's contact.
	# This replaces the old rigid-shoulder pose only for ordinary melee attacks.
	var stage=1+int(a.index)%3
	var duration_: float=Combo.duration(stage)
	var contact: float=maxf(.001,float(a.contact))
	var t: float=float(a.time)
	var elapsed=Combo.CONTACT_TIME*t/contact if t<=contact else Combo.CONTACT_TIME+(duration_-Combo.CONTACT_TIME)*(t-contact)/maxf(.001,float(a.duration)-contact)
	var p: Dictionary=Combo.sample(stage,elapsed)
	if actor.id=="samurai":
		p=SamuraiPose.sample(int(a.index),float(a.time),float(a.duration),contact)
		if int(a.index)%5==4:
			var progress=clampf(float(a.time)/maxf(.01,float(a.duration)),0,1)
			var turn=PI*smoothstep(.08,.70,progress)*(1-smoothstep(.88,1,progress))
			actor.model.rotation.y+=turn
			p.aim=p.aim.rotated(Vector3.UP,-turn)
	var left=actor.id=="explorer" and int(a.get("swingSide",1))<0
	if left:p=Strike.mirrored(p)
	RunBody.blend_base(skeleton,rest,Transform3D.IDENTITY,p.weight)
	var shifted={}
	for name in bones:
		if name=="Root":continue
		var value=pose(name);value.origin+=p.offset;shifted[name]=value
	for name in shifted:set_pose(name,shifted[name])
	rotate_chain("Pelvis",Basis.from_euler(p.hip))
	rotate_chain("Spine",Basis.from_euler(p.chest*.45))
	rotate_chain("Chest",Basis.from_euler(p.chest*.55))
	rotate_chain("Neck",Basis.from_euler(p.head))
	var side="L" if left else "R"
	var target: Vector3=p.wrist+p.offset
	var aim: Vector3=p.aim
	# A lance retains its thrust, using the same articulated Goemon body load.
	if actor.id=="dragoon":
		var phase: Dictionary=actor._phase(a)
		target=Vector3(.34,1.14,actor._c(phase,.1,-.64,-.72))
		aim=Vector3(0,actor._c(phase,.15,0,-.04),-1)
	if actor.id in ["magic-swordsman","dragoon"]:target=Strike.two_hand_target(skeleton,target,aim)
	Strike.arm(skeleton,side,target,p.weight)
	var other="R" if left else "L"
	Strike.arm(skeleton,other,p.offhand+p.offset,p.weight)
	Strike.feet(skeleton,p,bool(state.get("grounded",true)))
	var weapon_name="Weapon_Pistol" if left else "Weapon_Cutlass"
	var weapon: Node3D=actor.joints[weapon_name].node
	var axis: Vector3=actor.LEFT_BLADE if left else actor.WEAPON_AXES[actor.id]
	var world_aim=(skeleton.global_basis*aim).normalized()
	var weapon_scale: Vector3=actor.joints[weapon_name].scale*float(state.get("meleeVisualScale",1.0))
	var aim_basis=Basis(Quaternion(axis.normalized(),world_aim)).scaled(weapon_scale*skeleton.global_basis.get_scale())
	var rotation=weapon.global_basis.orthonormalized().slerp(aim_basis.orthonormalized(),p.weight)
	var size_=weapon.global_basis.get_scale().lerp(aim_basis.get_scale(),p.weight)
	weapon.global_transform=Transform3D(rotation.scaled(size_),skeleton.global_transform*pose("Hand_"+side).origin)
	if actor.id in ["magic-swordsman","dragoon"]:
		var grip_direction=(weapon.global_basis*axis).normalized()
		var support=skeleton.global_transform.affine_inverse()*(weapon.global_position-grip_direction*.18)
		Strike.arm(skeleton,other,support,p.weight)
	elif actor.joints.has("Weapon_Pistol") and not left:
		actor.joints.Weapon_Pistol.node.global_position=skeleton.global_transform*pose("Hand_L").origin
	elif left:
		actor.joints.Weapon_Cutlass.node.global_position=skeleton.global_transform*pose("Hand_R").origin
