extends RefCounted
## A saturated finishing edge and its true swept-capsule footprint.
## Geometry is presentation only; damage stays in NinjaDashStrike.
const LIFE=.50
static func spawn(fx,pos: Vector3,angle: float,reach: float,width: float,scale_: float,height: float)->Node3D:
	var root=Node3D.new();root.name="NinjaFinishingCut"
	root.position=pos;root.rotation.y=angle;root.scale=Vector3.ONE*scale_
	var steps=[16,24,32][clampi(fx.quality,0,2)]
	var floor_y=.06/scale_
	var fill=mesh(fx,footprint(fx,reach,width,steps,floor_y),Color("780de0"),.28,false)
	fill.name="FinishingArea";root.add_child(fill)
	var rim=mesh(fx,outline(fx,reach,width,.09,steps,floor_y+.006),Color("bd55ff"),.95,false)
	rim.name="ReachOutline";root.add_child(rim)
	var cut=Node3D.new();cut.name="PurpleFinishingEdge";root.add_child(cut)
	var center_y=height/scale_
	# Three nested edges stay inside the damage radius; they never grow beyond it.
	cut.add_child(mesh(fx,crescent(fx,reach,width,.50,steps,center_y),Color("7f1be8"),.32,true))
	cut.add_child(mesh(fx,crescent(fx,reach,width,.42,steps,center_y),Color("9f23ef"),.94,false))
	cut.add_child(mesh(fx,crescent(fx,reach,width,.045,steps,center_y),Color("ecc2ff"),.95,false))
	return fx._add(root,LIFE,"ninja-finisher",{"edge":cut,"area":fill,"rim":rim})
static func mesh(fx,geometry: Mesh,color: Color,opacity: float,glow: bool)->MeshInstance3D:
	var node=MeshInstance3D.new();node.mesh=geometry
	node.material_override=fx._material(color,opacity,glow)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
static func contour(reach: float,radius: float,steps: int,y: float)->PackedVector3Array:
	var points=PackedVector3Array()
	for i in steps+1:
		var a=PI*i/steps;points.append(Vector3(cos(a)*radius,y,reach+sin(a)*radius))
	for i in steps+1:
		var a=PI+PI*i/steps;points.append(Vector3(cos(a)*radius,y,sin(a)*radius))
	return points
static func footprint(fx,reach: float,width: float,steps: int,y: float)->ArrayMesh:
	var points=contour(reach,width,steps,y)
	var center=points.size();points.append(Vector3(0,y,reach*.5));var triangles=PackedInt32Array()
	for i in center:triangles.append_array(PackedInt32Array([center,i,(i+1)%center]))
	return fx._array_mesh(points,triangles)
static func outline(fx,reach: float,width: float,thickness: float,steps: int,y: float)->ArrayMesh:
	var outer=contour(reach,width,steps,y);var inner=contour(reach,maxf(.01,width-thickness),steps,y)
	var vertices=PackedVector3Array();var triangles=PackedInt32Array()
	for i in outer.size():vertices.append(outer[i]);vertices.append(inner[i])
	for i in outer.size():
		var a=i*2;var b=((i+1)%outer.size())*2
		triangles.append_array(PackedInt32Array([a,a+1,b,b,a+1,b+1]))
	return fx._array_mesh(vertices,triangles)
static func crescent(fx,reach: float,width: float,thickness: float,steps: int,y: float)->ArrayMesh:
	var vertices=PackedVector3Array();var triangles=PackedInt32Array()
	for i in steps+1:
		var angle=-PI*.5+PI*i/steps
		var taper=.35+.65*sin(PI*float(i)/steps)
		for radius in [width,maxf(.01,width-thickness*taper)]:
			# A diagonal upright crescent stays within the endpoint capsule.
			# Its high edge remains visible over Ninja's silhouette in chase view.
			var x=sin(angle)*radius*.96;var up=cos(angle)*radius*.96
			vertices.append(Vector3(x*cos(.35)-up*sin(.35),y+x*sin(.35)+up*cos(.35),reach+cos(angle)*radius*.18))
		if i<steps:
			var n=i*2;triangles.append_array(PackedInt32Array([n,n+1,n+2,n+1,n+3,n+2]))
	return fx._array_mesh(vertices,triangles)
