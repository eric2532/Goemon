@static_unload
extends RefCounted
## One imported source per asset; every placement shares its mesh and materials.
const DIR="res://assets/models/environments/wind_meadow/"
const WIND=preload("res://scripts/forest/wind_meadow_foliage.gdshader")
static func crossgate_tree(serial:int)->String:
 return DIR+"crossgate_flora/"+("cg_evergreen" if serial<10074 else "cg_silverleaf" if serial>=10088 else "cg_woodland")+".glb"
static var parts:Dictionary={}
static var wind_materials:Dictionary={}
static var roof_materials:Dictionary={}
static var building_style=preload("res://scripts/forest/forest_painterly_environment.gd").new(null)
static func source(asset:String)->Array:
 var path=asset if asset.begins_with("res://") else DIR+asset+".glb"
 if not parts.has(path):
  var scene=load(GameAssets.model_path(path)).instantiate();var result=[]
  var meshes=scene.find_children("*","MeshInstance3D",true,false)
  if scene is MeshInstance3D:meshes.push_front(scene)
  for mesh in meshes:
   var transform_=Transform3D.IDENTITY if mesh==scene else mesh.transform;var ancestor=mesh.get_parent()
   if mesh!=scene:
    while ancestor!=scene:transform_=ancestor.transform*transform_;ancestor=ancestor.get_parent()
   var material=mesh.material_override if mesh.material_override!=null else scene.get_meta("scenery_material",null) if scene.has_meta("scenery_material") else null
   if path.begins_with(DIR+"falan/"):material=building_style.paint(mesh.get_active_material(0),mesh,"imported")
   result.append({"mesh":mesh.mesh,"transform":transform_,"name":str(mesh.name),"material":material})
  parts[path]=result;scene.free()
 return parts[path]
static func batch(parent:Node3D,asset:String,poses:Array,wind:bool=false,far:float=0.0,tint:Color=Color.WHITE,roof:Color=Color.TRANSPARENT):
 if poses.is_empty():return
 var asset_name=asset.get_file().get_basename()
 var recovered_tree=asset.begins_with(DIR+"crossgate_flora/")
 var canopy_asset=recovered_tree or asset_name in ["broadleaf_tree","cedar_tree","pine_tree","sakura_tree"]
 if canopy_asset and poses.size()>64:
  var chunks={}
  for pose:Transform3D in poses:
   var cell=Vector2i(floori(pose.origin.x/96.0),floori(pose.origin.z/96.0))
   if not chunks.has(cell):chunks[cell]=[]
   chunks[cell].append(pose)
  # Keep every placement; local bounds let Godot cull trees outside the camera and shadow views.
  if chunks.size()>1:
   for group in chunks.values():batch(parent,asset,group,wind,far,tint,roof)
   return
 for part in source(asset):
  var node=MultiMeshInstance3D.new();node.name=asset_name+"_"+part.name
  if recovered_tree:node.set_meta("crossgate_tree_part",part.name)
  if canopy_asset and wind:node.extra_cull_margin=.5
  node.material_override=part.material
  if roof.a>0 and part.material is ShaderMaterial:
   var key=[part.material,roof]
   if not roof_materials.has(key):
    var variant:ShaderMaterial=part.material.duplicate()
    variant.set_shader_parameter("falan_roof_paint",roof)
    roof_materials[key]=variant
   node.material_override=roof_materials[key]
  node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=part.mesh;node.multimesh.instance_count=poses.size()
  for i in poses.size():node.multimesh.set_instance_transform(i,poses[i]*part.transform)
  if asset_name.begins_with("grass") or asset_name.begins_with("flowers"):node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  if far>0:node.visibility_range_end=far;node.visibility_range_end_margin=12
  if asset.begins_with("res://assets/models/cedar_pass/"):node.material_override=preload("res://assets/models/cedar_pass/shared_matte.tres")
  if wind and (not canopy_asset or part.name=="Canopy"):
   var tree=canopy_asset or asset_name in ["leafy_shrub","bamboo_cluster"];var key=str(tree)+str(canopy_asset)+str(tint)
   if recovered_tree:key+=asset_name
   if not wind_materials.has(key):
    var mat=ShaderMaterial.new();mat.shader=WIND;mat.set_shader_parameter("tree",tree);mat.set_shader_parameter("canopy",canopy_asset);mat.set_shader_parameter("strength",.025 if tree else .12);mat.set_shader_parameter("foliage_tint",Vector3(tint.r,tint.g,tint.b));wind_materials[key]=mat
    if recovered_tree:
     mat.set_shader_parameter("use_source_paint",true)
     mat.set_shader_parameter("source_paint",part.mesh.surface_get_material(0).albedo_texture)
   node.material_override=wind_materials[key]
  if asset_name=="broadleaf_tree" and part.name=="Canopy":node.set_meta("wind_meadow_canopy",true)
  parent.add_child(node)
static func building(parent:Node3D,asset:String)->Node3D:
 var node=load(DIR+"buildings/"+asset+".glb").instantiate();node.name="WindMeadowAsset";node.set_meta("native_terrain",true);parent.add_child(node)
 if asset in ["watchtower","cannon_tower","barracks"]:
  for mesh:MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
   for slot in mesh.mesh.get_surface_count():mesh.set_surface_override_material(slot,building_style.paint(mesh.get_active_material(slot),mesh,"imported"))
 return node
static func wall(parent:Node3D,length_:float,center_x:float):
 var poses=[];var count=ceili(length_/6.0);var segment=length_/count
 for i in count:poses.append(Transform3D(Basis.IDENTITY.scaled(Vector3(segment/6,1,1)),Vector3(center_x-length_*.5+segment*(i+.5),0,0)))
 var root=Node3D.new();root.name="WindMeadowWall";root.set_meta("native_terrain",true);parent.add_child(root)
 batch(root,"buildings/wall_section",poses)
static func gate(parent:Node3D):
 var source_=building(parent,"gate_frame");var leaf=source_.find_child("GateDoor",true,false)
 var profile=preload("res://scripts/forest/forest_structure_profile.gd")
 # The existing moving collider and wall-damage owner keep their original origin.
 var door=Geo.box(parent,Vector3(0,profile.GATE_CLOSED_Y,0),Vector3(profile.GATE_DOOR_WIDTH,profile.GATE_DOOR_HEIGHT,profile.GATE_DOOR_THICKNESS),Geo.mat("795239"));door.name="GateDoor";door.layers=0
 leaf.owner=null;leaf.reparent(door,false);leaf.position.y-=profile.GATE_CLOSED_Y;leaf.name="PaintedLeaf"
