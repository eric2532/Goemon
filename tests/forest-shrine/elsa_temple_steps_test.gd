extends "res://tests/forest-shrine/original_maps_test.gd"
const Steps=preload("res://scripts/forest/forest_elsa_hall_steps.gd")
const Temple=preload("res://scripts/forest/forest_elsa_temple.gd")
const Elsa=preload("res://scripts/forest/forest_elsa_route.gd")

func run():
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-elsa-temple-steps.cfg"
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.explorer_clock.save_left=600.
 var state=Original.state(59520);var bits:PackedByteArray=state.bits.duplicate()
 Tour.travel(game,Original.layout(59520),{"arrival":Original.source_point(59520,Vector2i(166,72)),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 6:await physics_frame
 var nav:Dictionary=game.army_runtime.navigation_data(game.model,false);var scale_:float=game.model.falan_scale
 check(nav.spacing==1.5*scale_ and nav.route_spacing==3.*scale_,"Temple support refines heights and retains the original route grid")
 for link in Temple.data().doors:
  var at=Original.source_point(59520,Vector2i(link.cell[0],link.cell[1]));var expected=3.5 if int(link.cell[0])<180 else 4. if int(link.cell[0])>220 else 4.5
  check(absf(game.model.surface_height(at.x,at.y)-expected)<.01,"Original temple door keeps its exact cell on its raised landing")
 var grid:Dictionary=Steps.data(59520).steps.grid;var candidates=[]
 for z in range(1,int(grid.size[1])-1,3):
  for x in range(1,int(grid.size[0])-1,3):
   var at=state.origin+Vector2(grid.origin[0]+x*1.5+.21,grid.origin[1]+z*1.5+.17);var cell=Vector2i(((at-state.origin)/3.).round())
   if not Original.open(bits,state.size,cell) or not Elsa.owned_cell(59520,cell) or Steps.height(at.x,at.y,59520)<.15:continue
   candidates.append(at)
 var samples=0
 for index in range(0,candidates.size(),maxi(1,candidates.size()/36)):
  var at:Vector2=candidates[index];var position:Vector3=game.model.world_point(at)
  var query=PhysicsRayQueryParameters3D.create(position+Vector3.UP*10.,position-Vector3.UP*3.,1);var hit=game.world.get_world_3d().direct_space_state.intersect_ray(query)
  check(not hit.is_empty() and absf(hit.position.y-position.y)<.02,"Temple physical support agrees with model height")
  var cell=Vector2i(((Vector2(position.x,position.z)-Vector2(nav.origin.x,nav.origin.z))/nav.spacing).round());var vertex=nav.origin+Vector3(cell.x*nav.spacing,0,cell.y*nav.spacing)
  check(absf(nav.heights[cell.y*nav.width+cell.x]-Steps.height(vertex.x/scale_,vertex.z/scale_,59520)*scale_)<.001,"Temple native height agrees with shared support")
  samples+=1
 check(samples>=18,"All three stair areas provide targeted open support samples")
 for pair in [[Vector2i(166,72),Vector2i(174,65)],[Vector2i(189,108),Vector2i(198,98)],[Vector2i(218,139),Vector2i(226,130)]]:
  var a=game.model.world_point(Original.source_point(59520,pair[0]),.1);var b=game.model.world_point(Original.source_point(59520,pair[1]))
  game.player.position=a;game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation();game.camera_rig.yaw=0.
  for i in 20:await physics_frame
  check(game.army_runtime.native.can_reach(game.player.position,b,.45),"Native routes cross the original entrance stairs")
  for target in [b,a]:
   for i in 1200:
    var delta:Vector3=target-game.player.position
    for action in ["move_forward","move_back","move_left","move_right"]:Input.action_release(action)
    if Vector2(delta.x,delta.z).length()<.45:break
    if absf(delta.x)>.25:Input.action_press("move_right" if delta.x>0 else "move_left")
    if absf(delta.z)>.25:Input.action_press("move_back" if delta.z>0 else "move_forward")
    await physics_frame
   for action in ["move_forward","move_back","move_left","move_right"]:Input.action_release(action)
   check(Vector2(game.player.position.x-target.x,game.player.position.z-target.z).length()<.65,"Normal controls ascend and descend the original stair approach")
   check(absf(game.player.position.y-game.model.world_height(game.player.position.x,game.player.position.z))<.2,"Player feet remain aligned at the entrance stair endpoint")
 check(state.bits==bits,"Original island walking flags remain unchanged")
 check(game.model.falan_floor==59520 and game.army_runtime.handles.is_empty(),"Stair tests preserve the island safe area")
 print("ELSA_TEMPLE_STEPS_RESULT samples=",samples," checks=",checks," failures=",failures)
 await finish()
