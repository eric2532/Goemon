extends "res://assets/characters/musashi/animations/approved_motion.gd"
## Keep Edo's casting choreography on Goemon's unchanged T-pose skeleton.
const UserRun=preload("res://scripts/user_stride_run.gd")
var user_run: RefCounted
const RunBody = preload("res://scripts/goemon_reference_run_body.gd")
const JumpPose = preload("res://scripts/goemon_reference_jump.gd")
var reference_jump_flip=-1.0
var jump_pose = JumpPose.new()
var idle_breath=preload("res://scripts/goemon_idle_breath.gd").new()
func _init(m):
	super(m)
	user_run=UserRun.new(model.skeleton)
	for side in ["L", "R"]:
		var shoulder: Vector3 = rest["Arm_" + side].origin
		var turn = Basis(Vector3.BACK, deg_to_rad(75.0 if side == "L" else -75.0))
		var lower = Transform3D(turn, shoulder - turn * shoulder)
		for bone in ["Arm_", "Forearm_", "Hand_"]:
			rest[bone + side] = lower * rest[bone + side]

func set_rot(bone_name: String, v: Vector3):
	super.set_rot("Pelvis" if bone_name == "Hips" else bone_name, v)

func update(delta,velocity,on_ground,vy,attack,is_dodging):
	super.update(delta,velocity,on_ground,vy,attack,is_dodging)
	var c=model.combat
	var busy=c!=null and c.state not in [c.State.IDLE,c.State.MOVING]
	idle_breath.update(delta,speed,grounded,busy or dodge or free_feet)

func evaluate():
	if not dirty:return
	super.evaluate()
	var c = model.combat
	if dodge or (free_feet and reference_jump_flip<0) or (c != null and not c.available()):return
	if grounded:apply_reference_run()
	if gait.air>.001:jump_pose.apply(model.skeleton,vertical,gait.air*JumpPose.flip_weight(reference_jump_flip),grounded)
	idle_breath.apply(model.skeleton)

func reset():
	super.reset();reference_jump_flip=-1;idle_breath.reset()

func apply_reference_run():
	var authored=UserRun.weight(speed,gait.direction.z)*(1.0-gait.air)
	if authored>.001:
		user_run.apply(fposmod(phase/TAU,1.0),authored)
		return
	var weight: float = gait.weight * maxf(0, gait.direction.z)
	if weight < .001:return
	var stride: float = fposmod(phase / TAU, 1.0)
	# Replace the old rigid gait's separate hip lifts as a connected pose.
	# Leaving those leg-root offsets in place fights the shared weight shift.
	var body_frame = pose("Root") * rest.Root.affine_inverse()
	RunBody.blend_base(model.skeleton, rest, body_frame, weight)
	RunBody.apply(model.skeleton, stride, weight)
	RunBody.arms(model.skeleton, stride, weight)
	for i in range(2):
		var side = "L" if i == 0 else "R"
		var step = fposmod(stride + i * .5, 1.0)
		var stance = RunBody.stance_fraction(gait.stride_speed,.72)
		var u = clampf((step - stance) / (1.0 - stance), 0, 1)
		var travel = .72 * (.5 - step / stance) if step < stance else lerpf(-.36, .36, smoothstep(0, 1, u))
		var lift = .49 * sin(PI * sqrt(u)) if step >= stance else 0.0
		var foot_goal: Vector3 = rest["Foot_" + side].origin + Vector3(0, lift, -travel)
		foot_goal.x += RunBody.swing_inset(side,u)
		var recovery = sin(PI * sqrt(u)) * weight
		var frame = Basis.IDENTITY.slerp(RunBody.hip_frame(model.skeleton), recovery)
		foot_goal = pose("Pelvis").origin + frame * (foot_goal - pose("Pelvis").origin)
		# Clearance is measured above the ground, while the recovery turns with the hips.
		foot_goal.y = rest["Foot_" + side].origin.y + lift
		solve_run_leg(side, pose("Foot_" + side).origin.lerp(foot_goal, weight), -1.2 * sin(PI * sqrt(u)) * weight, frame)

func pose(name_: String) -> Transform3D:
	return model.skeleton.get_bone_global_pose(model.skeleton.find_bone(name_))

func set_pose(name_: String, value: Transform3D):
	model.skeleton.set_bone_global_pose(model.skeleton.find_bone(name_), value)

func solve_run_leg(side: String, goal: Vector3, heel: float, frame: Basis):
	var hip = pose("Leg_" + side).origin
	var h0: Vector3 = rest["Leg_" + side].origin
	var k0: Vector3 = rest["Shin_" + side].origin
	var a0: Vector3 = rest["Foot_" + side].origin
	var upper = h0.distance_to(k0)
	var lower = k0.distance_to(a0)
	var ray = goal - hip
	var distance = clampf(ray.length(), .08, (upper + lower) * .998)
	var axis = ray.normalized()
	var pole = frame * Vector3.FORWARD
	pole = (pole - axis * pole.dot(axis)).normalized()
	var along = (upper * upper - lower * lower + distance * distance) / (2 * distance)
	var knee = hip + axis * along + pole * sqrt(maxf(0, upper * upper - along * along))
	var ankle = hip + axis * distance
	set_pose("Leg_" + side, Transform3D(frame * Basis(Quaternion((k0 - h0).normalized(), frame.inverse() * (knee - hip).normalized())) * rest["Leg_" + side].basis, hip))
	set_pose("Shin_" + side, Transform3D(frame * Basis(Quaternion((a0 - k0).normalized(), frame.inverse() * (ankle - knee).normalized())) * rest["Shin_" + side].basis, knee))
	set_pose("Foot_" + side, Transform3D(frame * Basis(Vector3.RIGHT, heel) * rest["Foot_" + side].basis, ankle))

func apply_locomotion():
	var previous=phase
	super.apply_locomotion()
	if grounded and not dodge and not free_feet and speed>2.2 and gait.direction.z>0:
		phase=previous+UserRun.cadence(speed)*TAU*dt
		gait.phase=phase
