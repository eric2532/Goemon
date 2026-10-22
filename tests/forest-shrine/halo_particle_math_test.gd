extends SceneTree
## Endpoint timing, mass/gravity sign, and HSV wrapping protect native effects
## against frame-dependent bursts and falling smoke/rising stone regressions.
var checks=0
var failures=0
var math
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func near(value:float,want:float,label_:String,tolerance:float=.00001):check(absf(value-want)<=tolerance,label_+" (%s expected %s)"%[value,want])
func run():
 check(ResourceLoader.exists("res://scripts/halo_particle_math.gd"),"Native particle math helper exists")
 if failures:finish();return
 math=load("res://scripts/halo_particle_math.gd")
 near(math.sample(null,7.0),7,"Missing bounds use caller fallback")
 near(math.sample(3.5),3.5,"Fixed authored values stay fixed")
 near(math.sample({"from":2,"to":2}),2,"Degenerate native range stays fixed")
 seed(812)
 for i in 30:
  var sampled=math.sample({"from":-3,"to":4})
  check(sampled>=-3 and sampled<=4,"Native range samples within authored bounds")
 check(math.color({"a":.2,"r":.3,"g":.4,"b":.5})==Color(.3,.4,.5,.2),"ARGB fields map into Godot RGBA")
 check(math.color({},Color(.4,.3,.2,.1))==Color(.4,.3,.2,.1),"Absent color fields retain supplied fallback")
 check(math.native_vector({"i":2,"j":3,"k":4})==Vector3(-3,4,-2),"Native forward/left/up maps to Godot basis")
 check(math.native_vector({"x":2,"y":3,"z":4})==Vector3(-3,4,-2),"Position field aliases use the same basis")
 var samples={"start":1.0,"end":0.0,"constant":.25,"buildup":.0625,"falloff":.4375,"quadratic":.15625}
 for name_ in samples:
  near(math.emission_fraction(name_,-1),0,"Prebirth %s has no particles"%name_)
  near(math.emission_fraction(name_,.25),samples[name_],"Native %s cumulative fraction"%name_)
  near(math.emission_fraction(name_,1),1,"Native %s emits full count by end"%name_)
  # The integer deltas telescope to the authored count at any frame partition.
  var emitted=0;var previous=0
  for t in [0.0,.013,.2,.21,.62,.99,1.0]:
   var current=int(math.emission_fraction(name_,t)*37)
   check(current>=previous,"Native %s cumulative count never decreases"%name_)
   emitted+=current-previous;previous=current
  check(emitted==37,"Native %s conserves all 37 particles across uneven frames"%name_)
 for name_ in ["constant","buildup","falloff","quadratic"]:
  for fraction in [0.0,.001,.1,.5,.9,.999,1.0]:
   var birth=math.emission_time(name_,fraction)
   near(math.emission_fraction(name_,birth),fraction,"%s inverse schedules exact cumulative quantile"%name_)
 near(math.emission_time("start",.6),0,"Start distribution schedules births at event start")
 near(math.emission_time("end",.6),1,"End distribution schedules births at event end")
 near(math.blend_ease("early",.25),.5,"Native early transition is square root")
 near(math.blend_ease("very_early",.0625),.5,"Native very early transition is fourth root")
 near(math.blend_ease("late",.5),.25,"Native late transition is square")
 near(math.blend_ease("very_late",.5),.0625,"Native very late transition is fourth power")
 near(math.blend_ease("cosine",.5),.5,"Native cosine transition midpoint")
 near(math.blend_ease("cosine",0),0,"Native cosine starts at zero")
 near(math.blend_ease("cosine",1),1,"Native cosine ends at one")
 seed(987)
 for i in 30:
  var c=math.random_color(Color(0,0,0,0),Color(1,1,1,1))
  near(c.r,c.g,"RGB range uses one shared blend factor")
  near(c.r,c.a,"Native effect alpha follows the same tint fraction")
 var lower=Color.from_hsv(.95,1,1,.2);var upper=Color.from_hsv(.05,1,1,.8)
 for i in 30:
  var hsv=math.random_color(lower,upper,true)
  check(hsv.h>=.9499 or hsv.h<=.0501,"HSV tint takes shortest route across red hue seam")
  near(hsv.s,1,"HSV interpolation preserves saturated native tint")
  near(hsv.v,1,"HSV interpolation preserves brightness")
 for i in 10:
  var tied_hue=math.random_color(Color.RED,Color.CYAN,true)
  check(tied_hue.h<=.50001,"Exactly opposite native hues follow direct interpolation, retaining half-turn sign")
 # Definitions are normalized manifest data: authored air friction, compiled
 # scaled density; native air inertia is added before calculating linear drag.
 var definition={"air_gravity_scale":-1.0,"air_friction":0.0,"scaled_density":100.0,"flags":0}
 var falling=math.physics_velocity(Vector3.ZERO,.1,definition,.2)
 near(falling.y,-1.962,"Negative native buoyancy scale falls under gravity")
 definition.air_gravity_scale=.5
 near(math.physics_velocity(Vector3.ZERO,.1,definition,.2).y,.981,"Positive native buoyancy scale lifts hot smoke")
 definition.flags=32
 check(math.physics_velocity(Vector3(1,2,3),.1,definition,.2)==Vector3(1,2,3),"Native no_gravity flag suppresses buoyancy")
 definition={"air_gravity_scale":0.0,"air_friction":.01,"scaled_density":869.525326,"flags":0}
 near(math.physics_velocity(Vector3(10,0,0),.1,definition,.1).x,9,"Normalized friction restores native coefficient and displaced air mass")
 near(math.physics_velocity(Vector3(10,0,0),.2,definition,.1).x,9.5,"Larger native radius has less drag per mass")
 definition.air_gravity_scale=-1.0
 near(math.physics_velocity(Vector3(10,0,0),.1,definition,.1).y,-.8829,"Native drag damps this step's gravity impulse too")
 definition.air_gravity_scale=0.0
 check(math.physics_velocity(Vector3(10,0,0),0,definition,.1)==Vector3(10,0,0),"Zero native radius has zero area and zero drag")
 check(math.physics_velocity(Vector3(10,0,0),.1,definition,0)==Vector3(10,0,0),"Zero time preserves velocity")
 check(math.physics_velocity(Vector3(10,0,0),.00001,definition,1)==Vector3.ZERO,"High drag clamps without reversing velocity")
 var states=[{"name":"birth","duration_bounds":{"from":.2,"to":.2},"transition_time_bounds":{"from":.3,"to":.3}},{"name":"death","duration_bounds":{"from":.4,"to":.4},"transition_time_bounds":{"from":99,"to":99}}]
 var plan=math.state_plan(states)
 check(plan.size()==2,"Native state plan contains each state")
 near(plan[0].start,0,"First state starts at birth")
 near(plan[0].hold,.2,"Native hold duration stays authored")
 near(plan[0].transition,.3,"Outgoing transition stays authored")
 near(plan[0].end,.5,"First interval includes hold and transition")
 near(plan[1].start,.5,"Next hold begins after preceding transition")
 near(plan[1].transition,0,"Native final nonloop state exits without transition")
 near(plan[1].end,.9,"State lifetime excludes unused final transition")
 check(plan[0].data==states[0] and plan[1].state==1,"State plan retains authored data and state index")
 var empty=math.state_plan([{"duration_bounds":{"from":0,"to":0},"transition_time_bounds":{"from":0,"to":0}}])
 near(empty[0].end,0,"Zero native lifespan is never fabricated into a visible lifetime")
 check(math.state_plan([]).is_empty(),"Empty native state list remains empty")
 finish()
func finish():
 print("HALO_PARTICLE_MATH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
