class_name HeroLocomotion
extends RefCounted
# AnimationTree owns the authored pose. Analytical leg IK adds terrain contact;
# combat remains an upper-body overlay and never changes hit timing or physics.
var model: Node3D
var skeleton: Skeleton3D
var tree: AnimationTree
var player: AnimationPlayer
var bones: Dictionary={}
var rest: Dictionary={}
var phase=0.0
var speed=0.0
var actual_speed=0.0
var local_velocity=Vector3.ZERO
var world_velocity=Vector3.ZERO
var direction=Vector3.FORWARD
var grounded=true
var was_grounded=true
var vertical=0.0
var air_blend=0.0
var air_age=0.0
var land_age=1.0
var landing_weight=0.0
var attack=0.0
var dodge=false
var free_feet=false
var dt=1.0/60.0
var dirty=true
var ticks=0
var last_origin=Vector3.ZERO
var initialized=false
var move_blend=Vector2.ZERO
var contact=[false,false]
var anchor=[Vector3.ZERO,Vector3.ZERO]
var normal=[Vector3.UP,Vector3.UP]
var foot_yaw=[0.0,0.0]
var targets=[Vector3.ZERO,Vector3.ZERO]
var last_goal=[Vector3.ZERO,Vector3.ZERO]
var plant_error=[0.0,0.0]
var step_events=0
var upper_overlay=0.0
var turn_lean=0.0
var acceleration_lean=0.0
var shoulder_inertia=0.0
var pivot_twist=0.0
var pivot_trail=0.0
var jump_compression=0.0
var landing_strength=0.0
var old_speed=0.0
var old_yaw=0.0
var action_arm_extension=0.0
var arm_action_requested=false
var lateral_response=0.0
var lateral_acceleration=0.0
var previous_local_velocity=Vector3.ZERO
var reference_pose=false
var pelvis_offset=0.0
var settling=[-1.0,-1.0]
var settle_start=[Vector3.ZERO,Vector3.ZERO]
var grounded_blend=1.0

func _init(owner_model: Node3D):
	model=owner_model
	skeleton=model.skeleton
	for i in range(skeleton.get_bone_count()):
		var name=skeleton.get_bone_name(i)
		bones[name]=i
		rest[name]=skeleton.get_bone_global_rest(i)
	player=model.rig_visual.find_child("AnimationPlayer",true,false)
	assert(player!=null,"Locomotion needs authored Blender animations")
	for name in player.get_animation_list():
		var clip=player.get_animation(name)
		if name in ["Idle","Walk","Run","Sprint","Back_Walk","Back_Run","Strafe_L_Walk","Strafe_L_Run","Strafe_R_Walk","Strafe_R_Run","JumpLoop","Fall"]:
			clip.loop_mode=Animation.LOOP_LINEAR
	build_tree()

func animation(name: String)->AnimationNodeAnimation:
	var node=AnimationNodeAnimation.new()
	node.animation=name
	return node

func build_tree():
	tree=AnimationTree.new()
	model.add_child(tree)
	tree.anim_player=tree.get_path_to(player)
	tree.root_node=tree.get_path_to(player.get_node(player.root_node))
	tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var graph=AnimationNodeBlendTree.new()
	var ground=AnimationNodeBlendSpace2D.new()
	ground.min_space=Vector2(-1,-1)
	ground.max_space=Vector2(1,1)
	ground.sync=true
	for entry in [["Idle",Vector2.ZERO],["Walk",Vector2(0,-0.24)],["Run",Vector2(0,-0.60)],["Sprint",Vector2(0,-1)], ["Back_Walk",Vector2(0,0.24)],["Back_Run",Vector2(0,0.60)], ["Strafe_L_Walk",Vector2(-0.24,0)],["Strafe_L_Run",Vector2(-0.60,0)], ["Strafe_R_Walk",Vector2(0.24,0)],["Strafe_R_Run",Vector2(0.60,0)]]:
		ground.add_blend_point(animation(entry[0]),entry[1])
	graph.add_node("Ground",ground)
	graph.add_node("DistancePhase",AnimationNodeTimeSeek.new())
	graph.connect_node("DistancePhase",0,"Ground")
	var air=AnimationNodeBlendSpace1D.new()
	air.min_space=0;air.max_space=2;air.sync=true
	air.add_blend_point(animation("JumpStart"),0)
	air.add_blend_point(animation("JumpLoop"),1)
	air.add_blend_point(animation("Fall"),2)
	graph.add_node("Air",air)
	graph.add_node("AirTime",AnimationNodeTimeSeek.new())
	graph.connect_node("AirTime",0,"Air")
	graph.add_node("GroundAir",AnimationNodeBlend2.new())
	graph.connect_node("GroundAir",0,"DistancePhase")
	graph.connect_node("GroundAir",1,"AirTime")
	graph.add_node("Land",animation("Land"))
	graph.add_node("LandTime",AnimationNodeTimeSeek.new())
	graph.connect_node("LandTime",0,"Land")
	graph.add_node("Landing",AnimationNodeBlend2.new())
	graph.connect_node("Landing",0,"GroundAir")
	graph.connect_node("Landing",1,"LandTime")
	graph.connect_node("output",0,"Landing")
	tree.tree_root=graph
	tree.active=true

func gait()->Vector3:
	# x = stance duty, y = full foot travel, z = swing clearance.
	# Short legs at game sprint speeds need a short contact / long recovery phase.
	var visual_speed=speed/ronin_speed_scale()
	var run=clampf((visual_speed-2.2)/6.0,0,1)
	var sprint=clampf((visual_speed-10.2)/7.8,0,1)
	return Vector3(lerpf(lerpf(0.60,0.18,run),0.12,sprint),lerpf(lerpf(0.52,0.64,run),0.76,sprint),lerpf(lerpf(0.10,0.17,run),0.22,sprint))

func ronin_speed_scale()->float:
	return 3.0 if is_instance_valid(model.ronin_scarf) and model.ronin_scarf.visible else 1.0

func update(delta: float,velocity_world: Vector3,on_floor: bool,vy: float,attack_value: float,dodging: bool):
	dt=maxf(delta,0.0001)
	world_velocity=Vector3(velocity_world.x,0,velocity_world.z)
	actual_speed=world_velocity.length()
	speed=lerpf(speed,actual_speed,1-exp(-dt*16))
	local_velocity=model.global_basis.inverse()*world_velocity
	if actual_speed>0.08: direction=Vector3(local_velocity.x,0,local_velocity.z).normalized()
	grounded=on_floor
	var vertical_before=vertical
	vertical=vy
	attack=attack_value
	dodge=dodging
	var arm_action=attack>0 or dodge or arm_action_requested or model.charge_requested or model.charge_pose_weight>0.01
	action_arm_extension=move_toward(action_arm_extension,1.0 if arm_action else 0.0,delta*(16 if arm_action else 8))
	if grounded and not was_grounded:
		land_age=0
		landing_strength=clampf(absf(vertical_before)/20.0,0.2,1.0)
		contact=[false,false]
		initialized=false
	if not grounded and was_grounded: air_age=0;contact=[false,false]
	air_age+=dt
	land_age+=dt
	air_blend=move_toward(air_blend,0 if grounded else 1,dt*10)
	grounded_blend=move_toward(grounded_blend,1 if grounded else 0,dt*14)
	landing_weight=(1-smoothstep(0,0.26,land_age))*lerpf(0.3,0.85,landing_strength)
	if grounded and actual_speed>0.06:
		var g=gait()
		phase=fposmod(phase+actual_speed/ronin_speed_scale()*dt/(g.y/g.x),1.0)
	var visual_speed=speed/ronin_speed_scale()
	var normalized_speed=lerpf(0,0.24,clampf(visual_speed/2.2,0,1)) if visual_speed<=2.2 else (lerpf(0.24,0.6,clampf((visual_speed-2.2)/8.0,0,1)) if visual_speed<10.2 else lerpf(0.6,1,clampf((visual_speed-10.2)/7.8,0,1)))
	if grounded and speed<0.1: phase=fposmod(phase+dt*0.22,1)
	var desired=Vector2(direction.x,direction.z)*normalized_speed
	move_blend=move_blend.lerp(desired,1-exp(-dt*16))
	var yaw=model.global_rotation.y
	var yaw_speed=angle_difference(old_yaw,yaw)/dt if initialized else 0.0
	turn_lean=lerpf(turn_lean,clampf(-yaw_speed*0.025,-0.09,0.09)*clampf(speed/5,0,1),1-exp(-dt*12))
	acceleration_lean=lerpf(acceleration_lean,clampf((actual_speed-old_speed)/dt*0.0035,-0.11,0.14),1-exp(-dt*12))
	shoulder_inertia=lerpf(shoulder_inertia,acceleration_lean,1-exp(-dt*8))
	var pivot_target=clampf(-yaw_speed*0.022,-0.26,0.26)*clampf(actual_speed/4,0,1) if grounded else 0.0
	pivot_twist=lerpf(pivot_twist,pivot_target,1-exp(-dt*18))
	pivot_trail=lerpf(pivot_trail,pivot_twist,1-exp(-dt*9))
	# Direction comes from real velocity, so strafing, air steering and braking
	# share a responsive upper-body weight shift without changing facing/input.
	var side=clampf(local_velocity.x/4.5,-1,1)
	lateral_response=lerpf(lateral_response,side,1-exp(-dt*11))
	var side_accel=clampf((local_velocity.x-previous_local_velocity.x)/dt*0.0014,-0.045,0.045)
	lateral_acceleration=lerpf(lateral_acceleration,side_accel,1-exp(-dt*14))
	previous_local_velocity=local_velocity
	old_speed=actual_speed
	old_yaw=yaw
	was_grounded=grounded
	dirty=true
	ticks+=1

func terrain(point: Vector3)->Dictionary:
	var q=PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.72,point-Vector3.UP*1.05,1)
	var hit=model.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.normal.dot(Vector3.UP)>0.6: return hit
	return {}

func pose(name: String)->Transform3D:
	return skeleton.get_bone_global_pose(bones[name])

func set_pose(name: String,value: Transform3D):
	skeleton.set_bone_global_pose(bones[name],value)

func rotate_chain(name: String,pivot: Vector3,rotation: Basis):
	# Apply a world-in-skeleton-space overlay to a bone and its complete descendants.
	var root_index: int=bones[name]
	var affected: Dictionary={}
	for i in range(skeleton.get_bone_count()):
		var ancestor=i
		while ancestor>=0 and ancestor!=root_index: ancestor=skeleton.get_bone_parent(ancestor)
		if ancestor!=root_index: continue
		var p=skeleton.get_bone_global_pose(i)
		p.origin=pivot+rotation*(p.origin-pivot)
		p.basis=rotation*p.basis
		affected[i]=p
	for i in affected: skeleton.set_bone_global_pose(i,affected[i])

func evaluate():
	if not dirty: return
	dirty=false
	if reference_pose:
		for name in bones: set_pose(name,rest[name])
		return
	tree.set("parameters/Ground/blend_position",move_blend)
	tree.set("parameters/DistancePhase/seek_request",phase)
	tree.set("parameters/Air/blend_position",minf(1,air_age/0.14) if vertical>0.5 else 2.0)
	tree.set("parameters/AirTime/seek_request",minf(air_age,0.99))
	tree.set("parameters/GroundAir/blend_amount",air_blend)
	tree.set("parameters/LandTime/seek_request",minf(land_age/0.24,0.999))
	tree.set("parameters/Landing/blend_amount",landing_weight)
	# Procedural overlays must never become the next frame's animation baseline.
	# Clear prior IK/overlay writes before the zero-delta animation seek.
	skeleton.reset_bone_poses()
	tree.advance(0)
	# The authored run crouches by 18–22 cm. Restore most of that clearance
	# before terrain IK so the short legs can swing without folding into the hips.
	var stride_weight=clampf((speed-2.2)/6.0,0,1)*grounded_blend
	if stride_weight>0.001:
		var lift=lerpf(.10,.14,clampf((speed-10.2)/7.8,0,1))*stride_weight
		var lifted={}
		for name in bones:
			if name=="Root":continue
			var value=pose(name);value.origin.y+=lift;lifted[name]=value
		for name in lifted:set_pose(name,lifted[name])
	# Small anticipation and turning bank above the hips; the head counter-rotates.
	var head_before=pose("Head")
	var chest=pose("Spine")
	rotate_chain("Spine",chest.origin,Basis.from_euler(Vector3(-acceleration_lean,0,turn_lean)))
	var head=pose("Head")
	head.basis=Basis(head_before.basis.get_rotation_quaternion().slerp(head.basis.get_rotation_quaternion(),0.25))
	set_pose("Head",head)
	# Directional intent is layered AFTER head stabilization, so the head follows
	# the shoulder turn instead of having it cancelled by the counter-motion pass.
	var side_weight=lateral_response*(0.5 if free_feet else 1.0)
	var bank=-side_weight*0.025-lateral_acceleration*0.25
	rotate_chain("Pelvis",pose("Pelvis").origin,Basis(Vector3.BACK,bank))
	rotate_chain("Spine",pose("Spine").origin,Basis.from_euler(Vector3(0,-side_weight*0.08,-side_weight*0.045-lateral_acceleration*0.50)))
	rotate_chain("Chest",pose("Chest").origin,Basis.from_euler(Vector3(0,-side_weight*0.12,-side_weight*0.035)))
	rotate_chain("Neck",pose("Neck").origin,Basis.from_euler(Vector3(0,-side_weight*0.08,side_weight*0.035)))
	# Transient momentum only: approved authored cycles and proportions stay intact.
	rotate_chain("Pelvis",pose("Pelvis").origin,Basis(Vector3.UP,pivot_twist*0.55))
	rotate_chain("Chest",pose("Chest").origin,Basis.from_euler(Vector3(-shoulder_inertia*0.35,pivot_trail-pivot_twist*0.55,0)))
	rotate_chain("Neck",pose("Neck").origin,Basis(Vector3.UP,-pivot_trail*0.25))
	var compression=jump_compression*0.065+absf(pivot_twist)*0.10
	compression+=landing_strength*sin(clampf(land_age/0.24,0,1)*PI)*0.045
	if grounded and (compression>0.0001 or absf(acceleration_lean)>0.0001):
		var cached: Dictionary={}
		for name in bones:
			if name=="Root":continue
			var value=pose(name);value.origin.y-=compression;value.origin.z-=acceleration_lean*0.20;cached[name]=value
		for name in cached:set_pose(name,cached[name])
	var release=sin(clampf(air_age/0.16,0,1)*PI)*0.13 if not grounded and vertical>0 else 0.0
	for arm_side in ["L","R"]:
		rotate_chain("Arm_"+arm_side,pose("Arm_"+arm_side).origin,Basis(Vector3.RIGHT,shoulder_inertia*0.5-release+landing_strength*sin(clampf((land_age-0.04)/0.28,0,1)*PI)*0.15))
	# The authored idle uses 81% upper/lower arm length. Open smoothly back to
	# normal reach for attacks/charging without moving shoulders or scaling hands.
	arm_action_requested=model.arms[0].rotation.length()>0.1 or model.arms[1].rotation.length()>0.1
	for arm_side in ["L","R"]:
		var upper=pose("Arm_"+arm_side);var lower=pose("Forearm_"+arm_side);var hand_pose=pose("Hand_"+arm_side)
		var scale_now=upper.basis.y.length()
		var extension=lerpf(scale_now,1.0,action_arm_extension)/maxf(0.01,scale_now)
		var new_elbow=upper.origin+(lower.origin-upper.origin)*extension
		hand_pose.origin=new_elbow+(hand_pose.origin-lower.origin)*extension
		lower.origin=new_elbow;upper.basis=upper.basis.scaled(Vector3.ONE*extension);lower.basis=lower.basis.scaled(Vector3.ONE*extension)
		set_pose("Arm_"+arm_side,upper);set_pose("Forearm_"+arm_side,lower);set_pose("Hand_"+arm_side,hand_pose)
	if not model.pipe_combo_pose.is_empty():apply_pipe_combo(model.pipe_combo_pose)
	elif model.charge_pose_weight>0.001:apply_charge_pose()
	# Existing combat / charging controls remain the source of attack poses.
	for i in range(2):
		var side="L" if i==0 else "R"
		var shoulder=pose("Arm_"+side).origin
		var overlay=model.arms[i].rotation
		if model.pipe_combo_pose.is_empty() and model.charge_pose_weight<=0.001 and overlay.length()>0.0001: rotate_chain("Arm_"+side,shoulder,Basis.from_euler(overlay))
	# Preserve the existing midair tuck controlled by double-jump input.
	for i in range(2):
		if not grounded and absf(model.legs[i].rotation.x)>0.01:
			var name="Leg_"+("L" if i==0 else "R")
			rotate_chain(name,pose(name).origin,Basis(Vector3.RIGHT,model.legs[i].rotation.x*0.45))
	if grounded and not dodge and not free_feet:
		solve_ground_feet()
	else:
		contact=[false,false]
		initialized=false
	attach_weapons()

func solve_ground_feet():
	var g=gait()
	var moving=speed>0.18 and actual_speed>0.04
	var world_from_skeleton=skeleton.global_transform
	var local_from_world=world_from_skeleton.affine_inverse()
	var origin=model.global_position
	# Compensate for capsule clearance and uneven ground before solving the legs.
	# This preserves support contacts rather than releasing an unreachable foot.
	var needed_drop=0.0
	for i in range(2):
		var side="L" if i==0 else "R"
		var p=fposmod(phase+i*0.5,1)
		if p>=g.x and moving: continue
		var fwd=g.y*(0.5-p/g.x) if moving else 0.0
		var base: Vector3=rest["Foot_"+side].origin
		var nominal=model.global_transform*(Vector3(base.x,0,0)+direction*fwd)
		var support=terrain(nominal)
		if support.is_empty(): continue
		var ground: Vector3=anchor[i] if contact[i] and initialized else support.position
		var support_normal: Vector3=normal[i] if contact[i] and initialized else support.normal
		var goal=ground+support_normal*0.185
		# Predict the same toe pivot used below before determining pelvis clearance.
		# Large backward strides otherwise reach farther after the initial solve.
		if moving and p/g.x>0.72:
			var heading=Basis(Vector3.UP,foot_yaw[i] if contact[i] and initialized else model.global_rotation.y)
			var toe=goal+heading*Vector3(0,-0.185,-0.46)
			goal=toe+Basis(heading*Vector3.RIGHT,-smoothstep(0.72,1,p/g.x)*0.25)*(goal-toe)
		var hip=world_from_skeleton*pose("Leg_"+side).origin
		var horizontal=Vector2(hip.x-goal.x,hip.z-goal.z).length()
		var reach=rest["Leg_"+side].origin.distance_to(rest["Shin_"+side].origin)+rest["Shin_"+side].origin.distance_to(base)
		var height=sqrt(maxf(0.05,reach*reach*0.99-horizontal*horizontal))
		needed_drop=maxf(needed_drop,hip.y-goal.y-height)
	pelvis_offset=maxf(clampf(needed_drop,0,0.28),move_toward(pelvis_offset,0,dt*0.8))
	if pelvis_offset>0.0001:
		var offset=local_from_world.basis*(Vector3.DOWN*pelvis_offset)
		var poses: Dictionary={}
		for name in bones:
			if name=="Root":continue
			var value=pose(name);value.origin+=offset;poses[name]=value
		for name in poses:set_pose(name,poses[name])
	if initialized and origin.distance_to(last_origin)>2.5:
		initialized=false
		contact=[false,false]
	for i in range(2):
		var side="L" if i==0 else "R"
		var foot_rest: Transform3D=rest["Foot_"+side]
		var p=fposmod(phase+i*0.5,1)
		var stance=p<g.x or not moving
		var fwd=g.y*(0.5-p/g.x) if p<g.x else g.y*(-0.5+smoothstep(0,1,(p-g.x)/(1-g.x)))
		var lift=0.0 if p<g.x else pow(sin(PI*pow((p-g.x)/(1-g.x),.65)),1.15)*g.z
		if not moving: fwd=0;lift=0
		# Ground probes use the actor frame, independent of torso banking/attacks.
		var local_point=Vector3(foot_rest.origin.x,0,0)+direction*fwd
		var nominal=model.global_transform*local_point
		var hit=terrain(nominal)
		if hit.is_empty():
			contact[i]=false
			continue
		var desired: Vector3=hit.position+Vector3.UP*(0.185+lift)
		if moving: settling[i]=-1
		if stance and settling[i]<0:
			# At magical travel speeds the contact travels with the body, so
			# the short legs retain a readable cadence instead of snapping back.
			if contact[i] and ronin_speed_scale()>1:
				anchor[i]+=world_velocity*dt*(1.0-1.0/ronin_speed_scale())
				anchor[i].y=hit.position.y
			if not contact[i] or not initialized:
				anchor[i]=hit.position
				normal[i]=hit.normal
				foot_yaw[i]=model.global_rotation.y
				step_events+=1
			contact[i]=true
			desired=anchor[i]+normal[i]*0.185
			# If a standing pivot/stop leaves a foot too far behind, take a small
			# corrective step instead of stretching the mesh or dragging an anchor.
			var hip_world=world_from_skeleton*pose("Leg_"+side).origin
			if Vector2(hip_world.x-desired.x,hip_world.z-desired.z).length()>0.62:
				contact[i]=false
				desired=hit.position+Vector3.UP*0.185
		else:
			contact[i]=false
		if not moving:
			var rest_goal: Vector3=hit.position+Vector3.UP*0.185
			var separation=Vector2(anchor[i].x-hit.position.x,anchor[i].z-hit.position.z).length()
			if settling[i]<0 and settling[1-i]<0 and initialized and separation>0.16:
				settling[i]=0
				settle_start[i]=targets[i]
			if settling[i]>=0:
				settling[i]=minf(1,settling[i]+dt/0.16)
				desired=settle_start[i].lerp(rest_goal,smoothstep(0,1,settling[i]))+Vector3.UP*sin(PI*settling[i])*0.075
				contact[i]=false
				if settling[i]>=1:
					settling[i]=-1;anchor[i]=hit.position;normal[i]=hit.normal;foot_yaw[i]=model.global_rotation.y
					contact[i]=true;desired=rest_goal;step_events+=1
		# Swing feet approach the next contact smoothly; planted targets never lerp.
		if not initialized: targets[i]=desired
		if contact[i]: targets[i]=desired
		else: targets[i]=targets[i].lerp(desired,1-exp(-dt*35))
		var yaw=foot_yaw[i] if contact[i] else model.global_rotation.y
		var world_heading=Basis(Vector3.UP,yaw)
		var ground_normal: Vector3=normal[i] if contact[i] else Vector3.UP
		var tilt=Basis(Quaternion(Vector3.UP,ground_normal))
		var foot_basis=local_from_world.basis*tilt*world_heading*foot_rest.basis
		var goal: Vector3=local_from_world*targets[i]
		if not contact[i] and moving:
			var swing=clampf((p-g.x)/(1-g.x),0,1)
			var lateral=(local_from_world.basis*world_heading*Vector3.RIGHT).normalized()
			foot_basis=Basis(lateral,-0.40*sin(PI*swing))*foot_basis
		# Controlled toe-off rolls around the toe rather than rotating through floor.
		if contact[i] and moving and p/g.x>0.72:
			var toe_roll=smoothstep(0.72,1,p/g.x)*0.25
			var lateral=(local_from_world.basis*world_heading*Vector3.RIGHT).normalized()
			var roll=Basis(lateral,-toe_roll)
			var toe=goal+(local_from_world.basis*world_heading)*Vector3(0,-0.185,-0.46)
			goal=toe+roll*(goal-toe)
			foot_basis=roll*foot_basis
		solve_leg(side,goal,foot_basis)
		plant_error[i]=(world_from_skeleton*pose("Foot_"+side).origin).distance_to(world_from_skeleton*goal) if contact[i] else 0.0
		last_goal[i]=world_from_skeleton*goal
	initialized=true
	last_origin=origin

func solve_leg(side: String,goal: Vector3,foot_basis: Basis):
	var hip=pose("Leg_"+side).origin
	var h0: Vector3=rest["Leg_"+side].origin
	var k0: Vector3=rest["Shin_"+side].origin
	var a0: Vector3=rest["Foot_"+side].origin
	var upper=h0.distance_to(k0)
	var lower=k0.distance_to(a0)
	var delta=goal-hip
	var distance=clampf(delta.length(),0.08,(upper+lower)*0.998)
	var axis=delta.normalized()
	var pole=Vector3.FORWARD
	pole=(pole-axis*pole.dot(axis)).normalized()
	var along=(upper*upper-lower*lower+distance*distance)/(2*distance)
	var knee=hip+axis*along+pole*sqrt(maxf(0,upper*upper-along*along))
	var ankle=hip+axis*distance
	var upper_basis=Basis(Quaternion((k0-h0).normalized(),(knee-hip).normalized()))*rest["Leg_"+side].basis
	var lower_basis=Basis(Quaternion((a0-k0).normalized(),(ankle-knee).normalized()))*rest["Shin_"+side].basis
	set_pose("Leg_"+side,Transform3D(upper_basis,hip))
	set_pose("Shin_"+side,Transform3D(lower_basis,knee))
	set_pose("Foot_"+side,Transform3D(foot_basis.orthonormalized(),ankle))

func attach_weapons():
	# Grip follows the articulated wrist/hand, not the old shoulder proxy.
	var hand=pose("Hand_R")
	var delta=hand*rest.Hand_R.affine_inverse()
	var grip=Vector3(1.335,1.285,-0.015)
	var grip_world=skeleton.global_transform*(delta*grip)
	var basis_world=skeleton.global_basis*delta.basis*Basis(Vector3.BACK,PI/2)
	model.pipe.global_transform=Transform3D(basis_world,grip_world)
	if is_instance_valid(model.chain_pipe):model.chain_pipe.global_transform=model.pipe.global_transform
	# Coin has its own presentation scale set by charging/surge gameplay.
	var coin_scale=model.coin.scale
	model.coin.global_transform=Transform3D(basis_world,grip_world+basis_world*Vector3(0,0,-0.1))
	model.coin.scale=coin_scale

func reset():
	action_arm_extension=0;arm_action_requested=false
	lateral_response=0;lateral_acceleration=0;previous_local_velocity=Vector3.ZERO
	phase=0;speed=0;actual_speed=0;old_speed=0;free_feet=false
	local_velocity=Vector3.ZERO;world_velocity=Vector3.ZERO
	move_blend=Vector2.ZERO;direction=Vector3.FORWARD
	air_blend=0;air_age=0;land_age=1;landing_weight=0
	shoulder_inertia=0;pivot_twist=0;pivot_trail=0;jump_compression=0;landing_strength=0
	grounded=true;was_grounded=true
	contact=[false,false];initialized=false;pelvis_offset=0;settling=[-1.0,-1.0]
	dirty=true

func apply_pose_body(p: Dictionary):
	# Pelvis drives the chest and shoulders, with fixed-length limbs and ground IK.
	var cached: Dictionary={}
	for name in bones:
		if name=="Root":continue
		var value=pose(name);value.origin+=p.offset;cached[name]=value
	for name in cached:set_pose(name,cached[name])
	rotate_chain("Pelvis",pose("Pelvis").origin,Basis.from_euler(p.hip))
	rotate_chain("Spine",pose("Spine").origin,Basis.from_euler(p.chest*0.45))
	rotate_chain("Chest",pose("Chest").origin,Basis.from_euler(p.chest*0.55))
	rotate_chain("Neck",pose("Neck").origin,Basis.from_euler(Vector3(-p.chest.x*0.4,-(p.hip.y+p.chest.y)*0.4,0)))
	rotate_chain("Arm_L",pose("Arm_L").origin,Basis.from_euler(p.guard))

func apply_pipe_combo(p: Dictionary):
	apply_pose_body(p)
	# A continuous wrist path makes the supplied pipe trace three distinct arcs.
	var weight=smoothstep(0,0.18,1.0-attack) if model.pipe_combo_stage==1 else 1.0
	if model.pipe_combo_stage==3:weight=1.0-smoothstep(0.78,1,1.0-attack)
	solve_combo_arm(p.wrist+p.offset,weight,p.roll,p.aim)

func solve_combo_arm(target: Vector3,weight: float,roll: float,aim: Vector3,reach_limit: float=0.995):
	var upper_pose=pose("Arm_R");var lower_pose=pose("Forearm_R");var hand_pose=pose("Hand_R")
	var shoulder=upper_pose.origin
	var upper_length=shoulder.distance_to(lower_pose.origin)
	var lower_length=lower_pose.origin.distance_to(hand_pose.origin)
	var goal=hand_pose.origin.lerp(target,weight)
	var ray=goal-shoulder
	var distance=clampf(ray.length(),0.08,(upper_length+lower_length)*reach_limit)
	var axis=ray.normalized()
	var pole=Vector3(0.8,-0.6,0.25)
	pole=(pole-axis*pole.dot(axis)).normalized()
	var along=(upper_length*upper_length-lower_length*lower_length+distance*distance)/(2*distance)
	var elbow=shoulder+axis*along+pole*sqrt(maxf(0,upper_length*upper_length-along*along))
	var wrist=shoulder+axis*distance
	var upper_rotation=Basis(Quaternion((lower_pose.origin-shoulder).normalized(),(elbow-shoulder).normalized()))
	var fore_rotation=Basis(Quaternion((hand_pose.origin-lower_pose.origin).normalized(),(wrist-elbow).normalized()))
	upper_pose.basis=upper_rotation*upper_pose.basis
	lower_pose.basis=fore_rotation*lower_pose.basis;lower_pose.origin=elbow
	var follow_basis=fore_rotation*hand_pose.basis
	var pipe_basis=Basis(aim.normalized(),roll*0.15)*Basis.looking_at(aim.normalized(),Vector3.UP)
	var grip_basis=pipe_basis*Basis(Vector3.BACK,-PI/2)*rest.Hand_R.basis
	hand_pose.basis=Basis(follow_basis.get_rotation_quaternion().slerp(grip_basis.get_rotation_quaternion(),weight))
	hand_pose.origin=wrist
	set_pose("Arm_R",upper_pose);set_pose("Forearm_R",lower_pose);set_pose("Hand_R",hand_pose)

func apply_charge_pose():
	# Compact right-side power stance. Reach is capped to retain a bent elbow.
	var p={"hip":Vector3(-0.035,-0.22,-0.045),"chest":Vector3(0.035,-0.20,-0.045),"offset":Vector3(0.025,-0.095,0.015),"wrist":Vector3(0.76,1.25,0.025),"guard":Vector3(1.0,-0.15,-0.20),"roll":0.2,"aim":Vector3(1,0.06,-0.08)}
	if model.charge_slot==2 and model.charge_release>=0:
		var throw=smoothstep(0.30,0.52,model.charge_release)
		p.wrist=p.wrist.lerp(Vector3(0.35,1.28,-0.52),throw)
		p.aim=p.aim.lerp(Vector3(0,0,-1),throw).normalized()
		p.chest.x+=throw*0.10
	var weight=model.charge_pose_weight
	var body_pose=PipeCombo.interpolate(PipeCombo.IDLE,p,weight)
	apply_pose_body(body_pose)
	solve_combo_arm(p.wrist+body_pose.offset,weight,p.roll,p.aim,lerpf(0.995,0.88,weight))
