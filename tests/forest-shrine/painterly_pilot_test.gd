extends SceneTree
var checks=0
var failures=0
var world
func _initialize():run.call_deferred()
func check(ok: bool,note: String):
 checks+=1;print("PASS: " if ok else "FAIL: ",note)
 if not ok:failures+=1
func collisions(node: Node)->Array:
 var result=[]
 for child in node.get_children():
  if child is CollisionObject3D:result.append([child.get_instance_id(),child.collision_layer,child.collision_mask,child.transform])
  if child is CollisionShape3D:result.append([child.get_instance_id(),child.shape,child.transform,child.disabled])
  result.append_array(collisions(child))
 return result
func run():
 var model=load("res://scripts/forest/forest_model.gd").new()
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_ramparts();model.reset(42,{},doc.data)
 world=load("res://scripts/forest/forest_world.gd").new();world.model=model;root.add_child(world)
 await process_frame
 check(world.has_method("set_painterly_preview"),"World supports reversible painterly presentation")
 if not world.has_method("set_painterly_preview"):world.queue_free();await process_frame;quit(1);return
 var before=collisions(world);var buildings=model.buildings.duplicate(true);doc.capture(model);var map_before=doc.encode()
 var original_shader=world.ground_material.shader
 var originals={}
 for id in world.structure_nodes:
  for child in world.structure_nodes[id].get_children():
   if child is MeshInstance3D:originals[child.get_instance_id()]=[weakref(child),child.material_override]
 world.set_painterly_preview(true);await process_frame
 check(collisions(world)==before,"Preview adds no collision bodies or changes to collision geometry")
 doc.capture(model)
 check(doc.encode()==map_before and model.buildings==buildings,"Presentation leaves authored map, health and building stats untouched")
 check(world.painterly_pilot.selected_ids.size()==2,"Exactly one gate and one nearby tower get the new presentation")
 check(world.model.center(model.buildings[world.painterly_pilot.selected_ids[1]]).x<world.model.center(model.buildings[world.painterly_pilot.selected_ids[0]]).x,"The pilot uses the western tower")
 var art=world.painterly_pilot.scenery
 model.revision+=1;world.sync(0)
 check(world.painterly_pilot.scenery==art,"Unrelated model revisions do not rebuild presentation")
 check(world.ground_material.shader!=original_shader,"Ground uses the painted texture shader")
 var count=world.painterly_pilot.scenery.get_child_count()
 world.set_painterly_preview(true)
 check(world.painterly_pilot.scenery.get_child_count()==count,"Repeated enable does not duplicate scenery")
 world.set_painterly_preview(false);await process_frame
 check(world.ground_material.shader==original_shader,"Disabling restores the original ground shader")
 var restored=true
 for value in originals.values():
  var mesh=value[0].get_ref()
  if mesh.material_override!=value[1]:restored=false
 check(restored,"All original structure material references restore exactly")
 check(collisions(world)==before,"Disabling preserves the original collision identities")
 for i in 3:world.set_painterly_preview(true);world.set_painterly_preview(false)
 world.set_painterly_preview(true);world.reload_map();await process_frame
 check(world.painterly_pilot.selected_ids.size()==2 and world.painterly_pilot.scenery.get_child_count()==count,"Reload reapplies one bounded pilot without accumulating scenery")
 world.set_painterly_preview(false)
 doc.load_original();model.reset(42,{},doc.data);world.reload_map();world.set_painterly_preview(true);await process_frame
 check(world.painterly_pilot.selected_ids.size()==2 and model.ramparts.is_empty(),"Protected Original Map stays available with the same optional art treatment")
 world.set_painterly_preview(false)
 for id in model.buildings.keys():
  if model.buildings[id].kind in ["gate","tower"]:model.buildings.erase(id)
 model.revision+=1;world.sync(0);world.set_painterly_preview(true);await process_frame
 check(world.painterly_pilot.selected_ids.is_empty(),"Custom maps without a gate or tower are handled safely")
 world.queue_free();await process_frame
 print("PAINTERLY_PILOT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
