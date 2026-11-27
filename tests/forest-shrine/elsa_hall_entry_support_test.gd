extends "res://tests/forest-shrine/elsa_hall_entry_review.gd"
## Candidate-only entry, shared ground contact and normal stair controls.

func run():
 if not initialized:printerr("ELSA_HALL_ENTRY_INIT_FAILED");quit(1);return
 await setup_review_game()
 var state:Dictionary=Original.state(59530);var bits:PackedByteArray=state.bits.duplicate()
 var arrival=Original.source_point(59530,Vector2i(59,93))
 Tour.travel(game,Original.layout(59520),{"arrival":Original.source_point(59520,Vector2i(200,94)),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 8:await physics_frame
 game.camera_rig.yaw=0.;Input.action_press("move_back")
 for i in 180:
  await physics_frame
  if game.model.falan_floor==59530:break
 Input.action_release("move_back")
 for i in 12:await physics_frame
 check(game.model.falan_floor==59530,"Normal on-foot temple entrance reaches its source map")
 if game.model.falan_floor!=59530:await finish();return
 var landed=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
 check(landed.distance_to(arrival)<.6,"The original doorway still lands at59,93")
 check(Steps.height(arrival.x,arrival.y,59530)<-5.,"The exact return event meets the inferred lower support")
 var nav:Dictionary=game.army_runtime.navigation_data(game.model,false);var scale_:float=game.model.falan_scale
 check(absf(nav.spacing-1.5*scale_)<.0001,"Native movement uses the same local height grid")
 var samples=0
 for cell in [Vector2i(59,93),Vector2i(60,92),Vector2i(62,93),Vector2i(65,93),Vector2i(69,92),Vector2i(65,99)]:
  check(Original.open(bits,state.size,cell),"Support probe stays on original open ground "+str(cell))
  var at=Original.source_point(59530,cell);var position:Vector3=game.model.world_point(at)
  var query=PhysicsRayQueryParameters3D.create(position+Vector3.UP*8.,position-Vector3.UP*2.,1)
  var hit=game.world.get_world_3d().direct_space_state.intersect_ray(query)
  check(not hit.is_empty() and absf(hit.position.y-position.y)<.02,"Physical support agrees with actor height "+str(cell))
  var index=Vector2i(((Vector2(position.x,position.z)-Vector2(nav.origin.x,nav.origin.z))/nav.spacing).round())
  check(absf(nav.heights[index.y*nav.width+index.x]-position.y)<.0002,"Native height agrees with physical support "+str(cell));samples+=1
 for at in [arrival,Original.source_point(59530,Vector2i(65,93))]:
  game.player.position=game.model.world_point(at,1.);game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
  for i in 45:await physics_frame
  check(game.player.is_on_floor(),"The actual player lands on signed stair support "+str(at))
  check(absf(game.player.position.y-game.model.world_height(game.player.position.x,game.player.position.z))<.16,"Player feet remain aligned with native ground "+str(at))
  print("ELSA_HALL_ENTRY_FOOT at=",at," actual=",game.player.position," expected_y=",game.model.world_height(game.player.position.x,game.player.position.z))
 game.player.position=game.model.world_point(arrival,.1);game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation();game.camera_rig.yaw=0.
 var upper=Original.source_point(59530,Vector2i(69,93))
 check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(upper),.45),"Native navigation crosses the original stair approach")
 var minimum=INF;var maximum=-INF;var foot_error=0.
 for leg in [["move_right",upper.x],["move_left",arrival.x]]:
  var target=float(leg[1])*scale_;Input.action_press(leg[0])
  for i in 700:
   await physics_frame
   minimum=minf(minimum,game.player.position.y);maximum=maxf(maximum,game.player.position.y)
   if game.player.is_on_floor():foot_error=maxf(foot_error,absf(game.player.position.y-game.model.world_height(game.player.position.x,game.player.position.z)))
   if absf(game.player.position.x-target)<.35:break
  Input.action_release(leg[0])
  print("ELSA_HALL_ENTRY_WALK ",leg[0]," map=",game.model.falan_floor," position=",game.player.position," target_x=",target)
  check(absf(game.player.position.x-target)<.7,"Normal movement crosses the stairs "+str(leg[0]))
 check(maximum-minimum>4.*scale_ and foot_error<.25,"The climb has real height and consistent foot contact")
 check(game.model.falan_floor==59530 and state.bits==bits,"Walking preserves the map and every original walkability bit")
 check(game.army_runtime.handles.is_empty(),"The temple remains a safe area")
 for i in 8:await physics_frame
 check(Elsa.open(game),"The original return event uses normal Explore interaction at59,93")
 if is_instance_valid(game.dialogue):
  var choices:Array=game.dialogue.pages[game.dialogue.page].options
  var links:Array=game.model.get_meta("falan_links",[]).filter(func(link):return link.at==arrival and link.get("floor",0)==59520)
  check(links.size()==1,"The return event retains its original source link")
  if links.size()==1:
   var selected=choices.filter(func(option):return str(option[0])=="travel")
   check(selected.size()==1,"Normal return menu identifies the island landing")
   if selected.size()==1:game.dialogue.chosen.emit(str(selected[0][0]))
  for i in 8:await physics_frame
  check(game.model.falan_floor==59520,"The original stone returns to the island")
  var expected=Original.source_point(59520,Vector2i(200,96))
  var actual=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
  check(actual.distance_to(expected)<.6,"Temple return keeps island landing200,96")
 print("ELSA_HALL_ENTRY_SUPPORT_RESULT samples=",samples," checks=",checks," failures=",failures," foot_error=",foot_error)
 await finish()
