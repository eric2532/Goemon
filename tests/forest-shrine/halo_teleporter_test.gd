extends SceneTree
## Actual world/editor lifecycle: catches asset substitution, repainting native
## energy, per-portal resource duplication, added sound/collision and spawn drift.
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func visuals(node:Node)->Array:
 return node.find_children("*","MeshInstance3D",true,false)
func snapshot(node:Node)->Array:
 var result=[]
 for mesh in visuals(node):
  result.append(mesh.mesh)
  for slot in mesh.mesh.get_surface_count():result.append(mesh.get_active_material(slot))
 return result
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_blood_gulch()
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{},doc.data);model.workers.clear()
 var before=model.portals.duplicate(true)
 var world=load("res://scripts/forest/forest_world.gd").new();world.model=model;world.painterly_preview_enabled=true;root.add_child(world)
 await process_frame
 check(world.portal_nodes.size()==8,"All eight authored entrances receive the replacement")
 var first=world.portal_nodes[0]
 var native=first.get_node_or_null("HaloTeleporter")
 check(native!=null,"The source world uses the recovered Halo teleporter")
 if native==null:world.queue_free();await process_frame;finish();return
 var triangles=0
 for visual in visuals(native):
  for slot in visual.mesh.get_surface_count():
   triangles+=visual.mesh.surface_get_arrays(slot)[Mesh.ARRAY_INDEX].size()/3
 check(triangles==184,"Original pad geometry retains all 184 native triangles, including its energy surfaces")
 check(first.find_children("*","CollisionObject3D",true,false).is_empty(),"Replacement scenery does not block existing enemy exits")
 check(first.find_children("*","AudioStreamPlayer3D",true,false).is_empty() and first.find_children("*","AudioStreamPlayer",true,false).is_empty(),"Enemy portals have no hum or activation audio")
 var original=snapshot(first)
 for i in world.portal_nodes.size():
  var portal=world.portal_nodes[i];var authored:Dictionary=before[i]
  check(portal.position==model.point(Vector2i(authored.x,authored.z)) and is_equal_approx(portal.rotation.y,-int(authored.rotation)*PI*.5),"Entrance %d retains its terrain anchor and inward facing"%i)
  check(snapshot(portal)==original,"Entrance %d shares original meshes and materials instead of allocating copies"%i)
 world.set_painterly_preview(false);world.set_painterly_preview(true)
 check(snapshot(first)==original,"Painterly toggles preserve the native metal textures and green energy shaders")
 world.show_portal_preview(Vector2i(0,20),1,true)
 check(snapshot(world.portal_ghost)==original,"Editor placement shows the same Halo pad and animated energy")
 check(is_equal_approx(world.portal_ghost.rotation.y,-PI*.5),"Editor rotation turns the real teleporter")
 for i in 5:world.sync(.1)
 check(snapshot(first)==original and model.portals==before,"Updates retain shared visual resources and authored spawn data")
 world.reload_map();await process_frame
 check(world.portal_nodes.size()==8 and snapshot(world.portal_nodes[0])==original,"Map reload reuses native resources with no accumulating portal geometry")
 world.queue_free();await process_frame;finish()
func finish():
 print("HALO_TELEPORTER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
