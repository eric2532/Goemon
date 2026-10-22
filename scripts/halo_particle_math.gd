extends RefCounted
## Native effect distributions, state timing, color ranges and airborne point
## physics. Input point physics is normalized manifest `data`, not `map_values`.
const AIR_MASS_OVER_RADIUS_CUBED=0.0011*118613.34
const COMPILED_FRICTION_SCALE=10000.0
const GRAVITY_METRES=9.81

static func sample(value:Variant,fallback:float=0.0)->float:
 if value is float or value is int:return float(value)
 if value is Dictionary:
  var lower=float(value.get("from",fallback))
  var upper=float(value.get("to",lower))
  return lerpf(lower,upper,randf()) if lower!=upper else lower
 return fallback

static func color(value:Dictionary,fallback:Color=Color.WHITE)->Color:
 return Color(float(value.get("r",fallback.r)),float(value.get("g",fallback.g)),float(value.get("b",fallback.b)),float(value.get("a",fallback.a)))

static func random_color(lower:Variant,upper:Variant,hsv:bool=false)->Color:
 var a:Color=lower if lower is Color else color(lower if lower is Dictionary else {})
 var b:Color=upper if upper is Color else color(upper if upper is Dictionary else {})
 var fraction=randf()
 if not hsv:return a.lerp(b,fraction)
 # Native HSV interpolation crosses the hue seam by the shorter arc.
 var hue_delta=b.h-a.h
 if hue_delta>.5:hue_delta-=1.0
 elif hue_delta<-.5:hue_delta+=1.0
 return Color.from_hsv(fposmod(a.h+hue_delta*fraction,1.0),lerpf(a.s,b.s,fraction),lerpf(a.v,b.v,fraction),lerpf(a.a,b.a,fraction))

static func native_vector(value:Dictionary)->Vector3:
 return Vector3(-float(value.get("j",value.get("y",0.0))),float(value.get("k",value.get("z",0.0))),-float(value.get("i",value.get("x",0.0))))

static func emission_fraction(function_name:String,t:float)->float:
 # The native initial previous-event fraction is -1, before start bursts.
 if t<0.0:return 0.0
 var fraction=clampf(t,0.0,1.0)
 match function_name:
  "start":return 1.0
  "end":return 1.0 if fraction>=1.0 else 0.0
  "buildup":return fraction*fraction
  "falloff":return 1.0-(1.0-fraction)*(1.0-fraction)
  "quadratic":return smoothstep(0.0,1.0,fraction)
 return fraction

static func emission_time(function_name:String,fraction:float)->float:
 var amount=clampf(fraction,0.0,1.0)
 match function_name:
  "start":return 0.0
  "end":return 1.0
  "buildup":return sqrt(amount)
  "falloff":return 1.0-sqrt(1.0-amount)
  "quadratic":
   # Invert the monotonic smoothstep cumulative function without an unstable
   # cubic division near its flat endpoints.
   if amount==0.0 or amount==1.0:return amount
   var lower=0.0
   var upper=1.0
   for iteration in 32:
    var middle=(lower+upper)*.5
    if smoothstep(0.0,1.0,middle)<amount:lower=middle
    else:upper=middle
   return (lower+upper)*.5
 return amount

static func blend_ease(function_name:String,t:float)->float:
 var fraction=clampf(t,0.0,1.0)
 match function_name.replace(" ","_"):
  "early":return sqrt(fraction)
  "very_early":return sqrt(sqrt(fraction))
  "late":return fraction*fraction
  "very_late":return pow(fraction,4.0)
  "cosine":return (1.0-cos(PI*fraction))*.5
 return fraction

static func physics_velocity(velocity:Vector3,radius_halo:float,definition:Dictionary,delta:float)->Vector3:
 if delta<=0.0:return velocity
 var result=velocity
 # Runtime buoyancy is signed: stones have negative scale, hot smoke positive.
 if int(definition.get("flags",0))&32==0:
  result.y+=GRAVITY_METRES*float(definition.get("air_gravity_scale",0.0))*delta
 var radius=maxf(0.0,radius_halo)
 if radius==0.0:return result
 # Friction scales with area, mass with volume. The common radius squared
 # cancels; native point physics includes the displaced air's inertia.
 var friction=float(definition.get("air_friction",0.0))*COMPILED_FRICTION_SCALE
 var mass_per_area=(float(definition.get("scaled_density",0.0))+AIR_MASS_OVER_RADIUS_CUBED)*radius
 var drag=clampf(delta*friction/mass_per_area,0.0,1.0) if mass_per_area!=0.0 else (1.0 if friction>0.0 else 0.0)
 return result*(1.0-drag)

static func state_plan(states:Array)->Array:
 var plan:Array=[]
 var start=0.0
 for index in states.size():
  var data:Dictionary=states[index]
  var hold=maxf(0.0,sample(data.get("duration_bounds")))
  # Native nonloop state machines die as soon as their last hold expires.
  var transition=maxf(0.0,sample(data.get("transition_time_bounds"))) if index+1<states.size() else 0.0
  var end=start+hold+transition
  plan.append({"data":data,"state":index,"start":start,"hold":hold,"transition":transition,"end":end})
  start=end
 return plan
