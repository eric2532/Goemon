extends RefCounted
## Private source-mask volume; no live dispatcher.
const Base=preload("res://scripts/forest/forest_east_region_art.gd")
const ROOT="res://assets/maps/falan/east_region/cactus_volume_prototype/"
static var catalog={}
static var meshes={}
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func depth(pixel:Vector2,spec:Dictionary)->float:
 var grid:Array=spec.depth_grid;var x=clampf(pixel.x/2.,0.,grid[0].size()-1);var y=clampf(pixel.y/2.,0.,grid.size()-1);var x0=int(x);var y0=int(y);var x1=mini(x0+1,grid[0].size()-1);var y1=mini(y0+1,grid.size()-1)
 return lerpf(lerpf(grid[y0][x0],grid[y0][x1],x-x0),lerpf(grid[y1][x0],grid[y1][x1],x-x0),y-y0)
static func point(pixel:Vector2,g:Dictionary,spec:Dictionary,reverse:bool)->Vector3:
 var ray=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized()
 return Base.projected(pixel,g,0.,spec.ground_offset)+ray*depth(pixel,spec)*(-1. if reverse else 1.)
static func normal(pixel:Vector2,g:Dictionary,spec:Dictionary,reverse:bool)->Vector3:
 var horizontal=point(pixel+Vector2.RIGHT*.5,g,spec,reverse)-point(pixel-Vector2.RIGHT*.5,g,spec,reverse);var vertical=point(pixel+Vector2.DOWN*.5,g,spec,reverse)-point(pixel-Vector2.DOWN*.5,g,spec,reverse)
 var n=horizontal.cross(vertical).normalized();return n if reverse else -n
static func mesh(serial:int,g:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var spec:Dictionary=data().graphics[str(serial)];assert(g.rgba_sha256==spec.native_rgba_sha256)
 var row=g.duplicate(true);row.rect=[0,0,g.rect[2],g.rect[3]];var front=Base.native_skin(row,load(ROOT+str(serial)+"-front.png"));var back=Base.native_skin(row,load(ROOT+str(serial)+"-back.png"))
 for y in range(0,int(g.rect[3]),2):
  for x in range(0,int(g.rect[2]),2):
   var pixels=[Vector2(x,y),Vector2(mini(x+2,g.rect[2]),y),Vector2(mini(x+2,g.rect[2]),mini(y+2,g.rect[3])),Vector2(x,mini(y+2,g.rect[3]))]
   for reverse in[false,true]:
    var skin=back if reverse else front
    for index in([3,2,1,3,1,0]if reverse else[0,1,2,0,2,3]):skin.projected_vertex(point(pixels[index],g,spec,reverse),normal(pixels[index],g,spec,reverse),Base.projected(pixels[index],g,0.,spec.ground_offset))
 var sides=Base.native_skin(row,load(ROOT+str(serial)+"-back.png"))
 for edge in spec.edges:
  var a=Vector2(edge[0],edge[1]);var b=Vector2(edge[2],edge[3]);var sample=Base.projected(Vector2(edge[4],edge[5]),g,0.,spec.ground_offset);var points=[point(a,g,spec,false),point(b,g,spec,false),point(b,g,spec,true),point(a,g,spec,true)];var n=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
  for index in[0,1,2,0,2,3]:sides.projected_vertex(points[index],n,sample)
 var rear=back.finish();var material=rear.surface_get_material(0).duplicate();material.set_shader_parameter("original_palette",false);rear.surface_set_material(0,material)
 var result=Base.owner_frame(Base.combine([front.finish(),rear,sides.finish()]));meshes[serial]=result;return result
static func solid_mesh(serial:int,g:Dictionary,with_native_paint:bool=false)->Mesh:
 var spec:Dictionary=data().graphics[str(serial)];var grain:Texture2D=load(ROOT+str(serial)+"-grain.png");var shape=Base.PreparedSkin.new([],grain,1./Base.Fit.VERTICAL);shape.tiles={"stone":Vector2.ZERO};shape.part="stone"
 var capsule=preload("res://scripts/forest/forest_east_round_cactus.gd")
 for part:Dictionary in spec.solid_parts:
  var a=Base.projected(Vector2(part.start[0],part.start[1]),g,0.,spec.ground_offset);var b=Base.projected(Vector2(part.end[0],part.end[1]),g,0.,spec.ground_offset);var delta=b-a;var length=delta.length();var radius=float(part.radius_pixels)/(Base.Fit.HORIZONTAL*sqrt(2.));var profile:Array[Vector2]=[]
  for section in[Vector2(0.,.02),Vector2(.04,.70),Vector2(.10,.98),Vector2(.75,1.),Vector2(.90,.85),Vector2(.97,.5),Vector2(1.,.02)]:profile.append(Vector2(radius*section.y,length*section.x))
  var reference=Base.PreparedSkin.new([],grain,1./Base.Fit.VERTICAL);reference.tiles={"stone":Vector2.ZERO};reference.part="stone";capsule.ribbed_round(reference,profile);var mesh=reference.finish();var basis=Basis(Quaternion(Vector3.UP,delta/length));var arrays:Array=mesh.get_meta("east_cpu_arrays")[0]
  for index in arrays[Mesh.ARRAY_VERTEX].size():
   shape.surface.set_normal(basis*arrays[Mesh.ARRAY_NORMAL][index]);shape.surface.set_uv(arrays[Mesh.ARRAY_TEX_UV][index]);shape.surface.set_uv2(Vector2.ZERO);shape.surface.add_vertex(a+basis*arrays[Mesh.ARRAY_VERTEX][index])
 var row:Dictionary=g.duplicate(true);row.rect=[0,0,g.rect[2],g.rect[3]]
 var body:Mesh=shape.finish();var paint=Base.native_skin(row,load(ROOT+str(serial)+"-front.png"));var eye=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized()
 if not with_native_paint:return Base.owner_frame(body)
 for arrays:Array in body.get_meta("east_cpu_arrays"):
  for start in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
   if arrays[Mesh.ARRAY_NORMAL][start].dot(eye)<=0.:continue
   for corner in 3:
    var at=start+corner;paint.projected_vertex(arrays[Mesh.ARRAY_VERTEX][at]+arrays[Mesh.ARRAY_NORMAL][at]*.012,arrays[Mesh.ARRAY_NORMAL][at],arrays[Mesh.ARRAY_VERTEX][at])
 return Base.owner_frame(Base.combine([body,paint.finish()]))
