extends RefCounted
## Distance-driven joint animation; action poses remain authored by Actor.
const UserRun=preload("res://scripts/user_stride_run.gd")
const RunBody = preload("res://scripts/goemon_reference_run_body.gd")
const GroundResponse=preload("res://scripts/ground_movement_response.gd")
const SteadyRun=preload("res://scripts/steady_weapon_run.gd")
var phase: float = 0.0
var speed: float = 0.0
var stride_speed: float = 0.0
var weight: float = 0.0
var direction: Vector3 = Vector3.BACK
var air: float = 0.0
var crouch: float = 0.0
var side_lean: float = 0.0
var neck_lean: float = 0.0
var strafe_yaw: float = 0.0
var carry_side: float = 0.0
var carry_weight: float = 0.0

func reset() -> void:
 phase = 0.0
 speed = 0.0
 stride_speed = 0.0
 weight = 0.0
 direction = Vector3.BACK
 air = 0.0
 crouch = 0.0
 side_lean = 0.0
 neck_lean = 0.0
 strafe_yaw = 0.0
 carry_side = 0.0
 carry_weight = 0.0

func apply(actor, state: Dictionary, dt: float, time: float, movement: float) -> void:
 var grounded: bool = state.get("grounded", true)
 var special: bool = float(state.get("roll", 0)) > 0 or state.get("travel") != null
 speed = float(state.get("motionSpeed", movement * 5.0))
 # Keep the leg path continuous when the controller stops or hits a wall.
 # The cycle clock still follows actual speed; only stance shape eases out.
 stride_speed = lerpf(stride_speed, speed, 1.0-exp(-dt*10.0))
 var target: float = clampf(speed / 6.0, 0, 1) if grounded and not special else 0.0
 var blend: float = 1.0-exp(-dt*16.0)
 var motion_blend: float = 1.0-exp(-dt*GroundResponse.POSE_RESPONSE)
 weight = lerpf(weight, target, motion_blend)
 air = lerpf(air, 0.0 if grounded or special else 1.0, 1.0-exp(-dt*20.0))
 crouch = lerpf(crouch, 1.0 if state.get("crouched", false) else 0.0, blend)
 var local: Vector3 = state.get("localMotion", Vector3.BACK * speed)
 if local.length_squared() > 0.04:
  direction = direction.lerp(local.normalized(), motion_blend)
 if grounded and not special:
  phase += (UserRun.cadence(speed) if UserRun.enabled(actor.id) and speed>2.2 else RunBody.cadence(speed)) * TAU * dt
 var stride: float = sin(phase) * weight * lerpf(0.64, 0.92, clampf(speed/18.0, 0, 1))
 var sideways: float = direction.x
 var forward: float = direction.z
 # Shoulders lead the weight shift; the neck follows with a smaller, softer tilt.
 # Preserve committed attack poses and guards instead of leaning the weapon away.
 var busy: bool = state.get("attack") != null or state.get("blocking", false) or float(state.get("shot",0)) > 0
 var body_motion: float = SteadyRun.swing_scale(actor.id,state)
 var lean_target: float = -sideways * weight * (0.2 if busy else 1.0)
 side_lean = lerpf(side_lean, lean_target, 1.0-exp(-dt*12.0))
 neck_lean = lerpf(neck_lean, side_lean, 1.0-exp(-dt*10.0))
 # Turn the stepping stance a little toward travel. Counter-turn the upper
 # body/head so camera-facing intent remains readable, without a rigid lean.
 strafe_yaw = lerpf(strafe_yaw,sideways*weight*.524*body_motion,1-exp(-dt*10))
 var pose_yaw: float = strafe_yaw
 var attack = state.get("attack")
 if attack is Dictionary:pose_yaw *= 1-actor._c(actor._phase(attack),1,1,1)
 elif busy or special:pose_yaw *= .2
 var step_direction: Vector3 = direction.rotated(Vector3.UP,-pose_yaw)
 var step_forward: float = step_direction.z
 var step_side: float = step_direction.x*.72
 actor._r("Leg_L", stride * step_forward, 0, -stride * step_side)
 actor._r("Leg_R", -stride * step_forward, 0, stride * step_side)
 actor._p("Leg_L", 0, maxf(0, cos(phase)) * weight * 0.075)
 actor._p("Leg_R", 0, maxf(0, -cos(phase)) * weight * 0.075)
 actor._r("Arm_L", -stride * forward * 0.5, 0, stride * sideways * 0.23)
 actor._r("Arm_R", stride * forward * 0.5, 0, -stride * sideways * 0.23)
 actor._r("Body", weight * forward * 0.07, stride * 0.025*body_motion, side_lean * 0.09*body_motion)
 actor._r("Head", -weight * forward * 0.04, -stride * 0.015*body_motion-pose_yaw*.10, neck_lean * 0.02*body_motion)
 actor._p("Body", -side_lean * 0.018*body_motion)
 _carry(actor,state,dt,sideways,busy or special or not grounded)
 # Goemon bodies breathe through the chest, keeping their soles on the floor.
 var idle_bob: float = 0.0 if actor.id=="edo" or actor.get("cosplay_rig")!=null else sin(time*2.4)*0.018*(1.0-weight)
 actor.model.position.y = (1.0-cos(phase*2.0))*0.027*weight*body_motion + idle_bob
 actor.model.rotation = Vector3(0,pose_yaw,0)
 var rise: float = clampf(float(state.get("vertical", 0))/12.0, -1, 1)
 actor._r("Leg_L", -air*(0.32+maxf(0,rise)*0.4))
 actor._r("Leg_R", air*(0.22+maxf(0,rise)*0.25))
 actor._r("Arm_L", -air*0.22, 0, air*0.12)
 actor._r("Arm_R", -air*0.22, 0, -air*0.12)
 var landing: float = float(state.get("landing", 0))
 actor.model.position.y -= landing * 0.13
 actor._r("Leg_L", -landing*0.28)
 actor._r("Leg_R", -landing*0.28)
 actor._r("Body", landing*0.12)
 # A smoothed stance keeps toggling Get Down from popping half a metre.
 actor.model.position.y -= crouch*0.52
 actor._r("Body", crouch*0.2)
 actor._r("Leg_L", -crouch*0.65)
 actor._r("Leg_R", -crouch*0.65)

func flip(actor, state: Dictionary) -> void:
 if actor.id in ["ninja","ranger","explorer"]:return # Authored tucked flip owns these bodies.
 var progress: float = float(state.get("flip", -1.0))
 if progress < 0 or progress > 1 or state.get("travel") != null or float(state.get("roll", 0)) > 0:
  return
 # Rotate around the hips, not the soles; retain the real collision/jump arc.
 var eased: float = progress*progress*(3.0-2.0*progress)
 var tuck: float = sin(progress*PI)
 actor._r("Leg_L", -tuck*0.85)
 actor._r("Leg_R", -tuck*0.85)
 actor._r("Arm_L", -tuck*0.45, 0, -tuck*0.16)
 actor._r("Arm_R", -tuck*0.45, 0, tuck*0.16)
 actor.model.rotation.x += eased*TAU
 var pivot := Vector3(0, 1.05, 0)
 actor.model.position += pivot-actor.model.basis*pivot

func _carry(actor, state: Dictionary, dt: float, sideways: float, busy: bool) -> void:
 if actor.id in ["ranger","knight"] and SteadyRun.enabled(actor.id,state):return
 # Follow the torso more slowly, so direction changes transfer weight to the hand.
 carry_side = lerpf(carry_side,sideways,1-exp(-dt*7.5))
 var attacking: bool = state.get("attack") is Dictionary
 var target: float = carry_weight if attacking else (weight*absf(sideways) if not busy and float(state.get("drinkGesture",0))<=0 else 0.0)
 carry_weight = lerpf(carry_weight,target,1-exp(-dt*(22 if busy else 9)))
 var amount: float = carry_weight
 # Remove locomotion's weapon offset by the committed contact pose. The short
 # opening fade avoids a pop when attacking from a low moving carry.
 var attack = state.get("attack")
 if attack is Dictionary:
  var attack_phase: Dictionary = actor._phase(attack)
  amount *= 1-actor._c(attack_phase,1,1,1)
 if amount < .001:return
 var heavy: bool = actor.id in ["magic-swordsman","knight","dragoon"]
 var lag: float = carry_side*amount
 actor._r("Arm_R", -.16*amount, lag*.20, lag*.20)
 actor._p("Arm_R", -.065*amount-lag*.04, .045*amount, -.075*amount)
 actor._r("Arm_L", .08*amount, -lag*.12, -lag*.15)
 # Local negative X is the authored right hand. Keep that handedness for both
 # strafe directions; the blade trails lower on left travel and opens on right.
 if actor.id in actor.WEAPON_AXES:
  var down: float = -.22 if heavy else -.12
  if actor.id=="mage":down=.65
  if actor.id=="dragoon":down=.12
  var target_axis := Vector3(-.94-carry_side*.12,down, .48-carry_side*.12)
  actor._aim_weapon("Weapon_Cutlass",actor.WEAPON_AXES[actor.id],target_axis,amount*.92)
 if actor.id=="explorer":
  actor._aim_weapon("Weapon_Pistol",actor.LEFT_BLADE,Vector3(.9,-.12,.45+carry_side*.12),amount*.8)
