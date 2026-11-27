extends RefCounted
## Private 10074 study: intact whole-tree Meadow canopy/material, no native photo skin.
const Native=preload("res://scripts/forest/forest_east_native_trees.gd")
const Cluster=preload("res://tests/forest-shrine/east_source100_cluster_tree_candidate.gd")
const Base=Native.Base
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Runtime Audit/Source100 Missing13/Tree Meadow Clumps Candidate/"
static var result:Mesh
static func mesh(serial:int)->Mesh:
 assert(serial==10074)
 if result!=null:return result
 Base.Art.load_east();var g:Dictionary=Base.Art.data().graphics[str(serial)];var spec:Dictionary=Native.data().graphics[str(serial)]
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"source.json"));var parts=[]
 for part:Dictionary in Base.Meadow.source("crossgate_flora/cg_woodland"):
  if part.name!="Canopy":continue
  parts.append(Base.transformed_existing(part.mesh,part.transform,part.material))
 var master:Mesh=Base.combine(parts);var turn=Transform3D(Basis(Vector3.UP,-PI*.25),Vector3.ZERO);var points:Array[Vector3]=[];var mean=Vector3.ZERO;var samples=0
 for arrays:Array in master.get_meta("east_cpu_arrays"):
  for point:Vector3 in arrays[Mesh.ARRAY_VERTEX]:points.append(turn*point)
  for color:Color in arrays[Mesh.ARRAY_COLOR]:mean+=Vector3(color.r,color.g,color.b);samples+=1
 assert(samples>0);mean/=samples
 var wanted:Array=spec.foliage_tint;var tint=Vector3(wanted[0],wanted[1],wanted[2])/mean
 var ray=Vector3(-1./16.,1./Base.Fit.VERTICAL,1./16.).normalized();var meshes=[Native.Traced.native_branches(g,spec)];var placements=[]
 var original:StandardMaterial3D=master.surface_get_material(0)
 assert(original.albedo_texture!=null,"Keep the whole canopy's original leaf-paint/UV contract")
 var paint=ShaderMaterial.new();paint.shader=Base.Meadow.WIND;paint.set_shader_parameter("tree",true);paint.set_shader_parameter("canopy",true);paint.set_shader_parameter("strength",.025);paint.set_shader_parameter("foliage_tint",tint);paint.set_shader_parameter("use_source_paint",true);paint.set_shader_parameter("source_paint",original.albedo_texture)
 var master_center=master.get_aabb().get_center()
 for box in data.source_visible_lobe_boxes:
  var pixel=Vector2((box[0]+box[2])*.5,(box[1]+box[3])*.5)
  var target=Rect2(Vector2(g.origin[0]+box[0],g.origin[1]+box[1]),Vector2(box[2]-box[0],box[3]-box[1]));var fit=Cluster.lobe_fit(points,target)*turn
  var desired=Base.projected(pixel,g,0.,float(spec.ground_offset));var old=fit*master_center
  fit.origin+=ray*(desired-old).dot(ray)
  assert(absf((fit*master_center-desired).dot(ray))<.0001,"Clumps must share the source trunk/crown depth plane")
  var cloud:Mesh=Base.transformed_existing(master,fit)
  for slot in cloud.get_surface_count():
   cloud.surface_set_material(slot,paint)
  meshes.append(cloud);placements.append({"native_box":box,"fit":var_to_str(fit),"physical_center":var_to_str(fit*master_center),"source_plane_center":var_to_str(desired)})
 result=Base.owner_frame(Base.combine(meshes));result.set_meta("private_meadow_clumps",serial);result.set_meta("source_clump_placements",placements);result.set_meta("native_palette_gain",tint);result.set_meta("existing_leaf_master","crossgate_flora/cg_woodland:Canopy");result.set_meta("no_native_photo_skin",true)
 return result
