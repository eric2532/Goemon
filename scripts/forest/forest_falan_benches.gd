extends RefCounted
## Source 10405–10407 / 10448–10451: slatted wood, turned posts and curved arms.
const Parts=preload("res://scripts/forest/forest_falan_lamps.gd")
const Paint=preload("res://scripts/forest/forest_painterly_environment.gd")
static var meshes:Dictionary={}
static var wood:ShaderMaterial

static func short_seat(serial:int)->bool:return serial in [10405,10406,10449,10451]

static func yaw(serial:int)->float:
 return (PI*.5 if serial in [10405,10407,10448,10449] else 0.0)+(PI if serial<10448 else 0.0)

static func batch(parent:Node3D,serial:int,poses:Array):
 var short_=short_seat(serial)
 if not meshes.has(short_):meshes[short_]=shape(short_)
 var node=MultiMeshInstance3D.new();node.name="RecoveredFalanBenches"
 node.set_meta("falan_bench_graphic",serial)
 node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
 node.multimesh.mesh=meshes[short_];node.multimesh.instance_count=poses.size()
 for i in poses.size():node.multimesh.set_instance_transform(i,poses[i])
 parent.add_child(node)

static func shape(short_:bool)->Mesh:
 Parts.prepare_primitives()
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var width=1.37 if short_ else 2.75
 var edge=width*.5-.10
 for i in 5:
  Parts.block(tool,Vector3(0,.80,-.34+i*.165),Vector3(width-.10,.11,.135))
 for x in [-edge,edge]:
  for z in [-.31,.31]:
   Parts.block(tool,Vector3(x,.43,z),Vector3(.10,.86,.10))
   Parts.oval(tool,Vector3(x,.12,z),Vector3(.13,.13,.13))
  Parts.block(tool,Vector3(x,.69,0),Vector3(.14,.15,.83))
  Parts.rod(tool,Vector3(x,.72,.34),Vector3(x,1.56,.34),.045)
  Parts.oval(tool,Vector3(x,1.60,.34),Vector3(.13,.13,.13))
  Parts.rod(tool,Vector3(x,.84,-.30),Vector3(x,1.13,-.30),.047)
  var last=Vector3(x,1.13,-.33)
  for i in range(1,7):
   var t=float(i)/6
   var next=Vector3(x,lerpf(1.13,1.36,t)+sin(t*PI)*.065,lerpf(-.33,.35,t))
   Parts.rod(tool,last,next,.045);last=next
 Parts.block(tool,Vector3(0,1.48,.34),Vector3(width,.14,.14))
 Parts.block(tool,Vector3(0,.96,.34),Vector3(width-.12,.10,.11))
 var count_=5 if short_ else 11
 for i in count_:
  var x=lerpf(-edge+.14,edge-.14,float(i)/maxi(1,count_-1))
  Parts.rod(tool,Vector3(x,1.01,.34),Vector3(x,1.43,.34),.024)
  Parts.oval(tool,Vector3(x,1.21,.34),Vector3(.075,.13,.075))
 var result=tool.commit()
 if wood==null:
  wood=ShaderMaterial.new();wood.shader=Paint.SURFACE
  wood.set_shader_parameter("brush_texture",Paint.BRUSH);wood.set_shader_parameter("base_color",Color("896c40"))
  wood.set_shader_parameter("surface_kind",0.0);wood.set_shader_parameter("grain_axis",Vector3.RIGHT);wood.set_shader_parameter("use_vertex_color",false)
 result.surface_set_material(0,wood)
 return result
