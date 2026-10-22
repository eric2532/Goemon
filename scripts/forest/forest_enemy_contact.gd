extends RefCounted
## Cached exported geometry shared by combat actors and model-owned arrows.

const Soldier=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
static var soldier_cache: Dictionary={}
static var cache: Dictionary={}
static var block_cache: Dictionary={}
static var crowd_script: Script
static func shapes(variant: int,blocks: bool=false)->Array:
	if Soldier.supports(variant):
		if not soldier_cache.has(variant):
			var bounds=Soldier.hurt_bounds();var shape=BoxShape3D.new();shape.size=bounds.size
			soldier_cache[variant]=[{"group":"body","shape":shape,"center":bounds.get_center(),"bounds":bounds,"box":true}]
		return soldier_cache[variant]
	if blocks:
		if block_cache.has(variant):return block_cache[variant]
		var result: Array=[]
		for item in shapes(variant):
			var shape=BoxShape3D.new();shape.size=item.bounds.size
			result.append({"group":item.group,"shape":shape,"center":item.bounds.get_center(),"bounds":item.bounds,"box":true})
		block_cache[variant]=result
		return result
	if cache.has(variant):return cache[variant]
	if variant==4:
		# Eight corners and six planes: rendering and every combat query share
		# the same floor-anchored block, without loading an enemy model.
		var size_=preload("res://scripts/forest/forest_enemy_roles.gd").BOSS_SIZE
		var bounds=AABB(Vector3(-size_.x*.5,0,-size_.z*.5),size_)
		var points=PackedVector3Array()
		for x in [-size_.x*.5,size_.x*.5]:
			for y in [0.0,size_.y]:
				for z in [-size_.z*.5,size_.z*.5]:points.append(Vector3(x,y,z))
		var hull=ConvexPolygonShape3D.new();hull.points=points
		var planes: Array[Plane]=[Plane(Vector3.RIGHT,size_.x*.5),Plane(Vector3.LEFT,size_.x*.5),Plane(Vector3.UP,size_.y),Plane(Vector3.DOWN,0),Plane(Vector3.BACK,size_.z*.5),Plane(Vector3.FORWARD,size_.z*.5)]
		cache[variant]=[{"group":"body","shape":hull,"center":bounds.get_center(),"bounds":bounds,"planes":planes}]
		return cache[variant]
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
	if Soldier.supports(int(data.variant)):return Transform3D.IDENTITY
	if data.get("frozen",0.0)>0 and data.has("frozen_pose"):data=data.frozen_pose
	# Lazy lookup avoids a preload cycle; reuse it across all member parts.
	if crowd_script==null:crowd_script=load("res://scripts/forest/forest_enemy_crowd.gd")
	return crowd_script.part_pose("body" if group=="capsule" else group,data)
## Immutable pose shared by actor physics and model-owned combat queries.
static func prepare(data: Dictionary,formation: Dictionary={})->Dictionary:
	if formation.is_empty() and data.has("shared_contacts"):return data.shared_contacts
	var root_pose=Transform3D(Basis(Vector3.UP,float(data.get("facing",0.0))),data.pos)
	var items=shapes(int(data.variant),data.get("block_contacts",false))
	var roots: Array=formation.get("roots",[root_pose])
	var parts: Array=formation.get("parts",[data])
	var compound: Array=[];var members: Array=[];var radius_scales: Array=[]
	var local_poses: Array[Transform3D]=[]
	var world_poses: Array[Transform3D]=[]
	var render_poses: Array=[]
	var inverses: Array[Transform3D]=[]
	var shape_bounds: Array[AABB]=[]
	var result=AABB();var first=true
	var root_inverse=root_pose.affine_inverse()
	for member in range(roots.size()):
		var member_root: Transform3D=roots[member]
		var member_poses: Array[Transform3D]=[];render_poses.append(member_poses)
		if absf(member_root.basis.determinant())<.000001:continue
		var padding_scale=1.0/maxf(.001,member_root.basis.get_scale().x)
		for item in items:
			var world_pose=member_root*part_pose(item.group,parts[member])
			member_poses.append(world_pose)
			compound.append(item);members.append(member);radius_scales.append(padding_scale)
			local_poses.append(root_inverse*world_pose);world_poses.append(world_pose);inverses.append(world_pose.affine_inverse())
			var box=world_pose*item.bounds
			# The exact contact still uses the local shape. A small world-space
			# margin keeps float32 transformed faces inside this rejection bound.
			shape_bounds.append(box.grow(.001))
			result=box if first else result.merge(box);first=false
	return {"shapes":compound,"members":members,"radius_scales":radius_scales,"local_poses":local_poses,"world_poses":world_poses,"render_poses":render_poses,"inverses":inverses,"shape_bounds":shape_bounds,"bounds":result,"pos":data.pos}
static func contact(data: Dictionary,point: Vector3,prepared: Dictionary={},shape_index:int=-1)->Vector3:
	if prepared.is_empty():prepared=data.get("shared_contacts",{})
	var ready=not prepared.is_empty()
	if ready and prepared.has("shape_bounds") and point.is_finite():
		return _prepared_contact(point,prepared,shape_index)
	var root_pose=Transform3D.IDENTITY if ready else Transform3D(Basis(Vector3.UP,float(data.get("facing",0.0))),data.pos)
	var best: Vector3=prepared.pos if ready else data.pos;var distance=INF
	var items: Array=prepared.shapes if ready else shapes(int(data.variant),data.get("block_contacts",false))
	for i in range(items.size()):
		if shape_index>=0 and i!=shape_index:continue
		var item: Dictionary=items[i]
		var pose: Transform3D=prepared.world_poses[i] if ready else root_pose*part_pose(item.group,data)
		var inverse: Transform3D=prepared.inverses[i] if ready else pose.affine_inverse()
		var local=inverse*point
		var candidate: Vector3
		if item.get("box",false):candidate=local.clamp(item.bounds.position,item.bounds.end)
		elif item.group=="capsule":candidate=_capsule_contact(item,local)
		else:
			var interval=_hull_interval(item,local,item.center,0.0)
			candidate=local.lerp(item.center,interval.x) if interval.x>=0 else item.center
		candidate=pose*candidate
		var d=point.distance_squared_to(candidate)
		if d<distance:distance=d;best=candidate
	return best
static func _prepared_shape_contact(point: Vector3,prepared: Dictionary,index: int)->Vector3:
	var item: Dictionary=prepared.shapes[index]
	var pose: Transform3D=prepared.world_poses[index]
	var inverse: Transform3D=prepared.inverses[index]
	var local=inverse*point
	var candidate: Vector3
	if item.get("box",false):candidate=local.clamp(item.bounds.position,item.bounds.end)
	elif item.group=="capsule":candidate=_capsule_contact(item,local)
	else:
		var interval=_hull_interval(item,local,item.center,0.0)
		candidate=local.lerp(item.center,interval.x) if interval.x>=0 else item.center
	return pose*candidate
static func _prepared_contact(point: Vector3,prepared: Dictionary,shape_index: int)->Vector3:
	var count: int=prepared.shapes.size()
	if shape_index>=0:
		return _prepared_shape_contact(point,prepared,shape_index) if shape_index<count else prepared.pos
	var first=-1;var lower=INF
	for index in count:
		var box: AABB=prepared.shape_bounds[index]
		var gap=point.distance_squared_to(point.clamp(box.position,box.end))
		if gap<lower:first=index;lower=gap
	if first<0:return prepared.pos
	var best=_prepared_shape_contact(point,prepared,first)
	var distance=point.distance_squared_to(best)
	var best_index=first
	for index in count:
		if index==first:continue
		var box: AABB=prepared.shape_bounds[index]
		if point.distance_squared_to(point.clamp(box.position,box.end))>distance:continue
		var candidate=_prepared_shape_contact(point,prepared,index)
		var gap=point.distance_squared_to(candidate)
		# Preserve the original first-part winner, including exact ties.
		if gap<distance or (gap==distance and index<best_index):
			best=candidate;distance=gap;best_index=index
	return best
static func segment_contact(data: Dictionary,from: Vector3,to: Vector3,radius: float,prepared: Dictionary={})->Dictionary:
	if prepared.is_empty():prepared=data.get("shared_contacts",{})
	var ready=not prepared.is_empty()
	var root_pose=Transform3D.IDENTITY if ready else Transform3D(Basis(Vector3.UP,float(data.get("facing",0.0))),data.pos)
	var best_t=INF;var point=Vector3.ZERO
	var items: Array=prepared.shapes if ready else shapes(int(data.variant),data.get("block_contacts",false))
	for i in range(items.size()):
		var item: Dictionary=items[i]
		var inverse: Transform3D
		if ready:inverse=prepared.inverses[i]
		else:inverse=(root_pose*part_pose(item.group,data)).affine_inverse()
		var local_radius=radius*float(prepared.radius_scales[i]) if ready and prepared.has("radius_scales") else radius
		var a=inverse*from;var b=inverse*to;var t=-1.0
		if item.get("box",false):t=_box_interval(item.bounds,a,b,local_radius).x
		elif item.group=="capsule":t=_capsule_segment(item,a,b,local_radius)
		else:t=_hull_interval(item,a,b,local_radius).x
		if t>=0 and t<best_t:
			best_t=t;point=contact(data,from.lerp(to,t),prepared,i)
	return {"t":best_t,"point":point} if best_t<INF else {}
static func _box_interval(bounds: AABB,from: Vector3,to: Vector3,radius: float)->Vector2:
	var low=bounds.position-Vector3.ONE*radius;var high=bounds.end+Vector3.ONE*radius
	var line=to-from;var enter=0.0;var leave=1.0
	for axis in range(3):
		if line[axis]==0:
			if from[axis]<low[axis] or from[axis]>high[axis]:return Vector2(-1,-1)
			continue
		var a=(low[axis]-from[axis])/line[axis];var b=(high[axis]-from[axis])/line[axis]
		enter=maxf(enter,minf(a,b));leave=minf(leave,maxf(a,b))
		if enter>leave:return Vector2(-1,-1)
	return Vector2(enter,leave)
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
	var native_interval=_native_hull_interval(item,from,to,radius,planes)
	if native_interval!=null:return native_interval
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
static func _native_hull_interval(item: Dictionary,from: Vector3,to: Vector3,radius: float,planes: Array[Plane])->Variant:
	# Geometry3D omits hits when a segment begins inside the hull. Extend both
	# ends outside a conservative enclosure, then clip its native entry/exit
	# back to the original segment. Stationary and tangent cases retain the
	# exact scripted fallback above.
	var line=to-from;var length_squared=line.length_squared()
	if length_squared<.00000001:return null
	var box: AABB=item.bounds
	if radius>0:
		var margin: float=item.get("expansion_margin",-1.0)
		if margin<0:
			margin=INF
			for plane in item.planes:margin=minf(margin,plane.d-plane.normal.dot(item.center))
			item.expansion_margin=maxf(0,margin)
		# Scaling about an interior point by 1+r/min_face_distance encloses
		# every plane-offset hull, including sharp corners whose radius
		# expansion extends farther than bounds.grow(radius).
		if margin<=.000001:return null
		var factor=1.0+radius/margin
		box=AABB(item.center+(box.position-item.center)*factor,box.size*factor)
	var length_=sqrt(length_squared);var direction=line/length_
	var middle=(box.get_center()-from).dot(direction)
	var extent=box.size.length()*.5+1.0
	var a=from+direction*(middle-extent);var b=from+direction*(middle+extent)
	var entry=Geometry3D.segment_intersects_convex(a,b,planes)
	if entry.is_empty():return null
	var exit=Geometry3D.segment_intersects_convex(b,a,planes)
	if exit.is_empty():return null
	var enter=(Vector3(entry[0])-from).dot(direction)/length_
	var leave=(Vector3(exit[0])-from).dot(direction)/length_
	# Near an endpoint, retain the original boundary arithmetic instead of
	# letting float roundoff in an extended segment decide inclusivity.
	if absf(enter)<.00001 or absf(enter-1)<.00001 or absf(leave)<.00001 or absf(leave-1)<.00001:return null
	if enter>1 or leave<0:return Vector2(-1,-1)
	return Vector2(maxf(0,enter),minf(1,leave))

static func bounds(data: Dictionary,prepared: Dictionary={})->AABB:
	if prepared.is_empty():prepared=data.get("shared_contacts",{})
	if not prepared.is_empty():return prepared.bounds
	var pose=Transform3D(Basis(Vector3.UP,float(data.get("facing",0.0))),data.pos)
	var result=AABB();var first=true
	for item in shapes(int(data.variant),data.get("block_contacts",false)):
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
