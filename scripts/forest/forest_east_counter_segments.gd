extends RefCounted
## Private3m continuous counter modules. Original source tiles own their joints.
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const ROOT="res://assets/maps/falan/east_region/counter_segments/"
const IDS=[17196,17197,17198,17199,17200,17201,17202,17203,17204]
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func footprint(serial:int)->PackedVector2Array:
 # The two source corners cut different vertices.17197's -8native-u margin
 # cuts the rear-left joint;17202's +8native-v base cuts the forward corner.
 if serial==17197:return PackedVector2Array([Vector2(.75,-1.5),Vector2(1.5,-1.5),Vector2(1.5,1.5),Vector2(-1.5,1.5),Vector2(-1.5,.75)])
 if serial==17202:return PackedVector2Array([Vector2(-1.5,-1.5),Vector2(1.5,-1.5),Vector2(1.5,1.5),Vector2(.5,1.5),Vector2(-1.5,-.5)])
 return PackedVector2Array([Vector2(-1.5,-1.5),Vector2(1.5,-1.5),Vector2(1.5,1.5),Vector2(-1.5,1.5)])
static func prism(tool:SurfaceTool,outline:PackedVector2Array,bottom:float,top:float):
 var triangles=Geometry2D.triangulate_polygon(outline)
 assert(not triangles.is_empty(),"Counter footprint must remain a simple source joint")
 for level in[bottom,top]:
  for start in range(0,triangles.size(),3):
   var order=[triangles[start],triangles[start+1],triangles[start+2]]
   if level==bottom:order.reverse()
   for index:int in order:tool.set_normal(Vector3.UP if level==top else Vector3.DOWN);tool.set_uv(outline[index]/1.5);tool.add_vertex(Vector3(outline[index].x,level,outline[index].y))
 for index in outline.size():
  var a:Vector2=outline[index];var b:Vector2=outline[(index+1)%outline.size()]
  Furniture.Shapes.quad(tool,Vector3(a.x,bottom,a.y),Vector3(b.x,bottom,b.y),Vector3(b.x,top,b.y),Vector3(a.x,top,a.y))
static func mesh(serial:int,graphic:Dictionary)->Mesh:
 assert(serial in IDS and graphic.rgba_sha256==data().graphics[str(serial)].source_rgba_sha256,"Pinned native counter module")
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)];var height=43.*.045
 var body=Furniture.tool();var base=Furniture.tool()
 #64native pixels span one3m cell. Top native-v=-43, floor-v=0.
 prism(body,footprint(serial),.14,height)
 prism(base,footprint(serial),0.,.14)
 var retained=[Source.committed_arrays(body.commit_to_arrays()),Source.committed_arrays(base.commit_to_arrays())]
 var model=Furniture.finish([body,base],[Fort.material(Color("154251"),false),Fort.material(Color("a5a18b"),false)])
 model.set_meta("east_cpu_arrays",retained)
 var skin=Furniture.tool()
 for slot in model.get_surface_count():
  var arrays:Array=retained[slot]
  var ids:Variant=arrays[Mesh.ARRAY_INDEX];var indexed=ids is PackedInt32Array and not ids.is_empty()
  for i in (ids.size()if indexed else arrays[Mesh.ARRAY_VERTEX].size()):
   var index:int=ids[i]if indexed else i;var p:Vector3=arrays[Mesh.ARRAY_VERTEX][index];var n:Vector3=arrays[Mesh.ARRAY_NORMAL][index]
   if n.y<.45 and n.dot(Vector3(-1,0,1))<.15:continue
   var pixel=Vector2((p.x+p.z)*32./3.,(p.z-p.x)*8.-p.y/.045)-Vector2(g.origin[0],g.origin[1])
   skin.set_normal(n);skin.set_uv(pixel/Vector2(g.size[0],g.size[1]));skin.add_vertex(p+n*.003)
 var front_arrays=Source.committed_arrays(skin.commit_to_arrays());var front=skin.commit();front.set_meta("east_cpu_arrays",[front_arrays])
 var texture:Texture2D=load(ROOT+str(serial)+".png");assert(texture!=null,"Import prepared counter references before construction")
 var paint=ShaderMaterial.new();paint.shader=preload("res://scripts/forest/forest_east_counter_front.gdshader");paint.set_shader_parameter("native_paint",texture);front.surface_set_material(0,paint)
 var result=East.combine([model,front]);result.set_meta("east_native_counter_segment",serial);result.set_meta("source_rgba_sha256",g.source_rgba_sha256);result.set_meta("inferred_hidden_body",true)
 meshes[serial]=result;return result
