extends RefCounted
## Cached exported geometry shared by combat actors and model-owned arrows.

static var cache: Dictionary={}
static func shapes(variant: int)->Array:
	if cache.has(variant):return cache[variant]
	var scene=load(load("res://scripts/forest/forest_enemy_roles.gd").asset_path(variant)).instantiate()
	var groups: Dictionary={}
	_collect(scene,Transform3D.IDENTITY,variant,groups)
	scene.free()
	var result: Array=[]
	for group in groups:
		var points: PackedVector3Array=groups[group]
		if points.is_empty():continue
		var bounds=AABB(points[0],Vector3.ZERO)
		for point in points:bounds=bounds.expand(point)
		if group=="capsule":
			var capsule=CapsuleShape3D.new()
			capsule.height=bounds.end.y
			capsule.radius=minf(capsule.height*.5,maxf(bounds.size.x,bounds.size.z)*.5)
			var center=Vector3(bounds.get_center().x,capsule.height*.5,bounds.get_center().z)
			result.append({"group":group,"shape":capsule,"center":center,"bounds":AABB(center-Vector3(capsule.radius,capsule.height*.5,capsule.radius),Vector3(capsule.radius*2,capsule.height,capsule.radius*2))})
		else:
			# Keep rounded contact within a small fraction of a metre while avoiding
			# twelve thousand shell planes in every projectile/contact query.
			if points.size()>768:
				var sampled=PackedVector3Array();var step=maxi(1,ceili(points.size()/768.0))
				for i in range(0,points.size(),step):sampled.append(points[i])
				for axis in range(3):
					var low=points[0];var high=points[0]
					for point in points:
						if point[axis]<low[axis]:low=point
						if point[axis]>high[axis]:high=point
					sampled.append(low);sampled.append(high)
				points=sampled
			var hull=ConvexPolygonShape3D.new();hull.points=points
			var faces=hull.get_debug_mesh().get_faces()
			var planes: Array[Plane]=[]
			var center=bounds.get_center()
			for i in range(0,faces.size(),3):
				var normal=(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized()
				if normal.is_zero_approx():continue
				if normal.dot(center-faces[i])>0:normal=-normal
				planes.append(Plane(normal,normal.dot(faces[i])))
			result.append({"group":group,"shape":hull,"center":center,"bounds":bounds,"planes":planes})
	cache[variant]=result
	return result
static func _collect(node: Node,parent: Transform3D,variant: int,groups: Dictionary):
	var pose=parent*node.transform if node is Node3D else parent
	if node is MeshInstance3D:
		var label=String(node.name).to_lower();var group=""
		if variant==2:
			if label.begins_with("body_round"):group="body"
			for prefix in ["foot_l","foot_r","fist_l","fist_r"]:
				if label.begins_with(prefix):group=prefix
		elif variant==3:
			if label=="root_paper_shell":group="body"
			elif label.begins_with("leg_l"):group="foot_l"
		elif "skull" in label or "ribcage" in label or "pelvis" in label:group="capsule"
		if not group.is_empty():
			var points: PackedVector3Array=groups.get(group,PackedVector3Array())
			for surface in range(node.mesh.get_surface_count()):
				for vertex in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:points.append(pose*vertex)
			groups[group]=points
	for child in node.get_children():_collect(child,pose,variant,groups)
static func part_pose(group: String,data: Dictionary)->Transform3D:
	if data.get("frozen",0.0)>0 and data.has("frozen_pose"):data=data.frozen_pose
	var crowd=load("res://scripts/forest/forest_enemy_crowd.gd") if ResourceLoader.exists("res://scripts/forest/forest_enemy_crowd.gd") else null
	if crowd!=null and crowd.has_method("part_pose"):return crowd.part_pose("body" if group=="capsule" else group,data)
	return Transform3D.IDENTITY
static func contact(data: Dictionary,point: Vector3)->Vector3:
	var root_pose=Transform3D(Basis(Vector3.UP,float(data.get("facing",0.0))),data.pos)
	var best: Vector3=data.pos;var distance=INF
	for item in shapes(int(data.variant)):
		var pose=root_pose*part_pose(item.group,data)
		var local=pose.affine_inverse()*point
		var candidate: Vector3
		if item.group=="capsule":candidate=_capsule_contact(item,local)
		else:
			var interval=_hull_interval(item,local,item.center,0.0)
			candidate=local.lerp(item.center,interval.x) if interval.x>=0 else item.center
		candidate=pose*candidate
		var d=point.distance_squared_to(candidate)
		if d<distance:distance=d;best=candidate
	return best
static func segment_contact(data: Dictionary,from: Vector3,to: Vector3,radius: float)->Dictionary:
	var root_pose=Transform3D(Basis(Vector3.UP,float(data.get("facing",0.0))),data.pos)
	var best_t=INF;var point=Vector3.ZERO
	for item in shapes(int(data.variant)):
		var pose=root_pose*part_pose(item.group,data);var inverse=pose.affine_inverse()
		var a=inverse*from;var b=inverse*to;var t=-1.0
		if item.group=="capsule":t=_capsule_segment(item,a,b,radius)
		else:t=_hull_interval(item,a,b,radius).x
		if t>=0 and t<best_t:
			best_t=t;point=contact(data,from.lerp(to,t))
	return {"t":best_t,"point":point} if best_t<INF else {}
static func _capsule_contact(item: Dictionary,point: Vector3)->Vector3:
	var capsule: CapsuleShape3D=item.shape
	var center: Vector3=item.center
	var half=maxf(0,capsule.height*.5-capsule.radius)
	var axis=Vector3(center.x,clampf(point.y,center.y-half,center.y+half),center.z)
	var offset=point-axis
	return point if offset.length()<=capsule.radius else axis+offset.normalized()*capsule.radius
static func _hull_interval(item: Dictionary,from: Vector3,to: Vector3,radius: float)->Vector2:
	# Clip ordinary outside-to-hull queries in native code. The scripted fallback
	# retains interior, stationary and tangent contacts the engine API omits.
	var planes: Array[Plane]=item.planes
	if radius!=0.0:
		var expanded: Dictionary=item.get("expanded_planes",{})
		if not expanded.has(radius):
			var offset: Array[Plane]=[]
			for plane in planes:offset.append(Plane(plane.normal,plane.d+radius))
			# Attack sizes can vary with progression; keep the shared cache bounded.
			if expanded.size()>=16:expanded.clear()
			expanded[radius]=offset;item.expanded_planes=expanded
		planes=expanded[radius]
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
static func bounds(data: Dictionary)->AABB:
	var pose=Transform3D(Basis(Vector3.UP,float(data.get("facing",0.0))),data.pos)
	var result=AABB();var first=true
	for item in shapes(int(data.variant)):
		var box=(pose*part_pose(item.group,data))*item.bounds
		result=box if first else result.merge(box);first=false
	return result

static func _capsule_segment(item: Dictionary,from: Vector3,to: Vector3,radius: float)->float:
	var shape: CapsuleShape3D=item.shape
	var r=shape.radius+radius
	var half=maxf(0,shape.height*.5-shape.radius)
	var a=from-item.center;var line=to-from
	var axis=Vector3(0,clampf(a.y,-half,half),0)
	if a.distance_squared_to(axis)<=r*r:return 0.0
	var best=INF
	var aa=line.x*line.x+line.z*line.z
	var bb=2*(a.x*line.x+a.z*line.z)
	var cc=a.x*a.x+a.z*a.z-r*r
	var disc=bb*bb-4*aa*cc
	if aa>.000001 and disc>=0:
		for t in [(-bb-sqrt(disc))/(2*aa),(-bb+sqrt(disc))/(2*aa)]:
			if t>=0 and t<=1 and absf(a.y+line.y*t)<=half:best=minf(best,t)
	for y in [-half,half]:
		var offset=a-Vector3(0,y,0)
		aa=line.length_squared();bb=2*offset.dot(line);cc=offset.length_squared()-r*r
		disc=bb*bb-4*aa*cc
		if aa>.000001 and disc>=0:
			var t=(-bb-sqrt(disc))/(2*aa)
			if t>=0 and t<=1:best=minf(best,t)
	return best if best<INF else -1.0
