extends "res://tests/forest-shrine/original_maps_test.gd"
## Fixed views are art evidence only. Dungeon completion requires the separate normal-entry walk.
const REVIEW="res://build/Other Files/Asset Toolkit/University Region/Views/"

func _initialize():
 create_timer(3600).timeout.connect(func():printerr("UNIVERSITY_REVIEW_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW))
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-university-review.cfg"
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.run_seed=341;game.explorer_clock.hour=12.0;game.explorer_clock.save_left=100000
 var scope=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/University Region/scope.json"))
 if "--fixed-only" not in OS.get_cmdline_user_args():
  for branch_ in Original.generated().SPECS:
   for n in range(1,Original.generated().count(branch_,341)+1):
    var id:int=Original.generated().floor_id(branch_,n)
    scope.fixed.append({"runtime":id,"source":id,"title":Original.title(id)})
  for id in range(51201,51213):scope.fixed.append({"runtime":id,"source":id,"title":Original.title(id)})
 var selected=[]
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--floor="):selected.append(int(argument.trim_prefix("--floor=")))
 var evidence=[]
 var previous:Variant=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"views.json")) if FileAccess.file_exists(REVIEW+"views.json") else null
 if previous is Array:evidence=previous
 var reviewed=0
 for entry in scope.fixed:
  var id=int(entry.runtime);var source=int(entry.source)
  if not selected.is_empty() and id not in selected and source not in selected:continue
  if not Original.owns(id):evidence.append({"source":source,"blocker":"Runtime source layout unavailable"});continue
  game.explorer_clock.hour=21. if source==4431 else 12.
  print("UNIVERSITY_REVIEW_ENTER ",source," ",entry.title)
  var state=Original.state(id,341);var picks=[]
  if source==59752:picks.append(Original.source_point(id,Vector2i(100,112)))
  for link in Original.links(id,341):
   if not picks.is_empty():break
   if link.get("floor",-1)>0 and Original.owns(int(link.floor)):
    var returns=Original.links(int(link.floor),341).filter(func(other):return other.get("floor",-1)==id)
    if not returns.is_empty():picks.append(returns[0].arrival);break
  if picks.is_empty():picks.append(Original.point(id,Original.safe_cell(id,state.size/2,341),341))
  var cell_count:int=state.size.x*state.size.y;var detail=Vector2i.ZERO;var weight=0.0
  for i in cell_count:
   var serial:int=state.raw.decode_u16(20+(cell_count+i)*2)
   if serial<1000:continue
   var graphic:Dictionary=Original.Art.data().graphics[str(serial)]
   var family=Original.Forms.kind(serial,false,graphic)
   if family in ["void","floor","tree","rock","wall","room_wall","ruin_wall"]:continue
   var area_:float=graphic.rect[2]*graphic.rect[3]
   if area_>weight:weight=area_;detail=Vector2i(i%state.size.x,i/state.size.x)
  if source==59752:
   picks.append(Original.source_point(id,Vector2i(130,143)))
  elif weight>0 and "--one-view" not in OS.get_cmdline_user_args():picks.append(Original.point(id,Original.safe_cell(id,detail+Vector2i(0,2),341),341))
  if source==4400:picks.append(Original.source_point(id,Vector2i(75,127)))
  Tour.travel(game,Original.layout(id),{"arrival":picks[0],"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 5:await physics_frame
  game.camera_rig.set_process(false);game.ui.hide()
  check(game.world.map_features.get_meta("recovered_source_map",-1)==source,"Build the intended fixed source map "+str(source))
  check(game.world.map_features.get_meta("recovered_solid_placements",0)>0,"Build solid scenery "+str(source))
  var row={"source":source,"runtime":id,"title":entry.title,"views":[],"runtime_hex_sha256":state.raw.hex_encode().sha256_text(),"limits":"Direct loads establish art coverage only; unseen depth and original height fields remain inferred."}
  for index in picks.size():
   game.player.position=game.model.world_point(picks[index],.15);game.player.velocity=Vector3.ZERO;game.player.reset_physics_interpolation()
   game.falan_crossing_position=Vector2.INF
   game.camera_rig.yaw=0;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT
   game.camera_rig.reset_follow();game.camera_rig.current_distance=game.camera_rig.combat_distance();game.camera_rig.update_camera(1.0,true)
   for i in 4:
    game.falan_crossing_position=Vector2.INF
    await process_frame
   await RenderingServer.frame_post_draw
   var name_="%d-%d.png"%[source,index]
   check(root.get_texture().get_image().save_png(REVIEW+name_)==OK,"Capture fixed normal-camera view "+name_)
   check(game.model.falan_floor==id,"The art capture remains in its labeled source room "+name_)
   var camera=game.camera_rig.camera
   row.views.append({"image":name_,"local":[picks[index].x,picks[index].y],"actual_local":[game.player.position.x/game.model.falan_scale,game.player.position.z/game.model.falan_scale],"camera":str(camera.global_transform),"fov":camera.fov})
  evidence=evidence.filter(func(old):return int(old.get("runtime",old.source))!=id)
  evidence.append(row);reviewed+=1
  var file=FileAccess.open(REVIEW+"views.json",FileAccess.WRITE);file.store_string(JSON.stringify(evidence,"  "));file.close()
 print("UNIVERSITY_REVIEW_RESULT maps=",reviewed," preserved_rows=",evidence.size()," checks=",checks," failures=",failures)
 quit(1 if failures else 0)
