extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
## Same fixed cameras before/after, plus scoped source/door coverage.
const REVIEW="res://build/Other Files/Asset Toolkit/Il and Laruka/"
var phase="Before" if "--baseline" in OS.get_cmdline_user_args() else "After"
var review=REVIEW+("Decorations/" if "--waterfront" in OS.get_cmdline_user_args() else "Details/" if "--details" in OS.get_cmdline_user_args() else "")
var captures=[]
var checks=0
var coverage=[]

func _initialize():
 create_timer(600).timeout.connect(func():printerr("IL_LARUKA_REVIEW_TIMEOUT");quit(1))
 heartbeat.call_deferred()
 run.call_deferred()

func heartbeat():
 if is_instance_valid(game):print("IL_LARUKA_STATE area=",Tour.area(game.model) if game.model!=null else "none"," paused=",paused," phase=",game.model.phase if game.model!=null else "none"," transition=",game.transitioning)
 create_timer(20,true,false,true).timeout.connect(heartbeat)

func check(ok:bool,message:String):
 checks+=1
 super.check(ok,message)

func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/il-laruka-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false
 game.tuning.invincible=true
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(review+phase))
 if "--waterfront" in OS.get_cmdline_user_args():
  await waterfront_review()
  await finish()
  return
 await open_area("east_coast")
 await site(2000,"il_village")
 await village_view("il-entrance",Vector3(34,27,-108),Vector3(-4,10,-91),"il_village")
 await village_view("il-main-street",Vector3(25,38,-21),Vector3(-20,10,8),"il_village")
 await village_view("il-chief",Vector3(52,38,105),Vector3(15,13,65),"il_village")
 await village_view("il-guild",Vector3(125,40,76),Vector3(81,14,35),"il_village")
 await village_view("il-overview",Vector3(190,250,230),Vector3(0,6,0),"il_village")
 if "--details" in OS.get_cmdline_user_args():await detail_views("il_village")
 await open_area("west_lakes")
 var link=Tour.Regions.site_links("west_lakes").filter(func(l):return l.site==2300)[0]
 await shot_review("laruka-approach",game.model.world_point(link.at+Vector2(32,15))+Vector3.UP*25,game.model.world_point(link.at)+Vector3.UP*5)
 await open_area("laruka")
 await village_view("laruka-entrance",Vector3(59,29,9),Vector3(16,9,-18),"laruka")
 await village_view("laruka-main-street",Vector3(19,44,41),Vector3(-37,10,24),"laruka")
 await village_view("laruka-church",Vector3(55,35,47),Vector3(18,12,18),"laruka")
 await village_view("laruka-overview",Vector3(185,235,230),Vector3(-12,6,24),"laruka")
 if "--details" in OS.get_cmdline_user_args():
  await detail_views("laruka")
  for id in [2099,2302,2303,2307,2399]:
   Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Tour.Indoor.safe_point(id,Vector2.ZERO),"yaw":0.0,"velocity":Vector3.ZERO})
   for i in 4:await physics_frame
   await shot_review("lower-room-"+str(id),Vector3(43,56,54)*game.model.falan_scale,Vector3.ZERO)
 if phase=="After" and "--views-only" not in OS.get_cmdline_user_args():await scoped_checks()
 var file=FileAccess.open(review+phase+"/cameras.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(captures,"  "));file.close()
 var report=FileAccess.open(review+phase+("/visual-checks.json" if "--views-only" in OS.get_cmdline_user_args() else "/checks.json"),FileAccess.WRITE)
 report.store_string(JSON.stringify({"checks":checks,"failures":errors,"maps":coverage},"  "));report.close()
 print("IL_LARUKA_REVIEW captures=",captures.size()," checks=",checks," failures=",errors)
 await finish()

func village_view(label:String,eye:Vector3,target:Vector3,village:String):
 if village=="il_village":await shot_review(label,village_world(eye,village),village_world(target,village))
 else:await shot_review(label,eye*game.model.falan_scale,target*game.model.falan_scale)

func shot_review(label:String,eye:Vector3,target:Vector3):
 if DisplayServer.get_name()=="headless":return
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
 game.ui.hide();game.set_process(false)
 var camera=game.camera_rig.camera
 camera.global_position=eye;camera.look_at(target);camera.fov=62
 camera.reset_physics_interpolation()
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(review+phase+"/"+label+".png")==OK,"Capture "+label)
 captures.append({"name":label,"camera":var_to_str(camera.global_transform),"fov":camera.fov})
 game.set_process(true);game.ui.show()

func scoped_checks():
 var source=preload("res://scripts/forest/forest_il_laruka_art.gd")
 check(Tour.Indoor.floor_info(2307)[0]==Vector2i(20,20),"Recovered materials shop uses the native 20 by 20 map")
 check(not Tour.Indoor.Dungeons.roofed(2307),"Materials shop uses an interior cutaway, preserving the visible source plan")
 check(Tour.Regions.Sites.DOORS[2306][0][2]==Vector2(-12,-15),"Food-shop stair arrives at native materials-shop cell 6,5")
 check(source.stair_openings(2307).has(Vector2i(6,7)) and source.stair_openings(2307).has(Vector2i(6,6)),"Recovered lower stair opens the original floor footprint")
 for village in ["il_village","laruka"]:
  await open_area("east_coast" if village=="il_village" else "west_lakes")
  await site(2000 if village=="il_village" else 2300,village)
  village_entries(6 if village=="il_village" else 7)
  var buildings=game.world.find_children("BlueCGVillageBuilding_*","Node3D",true,false)
  check(buildings.size()==(8 if village=="il_village" else 7),"Every native building placement renders in "+village)
  coverage.append({"area":village,"buildings":buildings.size(),"doors":game.model.get_meta("falan_links").filter(func(l):return l.to=="freyja_door").size()})
  # A doorway and an internal crossing per village, plus Laruka's two shop doors.
  if village=="il_village":
   await room(2012);await room(2099);await room(2012);await room(2000)
  else:
   await room(2301,0);await room(2302);await room(2303);await room(2302);await room(2301);await room(2300,0)
   await room(2301,1);await room(2300,1)
   await room(2306);await room(2307);await room(2306);await room(2300)
   await leave_village("west_lakes")
 for id in source.Data.MAPS:
  if id in [2000,2300]:continue
  var links=Tour.Regions.Sites.DOORS[id]
  var arrival:Vector2=links[0][0]
  Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Tour.Indoor.safe_point(id,arrival,game.model.seed_value),"yaw":0.0,"velocity":Vector3.ZERO})
  for i in 4:await physics_frame
  var owner=game.world.find_child("IlLarukaSourceScenery",true,false)
  check(owner!=null,"Source furnishings and walls render in "+str(id))
  if id==2307:
   check(owner.find_child("NativeGraphic_16595",true,false)!=null,"Materials-shop return stair renders")
   check(owner.get_parent().get_meta("il_laruka_source_objects",0)==97,"Materials shop retains every original fixture")
  check(game.world.find_child("ArchivedRoomFloor",true,false)!=null,"Original floor renders in "+str(id))
  var p=map_position()
  check(game.model.terrain.disk_clear(Vector3(p.x,0,p.y),.55),"Room arrival is on the original walk grid "+str(id))
  var npc=game.world.find_child("OriginalFalanNPCs",true,false)
  coverage.append({"map":id,"source_objects":source.Data.MAPS[id].size(),"npc_count":npc.get_child_count() if npc!=null else 0})
  await shot_review("room-"+str(id),Vector3(43,56,54)*game.model.falan_scale,Vector3.ZERO)

func detail_views(village:String):
 var source=preload("res://scripts/forest/forest_il_laruka_art.gd")
 var seen={}
 for row in source.Data.MAPS[source.IDS[village]]:
  var serial:int=row[2]
  if serial not in source.Data.BUILDINGS or seen.has(serial):continue
  seen[serial]=true
  var g:Dictionary=source.Data.GRAPHICS[str(serial)]
  var center=source.point(source.IDS[village],row)+Vector2((g.footprint[0]-1)*1.5,-(g.footprint[1]-1)*1.5)
  var p=Vector3(center.x,0,center.y)
  var radius=maxf(g.footprint[0],g.footprint[1])*1.5+14
  for side in [-1,1]:
   await village_view("house-%d-%s"%[serial,"reverse" if side<0 else "front"],p+Vector3(radius*side,20,radius*side),p+Vector3.UP*5,village)

func waterfront_review():
 await open_area("laruka")
 await village_view("waterfront-wide",Vector3(-110,33,108),Vector3(-73,5,63),"laruka")
 await village_view("waterfront-caps",Vector3(-86,18,72),Vector3(-71,6,54),"laruka")
 await village_view("waterfront-reverse",Vector3(-44,23,36),Vector3(-72,6,62),"laruka")
 if phase=="After":
  await village_view("waterfront-side",Vector3(-98,22,33),Vector3(-72,6,63),"laruka")
  var art=preload("res://scripts/forest/forest_il_laruka_art.gd")
  var rows=art.Data.MAPS[2300].filter(func(row):return row[2] in [38043,38044,38046,38051])
  check(rows.size()==15,"Every recovered waterfront placement renders")
  var quay=game.world.find_child("LarukaQuaySurfaces",true,false)
  check(quay!=null and quay.get_meta("source_paving_cells")==60,"Quay uses the original sixty-cell paving footprint")
  for serial in [38043,38044,38046,38051]:
   var node=game.world.find_child("NativeGraphic_"+str(serial),true,false)
   check(node!=null,"Recovered waterfront graphic "+str(serial)+" renders")
   check(art.Data.GRAPHICS[str(serial)].source_serial==serial+200000,"Waterfront graphic resolves the expansion ID "+str(serial))
  for row in rows:
   var at=art.point(2300,row)
   check(game.model.surface_height(at.x,at.y)>4.5,"Recovered cap has a supported walking surface "+str(row.slice(0,2)))
  await position_at(Vector2(-66,54))
  game.camera_rig.yaw=PI*.5
  Input.action_press("move_forward")
  for i in 90:
   await physics_frame
   if map_position().x< -75:break
  Input.action_release("move_forward")
  check(map_position().x< -74 and absf(map_position().y-54)<1.5,"Player crosses the restored stone caps")
  check(game.player.position.y/game.model.falan_scale>5.0,"Crossing stays on the capped walkway")
  village_entries(7)
  await room(2308);await room(2300)
 var file=FileAccess.open(review+phase+"/cameras.json",FileAccess.WRITE);file.store_string(JSON.stringify(captures,"  "));file.close()
 file=FileAccess.open(review+phase+"/checks.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":errors},"  "));file.close()
 print("LARUKA_WATERFRONT captures=",captures.size()," checks=",checks," failures=",errors)
