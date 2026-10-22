extends RefCounted
## One native mesh/collision build per map load. Navigation comes from surface.res.
const DIRECTORY="res://assets/maps/blood_gulch/"
const SHADER=preload("res://scripts/forest/blood_gulch_surface.gdshader")
static func bind(world,material:ShaderMaterial):
 material.set_shader_parameter("visibility_map",world.fog_texture)
 world.fog_materials.append(material);world.blood_gulch_materials.append(material)
static func add_mesh(world,parent:Node3D,mesh:Mesh,label_:String)->MeshInstance3D:
 var visual=MeshInstance3D.new();visual.name=label_;visual.mesh=mesh;parent.add_child(visual)
 for slot in mesh.get_surface_count():
  var source=mesh.surface_get_material(slot)
  assert(source is ShaderMaterial,"Blood Gulch bake requires native shader materials")
  var material:ShaderMaterial=source.duplicate();bind(world,material);visual.set_surface_override_material(slot,material)
 return visual
static func build(world,parent:Node3D):
 var mesh=load(DIRECTORY+"terrain.res") as Mesh
 var collision=load(DIRECTORY+"collision.res") as Shape3D
 assert(mesh!=null and collision!=null,"Missing baked Blood Gulch terrain/collision")
 if mesh==null or collision==null:return
 var root=Node3D.new();root.name="BloodGulchTerrain";root.set_meta("native_terrain",true);root.scale=Vector3(world.model.terrain_scale,1,world.model.terrain_scale);parent.add_child(root)
 add_mesh(world,root,mesh,"BloodGulchGround")
 var body=StaticBody3D.new();body.name="BloodGulchGroundCollision";body.collision_layer=1;body.collision_mask=0;root.add_child(body)
 var shape=CollisionShape3D.new();shape.shape=collision;body.add_child(shape)
 load("res://scripts/halo_impact_material.gd").tag_terrain(body,world.model,mesh)
 # Source macro alpha blends grass/sand; expose a reliable native grass impact
 # fallback while roads continue resolving as dirt via halo_ground_model.
 body.set_meta("halo_material","leaves")
 var ranges=body.get_meta("halo_face_materials",[])
 for entry in ranges:entry.material="leaves"
 body.set_meta("halo_face_materials",ranges)
 if ResourceLoader.exists(DIRECTORY+"cliffs.res"):
  var cliffs=load(DIRECTORY+"cliffs.res") as Mesh
  add_mesh(world,root,cliffs,"BloodGulchCliffs")
  var cliff_body=StaticBody3D.new();cliff_body.name="BloodGulchCliffCollision";cliff_body.collision_layer=1;cliff_body.collision_mask=0;cliff_body.set_meta("halo_material","stone");root.add_child(cliff_body)
  var cliff_shape=CollisionShape3D.new();cliff_shape.shape=cliffs.create_trimesh_shape();cliff_body.add_child(cliff_shape)
static func road_material(world)->ShaderMaterial:
 var material=ShaderMaterial.new();material.shader=SHADER
 # The native ground texture gives authored roads a worn earth/grass treatment.
 var soil=load(DIRECTORY+"source_detail_sand.png") as Texture2D
 material.set_shader_parameter("albedo_texture",soil)
 material.set_shader_parameter("surface_tint",Color(.72,.64,.43))
 material.set_shader_parameter("road_mode",true);bind(world,material);return material
