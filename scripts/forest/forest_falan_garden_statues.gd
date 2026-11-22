extends RefCounted
## Reusable sculpted silhouettes for the city's limestone and bronze monuments.
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
static var sculptures:Dictionary={}

static func build(root:Node3D,boxes,p:Vector3,serial:int):
 var rider=serial==10462
 var stone=Fort.material(Color("769e94") if rider else Color("b5b8aa"),false)
 var trim=Fort.material(Color("8ab0a3") if rider else Color("d5d6c4"),false)
 var plinth=Vector3(2.32,1.23,4.06) if rider else Vector3(1.78,1.22,1.78)
 boxes.add(p+Vector3.UP*.63,plinth,stone)
 for level in [.12,1.13,1.27]:
  var overhang=.25 if level!=1.13 else .11
  boxes.add(p+Vector3.UP*level,Vector3(plinth.x+overhang,.14,plinth.z+overhang),trim)
 for side in [-1,1]:
  boxes.add(p+Vector3(side*(plinth.x*.5+.016),.65,0),Vector3(.08,.55,plinth.z*.73),trim)
  boxes.add(p+Vector3(side*(plinth.x*.5+.061),.65,0),Vector3(.025,.37,plinth.z*.64),stone)
 if not sculptures.has(serial):sculptures[serial]=sculpt(serial)
 var figure=Geo.mesh(root,sculptures[serial],p+Vector3.UP*1.34,stone)
 figure.name="FalanStatue_%d"%serial
 figure.rotation.y=PI*.5 if serial==10402 else -PI*.25 if rider else 0.0

static func sculpt(serial:int)->ArrayMesh:
 var tool=SurfaceTool.new()
 tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var oval=SphereMesh.new()
 oval.radial_segments=10
 oval.rings=6
 var shaft=CylinderMesh.new()
 shaft.radial_segments=8
 if serial==10400:
  shape(tool,oval,Vector3(0,.70,-.13),Vector3(.85,1.35,.84))
  shape(tool,oval,Vector3(0,1.16,.29),Vector3(.84,1.04,.78))
  shape(tool,oval,Vector3(0,1.33,.61),Vector3(.56,.57,.55))
  shape(tool,oval,Vector3(0,1.17,.84),Vector3(.38,.25,.29))
  for x in [-.30,.30]:
   shape(tool,oval,Vector3(x,1.57,.53),Vector3(.20,.24,.19))
   shape(tool,oval,Vector3(x,.22,.45),Vector3(.30,.45,.63))
   rod(tool,shaft,Vector3(x,.18,.53),Vector3(x,.92,.34),.13)
 elif serial==10462:
  shape(tool,oval,Vector3(0,1.60,-.10),Vector3(1.0,1.16,2.75))
  shape(tool,oval,Vector3(0,1.73,.83),Vector3(.86,1.19,.93))
  rod(tool,shaft,Vector3(0,1.74,.89),Vector3(0,2.73,1.44),.33)
  shape(tool,oval,Vector3(0,2.60,1.67),Vector3(.56,.63,1.18))
  for side in [-1,1]:
   rod(tool,shaft,Vector3(side*.22,2.76,1.36),Vector3(side*.24,3.15,1.43),.085)
   rod(tool,shaft,Vector3(side*.34,.09,-1.0-side*.18),Vector3(side*.36,1.40,-1.05),.13)
   var knee=Vector3(side*.30,.55+maxf(0,side)*.41,1.0+maxf(0,side)*.38)
   rod(tool,shaft,Vector3(side*.33,1.55,.74),knee,.13)
   rod(tool,shaft,knee,knee+Vector3(0,-.51,.21 if side<0 else -.42),.11)
   rod(tool,shaft,Vector3(side*.13,2.42,-.29),Vector3(side*.56,1.72,.27),.15)
  rod(tool,shaft,Vector3(0,1.64,-1.31),Vector3(0,.62,-1.80),.14)
  figure(tool,oval,shaft,Vector3(0,2.20,-.24),true,false)
  rod(tool,shaft,Vector3(.54,4.0,.30),Vector3(.82,5.90,1.12),.056)
 else:
  for side in [-1,1]:
   rod(tool,shaft,Vector3(side*.16,.18,side*.13),Vector3(side*.19,1.02,0),.16)
   shape(tool,oval,Vector3(side*.16,.11,.15+side*.13),Vector3(.28,.22,.42))
  figure(tool,oval,shaft,Vector3.ZERO,false,serial==10402)
 return tool.commit()

static func figure(tool:SurfaceTool,oval:Mesh,shaft:Mesh,p:Vector3,mounted:bool,turned:bool):
 shape(tool,oval,p+Vector3(0,1.03,-.05),Vector3(.67,.48,.53))
 shape(tool,oval,p+Vector3(0,1.55,0),Vector3(.70,.87,.46))
 shape(tool,oval,p+Vector3(0,2.16,.032),Vector3(.40,.53,.44))
 shape(tool,oval,p+Vector3(0,2.12,.23),Vector3(.16,.19,.16))
 for side in [-1,1]:
  var shoulder=p+Vector3(side*.32,1.74,0)
  var elbow=p+Vector3(side*.43,1.38,.15)
  var hand=p+Vector3(side*.14,1.29,.34)
  if mounted:
   elbow=p+Vector3(side*.55,1.53,.19)
   hand=p+Vector3(side*.54,1.80 if side>0 else 1.18,.54)
  elif turned and side>0:hand=p+Vector3(.28,1.59,.35)
  rod(tool,shaft,shoulder,elbow,.13)
  rod(tool,shaft,elbow,hand,.10)
  shape(tool,oval,hand,Vector3(.22,.23,.23))

static func shape(tool:SurfaceTool,mesh:Mesh,p:Vector3,size_:Vector3):
 tool.append_from(mesh,0,Transform3D(Basis.IDENTITY.scaled(size_),p))

static func rod(tool:SurfaceTool,mesh:Mesh,from:Vector3,to:Vector3,radius:float):
 var delta=to-from
 var basis=Basis(Quaternion(Vector3.UP,delta.normalized())).scaled_local(Vector3(radius*2,delta.length(),radius*2))
 tool.append_from(mesh,0,Transform3D(basis,(from+to)*.5))
