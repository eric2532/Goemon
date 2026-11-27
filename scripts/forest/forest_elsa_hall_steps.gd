extends RefCounted
## Original curved treads share one local support grid with actors and native movement.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const FOLDER="res://assets/maps/falan/elsa/scenery/inner-hall/"
const TEMPLE="res://assets/maps/falan/elsa/scenery/temple-steps/"
const ENTRY="res://assets/maps/falan/elsa/scenery/temple-bg-stair/"
static var records:Dictionary={}
static var paints:Dictionary={}
static var visuals:Dictionary={}
static var supports:Dictionary={}
static var visual:Mesh
static var support:Mesh

static func owns(id:int)->bool:
 return id in [59520,59530,59535]

static func data(id:int=59535)->Dictionary:
 if not records.has(id):records[id]=JSON.parse_string(FileAccess.get_file_as_string((TEMPLE if id==59520 else ENTRY if id==59530 else FOLDER)+"data.json"))
 return records[id]

static func paint_texture(id:int,name:String="paint.png")->Texture2D:
 var key=[id,name]
 if not paints.has(key):paints[key]=load((TEMPLE if id==59520 else ENTRY if id==59530 else FOLDER)+name)
 return paints[key]

static func height(x:float,z:float,id:int=59535)->float:
 var steps:Dictionary=data(id).steps;var grid:Dictionary=steps.grid
 var at=(Vector2(x,z)-Vector2(steps.map_origin[0]+grid.origin[0],steps.map_origin[1]+grid.origin[1]))/float(grid.spacing)
 var cell=Vector2i(at.floor());var width=int(grid.size[0])
 if cell.x<0 or cell.y<0 or cell.x>=width-1 or cell.y>=int(grid.size[1])-1:return 0.
 var uv=at-Vector2(cell);var index=cell.y*width+cell.x;var h:Array=grid.heights
 var east=float(h[index+1]);var south=float(h[index+width])
 if uv.x+uv.y<=1.:return float(h[index])+(east-float(h[index]))*uv.x+(south-float(h[index]))*uv.y
 var far=float(h[index+width+1]);return far+(south-far)*(1.-uv.x)+(east-far)*(1.-uv.y)

static func add_navigation(nav:Dictionary,id:int=59535):
 var steps:Dictionary=data(id).steps;var grid:Dictionary=steps.grid;var spacing=float(grid.spacing)
 var width=roundi(int(steps.map_width)*3./spacing)+1
 var heights=PackedFloat32Array();heights.resize(width*width)
 var covered=PackedByteArray();covered.resize(heights.size());covered.fill(1)
 for z in int(grid.size[1]):
  for x in int(grid.size[0]):
   var ix=roundi((float(grid.origin[0])+x*spacing)/spacing);var iz=roundi((float(grid.origin[1])+z*spacing)/spacing)
   heights[iz*width+ix]=grid.heights[z*int(grid.size[0])+x]
 nav.merge({"width":width,"spacing":spacing,"origin":Vector3(steps.map_origin[0],0,steps.map_origin[1]),"heights":heights,"covered":covered},true)

static func build(root:Node3D,origin:Vector2,id:int=59535):
 var steps:Dictionary=data(id).steps
 if steps.get("external_visual",false):
  if not supports.has(id):supports[id]=support_mesh(steps,id)
  support=supports[id];add_support(root,origin,id)
  return
 if not visuals.has(id):
  var rect:Array=data(id).rect;var paint:Texture2D=paint_texture(id)
  var skin=Source.new([Rect2(Vector2.ZERO,paint.get_size()),-Vector2(rect[0],rect[1]),Vector2.ONE,0],paint,1./Fit.VERTICAL)
  skin.reflection_threshold=2.
  var bands={}
  if steps.has("riser_texture"):
   for name in ["riser","nosing"]:
    var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);bands[name]=tool
  for tier in steps.tiers:
   var polygon=PackedVector2Array()
   var complete:Array=tier.points+tier.back_points
   for point in complete:polygon.append(Vector2(point[0],point[2]))
   var triangles=Geometry2D.triangulate_polygon(polygon)
   for i in range(0,triangles.size(),3):
    var points=[]
    for j in 3:
     var point:Array=complete[triangles[i+j]];points.append(Vector3(point[0],point[1],point[2]))
    if (points[2]-points[0]).cross(points[1]-points[0]).y<0.:points.reverse()
    for point in points:skin.projected_vertex(point,Vector3.UP,point-Vector3.UP*float(tier.height) if steps.get("sample_ground",false) else point)
   var covered=0.
   for i in complete.size():
    var a:Array=complete[i];var b:Array=complete[(i+1)%complete.size()]
    var top_a=Vector3(a[0],a[1],a[2]);var top_b=Vector3(b[0],b[1],b[2])
    var rise=float(tier.height) if id==59520 else float(tier.get("riser",.5));var vertices=[top_a,top_b,top_b-Vector3.UP*rise,top_a-Vector3.UP*rise]
    var normal:Vector3=(vertices[2]-vertices[0]).cross(vertices[1]-vertices[0]).normalized()
    if not bands.is_empty():
     var length=Vector2(top_b.x-top_a.x,top_b.z-top_a.z).length()
     band(bands.riser,[top_a-Vector3.UP*.1,top_b-Vector3.UP*.1,vertices[2],vertices[3]],covered,length,(rise-.1)/(float(steps.get("riser_pixel_height",12.))/Fit.VERTICAL))
     band(bands.nosing,[top_a,top_b,top_b-Vector3.UP*.1,top_a-Vector3.UP*.1],covered,length)
     covered+=length
    else:
     for k in [0,1,2,0,2,3]:
      var point:Vector3=vertices[k]
      skin.projected_vertex(point,normal,point)
  var result:ArrayMesh=skin.finish(id==59530)
  for name in bands:
   var index=result.get_surface_count()
   if id==59530:result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,bands[name].commit_to_arrays())
   else:
    var part:Mesh=bands[name].commit();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.surface_get_arrays(0))
   result.surface_set_material(index,Source.material(paint_texture(id,str(steps[name+"_texture"]))))
  visuals[id]=result
  supports[id]=support_mesh(steps,id)
 visual=visuals.get(id);support=supports[id]
 if visual!=null:
  var node=Geo.mesh(root,visual,Vector3(origin.x,0,origin.y),null);node.name="ElsaTempleCurvedTreads" if id==59520 else "ElsaOriginalCurvedTreads"
  node.set_meta("source_map",id);node.set_meta("inferred_riser_height",.5)
 add_support(root,origin,id)

static func support_mesh(steps:Dictionary,id:int)->Mesh:
 var grid:Dictionary=steps.grid;var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for z in int(grid.size[1])-1:
  for x in int(grid.size[0])-1:
   var corners=[]
   for corner in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:
    var cell=Vector2i(x,z)+corner
    corners.append(Vector3(grid.origin[0]+cell.x*grid.spacing,grid.heights[cell.y*int(grid.size[0])+cell.x],grid.origin[1]+cell.y*grid.spacing))
   if not steps.get("support_all_grid",false) and maxf(maxf(corners[0].y,corners[1].y),maxf(corners[2].y,corners[3].y))<=0.:continue
   for i in [0,1,2,1,3,2]:tool.add_vertex(corners[i])
 if id==59530:
  var arrays=tool.commit_to_arrays();var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.set_meta("source_support_faces",arrays[Mesh.ARRAY_VERTEX]);return mesh
 else:return tool.commit()

static func add_support(root:Node3D,origin:Vector2,id:int):
 var body=StaticBody3D.new();body.name="ElsaTempleTreadSupport" if id==59520 else "ElsaCurvedTreadSupport";body.position=Vector3(origin.x,0,origin.y);body.collision_layer=1;body.collision_mask=0;root.add_child(body)
 var shape=CollisionShape3D.new();var mesh:Mesh=supports[id]
 if mesh.has_meta("source_support_faces"):
  var triangles=ConcavePolygonShape3D.new();triangles.set_faces(mesh.get_meta("source_support_faces"));shape.shape=triangles
 else:shape.shape=mesh.create_trimesh_shape()
 body.add_child(shape)

static func entry_ground(root:Node3D,origin:Vector2,size_:Vector2i):
 var grid:Dictionary=data(59530).steps.grid
 var hole=Rect2(origin+Vector2(grid.origin[0],grid.origin[1]),Vector2(grid.size[0]-1,grid.size[1]-1)*float(grid.spacing))
 var bounds=Rect2(origin-Vector2.ONE*1.5,Vector2(size_)*3.)
 var areas=[Rect2(bounds.position,Vector2(hole.position.x-bounds.position.x,bounds.size.y)),
  Rect2(Vector2(hole.end.x,bounds.position.y),Vector2(bounds.end.x-hole.end.x,bounds.size.y)),
  Rect2(Vector2(hole.position.x,bounds.position.y),Vector2(hole.size.x,hole.position.y-bounds.position.y)),
  Rect2(Vector2(hole.position.x,hole.end.y),Vector2(hole.size.x,bounds.end.y-hole.end.y))]
 for i in areas.size():
  var area:Rect2=areas[i];assert(area.size.x>0. and area.size.y>0.)
  var center=area.get_center()
  var body=preload("res://scripts/forest/forest_art.gd").solid(root,Vector3(center.x,-1.,center.y),Vector3(area.size.x,2.,area.size.y),1,"stone")
  body.name="RecoveredShalenaPhysicalGround_%d"%i;body.set_meta("original_map_ground",true)

static func band(tool:SurfaceTool,points:Array,covered:float,length:float,vertical_span:float=1.):
 var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
 var uv=[Vector2(covered/2.12,0),Vector2((covered+length)/2.12,0),Vector2((covered+length)/2.12,vertical_span),Vector2(covered/2.12,vertical_span)]
 for i in [0,1,2,0,2,3]:tool.set_normal(normal);tool.set_uv(uv[i]);tool.add_vertex(points[i])
