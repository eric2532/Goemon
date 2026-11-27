extends RefCounted
## Native shore-cap parts; callers enroll exact source placements, never a global family.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Palace=preload("res://scripts/forest/forest_falan_palace_art.gd")
const ROOT="res://assets/maps/falan/east_region/bank_caps/"
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static var shapes:Dictionary={}

static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog

static func cap_outline(serial:int)->PackedVector2Array:
 var result=PackedVector2Array()
 for p:Array in data().graphics[str(serial)].cap_outline:result.append(Vector2(p[0],p[1]))
 return result

static func support_rects(serial:int)->Array:return data().graphics[str(serial)].support_rects

static func part_skin():
 var result=Source.new([],load(ROOT+"surfaces.png"),.045)
 result.tiles={"grass":Vector2.ZERO,"stone":Vector2(128,0)};result.pitches={"grass":3.,"stone":1.2}
 return result

static func native_quad(skin,points:Array,normal:Vector3):
 # Clip geometry before projection: clamping a far lower vertex to the final
 # transparent texture row would still stretch the observed bank strip.
 var polygon=points.duplicate();var size_:Vector2=skin.graphic[0].size
 for axis in 2:
  for bound in [.5,size_[axis]-.5]:
   var result=[]
   for index in polygon.size():
    var a:Vector3=polygon[index];var b:Vector3=polygon[(index+1)%polygon.size()]
    var pa=skin.graphic[1]+Vector2((a.x+a.z)*32./3.,(a.z-a.x)*8.-a.y/.045)
    var pb=skin.graphic[1]+Vector2((b.x+b.z)*32./3.,(b.z-b.x)*8.-b.y/.045)
    var lower=is_equal_approx(bound,.5);var inside_a=pa[axis]>=bound if lower else pa[axis]<=bound;var inside_b=pb[axis]>=bound if lower else pb[axis]<=bound
    if inside_a:result.append(a)
    if inside_a!=inside_b:result.append(a.lerp(b,(bound-pa[axis])/(pb[axis]-pa[axis])))
   polygon=result
   if polygon.size()<3:return
 for index in range(1,polygon.size()-1):
  for corner in [0,index,index+1]:skin.projected_vertex(polygon[corner]+normal*.004,normal,polygon[corner])

static func mesh(serial:int,drop:float=4.)->Mesh:
 assert(drop>=.1 and drop<20.,"Bank continuation must use its measured land-to-water range")
 var key=Vector2i(serial,roundi(drop*1000.))
 if meshes.has(key):return meshes[key]
 var g:Dictionary=data().graphics[str(serial)];var outline=cap_outline(serial);var base=part_skin()
 var front=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],load(ROOT+str(serial)+"-front.png"),.045)
 front.reflection_threshold=2.;var triangles=Geometry2D.triangulate_polygon(outline);assert(not triangles.is_empty())
 base.part="grass"
 for at in range(0,triangles.size(),3):
  var points=[]
  for corner in 3:
   var p:Vector2=outline[triangles[at+corner]];points.append(Vector3(p.x,0,p.y))
  if (points[2]-points[0]).cross(points[1]-points[0]).y<0:points.reverse()
  base.quad(points[0],points[1],points[2],points[2]);native_quad(front,[points[0],points[1],points[2],points[2]],Vector3.UP)
  base.part="stone";base.quad(points[2]-Vector3.UP*drop,points[1]-Vector3.UP*drop,points[0]-Vector3.UP*drop,points[0]-Vector3.UP*drop);base.part="grass"
 var center=Vector2.ZERO
 for p:Vector2 in outline:center+=p
 center/=outline.size()
 for index in outline.size():
  var next=(index+1)%outline.size();var a=Vector3(outline[index].x,0,outline[index].y);var b=Vector3(outline[next].x,0,outline[next].y)
  var normal=(b-a).cross(Vector3.UP).normalized();var outward=Vector3((outline[index].x+outline[next].x)*.5-center.x,0,(outline[index].y+outline[next].y)*.5-center.y)
  var points=[a,b,b-Vector3.UP*drop,a-Vector3.UP*drop]
  if normal.dot(outward)<0:points.reverse();normal=-normal
  base.part="stone";base.quad(points[0],points[1],points[2],points[3])
  if normal.dot(Vector3(-1,0,1))>.02:native_quad(front,points,normal)
 var result=base.finish(true);var arrays_=[result.get_meta("source_surface_arrays")]
 var material:ShaderMaterial=result.surface_get_material(0).duplicate();material.set_shader_parameter("original_palette",false);result.surface_set_material(0,material)
 var native=front.finish(true);var arrays:Array=native.get_meta("source_surface_arrays")
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);result.surface_set_material(1,native.surface_get_material(0));arrays_.append(arrays)
 result.set_meta("source_surface_arrays_all",arrays_);result.set_meta("native_bank_cap",serial);result.set_meta("source_footprint",Vector2i.ONE)
 result.set_meta("hidden_depth_inferred",drop);meshes[key]=result;return result

static func all_rects(row:Dictionary)->Array:
 var result=support_rects(int(row.serial)).duplicate()
 result.append_array(row.get("join_rects",[]));result.append_array(row.get("support_only_rects",[]));return result

static func rectangle_points(rect:Array,y:float)->PackedVector3Array:
 return PackedVector3Array([Vector3(rect[0],y,rect[1]),Vector3(rect[2],y,rect[1]),Vector3(rect[2],y,rect[3]),Vector3(rect[0],y,rect[3])])

static func append_pieces(terrain,placements:Array):
 # Setup only: exact source strips reuse Ramparts' existing12m height buckets.
 for row:Dictionary in placements:
  var frame:Transform2D=row.get("frame",Transform2D.IDENTITY);var anchor:Vector2=row.anchor
  assert(absf(frame.x.normalized().dot(frame.y.normalized()))<.0001,"Bank support frames must keep orthogonal source axes")
  for rect:Array in all_rects(row):
   var middle=(float(rect[1])+float(rect[3]))*.5
   var a=anchor+frame.basis_xform(Vector2(rect[0],middle));var b=anchor+frame.basis_xform(Vector2(rect[2],middle));var along=(b-a).normalized()
   var piece={"a":a,"b":b,"along":along,"side":Vector2(-along.y,along.x),"half":(float(rect[3])-float(rect[1]))*.5*frame.y.length(),"length":a.distance_to(b),"start":0.,"end":a.distance_to(b),"h0":float(row.height),"h1":float(row.height),"joined":true,"source_bank_cap":true,"source_cell":row.source_cell}
   terrain.pieces.append(piece);terrain.maximum_height=maxf(terrain.maximum_height,piece.h0)
   var pad=piece.side.abs()*piece.half+Vector2.ONE*.002;var low=a.min(b)-pad;var high=a.max(b)+pad
   for x in range(floori(low.x/12.),floori(high.x/12.)+1):
    for z in range(floori(low.y/12.),floori(high.y/12.)+1):
     var cell=Vector2i(x,z)
     if not terrain.height_buckets.has(cell):terrain.height_buckets[cell]=[]
     terrain.height_buckets[cell].append(piece)

static func support_shape(row:Dictionary)->Shape3D:
 var key=[int(row.serial),row.get("join_rects",[]),row.get("support_only_rects",[])];var token=var_to_str(key)
 if shapes.has(token):return shapes[token]
 var faces=PackedVector3Array()
 for rect:Array in all_rects(row):
  var p=rectangle_points(rect,0.)
  for index in [0,1,2,0,2,3]:faces.append(p[index])
 var shape=ConcavePolygonShape3D.new();shape.set_faces(faces);shapes[token]=shape;return shape

static func build(root:Node3D,placements:Array):
 var groups={};var seams=part_skin();seams.part="grass";var seam_count=0
 for row:Dictionary in placements:
  var frame:Transform2D=row.get("frame",Transform2D.IDENTITY);var anchor:Vector2=row.anchor
  var basis=Basis(Vector3(frame.x.x,0,frame.x.y),Vector3.UP,Vector3(frame.y.x,0,frame.y.y));var pose=Transform3D(basis,Vector3(anchor.x,row.height,anchor.y))
  var drop=float(row.height)-float(row.get("water_height",2.));var key=Vector2i(int(row.serial),roundi(drop*1000.))
  if not groups.has(key):groups[key]=[]
  groups[key].append(pose)
  var before=root.get_child_count();Palace.support(root,support_shape(row),Vector3.ZERO)
  var body:StaticBody3D=root.get_child(before);body.transform=pose;body.name="NativeBankCapSupport";body.set_meta("native_bank_cap",int(row.serial));body.set_meta("source_cell",row.source_cell)
  for rect:Array in row.get("join_rects",[]):
   var corners=rectangle_points(rect,0.);var p=[]
   for point:Vector3 in corners:p.append(pose*point)
   seams.quad(p[0],p[1],p[2],p[3]);seam_count+=1
 for key:Vector2i in groups:
  var part=MultiMeshInstance3D.new();part.name="NativeSourceBankCap_"+str(key.x);part.multimesh=MultiMesh.new();part.multimesh.transform_format=MultiMesh.TRANSFORM_3D
  part.multimesh.mesh=mesh(key.x,key.y/1000.);part.multimesh.instance_count=groups[key].size()
  for index in groups[key].size():part.multimesh.set_instance_transform(index,groups[key][index])
  part.set_meta("source_graphic",key.x);part.set_meta("native_source_bank_cap",true);root.add_child(part)
 if seam_count:
  var part=MeshInstance3D.new();part.name="NativeKnownLandBankSeams";part.mesh=seams.finish(true);root.add_child(part)
