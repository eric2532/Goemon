extends RefCounted
## One editable Blender kit supplies solid, shared meshes for every city shrine.
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const KIT="res://assets/models/environments/wind_meadow/travel_stones/travel_stone_kit.glb"
const ROTATIONS={17235:0.0,17236:PI*.5,17237:-PI*.5,17238:PI*.5,17239:0.0,17240:PI,17241:0.0}
static var crystal_material:ShaderMaterial

static func piece(root:Node3D,part_name:String,point:Vector3,yaw:float=0.0)->MeshInstance3D:
 for part in Assets.source(KIT):
  if part.name!=part_name:continue
  var node=Geo.mesh(root,part.mesh,Vector3.ZERO,part.material)
  node.transform=Transform3D(Basis(Vector3.UP,yaw),point)*part.transform
  return node
 assert(false,"Missing solid travel-stone part: "+part_name)
 return null

static func ornament(root:Node3D,point:Vector3,serial:int):
 var part="Lectern" if serial in [17235,17236] else "Post" if serial==17241 else "Crescent"
 var node=piece(root,part,point,ROTATIONS[serial])
 node.name="TravelOrnament_%d_%d_%d"%[serial,point.x,point.z]
 node.set_meta("source_graphic",serial)

static func crystal(root:Node3D,point:Vector3)->MeshInstance3D:
 if crystal_material==null:
  crystal_material=ShaderMaterial.new()
  crystal_material.shader=preload("res://scripts/forest/forest_travel_crystal.gdshader")
  crystal_material.set_shader_parameter("facet_paint",preload("res://assets/textures/wind_meadow/travel_stones/crystal_paint.png"))
 var node=piece(root,"Crystal",point+Vector3.UP*3.05)
 node.material_override=crystal_material
 return node
