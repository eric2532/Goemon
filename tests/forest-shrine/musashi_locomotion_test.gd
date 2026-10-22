extends SceneTree
## Literal source-unit trajectories catch generic gravity, jump-cut and air-drag regressions.
var checks=0
var failures=0
class Body extends CharacterBody3D:
	var active_ability=null
	var jumps_used=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func near(actual:float,want:float,label_:String):
	check(absf(actual-want)<0.00001,label_+" got=%f want=%f"%[actual,want])
func run():
	var path="res://scripts/recovered_musashi_locomotion.gd"
	check(ResourceLoader.exists(path),"Musashi has a source locomotion implementation")
	if not ResourceLoader.exists(path):finish();return
	var script=load(path)
	var m=script.new()
	var v:Vector3=m.source_tick(Vector3.FORWARD,true,false,true,false,false)
	near(v.length(),0,"Run entry initializes the source vector before its first integration")
	v=m.source_tick(Vector3.FORWARD,true,false,true,false,false)
	near(v.length(),4.35375,"First digital run integration is 8.0625 source units")
	for i in 47:v=m.source_tick(Vector3.FORWARD,true,false,true,false,false)
	near(v.length(),5.94,"Digital run reaches 11 units after 48 acceleration updates")
	check(m.animation_state()=="sprint","Movement selects the source sprint table above 9.25 units")
	v=m.source_tick(Vector3.RIGHT,true,false,true,false,false)
	near(v.x,5.94,"Turning changes source facing immediately at retained speed")
	near(v.z,0,"Turning has no inherited Goemon steering blend")
	v=m.source_tick(Vector3.ZERO,true,false,true,false,false)
	near(v.length(),0,"Ground release clears the source vector immediately")
	check(m.animation_state()=="stop","Full-speed release begins the original skid state")
	var slide=0.0
	for i in 11:
		v=m.source_tick(Vector3.ZERO,true,false,true,false,false);slide+=v.length()/30.0
	near(slide,.792,"The full-speed skid travels exactly eleven four-unit source updates")
	v=m.source_tick(Vector3.ZERO,true,false,true,false,false)
	check(v.is_zero_approx() and m.animation_state()=="idle","The completed twelve-pose stop returns to idle without a twelfth movement step")
	m.reset();m.source_tick(Vector3.FORWARD,true,false,true,true,false)
	v=m.source_tick(Vector3.FORWARD,true,false,true,true,false)
	near(v.length(),2.16,"Cautious movement caps at four source units")
	m.reset();m.source_tick(Vector3.FORWARD,true,false,true,false,true)
	v=m.source_tick(Vector3.FORWARD,true,false,true,false,true)
	near(v.length(),2.16,"Guard walk reloads its four-unit source vector")
	v=m.source_tick(Vector3.RIGHT,true,false,true,false,true)
	near(v.x,2.16,"Mouse guard permits lateral movement")
	check(m.facing==Vector3.FORWARD,"Mouse guard preserves facing while strafing")
	m.reset();v=m.source_tick(Vector3.ZERO,true,true,true,false,false)
	near(v.y,0,"First jump entry initializes -18 without integrating the entry tick")
	check(m.jumps_used==1,"Ground Space consumes exactly the first jump")
	v=m.source_tick(Vector3.ZERO,false,false,true,false,false)
	near(v.y,8.8425,"Held first jump first integrated velocity is 16.375 units upward")
	v=m.source_tick(Vector3.ZERO,false,false,true,false,false)
	near(v.y,7.965,"Held first jump second integrated velocity is 14.75 upward")
	v=m.source_tick(Vector3.ZERO,false,true,true,false,false)
	near(v.y,6.6825,"L-Belt edge resets to fourteen then applies the same tick gravity")
	check(m.jumps_used==2 and m.animation_state()=="double_jump","Second Space selects the recovered spinning jump")
	v=m.source_tick(Vector3.ZERO,false,true,true,false,false)
	near(v.y,5.805,"An additional press cannot restore another launch")
	m.reset();m.source_tick(Vector3.ZERO,true,true,true,false,false)
	v=m.source_tick(Vector3.ZERO,false,false,false,false,false)
	near(v.y,8.3025,"Releasing rising Space adds one source unit to normal gravity")
	v=m.source_tick(Vector3.RIGHT,false,false,true,false,false)
	near(v.x,4.86,"Air direction establishes eight units then adds one immediately")
	v=m.source_tick(Vector3.ZERO,false,false,true,false,false)
	near(v.x,4.86,"Releasing air direction preserves source horizontal momentum")
	for i in 35:m.source_tick(Vector3.ZERO,false,false,true,false,false)
	m.source_tick(Vector3.ZERO,true,false,true,false,false)
	check(m.jumps_used==0 and m.animation_state()=="land","Landing clears jump availability and selects landing")
	m.source_tick(Vector3.ZERO,true,true,true,false,false)
	check(m.jumps_used==1,"A new grounded jump is available after landing")
	await physics_checks(script)
	finish()
func physics_checks(script):
	var floor_=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new()
	box.size=Vector3(40,.2,40);shape.shape=box;shape.position.y=-.1;floor_.add_child(shape);root.add_child(floor_)
	var body=Body.new();shape=CollisionShape3D.new();var capsule=CapsuleShape3D.new()
	capsule.height=1;capsule.radius=.25;shape.shape=capsule;shape.position.y=.5;body.add_child(shape);root.add_child(body)
	var driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
	var old_hz=Engine.physics_ticks_per_second
	var old_jitter=Engine.physics_jitter_fix
	# This fixture measures exact one-second trajectories across a runtime rate
	# change. Disable the engine's transitional step correction for that clock.
	Engine.physics_jitter_fix=0
	for hz in [30,60]:
		Engine.physics_ticks_per_second=hz;await physics_frame
		body.position=Vector3(0,.01,0)
		await driver.advance(3,func(_dt):body.velocity=Vector3.DOWN*3;body.move_and_slide())
		check(body.is_on_floor(),"Collision fixture starts grounded at %d Hz"%hz)
		var motion=script.new(body)
		var measured=[]
		await driver.advance(hz,func(dt):measured.append(dt);motion.physics_step(dt,Vector3.FORWARD,false,true,false,false))
		if absf(-body.position.z-4.665375)>.00001:print("SOURCE_CLOCK_DEBUG hz=",hz," deltas=",measured)
		near(-body.position.z,4.665375,"One-second real-body trajectory preserves the source entry and 29 integrations at %d Hz"%hz)
		motion.reset();body.position=Vector3(0,.01,0)
		await driver.advance(3,func(_dt):body.velocity=Vector3.DOWN*3;body.move_and_slide())
		var start_y=body.position.y
		var pressed=[true]
		await driver.advance(7*hz/30,func(dt):motion.physics_step(dt,Vector3.ZERO,pressed[0],true,false,false);pressed[0]=false)
		check(absf(body.position.y-start_y-1.32975)<.001,"Six real-body ascent integrations retain source height within the capsule recovery margin at %d Hz"%hz)
	Engine.physics_ticks_per_second=old_hz
	Engine.physics_jitter_fix=old_jitter
	body.queue_free();floor_.queue_free();driver.queue_free();await physics_frame
func finish():
	print("MUSASHI_LOCOMOTION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
