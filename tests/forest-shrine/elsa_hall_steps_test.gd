extends "res://tests/forest-shrine/original_maps_test.gd"
## Local height agreement and real player support; fixed views judge the source paint.
const Steps=preload("res://scripts/forest/forest_elsa_hall_steps.gd")

func run():
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-elsa-steps.cfg"
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.explorer_clock.save_left=600.
 Tour.travel(game,Original.layout(59535),{"arrival":Original.source_point(59535,Vector2i(45,63)),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 6:await physics_frame
 for title in ["ElsaOriginal_inner-hall","ElsaOriginal_inner-hall-floor","ElsaOriginalCurvedTreads","ElsaOriginalRoomWalls"]:
  var node=game.world.map_features.find_child(title,true,false)
  if node is MeshInstance3D:print("ELSA_HALL_MESH ",title," surfaces=",node.mesh.get_surface_count()," triangles=",node.mesh.get_faces().size()/3)
 var centers=[]
 for tier in Steps.data().steps.tiers:
  var center=Vector3.ZERO;var outline:Array=tier.points+tier.back_points
  for point in outline:center+=Vector3(point[0],point[1],point[2])
  centers.append(center/outline.size())
 var faces=Steps.visual.get_faces();var risers=0;var outward=true
 for i in range(0,faces.size(),3):
  var a=faces[i];var b=faces[i+1];var c=faces[i+2];var high=maxf(a.y,maxf(b.y,c.y));var low=minf(a.y,minf(b.y,c.y))
  if high-low<.1:continue
  var center:Vector3=centers[clampi(roundi(high*2)-1,0,centers.size()-1)]
  outward=outward and (c-a).cross(b-a).normalized().dot((a+b+c)/3.-center)>0.;risers+=1
 check(risers>0 and outward,"All solid stair risers face outside their platform")
 var state=Original.state(59535);var original_bits:PackedByteArray=state.bits.duplicate()
 var nav:Dictionary=game.army_runtime.navigation_data(game.model,false);var grid:Dictionary=Steps.data().steps.grid;var scale_:float=game.model.falan_scale
 check(nav.spacing==grid.spacing*scale_,"Native movement uses the local support grid's spacing")
 var samples=0;var maximum=0.;var open_samples=[]
 for z in range(1,int(grid.size[1])-1):
  for x in range(1,int(grid.size[0])-1):
   var at:Vector2=state.origin+Vector2(grid.origin[0]+x*grid.spacing+.21,grid.origin[1]+z*grid.spacing+.17)
   var cell=Vector2i(((at-state.origin)/3.).round())
   var expected=Steps.height(at.x,at.y)
   if expected<=.05 or not Original.open(state.bits,state.size,cell):continue
   var position:Vector3=game.model.world_point(at)
   var ray=PhysicsRayQueryParameters3D.create(position+Vector3.UP*8,position-Vector3.UP*3,1)
   var hit:Dictionary=game.world.get_world_3d().direct_space_state.intersect_ray(ray)
   check(not hit.is_empty() and absf(hit.position.y-position.y)<.015,"Physical support matches model height on an original open cell")
   var native_cell=Vector2i(((Vector2(position.x,position.z)-Vector2(nav.origin.x,nav.origin.z))/nav.spacing).round())
   var native_vertex=nav.origin+Vector3(native_cell.x*nav.spacing,0,native_cell.y*nav.spacing)
   var expected_vertex=Steps.height(native_vertex.x/scale_,native_vertex.z/scale_)*scale_
   check(absf(nav.heights[native_cell.y*nav.width+native_cell.x]-expected_vertex)<.0001,"Native height samples agree with the player support")
   open_samples.append(at);maximum=maxf(maximum,expected);samples+=1
 check(samples>8 and maximum>.5,"Curved stair support covers the real walkable approach")
 for index in [0,open_samples.size()/2,open_samples.size()-1]:
  if open_samples.is_empty():break
  var at:Vector2=open_samples[int(index)];game.player.position=game.model.world_point(at,1.)
  game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
  for i in 40:await physics_frame
  check(game.player.is_on_floor(),"The actual player lands on the curved stair support")
  check(absf(game.player.position.y-game.model.world_height(game.player.position.x,game.player.position.z))<.15,"Player feet and native ground remain aligned")
 check(state.bits==original_bits,"The stair fit preserves every original blocked and open cell")
 game.player.position=game.model.world_point(Original.source_point(59535,Vector2i(47,65)),.1)
 game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation();game.camera_rig.yaw=0.
 check(game.army_runtime.native.can_reach(game.player.position,game.model.world_point(Original.source_point(59535,Vector2i(47,57))),.45),"Native movement can cross the same original stair approach")
 var peak=0.;var foot_error=0.
 for leg in [["move_forward",57],["move_back",65]]:
  var target=game.model.world_point(Original.source_point(59535,Vector2i(47,int(leg[1]))))
  Input.action_press(leg[0])
  for i in 600:
   await physics_frame
   peak=maxf(peak,game.player.position.y)
   if game.player.is_on_floor():foot_error=maxf(foot_error,absf(game.player.position.y-game.model.world_height(game.player.position.x,game.player.position.z)))
   if absf(game.player.position.z-target.z)<.35:break
  Input.action_release(leg[0])
  check(absf(game.player.position.z-target.z)<.6,"Normal movement controls cross the curved stairs in both directions")
 check(peak>.7*scale_ and foot_error<.2,"Walking climbs the support and keeps feet aligned")
 check(game.model.falan_floor==59535,"The stair check stays in the original hall")
 check(game.army_runtime.handles.is_empty(),"The temple remains a safe area")
 print("ELSA_HALL_STEPS_RESULT samples=",samples," checks=",checks," failures=",failures)
 await finish()
