extends "res://tests/forest-shrine/elsa_second_stair_review.gd"
## Raw candidate heights use the existing model/native/physical owner.
const Steps=preload("res://scripts/forest/forest_elsa_hall_steps.gd")
var support_peak=0.
var support_foot_error=0.
var visible_triangles=PackedVector3Array()
var visible_float=0.
var visible_sink=0.
var worst_visible_source=Vector2.INF
var stair_node_name="ElsaPrivateSecondStair"

func verify_return_scene():
 pass

func visible_height(at:Vector2)->float:
 var result=-INF
 for i in range(0,visible_triangles.size(),3):
  var a=visible_triangles[i];var b=visible_triangles[i+1];var c=visible_triangles[i+2]
  var denominator=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
  if absf(denominator)<.0000001:continue
  var u=((b.z-c.z)*(at.x-c.x)+(c.x-b.x)*(at.y-c.z))/denominator
  var v=((c.z-a.z)*(at.x-c.x)+(a.x-c.x)*(at.y-c.z))/denominator
  if minf(u,minf(v,1.-u-v))>=-.00001:result=maxf(result,u*a.y+v*b.y+(1.-u-v)*c.y)
 return result

func walk_to(at:Vector2,floor_:int=59530)->bool:
 var cell=Vector2i(at.round());var state=Original.state(floor_)
 var open=Original.open(state.bits,state.size,cell) and Elsa.owned_cell(floor_,cell)
 check(open,"Stair approach stays on archived open ground "+str(at))
 if not open:return false
 var target:Vector3=game.model.world_point(Original.source_point(floor_,Vector2i.ZERO)+at*3.)
 check(game.army_runtime.native.can_reach(game.player.position,target,.45),"Native route reaches original stair waypoint "+str(cell))
 for i in 240:
  var offset=target-game.player.position
  if Vector2(offset.x,offset.z).length()<.3:break
  for pair in [["move_right",offset.x],["move_left",-offset.x],["move_back",offset.z],["move_forward",-offset.z]]:
   if float(pair[1])>.12:Input.action_press(pair[0])
   else:Input.action_release(pair[0])
  await physics_frame
  support_peak=maxf(support_peak,game.player.position.y)
  if game.player.is_on_floor():
   support_foot_error=maxf(support_foot_error,absf(game.player.position.y-game.model.world_height(game.player.position.x,game.player.position.z)))
   if game.model.falan_floor==59530:
    var surface=visible_height(Vector2(game.player.position.x,game.player.position.z))
    if is_finite(surface):
     var gap=game.player.position.y-surface
     if absf(gap)>maxf(visible_float,visible_sink):worst_visible_source=(Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale-Original.source_point(59530,Vector2i.ZERO))/3.
     visible_float=maxf(visible_float,gap);visible_sink=maxf(visible_sink,-gap)
 for action in ["move_right","move_left","move_back","move_forward"]:Input.action_release(action)
 var reached=Vector2(game.player.position.x-target.x,game.player.position.z-target.z).length()<.7
 check(reached,"Normal controls reach source stair waypoint "+str(cell))
 print("ELSA_SECOND_STAIR_WALK source=",at," cell=",cell," reached=",reached," position=",game.player.position," target=",target," peak=",support_peak)
 return reached

func _initialize():
 super._initialize()
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SECOND_FOLDER+"support-data.json"))
 assert(data.candidate_only and data.steps.external_visual)
 Steps.records[59530]=data

func run():
 await setup_review_game()
 var saved=FileAccess.get_file_as_bytes(game.settings_path) if FileAccess.file_exists(game.settings_path) else PackedByteArray()
 var state:Dictionary=Original.state(59530);var bits:PackedByteArray=state.bits.duplicate()
 var start=Original.source_point(59530,Vector2i(88,106))
 Tour.travel(game,Original.layout(59530),{"arrival":start,"yaw":0.,"velocity":Vector3.ZERO})
 for i in 10:await physics_frame
 prepare_review_point({"map":59530,"cell":[88,106],"label":"second-stair-support"})
 var stair=game.world.find_child(stair_node_name,true,false)
 var names:Array=stair.mesh.get_meta("source_paint_names");var arrays:Array=stair.mesh.get_meta("source_all_surface_arrays")
 for p in arrays[names.find("native")][Mesh.ARRAY_VERTEX]:visible_triangles.append(stair.global_transform*p)
 var nav:Dictionary=game.army_runtime.navigation_data(game.model,false);var scale_:float=game.model.falan_scale
 for cell in [Vector2i(88,106),Vector2i(90,106),Vector2i(91,105),Vector2i(92,105),Vector2i(93,105),Vector2i(94,104)]:
  var at=Original.source_point(59530,cell);var position:Vector3=game.model.world_point(at)
  check(Original.open(bits,state.size,cell) and Elsa.owned_cell(59530,cell),"Support probe belongs to original open source ground "+str(cell))
  var ray=PhysicsRayQueryParameters3D.create(position+Vector3.UP*2.,position-Vector3.UP*2.,1)
  var hit=game.world.get_world_3d().direct_space_state.intersect_ray(ray)
  check(not hit.is_empty() and absf(hit.position.y-position.y)<.02,"Physical/model height agree "+str(cell))
  var index=Vector2i(((Vector2(position.x,position.z)-Vector2(nav.origin.x,nav.origin.z))/nav.spacing).round())
  check(absf(nav.heights[index.y*nav.width+index.x]-position.y)<.0002,"Native/model height agree "+str(cell))
 var visited:Array[Vector2]=[Vector2(88,106)];var path:Array[Vector2]=[]
 for face in second_spec.surfaces:
  if face.role!="lower original tread":continue
  var center=Vector2.ZERO
  for p in face.points:center+=Vector2(p[0],p[2])
  path.append(center/(face.points.size()*3.))
 path.reverse();path.append(Vector2(93.25,104.75));path.append(Vector2(94,104))
 game.camera_rig.yaw=0.
 for at in path:
  if not await walk_to(at):break
  visited.append(at)
 for i in 4:await process_frame
 root.get_texture().get_image().save_png(capture_output+"second-stair-support-peak.png")
 check(visited.size()==path.size()+1,"Actual controls cover the source tread centres and door approach")
 for i in range(visited.size()-2,-1,-1):
  if not await walk_to(visited[i]):break
 if worst_visible_source.is_finite():
  var review_at=worst_visible_source
  if await walk_to(review_at):
   game.camera_rig.yaw=-PI*.5;game.camera_rig.pitch=.22;game.camera_rig.distance=12.;game.camera_rig.reset_follow()
   for i in 8:await process_frame
   for i in 2:await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(capture_output+"second-stair-visible-foot-contact.png")
   print("ELSA_SECOND_STAIR_VISIBLE_FOOT source=",review_at," float=",visible_float," sink=",visible_sink," camera_distance=",game.camera_rig.current_distance)
   game.camera_rig.yaw=0.;game.camera_rig.reset_follow()
   await walk_to(Vector2(88,106))
 check(support_peak>2.*scale_ and support_foot_error<.25,"Ascent/descent have height and stable ground contact")
 check(state.bits==bits and game.model.falan_floor==59530,"Support preserves the source map and every blocked/open bit")
 check(game.army_runtime.handles.is_empty(),"Temple remains safe")
 if visited.size()==path.size()+1:
  var reached=true
  for at in path:
   if not await walk_to(at):reached=false;break
  if reached:
   Input.action_press("move_right")
   for i in 240:
    await physics_frame
    if game.model.falan_floor!=59530:break
   Input.action_release("move_right")
   check(game.model.falan_floor==59534,"Normal stair-head crossing enters59534 through the original95,104 tile")
   if game.model.falan_floor==59534:
    var expected=Original.source_point(59534,Vector2i(30,39))
    check((Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale).distance_to(expected)<.6,"Stair-head door keeps59534 landing30,39")
    game.camera_rig.yaw=0.
    if await walk_to(Vector2(30,38),59534):
     Input.action_press("move_back")
     for i in 240:
      await physics_frame
      if game.model.falan_floor!=59534:break
     Input.action_release("move_back")
     check(game.model.falan_floor==59530,"The room's original exit returns to the temple")
     if game.model.falan_floor==59530:
      expected=Original.source_point(59530,Vector2i(95,80))
      check((Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale).distance_to(expected)<.6,"Asymmetric source exit preserves temple95,80, not a substituted stair-foot landing")
  print("ELSA_SECOND_STAIR_DOOR floor=",game.model.falan_floor," position=",game.player.position)
  verify_return_scene()
 if not saved.is_empty():check(FileAccess.get_file_as_bytes(game.settings_path)==saved,"Stair walking/crossings preserve saved home/login/preferences bytes")
 print("ELSA_SECOND_STAIR_SUPPORT_RESULT checks=",checks," failures=",failures," visited=",visited," peak=",support_peak," foot_error=",support_foot_error," visible_float=",visible_float," visible_sink=",visible_sink)
 await finish()
