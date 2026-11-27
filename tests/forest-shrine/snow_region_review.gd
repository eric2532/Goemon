extends "res://tests/forest-shrine/west_snow_route_review.gd"
## Whole-region fixed jumps; immutable map bytes, walk bits and travel recorded per view.
var scope:Dictionary

func _initialize():
 create_timer(1800).timeout.connect(func():printerr("SNOW_REGION_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 review_root="res://build/Other Files/Asset Toolkit/Snow Region/"
 phase="After" if "--after" in OS.get_cmdline_user_args() else "Before"
 var cleanup="--cleanup" in OS.get_cmdline_user_args()
 if cleanup:review_root="res://build/Other Files/Asset Toolkit/Snow Region Cleanup/"
 scope=JSON.parse_string(FileAccess.get_file_as_string(review_root+"boundary.json"))
 var selected=Array(OS.get_cmdline_user_args()).filter(func(a):return a.begins_with("--floor="))
 if not selected.is_empty() and FileAccess.file_exists(review_root+phase+"/cameras.json"):
  records=JSON.parse_string(FileAccess.get_file_as_string(review_root+phase+"/cameras.json")).filter(func(p):return not selected.has("--floor="+str(int(p.floor))))
 if phase=="After":
  for pose in JSON.parse_string(FileAccess.get_file_as_string(review_root+"Before/cameras.json")):baseline_poses[pose.name]=pose
 elif cleanup:
  for pose in JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/Snow Region/After/cameras.json")):baseline_poses[pose.name]=pose
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-snow-region-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.run_seed=341;game.set_process(false)
 reuse_gameplay_baseline=false
 for entry in scope.stages:
  if not selected.is_empty() and not selected.has("--floor="+str(int(entry.floor))):continue
  stage=entry.duplicate(true);stage.area="interior"
  print("SNOW_REGION_ENTER ",stage.floor)
  var id=int(stage.floor);var cell=Vector2(stage.anchor[0],stage.anchor[1])
  var layout=Original.layout(id);layout.seed=341
  Tour.travel(game,layout,{"arrival":local_point(cell),"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 6:await physics_frame
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
  game.camera_rig.set_process_unhandled_input(false)
  game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting();hide_canvas(game)
  await gameplay({"key":stage.key+"-representative","at":stage.anchor,"start":[cell.x,cell.y+1],"end":[cell.x,cell.y-1]})
  if id==51031:
   await gameplay({"key":stage.key+"-first-snow","at":[212,349],"start":[212,350],"end":[212,348]})
  if id==51011:
   for view in [["north-house",[38,33]],["round-house",[47,68]],["pub",[64,66]],["bay",[32,54]],["gate",[37,69]]]:
    await gameplay({"key":stage.key+"-"+view[0],"at":view[1],"start":view[1],"end":[view[1][0]+1,view[1][1]]})
  if stage.source==null:
   var row=Original.state(id,341)
   for z in range(0,row.size.y,10):
    for x in range(0,row.size.x,10):
     await isometric(stage.key+"-sector-%d-%d"%[x,z],Vector2(x+5,z+5),80)
  else:
   for section in stage.sectors:await isometric(section.key,Vector2(section.at[0],section.at[1]),105)
  var folder=review_root+phase+"/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
  var file=FileAccess.open(folder+"cameras.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"  "));file.close()
 print("SNOW_REGION_RESULT failures=",failures," captures=",records.size())
 game.queue_free();await process_frame;quit(1 if failures else 0)

func basis_record(name_:String,kind:String,cell:Vector2)->Dictionary:
 var pose=super.basis_record(name_,kind,cell)
 var state=Original.state(int(stage.floor),341)
 pose.raw=state.raw.hex_encode().sha256_text();pose.bits=state.bits.hex_encode().sha256_text()
 return pose
