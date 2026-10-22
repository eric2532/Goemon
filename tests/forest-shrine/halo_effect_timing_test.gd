extends SceneTree
const Effects=preload("res://scripts/halo_weapon_effects.gd")
var checks:int=0
var failures:int=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func near(value:float,want:float,label_:String,tolerance:float=.00001):check(absf(value-want)<=tolerance,label_+" (%s expected %s)"%[value,want])
func make_fx():
	var fx=Effects.new();root.add_child(fx);fx.set_process(false);return fx
func constant_effect(fx,count:float=4.0)->Dictionary:
	var native:Dictionary=fx.data.resolve("weapons\\rocket launcher\\effects\\rocket explosion","effect")
	var emission:Dictionary=native.events[0].particles[2].duplicate(true)
	emission.created_count={"from":count,"to":count};emission.distribution_function="constant"
	emission.velocity={"from":0,"to":0}
	return {"events":[{"delay_bounds":{"from":0,"to":0},"duration_bounds":{"from":1,"to":1},"parts":[],"particles":[emission]}]}
func run():
	var fx=make_fx()
	var identity:Transform3D=Transform3D.IDENTITY
	fx.fire_ejection(2,identity,identity)
	check(fx.component_count("sound")==1,"Pistol world ejection dispatches its authored auxiliary sound")
	check(fx.native_paths.has("sound\\sfx\\weapons\\pistol\\eject"),"Original ejection sound tag is selected")
	check(not fx.native_paths.has("sound\\sfx\\weapons\\pistol\\fire"),"World ejection does not duplicate the gunshot")
	check(fx.pending_count()==1 and fx.live_count()==0,"Pistol casing waits for original delayed event")
	fx.advance(.029)
	check(fx.live_count()==0,"Pistol casing stays pending before .03 seconds")
	fx.advance(.0011)
	check(fx.live_count()==1,"Pistol casing emits at .03 seconds")
	near(fx.particles.snapshot()[0].age,.0001,"Pistol casing age starts at actual birth time")
	fx.clear()
	fx.fire_ejection(3,identity,identity)
	fx.advance(.499)
	check(fx.live_count()==0,"Shotgun casing waits through original .5 second pump delay")
	fx.advance(.0011)
	check(fx.live_count()==1,"Shotgun casing emits at .5 seconds")
	near(fx.particles.snapshot()[0].age,.0001,"Shotgun casing receives only time after birth")
	fx.clear()
	var context:Dictionary=fx._context(Vector3(0,5,0))
	fx._effect(constant_effect(fx,4.9),context)
	check(fx.pending_count()==4,"Native sampled count truncates 4.9 to four particles")
	fx.advance(.249)
	check(fx.live_count()==0,"First of four constant particles waits until cumulative count reaches one")
	fx.advance(.0011)
	check(fx.live_count()==1,"First constant particle emits at t=.25")
	near(fx.particles.snapshot()[0].age,.0001,"Endpoint birth has no full-frame extra age")
	fx.advance(.7499)
	check(fx.live_count()==4,"Last native constant particle emits at event end")
	var expected:Array=[.75,.5,.25,0.0]
	var coarse:Array=fx.particles.snapshot()
	for i:int in expected.size():near(coarse[i].age,expected[i],"Coarse partition particle %d birth age"%i)
	var fine=make_fx()
	fine._effect(constant_effect(fine,4.9),fine._context(Vector3(0,5,0)))
	for i:int in 100:fine.advance(.01)
	check(fine.live_count()==coarse.size(),"Fine and coarse partitions conserve native particle count")
	var small:Array=fine.particles.snapshot()
	for i:int in expected.size():near(small[i].age,coarse[i].age,"Coarse/fine partition age agreement %d"%i)
	# Angle spread follows effect_random_translational_velocity's random-axis
	# rotation distribution: unlike a solid-angle cone, mean cos at pi is 1/3.
	seed(39238)
	var average_cosine:float=0.0
	for i:int in 10000:average_cosine+=fx._cone(Vector3.FORWARD,PI).dot(Vector3.FORWARD)
	average_cosine/=10000
	near(average_cosine,1.0/3.0,"Native effect cone retains random-axis central bias",.025)
	fx.clear()
	var system:Dictionary=fx.data.resolve("weapons\\frag grenade\\effects\\explosion med","particle_system")
	fx._system(system,fx._context(Vector3(0,5,0)))
	check(fx.live_count()==35,"Native explosion system creates exactly 35 initial particles")
	var timings:Dictionary={}
	for particle:Dictionary in fx.particles.snapshot():timings[particle.type_state_plan[0].end]=true
	check(timings.size()==1,"All explosion particles share one sampled emitter state timeline")
	fx.advance(3)
	check(fx.live_count()==0,"Native system fire-to-smoke particles finish before three seconds")
	fx.clear();fine.clear();fx.queue_free();fine.queue_free();await process_frame
	print("HALO_EFFECT_TIMING_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
