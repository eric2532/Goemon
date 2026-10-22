extends RefCounted
## Recovered Blood Gulch pad. Meshes/materials are built once and shared by all
## entrances and editor ghosts. Shader TIME animates the native texture layers;
## no particles, audio, collision bodies or per-frame script updates are added.
const ASSETS="res://assets/scenery/halo_teleporter/"
const JMS_METERS=.03048
const SCENE_SCALE=10.0
static var shared_meshes:Array=[]

static func build()->Node3D:
 if shared_meshes.is_empty():_build_meshes()
 var root=Node3D.new();root.name="HaloTeleporter"
 root.set_meta("native_halo_scenery",true)
 root.scale=Vector3.ONE*SCENE_SCALE
 for i in shared_meshes.size():
  var visual=MeshInstance3D.new();visual.name=["NativeMetalPad","NativeEnergySurface","NativeEnergyColumn"][i]
  visual.mesh=shared_meshes[i]
  if i>0:visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  root.add_child(visual)
 return root

static func _build_meshes():
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ASSETS+"model.json"))
 var materials={
  "teleporter_base":_metal("teleporter_base",true),
  "metal flat generic":_metal("metal_flat",false),
  "metal strips decorative wide":_metal("metal_strips",false),
  "teleporter_shield":_energy(false),
  "teleporter_cone":_energy(true),
 }
 shared_meshes=[ArrayMesh.new(),ArrayMesh.new(),ArrayMesh.new()]
 var vertices=PackedVector3Array();var normals=PackedVector3Array();var uvs=PackedVector2Array()
 for vertex in data.vertices:
  var p:Array=vertex.position;var n:Array=vertex.normal
  # Halo +X forward/+Y left/+Z up -> Godot -Z forward/-X left/+Y up.
  vertices.append(Vector3(-p[1],p[2],-p[0])*JMS_METERS)
  normals.append(Vector3(-n[1],n[2],-n[0]).normalized())
  uvs.append(Vector2(vertex.uv[0],1.0-vertex.uv[1]))
 for slot in data.materials.size():
  var indices=PackedInt32Array()
  for triangle in data.triangles:
   if int(triangle.material)!=slot:continue
   # JMS uses counterclockwise faces; Godot's front faces are clockwise.
   indices.append_array(PackedInt32Array([triangle.indices[2],triangle.indices[1],triangle.indices[0]]))
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
  var name_:String=data.materials[slot]
  var mesh:ArrayMesh=shared_meshes[1 if name_=="teleporter_shield" else (2 if name_=="teleporter_cone" else 0)]
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  mesh.surface_set_material(mesh.get_surface_count()-1,materials[name_])
  mesh.surface_set_name(mesh.get_surface_count()-1,name_)

static func _metal(name_:String,cutout:bool)->StandardMaterial3D:
 var material=StandardMaterial3D.new()
 material.albedo_texture=load(ASSETS+"textures/"+name_+".png")
 material.metallic=.4;material.roughness=.5
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 if cutout:
  material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
  material.alpha_scissor_threshold=.5
 return material

static func _energy(column:bool)->ShaderMaterial:
 var material=ShaderMaterial.new()
 material.shader=preload("res://scripts/forest/halo_teleporter_column.gdshader") if column else preload("res://scripts/forest/halo_teleporter_surface.gdshader")
 for name_ in (["volumetric_dust","teleporter_dust"] if column else ["plasma","energy_mask","shield"]):
  material.set_shader_parameter(name_,load(ASSETS+"textures/"+name_+".png"))
 return material
