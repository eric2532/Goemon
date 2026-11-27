extends "res://tests/forest-shrine/original_maps_test.gd"
## Fixed cameras in the live Explore world; no walkthrough and no saved preferences.
const REVIEW="res://build/Other Files/Asset Toolkit/Jenova Village Art/"
const VIEWS=[
 ["01-entrance",Vector2i(28,40),-PI*.5,.38,15.0],
 ["02-main-street",Vector2i(46,44),.15,.40,15.0],
 ["03-house-street",Vector2i(46,64),-.55,.40,15.0],
 ["04-north-shop",Vector2i(43,28),0.0,.44,15.0],
 ["05-round-landmark",Vector2i(44,39),-.45,.44,15.0],
 ["06-bay-house",Vector2i(57,49),-.5,.44,15.0],
 ["07-green-shop",Vector2i(46,56),-.4,.44,15.0],
 ["08-south-house",Vector2i(37,64),-.5,.44,15.0],
 ["09-east-gate",Vector2i(67,33),PI*.5,.44,15.0],
 ["10-north-gate",Vector2i(32,29),-PI*.5,.44,15.0],
 ["11-east-lane",Vector2i(67,47),PI*.5,.44,15.0],
 ["12-south-lane",Vector2i(51,71),0.0,.44,15.0],
 ["13-west-lane",Vector2i(34,50),-PI*.5,.44,15.0]]

func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-jenova-art-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.set_process(false)
 Tour.travel(game,Original.layout(51004),{"arrival":Original.source_point(51004,Vector2i(46,29)),"yaw":0.0,"velocity":Vector3.ZERO})
 for i in 8:await physics_frame
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 hide_canvas(game)
 var phase="Before" if "--baseline" in OS.get_cmdline_user_args() else "After"
 var folder=REVIEW+phase+"/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var reference=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"Before/cameras.json")) if phase=="After" else []
 var poses=[];var row=Original.state(51004)
 for view in VIEWS:
  var cell=Original.safe_cell(51004,view[1])
  check(connected(51004,Original.source_point(51004,Vector2i(46,29)),Original.source_point(51004,cell)),"Review camera is on reachable street "+view[0])
  game.player.position=game.model.world_point(Original.source_point(51004,cell),.15);game.player.velocity=Vector3.ZERO
  game.camera_rig.yaw=view[2];game.camera_rig.pitch=view[3];game.camera_rig.distance=view[4]
  game.camera_rig.combat_camera_angle=0;game.camera_rig.character_screen_offset=0
  game.camera_rig.reset_follow();game.camera_rig.set_process(true)
  for i in 35:await process_frame
  game.camera_rig.set_process(false)
  var camera=game.camera_rig.camera
  if phase=="After" and poses.size()<3:
   camera.global_transform=str_to_var(reference[poses.size()].camera)
   camera.fov=reference[poses.size()].fov
  camera.reset_physics_interpolation()
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(folder+view[0]+".png")==OK,"Captured fixed gameplay view")
  poses.append({"name":view[0],"cell":[cell.x,cell.y],"camera":var_to_str(camera.global_transform),"fov":camera.fov,"player":var_to_str(game.player.position)})
 if phase=="After":await survey(folder)
 var file=FileAccess.open(folder+"cameras.json",FileAccess.WRITE);file.store_string(JSON.stringify(poses,"  "));file.close()
 print("JENOVA_ART_VIEWS ",poses.size())
 await finish()

func hide_canvas(node:Node):
 if node is CanvasItem:node.hide()
 for child in node.get_children():hide_canvas(child)

func survey(folder:String):
 var row=Original.state(51004);var camera=game.camera_rig.camera
 # Every sector containing reachable ground, including the gate approaches.
 var sectors={}
 for index in Original.JenovaVillageArt.reachable:
  var cell=Vector2i(index%100,index/100);sectors[Vector2i(cell.x/20,cell.y/20)]=true
 var coverage=[]
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 for sector:Vector2i in sectors:
  var wanted=sector*20+Vector2i(10,10);var cell=reachable_cell(wanted)
  var at=game.model.world_point(Original.source_point(51004,wanted))
  game.player.position=game.model.world_point(Original.source_point(51004,cell),.15);game.player.velocity=Vector3.ZERO
  camera.size=88*game.model.falan_scale
  camera.global_position=at+Vector3(-1,1.6,1)*180*game.model.falan_scale;camera.look_at(at)
  await survey_shot(folder+"sector-%d-%d.png"%[sector.x,sector.y])
  coverage.append({"sector":[sector.x,sector.y],"reachable_camera_cell":[cell.x,cell.y]})
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 for serial in Original.JenovaVillageArt.SITES:
  var cell:Vector2i=Original.JenovaVillageArt.SITES[serial]
  var mesh=Original.JenovaVillageArt.mesh(serial,Original.Art.data().graphics[str(serial)])
  var bounds=mesh.get_aabb();var center=game.model.world_point(Original.source_point(51004,cell))+bounds.get_center()*game.model.falan_scale
  for facing in 2:
   camera.global_position=center+Vector3(-1 if facing==0 else 1,.8,1 if facing==0 else -1).normalized()*bounds.size.length()*game.model.falan_scale*1.05
   camera.look_at(center)
   await survey_shot(folder+"house-%d-%d.png"%[serial,facing])
 var file=FileAccess.open(folder+"coverage.json",FileAccess.WRITE);file.store_string(JSON.stringify({"reachable_cells":Original.JenovaVillageArt.reachable.size(),"sectors":coverage},"  "));file.close()

func reachable_cell(wanted:Vector2i)->Vector2i:
 var best=Vector2i.ZERO;var distance=INF
 for index in Original.JenovaVillageArt.reachable:
  var cell=Vector2i(index%100,index/100);var d=cell.distance_squared_to(wanted)
  if d<distance:best=cell;distance=d
 return best

func survey_shot(path:String):
 game.camera_rig.camera.reset_physics_interpolation()
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(path)==OK,"Captured village coverage")
