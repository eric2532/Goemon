extends RefCounted
## Archive facade contacts; enclosed upper and reverse architecture is inferred.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Steps=preload("res://scripts/forest/forest_elsa_hall_steps.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const ROOT="res://assets/maps/falan/elsa/scenery/temple/"
static var record:Dictionary={}
static var cached:Mesh

static func data()->Dictionary:
 if record.is_empty():record=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return record

static func ground(p:Vector2)->Vector3:
 return Vector3(p.x*3./64.-p.y/16.,0,p.x*3./64.+p.y/16.)

static func native(p:Vector3)->Vector2:
 return Vector2((p.x+p.z)*32./3.,(p.z-p.x)*8.)

static func facade_contacts(part:Dictionary)->Array[Vector2]:
 var contacts:Array[Vector2]=[]
 for i in part.front.size()-1:
  var a=Vector2(part.front[i][0],part.front[i][1]);var b=Vector2(part.front[i+1][0],part.front[i+1][1])
  var count=ceili(absf(b.x-a.x)/float(part.bays.across_pixels)) if part.has("bays") else 1
  for j in count:contacts.append(a.lerp(b,float(j)/count))
 contacts.append(Vector2(part.front[-1][0],part.front[-1][1]));return contacts

static func round_bays(point:Vector3,part:Dictionary)->Vector3:
 if not part.has("bays"):return point
 var source=native(point)-Vector2(0,point.y*Fit.VERTICAL);var depth=0.
 for span in part.bays.spans:
  var t=(source.x-(float(span[0])+float(span[1]))*.5)/(float(span[1])-float(span[0]))*2.
  if absf(t)<1.:depth=maxf(depth,sqrt(1.-t*t)*float(part.bays.depth))
 depth*=1.-smoothstep(float(part.bays.full_before),float(part.bays.fade_until),source.y)
 # This view direction projects to zero native pixels, keeping facade paint fixed.
 return point+Vector3(-Fit.VERTICAL/16.,1,Fit.VERTICAL/16.).normalized()*depth

static func curved_front(front,part:Dictionary,a:Vector3,b:Vector3,top_a:Vector3,top_b:Vector3,lift:float,center:Vector3):
 var levels=int(part.bays.vertical_segments)
 for level in levels:
  var q=[]
  for uv in [Vector2(0,float(level)/levels),Vector2(0,float(level+1)/levels),Vector2(1,float(level+1)/levels),Vector2(1,float(level)/levels)]:
   var p=a.lerp(top_a,uv.y).lerp(b.lerp(top_b,uv.y),uv.x)
   q.append(round_bays(p-Vector3.UP*lift,part)+Vector3.UP*lift)
  q=outward(q,center)
  var normal:Vector3=(q[2]-q[0]).cross(q[1]-q[0]).normalized()
  for k in [0,1,2,0,2,3]:front.projected_vertex(q[k],normal,q[k]-Vector3.UP*lift)

static func bounds()->Rect2:
 var r:Array=data().rect
 return Rect2(r[0],r[1],r[2]-r[0],r[3]-r[1])

static func build(root:Node3D,origin:Vector2):
 if cached==null:cached=mesh()
 var body=MeshInstance3D.new();body.name="ElsaOriginalTempleVolumes";body.mesh=cached;body.position=Vector3(origin.x,0,origin.y)
 body.set_meta("source_map",59520);body.set_meta("inferred_hidden_and_upper",true);root.add_child(body)
 Steps.build(root,origin,59520)
 build_rails(root,origin)

static func mesh()->Mesh:
 var r=bounds();var texture:Texture2D=load(Steps.TEMPLE+"front-paint.png")
 var front=Source.new([Rect2(Vector2.ZERO,r.size),-r.position,Vector2.ONE,0],texture,1./Fit.VERTICAL);front.reflection_threshold=2.
 var hidden={}
 for name in ["white","stone","blue","gold"]:
  var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);hidden[name]=tool
 for part in data().parts:
  var lift=float(Steps.data(59520).rises.get(part.name,0.))
  var contacts=facade_contacts(part);var front_count=contacts.size()
  var foot:PackedVector3Array=[]
  for p in contacts:foot.append(ground(p)+Vector3.UP*lift)
  for p in part.rear:foot.append(ground(Vector2(p[0],p[1]))+Vector3.UP*lift)
  var center=ground(Vector2(part.center[0],part.center[1]));var rear_center=Vector3.ZERO
  for p in part.rear:rear_center+=ground(Vector2(p[0],p[1]))
  center=(center+rear_center/part.rear.size())*.5
  var tops:PackedVector3Array=[];var source_tops:PackedVector3Array=[]
  for i in foot.size():
   var p:Vector3=foot[i];var h:float
   if part.kind=="pylon":h=(native(p).y-r.position.y)/Fit.VERTICAL if i<front_count else float(part.source_height)
   else:
    var t=clampf((native(p).x-part.front[0][0])/(part.front[-1][0]-part.front[0][0]),0.,1.)
    h=lerpf(part.front[0][1]-part.roof[0][1],part.front[-1][1]-part.roof[-1][1],t)/Fit.VERTICAL
   var top=p+Vector3.UP*maxf(h,1.)
   if part.kind=="pylon":
    var shift=(float(part.center[0])-native(p).x)*(1.-float(part.clip_scale))*3./64.
    top+=Vector3(shift,0,shift)
   source_tops.append(top)
   tops.append(round_bays(top-Vector3.UP*lift,part)+Vector3.UP*lift if i<front_count and part.has("bays") else top)
  for i in foot.size():
   var j=(i+1)%foot.size();var q=[foot[i],tops[i],tops[j],foot[j]]
   q=outward(q,center)
   if i<front_count-1:
    if part.has("bays"):curved_front(front,part,foot[i],foot[j],source_tops[i],source_tops[j],lift,center)
    else:
     var normal:Vector3=(q[2]-q[0]).cross(q[1]-q[0]).normalized()
     for k in [0,1,2,0,2,3]:front.projected_vertex(q[k],normal,q[k]-Vector3.UP*lift)
   elif part.kind=="pylon":
    var white_a:Vector3=foot[i].lerp(tops[i],2.16/(tops[i].y-lift));var white_b:Vector3=foot[j].lerp(tops[j],2.16/(tops[j].y-lift))
    panel(hidden.white,outward([white_a,tops[i],tops[j],white_b],center),4.25)
    var normal:Vector3=(q[2]-q[0]).cross(q[1]-q[0]).normalized();normal.y=0.;normal=normal.normalized()
    var lower=[foot[i]+normal*.5,foot[j]+normal*.5]
    var middle=[foot[i].lerp(tops[i],.7/(tops[i].y-lift))+normal*.6,foot[j].lerp(tops[j],.7/(tops[j].y-lift))+normal*.6]
    var upper=[foot[i].lerp(tops[i],2./(tops[i].y-lift)),foot[j].lerp(tops[j],2./(tops[j].y-lift))]
    for pair in [[lower,middle],[middle,upper]]:
     panel(hidden.blue,outward([pair[0][0],pair[1][0],pair[1][1],pair[0][1]],center),4.25)
    panel(hidden.gold,outward([upper[0],white_a,white_b,upper[1]],center),.8)
    if i==front_count-1:panel(hidden.blue,outward([foot[i],lower[0],middle[0],upper[0]],center),4.25)
    if j==0:panel(hidden.blue,outward([upper[1],middle[1],lower[1],foot[j]],center),4.25)
   else:panel(hidden.stone,q,4.25)
   if lift>0.:panel(hidden.blue,outward([foot[i]-Vector3.UP*lift,foot[i],foot[j],foot[j]-Vector3.UP*lift],center),4.25)
  if part.kind=="pylon":
   upper_enclosure(hidden,part,tops,center)
  else:
   # Closed barrel roof with a raised ridge; rear masonry stops at the blocked-band edge.
   var left:Vector3=tops[0];var right:Vector3=tops[1]
   var rear_left:Vector3=tops[-1];var rear_right:Vector3=tops[2]
   for span in range(foot.size()-1,2,-1):
    var t=clampf((native(foot[span]).x-part.front[0][0])/(part.front[-1][0]-part.front[0][0]),0.,1.)
    var u=clampf((native(foot[span-1]).x-part.front[0][0])/(part.front[-1][0]-part.front[0][0]),0.,1.)
    var starts=[left.lerp(right,t),left.lerp(right,u)];var ends=[tops[span],tops[span-1]]
    for slice_ in 12:
     var a=float(slice_)/12.;var b=float(slice_+1)/12.;var q=[]
     for uv in [Vector2(0,a),Vector2(1,a),Vector2(1,b),Vector2(0,b)]:
      q.append(starts[int(uv.x)].lerp(ends[int(uv.x)],uv.y)+Vector3.UP*sin(uv.y*PI)*float(part.crest))
     panel(hidden.blue,upward(q),4.25)
   # Roof end caps have thickness and close the arch above the side walls.
   for end in [0,1]:
    var a:Vector3=left if end==0 else right;var b:Vector3=rear_left if end==0 else rear_right
    for slice_ in 12:
     var t=float(slice_)/12.;var u=float(slice_+1)/12.
     var p=a.lerp(b,t);var q=a.lerp(b,u)
     panel(hidden.stone,outward([p,p+Vector3.UP*sin(t*PI)*float(part.crest),q+Vector3.UP*sin(u*PI)*float(part.crest),q],center),4.25)
 var result:ArrayMesh=front.finish()
 for name in hidden:
  var part:Mesh=hidden[name].commit();var index=result.get_surface_count()
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.surface_get_arrays(0))
  var material:ShaderMaterial=Source.material(load(ROOT+name+".png")).duplicate()
  material.set_shader_parameter("original_palette",false);material.set_shader_parameter("use_brush_finish",false)
  result.surface_set_material(index,material)
 return result

static func upper_enclosure(hidden:Dictionary,part:Dictionary,tops:PackedVector3Array,center:Vector3):
 var upper:PackedVector3Array=[];var cap:PackedVector3Array=[]
 var cornice=-INF
 for p in tops:cornice=maxf(cornice,p.y)
 cornice+=float(part.upper.extension)
 for p in tops:
  var v:Vector3=center+(p-center)*float(part.upper.wall_scale);v.y=cornice;upper.append(v)
 ring(hidden.white,tops,upper,center,4.25)
 ring(hidden.gold,upper,offset_ring(upper,.35),center,.35)
 var previous=offset_ring(upper,.35)
 for level in int(part.upper.roof_segments):
  var t=float(level+1)/int(part.upper.roof_segments)
  var radius=lerpf(float(part.upper.cap_scale),1.,cos(t*PI*.5))
  cap.clear()
  for p in upper:
   var v:Vector3=center+(p-center)*radius;v.y=cornice+.35+sin(t*PI*.5)*float(part.upper.roof_rise);cap.append(v)
  ring(hidden.blue,previous,cap,center,3.);previous=cap.duplicate()
 lid(hidden.blue,cap,3.)

static func offset_ring(points:PackedVector3Array,height:float)->PackedVector3Array:
 var result:PackedVector3Array=[]
 for p in points:result.append(p+Vector3.UP*height)
 return result

static func ring(tool:SurfaceTool,a:PackedVector3Array,b:PackedVector3Array,center:Vector3,pitch:float):
 for i in a.size():
  var j=(i+1)%a.size();panel(tool,outward([a[i],b[i],b[j],a[j]],center),pitch)

static func lid(tool:SurfaceTool,points:PackedVector3Array,pitch:float):
 var polygon=PackedVector2Array()
 for p in points:polygon.append(Vector2(p.x,p.z))
 var indices=Geometry2D.triangulate_polygon(polygon)
 for i in range(0,indices.size(),3):panel(tool,upward([points[indices[i]],points[indices[i+1]],points[indices[i+2]],points[indices[i+2]]]),pitch)

static func outward(points:Array,center:Vector3)->Array:
 var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]);var middle:Vector3=(points[0]+points[1]+points[2]+points[3])*.25
 if normal.dot(Vector3(middle.x-center.x,0,middle.z-center.z))<0.:points.reverse()
 return points

static func upward(points:Array)->Array:
 if (points[2]-points[0]).cross(points[1]-points[0]).y<0.:points.reverse()
 return points

static func panel(tool:SurfaceTool,points:Array,pitch:float):
 var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0])
 if normal.length_squared()<.0000001:normal=(points[3]-points[0]).cross(points[1]-points[0])
 if normal.length_squared()<.0000001:return
 normal=normal.normalized();var tangent:Vector3=(points[3]-points[0]).normalized()
 if tangent.is_zero_approx():tangent=(points[2]-points[1]).normalized()
 var vertical=normal.cross(tangent).normalized()
 for i in [0,1,2,0,2,3]:
  var p:Vector3=points[i];tool.set_normal(normal);tool.set_uv(Vector2(p.dot(tangent),p.dot(vertical))/pitch);tool.add_vertex(p)

static var rail_meshes:Dictionary={}

static func replaces(placement:Dictionary)->bool:
 return Steps.data(59520).rails.any(func(row):return row.group==placement.group)

static func build_rails(root:Node3D,origin:Vector2):
 var scenery=load("res://scripts/forest/forest_elsa_scenery.gd")
 if scenery.props.is_empty():scenery.props=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/elsa/props/data.json"))
 var props:Dictionary=scenery.props
 for row in Steps.data(59520).rails:
  var key:String=row.group;var at=ground(Vector2(row.anchor[0],row.anchor[1]))
  if not rail_meshes.has(key):
   var g:Dictionary;var paint:Texture2D;var solid:Texture2D;var foot:Vector2;var edges:Array
   var original:Dictionary=props.groups[key]
   g={"rect":[0,0,row.size[0],row.size[1]],"origin":original.origin,"cut":[original.master]};foot=Vector2(original.wall.foot[0],original.wall.foot[1]);edges=row.edges
   paint=load(Steps.TEMPLE+key+".png");solid=load(Steps.TEMPLE+key+"-solid.png")
   var source_mesh:Mesh=Fit.transformed(scenery.relief_shape(g,paint,solid,edges,foot),Fit.native_coastal_frame())
   var result=ArrayMesh.new()
   for slot in source_mesh.get_surface_count():
    var arrays:Array=source_mesh.surface_get_arrays(slot);var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    for i in points.size():
     var t=clampf((native(points[i]).x-float(g.origin[0]))/float(g.rect[2]),0.,1.)
     points[i].y+=lerpf(float(row.grade[0]),float(row.grade[1]),t)
    arrays[Mesh.ARRAY_VERTEX]=points;result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(slot,source_mesh.surface_get_material(slot))
   rail_meshes[key]=result
  var node=MeshInstance3D.new();node.name="ElsaTempleRail_"+key;node.mesh=rail_meshes[key];node.position=Vector3(origin.x,0,origin.y)+at
  node.set_meta("source_group",key);node.set_meta("inferred_tread_height",true);root.add_child(node)
