extends RefCounted
const MESH=preload("res://assets/maps/kai_highway/terrain.res")
const COLLISION=preload("res://assets/maps/kai_highway/collision.res")
const SHADER=preload("res://scripts/forest/kai_highway_surface.gdshader")
static func bind(world,material:ShaderMaterial):
 material.set_shader_parameter("visibility_map",world.fog_texture)
 world.fog_materials.append(material);world.kai_materials.append(material)
static func build(world,parent:Node3D):
 var root=Node3D.new();root.name="KaiHighwayTerrain";parent.add_child(root)
 var visual=MeshInstance3D.new();visual.mesh=MESH;root.add_child(visual)
 for slot in MESH.get_surface_count():
  var material=MESH.surface_get_material(slot).duplicate();bind(world,material);visual.set_surface_override_material(slot,material)
 var body=StaticBody3D.new();body.name="KaiTerrainCollision";body.collision_layer=1;body.collision_mask=0;root.add_child(body)
 var shape=CollisionShape3D.new();shape.shape=COLLISION;body.add_child(shape)
 load("res://scripts/halo_impact_material.gd").tag_terrain(body,world.model,MESH)
static func road_material(world)->ShaderMaterial:
 var material=ShaderMaterial.new();material.shader=SHADER
 material.set_shader_parameter("albedo_texture",preload("res://assets/maps/kai_highway/earth.png"))
 material.set_shader_parameter("wood_texture",preload("res://assets/maps/kai_highway/planks.png"))
 material.set_shader_parameter("road_mode",true);bind(world,material);return material
