extends RefCounted
## The fixed corridor alone reuses continuous source-rock masses and solid stone steps.
const Cliffs=preload("res://scripts/forest/forest_original_cliffs.gd")
const Stairs=preload("res://scripts/forest/forest_habaru_stairs.gd")
const FOLDER="res://assets/maps/falan/sokia/scenery/"
static var prepared:Dictionary={}
static func data()->Dictionary:
 if prepared.is_empty():prepared=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"gorge-mass.json"))
 return prepared
static func build(parent:Node3D,placements:Array,state:Dictionary):
 var source=data();var visual=Node3D.new();visual.name="SokiaGorgeSourceVisuals";parent.add_child(visual)
 var context={"profiles":source.profiles,"graphics":source.graphics,"cap_paint":source.cap_paint,"texture":load(FOLDER+"gorge-mass.png"),"original_palette":true,"minimum_crown_fraction":source.minimum_crown_fraction,"tile_unseen_faces":source.tile_unseen_faces}
 for key in ["wall_tiles","wall_tile_scale","wall_preview"]:
  if source.has(key):context[key]=source[key]
 Cliffs.build(visual,placements,state.size,state.bits,state.origin,15526,Vector2i.ZERO,context)
 for anchor in source.stair.anchors:
  var cell=Vector2i(anchor[0],anchor[1]);var at:Vector2=state.origin+Vector2(cell)*3.
  Stairs.build(visual,15526,cell,at,17954)
 # The existing source ground and walk-mask boundaries remain the sole physics owner.
 for collider in visual.find_children("*","CollisionObject3D",true,false):
  collider.get_parent().remove_child(collider);collider.free()
 var background=MeshInstance3D.new();background.name="GorgeSourceVoidBackground"
 var plane=PlaneMesh.new();plane.size=Vector2(state.size)*3.;background.mesh=plane
 background.position=Vector3(state.origin.x+(state.size.x-1)*1.5,.006,state.origin.y+(state.size.y-1)*1.5)
 var dark=StandardMaterial3D.new();dark.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;dark.albedo_color=Color("141414");background.material_override=dark
 visual.add_child(background)
 visual.set_meta("source_anchors",source.anchors);visual.set_meta("source_stair_anchors",source.stair.anchors)
 visual.set_meta("source_map_sha256",source.source_sha256)
 parent.set_meta("sokia_gorge_source_wall_anchors",source.anchors.size())
