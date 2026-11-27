extends RefCounted
## Private material-only trial on the one unchanged whole canopy.
const Whole=preload("res://tests/forest-shrine/east_source100_whole_canopy_candidate.gd")
const Base=Whole.Base
const ROOT=Whole.ROOT+"Native Leaf Material Candidate/"
static var result:Mesh
static func mesh(serial:int)->Mesh:
 assert(serial==10074)
 if result!=null:return result
 var original:Mesh=Whole.mesh(serial)
 result=original.duplicate()
 var records:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"source.json"))
 var arrays:Array=original.get_meta("east_cpu_arrays");var mean=Vector3.ZERO;var count=0
 for color:Color in arrays.back()[Mesh.ARRAY_COLOR]:mean+=Vector3(color.r,color.g,color.b);count+=1
 mean/=count
 var wanted:Array=records.native_crown_mean_linear;var sample:Array=records.opaque_crop_mean_linear
 var tint=Vector3(wanted[0]/sample[0],wanted[1]/sample[1],wanted[2]/sample[2])/mean
 var paint:ShaderMaterial=original.surface_get_material(original.get_surface_count()-1).duplicate()
 paint.set_shader_parameter("source_paint",ImageTexture.create_from_image(Image.load_from_file(ROOT+"native-leaf-edge-32.png")))
 paint.set_shader_parameter("source_cutout",true);paint.set_shader_parameter("foliage_tint",tint)
 result.surface_set_material(result.get_surface_count()-1,paint)
 result.set_meta("private_native_leaf_material",true);result.set_meta("leaf_crop",records.crop_bounds);result.set_meta("leaf_alpha_coverage",records.alpha128_coverage_fraction);result.set_meta("native_leaf_tint",tint)
 return result
