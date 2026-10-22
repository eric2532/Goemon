@static_unload
extends RefCounted
## Native STEP poses and one original actor OBB; all resources are shared.
const SCALE=5.4
const ROLE_TO_TYPE={0:1,1:2,3:3}
const DIR="res://assets/characters/thirstquencher/"
static var resources={}
static func supports(role:int)->bool:return ROLE_TO_TYPE.has(role)
static func data(role:int)->Resource:
 if not resources.has(role):resources[role]=load(DIR+"soldier_%d_runtime.res"%ROLE_TO_TYPE[role])
 return resources[role]
static func hurt_bounds()->AABB:
 # Original descriptor8018AB98: X[-32,32],Y[-112,0],Z[-64,64].
 return AABB(Vector3(-.32,0,-.64)*SCALE,Vector3(.64,1.12,1.28)*SCALE)
static func source_point(point:Vector3)->Vector3:
 # Source→glTF is(x,-y,-z), then half-turn to controller-Z.
 return Vector3(-point.x,-point.y,point.z)*(.01*SCALE)
static func frame_state(source:Dictionary,death_age:float=0)->Dictionary:
 var role=int(source.variant);var resource=data(role);var clips:Dictionary=resource.get_meta("clips");var semantic:Dictionary=resource.get_meta("semantics")
 var value:Dictionary=source.get("frozen_pose",source) if float(source.get("frozen",0))>0 else source
 var clip:String=semantic.idle;var tick=float(value.get("soldier_pose_tick",0));var loop=true
 if death_age>0:
  clip=semantic.death;tick=death_age*30;loop=false
 elif float(value.get("soldier_hurt_left",0))>0:
  clip=value.get("soldier_hurt_clip",semantic.hurt[0]);tick=float(value.get("soldier_hurt_tick",0));loop=false
 elif value.get("soldier_action","")=="attack":
  clip=value.get("soldier_clip",semantic.attack[0]);tick=float(value.get("soldier_tick",0));loop=false
 elif Vector3(value.get("velocity",Vector3.ZERO)).length_squared()>.01:
  clip=semantic.walk if role==1 else semantic.run
  tick=fposmod(float(value.get("walk_phase",0)),TAU)/TAU*int(clips[clip].ticks)
 var selected:Dictionary=clips.get(clip,clips[semantic.idle])
 var index=posmod(floori(tick),int(selected.ticks)) if loop else clampi(floori(tick),0,int(selected.ticks)-1)
 return {"clip":clip,"tick":index,"row":int(value.get("army_pose_row",selected.rows[index]))}
static func shader_material(resource:Resource,original:StandardMaterial3D,palette:Texture2D=null)->ShaderMaterial:
 var material=ShaderMaterial.new();material.shader=preload("res://assets/materials/thirstquencher_crowd.gdshader")
 material.set_shader_parameter("pose_texture",resource.get_meta("pose_texture"))
 material.set_shader_parameter("textured",original.albedo_texture!=null)
 material.set_shader_parameter("tint_color",original.albedo_color)
 if original.albedo_texture!=null:material.set_shader_parameter("albedo_texture",original.albedo_texture)
 if palette!=null:material.set_shader_parameter("use_tint_palette",true);material.set_shader_parameter("tint_palette",palette)
 return material
static func make_mesh(role:int,separate_surfaces:bool=false)->ArrayMesh:
 var resource=data(role);var source:ArrayMesh=resource.get_meta("mesh")
 if separate_surfaces:
  var copy:ArrayMesh=source.duplicate()
  for slot in copy.get_surface_count():copy.surface_set_material(slot,shader_material(resource,source.surface_get_material(slot)))
  return copy
 # Group only identical original texture resources. Float palette entries
 # replace per-draw uniforms; no original triangle/color/UV is approximated.
 var groups={};var ranges=[];var colors=Image.create(1,source.get_surface_count(),false,Image.FORMAT_RGBAF)
 for slot in source.get_surface_count():
  var original=source.surface_get_material(slot) as StandardMaterial3D;var texture=original.albedo_texture
  colors.set_pixel(0,slot,original.albedo_color.srgb_to_linear())
  if not groups.has(texture):groups[texture]={"material":original,"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"uv":PackedVector2Array(),"uv2":PackedVector2Array(),"colors":PackedColorArray(),"indices":PackedInt32Array()}
  var target:Dictionary=groups[texture];var arrays=source.surface_get_arrays(slot);var first:int=target.vertices.size()
  ranges.append({"source_slot":slot,"surface":groups.keys().find(texture),"vertex_first":first,"index_first":target.indices.size()})
  target.vertices.append_array(arrays[Mesh.ARRAY_VERTEX]);target.normals.append_array(arrays[Mesh.ARRAY_NORMAL]);target.uv.append_array(arrays[Mesh.ARRAY_TEX_UV]);target.colors.append_array(arrays[Mesh.ARRAY_COLOR])
  for point:Vector2 in arrays[Mesh.ARRAY_TEX_UV2]:target.uv2.append(Vector2(point.x,slot))
  for index:int in arrays[Mesh.ARRAY_INDEX]:target.indices.append(first+index)
 var palette=ImageTexture.create_from_image(colors);var mesh=ArrayMesh.new()
 for group:Dictionary in groups.values():
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=group.vertices;arrays[Mesh.ARRAY_NORMAL]=group.normals;arrays[Mesh.ARRAY_TEX_UV]=group.uv;arrays[Mesh.ARRAY_TEX_UV2]=group.uv2;arrays[Mesh.ARRAY_COLOR]=group.colors;arrays[Mesh.ARRAY_INDEX]=group.indices
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(mesh.get_surface_count()-1,shader_material(resource,group.material,palette))
 mesh.set_meta("source_ranges",ranges)
 return mesh
static func update_environment(mesh:Mesh,environment:Environment):
 var filmic=environment!=null and environment.tonemap_mode==Environment.TONE_MAPPER_FILMIC
 var exposure=environment.tonemap_exposure if environment!=null else 1.0
 var white=environment.tonemap_white if environment!=null else 1.0
 for slot in mesh.get_surface_count():
  var material=mesh.surface_get_material(slot)
  material.set_shader_parameter("compensate_filmic",filmic);material.set_shader_parameter("scene_exposure",exposure);material.set_shader_parameter("scene_white",white)
