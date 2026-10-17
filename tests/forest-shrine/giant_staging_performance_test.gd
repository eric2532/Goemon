extends SceneTree
## Exercise the wave director, including staging validation; direct actor
## creation does not reproduce Daruma's repeated approach-search hitch.
const Model=preload("res://scripts/forest/forest_model.gd")
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
var failures=0
var checks=0
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func run():
	Contact.shapes(2)
	for towers in [0,10,30]:
		var m=Model.new();m.reset(90824)
		for x in range(-40,40):
			for z in range(-40,40):m.explored[Vector2i(x,z)]=true
		var built=0
		for x in range(-14,15,4):
			for z in range(-14,15,4):
				if built>=towers or Vector2(x,z).length()<8:continue
				var cell=Vector2i(x,z)
				if m.placement_error("tower",cell,0).is_empty():m._make_building("tower",cell,0);built+=1
		check(built==towers,"Performance fixture contains valid nonoverlapping towers")
		m.rebuild_navigation();m.wave=2;m.start_wave()
		var start=Time.get_ticks_usec();m.waves.spawn_one()
		var ms=(Time.get_ticks_usec()-start)/1000.0
		print("GIANT_STAGING_SPAWN towers=%d ms=%.3f"%[towers,ms])
		check(ms<16.667,"Giant staging and spawn fit inside one 60 Hz frame")
		check(m.enemies.size()==1 and m.enemies.values()[0].variant==2,"Wave director actually spawns Daruma")
		if m.enemies.is_empty() or m.enemies.values()[0].variant!=2:continue
		var giant: Dictionary=m.enemies.values()[0]
		check(m.waves.navigation.full_unseen(giant.pos,2),"Giant's complete footprint remains unseen")
		check(not m.waves.navigation.approach(giant,m.shrine()).is_empty(),"Giant retains a valid shrine approach")
		var peak=0.0
		for i in range(120):
			start=Time.get_ticks_usec();m.waves.tick_enemy(giant,1.0/60,Vector3(0,0,18))
			peak=maxf(peak,(Time.get_ticks_usec()-start)/1000.0)
		print("GIANT_STAGING_MOVEMENT towers=%d peak_ms=%.3f"%[towers,peak])
		check(peak<16.667,"Giant's first target and movement updates fit the combat frame budget")
	print("GIANT_STAGING_PERFORMANCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
