extends RefCounted
## Resolve sparse weapon impacts from authored colliders; never search the world.
## Names match Halo CE projectile material response records (grass is `leaves`).
const MATERIALS=["dirt","sand","stone","snow","wood","metal_hollow","metal_thin","metal_thick","rubber","glass","force_field","grunt","hunter_armor","hunter_skin","elite","jackal","jackal_energy_shield","engineer_skin","engineer_force_field","flood_combat_form","flood_carrier_form","cyborg_armor","cyborg_energy_shield","human_armor","human_skin","sentinel","moniter","plastic","water","leaves","elite_energy_shield","ice","hunter_shield"]
static func resolve(hit:Dictionary,target:Ninja=null)->String:
 if is_instance_valid(target):return "human_skin"
 var collider=hit.get("collider")
 if not is_instance_valid(collider) or not collider is Node:return "stone"
 # A shape owner may carry a more specific material than its shared body.
 if collider is CollisionObject3D:
  var shape_index=int(hit.get("shape",-1))
  if shape_index>=0:
   for owner_id in collider.get_shape_owners():
    for owner_shape in collider.shape_owner_get_shape_count(owner_id):
     if collider.shape_owner_get_shape_index(owner_id,owner_shape)!=shape_index:continue
     var shape_owner=collider.shape_owner_get_owner(owner_id)
     if is_instance_valid(shape_owner) and shape_owner.has_meta("halo_material"):
      var shape_material=canonical(shape_owner.get_meta("halo_material"))
      if not shape_material.is_empty():return shape_material
     break
 var node:Node=collider
 for depth in 8:
  if node==null:break
  # Roads are a visual overlay on the ground collision; use its direct model
  # reference for O(1) road/bridge lookup instead of searching map structures.
  if node.has_meta("halo_ground_model") and hit.get("position") is Vector3:
   var model=node.get_meta("halo_ground_model")
   if is_instance_valid(model):
    var p:Vector3=hit.position
    if model.terrain.has_method("bridge_at") and model.terrain.bridge_at(p.x,p.z):return "wood"
    if model.roads.has(model.cell_of(p)):return "dirt"
  var face_index=int(hit.get("face_index",-1))
  if face_index>=0:
   for surface in node.get_meta("halo_face_materials",[]):
    if face_index<int(surface.end):
     var face_material=canonical(surface.material)
     if not face_material.is_empty():return face_material
     break
  var authored=canonical(node.get_meta("halo_material",""))
  if not authored.is_empty():return authored
  # Known legacy terrain names are conservative fallbacks for imported maps.
  if node.name=="WalkableRampart":return "stone"
  if node.name=="KaiTerrainCollision":return "dirt"
  node=node.get_parent()
 return "stone"
static func canonical(value)->String:
 if not value is String and not value is StringName:return ""
 var material=String(value).strip_edges().to_lower().replace(" ","_")
 if material in ["grass","plant"]:material="leaves"
 if material in ["human","flesh"]:material="human_skin"
 return material if material in MATERIALS else ""
static func tag_terrain(body:StaticBody3D,model,mesh:Mesh):
 body.set_meta("halo_ground_model",model)
 body.set_meta("halo_material","dirt")
 # Godot's trimesh face index follows the concatenated triangle surfaces.
 # Build just the surface boundaries once, without copying triangle data.
 var ranges:Array=[]
 var end=0
 for slot in mesh.get_surface_count():
  var arrays=mesh.surface_get_arrays(slot)
  var indices=arrays[Mesh.ARRAY_INDEX]
  var count=indices.size() if indices!=null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
  end+=count/3
  var material="stone"
  var shader=mesh.surface_get_material(slot)
  if shader is ShaderMaterial:
   var texture=shader.get_shader_parameter("albedo_texture")
   if texture is Texture2D:
    match texture.resource_path.get_file():
     "earth.png":material="dirt"
     "grass.png","texture_09003000_32x64.png":material="leaves"
     "planks.png","texture_0a003000_32x64.png","texture_0a00d000_32x64.png":material="wood"
  ranges.append({"end":end,"material":material})
 body.set_meta("halo_face_materials",ranges)
