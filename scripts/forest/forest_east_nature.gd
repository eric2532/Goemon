extends RefCounted
## Source-identified East plants reuse the existing timber, round parts and tree masters.
const Base=preload("res://scripts/forest/forest_east_region_art.gd")
const Trees=preload("res://scripts/forest/forest_east_tree_families.gd")
const Cactus=preload("res://scripts/forest/forest_east_round_cactus.gd")
const Lamps=preload("res://scripts/forest/forest_falan_lamps.gd")
const ROOT="res://assets/maps/falan/east_region/nature/"
static var catalog:Dictionary={}
static var meshes:Dictionary={}
static var sphere_arrays:Array=[]
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func owns(serial:int)->bool:return serial!=11699 and data().graphics.has(str(serial))
static func front(serial:int)->Texture2D:return load(ROOT+str(serial)+"-front.png")
static func mesh(serial:int,g:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var spec:Dictionary=data().graphics[str(serial)];var result:Mesh
 assert(spec.native_rgba_sha256==g.rgba_sha256 and spec.graphic.origin==g.origin and spec.graphic.footprint==g.footprint,"Regenerate East nature after its native source binding changes")
 if serial in [11746,11782,11785,11786]:
  result=Cactus.mesh(serial,g);result.set_meta("east_source_graphic",serial);result.set_meta("east_nature_kind",spec.kind);result.set_meta("east_inferred_reverse",true);meshes[serial]=result;return result
 match spec.kind:
  "seasonal_tree","native_branch_tree":result=Trees.mesh(g,spec)
  "source_skeleton":result=Trees.native_branches(g,spec)
  "source_canopy_tree":result=Base.combine([Trees.native_branches(g,spec),Base.foliage(g,load(ROOT+str(serial)+"-foliage.png"),[0,0,g.rect[2],g.rect[3]],float(spec.ground_offset))])
  "native_loose_bones":result=loose_bones(g,serial)
  "source_stump":result=Base.source_rock(g,spec,front(serial))
  "source_flowerbed":result=flowerbed(g,spec)
  "source_leaf_dome":result=leaf_dome(g,spec)
  "rounded_native_contour":result=rounded(g,spec)
  "potted_shrub":result=potted(g,spec)
  "source_logs":result=logs(g,spec)
  "basin_tree":result=basin_tree(g,spec)
  "native_crop":result=Base.combine([Base.foliage(g,load(ROOT+str(serial)+"-crop.png"),[0,0,g.rect[2],g.rect[3]],float(spec.ground_offset)),floor_card(g,load(ROOT+str(serial)+"-soil.png"),.04)])
  "native_flora":result=Base.foliage(g,front(serial),[0,0,g.rect[2],g.rect[3]],float(spec.ground_offset))
 if spec.get("height_frame","")!="original-owner":result=Base.owner_frame(result)
 result.set_meta("east_source_graphic",serial);result.set_meta("east_nature_kind",spec.kind);result.set_meta("east_inferred_reverse",true)
 meshes[serial]=result
 return result
static func native(g:Dictionary,paint:Texture2D):
 var row:Dictionary=g.duplicate(true);row.rect=[0,0,g.rect[2],g.rect[3]]
 return Base.native_skin(row,paint)
static func depth_at(pixel:Vector2,spec:Dictionary)->float:
 var grid:Array=spec.depth_grid;var x=clampf(pixel.x/4.,0.,grid[0].size()-1.);var y=clampf(pixel.y/4.,0.,grid.size()-1.)
 var x0=int(x);var y0=int(y);var x1=mini(x0+1,grid[0].size()-1);var y1=mini(y0+1,grid.size()-1)
 return lerpf(lerpf(float(grid[y0][x0]),float(grid[y0][x1]),x-x0),lerpf(float(grid[y1][x0]),float(grid[y1][x1]),x-x0),y-y0)
static func contour_point(pixel:Vector2,g:Dictionary,spec:Dictionary,reverse:bool)->Vector3:
 var ray=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized();var depth=depth_at(pixel,spec)
 return Base.projected(pixel,g,0.,float(spec.ground_offset))+ray*(-float(spec.depth)-depth if reverse else depth)
static func rounded(g:Dictionary,spec:Dictionary)->Mesh:
 var observed=native(g,front(int(spec.graphic_id)));var rear=native(g,load(ROOT+str(int(spec.graphic_id))+"-back.png"))
 var w=int(g.rect[2]);var h=int(g.rect[3])
 for y in range(0,h,4):
  for x in range(0,w,4):
   var pixels=[Vector2(x,y),Vector2(mini(x+4,w),y),Vector2(mini(x+4,w),mini(y+4,h)),Vector2(x,mini(y+4,h))]
   for reverse in [false,true]:
    var points=[]
    for pixel in pixels:points.append(contour_point(pixel,g,spec,reverse))
    var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized();var skin=rear if reverse else observed
    for index in ([3,2,1,3,1,0] if reverse else [0,1,2,0,2,3]):skin.projected_vertex(points[index],-normal if reverse else normal,Base.projected(pixels[index],g,0.,float(spec.ground_offset)))
 for edge in spec.edges:
  var a=Vector2(edge[0],edge[1]);var b=Vector2(edge[2],edge[3]);var sample=Base.projected(Vector2(edge[4],edge[5]),g,0.,float(spec.ground_offset))
  var points=[contour_point(a,g,spec,false),contour_point(b,g,spec,false),contour_point(b,g,spec,true),contour_point(a,g,spec,true)]
  var normal:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
  for index in [0,1,2,0,2,3]:rear.projected_vertex(points[index],normal,sample)
 var back:Mesh=rear.finish();var paint:ShaderMaterial=back.surface_get_material(0).duplicate();paint.set_shader_parameter("original_palette",false);back.surface_set_material(0,paint)
 return Base.combine([observed.finish(),back])
static func potted(g:Dictionary,spec:Dictionary)->Mesh:
 var base=Vector2(float(spec.pot_center),float(spec.pot_base));var height=float(spec.pot_base)-float(spec.pot_top)
 var bowl={"base":[base.x,base.y],"height_pixels":height,"diameter":spec.pot_width,"material":spec.get("pot_material","timber"),"profile":spec.get("pot_profile",[[0,.65],[.12,.75],[.85,1],[.94,1.09],[1,1.09]]),"hollow_top":true,"cap_inner":.82,"recess":0}
 var pot:Mesh=Base.round_body(g,bowl)
 var material:ShaderMaterial=pot.surface_get_material(1).duplicate();material.set_shader_parameter("use_base_texture",false);material.set_shader_parameter("original_palette",false);material.set_shader_parameter("base_color",Color(float(spec.pot_color[0])/255.,float(spec.pot_color[1])/255.,float(spec.pot_color[2])/255.).srgb_to_linear());pot.surface_set_material(1,material)
 var leaf:Mesh=Base.foliage(g,load(ROOT+str(int(spec.graphic_id))+"-leaves.png"),[0,0,g.rect[2],g.rect[3]],float(spec.ground_offset))
 var stems=Base.structure();var low=Base.point(base,0.,g)+Vector3.UP*height/Base.Fit.VERTICAL
 assert(is_equal_approx((low.z-low.x)*8.-low.y*Base.Fit.VERTICAL-float(g.origin[1]),float(spec.pot_top)),"Plant support must start at its measured source pot rim")
 for offset in [-.12,0.,.12]:
  var high=Base.projected(Vector2(float(spec.pot_center)+float(spec.pot_width)*offset,float(spec.pot_top)-8.),g,0.,float(spec.ground_offset))
  Base.rod(stems,low,high,.035,"bark")
 var supports:Mesh=stems.finish();var green:ShaderMaterial=supports.surface_get_material(0).duplicate();green.set_shader_parameter("use_base_texture",false);green.set_shader_parameter("original_palette",false);green.set_shader_parameter("base_color",Color(.18,.29,.09).srgb_to_linear());supports.surface_set_material(0,green)
 return Base.combine([pot,leaf,supports])
static func logs(g:Dictionary,spec:Dictionary)->Mesh:
 var solid=Base.structure();var paint=native(g,front(int(spec.graphic_id)));var eye=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized()
 for axis in spec.axes:
  var a=Base.projected(Base.v(axis[0]),g,0.,float(spec.ground_offset));var b=Base.projected(Base.v(axis[1]),g,0.,float(spec.ground_offset))
  Base.rod(solid,a,b,float(spec.radius_pixels)/(Base.Fit.HORIZONTAL*sqrt(2.)),"bark")
 var body:Mesh=solid.finish();var arrays:Array=body.get_meta("east_cpu_arrays")[0]
 for offset in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3):
  if arrays[Mesh.ARRAY_NORMAL][offset].dot(eye)<=0.:continue
  for i in range(offset,offset+3):paint.projected_vertex(arrays[Mesh.ARRAY_VERTEX][i]+arrays[Mesh.ARRAY_NORMAL][i]*.012,arrays[Mesh.ARRAY_NORMAL][i],arrays[Mesh.ARRAY_VERTEX][i])
 return Base.combine([body,paint.finish()])
static func basin_tree(g:Dictionary,spec:Dictionary)->Mesh:
 var limbs=Trees.native_branches(g,spec);var pieces=[limbs,Base.foliage(g,load(ROOT+str(int(spec.graphic_id))+"-foliage.png"),[0,0,g.rect[2],g.rect[3]],float(spec.ground_offset))]
 for basin in spec.basins:
  var tower={"base":[basin.center[0],basin.center[1]+float(basin.height_pixels)*.5],"level_pixels":float(spec.ground_offset)-float(g.origin[1])-float(basin.center[1])-float(basin.height_pixels)*.5,"height_pixels":basin.height_pixels,"diameter":basin.diameter,"material":"bark","profile":[[0,.65],[.25,.80],[.7,1],[1,1]],"hollow_top":true,"cap_inner":.85,"paint_top":true,"recess":0}
  pieces.append(Base.round_body(g,tower))
 return Base.combine(pieces)

static func loose_bones(g:Dictionary,serial:int)->Mesh:
 var skin=native(g,front(serial));var points=[]
 for pixel in [Vector2.ZERO,Vector2(g.rect[2],0),Vector2(g.rect[2],g.rect[3]),Vector2(0,g.rect[3])]:points.append(Base.point(pixel,.05,g))
 for index in [0,1,2,0,2,3]:skin.projected_vertex(points[index],Vector3.UP,points[index])
 for index in [3,2,1,3,1,0]:skin.projected_vertex(points[index]-Vector3.UP*.02,Vector3.DOWN,points[index])
 return skin.finish()

static func flowerbed(g:Dictionary,spec:Dictionary)->Mesh:
 var skin=native(g,front(int(spec.graphic_id)));skin.pixel_height=.045
 var rear=native(g,load(ROOT+str(int(spec.graphic_id))+"-back.png"));rear.pixel_height=.045
 var pixels=[Vector2.ZERO,Vector2(g.rect[2],0),Vector2(g.rect[2],g.rect[3]),Vector2(0,g.rect[3])];var points=[]
 for pixel in pixels:points.append(owner_point(pixel,float(spec.height),g))
 for index in [0,1,2,0,2,3]:skin.projected_vertex(points[index],Vector3.UP,points[index])
 for edge in spec.edges:
  var a=Vector2(edge[0],edge[1]);var b=Vector2(edge[2],edge[3]);var sample=owner_point(Vector2(edge[4],edge[5]),float(spec.height),g)
  var corners=[owner_point(a,float(spec.height),g),owner_point(b,float(spec.height),g),owner_point(b,0.,g),owner_point(a,0.,g)]
  var n:Vector3=(corners[2]-corners[0]).cross(corners[1]-corners[0]).normalized()
  for index in [0,1,2,0,2,3]:rear.projected_vertex(corners[index],n,sample)
 var reverse:Mesh=rear.finish();var material:ShaderMaterial=reverse.surface_get_material(0).duplicate();material.set_shader_parameter("original_palette",false);reverse.surface_set_material(0,material)
 return Base.combine([skin.finish(),reverse,floor_card(g,load(ROOT+str(int(spec.graphic_id))+"-back.png"),.01,true)])

static func owner_point(pixel:Vector2,height:float,g:Dictionary)->Vector3:
 var point=Base.point(pixel,height/Base.OWNER_Y_SCALE,g);point.y=height;return point

static func floor_card(g:Dictionary,paint:Texture2D,height:float,reverse:bool=false)->Mesh:
 var skin=native(g,paint);var points=[]
 for pixel in [Vector2.ZERO,Vector2(g.rect[2],0),Vector2(g.rect[2],g.rect[3]),Vector2(0,g.rect[3])]:points.append(owner_point(pixel,height,g))
 for index in ([3,2,1,3,1,0] if reverse else [0,1,2,0,2,3]):skin.projected_vertex(points[index],Vector3.DOWN if reverse else Vector3.UP,points[index])
 return skin.finish()

static func dome_point(pixel:Vector2,g:Dictionary,spec:Dictionary,reverse:bool=false)->Vector3:
 var bounds:Array=spec.visible;var u=clampf((pixel.x-bounds[0])/float(bounds[2]-bounds[0]),0.,1.);var v=clampf((pixel.y-bounds[1])/float(bounds[3]-bounds[1]),0.,1.)
 var height=float(spec.base_height)+sin(u*PI)*sin(v*PI)*float(spec.dome_height)
 return owner_point(pixel,height-(float(spec.depth) if reverse else 0.),g)
static func leaf_dome(g:Dictionary,spec:Dictionary)->Mesh:
 var front_skin=native(g,front(int(spec.graphic_id)));front_skin.pixel_height=.045
 var back_skin=native(g,load(ROOT+str(int(spec.graphic_id))+"-back.png"));back_skin.pixel_height=.045
 var w=int(g.rect[2]);var h=int(g.rect[3])
 for y in range(0,h,12):
  for x in range(0,w,12):
   var pixels=[Vector2(x,y),Vector2(mini(x+12,w),y),Vector2(mini(x+12,w),mini(y+12,h)),Vector2(x,mini(y+12,h))]
   for reverse in [false,true]:
    var points=[]
    for pixel in pixels:points.append(dome_point(pixel,g,spec,reverse))
    var n:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized();var skin=back_skin if reverse else front_skin
    for index in ([3,2,1,3,1,0] if reverse else [0,1,2,0,2,3]):skin.projected_vertex(points[index],-n if reverse else n,points[index])
 for edge in spec.edges:
  var a=Vector2(edge[0],edge[1]);var b=Vector2(edge[2],edge[3]);var sample=dome_point(Vector2(edge[4],edge[5]),g,spec)
  var points=[dome_point(a,g,spec),dome_point(b,g,spec),dome_point(b,g,spec,true),dome_point(a,g,spec,true)]
  var n:Vector3=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
  for index in [0,1,2,0,2,3]:back_skin.projected_vertex(points[index],n,sample)
 var reverse:Mesh=back_skin.finish();var material:ShaderMaterial=reverse.surface_get_material(0).duplicate();material.set_shader_parameter("original_palette",false);reverse.surface_set_material(0,material)
 return Base.combine([front_skin.finish(),reverse])
