extends SceneTree
## Render the real Explore world; review positions must already be walkable.
const Tour=preload("res://scripts/forest/forest_falan_tour.gd")
const Civic=preload("res://scripts/forest/forest_falan_civic_exterior.gd")
const Street=preload("res://scripts/forest/forest_falan_street_details.gd")
const Fit=Civic.Proportions
const OUT="res://build/Other Files/Asset Toolkit/Explore Visual Match/"
var game
var failures=0

func _initialize():
 create_timer(180).timeout.connect(func():printerr("EXPLORE_VISUAL_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 var phase="After"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--stage="):phase=argument.trim_prefix("--stage=")
 var output=OUT+phase+"/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-explore-visual-review.cfg"
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false
 game.equipment_hub.enter_button.pressed.emit()
 for i in 6:await physics_frame
 game.explorer_clock.load_hour(12.0);game.explorer_clock.update_lighting()
 game.camera_rig.set_process(false)
 game.camera_rig.set_process_unhandled_input(false)
 game.set_process(false)
 game.ui.hide()
 var report={"area":Tour.area(game.model),"floor":game.model.falan_floor,"views":[],"obstacles":{},"links":[]}
 for anchor in game.model.scenery_obstacles:
  report.obstacles[str(anchor)]=str(game.model.scenery_obstacles[anchor])
 for link in game.model.get_meta("falan_links",[]):report.links.append(str(link))
 var office=game.world.find_child("FalanCivicFacade_1091",true,false)
 assert(office!=null,"The existing city must contain its office")
 report.office_bounds=str(Fit.projected_bounds(Fit.node_points(office)))
 print("OFFICE_VISUAL_BOUNDS ",report.office_bounds," native=",Fit.References.RECTS.civic_1091)
 var lower=office.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.get_meta("falan_source_feature","") in ["office_lower_front","office_lower_side"])
 assert(lower.size()==6,"Only the six native source-visible lower panes are restored")
 for pane in lower:
  for corner in [Vector3(-.5,-.5,0),Vector3(.5,-.5,0)]:
   assert(pane.to_global(corner).y>=office.global_position.y,"Lower panes clear the unchanged ground plane")
 var laundry=game.world.find_children("RecoveredFalanStreetDetail11004_*","MeshInstance3D",true,false)
 assert(laundry.size()==2,"Both recorded city clotheslines are visible scenery")
 for node in laundry:
  assert(node.mesh==Street.prepare(11004),"Clotheslines share one prepared mesh")
  assert(node.mesh.get_aabb().position.y>=-.001,"Clothesline posts stand on their source ground")
 var camera:Camera3D=game.camera_rig.camera
 # Start plaza and its public side street; no camera/player position opens a route.
 for row in [["office-plaza",Vector2(-234,-108),Vector3(-220,18,-78),Vector3(-252,8,-116)],
             ["office-side",Vector2(-228,-132),Vector3(-215,22,-126),Vector3(-252,10,-135)]]:
  var at:Vector2=row[1]
  var clear=game.model.terrain.disk_clear(game.model.world_point(at,.15)/game.model.falan_scale,.55)
  if not clear:failures+=1;printerr("EXPLORE_VISUAL_FAIL inaccessible viewpoint ",row[0]);continue
  game.player.position=game.model.world_point(at,.15);game.player.velocity=Vector3.ZERO
  camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=65
  camera.global_position=row[2]*game.model.falan_scale;camera.look_at(row[3]*game.model.falan_scale)
  await shot(output+row[0]+".png")
  report.views.append({"name":row[0],"route_position":str(at),"walkable":clear,"eye":str(row[2]),"target":str(row[3])})
 # Same source pixel scale and camera as the archived native-office reference.
 var rect:Rect2=Fit.References.RECTS.civic_1091
 var center=rect.get_center()
 var at=Vector3((center.x/Fit.HORIZONTAL+center.y/Fit.FLOOR)*.5,0,(center.y/Fit.FLOOR-center.x/Fit.HORIZONTAL)*.5)+office.position
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.keep_aspect=Camera3D.KEEP_HEIGHT
 camera.size=900.0/(sqrt(2.0)*Fit.HORIZONTAL)*game.model.falan_scale
 camera.global_position=(at+Vector3(100,100*sqrt(2.0)*tan(asin(.75)),100))*game.model.falan_scale
 camera.look_at(at*game.model.falan_scale)
 await shot(output+"office-matched-city.png")
 var bodies=office.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.get_meta("office_source_body",false))
 assert(bodies.size()==1,"One solid owner builds the native office body")
 var ground_pixels=[]
 var body:MeshInstance3D=bodies[0]
 for point:Vector3 in body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
  var world:Vector3=body.to_global(point)
  if absf(world.y-office.global_position.y)<.001:
   ground_pixels.append(camera.unproject_position(world)-Vector2(539.5,224))
 assert(ground_pixels.size()>=4,"The closed office body rests on the existing ground plane")
 report.office_caps=[]
 for batch in office.find_children("*","MultiMeshInstance3D",true,false):
  for i in batch.multimesh.instance_count:
   var pose:Transform3D=batch.multimesh.get_instance_transform(i)
   if pose.basis.get_scale().distance_to(Vector3(1.14,.77,1.14))>.001:continue
   var pixel=camera.unproject_position(batch.to_global(pose*Vector3(0,.5,0)))-Vector2(539.5,224)
   report.office_caps.append(str(pixel))
 assert(report.office_caps.size()==20,"The office retains its twenty measured native caps")
 report.source_frame={"office_transform":str(office.global_transform),"scale":game.model.falan_scale,"points":[]}
 for p in [Vector3(-8,14.53,-1.53),Vector3(7.8,14.53,-1.53),Vector3(-4.33,8.55,4.76),Vector3(2.36,8.55,4.76)]:
  var fitted:Vector3=Fit.Data.FITS.civic_1091*p
  var pixel:Vector2=camera.unproject_position(office.to_global(fitted))-Vector2(539.5,224)
  var expected:Vector2=Fit.project(fitted)-rect.position
  assert(pixel.distance_to(expected)<.01,"The city comparison uses the native source camera")
  report.source_frame.points.append({"local":str(p),"rendered":str(pixel),"expected":str(expected)})
  print("OFFICE_SOURCE_POINT ",p," rendered=",pixel," expected=",expected)
 var file=FileAccess.open(output+"review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("EXPLORE_VISUAL_RESULT failures=",failures," views=",report.views.size())
 game.queue_free();await process_frame;quit(1 if failures else 0)

func shot(path:String):
 game.camera_rig.camera.reset_physics_interpolation()
 for i in 6:await process_frame
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(path)==OK,"Save visual evidence")
