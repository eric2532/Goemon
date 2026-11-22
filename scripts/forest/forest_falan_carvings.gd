extends RefCounted
## Shallow original-painted relief, prepared once and shared by every placement.
const Data=preload("res://assets/maps/falan/city_carvings.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Parts=preload("res://scripts/forest/forest_falan_lamps.gd")
const Shapes=preload("res://scripts/forest/forest_falan_building_shapes.gd")
static var meshes:Dictionary={}
static var paint:ShaderMaterial
static var lantern:Mesh
static var lantern_inset:Mesh
static var glazing:Material
static var valance:Mesh

static func add(root:Node3D,feature:String,p:Vector3,size_:Vector2,yaw:float=0.0):
 if paint==null:
  paint=Source.material(Data.STONE).duplicate();paint.set_shader_parameter("original_palette",false)
  glazing=Source.material(Data.ATLAS).duplicate();glazing.set_shader_parameter("original_palette",false)
 if not meshes.has(feature):meshes[feature]=relief(feature)
 var node=Geo.mesh(root,meshes[feature],p,glazing if float(Data.FEATURES[feature][1])==0.0 else paint)
 node.scale=Vector3(size_.x,size_.y,1);node.rotation.y=yaw
 node.set_meta("falan_carving",feature)
 return node

static func relief(feature:String,data:Script=Data)->Mesh:
 var row:Array=data.FEATURES[feature];var rect:Rect2i=row[0];var rise:float=row[1]
 var depth=data.DEPTH.get_image()
 var step:int=row[2] if row.size()>2 else 2
 assert(step in [1,2],"Relief sampling must use one or two native pixels")
 var columns=clampi(rect.size.x/step,12,128 if step==1 else 64) if rise>0 else 1
 var rows=clampi(rect.size.y/step,8,128 if step==1 else 48) if rise>0 else 1
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points=[];var uvs=[]
 for y in rows+1:
  for x in columns+1:
   var uv=Vector2(float(x)/columns,float(y)/rows)
   var pixel=Vector2(rect.position)+uv*Vector2(rect.size-Vector2i.ONE)
   var amount=depth.get_pixelv(Vector2i(pixel.round())).r
   points.append(Vector3(uv.x-.5,.5-uv.y,rise*amount))
   uvs.append((pixel+Vector2.ONE*.5)/data.ATLAS.get_size())
 for y in rows:
  for x in columns:
   var a=y*(columns+1)+x
   for triangle in [[a,a+1,a+columns+1],[a+1,a+columns+2,a+columns+1]]:
    for i in triangle:tool.set_uv(uvs[i]);tool.add_vertex(points[i])
 tool.generate_normals()
 return tool.commit()

static func mansion_lantern(root:Node3D,p:Vector3,copper:Material,dark:Material):
 if lantern==null:
  Parts.prepare_primitives()
  var frame=SurfaceTool.new();frame.begin(Mesh.PRIMITIVE_TRIANGLES)
  var inset=SurfaceTool.new();inset.begin(Mesh.PRIMITIVE_TRIANGLES)
  for row in [[.0,.13,.88],[.15,.10,.72],[.65,.12,.77]]:
   Parts.rod(frame,Vector3.UP*row[0],Vector3.UP*(row[0]+row[1]),row[2])
  Parts.rod(inset,Vector3.UP*.20,Vector3.UP*.67,.55)
  for i in 8:
   var angle=i*TAU/8;var axis=Vector3(cos(angle),0,sin(angle))
   Parts.rod(frame,axis*.64+Vector3.UP*.24,axis*.64+Vector3.UP*.65,.045)
   var last=axis*.77+Vector3.UP*.77
   for j in range(1,9):
    var t=float(j)/8*PI*.5
    var next=axis*.77*cos(t)+Vector3.UP*(.77+sin(t)*.25)
    Parts.rod(frame,last,next,.032);last=next
  for i in 8:
   var a=i*PI/16;var b=(i+1)*PI/16
   var cap=CylinderMesh.new();cap.radial_segments=24;cap.rings=0
   cap.bottom_radius=.77*cos(a);cap.top_radius=.77*cos(b);cap.height=.25*(sin(b)-sin(a))
   frame.append_from(cap,0,Transform3D(Basis.IDENTITY,Vector3.UP*(.77+.125*(sin(a)+sin(b)))))
  Parts.rod(frame,Vector3.UP*1.0,Vector3.UP*1.12,.055)
  lantern=frame.commit();lantern_inset=inset.commit()
 for row in [[lantern,copper],[lantern_inset,dark]]:
  var node=Geo.mesh(root,row[0],p,row[1]);node.set_meta("falan_mansion_lantern",true)

static func mansion_valance(root:Node3D,p:Vector3,width:float,height:float,yaw:float,cloth:Material):
 if valance==null:
  var outline=PackedVector2Array([Vector2(-.5,.5),Vector2(.5,.5),Vector2(.5,-.13)])
  for i in range(1,17):
   var x=.5-float(i)/16
   outline.append(Vector2(x,-.13-.32*sin(float(i)/16*PI)))
  valance=Shapes.extrude(outline,.10)
 var node=Geo.mesh(root,valance,p,cloth);node.scale=Vector3(width,height,1);node.rotation.y=yaw
 node.set_meta("falan_mansion_valance",true)
