extends SceneTree
## Actual map/physics/native navigation boundaries. Catches scenery-only scale,
## hidden distant actors, custom-map rewrites and lost scale on editor save/load.
var checks=0
var failures=0
func _initialize():
 create_timer(45).timeout.connect(func():printerr("FAIL: open battlefield timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new()
 check(doc.load_blood_gulch().is_empty(),"Expanded default map validates")
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{},doc.data);model.workers.clear()
 check(is_equal_approx(float(doc.data.get("terrain_scale",1.0)),1.2),"Default battlefield is stretched 20 percent horizontally")
 check(model.visible_at(Vector3(0,0,-180)) and model.explored_at(Vector3(0,0,-180)),"Distant battlefield actors and ground are visible from the start")
 model.update_vision(Vector3(0,0,180));model.update_vision(Vector3(0,0,-180))
 check(model.visible_at(Vector3(0,0,180)) and model.visible_at(Vector3(0,0,-180)),"Moving the hero never hides another side of the battlefield")
 check(model.placement_error("tower",Vector2i(15,2),0)!="Unexplored terrain","Unvisited terrain is no longer rejected for lack of scouting")
 check(model.waves.navigation.full_unseen(Vector3.ZERO,0),"Visible arrivals are not blocked by the former unseen-spawn requirement")
 var old=doc.data.duplicate(true);old.erase("terrain_scale")
 var legacy=load("res://scripts/forest/forest_model.gd").new();legacy.reset(42,{},old)
 check(is_equal_approx(model.terrain.spacing,3.6) and is_equal_approx(legacy.terrain.spacing,3.0),"Default uses stretched sampling while old custom maps retain original scale")
 check(model.enemy_grid.region==Rect2i(-48,-48,96,96) and legacy.enemy_grid.region==Rect2i(-40,-40,80,80),"Navigation expands with the battlefield and old map bounds stay unchanged")
 check(model.buildings[2].cell==legacy.buildings[2].cell and model.dimensions("gate",0)==Vector2i(2,1),"Castle and door footprints retain their existing size")
 check(model.enemy_grid.is_point_solid(Vector2i(46,46)) and model.waves.navigation.clearance_grid(0).is_point_solid(Vector2i(46,46)),"Expanded grid cells outside the canyon stay physically blocked")
 var captured=doc.data.duplicate(true);doc.capture(model)
 var restored=load("res://scripts/forest/forest_map_document.gd").new()
 check(restored.decode(doc.encode()).is_empty() and is_equal_approx(float(restored.data.get("terrain_scale",1.0)),1.2),"Editor capture/save/reload preserves the stretched map")
 var invalid=captured.duplicate(true);invalid.terrain_scale=0
 check(not restored.validate(invalid).is_empty(),"Invalid terrain scale is rejected before changing a map")
 var world=load("res://scripts/forest/forest_world.gd").new();world.model=model;world.painterly_preview_enabled=true;root.add_child(world);await process_frame
 var edge=Vector3(158,model.surface_height(158,234),234)
 var edge_to=edge
 check(model.terrain.disk_clear(edge,3.9) and model.waves.navigation.supported_corridor(edge,edge_to,3.9,.25).clear,"Native corridors accept supported actor footprints beyond the former boundary")
 var crowd=load("res://scripts/forest/forest_enemy_crowd.gd").new();crowd.game=world
 check(crowd._member_ground(edge,edge,3.9,model.terrain)!=null,"Legacy crowd bodies remain rendered on supported expanded-edge ground")
 crowd.free()
 var land=world.map_features.get_node("BloodGulchTerrain")
 check(land.scale.is_equal_approx(Vector3(1.2,1,1.2)),"Native grass and cliffs stretch horizontally while heights remain unchanged")
 var fog=world.fog_texture.get_image()
 check(fog.get_pixel(0,0).r>.99 and fog.get_pixel(0,0).g>.99 and fog.get_pixel(79,79).g>.99,"All shader visibility samples are fully revealed")
 var far=model.point(Vector2i(0,34));var native_data=load("res://scripts/forest/crowd/army_runtime.gd").navigation_data(model,false)
 check(native_data.origin.is_equal_approx(Vector3(-288,0,-288)) and is_equal_approx(native_data.spacing,3.6),"Native army navigation receives the same stretched origin and spacing")
 await physics_frame;await physics_frame
 var ground=land.get_node("BloodGulchGroundCollision");var ignored:Array[RID]=[]
 for body in world.find_children("*","CollisionObject3D",true,false):
  if body!=ground:ignored.append(body.get_rid())
 var agrees=true;var samples=0
 for p in [Vector2(36,36),Vector2(-36,-36),Vector2(0,115.2),Vector2(115.2,0),Vector2(-115.2,0),Vector2(0,-115.2)]:
  if not model.terrain.contains(p.x,p.y):continue
  samples+=1
  var ray=PhysicsRayQueryParameters3D.create(Vector3(p.x,160,p.y),Vector3(p.x,-100,p.y),1,ignored)
  var hit=world.get_world_3d().direct_space_state.intersect_ray(ray)
  if hit.is_empty() or absf(hit.position.y-model.surface_height(p.x,p.y))>.025:agrees=false
 check(samples>=4 and agrees,"Stretched collision and authoritative navigation heights agree on every sampled approach")
 check(world.portal_nodes.size()==8 and world.portal_nodes.all(func(p):return p.visible),"All eight Halo teleporters remain visible")
 world.queue_free();await process_frame
 print("OPEN_BATTLEFIELD_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
