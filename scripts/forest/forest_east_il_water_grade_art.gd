extends RefCounted
## Private inferred ground grades: original terrain material above the hidden cut.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Caps=preload("res://scripts/forest/forest_east_bank_caps.gd")

static func add_top(tool:SurfaceTool,points:Array):
 var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
 if normal.y<0:points.reverse();normal=-normal
 for index in [0,1,2,0,2,3]:tool.set_normal(normal);tool.add_vertex(points[index])

static func build(root:Node3D,proposal:Dictionary,ground:Material):
 var top=SurfaceTool.new();top.begin(Mesh.PRIMITIVE_TRIANGLES);var earth=Caps.part_skin();earth.part="stone"
 for row:Dictionary in proposal.ramps:
  var a=Vector2(row.a[0],row.a[1]);var b=Vector2(row.b[0],row.b[1]);var end=Vector2(row.landing_end[0],row.landing_end[1]);var along=(b-a).normalized();var side=Vector2(-along.y,along.x)*float(row.half)
  for section in [[a,b,float(row.h0),float(row.h1)],[b,end,float(row.h1),float(row.h1)]]:
   var p:Vector2=section[0];var q:Vector2=section[1];var h0:float=section[2];var h1:float=section[3]
   var points=[Vector3(p.x-side.x,h0,p.y-side.y),Vector3(q.x-side.x,h1,q.y-side.y),Vector3(q.x+side.x,h1,q.y+side.y),Vector3(p.x+side.x,h0,p.y+side.y)]
   add_top(top,points.duplicate())
   var center=(points[0]+points[1]+points[2]+points[3])*.25
   for index in 4:
    var next=(index+1)%4;var x:Vector3=points[index];var y:Vector3=points[next];var low_x=Vector3(x.x,0,x.z);var low_y=Vector3(y.x,0,y.z)
    var face=[x,y,low_y,low_x];var normal=(face[2]-face[0]).cross(face[1]-face[0]);var middle=(x+y)*.5-center;middle.y=0
    if normal.dot(middle)<0:face.reverse()
    earth.quad(face[0],face[1],face[2],face[3])
   earth.quad(Vector3(points[3].x,0,points[3].z),Vector3(points[2].x,0,points[2].z),Vector3(points[1].x,0,points[1].z),Vector3(points[0].x,0,points[0].z))
 var arrays=top.commit_to_arrays();var surface=top.commit();surface.set_meta("source_surface_arrays",Source.committed_arrays(arrays))
 var node=MeshInstance3D.new();node.name="Source252InferredGrassGrades";node.mesh=surface;node.material_override=ground;root.add_child(node)
 var body=MeshInstance3D.new();body.name="Source252HiddenGradeFoundations";body.mesh=earth.finish(true)
 var material:ShaderMaterial=body.mesh.surface_get_material(0).duplicate();material.set_shader_parameter("original_palette",false);body.material_override=material;root.add_child(body)
 root.set_meta("source252_grade_inferred",true)
