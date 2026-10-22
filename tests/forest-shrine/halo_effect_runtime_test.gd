extends SceneTree
var failures=0
var checks=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1;print("PASS: " if ok else "FAIL: ",label_)
	if not ok:failures+=1
func run():
	check(ResourceLoader.exists("res://scripts/halo_weapon_effects.gd"),"Native effect adapter exists")
	check(FileAccess.file_exists("res://assets/characters/master_chief/effects/manifest.json"),"Original effect graph and sprite metadata were recovered")
	if failures:finish();return
	var fx=load("res://scripts/halo_weapon_effects.gd").new();root.add_child(fx)
	check(fx.data.tags.size()>100,"Native effect adapter loads the original dependency graph")
	fx.explosion(Vector3(0,2,0),Vector3.UP,"stone",3)
	check(fx.live_count()>35,"Original explosion creates layered fire, smoke, debris and flare particles")
	check(fx.component_count("decal")>0 and fx.component_count("light")>0,"Original explosion includes its scorch mark and light")
	check(fx.native_paths.has("weapons\\frag grenade\\effects\\explosion med"),"Explosion dispatches the native fire-to-smoke system")
	var initial=fx.live_count()
	for i in 180:fx.advance(1.0/60)
	check(fx.live_count()>0,"Explosion's original smoke persists after the fire")
	check(fx.live_count()<fx.MAX_PARTICLES,"Original effects remain bounded")
	fx.clear()
	check(fx.live_count()==0 and fx.pending_count()==0,"Clear releases particles and delayed events")
	fx.fire_first_person(4,Transform3D.IDENTITY,Transform3D.IDENTITY,false)
	check(fx._lights.size()==1,"Rifle firing activates its muzzle light without enabling its separate flashlight")
	fx.clear()
	fx.rocket_start(0,Vector3(0,2,0),Vector3.FORWARD)
	check(fx.light_volumes.live_count()==1,"Rocket includes its original twenty-sprite glow widget")
	fx.rocket_move(0,Vector3(0,2,-2),Vector3.FORWARD,.05)
	fx.rocket_stop(0)
	check(fx.light_volumes.live_count()==0,"Retiring a rocket reclaims its owner-bound glow")
	fx.clear()
	fx.queue_free();await process_frame
	finish()
func finish():
	print("HALO_EFFECT_RUNTIME_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
