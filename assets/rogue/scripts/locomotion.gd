extends RefCounted
## Distance-driven joint animation; action poses remain authored by Actor.
var phase: float = 0.0
var weight: float = 0.0
var direction: Vector3 = Vector3.BACK
var air: float = 0.0
var crouch: float = 0.0

func reset() -> void:
 phase = 0.0
 weight = 0.0
 direction = Vector3.BACK
 air = 0.0
 crouch = 0.0

func apply(actor, state: Dictionary, dt: float, time: float, movement: float) -> void:
 var grounded: bool = state.get("grounded", true)
 var special: bool = float(state.get("roll", 0)) > 0 or state.get("travel") != null
 var speed: float = float(state.get("motionSpeed", movement * 5.0))
 var target: float = clampf(speed / 6.0, 0, 1) if grounded and not special else 0.0
 var blend: float = 1.0-exp(-dt*16.0)
 weight = lerpf(weight, target, blend)
 air = lerpf(air, 0.0 if grounded or special else 1.0, 1.0-exp(-dt*20.0))
 crouch = lerpf(crouch, 1.0 if state.get("crouched", false) else 0.0, blend)
 var local: Vector3 = state.get("localMotion", Vector3.BACK * speed)
 if local.length_squared() > 0.04:
  direction = direction.lerp(local.normalized(), blend)
 if grounded and not special:
  phase += speed * dt * 1.45 / (1.0 + maxf(0, speed-10.0)*0.045)
 var stride: float = sin(phase) * weight * lerpf(0.64, 0.92, clampf(speed/18.0, 0, 1))
 var sideways: float = direction.x
 var forward: float = direction.z
 actor._r("Leg_L", stride * forward, 0, -stride * sideways)
 actor._r("Leg_R", -stride * forward, 0, stride * sideways)
 actor._p("Leg_L", 0, maxf(0, cos(phase)) * weight * 0.075)
 actor._p("Leg_R", 0, maxf(0, -cos(phase)) * weight * 0.075)
 actor._r("Arm_L", -stride * forward * 0.5, 0, stride * sideways * 0.23)
 actor._r("Arm_R", stride * forward * 0.5, 0, -stride * sideways * 0.23)
 actor._r("Body", weight * forward * 0.07, stride * 0.045, -weight * sideways * 0.055)
 actor._r("Head", -weight * forward * 0.04, -stride * 0.025)
 actor.model.position.y = (1.0-cos(phase*2.0))*0.027*weight + sin(time*2.4)*0.018*(1.0-weight)
 actor.model.rotation = Vector3.ZERO
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
