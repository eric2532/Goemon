extends "res://tests/forest-shrine/black_prayer_source_route_review.gd"
## Focused source completion/fixture review; quest/native owners are unchanged.
const Fixtures=preload("res://scripts/forest/forest_black_prayer_room_fixtures.gd")
const GEO_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Black Prayer source route/Room geometry/"
var geometry_report={"maps":[],"fixtures":[],"cameras":[],"limits":["Hidden depth/reverse faces reuse compatible solid masters and original paint; source2D bounds do not certify original3D geometry.","Direct source/contact stations are fixtures, not a complete outdoor quest traversal."]}
func _initialize():
 create_timer(900).timeout.connect(func():printerr("BLACK_PRAYER_GEOMETRY_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GEO_OUT))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-prayer-geometry-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false);game.player.set_auto_attack(false)
 var saved=JSON.stringify(get_meta("falan_venture"))
 var rooms_only="--rooms-only" in OS.get_cmdline_user_args()
 if not rooms_only:
  print("BLACK_PRAYER_GEOMETRY_BEGIN")
  await visit_source(16508,Vector2i(3,25));clear_enemies()
  var pre:Dictionary=Quest.data().pre;var raw=Marshalls.base64_to_raw(pre.raw).decompress(15020,FileAccess.COMPRESSION_DEFLATE)
  var before=Tour.Indoor.Freyja.ROOMS[16508][2].hex_decode();var bits=pre.walk.hex_decode();var added=[]
  for i in 2500:
   if not(bits[i>>3]&(1<<(i&7))) or before[i>>3]&(1<<(i&7)):continue
   var cell=Vector2i(i%50,i/50);added.append([cell.x,cell.y])
   var at=game.model.world_point(source_point(cell),.15)
   check(game.army_runtime.native.can_reach(at,at,.25),"Native support reaches recovered source cell "+str(cell))
  check(added.size()==68,"Exactly68source-open cells are newly reachable in16508")
  check(game.army_runtime.native.can_reach(game.model.world_point(source_point(Vector2i(3,17)),.15),game.model.world_point(source_point(Vector2i(3,40)),.15),.4),"Western source corridor is connected under existing native navigation")
  var pose=game.player.global_transform;pose.origin=game.model.world_point(source_point(Vector2i(3,25)),.32)
  check(game.player.test_move(pose,game.model.world_point(source_point(Vector2i(2,25)),.32)-pose.origin),"Original source west wall still blocks movement beyond recovered corridor")
  var start=source_cell();game.camera_rig.yaw=0.;game.camera_rig.update_camera(0.,true)
  game.set_physics_process(true);game.player.set_physics_process(true)
  var replay_frames=0;var reassertions=0
  Input.action_press("move_forward")
  for i in 300:
   if not Input.is_action_pressed("move_forward"):reassertions+=1;Input.action_press("move_forward")
   await physics_frame;replay_frames=i+1
   if source_cell().y<=20:break
  Input.action_release("move_forward")
  for i in 4:await physics_frame
  game.set_physics_process(false);game.player.set_physics_process(false)
  var finish=source_cell()
  check(start.x==3 and finish.x in [3,4] and finish.y<=20,"Replayed ordinary forward input walks along recovered16508ground without movement teleport")
  print("BLACK_PRAYER_GEOMETRY_WEST_MOVEMENT ",start," -> ",finish)
  geometry_report.maps.append({"id":16508,"client_sha256":pre.client_raw_sha256,"hybrid_sha256":pre.raw_sha256,"server_sha256":pre.server_provenance.sha256,"completion":pre.completion,"walk_preservation":pre.walk_preservation,"added_open":added,"movement":{"kind":"held action replay each physics frame","start":str(start),"finish":str(finish),"frames":replay_frames,"reassertions":reassertions}})
  await geometry_camera("16508-west-normal",Vector2i(3,25))
  await geometry_camera("16508-court-normal",Vector2i(24,22))
  # Actual StandEnemy F still owns the original mandatory party after the layout fill.
  await interact_source("81000",[]);await ruby_party(0)
  check(game.model.falan_floor==16509 and source_cell()==Vector2i(24,12),"Unchanged original native victory still reaches16509(24,12)")
 for id:int in [3354,5011]:
  await visit_source(id,Vector2i(10,10) if id==3354 else Vector2i(8,7))
  check(game.exploration_loot.slots.all(func(slot):return not slot.active or not slot.chest),"Source room still has no unsupported ambient chest "+str(id))
  var actual={}
  for node in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
   var mesh=node.multimesh.mesh
   if not mesh.has_meta("black_prayer_source_fixture"):continue
   var serial=int(mesh.get_meta("black_prayer_source_fixture"));var record:Dictionary=Quest.data().room_fixtures.graphics[str(serial)]
   var points:Array[Vector3]=[]
   if mesh.has_meta("east_cpu_arrays"):
    for arrays:Array in mesh.get_meta("east_cpu_arrays"):points.append_array(arrays[Mesh.ARRAY_VERTEX])
   else:points=Fixtures.Fit.mesh_points(mesh)
   var frame=Transform3D(Basis.IDENTITY.scaled(Vector3(1.,1./Fixtures.East.OWNER_Y_SCALE,1.)),Vector3.ZERO)
   var target:Rect2=mesh.get_meta("source_bounds")
   var measured=Fixtures.Fit.projected_bounds(points,Transform3D(Basis(Vector3.UP,PI*.5),Vector3.ZERO)*frame)
   check(measured.position.distance_to(target.position)<.05 and measured.size.distance_to(target.size)<.05,"Solid fixture fits measured original source bounds "+str(serial))
   check(mesh.get_meta("source_rgba_sha256")==record.source_rgba_sha256,"Fixture retains exact original source paint identity "+str(serial))
   actual[str(serial)]=actual.get(str(serial),0)+node.multimesh.instance_count
  var path=Tour.Indoor.Original.path_for(id);var row:Dictionary=Tour.Indoor.Original.Art.data().maps[path]
  var original=Marshalls.base64_to_raw(row.raw).decompress(int(row.bytes),FileAccess.COMPRESSION_DEFLATE)
  var width=int(row.size[0]);var cells=width*int(row.size[1]);var expected={}
  for i in cells:
   var serial=original.decode_u16(20+(cells+i)*2)
   if Fixtures.owns(id,serial):expected[str(serial)]=expected.get(str(serial),0)+1
  check(actual==expected,"Every scoped source fixture appears once at each original anchor "+str(id))
  print("BLACK_PRAYER_GEOMETRY_ROOM ",id," source_anchors=",expected," actual=",actual)
  geometry_report.fixtures.append({"map":id,"actual":actual,"expected":expected,"client_sha256":row.sha256,"raw_unchanged":Tour.Indoor.Original.state(id).raw==original})
  check(Tour.Indoor.Original.state(id).raw==original,"Room geometry changes no original layout/cache byte "+str(id))
  await geometry_camera(str(id)+"-normal",Vector2i(10,10) if id==3354 else Vector2i(8,7))
  await geometry_camera(str(id)+"-fixtures-normal",Vector2i(12,7) if id==3354 else Vector2i(7,6))
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Source geometry/native review preserves saved adventure state")
 geometry_report.checks=checks;geometry_report.failures=errors;geometry_report.source_events_sha256=FileAccess.get_sha256(Quest.ROOT+"data.json")
 geometry_report.actor_bank={"motions_sha256":FileAccess.get_sha256(Ruby.ROOT+"motions.json"),"blade_source_key":"original:2913"}
 geometry_report.battles=route_report.battles;geometry_report.cameras=route_report.cameras;geometry_report.normal_scenery_views=route_report.cameras.filter(func(row):return row.name.begins_with("geometry-")).size();geometry_report.fight_views=route_report.cameras.filter(func(row):return not row.name.begins_with("geometry-")).size();geometry_report.goal_complete=false
 var mode="headless" if DisplayServer.get_name()=="headless" else "rendered"
 var file=FileAccess.open(GEO_OUT+("rooms-only-" if rooms_only else "")+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(geometry_report,"  "));file.close()
 print("BLACK_PRAYER_GEOMETRY_RESULT checks=",checks," failures=",errors," cameras=",geometry_report.cameras.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
func geometry_camera(label_:String,cell:Vector2i):
 await route_camera("geometry-"+label_,cell)
func route_camera(label_:String,cell:Vector2i):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.presentation_events.clear();game.crowd.army.presentation.clear()
 if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.clear()
 prayer_camera_position(game.model.world_point(source_point(cell),.15))
 if label_.ends_with("fixtures-normal"):
  game.camera_rig.yaw=-PI*.25
  game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(0.,true)
 game.army_runtime.sync_compatibility();game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 for i in 4:await process_frame
 var camera:Camera3D=game.camera_rig.camera;check(is_equal_approx(camera.fov,63.),"Normal63degree source geometry camera "+label_)
 RenderingServer.force_draw();var shot=root.get_texture().get_image();check(capture_ready(shot),"Nonblank source geometry view "+label_)
 shot.save_png(GEO_OUT+label_+".png")
 route_report.cameras.append({"name":label_,"source_floor":game.model.falan_floor,"cell":[cell.x,cell.y],"eye":var_to_str(camera.global_position),"rotation":var_to_str(camera.global_rotation),"fov":camera.fov,"seed":game.model.seed_value})
