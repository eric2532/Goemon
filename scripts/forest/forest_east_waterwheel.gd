extends RefCounted
## Private solid timber wheel, reusing the existing closed board/shaft pieces.
const East=preload("res://scripts/forest/forest_east_region_art.gd")
const Furniture=preload("res://scripts/forest/forest_falan_interior_furniture.gd")
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const ROOT="res://assets/maps/falan/east_region/waterwheel/"
static var catalog:Dictionary={}
static var prepared:Mesh
static func owns(serial:int)->bool:return serial==1238504
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func point(pixel:Vector2,height:float,g:Dictionary)->Vector3:
 var native=pixel+Vector2(g.origin[0],g.origin[1]);var v=native.y+height/.045
 return Vector3(native.x*3./64.-v/16.,height,native.x*3./64.+v/16.)
static func beam(tool:SurfaceTool,a:Vector3,b:Vector3,width:float):
 var block=BoxMesh.new();block.size=Vector3(width,a.distance_to(b),width)
 tool.append_from(block,0,Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized())),(a+b)*.5))
static func ring(tool:SurfaceTool,x:float,radius:float,sectors:int):
 var shapes=Furniture.Shapes
 for i in sectors:
  var a=i*TAU/sectors;var b=(i+1)*TAU/sectors
  var points=[]
  for axial in [-.12,.12]:
   for r in [radius-.30,radius]:
    for angle in [a,b]:points.append(Vector3(x+axial,cos(angle)*r,sin(angle)*r))
  for face in [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]:shapes.quad(tool,points[face[3]],points[face[2]],points[face[1]],points[face[0]])
static func timber(color:Color)->Material:
 var paint:ShaderMaterial=Source.material(load(ROOT+"timber.png")).duplicate()
 paint.set_shader_parameter("original_palette",true);paint.set_shader_parameter("alpha_cutout",false)
 paint.set_shader_parameter("base_color",color);paint.set_shader_parameter("archive_triplanar",true)
 paint.set_shader_parameter("uv_scale",Vector2.ONE/1.35)
 return paint
static func mesh(serial:int,graphic:Dictionary)->Mesh:
 assert(owns(serial)and graphic.rgba_sha256==data().source_rgba_sha256,"Regenerate pinned native waterwheel")
 if prepared!=null:return prepared
 var g=data();Furniture.Parts.prepare_primitives();var frame=Furniture.tool();var rim=Furniture.tool();var paddles=Furniture.tool();var axle=Furniture.tool()
 var r:float=g.radius;var half=float(g.wheel_depth)*.5;var sectors:int=g.sectors
 for side in [-1,1]:
  var x=side*half;ring(rim,x,r,sectors)
  for i in sectors:
   var t=i*TAU/sectors
   beam(frame,Vector3(x,0,0),Vector3(x,cos(t)*(r-.15),sin(t)*(r-.15)),.18)
  # Reuse the same measured frame design on its unseen support plane.
  var bearing=x+side*.40
  for z in [-2.25,2.25]:beam(frame,Vector3(bearing,-float(g.hub_height)+.10,z),Vector3(bearing,float(g.frame_rise),0),float(g.frame_width))
  beam(frame,Vector3(bearing,-.15,-1.8),Vector3(bearing,-.15,1.8),float(g.frame_width)*.7)
 for i in sectors:
  var angle=(i+.5)*TAU/sectors;var radial=Vector3(0,cos(angle),sin(angle));var tangent=Vector3(0,-sin(angle),cos(angle))
  var block=BoxMesh.new();block.size=Vector3(half*2.,.20,.90)
  paddles.append_from(block,0,Transform3D(Basis(Vector3.RIGHT,radial,tangent),radial*(r-.16)))
 Furniture.Parts.rod(axle,Vector3(-half-1.15,0,0),Vector3(half+1.15,0,0),.18)
 var core=Furniture.finish([frame,rim,paddles,axle],[timber(Color("d6c39f")),timber(Color("e5c58f")),timber(Color("c8ab7c")),timber(Color("c0a781"))])
 var center=point(Vector2(g.front_hub_pixel[0],g.front_hub_pixel[1]),g.hub_height,g)+Vector3.RIGHT*half
 core=East.transformed_existing(core,Transform3D(Basis.IDENTITY,center))
 var water_texture:Texture2D=load(ROOT+"water.png")
 assert(water_texture!=null,"Import the prepared native waterwheel textures before construction")
 var water=Source.new([Rect2(0,0,g.size[0],g.size[1]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],water_texture,.045)
 var pixels=[Vector2.ZERO,Vector2(g.size[0],0),Vector2(g.size[0],g.size[1]),Vector2(0,g.size[1])]
 for i in [0,1,2,0,2,3]:water.surface.set_normal(Vector3.UP);water.surface.set_uv(pixels[i]/Vector2(g.size[0],g.size[1]));water.surface.add_vertex(point(pixels[i],.025,g))
 var pose=Transform3D(Basis.IDENTITY,Vector3.UP*float(g.water_offset))
 prepared=East.transformed_existing(East.combine([core,water.finish()]),pose);prepared.set_meta("waterwheel_bounds",pose*core.get_aabb());prepared.set_meta("east_native_waterwheel",serial);prepared.set_meta("source_rgba_sha256",g.source_rgba_sha256);prepared.set_meta("inferred_hidden_construction",true);return prepared
