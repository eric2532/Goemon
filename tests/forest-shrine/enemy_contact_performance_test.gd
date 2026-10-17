extends SceneTree
# Catches detailed hull queries exhausting the 60Hz combat budget, while checking
# entry, interior, grazing and expanded-radius contact on the real imported hulls.
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
var checks=0
var failures=0
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func run():
	for kind in [2,3]:
		var data={"variant":kind,"pos":Vector3.ZERO,"facing":0.0,"action":"walk","walk_phase":0.0,"velocity":Vector3.ZERO}
		for item in Contact.shapes(kind):
			if item.group=="capsule":continue
			var center: Vector3=item.center
			check(Contact._hull_interval(item,center,center,0).x==0,"Interior stationary point hits %s"%item.group)
			for radius in [0.0,.05,.6,2.0]:
				for offset in [Vector3(30,0,0),Vector3(0,30,0),Vector3(0,0,-30),Vector3(30,30,0)]:
					var a=center+offset;var b=center-offset
					var expected=reference_interval(item,a,b,radius)
					var actual=Contact._hull_interval(item,a,b,radius)
					check(absf(actual.x-expected.x)<.00003,"Actual hull entry matches clipped planes")
					check(Contact._hull_interval(item,center,b,radius).x==0,"Interior segment hits at its start")
			check(Contact._hull_interval(item,center+Vector3(50,50,50),center+Vector3(60,60,60),0).x<0,"Remote segment misses fitted hull")
			var surface=Contact.contact(data,center+Vector3(0,0,-30))
			check(not Contact.segment_contact(data,surface,surface,.003).is_empty(),"Surface contact is inside the posed collider")
	# Warm resources before timing. The old per-plane GDScript loop exceeds this
	# generous budget by over five times on the development machine.
	var lantern={"variant":3,"pos":Vector3(0,0,50),"facing":0.0,"action":"walk","walk_phase":.5,"velocity":Vector3(0,0,-1)}
	for i in range(20):Contact.contact(lantern,Vector3(0,1.5,18))
	var start=Time.get_ticks_usec()
	for i in range(320):Contact.contact(lantern,Vector3(0,1.5,18))
	var average=(Time.get_ticks_usec()-start)/320000.0
	print("LANTERN_CONTACT_MEAN_MS ",average)
	check(average<.06,"Rounded contact queries stay within the crowd combat budget")
	print("FOREST_ENEMY_CONTACT_PERFORMANCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func reference_interval(item: Dictionary,from: Vector3,to: Vector3,radius: float)->Vector2:
	var enter=0.0;var leave=1.0;var line=to-from
	for plane in item.planes:
		var distance=plane.normal.dot(from)-plane.d-radius
		var slope=plane.normal.dot(line)
		if absf(slope)<.000001:
			if distance>0:return Vector2(-1,-1)
			continue
		var t=-distance/slope
		if slope<0:enter=maxf(enter,t)
		else:leave=minf(leave,t)
		if enter>leave:return Vector2(-1,-1)
	return Vector2(enter,leave)
