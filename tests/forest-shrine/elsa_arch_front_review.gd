extends "res://tests/forest-shrine/elsa_map_review.gd"
## Review the actual production entrance; never deform or replace a live mesh.
const Scenery=preload("res://scripts/forest/forest_elsa_scenery.gd")
var prepared=false

func _initialize():
 capture_output=OUTPUT+"arch-production/"
 super._initialize()

func prepare_review_point(point:Dictionary):
 check(int(point.map)==59603,"Production entrance review uses its owned source crossing")
 if prepared:return
 prepared=true
 var entrance=Scenery.TrialEntrance;var spec=entrance.data()
 check(spec.map_source_proofs.size()==56 and not spec.candidate_only,"Production entrance retains the56-map source proof")
 var visible_recess=[];var arches=[]
 for node in game.world.find_children("*","GeometryInstance3D",true,false):
  if not node.is_visible_in_tree() or node.get_world_3d()!=game.camera_rig.camera.get_world_3d():continue
  if node.name=="ElsaOriginalArchRecess":visible_recess.append(node)
  if str(node.name).begins_with("ElsaOriginalObject_562"):arches.append(node)
 check(visible_recess.size()==1 and visible_recess[0].mesh==entrance.mesh,"Normal scenery setup binds the shared production recess")
 check(visible_recess.size()==1 and visible_recess[0].get_child_count()==0,"Recess adds no collision, interaction or travel owner")
 check(visible_recess.size()==1 and visible_recess[0].get_meta("inferred_floor_thickness")==.5,"Underfloor continuation remains explicitly inferred")
 var row:Dictionary=Scenery.props.groups["562"];var surface=Scenery.source_surface_spec(row.source_surface.path,59603)
 var key="prop:562:"+str(surface.background_template)
 check(arches.size()==1 and arches[0].multimesh.mesh==Scenery.meshes.get(key),"The matched foreground uses its real map-specific production mesh")
 var at=Original.source_point(59603,Vector2i(45,95))
 check(is_zero_approx(game.model.surface_height(at.x,at.y)),"Original crossing remains on its unchanged walking-height floor")
 var links=Original.links(59603).filter(func(link):return link.at==at and link.get("floor",0)==59602)
 check(links.size()==1 and links[0].arrival==Original.source_point(59602,Vector2i(66,75)),"Source entrance retains its original destination and landing")
 print("ELSA_ARCH_PRODUCTION map=59603 source_maps=56 background_template=",surface.background_template)
