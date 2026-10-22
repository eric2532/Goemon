extends "res://tests/forest-shrine/painterly_pilot_test.gd"
const FOLDER="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/painterly-environment-20261018"
var camera:Camera3D
func geometry(root_:Node)->Array:
 var result=[]
 for node in root_.get_children():
  if node.name=="Health":continue
  if node is MeshInstance3D or node is MultiMeshInstance3D:result.append(node)
  result.append_array(geometry(node))
 return result
func snapshot(nodes:Array)->Array:
 var result=[]
 for node in nodes:
  var item={"node":weakref(node),"override":node.material_override,"mesh":node.mesh if node is MeshInstance3D else node.multimesh.mesh,"surfaces":[],"active":[],"shaders":[]}
  if node is MeshInstance3D:
   if node.mesh!=null:
    for slot in node.mesh.get_surface_count():
     item.surfaces.append(node.get_surface_override_material(slot));item.active.append(node.get_active_material(slot))
  else:
   item.active.append(node.material_override);item.multimesh=node.multimesh;item.buffer=node.multimesh.buffer.duplicate()
  for mat in item.active:item.shaders.append(mat.shader if mat is ShaderMaterial else null)
  result.append(item)
 return result
func changed(item:Dictionary)->bool:
 var node=item.node.get_ref()
 for i in item.active.size():
  var mat=node.get_active_material(i) if node is MeshInstance3D else node.material_override
  if mat!=item.active[i] or (mat is ShaderMaterial and mat.shader!=item.shaders[i]):return true
 return false
func restored(items:Array)->bool:
 for item in items:
  var node=item.node.get_ref()
  if node.material_override!=item.override:return false
  if (node.mesh if node is MeshInstance3D else node.multimesh.mesh)!=item.mesh:return false
  if node is MeshInstance3D:
   for slot in item.surfaces.size():
    if node.get_surface_override_material(slot)!=item.surfaces[slot]:return false
  else:
   if node.multimesh!=item.multimesh or node.multimesh.buffer!=item.buffer:return false
  if changed(item):return false
 return true
func capture(label_:String,point:Vector3,look:Vector3,size_:float=0):
 if DisplayServer.get_name()=="headless":return
 if camera==null:camera=Camera3D.new();root.add_child(camera);camera.current=true
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL if size_>0 else Camera3D.PROJECTION_PERSPECTIVE
 if size_>0:camera.size=size_
 camera.position=point;camera.look_at(look)
 for i in 5:await process_frame
 RenderingServer.force_draw();root.get_texture().get_image().save_png(FOLDER+"/"+label_+".png")
func run():
 var model=load("res://scripts/forest/forest_model.gd").new();var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_ramparts();model.reset(42,{},doc.data)
 world=load("res://scripts/forest/forest_world.gd").new();world.model=model;root.add_child(world);await process_frame
 var state=collisions(world);doc.capture(model);var map_before=doc.encode();var scouting=[model.explored.duplicate(true),model.visible_cells.duplicate(true)]
 var groups={};var all_items=[]
 for id in model.buildings:
  var kind=model.buildings[id].kind
  if not groups.has(kind):groups[kind]=[]
  groups[kind].append_array(snapshot(geometry(world.structure_nodes[id])))
 for label_ in ["trees","ramparts","deposits"]:
  var node=world.forest_root if label_=="trees" else (world.deposit_root if label_=="deposits" else world.map_features.get_node("RaisedWallRoutes"))
  groups[label_]=snapshot(geometry(node))
 for items in groups.values():all_items.append_array(items)
 var workers=[]
 for node in world.worker_nodes.values():workers.append_array(snapshot(geometry(node)))
 var portal=world.portal_nodes[0];var portal_effects=[]
 for mesh in geometry(portal):
  for slot in mesh.mesh.get_surface_count():
   var mat=mesh.get_active_material(slot)
   if mat is ShaderMaterial and mat.shader.resource_path.get_file() in ["halo_teleporter_surface.gdshader","halo_teleporter_column.gdshader"]:portal_effects.append([mesh,slot,mat,mat.shader])
 # The old toggle still gives an exact A/B view.
 await capture("overview-before",Vector3(40,210,245),Vector3(0,0,85),300)
 await capture("settlement-before",Vector3(38,25,67),Vector3(-3,6,24))
 world.set_painterly_preview(true);await process_frame
 for label_ in groups:
  var count=0
  for item in groups[label_]:
   if changed(item) or item.active.all(func(mat):return mat is ShaderMaterial and mat.shader.resource_path.ends_with("forest_stone.gdshader")):count+=1
  check(count==groups[label_].size() and count>0,"Painterly coverage for all %s surfaces (%d/%d)"%[label_,count,groups[label_].size()])
 check(collisions(world)==state,"Tree, wall, building and rampart collision identities and transforms are unchanged")
 doc.capture(model);check(doc.encode()==map_before and model.explored==scouting[0] and model.visible_cells==scouting[1],"Authored map and scouting state stay unchanged")
 var instances_same=true
 for item in groups.trees+groups.wall:
  var node=item.node.get_ref()
  if node is MultiMeshInstance3D and (node.multimesh!=item.multimesh or node.multimesh.buffer!=item.buffer or node.multimesh.mesh!=item.mesh):instances_same=false
 check(instances_same,"Trees and stone walls retain their instancing buffers and original meshes")
 check(restored(workers),"Worker character materials and geometry remain untouched")
 check(portal_effects.size()==2 and portal_effects.all(func(item):return item[0].get_active_material(item[1])==item[2] and item[2].shader==item[3]),"Both native green teleporter effects remain active and unchanged")
 var prior_hero=model.hero_position;model.hero_position=Vector3(12,0,18);model.phase="wave";world.sync(0)
 var canopy=world.forest_root.get_child(1).material_override
 check(canopy.get_shader_parameter("canopy_cutaway")==true and canopy.get_shader_parameter("hero_position")==Vector2(12,18),"Painted canopy follows the live player position and combat cutaway")
 model.hero_position=prior_hero;model.phase="preparing";world.sync(0)
 await capture("overview-after",Vector3(40,210,245),Vector3(0,0,85),300)
 await capture("settlement-after",Vector3(38,25,67),Vector3(-3,6,24))
 await capture("forest-after",Vector3(-57,17,76),Vector3(-77,9,37))
 await capture("rampart-after",Vector3(52,36,165),Vector3(0,17,130))
 world.set_painterly_preview(false);await process_frame
 check(restored(all_items),"Original override, embedded and per-surface materials restore exactly")
 world.set_painterly_preview(true);world.reload_map();await process_frame
 check(world.forest_root.get_child(0).material_override.shader.resource_path.ends_with("forest_painterly_surface.gdshader"),"Map reload reapplies painted trees")
 # A newly built object must be painted even if the original focus pair is unchanged.
 var cell=Vector2i(-4,-3);var id=model._make_building("tower",cell,0).id;model.revision+=1;world.sync(0)
 var newly_painted=false
 for mesh in geometry(world.structure_nodes[id]):
  if mesh.material_override is ShaderMaterial:newly_painted=true
 check(newly_painted,"Newly placed buildings receive the environment style immediately")
 world.set_painterly_preview(false);world.queue_free();await process_frame
 print("PAINTERLY_ENVIRONMENT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
