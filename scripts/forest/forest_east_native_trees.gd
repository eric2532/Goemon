extends RefCounted
## East-only source fits reuse whole Meadow trees; all resources are prepared once per ID.
const Base=preload("res://scripts/forest/forest_east_region_art.gd")
const Traced=preload("res://scripts/forest/forest_east_tree_families.gd")
const ROOT="res://assets/maps/falan/east_region/native_trees/"
static var catalog:Dictionary={}
static var masters:Dictionary={}
static var source_points:Dictionary={}
static var canopy_surfaces:Dictionary={}
static var meshes:Dictionary={}
static func data()->Dictionary:
 if catalog.is_empty():catalog=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return catalog
static func owns(serial:int)->bool:return data().graphics.has(str(serial))
static func master(asset:String)->Mesh:
 if masters.has(asset):return masters[asset]
 var parts=[];var points:Array[Vector3]=[];var roles=[]
 for part in Base.Meadow.source(asset):
  var mesh:Mesh=Base.transformed_existing(part.mesh,part.transform,part.material)
  for arrays:Array in mesh.get_meta("east_cpu_arrays"):
   for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:points.append(p)
   roles.append(part.name=="Canopy")
  parts.append(mesh)
 masters[asset]=Base.combine(parts);source_points[asset]=points;canopy_surfaces[asset]=roles
 return masters[asset]
static func mesh(serial:int,g:Dictionary)->Mesh:
 if meshes.has(serial):return meshes[serial]
 var spec:Dictionary=data().graphics[str(serial)]
 assert(spec.source_rgba_sha256==g.rgba_sha256 and spec.origin==g.origin and spec.footprint==g.footprint,"Regenerate source-native tree bindings")
 if spec.get("kind","")=="native_canopy_tree":
  var traced:Mesh=Base.owner_frame(Traced.native_canopy(g,spec));traced.set_meta("east_source_graphic",serial);traced.set_meta("east_native_tree_fit",true)
  meshes[serial]=traced;return traced
 var original:Mesh=master(spec.asset);var turn=Transform3D(Basis(Vector3.UP,-PI*.25),Vector3.ZERO);var points:Array[Vector3]=[]
 for p:Vector3 in source_points[spec.asset]:points.append(turn*p)
 var b:Array=spec.visible;var target=Rect2(float(g.origin[0])+b[0],float(g.origin[1])+b[1],b[2]-b[0],b[3]-b[1])
 var source_fit:Transform3D=Base.Fit.measure(points,"",Basis(Vector3.UP,PI*.5),target)*turn
 var result:Mesh=Base.owner_frame(Base.transformed_existing(original,source_fit))
 for slot in result.get_surface_count():
  var material:Material=result.surface_get_material(slot)
  if material is StandardMaterial3D:
   var paint:StandardMaterial3D=material.duplicate()
   var canopy:bool=canopy_surfaces[spec.asset][slot]
   var rgb:Array=spec.foliage_tint if canopy else spec.bark_tint
   if canopy:
    var leaves=ShaderMaterial.new();leaves.shader=Base.Meadow.WIND
    leaves.set_shader_parameter("tree",true);leaves.set_shader_parameter("canopy",true);leaves.set_shader_parameter("strength",.025)
    leaves.set_shader_parameter("use_source_paint",true);leaves.set_shader_parameter("source_paint",paint.albedo_texture);leaves.set_shader_parameter("source_cutout",true)
    leaves.set_shader_parameter("foliage_tint",Vector3(rgb[0],rgb[1],rgb[2]));result.surface_set_material(slot,leaves)
   else:
    paint.albedo_color=Color(rgb[0],rgb[1],rgb[2])*paint.albedo_color;result.surface_set_material(slot,paint)
 result.set_meta("east_source_graphic",serial);result.set_meta("east_native_tree_fit",true);result.set_meta("east_tree_source_fit",source_fit)
 result.set_meta("east_tree_target",target);meshes[serial]=result;return result
