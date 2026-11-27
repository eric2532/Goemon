extends RefCounted
## Measured East final-fallback forms; placement/navigation stay with OriginalMaps.
const Source=preload("res://scripts/forest/forest_coastal_mesh.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Court=preload("res://scripts/forest/forest_falan_courtyard.gd")
const Boxes=preload("res://scripts/forest/forest_static_boxes.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const ROOT="res://assets/maps/falan/east_region/fallback_families/"
const IDS=[10474,10475,11150,11151,11188,11189,11190,11191,11192,11193,11194,11195,11196,11197,11198,11199,11200,11201,11202,11203,11204,11205,11206,11207,11208,1235161,1235162,1235163,1235164,1235165,1235166,1235167]
static var source_data:Dictionary={}
static var meshes:Dictionary={}

static func owns(serial:int)->bool:return serial in IDS

static func data()->Dictionary:
 if source_data.is_empty():source_data=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return source_data

static func owner_frame()->Transform3D:
 return Transform3D(Basis.IDENTITY.scaled(Vector3(1,.045*Fit.VERTICAL,1)),Vector3.ZERO)

static func native_target(g:Dictionary)->Rect2:
 var b:Array=g.get("structural_bounds",g.bounds)
 return Rect2(g.origin[0]+b[0],g.origin[1]+b[1],b[2]-b[0],b[3]-b[1])

static func fence(serial:int,g:Dictionary)->Mesh:
 var iron=Fort.material(Color(g.iron_rgb[0],g.iron_rgb[1],g.iron_rgb[2]),false)
 var boxes=Boxes.new()
 Court.ironwork(boxes,Vector3.ZERO,10675 if serial==10474 else 10674,iron)
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var cube=BoxMesh.new();cube.size=Vector3.ONE
 for group:Dictionary in boxes.groups.values():
  for pose:Transform3D in group.transforms:tool.append_from(cube,0,Transform3D(Basis.IDENTITY,group.origin)*pose)
 var raw=tool.commit();raw.surface_set_material(0,iron)
 var fit=Fit.measure(Fit.mesh_points(raw),"",Basis(Vector3.UP,PI*.5),native_target(g))
 var result=Fit.transformed(raw,owner_frame()*fit)
 result.set_meta("native_iron_bars",5);result.set_meta("native_iron_caps",5);result.set_meta("native_iron_rails",2)
 result.set_meta("native_fence_axis","z" if serial==10474 else "x")
 return result

static func plant(serial:int,g:Dictionary)->Mesh:
 if serial not in [11150,11151]:
  # The exact native Sokia11199 already owns source-shaped fronds and the original palm trunk.
  var raw:Mesh=load("res://scripts/forest/forest_ruby_region_art.gd").palm_shape(serial)
  var fitted=Fit.measure(Fit.mesh_points(raw),"",Basis(Vector3.UP,PI*.5),native_target(g))
  return Fit.transformed(raw,owner_frame()*fitted)
 var asset=Meadow.crossgate_tree(10085)
 var turn=Transform3D(Basis(Vector3.UP,-PI*.25),Vector3.ZERO)
 var points:Array[Vector3]=[]
 for part in Meadow.source(asset):points.append_array(Fit.mesh_points(part.mesh,turn*part.transform))
 # Identical whole-master fit to the existing Kili11150/51 owner, then the East .045 Y frame once.
 var pose=owner_frame()*Fit.measure(points,"",Basis(Vector3.UP,PI*.5),native_target(g))*turn
 var result=ArrayMesh.new()
 for part in Meadow.source(asset):
  for slot in part.mesh.get_surface_count():
   var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
   tool.append_from(part.mesh,slot,pose*part.transform)
   tool.commit(result)
   var material:Material=part.material if part.material!=null else part.mesh.surface_get_material(slot)
   if part.name=="Canopy":
    var leaf=ShaderMaterial.new();leaf.shader=Meadow.WIND
    leaf.set_shader_parameter("tree",true);leaf.set_shader_parameter("canopy",true)
    leaf.set_shader_parameter("strength",0.0);leaf.set_shader_parameter("source_cutout",true)
    leaf.set_shader_parameter("use_source_paint",true)
    leaf.set_shader_parameter("source_paint",part.mesh.surface_get_material(slot).albedo_texture)
    leaf.set_shader_parameter("foliage_tint",Vector3(g.leaf_rgb[0]/g.base_leaf_rgb[0],g.leaf_rgb[1]/g.base_leaf_rgb[1],g.leaf_rgb[2]/g.base_leaf_rgb[2]))
    material=leaf
   result.surface_set_material(result.get_surface_count()-1,material)
 return result

static func painted_quad(base,front,a:Vector3,b:Vector3,c:Vector3,d:Vector3,part:String="stone"):
 base.part=part;base.quad(a,b,c,d)
 var normal=(c-a).cross(b-a)
 if normal.length_squared()<.000001:return
 normal=normal.normalized()
 # Only the two observed source-facing planes receive original paint. Backs stay independently tiled.
 if normal.y<.75 and (normal.x<-.01 or normal.z>.01):
  for p:Vector3 in [a,b,c,a,c,d]:front.projected_vertex(p+normal*.003,normal,p)

static func ring(extent:Vector2,y:float,center:Vector3=Vector3.ZERO,bevel:float=0.0)->Array[Vector3]:
 var x=extent.x;var z=extent.y
 var result:Array[Vector3]=[]
 var corners=[Vector2(-x,-z),Vector2(-x,z),Vector2(x,z),Vector2(x,-z)] if bevel<=0 else [Vector2(-x,-z+bevel),Vector2(-x,z-bevel),Vector2(-x+bevel,z),Vector2(x-bevel,z),Vector2(x,z-bevel),Vector2(x,-z+bevel),Vector2(x-bevel,-z),Vector2(-x+bevel,-z)]
 for p:Vector2 in corners:result.append(center+Vector3(p.x,y,p.y))
 return result

static func profile(base,front,rows:Array,center:Vector3=Vector3.ZERO,bevel:float=0.0):
 var before:Array[Vector3]=[]
 for row:Vector3 in rows:
  var current=ring(Vector2(row.x,row.z),row.y,center,minf(bevel,minf(row.x,row.z)*.5))
  if not before.is_empty():
   for i in current.size():
    var next=(i+1)%current.size()
    painted_quad(base,front,before[i],current[i],current[next],before[next],"gold" if row.y>6.9 and before[0].y>6.7 else "stone")
  before=current
 # Close both ends, including the unseen underside. No transparent rear or billboard edge.
 var low:Vector3=rows[0];var high:Vector3=rows[-1]
 for ends in [[ring(Vector2(low.x,low.z),low.y,center,minf(bevel,minf(low.x,low.z)*.5)),false],[before,true]]:
  var points:Array=ends[0];var middle=Vector3.ZERO
  for p:Vector3 in points:middle+=p
  middle/=points.size();base.part="cap" if ends[1] else "stone"
  for i in points.size():
   var next=(i+1)%points.size()
   if ends[1]:base.quad(middle,points[next],points[i],points[i])
   else:base.quad(middle,points[i],points[next],points[next])

static func wall(serial:int,g:Dictionary)->Mesh:
 var texture:Texture2D=load(ROOT+str(serial)+".png")
 var base=Source.new([Rect2(),Vector2.ZERO,Vector2.ONE,0],load(ROOT+"surfaces.png"),.045)
 base.tiles={"stone":Vector2(0,0),"gold":Vector2(128,0),"cap":Vector2(256,0)}
 base.pitches={"stone":1.5,"gold":.8,"cap":1.5}
 var front=Source.new([Rect2(Vector2.ZERO,Vector2(g.size[0],g.size[1])),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture,.045)
 var high:float=g.height
 if g.form=="beam_post":
  profile(base,front,[Vector3(1.20,0,1.20),Vector3(1.46,.22,1.46),Vector3(1.25,.45,1.25),Vector3(.83,.64,.83),Vector3(.73,3.85,.73),Vector3(1.04,4.05,1.04),Vector3(1.04,4.45,1.04)],Vector3.ZERO,.16)
  var along_x=serial==1235166
  var section=Vector2(4.5,1.5) if along_x else Vector2(1.5,4.5)
  # The native128x96 cap is a9x3 beam. Its underside narrows into the single source post.
  profile(base,front,[Vector3(.94,4.45,.94),Vector3(section.x*.55,5.28,section.y*.55),Vector3(section.x,6.55,section.y),Vector3(section.x,high,section.y)])
 elif g.form=="fluted_post":
  profile(base,front,[Vector3(1.39,0,1.39),Vector3(1.52,.28,1.52),Vector3(1.36,.48,1.36),Vector3(1.36,high-.30,1.36),Vector3(1.5,high,1.5)],Vector3.ZERO,.19)
 else:
  profile(base,front,[Vector3(1.5,0,1.5),Vector3(1.5,.66,1.5),Vector3(1.43,.78,1.43),Vector3(1.43,high-.72,1.43),Vector3(1.5,high-.55,1.5),Vector3(1.5,high,1.5)])
  if serial==1235161:
   # Native35161 adds the left fluted edge post; it does not change the source walk footprint.
   profile(base,front,[Vector3(.25,0,.25),Vector3(.39,.18,.39),Vector3(.27,.45,.27),Vector3(.24,high-.8,.24),Vector3(.37,high-.65,.37)],Vector3(-1.65,0,-.75),.08)
 var result=base.finish();var observed=front.finish()
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,observed.surface_get_arrays(0))
 result.surface_set_material(1,observed.surface_get_material(0))
 return result

static func mesh(serial:int,graphic:Dictionary={})->Mesh:
 assert(owns(serial),"Unowned East fallback family")
 if meshes.has(serial):return meshes[serial]
 var g:Dictionary=data().graphics[str(serial)]
 if not graphic.is_empty():assert(graphic.rgba_sha256==g.source_rgba_sha256,"Regenerate East fallback native evidence")
 var result=fence(serial,g) if serial in [10474,10475] else plant(serial,g) if serial<12000 else wall(serial,g)
 result.set_meta("east_native_fallback",serial);result.set_meta("source_rgba_sha256",g.source_rgba_sha256)
 meshes[serial]=result
 return result
