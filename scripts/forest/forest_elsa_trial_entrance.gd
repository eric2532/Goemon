extends RefCounted
## Original matched BG/FG opening, with inferred hidden recess and floor thickness.
const ROOT="res://assets/maps/falan/elsa/scenery/trial-entrance/"
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
static var record:Dictionary={}
static var mesh:Mesh

static func data()->Dictionary:
 if record.is_empty():
  record=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
  assert(record.map_source_proofs.size()==56 and not record.candidate_only,"Entrance needs the reviewed complete source proof")
 return record

static func owns(id:int)->bool:return data().map_source_proofs.has(str(id))

static func fitted(point:Vector3,native_offset:Vector2)->Vector3:
 if point.y>=-.05:return point
 var spec=data();var r:Array=spec.front_rect;var pixel=Vector2((point.x+point.z)*32./3.,(point.z-point.x)*8.-point.y*Fit.VERTICAL)+native_offset
 var outside=maxf(maxf(float(r[0])-pixel.x,pixel.x-float(r[2])),maxf(float(r[1])-pixel.y,pixel.y-float(r[3])))
 var weight=1.-smoothstep(0.,float(spec.transition_pixels),maxf(0.,outside))
 var rise=((float(spec.foot_v)-pixel.y)/Fit.VERTICAL-point.y)*weight
 return point+Vector3(-Fit.VERTICAL/16.,1,Fit.VERTICAL/16.)*rise

static func front_point(pixel:Vector2)->Vector3:
 var foot=float(data().foot_v)
 return Vector3(pixel.x*3./64.-foot/16.,(foot-pixel.y)/Fit.VERTICAL,pixel.x*3./64.+foot/16.)

static func build(root:Node3D,id:int,origin:Vector2):
 if not owns(id):return
 if mesh==null:
  var spec=data();var r:Array=spec.native_rect;var paint:Texture2D=load(ROOT+"paint.png")
  var skin=Source.new([Rect2(Vector2.ZERO,paint.get_size()),-Vector2(r[0],r[1]),Vector2.ONE,0],paint,1./Fit.VERTICAL)
  var depth=Vector3(-Fit.VERTICAL/16.,1,Fit.VERTICAL/16.)*-float(spec.inferred_depth)
  var normal=Vector3(-1,0,1).normalized()
  for key in spec.backing_rows:
   var y=int(key);var span:Array=spec.backing_rows[key]
   var q=[front_point(Vector2(span[1],y))+depth,front_point(Vector2(span[1],y+1))+depth,front_point(Vector2(span[0],y+1))+depth,front_point(Vector2(span[0],y))+depth]
   for k in [0,1,2,0,2,3]:skin.projected_vertex(q[k],normal,q[k])
  var sides=SurfaceTool.new();sides.begin(Mesh.PRIMITIVE_TRIANGLES)
  var centre=front_point(Vector2(4480,1170))+depth*.5
  for edge in spec.edges:
   var a=Vector2(r[0]+edge[0],r[1]+edge[1]);var b=Vector2(r[0]+edge[2],r[1]+edge[3])
   if minf(a.y,b.y)>=float(spec.foot_v):continue
   var first=front_point(a);var second=front_point(b);var q=[first,second,second+depth,first+depth]
   var n:Vector3=(q[2]-q[0]).cross(q[1]-q[0]);var middle:Vector3=(q[0]+q[1]+q[2]+q[3])*.25
   if n.dot(centre-middle)<0.:q.reverse();n=-n
   if n.length_squared()<.000001:continue
   for k in [0,1,2,0,2,3]:sides.set_normal(n.normalized());sides.set_uv(Vector2(.5,.5));sides.add_vertex(q[k])
  var left=INF;var right=-INF
  for y in range(int(spec.lower_continuation_from),int(spec.foot_v)+1):
   var span:Array=spec.rows[str(y)];left=minf(left,float(span[0]));right=maxf(right,float(span[1]))
  var foot=float(spec.foot_v);var bottom=foot+Fit.VERTICAL*float(spec.inferred_floor_thickness);var lap=float(spec.backing_margin_pixels)
  var underside=[front_point(Vector2(left-lap,foot)),front_point(Vector2(right+lap,foot)),front_point(Vector2(right+lap,bottom)),front_point(Vector2(left-lap,bottom))]
  for k in [0,1,2,0,2,3]:sides.set_normal(normal);sides.set_uv(Vector2(.5,.5));sides.add_vertex(underside[k])
  var result:ArrayMesh=skin.finish();var inner:Mesh=sides.commit();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,inner.surface_get_arrays(0))
  result.surface_set_material(1,Source.material(load(ROOT+"inner-edge.png")));mesh=result
 var node=MeshInstance3D.new();node.name="ElsaOriginalArchRecess";node.mesh=mesh;node.position=Vector3(origin.x,0,origin.y)
 node.set_meta("inferred_recess_depth",data().inferred_depth);node.set_meta("inferred_floor_thickness",data().inferred_floor_thickness);root.add_child(node)
