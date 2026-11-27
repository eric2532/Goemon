extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"
## Bounded port/door checks and direct-load coverage; no complete street walkthrough.
const REVIEW="res://build/Other Files/Asset Toolkit/Kili Ghana Villages/"
var checks=0
func _initialize():
 create_timer(600).timeout.connect(func():printerr("KILI_GHANA_INTEGRATION_TIMEOUT");quit(1))
 run.call_deferred()
func check(ok:bool,message:String):
 checks+=1;super.check(ok,message)
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/kili-ghana-integration-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit();game.tuning.invincible=true
 for i in 4:await physics_frame
 for area in ["kili","ghana"]:
  await open_area(area)
  village_entries(10 if area=="kili" else 9)
  var entry=Tour.Regions.entry_point(area)
  for link in game.model.get_meta("falan_links"):
   if link.to=="freyja_door":check(road_connected(entry,link.at,.55,false),"Source streets connect to every original door in "+area+" / "+str(link.floor))
  var count=game.world.map_features.get_meta("kili_ghana_native_fixtures",-1)
  if count<0:
   for node in game.world.map_features.find_children("*","Node3D",true,false):
    if node.has_meta("kili_ghana_native_fixtures"):count=node.get_meta("kili_ghana_native_fixtures");break
  check(count==preload("res://scripts/forest/forest_kili_ghana_props.gd").catalog().areas[area].size(),"Every omitted source fixture renders once in "+area)
  # Changed residence thresholds plus a chief doorway and internal passage in each village.
  if area=="ghana":
   for id in [3804,3805,3806]:await room(id);await room(3000)
   await room(3012);await room(3013);await room(3012);await room(3000)
  else:
   await room(3212);await room(3213);await room(3212);await room(3200)
  var village_id=3200 if area=="kili" else 3000
  var exits=game.model.get_meta("falan_links").filter(func(l):return l.to=="freyja_outside").duplicate(true)
  check(exits.size()==2,"Both original regional gates remain in "+area)
  for link in exits:
   await open_area(area)
   var before=game.model
   await position_at(link.at)
   if game.model==before:await walk_through_entry()
   check(Tour.area(game.model)==link.area,"Gate crosses to its preserved regional approach: "+area+" → "+link.area)
   var candidates=game.model.get_meta("falan_links").filter(func(l):return l.get("site")==village_id)
   check(not candidates.is_empty(),"Approach retains village return "+area)
   if candidates.is_empty():continue
   candidates.sort_custom(func(a,b):return a.at.distance_squared_to(map_position())<b.at.distance_squared_to(map_position()))
   before=game.model;await position_at(candidates[0].at)
   if game.model==before:await walk_through_entry()
   check(Tour.area(game.model)==area,"Gate round trip returns to "+area)
 var route=JSON.parse_string(FileAccess.get_file_as_string(REVIEW+"route.json"))
 var covered=[]
 for stage in route.stages:
  if stage.area!="interior":continue
  var id=int(stage.floor);var info=Tour.Indoor.floor_info(id)
  var first=Tour.Regions.Sites.DOORS[id][0][0]
  Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Tour.Indoor.safe_point(id,first),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 3:await physics_frame
  var floor_node=game.world.find_child("ArchivedRoomFloor",true,false)
  check(floor_node!=null,"Source floor renders "+str(id))
  var furnishings=game.world.find_child("ArchivedCoastalFurnishings",true,false)
  check(furnishings!=null,"Prepared native room fixtures render "+str(id))
  var source:Array=Tour.Indoor.RoomArt.Coastal.Data.ROOMS[id]
  if furnishings!=null:check(furnishings.get_parent().get_meta("coastal_source_objects")==source.size(),"Complete source object coverage "+str(id))
  check(game.model.terrain.disk_clear(Vector3(map_position().x,0,map_position().y),.55),"Safe source arrival "+str(id))
  for link in game.model.get_meta("falan_links"):
   var cell=Vector2i(((link.at-info[1])/3.).round())
   check(Tour.Indoor.open_cell(info[2].hex_decode(),info[0],cell.x,cell.y),"Every source indoor threshold is open "+str(id))
  covered.append(id)
 var file=FileAccess.open(REVIEW+"integration.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":errors,"interiors":covered,"rendered":DisplayServer.get_name()!="headless","scope":"All 27 rooms loaded; three Ghana residences, both chief passages and four gate round trips spot-checked. No full street walkthrough."},"  "));file.close()
 print("KILI_GHANA_INTEGRATION_RESULT interiors=",covered.size()," checks=",checks," failures=",errors)
 game.queue_free();await process_frame;quit(1 if errors else 0)
