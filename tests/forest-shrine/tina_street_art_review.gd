extends "res://tests/forest-shrine/tina_full_village_review.gd"
## Three fixed gameplay cameras, with temporary preferences and direct travel.
const ART_OUT="res://build/Other Files/Asset Toolkit/Tina Recovery/Street Art Pass/"
const STREET_VIEWS=[
 ["01-main-street",Vector2i(42,45),.65,.61,18.0],
 ["02-blue-house-close",Vector2i(33,40),-PI*.25,.61,18.0],
 ["03-south-street",Vector2i(42,59),-PI*.25,.61,18.0]]

func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-tina-art-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.set_process(false);game.explorer_clock.load_hour(12)
 await visit_source(32181,Vector2i(94,66))
 await travel_with_j()
 hide_canvas(game)
 verify_live_art()
 var phase="Before" if "--baseline" in OS.get_cmdline_user_args() else "After"
 var output=ART_OUT
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--audit-out="):output=arg.trim_prefix("--audit-out=").trim_suffix("/")+"/"
 var folder=output+phase+"/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var camera=game.camera_rig.camera;camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 var poses=[]
 for view in ([] if "--night-only" in OS.get_cmdline_user_args() else STREET_VIEWS):
  var row=Original.state(51005)
  check(Original.open(row.bits,row.size,view[1]),"Fixed review position is reachable ground "+str(view[1]))
  game.player.global_position=game.model.world_point(Original.source_point(51005,view[1]))+Vector3.UP
  game.player.velocity=Vector3.ZERO
  game.camera_rig.yaw=view[2];game.camera_rig.pitch=view[3];game.camera_rig.distance=view[4]
  game.camera_rig.reset_follow();game.camera_rig.set_process(true)
  for i in 30:await process_frame
  game.camera_rig.set_process(false)
  await audit_snap(folder+view[0]+".png")
  poses.append({"name":view[0],"source_cell":[view[1].x,view[1].y],"camera":var_to_str(camera.global_transform),"fov":camera.fov,"player":var_to_str(game.player.global_position)})
 if not poses.is_empty():
  var file=FileAccess.open(folder+"cameras.json",FileAccess.WRITE);file.store_string(JSON.stringify(poses,"  "))
 # Inspect every live house family, including the separate night-only west house.
 var houses=[["04-hospital",Vector2i(36,27),11414],["05-blue-house",Vector2i(36,38),11409],["06-green-house",Vector2i(30,61),11407],["07-pub",Vector2i(46,55),11416],["08-shed",Vector2i(48,35),11451]]
 game.camera_rig.set_process(false)
 for view in ([] if "--night-only" in OS.get_cmdline_user_args() else houses):
  await house_view(folder+view[0]+".png",51005,view[1],view[2])
 game.explorer_clock.load_hour(0)
 await travel_with_j();hide_canvas(game);verify_live_art()
 await house_view(folder+"09-night-west-house.png",4201,Vector2i(21,54),11410)
 await house_view(folder+"10-night-green-house.png",4201,Vector2i(30,60),11407)
 print("TINA_PLAYER_SCALE standing_height=",preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT)
 finish()

func travel_with_j():
 var press=InputEventKey.new();press.physical_keycode=KEY_J;press.pressed=true
 game._input(press)
 check(is_instance_valid(game.dialogue) and game.dialogue.speaker=="區域旅行","Actual J handler opens area travel")
 if not is_instance_valid(game.dialogue):return
 var button=game.dialogue.options.get_child(0)
 check(button.text==Original.title(4200),"J menu offers the correct village")
 button.pressed.emit()
 for i in 10:await physics_frame
 for i in 4:await process_frame
 check(game.model.falan_floor==game.explorer_clock.phase_floor(51005),"J menu loads the current day/night village")

func verify_live_art():
 var source=Original.source_id(game.model.falan_floor)
 var node=recovered_root(game,source);check(node!=null,"J travel created the live original-map root")
 var houses=[];var outside_untouched=false
 for child in node.get_children():
  if not child is MultiMeshInstance3D or not child.has_meta("source_graphic"):continue
  var serial=int(child.get_meta("source_graphic"));var mesh:Mesh=child.multimesh.mesh
  if serial in Original.TinaVillageArt.ACTIVE:
   if mesh.has_meta("tina_street_art"):
    for i in child.multimesh.instance_count:houses.append(serial)
   elif serial==11409:outside_untouched=true
 check(houses.size()==(6 if source==4201 else 5),"Every village house uses the redesigned mesh after J travel")
 check(outside_untouched,"The separate northern approach house keeps its original mesh")
 print("TINA_LIVE_HOUSES source=",source," serials=",houses)

func house_view(path:String,id:int,cell:Vector2i,serial:int):
 var g:Dictionary=Original.Art.data().graphics[str(serial)]
 var mesh=Original.TinaVillageArt.mesh(serial,g);var bounds=mesh.get_aabb()
 var center=game.model.world_point(Original.source_point(id,cell))+bounds.get_center()*game.model.falan_scale
 var camera=game.camera_rig.camera
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 camera.global_position=center+(Vector3(.45,2.0,.6) if id==4201 else Vector3(-1,.85,1)).normalized()*bounds.size.length()*game.model.falan_scale*1.15
 camera.look_at(center)
 await audit_snap(path)
