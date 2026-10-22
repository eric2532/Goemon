extends SceneTree
## Preserve the previous exact clipping answers while moving interior segments
## into Geometry3D's native convex intersection implementation.
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func reference(item: Dictionary,from: Vector3,to: Vector3,radius: float)->Vector2:
	var planes: Array[Plane]=[]
	for plane in item.planes:planes.append(Plane(plane.normal,plane.d+radius))
	var entry=Geometry3D.segment_intersects_convex(from,to,planes)
	if not entry.is_empty():
		var line=to-from;var length_squared=line.length_squared()
		var enter=clampf((entry[0]-from).dot(line)/length_squared,0,1)
		var exit=Geometry3D.segment_intersects_convex(to,from,planes)
		var leave=clampf((exit[0]-from).dot(line)/length_squared,0,1) if not exit.is_empty() else 1.0
		return Vector2(enter,leave)
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
func run():
	var api: Variant=Contact.new()
	check(api.has_method("_native_hull_interval"),"Interior hull segments have a native clipping path")
	if not api.has_method("_native_hull_interval"):finish();return
	var random=RandomNumberGenerator.new();random.seed=141019
	for variant in range(2,5):
		for item in Contact.shapes(variant):
			if item.group=="capsule":continue
			for radius in [0.0,.25,1.35]:
				var box: AABB=item.bounds
				var points: Array[Vector3]=[item.center,box.position,box.end,item.center+Vector3(.02,0,0),item.center+Vector3(0,.03,0)]
				for i in range(24):points.append(box.position+Vector3(random.randf_range(-.5,1.5)*box.size.x,random.randf_range(-.5,1.5)*box.size.y,random.randf_range(-.5,1.5)*box.size.z))
				for i in range(points.size()):
					for to in [points[(i+1)%points.size()],points[i],item.center]:
						var expected=reference(item,points[i],to,radius)
						var actual=Contact._hull_interval(item,points[i],to,radius)
						check(actual.distance_to(expected)<.0001,"Variant %d %s radius %.2f exact old interval"%[variant,item.group,radius])
				# Both endpoints are strictly inside; the engine's ordinary API
				# returns empty here, but the extended query must resolve natively.
				var planes: Array[Plane]=[]
				for plane in item.planes:planes.append(Plane(plane.normal,plane.d+radius))
				var native: Variant=api._native_hull_interval(item,item.center,item.center+Vector3(.02,0,0),radius,planes)
				check(native is Vector2 and native.is_equal_approx(Vector2(0,1)),"Interior short segment clips natively")
	var boss=Contact.shapes(4)[0]
	for radius in [0.0,.25,1.35]:
		var box: AABB=boss.bounds
		for offset in [-.0001,0.0,.0001]:
			var a=Vector3(box.end.x+radius+offset,box.get_center().y,-30)
			var b=Vector3(a.x,a.y,30)
			check(Contact._hull_interval(boss,a,b,radius).distance_to(reference(boss,a,b,radius))<.0001,"Boss tangent boundary retains old interval")
	# A tall narrow prism's offset side planes meet far beyond grow(radius).
	# This guards the conservative enclosure used by native line extension.
	var side=Vector3(1,.001,0).normalized()
	var sharp_planes: Array[Plane]=[Plane(side,side.x),Plane(Vector3(-side.x,side.y,0),side.x),Plane(Vector3.DOWN,0),Plane(Vector3.BACK,1),Plane(Vector3.FORWARD,1)]
	var sharp={"center":Vector3(0,500,0),"bounds":AABB(Vector3(-1,0,-1),Vector3(2,1000,2)),"planes":sharp_planes}
	for radius in [.25,1.35]:
		for line in [[Vector3(0,1000+radius*500,0),Vector3(0,1000+radius*500,.02)],[Vector3(0,500,0),Vector3(0,2500,0)],[Vector3(0,2351,0),Vector3(0,2351,.02)]]:
			check(Contact._hull_interval(sharp,line[0],line[1],radius).distance_to(reference(sharp,line[0],line[1],radius))<.0001,"Sharp expanded corners preserve exact intervals")
	finish()
func finish():
	print("NATIVE_ENEMY_HULL_INTERVAL_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
