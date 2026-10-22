extends "res://tests/forest-shrine/painterly_environment_test.gd"
## Building changes must not recreate unaffected scenery, materials or lighting.
func detail_at(point:Vector3)->Node3D:
 for node in world.painterly_pilot.scenery.get_children():
  if node.position.is_equal_approx(point):return node
 return null
func retained(items:Array)->bool:
 for item in items:
  var node=item.node.get_ref()
  if not is_instance_valid(node) or node.material_override!=item.override:return false
  if node is MeshInstance3D:
   for slot in item.surfaces.size():
    if node.get_surface_override_material(slot)!=item.surfaces[slot]:return false
 return true
func run():
 # Actors keep empty mesh nodes for effects. Their identity still belongs in
 # the snapshot; an empty placeholder must not abort the preservation check.
 var empty=MeshInstance3D.new();root.add_child(empty)
 var empty_snapshot=snapshot([empty])
 check(empty_snapshot.size()==1 and restored(empty_snapshot),"Empty effect meshes remain part of the preservation snapshot")
 empty.mesh=BoxMesh.new()
 check(not restored(empty_snapshot),"The snapshot detects a mesh added to an empty effect placeholder")
 empty.free()
 var model=load("res://scripts/forest/forest_model.gd").new()
 var layout={"deposits":[{"x":-5,"z":1,"amount":1200}],"trees":[{"x":18,"z":18,"scale":1.0}],"roads":[{"x":5,"z":5}],"buildings":[
  {"kind":"mine","x":-5,"z":1,"rotation":0},{"kind":"gate","x":0,"z":7,"rotation":0},{"kind":"tower","x":-5,"z":7,"rotation":0}]}
 model.reset(42,{},layout);model.workers.clear()
 world=load("res://scripts/forest/forest_world.gd").new();world.model=model;root.add_child(world);await process_frame
 var original_nodes=[]
 for node in world.structure_nodes.values():original_nodes.append_array(geometry(node))
 original_nodes.append_array(geometry(world.forest_root));original_nodes.append_array(geometry(world.deposit_root))
 var originals=snapshot(original_nodes)
 var environment:WorldEnvironment
 var sun:DirectionalLight3D
 for node in world.get_children():
  if node is WorldEnvironment:environment=node
  elif node is DirectionalLight3D:sun=node
 var original_environment=environment.environment
 var original_sun=[sun.rotation,sun.light_color,sun.light_energy]
 var original_ground=world.ground_material.shader
 var original_roads=world.map_features.get_node("RoadTiles").material_override.shader
 world.set_painterly_preview(true)
 var pilot=world.painterly_pilot
 var scenery_ref=weakref(pilot.scenery)
 var gate_ref=weakref(detail_at(model.center(model.buildings[3])))
 var tower_ref=weakref(detail_at(model.center(model.buildings[4])))
 var painted=snapshot(original_nodes)
 var painted_environment=environment.environment
 var initial_overrides=pilot.environment_style.overrides.size()
 var added_mine=model._make_building("mine",Vector2i(9,1),0)
 model.revision+=1;world.sync(0)
 check(pilot.scenery==scenery_ref.get_ref(),"Adding one building retains the scenery root")
 check(environment.environment==painted_environment,"Adding one building retains the painted environment resource")
 check(retained(painted),"Adding one building retains every unchanged material binding")
 check(detail_at(model.center(model.buildings[3]))==gate_ref.get_ref() and detail_at(model.center(model.buildings[4]))==tower_ref.get_ref(),"Adding one building retains existing gate/tower decorations and lights")
 var mine_painted=false
 for mesh in geometry(world.structure_nodes[added_mine.id]):
  if mesh.material_override is ShaderMaterial and mesh.material_override.shader==pilot.SURFACE:mine_painted=true
 check(mine_painted,"The newly added mine receives painterly materials immediately")
 var added_tower=model._make_building("tower",Vector2i(9,7),1)
 model.revision+=1;world.sync(0)
 var new_detail=detail_at(model.center(added_tower))
 check(new_detail!=null and new_detail.transform==world.structure_nodes[added_tower.id].transform,"A new tower receives decoration at its exact transform")
 check(pilot.scenery.get_child_count()==3,"Adding one tower creates exactly one decoration group")
 model._remove_building(added_tower.id);model._remove_building(added_mine.id);model.revision+=1;world.sync(0)
 check(pilot.scenery==scenery_ref.get_ref() and environment.environment==painted_environment,"Removing buildings retains scenery and lighting resources")
 check(detail_at(model.center(model.buildings[3]))==gate_ref.get_ref() and detail_at(model.center(model.buildings[4]))==tower_ref.get_ref(),"Removing buildings retains unaffected decoration identities")
 check(pilot.scenery.get_child_count()==2 and retained(painted),"Removing buildings immediately removes only their details")
 check(pilot.environment_style.overrides.size()==initial_overrides,"Removed structures release their material restoration records")
 # A replacement node with an existing model ID must be treated as new geometry.
 world.structure_nodes[4].queue_free();world.structure_nodes.erase(4);model.revision+=1;world.sync(0)
 check(detail_at(model.center(model.buildings[4]))!=tower_ref.get_ref(),"Replacing one structure recreates its own decoration")
 check(detail_at(model.center(model.buildings[3]))==gate_ref.get_ref() and pilot.scenery.get_child_count()==2,"Replacing a structure retains unrelated details without duplicates")
 # Full disable still restores the exact original resources of surviving nodes.
 world.set_painterly_preview(false);await process_frame
 var surviving=originals.filter(func(item):return is_instance_valid(item.node.get_ref()))
 check(restored(surviving),"Disabling after incremental changes restores every surviving original material")
 check(environment.environment==original_environment and [sun.rotation,sun.light_color,sun.light_energy]==original_sun,"Disabling restores the exact original environment and sun")
 check(world.ground_material.shader==original_ground and world.map_features.get_node("RoadTiles").material_override.shader==original_roads,"Disabling restores ground and road shaders")
 world.set_painterly_preview(true);world.reload_map();await process_frame
 check(pilot.scenery.get_child_count()==2 and pilot.selected_ids==[3,4],"Reload rebuilds exactly the current map's decoration and focus")
 check(world.forest_root.get_child(0).material_override.shader==pilot.SURFACE,"Reload reapplies painterly forest materials")
 check(environment.environment.ssao_enabled and world.ground_material.shader==pilot.GROUND,"Reload retains the painterly environment and ground")
 world.set_painterly_preview(false)
 check(environment.environment==original_environment and world.ground_material.shader==original_ground,"Disabling after reload restores original resources")
 world.queue_free();await process_frame
 print("PAINTERLY_INCREMENTAL_REFRESH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
