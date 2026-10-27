extends SceneTree
## Author in flight space, then bake into the existing descent/eruption contract.
const DESTINATION="res://assets/rogue/effects/dragoon_energy_dragon.res"
const BODY=Color("3f3b49")
const ARMOR=Color("5b5564")
const BELLY=Color("69616b")
const MEMBRANE=Color("393441")
const CLAW=Color("817982")
const FLIGHT=Basis(Vector3(1,0,0),Vector3(0,.573576,.819152),Vector3(0,-.819152,.573576))
const OFFSET=Vector3(0,2.5,-3)
var vertices=PackedVector3Array()
var normals=PackedVector3Array()
var colors=PackedColorArray()
var uvs=PackedVector2Array()
var indices=PackedInt32Array()

func _initialize():
	# Broad ribcage, rising neck and long balancing tail follow the approved concept.
	var spine=[Vector3(0,1.1,-6),Vector3(0,1.2,-4.8),Vector3(0,1.5,-3.6),Vector3(0,1.8,-2.4),Vector3(0,2.3,-1.3),Vector3(0,3.1,-.55),Vector3(0,3.7,.35),Vector3(0,3.85,1.35)]
	var radii=[Vector2(.65,.75),Vector2(1.05,1.05),Vector2(1.45,1.45),Vector2(1.35,1.45),Vector2(.95,1.13),Vector2(.74,.92),Vector2(.68,.79),Vector2(.66,.66)]
	tube(spine,radii,BODY,12)
	var tail=[Vector3(0,1.15,-5.6),Vector3(0,1.1,-6.6),Vector3(.2,1,-7.7),Vector3(.7,.75,-8.8),Vector3(1.65,.55,-9.8),Vector3(2.85,.65,-10.45),Vector3(3.7,1,-10.4),Vector3(4.1,1.35,-9.8),Vector3(4,1.6,-9.2)]
	var tail_r=[Vector2(.72,.76),Vector2(.61,.64),Vector2(.48,.52),Vector2(.36,.4),Vector2(.27,.3),Vector2(.19,.23),Vector2(.13,.16),Vector2(.07,.1),Vector2(.006,.006)]
	tube(tail,tail_r,BODY,10)
	for i in range(1,spine.size()-1):
		var p:Vector3=spine[i];var tangent:Vector3=(spine[i+1]-spine[i-1]).normalized()
		var up=tangent.cross(Vector3.RIGHT).normalized();var width:float=radii[i].x;var height:float=radii[i].y
		# Staggered scales wrap the neck and chest; the dark core forms their seams.
		for row in 2:
			var t=float(row)/2
			var center=p.lerp(spine[i+1],t)
			var radius:Vector2=radii[i].lerp(radii[i+1],t)
			for band in 8:
				var angle=TAU*(float(band)+.12*row)/8
				var normal=(Vector3.RIGHT*cos(angle)+up*sin(angle)).normalized()
				var at=center+(Vector3.RIGHT*radius.x*cos(angle)+up*radius.y*sin(angle))*1.015
				var color=BELLY if sin(angle)<-.6 else ARMOR
				plate(at,tangent.cross(normal),-tangent,normal,lerpf(radius.y,radius.x,absf(sin(angle)))*.42,.78,.15,color)
		var top=p+up*height
		tube([top,top+up*.45-tangent*.35,top+up*(.85 if i<4 else .55)-tangent*.85],[Vector2(.24,.32),Vector2(.19,.22),Vector2(.006,.006)],ARMOR,6)
	for i in range(1,tail.size()-1):
		var tangent:Vector3=(tail[i+1]-tail[i-1]).normalized();var up=tangent.cross(Vector3.RIGHT).normalized()
		plate(tail[i]+up*tail_r[i].y,Vector3.RIGHT,-tangent,up,tail_r[i].x*1.12,.65,.12,ARMOR)
		tube([tail[i]+up*tail_r[i].y,tail[i]+up*(tail_r[i].y+.38)-tangent*.45],[Vector2(.14,.24),Vector2(.005,.005)],ARMOR,5)
	head()
	for side in [-1.0,1.0]:
		limbs(side)
		wing(side)
	var flight_bounds=AABB(vertices[0],Vector3.ZERO)
	var inverse=FLIGHT.inverse()
	for i in vertices.size():
		flight_bounds=flight_bounds.expand(vertices[i])
		vertices[i]=inverse*(vertices[i]-OFFSET)+Vector3(0,7,0)
		normals[i]=(inverse*normals[i]).normalized()
		assert(vertices[i].is_finite() and normals[i].is_finite())
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.resource_name="DragoonEnergyDragon"
	# Shader flight and wing poses must remain inside the renderer's culling bounds.
	mesh.custom_aabb=mesh.get_aabb().merge(flight_bounds).grow(2.0)
	assert(mesh.get_surface_count()==1 and indices.size()/3<16000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINATION.get_base_dir()))
	assert(ResourceSaver.save(mesh,DESTINATION,ResourceSaver.FLAG_COMPRESS)==OK)
	print("DRAGON_MESH_BAKED vertices=%d triangles=%d bounds=%s"%[vertices.size(),indices.size()/3,mesh.get_aabb()]);quit()

func head():
	# A wedge skull and genuinely open jaw replace the round, smiling muzzle.
	tube([Vector3(0,3.8,.9),Vector3(0,4,1.5),Vector3(0,3.94,2.15),Vector3(0,3.7,2.9),Vector3(0,3.48,3.65),Vector3(0,3.3,3.9)],[Vector2(.58,.62),Vector2(.82,.68),Vector2(.73,.48),Vector2(.48,.32),Vector2(.32,.25),Vector2(.025,.035)],BODY,8)
	tube([Vector3(0,3.48,1.55),Vector3(0,2.6,2.1),Vector3(0,2.23,2.9),Vector3(0,2.34,3.48),Vector3(0,2.53,3.69)],[Vector2(.53,.35),Vector2(.48,.2),Vector2(.34,.16),Vector2(.2,.12),Vector2(.01,.015)],ARMOR,8)
	plate(Vector3(0,4.42,1.75),Vector3.RIGHT,Vector3.BACK,Vector3.UP,.55,1.45,.16,ARMOR)
	tube([Vector3(0,4.12,2.65),Vector3(0,3.91,3.1),Vector3(0,3.54,3.8)],[Vector2(.19,.16),Vector2(.13,.12),Vector2(.01,.01)],ARMOR,6)
	for side in [-1.0,1.0]:
		# Two main horns, a sharp cheek and a thick brow frame each ruby eye.
		tube([Vector3(side*.58,4.4,1.35),Vector3(side*.75,4.85,.9),Vector3(side*.92,5.4,.1),Vector3(side*1.02,5.85,-.8),Vector3(side*.98,6,-1.4)],[Vector2(.3,.32),Vector2(.26,.28),Vector2(.18,.21),Vector2(.08,.11),Vector2(.004,.004)],ARMOR,7)
		plate(Vector3(side*.67,3.92,1.35),Vector3(0,1,0),Vector3(0,-.3,-1).normalized(),Vector3.RIGHT*side,.42,1.1,.2,ARMOR)
		tube([Vector3(side*.63,4.15,1.7),Vector3(side*.78,4.16,2.13),Vector3(side*.48,3.96,2.63)],[Vector2(.18,.18),Vector2(.18,.14),Vector2(.015,.025)],ARMOR,6)
		var eye=Vector3(side*.746,3.99,2.1)
		plate(eye,Vector3.BACK,Vector3.UP,Vector3.RIGHT*side,.28,.22,.055,Color("ee1526"))
		tube([Vector3(side*.72,3.7,1.75),Vector3(side*1.0,3.73,1.02),Vector3(side*1.15,3.87,.35)],[Vector2(.21,.25),Vector2(.17,.19),Vector2(.005,.005)],ARMOR,6)
		for i in 5:
			var z=2.22+i*.25;var x=lerpf(.55,.23,float(i)/4)
			var top=Vector3(side*x,lerpf(3.68,3.45,float(i)/4),z)
			var bottom=Vector3(side*x*.65,lerpf(2.58,2.39,float(i)/4),z+.08)
			tube([top,top+Vector3(-side*.035,-(.27 if i==0 else .14),.09)],[Vector2(.065,.075),Vector2(.004,.004)],CLAW,5)
			tube([bottom,bottom+Vector3(0,.12,.05)],[Vector2(.045,.05),Vector2(.004,.004)],CLAW,5)

func limbs(side:float):
	var shoulder=Vector3(side*1.18,2,-2.15)
	tube([shoulder,Vector3(side*1.7,1.35,-1.6),Vector3(side*2,.7,-1),Vector3(side*1.9,.65,.2)],[Vector2(.63,.62),Vector2(.48,.5),Vector2(.29,.3),Vector2(.25,.3)],BODY,9)
	plate(shoulder+Vector3(side*.28,.3,.2),Vector3.BACK,Vector3.DOWN,Vector3(side,.2,.2).normalized(),.67,1.2,.35,ARMOR)
	plate(Vector3(side*2,.95,-.6),Vector3.RIGHT,Vector3.BACK,Vector3.UP,.32,.85,.18,ARMOR)
	var hip=Vector3(side*.85,1.2,-4.75)
	tube([hip,Vector3(side*1.5,.65,-3.95),Vector3(side*1.7,-.15,-4.2),Vector3(side*1.65,-.65,-5.25),Vector3(side*1.7,-.9,-4.6)],[Vector2(.85,.85),Vector2(.74,.77),Vector2(.43,.46),Vector2(.24,.26),Vector2(.35,.23)],BODY,10)
	plate(Vector3(side*1.5,.7,-4),Vector3.BACK,Vector3.DOWN,Vector3.RIGHT*side,.7,1.35,.28,ARMOR)
	tube([Vector3(side*1.82,-.3,-4.65),Vector3(side*2.05,.05,-5.45),Vector3(side*2.12,.15,-5.85)],[Vector2(.19,.23),Vector2(.13,.16),Vector2(.005,.005)],ARMOR,6)
	for i in 3:
		var finger=Vector3(side*(1.63+i*.25),.62,.1-i*.09)
		tube([finger,finger+Vector3(side*.08,-.13,.45),finger+Vector3(side*.1,-.47,.77)],[Vector2(.16,.17),Vector2(.13,.14),Vector2(.075,.08)],ARMOR,6)
		tube([finger+Vector3(side*.1,-.4,.7),finger+Vector3(side*.1,-.6,.78),finger+Vector3(side*.04,-.8,.6)],[Vector2(.1,.11),Vector2(.06,.07),Vector2(.004,.004)],CLAW,6)
		var toe=Vector3(side*(1.38+i*.28),-.88,-4.65+i*.03)
		tube([toe,toe+Vector3(0,-.12,.45),toe+Vector3(0,-.4,.8)],[Vector2(.18,.18),Vector2(.14,.14),Vector2(.085,.09)],ARMOR,6)
		tube([toe+Vector3(0,-.33,.7),toe+Vector3(0,-.53,.82),toe+Vector3(0,-.75,.63)],[Vector2(.11,.12),Vector2(.07,.08),Vector2(.004,.004)],CLAW,6)

func wing(side:float):
	var first=vertices.size()
	var root_=Vector3(side*1.35,2.7,-2.9)
	var elbow=Vector3(side*3.4,5.6,-3.25)
	var tips=[Vector3(side*9.8,7.45,-5.1),Vector3(side*9.4,4.1,-7.45),Vector3(side*7.1,2.5,-8.65),Vector3(side*4.5,1.6,-8.25),Vector3(side*1.35,1.6,-5.4)]
	# Curved, scalloped membrane sectors follow the fingers without overlapping fans.
	for band in tips.size()-1:
		for radial in range(1,9):
			for across in 6:
				var a=wing_point(elbow,tips[band],tips[band+1],float(radial-1)/8,float(across)/6)
				var b=wing_point(elbow,tips[band],tips[band+1],float(radial)/8,float(across)/6)
				var c=wing_point(elbow,tips[band],tips[band+1],float(radial)/8,float(across+1)/6)
				var d=wing_point(elbow,tips[band],tips[band+1],float(radial-1)/8,float(across+1)/6)
				var shade=MEMBRANE.lerp(ARMOR,.1+sin(float(radial)/8*PI)*.28)
				panel(a,b,c,shade);panel(a,c,d,shade)
	panel(root_,elbow,tips[-1],MEMBRANE)
	tube([root_,root_.lerp(elbow,.5)+Vector3(0,.2,.25),elbow,elbow.lerp(tips[0],.48)+Vector3(0,.55,.1),tips[0]],[Vector2(.49,.46),Vector2(.4,.36),Vector2(.29,.31),Vector2(.2,.22),Vector2(.006,.006)],ARMOR,8)
	for tip in tips.slice(1):
		tube([elbow,elbow.lerp(tip,.35)+Vector3(0,.32,.1),elbow.lerp(tip,.7)+Vector3(0,.26,.08),tip],[Vector2(.14,.17),Vector2(.11,.13),Vector2(.07,.08),Vector2(.005,.005)],ARMOR,6)
	tube([elbow,elbow+Vector3(side*.1,.72,.45),elbow+Vector3(side*.3,1.15,.25)],[Vector2(.25,.25),Vector2(.17,.18),Vector2(.004,.004)],ARMOR,7)
	for i in range(first,vertices.size()):colors[i].a=0.0

func wing_point(elbow:Vector3,a:Vector3,b:Vector3,r:float,t:float)->Vector3:
	var edge=a.lerp(b,t).lerp(elbow,sin(t*PI)*.23)
	var p=elbow.lerp(edge,r)
	p.y+=sin(r*PI)*(.32+sin(t*PI)*.35)
	p.z+=sin(r*PI)*.1
	return p

func plate(center:Vector3,across:Vector3,along:Vector3,outward:Vector3,width:float,length_:float,lift:float,color:Color):
	var top=center-along*length_*.5
	var left=center-across*width-along*length_*.25
	var right=center+across*width-along*length_*.25
	var tip=center+along*length_*.7
	var ridge=center+outward*lift
	var edges=[[top,left],[left,tip],[tip,right],[right,top]]
	for i in edges.size():
		facet(edges[i][0],edges[i][1],ridge,color.lerp(BODY,.12 if i<2 else 0),outward)

func facet(a:Vector3,b:Vector3,c:Vector3,color:Color,outward:Vector3=Vector3.ZERO):
	var normal=(c-a).cross(b-a).normalized()
	if normal.length_squared()<.1:return
	if outward!=Vector3.ZERO and normal.dot(outward)<0:
		var swap=b;b=c;c=swap;normal=-normal
	for point in [a,b,c]:
		indices.append(vertices.size());vertices.append(point);normals.append(normal);colors.append(color);uvs.append(Vector2(0,clampf((point.z+11)/15,0,1)))

func panel(a:Vector3,b:Vector3,c:Vector3,color:Color):
	facet(a,b,c,color);facet(c,b,a,color)

func tube(points:Array,radii:Array,color:Color,sides:int):
	# Offline curves retain a single immutable runtime mesh.
	if points.size()>=7:
		var curved=[];var sizes=[]
		for segment in points.size()-1:
			for step in 3:
				var t=float(step)/3.0
				var a:Vector3=points[maxi(0,segment-1)];var b:Vector3=points[segment]
				var c:Vector3=points[segment+1];var d:Vector3=points[mini(points.size()-1,segment+2)]
				curved.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
				sizes.append(radii[segment].lerp(radii[segment+1],t))
		curved.append(points[-1]);sizes.append(radii[-1]);points=curved;radii=sizes
	var first=vertices.size()
	for i in points.size():
		var tangent:Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var hint=Vector3.RIGHT if absf(tangent.x)<.85 else Vector3.UP
		var axis=(hint-tangent*hint.dot(tangent)).normalized();var cross=tangent.cross(axis).normalized()
		for j in sides:
			var angle=TAU*j/sides;var normal=(axis*cos(angle)/radii[i].x+cross*sin(angle)/radii[i].y).normalized()
			var p:Vector3=points[i]+axis*cos(angle)*radii[i].x+cross*sin(angle)*radii[i].y
			vertices.append(p);normals.append(normal);uvs.append(Vector2(float(j)/sides,clampf((p.z+11)/15,0,1)))
			colors.append(color)
			if i>0:
				var a=first+(i-1)*sides+j;var b=first+(i-1)*sides+(j+1)%sides;var c=first+i*sides+j;var d=first+i*sides+(j+1)%sides
				indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	for end in [0,points.size()-1]:
		for j in range(1,sides-1):
			var a=first+end*sides;var b=a+j;var c=a+j+1
			indices.append_array(PackedInt32Array([a,c,b] if end==0 else [a,b,c]))
