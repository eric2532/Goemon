extends SceneTree
## Actual bake + world lifecycle; catches flat-floor leaks, material repainting and stale resources.
var checks=0
var failures=0
func _initialize():
 create_timer(40).timeout.connect(func():printerr("FAIL: native world test timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1
 print("PASS: " if ok else "FAIL: ",label_)
func run():
 check(ResourceLoader.exists("res://assets/maps/blood_gulch/terrain.res"),"Native Blood Gulch bake is available")
 if failures:quit(1);return
 var doc=load("res://scripts/forest/forest_map_document.gd").new()
 var error=doc.load_blood_gulch();check(error.is_empty(),"Bundled castle layout loads: "+error)
 if failures:quit(1);return
 var native_layout=doc.data.duplicate(true)
 # Exercise editor-painted native roads even when the bundled map uses only its original paths.
 native_layout.roads=[{"x":0,"z":2}]
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{},native_layout);model.workers.clear()
 var world=load("res://scripts/forest/forest_world.gd").new();world.model=model;world.painterly_preview_enabled=true;root.add_child(world)
 await process_frame
 var native=world.map_features.get_node_or_null("BloodGulchTerrain")
 check(native!=null and not world.base_ground.visible and world.base_ground_collision.collision_layer==0,"Native ground replaces the flat visual and physical base")
 check(world.playable_bounds.position.is_equal_approx(Vector2(-280.8,-280.8)) and world.playable_bounds.size.is_equal_approx(Vector2(561.6,561.6)),"Native playable bounds stay inside the baked terrain grid")
 var environment:WorldEnvironment
 for node in world.get_children():
  if node is WorldEnvironment:environment=node
 var daytime=environment.environment
 check(daytime.background_mode==Environment.BG_SKY,"The actual native map starts with bright sky after painterly initialization")
 var materials=[]
 for visual in native.find_children("*","MeshInstance3D",true,false):
  for slot in visual.mesh.get_surface_count():materials.append(visual.get_active_material(slot))
 check(not materials.is_empty() and materials.all(func(mat):return mat is ShaderMaterial and mat.shader.resource_path.ends_with("blood_gulch_surface.gdshader")),"Native grass and cliff materials survive generic painterly styling")
 check(materials.all(func(mat):return mat.get_shader_parameter("visibility_map")==world.fog_texture),"All native surfaces share gameplay scouting state")
 var roads=world.map_features.get_node_or_null("RoadTiles")
 if roads!=null:
  check(roads.material_override.shader.resource_path.ends_with("blood_gulch_surface.gdshader") and roads.material_override.get_shader_parameter("albedo_texture").resource_path.ends_with("source_detail_sand.png"),"Authored roads retain native soil instead of painterly or wooden tiles")
 var ground=native.get_node("BloodGulchGroundCollision")
 check(ground.get_meta("halo_ground_model")==model and ground.get_meta("halo_material")=="leaves","Native ground exposes direct Halo grass/road impact classification")
 check(native.get_node_or_null("BloodGulchCliffCollision")!=null,"Native cliffs have static physical boundaries")
 await physics_frame;await physics_frame
 var excluded:Array[RID]=[]
 for body in world.find_children("*","CollisionObject3D",true,false):
  if body!=ground:excluded.append(body.get_rid())
 var agrees=true;var covered_samples=0
 for point in [Vector2.ZERO,Vector2(30,30),Vector2(-30,-30),Vector2(0,96),Vector2(96,0),Vector2(0,-96),Vector2(-96,0),Vector2(96,96),Vector2(-96,-96)]:
  var query=PhysicsRayQueryParameters3D.create(Vector3(point.x,180,point.y),Vector3(point.x,-100,point.y),1,excluded)
  var hit=world.get_world_3d().direct_space_state.intersect_ray(query)
  if model.terrain.contains(point.x,point.y):
   covered_samples+=1
   if hit.is_empty() or hit.collider!=ground or absf(hit.position.y-model.surface_height(point.x,point.y))>.025:agrees=false
  # Partial native boundary triangles may cap the edge without becoming
  # navigable cells. Their geometry/coverage is checked by the bake tests.
 check(agrees and covered_samples>=6,"Physical native ground agrees with covered navigation heights on pad and approaches")
 for i in 3:model.revision+=1;world.sync(0)
 check(environment.environment==daytime and world.map_features.get_node("BloodGulchTerrain")==native,"Ordinary updates retain native terrain and environment identities")
 model.hero_position=Vector3(12,0,18);model.phase="wave";world.sync(.3)
 check(materials.all(func(mat):return mat.get_shader_parameter("hero_position")==Vector2(12,18) and mat.get_shader_parameter("show_grid")==false),"Native terrain follows hero visibility and hides preparation grid in combat")
 # Full map change must drop the native mesh/material bindings and restore the older atmosphere.
 doc.load_four_gates();model.reset(42,{},doc.data);model.workers.clear();world.reload_map();await process_frame
 check(world.map_features.get_node_or_null("BloodGulchTerrain")==null and world.base_ground.visible and world.base_ground_collision.collision_layer==1,"Legacy map restores its original physical and visual base")
 check(world.blood_gulch_materials.is_empty() and environment.environment.background_mode==Environment.BG_COLOR,"Legacy map releases native materials and restores legacy atmosphere")
 model.reset(42,{},native_layout);model.workers.clear();world.reload_map();await process_frame
 check(world.map_features.get_node_or_null("BloodGulchTerrain")!=null and environment.environment.background_mode==Environment.BG_SKY,"Returning to native map restores its sky and terrain")
 world.set_painterly_preview(false);world.set_painterly_preview(true)
 check(environment.environment.background_mode==Environment.BG_SKY,"Native map stays bright after both painterly toggle directions")
 world.queue_free();await process_frame
 print("BLOOD_GULCH_WORLD_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
