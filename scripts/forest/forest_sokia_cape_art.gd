extends RefCounted
## Continuous source-footprint rock; original map and native collision keep ownership.
const Cliffs=preload("res://scripts/forest/forest_original_cliffs.gd")
static var prepared:Dictionary={}
static var rock:ShaderMaterial
static func data()->Dictionary:
 if prepared.is_empty():prepared=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/cape/rock.json"))
 return prepared
static func build(parent:Node3D,placements:Array,state:Dictionary):
 var source=data();var visual=Node3D.new();visual.name="SokiaCapeSourceVisuals";parent.add_child(visual)
 var context={"profiles":source.profiles,"graphics":source.graphics,"cap_paint":source.cap_paint,"texture":load(source.texture),"original_palette":true,"minimum_crown_fraction":source.minimum_crown_fraction,"tile_unseen_faces":true,"wall_tiles":source.wall_tiles,"wall_tile_scale":source.wall_tile_scale}
 Cliffs.build(visual,placements,state.size,state.bits,state.origin,15525,Vector2i.ZERO,context)
 var background=MeshInstance3D.new();background.name="CapeSourceVoidBackground";var plane=PlaneMesh.new();plane.size=Vector2(state.size)*3.;background.mesh=plane
 background.position=Vector3(state.origin.x+(state.size.x-1)*1.5,.006,state.origin.y+(state.size.y-1)*1.5)
 var dark=StandardMaterial3D.new();dark.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;dark.albedo_color=Color("141414");background.material_override=dark;visual.add_child(background)
 parent.set_meta("sokia_cape_source_wall_anchors",source.anchors);visual.set_meta("source_map_sha256",source.source_sha256)
static func generated_paint(parent:Node3D):
 if rock==null:
  var rgb:Array=data().generated_rock_paint.mean_rgb
  rock=load("res://scripts/forest/forest_stone_fort.gd").material(Color(rgb[0],rgb[1],rgb[2]),false).duplicate()
  rock.set_shader_parameter("use_cliff_face",true);rock.set_shader_parameter("cliff_face",load("res://assets/maps/falan/sokia/cape/rock.png"));rock.set_shader_parameter("snow_cover",0.)
 for name_ in ["FrostpassRockWalls","FrostpassRockMass"]:
  var node=parent.find_child(name_,true,false)
  if node!=null:node.material_override=rock
 parent.set_meta("cape_generated_wall_paint",data().generated_rock_paint)
