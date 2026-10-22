extends SceneTree
## Catch repeated contact events and discontinuous support changes on terrain.
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func tick(model: HeroModel,speed: float):
	model.locomotion_velocity=Vector3.FORWARD*speed
	model.position+=model.locomotion_velocity/60.0
	model.animate(1.0/60,speed,true,0,0,false,0,false);model.sync_skeleton()
func run():
	var ground=StaticBody3D.new();root.add_child(ground)
	var collision=CollisionShape3D.new();collision.shape=BoxShape3D.new();collision.shape.size=Vector3(200,.2,200);collision.position.y=-.1;ground.add_child(collision)
	await physics_frame
	var model=HeroModel.new();root.add_child(model);model.set_process(false)
	for speed in [3.0,5.0,7.0]:
		model.position=Vector3.ZERO;model.locomotion.reset()
		for frame in range(120):tick(model,speed)
		var before: int=model.locomotion.step_events
		for frame in range(120):tick(model,speed)
		var events: int=model.locomotion.step_events-before
		print("CONTACT_EVENTS speed=",speed," two_seconds=",events)
		check(events>=2 and events<=10,"Partial-speed run emits one event per actual plant at speed %s"%speed)
	ground.free()
	ground=StaticBody3D.new();root.add_child(ground)
	collision=CollisionShape3D.new();collision.shape=WorldBoundaryShape3D.new();collision.shape.plane=Plane(Vector3(0,1,.2).normalized(),0);ground.add_child(collision)
	await physics_frame
	model.position=Vector3.ZERO;model.locomotion.reset()
	for frame in range(120):
		model.locomotion_velocity=Vector3.FORWARD*10.2
		model.animate(1.0/60,10.2,true,0,0,false,0,false);model.sync_skeleton()
	for seam in [.5,1.0]:
		var heights=[]
		for phase_ in [seam-.0001,seam+.0001]:
			model.locomotion.dt=0;model.locomotion.phase=fposmod(phase_,1.0);model.locomotion.dirty=true;model.sync_skeleton()
			heights.append(model.locomotion.pose("Root").origin.y)
		print("SLOPE_SEAM phase=",seam," height_change=",absf(heights[1]-heights[0]))
		check(absf(heights[1]-heights[0])<.005,"Sloped terrain stays continuous across support seam %s"%seam)
	model.free();ground.free()
	print("USER_STRIDE_GROUND_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
