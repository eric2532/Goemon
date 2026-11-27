extends RefCounted
## Private one whole world-space canopy; existing wood/source assets stay immutable.
const Native=preload("res://scripts/forest/forest_east_native_trees.gd")
const Base=Native.Base
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Tree Whole Canopy Candidate/"
static var result:Mesh
static func mesh(serial:int)->Mesh:
 assert(serial==10074)
 if result!=null:return result
 Base.Art.load_east();var g:Dictionary=Base.Art.data().graphics[str(serial)];var spec:Dictionary=Native.data().graphics[str(serial)];var parts=[]
 for part:Dictionary in Base.Meadow.source("crossgate_flora/cg_woodland"):
  if part.name=="Canopy":parts.append(Base.transformed_existing(part.mesh,part.transform,part.material))
 var master:Mesh=Base.combine(parts);var right=Vector3(1,0,1).normalized();var width=Vector2(INF,-INF);var mean=Vector3.ZERO;var samples=0
 for arrays:Array in master.get_meta("east_cpu_arrays"):
  for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:width.x=minf(width.x,point.dot(right));width.y=maxf(width.y,point.dot(right))
  for color:Color in arrays[Mesh.ARRAY_COLOR]:mean+=Vector3(color.r,color.g,color.b);samples+=1
 mean/=samples
 var target_width=228./(sqrt(2.)*Base.Fit.HORIZONTAL);var scale_=target_width/(width.y-width.x);var bounds=master.get_aabb()
 # This visible leaf/wood connection is independently measured. The old helper
 # crown_junction y270 includes lower olive bark; preserved branch tips start237.5.
 var raw_junction=Base.projected(Vector2(112.5,235.),g,0.,float(spec.ground_offset));var junction=Vector3(raw_junction.x,raw_junction.y*Base.OWNER_Y_SCALE,raw_junction.z)
 var center=bounds.get_center()*scale_;var shift=Vector3(junction.x-center.x,junction.y-.25-bounds.position.y*scale_,junction.z-center.z)
 var pose=Transform3D(Basis.from_scale(Vector3.ONE*scale_),shift);var canopy:Mesh=Base.transformed_existing(master,pose)
 var wanted:Array=spec.foliage_tint;var tint=Vector3(wanted[0],wanted[1],wanted[2])/mean
 var original:StandardMaterial3D=master.surface_get_material(0);assert(original.albedo_texture!=null)
 var paint=ShaderMaterial.new();paint.shader=Base.Meadow.WIND;paint.set_shader_parameter("tree",true);paint.set_shader_parameter("canopy",true);paint.set_shader_parameter("strength",.025);paint.set_shader_parameter("foliage_tint",tint);paint.set_shader_parameter("use_source_paint",true);paint.set_shader_parameter("source_paint",original.albedo_texture)
 for i in canopy.get_surface_count():canopy.surface_set_material(i,paint)
 # The original source-traced wood needs its existing pixel-owner adaptation.
 # The reused world-space canopy keeps its natural proportions; do not adapt it twice.
 var wood:Mesh=Base.owner_frame(Native.Traced.native_branches(g,spec))
 result=Base.combine([wood,canopy]);result.set_meta("private_whole_canopy",serial);result.set_meta("whole_master_uniform_scale",scale_);result.set_meta("source_width_world",target_width);result.set_meta("source_junction_pixel",Vector2(112.5,235.));result.set_meta("wood_junction_world",junction);result.set_meta("inferred_canopy_overlap",.25);result.set_meta("world_canopy_no_extra_y_scale",true);result.set_meta("height_frames","source-traced wood=.045/pixel; reused world canopy=uniform source-width fit")
 return result
