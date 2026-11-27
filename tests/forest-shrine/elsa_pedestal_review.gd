extends "res://tests/forest-shrine/elsa_map_review.gd"
## Review the real source-fitted pedestal without replacing any live mesh.
const Scenery=preload("res://scripts/forest/forest_elsa_scenery.gd")
var prepared=false

func _initialize():
 capture_output=OUTPUT+"pedestal-production/"
 super._initialize()

func prepare_review_point(point:Dictionary):
 check(int(point.map)==59530,"Pedestal remains in its original temple map")
 if prepared:return
 prepared=true
 var guard:Dictionary=load("res://tests/forest-shrine/elsa_entry_loot_test.gd").evaluate()
 check(guard.get("checks",0)==192 and guard.get("errors",[]).is_empty(),"All95 source areas still exclude generic entry loot on first and repeated preparation")
 var row:Dictionary=Scenery.props.groups["406"];var spec=Scenery.source_surface_spec(row.pedestal.path,59530)
 check(row.rgba_sha256==spec.rgba_sha256 and not spec.candidate_only,"Runtime sections retain the exact original pedestal source")
 var matches=[]
 for node in game.world.find_children("ElsaOriginalObject_406","MultiMeshInstance3D",true,false):
  if node.is_visible_in_tree() and node.get_world_3d()==game.camera_rig.camera.get_world_3d():matches.append(node)
 check(matches.size()==1 and matches[0].multimesh.instance_count==1,"The source pedestal retains its single original placement")
 if matches.size()!=1:return
 var node=matches[0];var mesh:Mesh=node.multimesh.mesh
 check(mesh==Scenery.meshes.get("prop:406") and mesh.get_surface_count()==2,"Normal scenery binds the shared body and globe surfaces")
 check(mesh.has_meta("source_surface_arrays"),"The body retains prepared CPU arrays through source fitting")
 var materials_match=true
 for i in 2:
  var material:ShaderMaterial=mesh.surface_get_material(i);var texture:Texture2D=material.get_shader_parameter("base_texture")
  materials_match=materials_match and texture.resource_path==spec.paints["body" if i==0 else "globe"]
 check(materials_match,"Both material boundaries use their canonical original-paint derivatives")
 var cap=(float(spec.body.foot[1])-float(spec.orb.cap_native_row))/Scenery.Fit.VERTICAL
 check(absf(mesh.get_aabb().end.y-cap-2.*float(spec.orb.radius))<.001 and absf(mesh.get_aabb().position.y)<.001,"Actual mesh keeps a full round globe resting on its cap and the original base height")
 var placement:Dictionary=Scenery.props.maps["59530"].filter(func(p):return p.group=="406")[0]
 var state=Original.state(59530);var u=float(placement.anchor[0]);var v=float(placement.anchor[1])
 var expected=Vector3(state.origin.x+u*3./64.-v/16.,0,state.origin.y+u*3./64.+v/16.)
 var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(0)
 check((pose.origin/game.model.falan_scale).distance_to(expected)<.001,"Normal batching preserves the original native anchor")
 check(node.get_child_count()==0,"Pedestal adds no collision, NPC, quest or interaction owner")
 print("ELSA_PEDESTAL_PRODUCTION source=",spec.rgba_sha256," surfaces=",mesh.get_surface_count())
