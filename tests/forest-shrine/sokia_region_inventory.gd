extends "res://tests/forest-shrine/original_maps_test.gd"
## Test-only direct loads record actual links and actors before reconstruction.
const OUTPUT="res://build/Other Files/Asset Toolkit/Sokia Region Reconstruction/"

func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate()
 game.settings_path="/tmp/crossgate-sokia-survey-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true
 var queue:Array=["kili","sokia_coast","sokia_desert","ghana_road","ghana","ghana_north_road",13001,3350,15004,47010,3300]
 var visited={};var records=[]
 while not queue.is_empty():
  var key=queue.pop_front()
  if visited.has(key):continue
  visited[key]=true;print("SOKIA_SURVEY_ENTER ",key)
  var floor_=key if key is int else 0
  var area="interior" if key is int else key
  var layout=Tour.Indoor.layout(floor_) if floor_ else Tour.outdoor_layout(get_meta("falan_venture"),area)
  Tour.travel(game,layout,{"arrival":Vector2.ZERO,"yaw":0.0,"velocity":Vector3.ZERO})
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
  for i in 3:await process_frame
  var npcs=[]
  for node in game.world.map_features.find_children("*","Sprite3D",true,false):
   if not node.has_meta("npc_name"):continue
   var at=Vector2(node.position.x,node.position.z)
   var cell:Vector2
   if floor_:cell=(at-Tour.Indoor.floor_info(floor_)[1])/3.
   elif area in ["ghana","kili"]:cell=(at-Tour.Regions.Sites.VILLAGES[area][2])/3.
   else:cell=Tour.Regions.frame(area)*at/3.
   npcs.append({"name":node.get_meta("npc_name"),"cell":[cell.x,cell.y],"record":node.get_meta("npc_record",{})})
  var links=[]
  for original in game.model.get_meta("falan_links",[]):
   var link:Dictionary=original.duplicate(true)
   for field in ["at","arrival","source_arrival","direction","trail_sign"]:
    if link.get(field) is Vector2:link[field]=[link[field].x,link[field].y]
   links.append(link)
   var target=int(link.get("floor",0))
   if (target>=3001 and target<=3099 or target>=3350 and target<=3353 or target in [3804,3805,3806]) and not visited.has(target):queue.append(target)
  records.append({"key":key,"area":area,"floor":floor_,"title":layout.get("title",""),"links":links,"npcs":npcs,"patrol_count":game.model.waves.patrol_posts.size(),"patrol_posts":var_to_str(game.model.waves.patrol_posts),"collision_shapes":game.world.map_features.find_children("*","CollisionShape3D",true,false).size()})
  var file=FileAccess.open(OUTPUT+"runtime-before.json",FileAccess.WRITE)
  file.store_string(JSON.stringify(records,"  "));file.close()
 check(visited.has("kili") and visited.has("ghana") and visited.has(13001),"Both village link tables and Great Wind loaded")
 print("SOKIA_SURVEY_RESULT maps=",records.size()," checks=",checks," failures=",failures)
 game.queue_free();await process_frame;quit(1 if failures else 0)
