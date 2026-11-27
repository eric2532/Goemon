extends "res://tests/forest-shrine/elsa_map_review.gd"
## Inspect normal scenery bindings; no private heights, meshes or art injection.
const Floor=preload("res://scripts/forest/forest_elsa_landmark_floor.gd")
const Steps=preload("res://scripts/forest/forest_elsa_hall_steps.gd")
const Scenery=preload("res://scripts/forest/forest_elsa_scenery.gd")
var prepared=false

func _initialize():
 capture_output=OUTPUT+"entry-pedestals-production/"
 super._initialize()

func prepare_review_point(point:Dictionary):
 check(int(point.map)==59530,"Entry pedestals stay in their original map")
 if prepared:return
 prepared=true
 var row:Dictionary=Scenery.source_surface_spec(Scenery.ROOT+"entry-pedestals/data.json",59530)
 check(not row.candidate_only and not row.spec.candidate_only,"Normal scenery uses the published source variant")
 check(not Steps.records.has(59530) and not Steps.owns(59530),"Private negative stair support is not activated by the pedestal art")
 for cell in [Vector2i(59,93),Vector2i(69,92),Vector2i(66,90)]:
  var at=Original.source_point(59530,cell)
  check(is_zero_approx(game.model.surface_height(at.x,at.y)),"The original flat floor remains unchanged "+str(cell))
 var floor_data:Dictionary=Floor.data(59530)
 check(floor_data.pedestals_only and not floor_data.candidate_only and int(floor_data.removed_matte_pixels)==0,"Floor UV derivatives relocate only the BG pedestal photograph")
 var camera=game.camera_rig.camera
 var nodes=game.world.find_children("ElsaOriginalBGPedestal","MeshInstance3D",true,false).filter(func(node):return node.is_visible_in_tree() and node.get_world_3d()==camera.get_world_3d())
 check(nodes.size()==1,"The mapped background pedestal is instantiated exactly once")
 if nodes.size()!=1:return
 var node=nodes[0];var mesh:Mesh=node.mesh
 check(mesh.get_surface_count()==2 and mesh.has_meta("source_surface_arrays"),"Body/globe geometry retains its CPU source through the existing fitter")
 var paints_match=true
 for i in 2:
  var material:ShaderMaterial=mesh.surface_get_material(i);var texture:Texture2D=material.get_shader_parameter("base_texture")
  paints_match=paints_match and texture.resource_path==row.spec.paints["body" if i==0 else "globe"] and material.get_shader_parameter("original_palette")==true
 check(paints_match,"Both material boundaries bind the published BG variant paint")
 var native_foot=Vector2(row.bg_origin[0]+row.spec.body.foot[0],row.bg_origin[1]+row.spec.body.foot[1])
 var state=Original.state(59530)
 var expected=Vector3(state.origin.x,0,state.origin.y)+Floor.ground(native_foot)
 var actual:Vector3=node.global_transform*Floor.ground(Vector2(row.spec.body.foot[0],row.spec.body.foot[1]))/game.model.falan_scale
 check(actual.distance_to(expected)<.001,"The pedestal preserves its source-native foot and placement")
 var repair=node.get_parent().find_child("ElsaOriginalPedestalApronRepair",false,false)
 check(repair!=null and node.get_child_count()==0 and repair.get_child_count()==0,"Geometry and masked parent paving add no gameplay or collision owner")
 var background=node.get_parent().find_child("ElsaOriginalTempleVoid",false,false)
 check(background!=null and background.mesh is BoxMesh and background.mesh.flip_faces and background.get_child_count()==0,"Native background color encloses scene-sky gaps without physical terrain")
 check(node.get_parent().find_child("ElsaOriginalCurvedTreads",false,false)==null,"Stair photographs stay intact until their independent candidate is ready")
 check(game.army_runtime.handles.is_empty(),"The temple remains a safe area")
 var crystals=game.world.find_children("ElsaTempleReturnCrystal_*","MeshInstance3D",true,false).filter(func(part):return part.is_visible_in_tree() and part.get_world_3d()==camera.get_world_3d())
 check(crystals.size()==3,"All three return stones reuse the existing solid city crystal")
 for crystal in crystals:
  var proxy=crystal.get_parent();var actor:Dictionary=proxy.get_meta("npc_record",{})
  var at=Original.source_point(59530,Vector2i(actor.cell[0],actor.cell[1]))
  var location=Vector2(proxy.global_position.x,proxy.global_position.z)/game.model.falan_scale
  check(location.distance_to(at)<.001 and int(actor.graphic)==103010,"Crystal art retains the exact original NPC interaction point")
 print("ELSA_ENTRY_PEDESTALS_PRODUCTION source=",row.selected_source_sha256," repaired_pixels=",row.repair_samples.size())
