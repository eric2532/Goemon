@static_unload
extends RefCounted
## Native STEP poses and one original actor OBB; all resources are shared.
const SCALE=1.8
const ROLE_TO_TYPE={0:1,1:2,3:3}
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const DIR="res://assets/characters/thirstquencher/"
static var resources={}
static func supports(role:int)->bool:return role in Roles.RIGID_TYPES
static func data(role:int)->Resource:
 if not resources.has(role):
  resources[role]=load("res://assets/characters/recovered_monsters/"+Roles.RECOVERED[role]+"_runtime.res") if Roles.RECOVERED.has(role) else load(DIR+"soldier_%d_runtime.res"%ROLE_TO_TYPE[role])
 return resources[role]
static func hurt_bounds(role:int=0)->AABB:
 if role==Roles.DARK_LUMINA_3:return AABB(Vector3(-.55,0,-.5)*Roles.DARK_LUMINA_3_SCALE,Vector3(1.1,2.5,1)*Roles.DARK_LUMINA_3_SCALE)
 if role==Roles.DARK_LUMINA_2:return AABB(Vector3(-224,0,-160)*.018*Roles.Dark.SCALE,Vector3(448,288,272)*.018*Roles.Dark.SCALE)
 if role==Roles.VAMBEE_TORSO:return AABB(Vector3(-.28,0,-.64)*SCALE,Vector3(.56,.64,.96)*SCALE)
 if role==Roles.VAMBEE:return AABB(Vector3(-.28,0,-.28)*SCALE,Vector3(.56,1.28,.56)*SCALE)
 if role==Roles.HAYA_WOLF:return AABB(Vector3(-.28,0,-.28)*SCALE,Vector3(.56,1.60,.56)*SCALE)
 if role==Roles.SLOW_GUY:return AABB(Vector3(-.56,0,-.56)*SCALE,Vector3(1.12,1.28,.72)*SCALE)
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
static func make_mesh(role:int,separate_surfaces:bool=false,prepared:Resource=null)->ArrayMesh:
 var resource=data(role) if prepared==null else prepared;var source:ArrayMesh=resource.get_meta("mesh");var sword_morph:ImageTexture
 if role==Roles.DARK_LUMINA_3 and prepared==null:
  source=source.duplicate()
  var scene=load("res://assets/models/enemies/recovered_monsters/dark_lumina_3_effects.glb").instantiate()
  var blade:Mesh=scene.find_child("Part_02",true,false).mesh
  var blade_points=0
  for surface in blade.get_surface_count():blade_points+=blade.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX].size()
  var sword_image=Image.create(blade_points,2,false,Image.FORMAT_RGBAF);var blade_offset=0
  for surface in blade.get_surface_count():
   var shapes=blade.surface_get_blend_shape_arrays(surface)
   var arrays=blade.surface_get_arrays(surface)
   if arrays[Mesh.ARRAY_NORMAL]==null:
    var surface_tool=SurfaceTool.new();surface_tool.create_from(blade,surface);surface_tool.generate_normals();arrays=surface_tool.commit().surface_get_arrays(0)
   var uv2=PackedVector2Array();uv2.resize(arrays[Mesh.ARRAY_VERTEX].size());
   for vertex in uv2.size():
    uv2[vertex]=Vector2(17+(blade_offset+vertex)/10000.0,0)
    for row in 2:
     var v:Vector3=shapes[row][Mesh.ARRAY_VERTEX][vertex];sword_image.set_pixel(blade_offset+vertex,row,Color(v.x,v.y,v.z,1))
   blade_offset+=uv2.size();arrays[Mesh.ARRAY_TEX_UV2]=uv2
   source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);source.surface_set_material(source.get_surface_count()-1,blade.surface_get_material(surface))
  sword_morph=ImageTexture.create_from_image(sword_image)
  scene.free()
 if separate_surfaces:
  var copy:ArrayMesh=source.duplicate()
  for slot in copy.get_surface_count():copy.surface_set_material(slot,shader_material(resource,source.surface_get_material(slot)))
  if role==Roles.DARK_LUMINA_2:
   for slot in copy.get_surface_count():copy.surface_get_material(slot).set_shader_parameter("role_size",Roles.Dark.SCALE)
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
  target.vertices.append_array(arrays[Mesh.ARRAY_VERTEX]);target.normals.append_array(arrays[Mesh.ARRAY_NORMAL]);target.colors.append_array(arrays[Mesh.ARRAY_COLOR])
  var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
  if uv.is_empty():uv.resize(arrays[Mesh.ARRAY_VERTEX].size()) # Untextured native faces have no UV channel.
  target.uv.append_array(uv)
  for point:Vector2 in arrays[Mesh.ARRAY_TEX_UV2]:target.uv2.append(Vector2(point.x,slot))
  for index:int in arrays[Mesh.ARRAY_INDEX]:target.indices.append(first+index)
 var palette=ImageTexture.create_from_image(colors);var mesh=ArrayMesh.new()
 for group:Dictionary in groups.values():
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=group.vertices;arrays[Mesh.ARRAY_NORMAL]=group.normals;arrays[Mesh.ARRAY_TEX_UV]=group.uv;arrays[Mesh.ARRAY_TEX_UV2]=group.uv2;arrays[Mesh.ARRAY_COLOR]=group.colors;arrays[Mesh.ARRAY_INDEX]=group.indices
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(mesh.get_surface_count()-1,shader_material(resource,group.material,palette))
 if role==Roles.DARK_LUMINA_3:
  for slot in mesh.get_surface_count():
   mesh.surface_get_material(slot).set_shader_parameter("finale",true);mesh.surface_get_material(slot).set_shader_parameter("sword_morph",sword_morph);mesh.surface_get_material(slot).set_shader_parameter("role_size",Roles.DARK_LUMINA_3_SCALE)
  var bounds:AABB=resource.get_meta("bounds");mesh.custom_aabb=AABB(bounds.position*Roles.DARK_LUMINA_3_SCALE,bounds.size*Roles.DARK_LUMINA_3_SCALE)
 if role==Roles.DARK_LUMINA_2:
  for slot in mesh.get_surface_count():mesh.surface_get_material(slot).set_shader_parameter("role_size",Roles.Dark.SCALE)
  var bounds:AABB=resource.get_meta("bounds");mesh.custom_aabb=AABB(bounds.position*Roles.Dark.SCALE,bounds.size*Roles.Dark.SCALE)
 mesh.set_meta("source_ranges",ranges)
 return mesh
static func update_environment(mesh:Mesh,environment:Environment):
 var filmic=environment!=null and environment.tonemap_mode==Environment.TONE_MAPPER_FILMIC
 var exposure=environment.tonemap_exposure if environment!=null else 1.0
 var white=environment.tonemap_white if environment!=null else 1.0
 for slot in mesh.get_surface_count():
  var material=mesh.surface_get_material(slot)
  material.set_shader_parameter("compensate_filmic",filmic);material.set_shader_parameter("scene_exposure",exposure);material.set_shader_parameter("scene_white",white)
