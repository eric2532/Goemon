extends SceneTree
## Bake once: the landing effect shares one lightweight mesh at runtime.
const DESTINATION="res://assets/rogue/effects/dragoon_energy_dragon.res"
const BLUE=Color("248be8")
const CYAN=Color("84e7ff")
const CORE=Color("efffff")
var vertices=PackedVector3Array()
var normals=PackedVector3Array()
var colors=PackedColorArray()
var uvs=PackedVector2Array()
var indices=PackedInt32Array()

func _initialize():
	# The tail curls into an S-shaped chest and a forward-reaching dragon head.
	tube([Vector3(1,.05,1.1),Vector3(2,.5,-1.4),Vector3(1.7,1.7,-3.3),Vector3(0,3.2,-3.5),Vector3(-1.6,4.7,-1.9),Vector3(-1.9,6.2,.1),Vector3(-1.2,7.5,.7),Vector3(-.5,8.8,.0),Vector3(0,10.1,.4)], [Vector2(.03,.03),Vector2(.3,.3),Vector2(.63,.6),Vector2(.9,.8),Vector2(1.05,.88),Vector2(1.1,.95),Vector2(1.05,1.0),Vector2(1.1,1.1),Vector2(1.2,1.1)], BLUE,12)
	# Angular skull, brow and long muzzle, with a separate open lower jaw.
	tube([Vector3(0,10.1,-.25),Vector3(0,10.8,.5),Vector3(0,11.0,1.6),Vector3(0,10.75,2.75),Vector3(0,10.4,4.1),Vector3(0,10.5,4.55)], [Vector2(.7,.75),Vector2(1.25,1.05),Vector2(1.2,.9),Vector2(.75,.5),Vector2(.66,.34),Vector2(.15,.16)],BLUE,10)
	tube([Vector3(0,9.85,1),Vector3(0,9.25,2.3),Vector3(0,9.45,3.7),Vector3(0,10.05,4.42)],[Vector2(.7,.42),Vector2(.64,.24),Vector2(.49,.2),Vector2(.08,.08)],BLUE,8)
	# Paired swept horns and wide cheek fins give a readable silhouette in 3D.
	for side in [-1,1]:
		tube([Vector3(side*.82,11.35,.2),Vector3(side*1.02,12.25,-.35),Vector3(side*1.12,13.3,-1.2),Vector3(side*1.1,14.25,-2.05)],[Vector2(.4,.38),Vector2(.3,.28),Vector2(.17,.14),Vector2(.008,.008)],CYAN,7)
		tube([Vector3(side*.93,10.7,.35),Vector3(side*1.82,11.1,-.8),Vector3(side*2.2,11.25,-2.3)],[Vector2(.55,.38),Vector2(.45,.15),Vector2(.01,.01)],BLUE,7)
		# Raised, slanted brow; the eyes sit just proud of each side of the skull.
		tube([Vector3(side*.95,11.5,1.25),Vector3(side*1.21,11.35,2.05),Vector3(side*.72,11.1,2.8)],[Vector2(.18,.22),Vector2(.2,.18),Vector2(.03,.04)],CYAN,6)
		ellipsoid(Vector3(side*1.08,11.08,1.82),Vector3(.12,.18,.45),CORE)
		ellipsoid(Vector3(side*1.18,11.1,1.97),Vector3(.025,.11,.055),Color("ffffff"))
		# Whisker streams and white-hot fangs frame the open mouth.
		tube([Vector3(side*.6,10.4,3.8),Vector3(side*1.3,10.0,4.2),Vector3(side*1.5,10.45,5.05)],[Vector2(.12,.12),Vector2(.09,.09),Vector2(.006,.006)],CYAN,6)
		for z in [2.55,3.35]:
			tube([Vector3(side*.48,10.35,z),Vector3(side*.38,9.8,z+.12)],[Vector2(.14,.13),Vector2(.007,.007)],CORE,5)
		# Two short forelimbs ending in three pointed energy talons.
		tube([Vector3(-1.3+side*.8,7.2,.3),Vector3(-1.3+side*1.9,7.2,1.3),Vector3(-1.3+side*2.25,6.2,2.0),Vector3(-1.3+side*2.6,6.6,2.9)],[Vector2(.43,.43),Vector2(.36,.34),Vector2(.24,.22),Vector2(.19,.19)],BLUE,8)
		for claw in range(3):
			var tip=Vector3(-1.3+side*(2.25+claw*.35),6.6,2.8)
			tube([tip,tip+Vector3(side*.12,.14,.55),tip+Vector3(side*.12,.55,.9)],[Vector2(.13,.13),Vector2(.09,.09),Vector2(.006,.006)],CYAN,5)
	# Curved, tapering ice-energy mane rather than a flat emblem or billboard.
	for spine in [[0,10.5,-.2,1.7],[-.3,9.2,-.65,1.8],[-1,7.9,-.15,1.5],[-1.8,6.4,-.65,1.55],[-1.6,4.65,-2.4,1.3],[0,3.2,-3.7,.85]]:
		var p=Vector3(spine[0],spine[1],spine[2])
		tube([p,p+Vector3(0,.55,-spine[3]*.65),p+Vector3(0,.38,-spine[3])],[Vector2(.24,.6),Vector2(.15,.4),Vector2(.008,.008)],CYAN,6)
	# A small nose horn and a curling tail stream finish the reference's profile.
	tube([Vector3(0,10.7,3.65),Vector3(0,11.2,4),Vector3(0,11.85,4.0)],[Vector2(.2,.25),Vector2(.15,.15),Vector2(.006,.006)],CYAN,6)
	tube([Vector3(0,2.9,-3.5),Vector3(0,3.3,-5.05),Vector3(0,4.6,-5.65),Vector3(0,5.25,-5.25)],[Vector2(.45,.45),Vector2(.35,.35),Vector2(.18,.18),Vector2(.008,.008)],CYAN,8)
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.resource_name="DragoonEnergyDragon"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINATION.get_base_dir()))
	assert(ResourceSaver.save(mesh,DESTINATION,ResourceSaver.FLAG_COMPRESS)==OK)
	print("DRAGON_MESH_BAKED vertices=%d triangles=%d bounds=%s"%[vertices.size(),indices.size()/3,mesh.get_aabb()]);quit()

func tube(points:Array,radii:Array,color:Color,sides:int):
	# Smooth the long neck and tail without adding a live animation rig.
	if points.size()>=7:
		var curved=[];var sizes=[]
		for segment in points.size()-1:
			for step in 4:
				var t=float(step)/4.0
				var a:Vector3=points[maxi(0,segment-1)];var b:Vector3=points[segment]
				var c:Vector3=points[segment+1];var d:Vector3=points[mini(points.size()-1,segment+2)]
				curved.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
				sizes.append(radii[segment].lerp(radii[segment+1],t))
		curved.append(points[-1]);sizes.append(radii[-1]);points=curved;radii=sizes
	var first=vertices.size()
	for i in points.size():
		var tangent:Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
		var hint=Vector3.RIGHT if absf(tangent.x)<.85 else Vector3.FORWARD
		var axis=(hint-tangent*hint.dot(tangent)).normalized();var cross=tangent.cross(axis).normalized()
		for j in sides:
			var angle=TAU*j/sides;var normal=(axis*cos(angle)/radii[i].x+cross*sin(angle)/radii[i].y).normalized()
			var p:Vector3=points[i]+axis*cos(angle)*radii[i].x+cross*sin(angle)*radii[i].y
			vertices.append(p);normals.append(normal);uvs.append(Vector2(float(j)/sides,p.y/14.5))
			colors.append(color.lerp(CYAN,maxf(0,normal.z)*.24) if color==BLUE else color)
			if i>0:
				var a=first+(i-1)*sides+j;var b=first+(i-1)*sides+(j+1)%sides;var c=first+i*sides+j;var d=first+i*sides+(j+1)%sides
				indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	# Close both ends so the volumetric shape reads correctly from any camera.
	for end in [0,points.size()-1]:
		for j in range(1,sides-1):
			var a=first+end*sides;var b=a+j;var c=a+j+1
			indices.append_array(PackedInt32Array([a,c,b] if end==0 else [a,b,c]))

func ellipsoid(center:Vector3,size:Vector3,color:Color):
	var points=[];var radii=[]
	for i in 7:
		var angle=PI*float(i)/6
		points.append(center+Vector3(0,cos(angle)*size.y,0))
		radii.append(Vector2(maxf(.003,sin(angle)*size.x),maxf(.003,sin(angle)*size.z)))
	tube(points,radii,color,10)
