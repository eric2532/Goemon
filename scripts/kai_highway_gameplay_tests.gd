extends SceneTree
var game
var checks=0
var failures=0
var config_path="user://kai-highway-gameplay-%d.cfg"%OS.get_process_id()
const KAI_SHADER=preload("res://scripts/forest/kai_highway_surface.gdshader")
func _initialize():
 create_timer(90).timeout.connect(func():printerr("FAIL: Kai gameplay timeout");quit(1))
 run.call_deferred()
func frames(count:int=3):
 for i in count:await process_frame
func check(ok:bool,note:String):
 checks+=1;print("PASS: " if ok else "FAIL: ",note)
 if not ok:failures+=1
func ray_floor(x:float,z:float)->Dictionary:
 var query=PhysicsRayQueryParameters3D.create(Vector3(x,70,z),Vector3(x,-4,z),1)
 return game.world.get_world_3d().direct_space_state.intersect_ray(query)
func collision_matches(point:Vector2)->bool:
 var hit=ray_floor(point.x,point.y)
 return not hit.is_empty() and absf(hit.position.y-game.model.surface_height(point.x,point.y))<.025
func capture(label_:String):
 if "--visual" not in OS.get_cmdline_user_args():return
 var folder=OS.get_environment("SONIC_KAI_CAPTURE_DIR")
 if folder.is_empty():folder="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Kai Highway Castle"
 DirAccess.make_dir_recursive_absolute(folder)
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(folder.path_join(label_+".png"))==OK,"Native Kai capture "+label_)
func run():
 if has_meta("forest_custom_layout"):remove_meta("forest_custom_layout")
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
 await frames();await physics_frame
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 check(game.model.terrain_source=="kai_highway" and game.model.has_elevation(),"A fresh run selects Kai terrain without custom map metadata")
 check(not game.world.base_ground.visible and game.world.base_ground_collision.collision_layer==0,"Kai hides and disables the flat base floor")
 var terrain=game.world.map_features.get_node_or_null("KaiHighwayTerrain")
 check(terrain!=null and terrain.get_node_or_null("KaiTerrainCollision") is StaticBody3D,"The visible Kai terrain has its own native collision body")
 if terrain==null:await finish();return
 for point in [Vector2(0,90),Vector2(0,120),Vector2(72,-150),Vector2(-120,0),Vector2(144,72),Vector2(-120,-174)]:
  check(collision_matches(point),"Physical terrain agrees with the model on road/raised surface "+str(point))
 check(game.model.surface_height(0,120)>4 and game.model.surface_height(-120,-174)>8,"Collision samples include the inclined road and original raised terraces")
 var boundary=ray_floor(-204,-204)
 check(not boundary.is_empty() and boundary.collider==terrain.get_node("KaiTerrainCollision"),"Kai boundary collision comes from its native terrain body")
 check(game.world.portal_nodes.size()==8,"All eight spawn portals exist in the physical scene")
 for index in mini(8,game.world.portal_nodes.size()):
  var portal=game.model.portals[index];var node=game.world.portal_nodes[index]
  var expected=game.model.point(Vector2i(portal.x,portal.z))
  check(node.visible and node.position.distance_to(expected)<.001 and is_equal_approx(node.rotation.y,-int(portal.rotation)*PI*.5) and collision_matches(Vector2(expected.x,expected.z)),"Portal %d sits on its own supported Kai surface and faces its authored exit"%index)
 await capture("kai-gameplay-overview")
 await painterly_checks()
 await preset_checks()
 await movement_checks()
 await finish()
func painterly_checks():
 game.world.set_painterly_preview(false);await frames()
 var visual=game.world.map_features.get_node("KaiHighwayTerrain").get_child(0)
 var materials=[]
 for slot in visual.mesh.get_surface_count():materials.append(visual.get_surface_override_material(slot))
 var roads=game.world.map_features.get_node("RoadTiles");var road_material=roads.material_override
 check(not materials.is_empty() and materials.all(func(material):return material is ShaderMaterial and material.shader==KAI_SHADER),"Kai terrain uses its native textured surface materials")
 game.world.set_painterly_preview(true);await frames()
 check(game.world.painterly_pilot.enabled and is_instance_valid(game.world.painterly_pilot.scenery),"Painterly scenery is actually applied to the Kai world")
 var unchanged=true
 for slot in materials.size():
  if visual.get_surface_override_material(slot)!=materials[slot] or materials[slot].shader!=KAI_SHADER:unchanged=false
 check(unchanged and roads.material_override==road_material and road_material.shader==KAI_SHADER,"Painterly apply preserves native Kai terrain and road materials")
 check(collision_matches(Vector2(0,120)),"Painterly apply preserves native incline collision")
func preset_checks():
 var document=load("res://scripts/forest/forest_map_document.gd").new()
 check(document.load_original().is_empty(),"Protected Original Map remains available")
 game.preview_forest_map(document.data);await frames();await physics_frame
 check(game.model.terrain_source.is_empty() and game.world.base_ground.visible and game.world.base_ground_collision.collision_layer==1,"Reloading Original Map restores its visible and solid flat floor")
 var hit=ray_floor(-204,-204)
 check(game.world.map_features.get_node_or_null("KaiHighwayTerrain")==null and not hit.is_empty() and hit.collider==game.world.base_ground_collision and absf(hit.position.y)<.001,"Original Map removes Kai collision and restores flat ground at the old cutout")
 check(document.load_kai_highway().is_empty(),"Kai Highway Castle remains available after the flat preset")
 game.preview_forest_map(document.data);await frames();await physics_frame
 check(game.model.terrain_source=="kai_highway" and not game.world.base_ground.visible and game.world.base_ground_collision.collision_layer==0,"Restoring Kai disables the flat floor again")
 hit=ray_floor(-204,-204)
 check(collision_matches(Vector2(0,120)) and not hit.is_empty() and hit.collider==game.world.map_features.get_node("KaiHighwayTerrain/KaiTerrainCollision"),"Restored Kai uses its own elevated and boundary collision")
func movement_checks():
 game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
 game.player.select_character(5);game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO;game.tuning.invincible=true;game.camera_rig.yaw=0
 game.player.position=Vector3(0,.1,72);game.player.velocity=Vector3.ZERO
 var controller=game.player.active_ability;controller.reset_run();controller.player.pos=game.player.position
 await physics_frame
 for i in 30:controller.physics_step(1.0/60)
 check(game.player.is_on_floor() and absf(game.player.position.y)<.12,"The actual Ninja controller settles on the low road approach")
 game.player.smoke_move=Vector2(0,1)
 var maximum_error=0.0;var grounded_steps=0;var steps=0
 for i in 900:
  controller.physics_step(1.0/60);steps+=1
  maximum_error=maxf(maximum_error,absf(game.player.position.y-game.model.surface_height(game.player.position.x,game.player.position.z)))
  if game.player.is_on_floor():grounded_steps+=1
  if game.player.position.z>=120:break
 game.player.smoke_move=Vector2.ZERO
 check(game.player.position.z>=120 and game.player.position.y>4 and absf(game.player.position.x)<.2,"Ninja walks uphill through native collision to the raised road ("+str(game.player.position)+")")
 check(maximum_error<.15 and grounded_steps>=steps*.9,"Uphill controller movement stays supported by the same continuous terrain")
 for i in 30:controller.physics_step(1.0/60)
 var origin=game.player.position;var peak=origin.y;var airborne=false;var landed=false
 var jump=InputEventAction.new();jump.action="jump";jump.pressed=true;controller.input(jump);jump.pressed=false;controller.input(jump)
 for i in 240:
  controller.physics_step(1.0/60);peak=maxf(peak,game.player.position.y)
  if not game.player.is_on_floor():airborne=true
  if airborne and game.player.is_on_floor():landed=true;break
 check(airborne and peak-origin.y>1 and landed,"Controller jump leaves the inclined road and lands again")
 check(landed and absf(game.player.position.y-game.model.surface_height(game.player.position.x,game.player.position.z))<.15 and Vector2(game.player.position.x-origin.x,game.player.position.z-origin.z).length()<.25,"Jump landing returns to the same native road surface")
 game.camera_rig.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;game.camera_rig.camera.position=Vector3(26,22,103);game.camera_rig.camera.look_at(game.player.position+Vector3.UP*3)
 await capture("kai-gameplay-incline")
func finish():
 if is_instance_valid(game):
  game.player.smoke_move=Vector2.ZERO
  if is_instance_valid(game.player.active_ability):game.player.active_ability.cancel()
  game.sound_library.cancel();game.music.stop()
  for voice in game.voices:voice.stop()
  game.queue_free();game=null
 paused=false;await frames(8);await create_timer(.35).timeout
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 if has_meta("forest_custom_layout"):remove_meta("forest_custom_layout")
 print("KAI_HIGHWAY_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
