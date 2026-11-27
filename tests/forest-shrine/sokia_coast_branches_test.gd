extends "res://tests/forest-shrine/sokia_house_crossing_test.gd"
const BRANCH_OUT="res://build/Other Files/Asset Toolkit/Sokia Region Reconstruction/Coastal branches/"
func _initialize():
 create_timer(1500).timeout.connect(func():printerr("SOKIA_COAST_BRANCH_TIMEOUT");quit(1))
 run.call_deferred()
func try_gate(at:Vector2,target_area:String,target_floor:int)->bool:
 for direction in [Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN]:
  var start=at-direction*3.8
  if not game.model.terrain.disk_clear(Vector3(start.x,game.model.surface_height(start.x,start.y)+.5,start.y),.4):continue
  game.set_physics_process(true);game.player.set_physics_process(true)
  var previous=game.model
  await walk_gate(at,direction)
  if game.model.falan_area==target_area and game.model.falan_floor==target_floor:return true
  if game.model!=previous:return false
 return false
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-sokia-branches-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"));var records=[]
 var mouths_only="--mouths-only" in OS.get_cmdline_user_args()
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/fixed/catalog.json"))
 var population=Tour.SouthPopulation.coast_data()
 for path in source.maps:
  if mouths_only:continue
  if source.maps[path].get("sokia_visual_only",false):continue
  var id=int(source.maps[path].id)
  print("SOKIA_BRANCH_ENTER ",id)
  Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Tour.Indoor.safe_point(id,Vector2.ZERO),"yaw":0.,"velocity":Vector3.ZERO})
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
  for i in 3:await process_frame
  var state=Original.state(id)
  check(state.raw==Original.Art.raw_map(path),"Every original map byte retained: "+str(id))
  check(state.bits==Marshalls.base64_to_raw(source.maps[path].walk).decompress((state.size.x*state.size.y+7)/8,FileAccess.COMPRESSION_DEFLATE),"Native walking grid retained: "+str(id))
  check(game.world.map_features.get_meta("recovered_source_map")==id,"Existing map renderer owns "+str(id))
  var links=game.model.get_meta("falan_links",[])
  for warp in Original.Art.data().warps:
   if int(warp[0])!=id or not source.maps.has("BlueCrossgate/map/0/%d.dat"%int(warp[3])):continue
   check(links.any(func(l):return int(l.get("floor",-1))==int(warp[3]) and l.at.distance_to(Original.source_point(id,Vector2i(warp[1],warp[2])))<.01),"Original onward branch retained: %d → %d"%[id,warp[3]])
  game.explorer_clock.load_hour(22);game.explorer_npcs.prepare()
  var expected:Array=population.npcs.filter(func(n):return int(n.source)==id)
  check(game.explorer_npcs.actors.size()==expected.size(),"No source NPC missing or duplicated: "+str(id))
  var ids={};var talks=[]
  for actor in game.explorer_npcs.actors:
   var record:Dictionary=actor.node.get_meta("npc_record")
   check(not ids.has(record.id),"Unique source actor "+record.id);ids[record.id]=true
   check(Tour.SouthPopulation.source_cell(game.model,Vector2(actor.node.position.x,actor.node.position.z))==Vector2i(record.cell[0],record.cell[1]),"Original source actor cell "+record.id)
   var talked=false
   for dy in range(-1,2):
    for dx in range(-1,2):
     if dx==0 and dy==0:continue
     var spot=Vector2(actor.node.position.x,actor.node.position.z)+Vector2(dx,dy)*3.
     if not game.model.terrain.disk_clear(Vector3(spot.x,game.model.surface_height(spot.x,spot.y)+.5,spot.y),.4):continue
     game.player.position=game.model.world_point(spot,.15);game.player.reset_physics_interpolation()
     game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
     if game.explorer_npcs.nearest.get("node")!=actor.node:continue
     var key=InputEventKey.new();key.physical_keycode=KEY_F;key.pressed=true;game._input(key)
     talked=is_instance_valid(game.dialogue) and game.explorer_npcs.selected.get("id","")=="source:"+record.id
     if talked:
      check(not game.dialogue.body.text.strip_edges().is_empty(),"Source actor has a short line: "+record.id)
      game.explorer_npcs.finish();talks.append(record.id);break
    if talked:break
   check(talked,"Normal F input reaches source branch actor "+record.id)
  records.append({"map":id,"npcs":ids.keys(),"talked":talks,"links":var_to_str(links),"source_sha256":source.maps[path].sha256})
 var port_rows=load("res://scripts/forest/forest_sokia_scenery.gd").COAST_PORTS.duplicate()
 if mouths_only:port_rows.append_array([[356,334,13001,18,6],[402,304,13001,133,26]])
 var mouth_cells=0
 for p in port_rows:
  if mouths_only and Vector2i(p[0],p[1]) not in [Vector2i(380,324),Vector2i(368,351),Vector2i(369,351),Vector2i(626,209),Vector2i(356,334),Vector2i(402,304)]:continue
  if int(p[0])==369 and not mouths_only:continue
  if mouths_only:mouth_cells+=1
  var area="sokia_desert" if int(p[0])==402 else "ghana_road" if int(p[0])>=550 else "sokia_coast"
  var at=Tour.Regions.frame(area).inverse()*(Vector2(p[0],p[1])*3.)
  Tour.travel(game,Tour.Regions.layout(area),{"arrival":at-Vector2(8,0),"yaw":0.,"velocity":Vector3.ZERO})
  game.set_process(false)
  for i in 4:await physics_frame
  var entered=await try_gate(at,"interior",int(p[2]))
  check(entered,"Normal movement enters source coastal branch "+str(p[2]))
  if not entered:continue
  # Great Wind retains its legacy indoor owner; the restored rooms use Original.
  var exit=Tour.Indoor.floor_info(13001)[1]+Vector2(p[3],p[4])*3. if int(p[2])==13001 else Original.source_point(int(p[2]),Vector2i(p[3],p[4]))
  var returned=await try_gate(exit,area,0)
  check(returned,"Normal movement returns from source branch "+str(p[2]))
 if "--all-connectors" in OS.get_cmdline_user_args():
  for warp in Original.Art.data().warps:
   var from_path="BlueCrossgate/map/0/%d.dat"%int(warp[0]);var to_path="BlueCrossgate/map/0/%d.dat"%int(warp[3])
   if not source.maps.has(from_path) or source.maps[from_path].get("sokia_visual_only",false):continue
   if int(warp[3])!=300 and (not source.maps.has(to_path) or source.maps[to_path].get("sokia_visual_only",false)):continue
   var id=int(warp[0]);var at=Original.source_point(id,Vector2i(warp[1],warp[2]))
   Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Tour.Indoor.safe_point(id,at-Vector2(8,0)),"yaw":0.,"velocity":Vector3.ZERO})
   game.set_process(false)
   for i in 3:await physics_frame
   var target_area="ghana_road" if int(warp[4])>=550 else "sokia_coast"
   var crossed=await try_gate(at,target_area if int(warp[3])==300 else "interior",0 if int(warp[3])==300 else int(warp[3]))
   check(crossed,"Normal movement follows every restored source connector: "+str(warp))
   if crossed:
    var actual=Tour.SouthPopulation.source_cell(game.model,Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale)
    check(Vector2(actual).distance_to(Vector2(warp[4],warp[5]))<3.,"Source landing retained after movement: "+str(warp))
  for spec in [["sokia_coast",Vector2i(356,334),Vector2i(18,6)],["sokia_desert",Vector2i(402,304),Vector2i(133,26)]]:
   var at=Tour.Regions.frame(spec[0]).inverse()*(Vector2(spec[1])*3.)
   Tour.travel(game,Tour.Regions.layout(spec[0]),{"arrival":at-Vector2(8,0),"yaw":0.,"velocity":Vector3.ZERO})
   game.set_process(false)
   for i in 3:await physics_frame
   var entered=await try_gate(at,"interior",13001)
   check(entered,"Normal movement enters each Great Wind mouth: "+str(spec[1]))
   if entered:
    var exit=Tour.Indoor.floor_info(13001)[1]+Vector2(spec[2])*3.
    check(await try_gate(exit,spec[0],0),"Normal movement returns through Great Wind mouth: "+str(spec[2]))
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Existing adventure data remains unchanged")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BRANCH_OUT))
 var file=FileAccess.open(BRANCH_OUT+("mouth-verification.json" if mouths_only else "verification.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures} if mouths_only else records,"  "));file.close()
 if mouths_only:print("SOKIA_MOUTH_MOVEMENT_RESULT source_cells=",mouth_cells," checks=",checks," failures=",failures)
 print("SOKIA_COAST_BRANCH_RESULT maps=",records.size()," checks=",checks," failures=",failures)
 game.queue_free();await process_frame;quit(1 if failures else 0)
