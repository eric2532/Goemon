extends RefCounted
## Source lamp families share cached solid parts and spatial batches.
const Statues=preload("res://scripts/forest/forest_falan_garden_statues.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Paint=preload("res://scripts/forest/forest_painterly_environment.gd")
static var meshes:Dictionary={}
static var cylinder:CylinderMesh
static var sphere:SphereMesh
static var box:BoxMesh
static var stone_paint:ShaderMaterial
static var metal_paint:ShaderMaterial

static func batch(parent:Node3D,serial:int,poses:Array):
 if not meshes.has(serial):meshes[serial]=shape(serial)
 var node=MultiMeshInstance3D.new();node.name="RecoveredFalanLamps"
 node.set_meta("falan_lamp_graphic",serial)
 node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
 node.multimesh.mesh=meshes[serial];node.multimesh.instance_count=poses.size()
 for i in poses.size():node.multimesh.set_instance_transform(i,poses[i])
 parent.add_child(node)

static func rod(tool:SurfaceTool,a:Vector3,b:Vector3,radius:float):
 var delta=b-a
 tool.append_from(cylinder,0,Transform3D(Basis(Quaternion(Vector3.UP,delta.normalized())).scaled_local(Vector3(radius*2,delta.length(),radius*2)),(a+b)*.5))

static func oval(tool:SurfaceTool,p:Vector3,size_:Vector3):
 tool.append_from(sphere,0,Transform3D(Basis.IDENTITY.scaled(size_),p))

static func block(tool:SurfaceTool,p:Vector3,size_:Vector3):
 tool.append_from(box,0,Transform3D(Basis.IDENTITY.scaled(size_),p))

static func lantern(frame:SurfaceTool,glass:SurfaceTool,top:Vector3,hanging:bool,globe:bool=false):
 var p=top-Vector3.UP*.36 if hanging else top+Vector3.UP*.28
 if globe:
  oval(glass,p,Vector3(.38,.36,.38))
  for row in [[-.18,.17],[.18,.19],[.26,.14],[.34,.085]]:rod(frame,p+Vector3.UP*(row[0]-.035),p+Vector3.UP*(row[0]+.035),row[1])
  return
 oval(glass,p,Vector3(.30,.48,.30))
 for y in [-.24,.24]:rod(frame,p+Vector3.UP*(y-.025),p+Vector3.UP*(y+.025),.20)
 for side in [-1,1]:
  rod(frame,p+Vector3(side*.15,-.22,0),p+Vector3(side*.15,.22,0),.016)
  rod(frame,p+Vector3(0,-.22,side*.15),p+Vector3(0,.22,side*.15),.016)
 oval(frame,p+Vector3.UP*.32,Vector3(.30,.17,.30))
 rod(frame,p+Vector3.UP*.35,p+Vector3.UP*.47,.025)

static func prepare_primitives():
 if cylinder==null:
  cylinder=CylinderMesh.new();cylinder.height=1;cylinder.top_radius=.5;cylinder.bottom_radius=.5;cylinder.radial_segments=12;cylinder.rings=0
  sphere=SphereMesh.new();sphere.radius=.5;sphere.height=1;sphere.radial_segments=12;sphere.rings=6
  box=BoxMesh.new();box.size=Vector3.ONE

static func shape(serial:int)->Mesh:
 prepare_primitives()
 var stone=SurfaceTool.new();stone.begin(Mesh.PRIMITIVE_TRIANGLES)
 var metal=SurfaceTool.new();metal.begin(Mesh.PRIMITIVE_TRIANGLES)
 var glass=SurfaceTool.new();glass.begin(Mesh.PRIMITIVE_TRIANGLES)
 var column=serial in [10611,10612]
 var height=5.5 if serial in [10428,10429] else 6.0
 for step in 3:
  var width=.65-step*.12
  block(stone,Vector3(0,.07+step*.11,0),Vector3(width,.13,width))
 rod(stone,Vector3(0,.36,0),Vector3(0,.83,0),.18)
 rod(stone if column else metal,Vector3(0,.80,0),Vector3(0,height,0),.11 if column else .045)
 for y in [.84,1.03,height*.48,height-.50,height-.18]:
  oval(metal,Vector3(0,y,0),Vector3(.23,.16,.23))
 if column:
  for y in [1.1,1.55,4.6,5.1]:
   rod(stone,Vector3(0,y-.06,0),Vector3(0,y+.06,0),.22)
  oval(stone,Vector3(0,height-.05,0),Vector3(.65,.65,.65))
  var source=Statues.sculpt(10400 if serial==10611 else 10401)
  stone.append_from(source,0,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.48),Vector3(0,height+.25,0)))
 elif serial==10428:
  lantern(metal,glass,Vector3(0,height,0),false)
 elif serial==10429:
  var last=Vector3(0,height-.6,0)
  for i in range(1,13):
   var angle=PI*float(i)/12.0
   var next=Vector3(-.42+.42*cos(angle),height-.6+sin(angle)*.50,0)
   rod(metal,last,next,.031);last=next
  lantern(metal,glass,last,true)
 else:
  var triple=serial==10423
  for side in [-1,1]:
   var sign_=side*(-1 if serial==10424 else 1)
   var end=Vector3(sign_*.78,height-.55+side*.40,0)
   var last=Vector3(0,height-.90,0)
   for i in range(1,9):
    var t=float(i)/8
    var next=Vector3(end.x*t,lerpf(height-.90,end.y,t)+sin(t*PI)*.08,0)
    rod(metal,last,next,.032);last=next
   lantern(metal,glass,end,true,true)
  if triple:lantern(metal,glass,Vector3(0,height+.1,0),false,true)
  else:
   rod(metal,Vector3(0,height-.3,0),Vector3(0,height+.4,0),.04)
   oval(metal,Vector3(0,height+.45,0),Vector3(.17,.28,.17))
   for y in [height-.15,height+.10,height+.32]:rod(metal,Vector3(0,y-.04,0),Vector3(0,y+.04,0),.10)
   rod(metal,Vector3(0,height+.52,0),Vector3(0,height+.82,0),.018)
 var result=ArrayMesh.new()
 var tools=[stone,metal] if column else [stone,metal,glass]
 if stone_paint==null:
  stone_paint=Fort.material(Color("929986")).duplicate();stone_paint.set_shader_parameter("weathered_masonry",true);stone_paint.set_shader_parameter("masonry_tile",Vector2(.34,.18))
  stone_paint.set_shader_parameter("weathered_masonry_strength",.35)
  metal_paint=ShaderMaterial.new();metal_paint.shader=Paint.SURFACE
  metal_paint.set_shader_parameter("brush_texture",Paint.BRUSH);metal_paint.set_shader_parameter("base_color",Color("696b52"));metal_paint.set_shader_parameter("surface_kind",6.0);metal_paint.set_shader_parameter("use_vertex_color",false)
 var materials=[stone_paint,metal_paint,Geo.mat("b9d9d6",.1,.12)]
 for i in tools.size():
  var mesh=tools[i].commit()
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0))
  result.surface_set_material(i,materials[i])
 return result
