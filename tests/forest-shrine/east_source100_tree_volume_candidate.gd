extends RefCounted
## Private single-tree crown study. Canonical Native27 meshes/art stay unchanged.
const Native=preload("res://scripts/forest/forest_east_native_trees.gd")
const Base=Native.Base
static var meshes:Dictionary={}
static func mesh(serial:int)->Mesh:
 if meshes.has(serial):return meshes[serial]
 assert(serial in [10074,10087,10089],"This private variation is limited to the three diagnosed East field trees")
 Base.Art.load_east();var graphic:Dictionary=Base.Art.data().graphics[str(serial)];var spec:Dictionary=Native.data().graphics[str(serial)]
 var paint:Texture2D=load(Native.ROOT+str(serial)+"-foliage.png");var image=Image.load_from_file(Native.ROOT+str(serial)+"-foliage.png");var visible=image.get_used_rect()
 var source_master=[]
 for part:Dictionary in Base.Meadow.source(spec.asset):
  if part.name=="Canopy":source_master.append(Base.transformed_existing(part.mesh,part.transform,part.material))
 assert(not source_master.is_empty(),"Reuse the existing whole Meadow canopy part")
 var crown:Mesh=Base.combine(source_master);var turn=Transform3D(Basis(Vector3.UP,-PI*.25),Vector3.ZERO);var points:Array[Vector3]=[]
 for arrays:Array in crown.get_meta("east_cpu_arrays"):
  for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:points.append(turn*p)
 var target=Rect2(Vector2(graphic.origin[0],graphic.origin[1])+Vector2(visible.position),Vector2(visible.size))
 var fit=Base.Fit.measure(points,"",Basis(Vector3.UP,PI*.5),target)*turn;crown=Base.transformed_existing(crown,fit)
 # Compress only camera-depth globally: source projection stays unchanged.
 # The exact native alpha face owns the observed silhouette; the reused mass
 # is an inferred rounded reverse rather than another rotated whole-front card.
 var center=Base.projected(Vector2(visible.get_center()),graphic,0.,float(spec.ground_offset));var normal=Vector3(-1,0,1).normalized();var ray=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized();var low=INF;var high=-INF
 for arrays:Array in crown.get_meta("east_cpu_arrays"):
  for p:Vector3 in arrays[Mesh.ARRAY_VERTEX]:var d=(p-center).dot(normal);low=minf(low,d);high=maxf(high,d)
 var original_arrays:Array=crown.get_meta("east_cpu_arrays");var depth_scale=minf(1.,3./maxf(high-low,.001));var amount=(depth_scale-1.)/ray.dot(normal)
 var basis=Basis(Vector3.RIGHT+ray*normal.x*amount,Vector3.UP+ray*normal.y*amount,Vector3.BACK+ray*normal.z*amount)
 var offset=-ray*center.dot(normal)*amount-ray*(high*depth_scale+.12)/ray.dot(normal)
 crown=Base.transformed_existing(crown,Transform3D(basis,offset))
 var projection_error=0.
 for slot in original_arrays.size():
  var before:PackedVector3Array=original_arrays[slot][Mesh.ARRAY_VERTEX];var after:PackedVector3Array=crown.get_meta("east_cpu_arrays")[slot][Mesh.ARRAY_VERTEX]
  for index in before.size():
   var delta=after[index]-before[index];projection_error=maxf(projection_error,Vector2((delta.x+delta.z)*32./3.,(delta.z-delta.x)*8.-delta.y*Base.Fit.VERTICAL).length())
 assert(projection_error<.0001,"Hidden crown depth must not move its measured source projection")
 for slot in crown.get_surface_count():
  var material:Material=crown.surface_get_material(slot)
  if material is StandardMaterial3D:
   var leaves=ShaderMaterial.new();leaves.shader=Base.Meadow.WIND;leaves.set_shader_parameter("tree",true);leaves.set_shader_parameter("canopy",true);leaves.set_shader_parameter("strength",.025);leaves.set_shader_parameter("use_source_paint",true);leaves.set_shader_parameter("source_paint",material.albedo_texture);leaves.set_shader_parameter("source_cutout",true);leaves.set_shader_parameter("foliage_tint",Vector3(spec.foliage_tint[0],spec.foliage_tint[1],spec.foliage_tint[2]));crown.surface_set_material(slot,leaves)
 var row:Dictionary=graphic.duplicate(true);row.rect=[0,0,graphic.rect[2],graphic.rect[3]];var front=Base.native_skin(row,paint);var pixels=[Vector2.ZERO,Vector2(graphic.rect[2],0),Vector2(graphic.rect[2],graphic.rect[3]),Vector2(0,graphic.rect[3])];var corners=[]
 for pixel in pixels:corners.append(Base.projected(pixel,graphic,0.,float(spec.ground_offset)))
 var n=(corners[2]-corners[0]).cross(corners[1]-corners[0]).normalized()
 for index in [0,1,2,0,2,3]:front.projected_vertex(corners[index],n,corners[index])
 for index in [3,2,1,3,1,0]:front.projected_vertex(corners[index],-n,corners[index])
 var result=Base.owner_frame(Base.combine([Native.Traced.native_branches(graphic,spec),crown,front.finish()]))
 result.set_meta("private_source_tree_volume",serial);result.set_meta("observed_front_sha256",FileAccess.get_sha256(Native.ROOT+str(serial)+"-foliage.png"));result.set_meta("inferred_rear_master",spec.asset);result.set_meta("source_camera_depth_only",3.);result.set_meta("crown_source_projection_error",projection_error);meshes[serial]=result;return result
