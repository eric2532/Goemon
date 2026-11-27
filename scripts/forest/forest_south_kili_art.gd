extends RefCounted
## Setup-only owned finishes; original meshes, collision, signs and doors stay authoritative.
const Population=preload("res://scripts/forest/forest_south_kili_population.gd")
static var scopes:Dictionary={}
static var materials:Dictionary={}
static func scope(model)->Texture2D:
 var area:String=model.falan_area
 var size_:Vector2i=model.terrain.mask_texture().get_size()
 var origin:Vector2=model.terrain.mask_origin()
 if scopes.has(area) and scopes[area].get_size()==Vector2(size_) and scopes[area].get_meta("grid_origin")==origin:return scopes[area]
 var image=Image.create(size_.x,size_.y,false,Image.FORMAT_R8)
 for y in image.get_height():
  for x in image.get_width():
   var at=origin+Vector2(x,y)*3.
   if area=="kili" or Population.in_scope(area,Population.source_cell(model,at)):image.set_pixel(x,y,Color.WHITE)
 image.generate_mipmaps();scopes[area]=ImageTexture.create_from_image(image);scopes[area].set_meta("grid_origin",origin)
 return scopes[area]
static func owned(original:ShaderMaterial,model,role:String)->ShaderMaterial:
 var cave:bool=model.falan_area=="interior"
 var cold:bool=model.falan_floor in [15003,15004,15005]
 var key=[original,model.falan_area,cold,role]
 if materials.has(key):return materials[key]
 var mat:ShaderMaterial=original.duplicate()
 var amount=.62 if cave else .40
 var tint=Vector3(.34,.47,.51) if cold else Vector3(.48,.42,.32)
 if role=="rock":tint=Vector3(.28,.38,.42) if cold else Vector3(.40,.35,.28)
 elif role=="ground":tint=Vector3(.44,.43,.28) if model.falan_area=="sokia_coast" else Vector3(.35,.39,.22);amount=.18 if model.falan_area=="kili" else .30
 elif role=="facade":tint=Vector3(.66,.59,.46);amount=.16;mat.set_shader_parameter("route_preserve_ink",true)
 mat.set_shader_parameter("route_finish",amount);mat.set_shader_parameter("route_tint",tint)
 if not cave:
  var origin:Vector2=(model.terrain.mask_origin()-Vector2.ONE*1.5)*model.falan_scale
  var size_:Vector2=model.terrain.mask_texture().get_size()*3.*model.falan_scale
  mat.set_shader_parameter("route_scope",scope(model));mat.set_shader_parameter("route_scope_bounds",Vector4(origin.x,origin.y,size_.x,size_.y))
 materials[key]=mat
 return mat
static func finish(root:Node3D,model):
 if not Population.owns(model):return
 materials.clear()
 var count=0
 for node in root.find_children("*","GeometryInstance3D",true,false):
  var mesh:Mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D else null
  if mesh==null:continue
  if model.falan_area=="kili" and node is MeshInstance3D and node.name.begins_with("BlueCGVillageBuilding_"):
   var source=node.get_active_material(0)
   if source is ShaderMaterial:node.set_surface_override_material(0,owned(source,model,"facade"));count+=1
   continue
  var material:Material=node.material_override if node.material_override!=null else mesh.surface_get_material(0)
  if not material is ShaderMaterial:continue
  var shader:String=material.shader.resource_path.get_file()
  var role=""
  if model.falan_area=="interior" and shader=="habaru_ceiling.gdshader":role="rock"
  elif model.falan_area=="interior" and node.name=="ArchivedRoomFloor":role="floor"
  elif shader=="forest_stone.gdshader" and material.get_shader_parameter("use_cliff_face"):role="cliff"
  elif shader=="wind_meadow_ground.gdshader":role="ground"
  if role.is_empty():continue
  node.material_override=owned(material,model,role);count+=1
 root.set_meta("south_kili_owned_finishes",count)
 var world:Node=root
 while world!=null and not world.has_method("make_map_features"):world=world.get_parent()
 if world!=null:
  for key in materials:
   for registry in [world.kai_materials,world.blood_gulch_materials,world.attack_materials,world.fog_materials]:
    if key[0] in registry and materials[key] not in registry:registry.append(materials[key])
