class_name WorldExpansion
extends RefCounted
const LINEAR_SCALE=3.1622776601683795
static func bounds(area: int)->Rect2:
	var dimensions=Vector2(186,163 if area==0 else 186)*LINEAR_SCALE
	return Rect2(Vector2(-dimensions.x*.5,62-dimensions.y if area==0 else -8-dimensions.y*.5),dimensions)
static func plan(world):
	world.outposts.clear();world.outer_routes.clear()
	if world.area_index==0:
		for z in [-155,-275,-397]:
			for x in [-195,0,195]:world.outposts.append(Vector3(x,0,z))
	else:
		for point in [Vector2(-205,-200),Vector2(0,-225),Vector2(205,-200),Vector2(-220,-20),Vector2(220,-20),Vector2(-205,190),Vector2(0,210),Vector2(205,190),Vector2(0,-130)]:
			world.outposts.append(Vector3(point.x,0,point.y))
	for i in range(world.outposts.size()):
		var p=world.outposts[i];p.y=world.raw_height(p.x,p.z);world.outposts[i]=p
		world.landmarks["OUTPOST %02d" % (i+1)]=p
		var nearest=Vector3(0,world.raw_height(0,-65),-65)
		if world.area_index==0 and absf(p.x)>50:nearest=Vector3(signf(p.x)*76,world.raw_height(signf(p.x)*76,-51),-51)
		for j in range(i):
			if p.distance_to(world.outposts[j])<p.distance_to(nearest):nearest=world.outposts[j]
		world.outer_routes.append([nearest,p])
	# Cross-links keep the expanded map connected instead of forming dead-end spokes.
	for pair in ([[0,1],[1,2],[3,4],[4,5],[6,7],[7,8]] if world.area_index==0 else [[0,1],[1,2],[3,5],[5,6],[6,7],[7,4],[8,1]]):
		world.outer_routes.append([world.outposts[pair[0]],world.outposts[pair[1]]])
static func flatten(world,x: float,z: float,h: float)->float:
	for c in world.outposts:
		var distance=Vector2(x-c.x,z-c.z).length()
		if distance<31:return lerpf(c.y,h,smoothstep(25,31,distance))
	return h
static func dress(world):
	var stone=Geo.mat(["c7b48b","809e9e","d1bda6","c8a073"][world.area_index])
	for route in world.outer_routes:path(world,route[0],route[1])
	for i in range(world.outposts.size()):
		var c=world.outposts[i]
		Geo.cylinder(world,c-Vector3.UP*.055,24,.14,stone,true)
		# Carved approach, shrine and lanterns retain normal building/character scale.
		world.torii(c.x,c.z+26,10)
		world.temple(c.x,c.z-34,11,8,1)
		for side in [-1,1]:
			world.lantern(c+Vector3(side*23,0,6))
			world.lantern(c+Vector3(side*23,0,-6))
		for j in range(9):
			var a=j*TAU/9;var p=c+Vector3(cos(a),0,sin(a))*41
			if absf(p.x-c.x)<13:continue
			p.y=world.height_at(p.x,p.z)
			if world.area_index==1:
				Geo.spike(world,p,p+Vector3(2,6,1),1.4,Geo.mat("68c6c5",.2,.2))
			else:world.tree(p,world.area_index==2,world.area_index==3)
	# Low-cost scattered stones between districts (one shared mesh/material).
	var mesh=SphereMesh.new();mesh.radius=1;mesh.height=2;mesh.radial_segments=8;mesh.rings=4
	var multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.mesh=mesh;multimesh.instance_count=360
	for i in range(360):
		var p=Vector3(world.rng.randf_range(world.playable_bounds.position.x+6,world.playable_bounds.end.x-6),0,world.rng.randf_range(world.playable_bounds.position.y+6,world.playable_bounds.end.y-6))
		p.y=world.height_at(p.x,p.z)-.35
		for c in world.outposts:
			if Vector2(p.x-c.x,p.z-c.z).length()<32:p.y-=8
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(1.3,.6,1)*world.rng.randf_range(.5,2)),p))
	var instance=MultiMeshInstance3D.new();instance.multimesh=multimesh;instance.material_override=Geo.mat("819586");world.add_child(instance)
static func enemy_spots(world,per_outpost: int)->Array:
	var result=[]
	for c in world.outposts:
		for i in range(per_outpost):
			# Sunflower packing: even spacing, safely inside each clear 24m court.
			var angle=i*2.399963;var radius=3+sqrt(float(i)/per_outpost)*18
			result.append(Vector2(c.x+cos(angle)*radius,c.z+sin(angle)*radius))
	return result
static func walls(world,material: Material):
	var rect=world.playable_bounds;var center=rect.get_center()
	for x in [rect.position.x-2,rect.end.x+2]:
		var wall=Geo.box(world,Vector3(x,22,center.y),Vector3(4,64,rect.size.y+8),material,true)
		if world.area_index==0:wall.hide()
	for z in [rect.position.y-2,rect.end.y+2]:
		var wall=Geo.box(world,Vector3(center.x,22,z),Vector3(rect.size.x+8,64,4),material,true)
		if world.area_index==0:wall.hide()

static func path(world,a: Vector3,b: Vector3):
	var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side=(b-a).cross(Vector3.UP).normalized()*3.5
	var segments=ceili(a.distance_to(b)/2.5)
	for i in range(segments):
		var p=a.lerp(b,float(i)/segments);var q=a.lerp(b,float(i+1)/segments)
		for vertex in [p-side,p+side,q-side,p+side,q+side,q-side]:
			vertex.y=world.height_at(vertex.x,vertex.z)+.08
			st.set_color(Color("c7b38a") if i%2 else Color("d5c296"));st.add_vertex(vertex)
	st.generate_normals()
	var material=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=1
	Geo.mesh(world,st.commit(),Vector3.ZERO,material)
