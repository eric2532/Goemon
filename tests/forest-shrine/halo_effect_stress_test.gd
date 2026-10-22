extends SceneTree
var failures=0
var checks=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1;print("PASS: " if ok else "FAIL: ",label_)
	if not ok:failures+=1
func run():
	var fx=load("res://scripts/halo_weapon_effects.gd").new();root.add_child(fx);fx.set_process(false)
	var muzzle=Transform3D(Basis.IDENTITY,Vector3(0,2,0));var ejection=Transform3D(Basis.IDENTITY,Vector3(.2,2,0))
	for shot in 300:
		fx.fire_first_person(4,muzzle,ejection,false);fx.fire_ejection(4,muzzle,ejection)
		for tick in 4:fx.advance(1.0/60)
	check(fx.live_count()>250,"Sustained rifle retains original 30-second casing lifetime")
	check(fx.live_count()<fx.MAX_PARTICLES and fx.pending_count()<fx.MAX_JOBS,"Sustained rifle particle and delayed-event pools stay bounded")
	check(fx.particles.batch_count()<40,"Repeated rifle firing shares original atlas batches")
	fx.clear()
	for slot in [2,3,4]:
		for material in ["stone","wood","dirt","human_skin","metal_thick","leaves"]:
			fx.fire_world(slot,Vector3(0,2,3),Vector3(0,2,0),{"impact":true,"normal":Vector3.BACK,"material":material},true)
	check(fx.component_count("effect")>18 and fx.component_count("sound")>0,"All bullet weapons dispatch original material-specific effect and sound graphs")
	check(fx.component_count("decal")>0,"Bullet impacts include recovered native marks")
	fx.clear()
	fx.fire_ejection(3,muzzle,ejection)
	check(fx.pending_count()>0,"Shotgun shell waits for the native half-second pump event")
	fx.cancel_ejection();check(fx.pending_count()==0,"Switching cancels delayed ejection")
	fx.clear();check(fx.live_count()==0 and fx.pending_count()==0,"Cleanup clears all bounded transient state")
	fx.queue_free();await process_frame
	print("HALO_EFFECT_STRESS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
