extends RefCounted
## Material bindings only: no character roots, geometry, collision or map writes.
const SURFACE=preload("res://scripts/forest/forest_painterly_surface.gdshader")
const FOG=preload("res://scripts/forest/forest_fog.gdshader")
const BRUSH=preload("res://assets/textures/forest_painterly/painterly_ground_v1.png")
var world
var overrides:Array=[]
var fog_shaders:Array=[]
var touched_fog:Dictionary={}
var materials:Dictionary={}
var cull_shaders:Dictionary={}
func _init(owner_world):world=owner_world
func apply():
 for id in world.structure_nodes:style(world.structure_nodes[id],"building")
 style(world.forest_root,"forest")
 style(world.map_features,"stone")
 style(world.deposit_root,"stone")
func restore():
 for entry in overrides:
  var node=entry[0].get_ref()
  if not is_instance_valid(node):continue
  if entry[1]<0:node.material_override=entry[2]
  else:node.set_surface_override_material(entry[1],entry[2])
 for entry in fog_shaders:
  var mat=entry[0].get_ref()
  if not is_instance_valid(mat):continue
  mat.shader=entry[1]
  for name_ in ["brush_texture","surface_kind","fog_enabled","use_vertex_color"]:mat.set_shader_parameter(name_,null)
 overrides.clear();fog_shaders.clear();touched_fog.clear();materials.clear();cull_shaders.clear()
func restore_overrides(root_:Node):
 # A removed/replaced building must not retain meshes or replacement materials.
 # Shared forest/map fog materials remain styled until the full restore.
 for index in range(overrides.size()-1,-1,-1):
  var entry=overrides[index]
  var node=entry[0].get_ref()
  if not is_instance_valid(node):overrides.remove_at(index);continue
  if not is_instance_valid(root_) or not root_.is_ancestor_of(node):continue
  if entry[1]<0:node.material_override=entry[2]
  else:node.set_surface_override_material(entry[1],entry[2])
  overrides.remove_at(index)
 var used:Dictionary={}
 for entry in overrides:
  var node=entry[0].get_ref()
  if not is_instance_valid(node):continue
  var mat=node.material_override if entry[1]<0 else node.get_surface_override_material(entry[1])
  used[mat]=true
 for key in materials.keys():
  if not used.has(materials[key]):materials.erase(key)
func style(root_:Node,role:String):
 for node in root_.get_children():
  if node.name in ["Health","RoadTiles"] or node.get_meta("native_terrain",false) or node.get_meta("native_halo_scenery",false):continue
  if node is MeshInstance3D or node is MultiMeshInstance3D:
   if node.material_override is ShaderMaterial:
    var source:ShaderMaterial=node.material_override
    # Retain portal animation, road/ground shading and every special effect.
    if source.shader==FOG and not touched_fog.has(source):
     touched_fog[source]=true;fog_shaders.append([weakref(source),source.shader])
     var kind=3 if source.get_shader_parameter("canopy_layer")==true else (4 if role=="forest" else 1)
     source.shader=SURFACE;source.set_shader_parameter("brush_texture",BRUSH)
     source.set_shader_parameter("surface_kind",kind);source.set_shader_parameter("fog_enabled",true);source.set_shader_parameter("use_vertex_color",true)
   elif node.material_override is StandardMaterial3D:
    var replacement=paint(node.material_override,node,role)
    overrides.append([weakref(node),-1,node.material_override]);node.material_override=replacement
   elif node is MeshInstance3D and node.material_override==null and node.mesh!=null:
    for slot in node.mesh.get_surface_count():
     var source=node.get_active_material(slot)
     if source is StandardMaterial3D:
      overrides.append([weakref(node),slot,node.get_surface_override_material(slot)])
      node.set_surface_override_material(slot,paint(source,node,"imported"))
  style(node,role)
func paint(source:StandardMaterial3D,node:GeometryInstance3D,role:String)->Material:
 # Preserve translucent effects; the current imported buildings are opaque.
 if source.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA:return source
 var color=source.albedo_color
 var kind=5 if role=="imported" else 1
 var axis=Vector3.UP
 var mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh
 if role!="imported":
  if source.metallic>.1 or (color.r>.7 and color.g>.55 and color.b<.45):kind=6
  elif mesh is PrismMesh:kind=2
  elif color.r>color.g*1.15 and color.r>color.b*1.25:kind=0
 if mesh is BoxMesh:
  if mesh.size.x>mesh.size.y and mesh.size.x>mesh.size.z:axis=Vector3.RIGHT
  elif mesh.size.z>mesh.size.y:axis=Vector3.BACK
 var key=str(source.get_instance_id())+str(kind)+str(axis)
 if materials.has(key):return materials[key]
 var mat=ShaderMaterial.new();var cull=source.cull_mode
 if not cull_shaders.has(cull):
  if cull==BaseMaterial3D.CULL_BACK:cull_shaders[cull]=SURFACE
  else:
   var shader=Shader.new();shader.code=SURFACE.code.replace("cull_back","cull_front" if cull==BaseMaterial3D.CULL_FRONT else "cull_disabled");cull_shaders[cull]=shader
 mat.shader=cull_shaders[cull]
 mat.set_shader_parameter("base_color",color);mat.set_shader_parameter("surface_kind",kind);mat.set_shader_parameter("grain_axis",axis)
 mat.set_shader_parameter("brush_texture",BRUSH)
 mat.set_shader_parameter("use_vertex_color",source.vertex_color_use_as_albedo)
 mat.set_shader_parameter("vertex_color_srgb",source.vertex_color_is_srgb)
 mat.set_shader_parameter("use_base_texture",source.albedo_texture!=null);mat.set_shader_parameter("base_texture",source.albedo_texture)
 mat.set_shader_parameter("uv_scale",Vector2(source.uv1_scale.x,source.uv1_scale.y));mat.set_shader_parameter("uv_offset",Vector2(source.uv1_offset.x,source.uv1_offset.y))
 mat.set_shader_parameter("alpha_cutout",source.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR);mat.set_shader_parameter("alpha_threshold",source.alpha_scissor_threshold)
 if source.emission_enabled:
  mat.set_shader_parameter("emission_color",source.emission);mat.set_shader_parameter("emission_strength",source.emission_energy_multiplier)
 materials[key]=mat;return mat
