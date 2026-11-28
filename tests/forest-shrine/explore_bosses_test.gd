extends "res://tests/forest-shrine/explore_access_test.gd"
var boss_report=[]
var production_sources={}
var field_route_trace=[]
func _initialize():
 create_timer(7200 if Array(OS.get_cmdline_user_args()).any(func(arg):return arg in["--matrix","--specials","--endpoints"])else 900).timeout.connect(func():printerr("EXPLORE_BOSSES_TIMEOUT");save_boss_report();quit(1));run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-explore-bosses-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for script in [game.get_script(),game.explore_access.get_script(),game.explorer_npcs.get_script(),game.model.waves.get_script(),Tour,Original,preload("res://scripts/forest/forest_explore_routes.gd"),preload("res://scripts/forest/forest_east_region.gd"),preload("res://scripts/forest/forest_university_region.gd"),preload("res://scripts/forest/forest_explore_retries.gd"),preload("res://scripts/forest/forest_east_battles.gd")]:production_sources[script.resource_path]=script.get_source_code().sha256_text()
 for script in [preload("res://scripts/forest/crowd/army_kit_data.gd"),preload("res://scripts/forest/crowd/east_region_sprites.gd"),preload("res://scripts/forest/crowd/army_presentation.gd"),preload("res://scripts/forest/pet_catalog.gd"),preload("res://scripts/forest/crowd/university_region_sprites.gd"),preload("res://scripts/forest/crowd/army_renderer.gd")]:production_sources[script.resource_path]=script.get_source_code().sha256_text()
 for script in [preload("res://scripts/forest/forest_explore_endpoints.gd"),preload("res://scripts/forest/crowd/pet_dimensions.gd"),preload("res://scripts/forest/crowd/snow_region_sprites.gd")]:production_sources[script.resource_path]=script.get_source_code().sha256_text()
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 set_test_seed()
 game.tuning.invincible=true;game.player.run_upgrades.damage=100000
 var room_entry=Vector2i(-1,-1);var stand_off=0.
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--room-entry="):
   var entry_parts=arg.trim_prefix("--room-entry=").split(",")
   if entry_parts.size()==2:room_entry=Vector2i(int(entry_parts[0]),int(entry_parts[1]))
  if arg.begins_with("--stand-off="):stand_off=float(arg.trim_prefix("--stand-off="))
 var cases=[[4501,Vector2i(10,12),"altar"],[15569,Vector2i(22,24),"5320"],[51805,Vector2i(10,10),"new-scientist"],[13016,Vector2i(39,18),"new-temple"]]
 if "--lizard"in OS.get_cmdline_user_args():cases=[[16520,Vector2i(10,14),"lizard"]]
 if "--diagnose"in OS.get_cmdline_user_args():cases=cases.filter(func(c):return c[2]in["5320","new-scientist","new-temple"])
 if "--endpoints"in OS.get_cmdline_user_args():
  cases=[[13016,Vector2i(39,18),"new-temple"],[15522,Vector2i(40,8),"new-snow-summit"],[32106,Vector2i(16,39),"new-babel-middle"],[32115,Vector2i(70,100),"new-babel-end"]]
  var generated=Original.generated()
  for branch_ in preload("res://scripts/forest/forest_explore_endpoints.gd").BRANCHES:
   var floor_=generated.floor_id(branch_,generated.count(branch_,game.model.seed_value))
   cases.append([floor_,generated.doors(floor_,game.model.seed_value)[0],"new-"+branch_])
 if "--matrix"in OS.get_cmdline_user_args():
  cases=[]
  var census=JSON.parse_string(FileAccess.get_file_as_string(ACCESS_OUT+"runtime-inventory.json"))
  var blocked=census.blockers.map(func(b):return str(b.actor))
  var catalog=preload("res://scripts/forest/forest_explore_routes.gd");catalog.data()
  for rows in catalog.catalog.bosses.values():
   for row in rows:
    var id=Original.runtime_id(int(row.source))
    if not Original.owns(id)and not(id==Tour.Falken.ROOM and str(row.actor)=="81001") or str(row.actor)in blocked:continue
    var declarations=[]
    for declaration in row.declarations:
     if declaration in declarations:continue
     declarations.append(declaration);cases.append([id,Vector2i(23,45)if str(row.actor)=="81001"else Vector2i(row.cell[0],row.cell[1]),str(row.actor),row.declarations.find(declaration)])
 if "--terminals"in OS.get_cmdline_user_args():
  cases=[]
  var generated=Original.generated();var routes=preload("res://scripts/forest/forest_explore_routes.gd");routes.data()
  for branch in generated.SPECS:
   var spec:Dictionary=generated.SPECS[branch]
   if not spec.get("east",false)or int(spec.get("terminal_enemy",0))<=0:continue
   var id=generated.floor_id(branch,generated.count(branch,game.model.seed_value))
   var seen=[]
   for declaration in routes.catalog.bosses.get("777",[]):
    if str(declaration.actor)!=str(int(spec.terminal_enemy)):continue
    for index in declaration.declarations.size():
     var text:String=declaration.declarations[index]
     if text in seen:continue
     seen.append(text);cases.append([id,generated.doors(id,game.model.seed_value)[0],str(declaration.actor),index])
  check(cases.size()==1,"Only the declared generated shadow endpoint attaches a source-777 encounter; unused templates remain archival")
 if "--inline-bosses"in OS.get_cmdline_user_args():
  var catalog=preload("res://scripts/forest/forest_explore_routes.gd");catalog.data()
  var roles:Array=catalog.catalog.source_events.actors.values().filter(func(a):return a.type=="StandEnemy")
  cases=cases.filter(func(c):return roles.any(func(a):return str(a.id)==str(c[2])and Original.runtime_id(int(a.source))==int(c[0])))
 if "--specials"in OS.get_cmdline_user_args():
  cases=[]
  var regional=preload("res://scripts/forest/forest_university_region.gd")
  for key in regional.BOSSES:
   var spec=regional.specification(key,game.model.seed_value);cases.append([spec.map,spec.cell,key])
  var dungeon=Original.generated();var terminal_floor=dungeon.floor_id("east_102",dungeon.count("east_102",game.model.seed_value))
  cases.append([terminal_floor,dungeon.doors(terminal_floor,game.model.seed_value)[0],"80023"])
  cases.append([0,Vector2i(182,101),"5237"])
  cases.append_array([[11004,Vector2i(16,11),"habaru_slot"],[11001,Vector2i(8,21),"venoa_bear_slot"],[15003,Vector2i(33,29),"undersea_slot"],[23001,Vector2i(23,45),"falken_slot"],[16508,Vector2i(25,20),"ruby_slot"],[47017,Vector2i(22,23),"grave_slot"],[15505,Vector2i(40,6),"zombie_slot"],[16503,Vector2i(25,20),"captain_slot"]])
  var census=JSON.parse_string(FileAccess.get_file_as_string(ACCESS_OUT+"runtime-inventory.json"))
  var blocked=census.blockers.map(func(b):return str(b.actor))
  cases=cases.filter(func(c):return "regional:"+str(c[2])not in blocked)
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--source="):cases=cases.filter(func(c):return c[0]==int(arg.trim_prefix("--source=")))
  if arg.begins_with("--boss="):cases=cases.filter(func(c):return c[2]==arg.trim_prefix("--boss="))
 if "--unverified"in OS.get_cmdline_user_args():
  var history=JSON.parse_string(FileAccess.get_file_as_string(ACCESS_OUT+"bosses-history.json"))if FileAccess.file_exists(ACCESS_OUT+"bosses-history.json")else{}
  var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
  cases=cases.filter(func(route):var row=history.get("%s:%s:%s:%s"%[route[0],route[2],route[3]if route.size()>3 else 0,mode],{});return row.get("visibility_contract","")!="prepared-original-pages-v1"or row.get("party_presentation_contract","")!="all-required-members-v1"or not row.get("passed",false)or not row.get("retry",{}).get("passed",false)or not row.get("retry",{}).get("portal_walked",false)or route[2]in["zombie","dijiro","lizard"]and not row.get("proximity_approach",false))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--skip="):cases=cases.slice(int(arg.trim_prefix("--skip=")))
  if arg.begins_with("--limit="):cases=cases.slice(0,int(arg.trim_prefix("--limit=")))
 if Array(OS.get_cmdline_user_args()).any(func(arg):return arg.begins_with("--boss="))and "--unverified"not in OS.get_cmdline_user_args():check(not cases.is_empty(),"Explicitly requested boss has a live verification case")
 var ninja_cycles="--ninja-cycles"in OS.get_cmdline_user_args()
 if ninja_cycles:
  cases=cases.filter(func(c):return str(c[2])in["80072","80073","80074"])
  var repeated=[]
  for cycle in 3:
   for route in cases:repeated.append(route.duplicate()+[cycle+1])
  cases=repeated
  check(not cases.is_empty(),"Ninja alternative-cycle verification has original live cases")
 for route in cases:
  var boss_role:String={"5306":"zombie","81012":"lizard","81001":"falken_slot"}.get(str(route[2]),str(route[2]))
  print("EXPLORE_BOSS_CASE ",route)
  var before_failures=failures
  game.player.run_upgrades.damage=10000 if "--phase-review"in OS.get_cmdline_user_args()else 100000
  if is_instance_valid(game.dialogue):game.close_boss_dialogue()
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.explorer_npcs.set_process(false)
  var field_continuous="--field-journey"in OS.get_cmdline_user_args()
  var continuous=field_continuous or room_entry!=Vector2i(-1,-1)
  if field_continuous:
   if not await enter_field_boss_arena(route):continue
  elif room_entry!=Vector2i(-1,-1):await visit_source(route[0],room_entry)
  elif route[0]==0 and route[2]=="5237":
   check(preload("res://scripts/forest/forest_explore_routes.gd").travel(game,100,route[1]),"Original world boss has a published walkable source field")
   for i in 10:await physics_frame
  elif Original.owns(route[0]):await visit_source(route[0],Vector2i(10,52)if route[0]==46041 else route[1])
  else:
   var info=Tour.Indoor.floor_info(route[0],game.model.seed_value)
   Tour.travel(game,Tour.Indoor.layout(route[0]),{"arrival":Tour.Indoor.safe_point(route[0],info[1]+Vector2(route[1])*3.,game.model.seed_value),"yaw":0.,"velocity":Vector3.ZERO})
   for i in 8:await physics_frame
   check(game.model.falan_floor==route[0],"Existing legacy owner loads the boss arena")
  if preload("res://scripts/forest/crowd/east_region_sprites.gd").owns_model(game.model):check(game.crowd.army.presentation.cave_sprites==preload("res://scripts/forest/crowd/east_region_sprites.gd"),"Simulation, textures, contact timelines and death presentation share the same prepared map bank")
  game.player.set_auto_attack(false)
  game.army_runtime.refresh_navigation(0)
  var setup_at=preload("res://scripts/forest/forest_east_region.gd").source_point(100,route[1],game.model.falan_area)if route[0]==0 else Original.source_point(route[0],Vector2i(10,52)if route[0]==46041 else route[1],game.model.seed_value)if Original.owns(route[0])else Tour.Indoor.floor_info(route[0],game.model.seed_value)[1]+Vector2(route[1])*3.
  var proximity=12. if boss_role=="zombie"else 18. if boss_role in["dijiro","lizard"]else 0.
  var trigger_at=setup_at
  if proximity>0:
   var spec=preload("res://scripts/forest/forest_university_region.gd").specification(boss_role,game.model.seed_value)
   trigger_at=Original.source_point(route[0],spec.cell,game.model.seed_value)
  if continuous:check(game.model.falan_floor==route[0],"Continuous player route reaches the original boss arena without a second setup spawn")
  else:check(setup_walkable(trigger_at+Vector2(0,24)if proximity>0 else setup_at,trigger_at,proximity),"Boss test begins on legal player ground outside the original proximity trigger")
  game.explorer_npcs.prepare()
  game.set_process(true);game.set_physics_process(true);game.player.set_physics_process(true);game.explorer_npcs.set_process(true)
  for i in 4:await physics_frame
  game.explore_access.map_token=[];game.explore_access._process(.2)
  if route[0]==46041:
   for step in [[Vector2i(21,8),46042],[Vector2i(7,34),46041]]:
    var source_at=Original.source_point(game.model.falan_floor,step[0],game.model.seed_value)
    var doors=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("floor",-1))==step[1]and link.at.distance_squared_to(source_at)<9.)
    check(not doors.is_empty(),"Original training stairs connect the two source room components")
    if doors.is_empty():break
    await walk_door(doors[0].at)
    for i in 10:await physics_frame
    check(game.model.falan_floor==step[1],"Actual walking follows the original training stairs into the examiner's component")
    if game.model.falan_floor!=step[1]:break
    game.explore_access.map_token=[];game.explore_access._process(.2)
  if boss_role=="falken_slot":
   var seals=game.explore_access.gates.filter(func(g):return g.get("target",-1)==23001 and g.get("landing",Vector2i.ZERO)==Vector2i(23,23))
   check(not seals.is_empty(),"Normal tower landing exposes the named arena seal Cross Gate")
   if not seals.is_empty():
    var scroll=get_meta(Tour.Falken.SCROLL,false)
    await walk_toward(seals[0].at,1200);press_f()
    if is_instance_valid(game.dialogue):
     var options=game.dialogue.pages[0].options.filter(func(o):return o[1]==seals[0].caption)
     if not options.is_empty():game.dialogue.chosen.emit(options[0][0])
    for i in 12:await physics_frame
    check(game.player.position.distance_to(game.model.world_point(Tour.Falken.point(23001,Vector2i(23,23)),.15))<1.,"Actual walk and F cross the seal into the original arena")
    check(get_meta(Tour.Falken.SCROLL,false)==scroll,"Explore arena access does not award the quest scroll")
    game.explore_access.map_token=[];game.explore_access._process(.2)
  var trigger_trace=[];var interaction_direction=Vector2.ZERO
  game.army_runtime.refresh_navigation(0)
  game.explore_access.map_token=[];game.explore_access._process(.2)
  if not route[2].begins_with("new-"):
   var spots=game.explore_access.boss_spots.filter(func(s):return s.get("key","")==route[2]or s.get("actor","")==route[2]or s.get("group","")==route[2]or route[2]in s.get("actors",[]))
   check(not spots.is_empty(),"Scripted boss has a defined marked encounter location "+route[2])
   if not spots.is_empty():
    var spot:Dictionary=spots[0];var station=game.explore_access.safe_station(spot.at)
    if spot.get("manual_begin",false):
     check(is_instance_valid(spot.get("host"))and spot.host.visible and spot.host.multimesh.instance_count==1,"Proximity boss has a visible original waiting model before the player approaches")
     await access_capture("boss-"+str(route[2])+"-waiting")
    var cleared=game.explore_access.encounters.values().filter(func(r):return r.scope==game.explore_access.scope()and r.group==spot.group and r.cleared and r.has("portal"))
    if not cleared.is_empty()and not ninja_cycles:
     await walk_toward(cleared[0].portal,360,true)
     press_f()
     if is_instance_valid(game.dialogue)and game.dialogue.pages[0].options.any(func(o):return o[0]=="retry"):game.dialogue.chosen.emit("retry")
     for i in 20:await physics_frame
     station=game.explore_access.safe_station(spot.at)
    if not station.is_finite():print("BOSS_STATION_BLOCKED ",station_diagnostics(spot.at))
    check(station.is_finite(),"Scripted boss has source-open physical approach "+route[2])
    if station.is_finite():
     var approach_info=Tour.Indoor.floor_info(game.model.falan_floor,game.model.seed_value)if game.model.falan_area=="interior"else[]
     var approach_bits=Tour.Indoor.walk_mask(game.model.falan_floor,approach_info[0],approach_info[2].hex_decode(),game.model.seed_value)if not approach_info.is_empty()else PackedByteArray()
     var approach=station
     for radius in([24.,30.,36.]if proximity>0 else[2.5,4.5,6.,9.,1.5,1.]):
      for direction in 16:
       var point=station+Vector2.from_angle(direction*TAU/16.)*radius
       if proximity>0 and point.distance_to(trigger_at)<proximity+1.:continue
       var world=game.model.world_point(point,.15)
       if not avoids_walk_in_doors(point,station):continue
       if not approach_bits.is_empty()and not Original.open(approach_bits,approach_info[0],Vector2i(((point-approach_info[1])/3.).round())):continue
       if not game.explore_access.body_clear(world)or not game.army_runtime.native.can_reach_ally(world,game.model.world_point(station,.15),.55*game.model.falan_scale):continue
       if not game._ryo_clear_path(world+Vector3.UP*1.2,game.model.world_point(station,1.2)):continue
       approach=point;break
      if approach!=station:break
     if stand_off>0:
      interaction_direction=(Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale-station).normalized()
      if interaction_direction.is_zero_approx():interaction_direction=(approach-station).normalized()
      approach=station+interaction_direction*stand_off
      var approach_world=game.model.world_point(approach,.15)
      check(game.explore_access.body_clear(approach_world)and game.army_runtime.native.can_reach_ally(game.player.position,approach_world,.55*game.model.falan_scale)and game._ryo_clear_path(approach_world+Vector3.UP*1.2,game.model.world_point(station,1.2)),"Normal room approach has legal player-side interaction ground")
     check(approach!=station,"Boss marker has a walk-in approach")
     if not continuous:
      game.player.position=game.model.world_point(approach,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
     var interaction_at=approach if stand_off>0 else station
     await walk_toward(interaction_at,1200 if continuous else 240 if proximity>0 else 90,continuous)
     check(game.player.position.distance_to(game.model.world_point(interaction_at,.15))<1.,"Player movement reaches the marked boss interaction approach")
     if spot.group in["habaru_slot","falken_slot"]:await verify_waiting_host_wall(spot.group)
     game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
     if route[2]in["abyss","azure"]:
      var expected="source:"+("5269"if route[2]=="abyss"else"1102643")
      check(not game.explorer_npcs.nearest.is_empty()and game.explorer_npcs.nearest.record.id==expected,"Player-side prompt selects the original required boss NPC")
      check(is_instance_valid(game.explorer_npcs.hint)and game.explorer_npcs.hint.visible,"Required boss NPC prompt is visible from legal player ground")
     trigger_trace.append(trigger_state("Walked to original trigger"))
     var chest_before=game.exploration_loot.nearest()
     var chest_key=str(game.exploration_loot.slots[chest_before].get("key",""))if chest_before>=0 else ""
     var activated=game.model.enemies.values().any(func(e):return e.hp>0 and game.explore_access.group(e)==spot.group)
     if not activated:press_f()
     trigger_trace.append(trigger_state("Original automatic trigger"if activated else"F"))
     if not activated and not chest_key.is_empty()and game.exploration_loot.opened_chests.has(chest_key)and not is_instance_valid(game.dialogue):
      press_f();trigger_trace.append(trigger_state("F after collecting nearby loot"))
     if is_instance_valid(game.dialogue)and game.dialogue.speaker=="回城傳送門":
      var portals=game.explore_access.encounters.values().filter(func(r):return r.scope==game.explore_access.scope()and r.cleared and r.has("portal"))
      portals.sort_custom(func(a,b):return game.player.position.distance_squared_to(game.model.world_point(a.portal))<game.player.position.distance_squared_to(game.model.world_point(b.portal)))
      var alternatives=game.explore_access.boss_spots.filter(func(s):return s.has("fights")and not portals.is_empty()and s.at.distance_squared_to(portals[0].portal)<4.5*4.5)
      var selected=alternatives.find(spot)
      var options:Array=game.dialogue.pages[0].options
      if selected>=0 and options.any(func(o):return o[0]=="challenge:%d"%selected):game.dialogue.chosen.emit("challenge:%d"%selected)
      elif options.any(func(o):return o[0]=="retry"):game.dialogue.chosen.emit("retry")
     if is_instance_valid(game.dialogue)and game.dialogue.speaker=="選擇挑戰":
      var overlapping=game.explore_access.boss_spots.filter(func(s):return s.has("fights")and s.at.distance_squared_to(station)<5.*5.)
      var selected=overlapping.find(spot)
      if selected>=0:game.dialogue.chosen.emit(str(selected))
      trigger_trace.append(trigger_state("select"))
     if is_instance_valid(game.dialogue) and game.dialogue.speaker=="Cross Gate":
      var challenges=game.dialogue.pages[0].options.filter(func(o):return str(o[0]).begins_with("challenge:"))
      var nearby=game.explore_access.boss_spots.filter(func(s):return s.has("fights")and s.at.distance_squared_to(station)<5.*5. and game.explore_access.gates.any(func(g):return g.at.distance_squared_to(s.at)<4.5*4.5 and g.at.distance_squared_to(station)<5.*5.))
      var selected=nearby.find(spot)
      if selected>=0 and selected<challenges.size():game.dialogue.chosen.emit(challenges[selected][0])
      elif not challenges.is_empty():game.dialogue.chosen.emit(challenges[0][0])
      elif game.dialogue.pages[0].options.any(func(o):return o[0]=="talk"):game.dialogue.chosen.emit("talk")
     if "--diagnose"in OS.get_cmdline_user_args():
      print("BOSS_TRIGGER ",route[2]," at=",station," original=",spot.at," dialogue=",game.dialogue.speaker if is_instance_valid(game.dialogue) else "none"," toast=",game.forest_ui.message)
      print("BOSS_NEARBY_DOORS ",game.model.get_meta("falan_links",[]).filter(func(link):return link.at.distance_squared_to(spot.at)<30.*30.).map(func(link):return {"at":str(link.at),"target":link.get("floor",-1),"arrival":str(link.get("arrival",Vector2.INF)),"walk_in":link.get("walk_in",false),"gate_only":link.get("explore_gate_only",false)}))
     if is_instance_valid(game.dialogue)and game.dialogue.speaker==spot.name:
      await drain()
      var choices:Array=game.dialogue.pages[game.dialogue.page].get("options",[])if is_instance_valid(game.dialogue)else[]
      var answer=str(route[3])if route.size()>3 else "0"
      if choices.any(func(o):return o[0]==answer):game.dialogue.chosen.emit(answer)
      elif choices.any(func(o):return o[0]=="yes"):game.dialogue.chosen.emit("yes")
      else:await drain()
     else:await drain()
     trigger_trace.append(trigger_state("challenge"))
  for i in 15:await physics_frame
  game.model.waves.tick(0.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility();game.explore_access._process(.2)
  var bosses=game.model.enemies.values().filter(func(e):return e.get("boss",false))
  if boss_role=="zombie":bosses=game.model.enemies.values().filter(func(e):return e.get("university_battle","")=="zombie")
  check(not bosses.is_empty(),"Boss appears as a live native actor "+str(route[2]))
  check(not game.forest_ui.message.contains("原始戰鬥模型尚未準備"),"The actual encounter does not offer an unprepared duplicate battle")
  if route[0]in Tour.Winter.Decree.GUARDIAN_FLOORS:
   check(range(1,Tour.Winter.Decree.FLOOR_COUNT+1).all(func(n):return not preload("res://scripts/forest/crowd/east_region_sprites.gd").owns(Tour.Winter.Decree.floor_id(n))),"All sixty recovered cursed floors keep their existing native army owner")
   check(game.crowd.army.presentation.cave_sprites==preload("res://scripts/forest/crowd/cursed_maze_sprites.gd"),"Guardian simulation, bodies, attacks and spell presentation share the existing cursed bank")
   var required=Tour.Winter.Decree.encounters(route[0],game.model.seed_value)
   var formation=game.model.enemies.values().filter(func(e):return e.hp>0 and e.has("frostpass_slot"))
   check(formation.size()==required.size(),"The existing cursed guardian retains every original formation member")
  if route[2]=="81010":
   check(bosses.size()==2 and bosses.all(func(e):return e.has("frostpass_slot")and not e.has("university_battle")),"Both original kings retain their native encounter and spell owner")
   check(game.crowd.army.presentation.cave_sprites==preload("res://scripts/forest/crowd/cursed_maze_sprites.gd"),"The dual kings retain their original native attack, spell and death presentation bank")
  if route[2]=="81002":
   var party=game.model.enemies.values().filter(func(e):return e.has("university_battle"))
   check(party.size()==5,"Sleipnir includes all five mandatory original enemy rows")
   var bypasses=game.explore_access.gates.filter(func(g):return g.get("actor","")=="restricted_door"and int(g.get("target",0))==16512)
   check(bypasses.size()==1 and game.explore_access.boss_spots.any(func(s):return s.get("actor","")=="81002"and s.at.distance_squared_to(bypasses[0].at)>=6.*6.),"The one Explore seal gate stands beside the marked boss")
   var gems=game.world.map_features.find_children("BlueCGYellowDiamond","AnimatedSprite3D",true,false)
   check(gems.all(func(gem):return gem.get_parent().get_parent().is_queued_for_deletion()or gem.get_parent().get_parent()==game.explore_access.gate_visuals),"Restricted entrances have one Explore visual owner instead of overlapping native markers")
   check(bosses.any(func(e):return e.get("enemy_name","")=="神兽史雷普尼尔"),"Sleipnir keeps its original encounter name when an appearance has multiple source roles")
   check(party.all(func(e):return not e.has("frostpass_slot")),"The complete source party replaces the former standalone horse owner")
  check(bosses.all(func(e):return boss_pages_ready(e)),"Every live boss uses its prepared original body texture pages")
  check(bosses.any(func(e):var proxy=game.army_runtime.enemy_target(e.id);return game.army_runtime.handles.has(e.id)and proxy!=null and game.forest_enemy_visible(proxy)),"Marked boss has an in-world native body in revealed arena ground")
  var record={"map":route[0],"boss":route[2],"choice":route[3]if route.size()>3 else 0,"initial_members":game.model.enemies.size(),"bosses":bosses.map(func(e):return e.get("enemy_name","")),"ordinary_F":route[2]in["altar","5320"]or "--matrix"in OS.get_cmdline_user_args(),"qualification":"Temporary hero invulnerability/damage boost; original enemy counts, phases, damage and timing retained."}
  if field_continuous:
   record.field_route=field_route_trace.duplicate(true)
   record.setup_contract="one-field-setup-then-walk-f-v1"
  elif room_entry!=Vector2i(-1,-1):
   record.setup_contract="one-room-entry-setup-then-walk-f-v1";record.room_entry=str(room_entry);record.stand_off=stand_off
  record.activation=route[4]if route.size()>4 else 0
  record.source=100 if route[0]==0 and route[2]=="5237"else Original.source_id(route[0])
  if str(route[2])in["5595","5596","5597"]:
   var aliases=game.explorer_npcs.actors.filter(func(entry):return str(route[2])in entry.get("battle_aliases",[]))
   record.waiting_aliases=aliases.map(func(entry):return {"actor":entry.record.id,"visible":entry.node.is_visible_in_tree()})
   check(aliases.size()==4 and aliases.all(func(entry):return not entry.node.is_visible_in_tree()),"All co-located original TuTu waiting copies hide while the selected original fight is active")
  record.production_sources=production_sources
  record.visibility_contract="prepared-original-pages-v1"
  record.party_presentation_contract="all-required-members-v1"
  record.proximity_approach=proximity>0
  record.trigger_trace=trigger_trace
  record.presentation_blockers=get_meta("explore_boss_presentation_blockers",{})
  record.diagnostics={"floor":game.model.falan_floor,"source":game.model.waves.patrol_source.resource_path,"endpoint":str(game.explore_access.endpoint),"endpoint_blocker":game.model.get_meta("explore_endpoint_blocker",{}),"spots":str(game.explore_access.boss_spots),"east_blockers":get_meta("east_battle_blockers",{}),"dialogue":game.dialogue.speaker if is_instance_valid(game.dialogue) else "closed"}
  record.diagnostics.gates=game.explore_access.gates.map(func(g):return {"at":str(g.at),"target":g.get("target",-1),"actor":g.get("actor","")})
  record.diagnostics.placement_adjustments=game.model.get_meta("explore_boss_placement_adjustments",{})
  record.diagnostics.diamonds=game.world.map_features.find_children("BlueCGYellowDiamond","AnimatedSprite3D",true,false).map(func(node):return {"path":str(node.get_path()),"at":str(node.global_position)})
  if bosses.is_empty()or game.paused:
   record.passed=false;record.diagnostics.options=game.dialogue.pages[game.dialogue.page].get("options",[])if is_instance_valid(game.dialogue)else[]
   boss_report.append(record);save_boss_report();continue
  if route[0]==15518:
   var cow_skin=int(preload("res://scripts/forest/crowd/east_region_sprites.gd").data().species.filter(func(s):return int(s.id)==101921)[0].skin)
   check(game.model.enemies.values().any(func(e):return int(e.get("skin",-1))==cow_skin and game.army_runtime.handles.has(e.id)and game.forest_enemy_visible(game.army_runtime.enemy_target(e.id))),"Original cow has a visible native in-world body beside Alubass")
  if not bosses.is_empty():aim_camera_at(game.army_runtime.enemy_target(bosses[0].id))
  await access_capture("boss-"+str(route[2])+"-active")
  var fight_key=""if bosses.is_empty()else game.explore_access.group(bosses[0])
  if fight_key.begins_with("regional:east:"):
   var selected=preload("res://scripts/forest/forest_east_battles.gd").specification(fight_key.trim_prefix("regional:"))
   record.selected_encounter=int(selected.get("encounter",-1))
   if ninja_cycles:check(str(route[2])in selected.get("actors",[]),"The intended original ninja owns this activated party")
  if not bosses.is_empty()and stand_off<=0:await approach_boss(Vector2(bosses[0].pos.x,bosses[0].pos.z)/game.model.falan_scale)
  game.explore_access._process(.2)
  var discovered=game.explore_access.encounters.values().filter(func(r):return r.scope==game.explore_access.scope()and r.group==fight_key and r.discovered and not r.cleared)
  check(not discovered.is_empty()and game.explore_access.pins().any(func(pin):return pin.label.begins_with("⚔ 未擊敗")and discovered.any(func(r):return r.at==pin.at)),"Approaching the visible live boss exposes its undefeated Explore map/minimap pin")
  await fight_with_player_inputs(fight_key,record)
  await wait_for_portal(fight_key)
  game.explore_access._process(.2)
  var returns=game.explore_access.encounters.values().filter(func(r):return r.scope==game.explore_access.scope() and r.group==fight_key and r.cleared and r.has("portal"))
  var portals=returns.map(func(r):return {"at":r.portal})
  if portals.is_empty():await access_capture("boss-"+str(route[2])+"-unresolved")
  record.living_arena=survivors("")
  record.owner_state={"floor":game.model.falan_floor,"area":game.model.falan_area,"scope":game.explore_access.scope(),"encounter_scopes":game.explore_access.encounters.values().map(func(r):return [r.scope,r.group,r.cleared,r.pending]),"phase":game.model.phase,"spawned":game.model.waves.spawned,"grave_slain":get_meta("grave_slain",{}),"spawn_blocker":game.model.get_meta("explore_boss_spawn_blocker",{}),"patrol_posts":game.model.waves.patrol_posts.size()}
  record.owner_state.placement_adjustments=str(game.model.get_meta("explore_boss_placement_adjustments",{}))
  record.owner_state.hero=str(game.player.position);record.owner_state.hero_native_clear=game.army_runtime.native.can_reach_ally(game.player.position,game.player.position,.55*game.model.falan_scale)
  record.owner_state.stations=game.explore_access.encounters.values().filter(func(r):return r.scope==game.explore_access.scope()).map(func(r):var world=game.model.world_point(r.at,.15);return {"at":str(r.at),"native_clear":game.army_runtime.native.can_reach_ally(world,world,.55*game.model.falan_scale),"physical_clear":game.explore_access.body_clear(world),"player_reach":game.army_runtime.native.can_reach_ally(game.player.position,world,.55*game.model.falan_scale),"safe_station":str(game.explore_access.safe_station(r.at))})
  record.encounters=game.explore_access.encounters.values().filter(func(r):return r.scope==game.explore_access.scope()).map(func(r):return {"group":r.group,"cleared":r.cleared,"pending":r.pending,"portal":r.get("portal",null),"portal_pending":r.get("portal_pending",false),"superseded":r.get("superseded",false)})
  check(portals.size()==1,"Complete encounter produces one optional return portal "+str(route[2]))
  if route[2]=="81002":check(get_meta("frostpass_slain",{}).has(Vector2i(16511,0)),"Complete source victory opens the preserved original guardian seal")
  if route[2]=="81010":check(Tour.Winter.Decree.cleared(get_meta("frostpass_slain",{}),game.model.falan_floor,game.model.seed_value),"Complete dual-king source victory opens the preserved original final decree seal")
  if not returns.is_empty():
   check(game.explore_access.pins().any(func(p):return p.label.begins_with("✓ 已擊敗")and p.at==returns[0].at),"Discovered boss pin changes to cleared after complete victory")
   if route[0]in Tour.Winter.Decree.GUARDIAN_FLOORS:
    check(not game.explore_access.pins().any(func(pin):return pin.label.begins_with("⚔ 未擊敗")),"Completed native guardian has no duplicate undefeated Explore pin")
    check(Tour.Winter.Decree.cleared(get_meta("frostpass_slain",{}),game.model.falan_floor,game.model.seed_value),"Full native guardian victory preserves its ordinary seal ledger")
   check(game.exploration_loot.slots.filter(func(s):return s.active and s.get("key","")==returns[0].chest_key).size()==1,"Complete victory creates one reachable weapon chest generation")
  record.remaining=game.model.enemies.size();record.portals=portals.size()
  if not portals.is_empty():
   var at:Vector2=portals[0].at
   var path_start=game.explore_access.player_path_start()
   check(path_start.is_finite()and game.army_runtime.native.can_reach_ally(path_start,game.model.world_point(at,.15),.55*game.model.falan_scale),"Victory portal is player-reachable "+str(route[2]))
   await walk_toward(at,360,true)
   check(game.player.position.distance_to(game.model.world_point(at,.15))<1.,"Actual player movement reaches the victory portal "+str(route[2]))
   record.portal_arrival=trigger_state("Walked to victory portal")
   for i in 180:await physics_frame
   record.portal_wait=trigger_state("Stayed beside victory portal while looting")
   if str(route[2])in["5595","5596","5597"]:
    var aliases=game.explorer_npcs.actors.filter(func(entry):return str(route[2])in entry.get("battle_aliases",[]))
    check(aliases.size()==4 and aliases.all(func(entry):return entry.node.is_visible_in_tree()),"Co-located original waiting copies return after full victory without moving the NPCs")
   # Inspect the small in-world portal from an actual nearby walking position.
   for direction in 16:
    var view_at=at+Vector2.from_angle(direction*TAU/16.)*4.5
    var world=game.model.world_point(view_at,.15)
    if not avoids_walk_in_doors(Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale,view_at):continue
    if not game.explore_access.body_clear(world)or not game.army_runtime.native.can_reach_ally(game.player.position,world,.55*game.model.falan_scale):continue
    if not game._ryo_clear_path(world+Vector3.UP*1.2,game.model.world_point(at,1.2)):continue
    await walk_toward(view_at,180,true)
    if game.player.position.distance_to(world)>1.:continue
    var toward=at-Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
    game.camera_rig.yaw=atan2(-toward.x,-toward.y)
    for i in 6:await physics_frame
    await access_capture("boss-"+str(route[2])+"-portal-approach")
    verify_portal_caption(record,returns[0])
    await walk_toward(at,180,true)
    break
   await access_capture("boss-"+str(route[2])+"-portal")
   if "--portal-pair-review"in OS.get_cmdline_user_args():await verify_portal_pair(record,returns[0])
   var automatic=game.explore_access.boss_spots.filter(func(s):return s.group==fight_key and s.get("record",{}).get("type","")=="StandEnemy")
   if not automatic.is_empty():
    var count_before=returns[0].victories
    game.set_meta("east_auto_cooldown",{})
    if continuous:await walk_toward(automatic[0].at,1200,true)
    else:
     game.player.position=game.model.world_point(automatic[0].at,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
    for i in 12:await physics_frame
    load("res://scripts/forest/forest_east_region.gd").tick(game,.2)
    check(returns[0].cleared and returns[0].has("portal") and returns[0].victories==count_before,"Expired original trigger cooldown does not restart a cleared fight during looting")
    if continuous:await walk_toward(at,1200,true)
    else:
     game.player.position=game.model.world_point(at,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
   if "--victory-exits"in OS.get_cmdline_user_args()and not returns[0].get("win",[]).is_empty():
    record.victory_exit=await walk_victory_exit(returns[0],route,record)
    if not record.victory_exit:record.passed=false;boss_report.append(record);save_boss_report();continue
    await walk_toward(returns[0].portal,600,true)
   if route[2]=="ruby_slot"and "--portal-priority-review"in OS.get_cmdline_user_args():
    var chests=game.exploration_loot.slots.filter(func(s):return s.active and s.get("key","")==returns[0].chest_key)
    check(chests.size()==1,"Portal-priority review uses the actual earned boss chest")
    if not chests.is_empty():
     var position=game.model.world_point(returns[0].portal,.05)
     chests[0].pos=position+(game.player.position-position).normalized()*.00001
     var chest_distance=game.player.position.distance_squared_to(chests[0].pos)
     var portal_distance=game.explore_access.interaction_distance_squared()
     check(chest_distance<portal_distance and absf(chest_distance-portal_distance)<.0001,"Co-located earned chest reproduces only a rounding-sized interaction distance difference")
   var earned=returns[0].victories
   if stand_off>0:
    await walk_toward(at+interaction_direction*minf(3.5,stand_off),600,true)
    check(game.player.position.distance_to(game.model.world_point(at,.15))<4.*game.model.falan_scale,"Retry uses a legal nearby player-side portal interaction")
   record.before_retry=trigger_state("Before retry F")
   press_f()
   record.retry_prompt=trigger_state("Victory portal retry")
   check(is_instance_valid(game.dialogue) and game.dialogue.pages[0].options.any(func(o):return o[0]=="retry"),"Victory portal exposes the original encounter retry")
   if route[2]=="ruby_slot"and "--portal-priority-review"in OS.get_cmdline_user_args():
    for reward in["boss","food","elite"]:
     if reward!="boss":
      check(game.exploration_loot.spawn_chest(0,game.model.world_point(returns[0].portal,.05),"portal-review:"+reward,false,reward=="elite"),"Set up a nearby "+reward+" chest on earned portal ground")
      game.close_boss_dialogue();press_f()
     var expected="開啟 Boss 武器寶箱"if reward=="boss"else"開啟 精英寶箱"if reward=="elite"else"開啟 食物寶箱"
     check(is_instance_valid(game.dialogue)and game.dialogue.pages[0].options.any(func(o):return o[0]=="loot"and o[1]==expected),"Portal menu keeps nearby "+reward+" loot accessible")
     if is_instance_valid(game.dialogue):game.dialogue.chosen.emit("loot")
     check(returns[0].cleared and returns[0].has("portal")and returns[0].victories==earned,"Collecting "+reward+" loot keeps the earned return portal")
     press_f()
     check(is_instance_valid(game.dialogue)and game.dialogue.speaker=="回城傳送門"and game.dialogue.pages[0].options.any(func(o):return o[0]=="retry"),"Actual F still offers the portal after collecting "+reward+" loot")
   if is_instance_valid(game.dialogue):game.dialogue.chosen.emit("retry")
   record.retry_trace=[trigger_state("After selecting retry")]
   if fight_key in["habaru_slot","falken_slot"]:
    var hosts=game.explore_access.boss_spots.filter(func(s):return s.group==fight_key)
    if not hosts.is_empty():
     await walk_toward(hosts[0].at+Vector2(0,5),600)
     for i in 6:await physics_frame
     record.retry_trace.append(trigger_state("Walked to waiting retry boss"))
     record.retry_trace[-1].merge({"habaru_talk":game.can_talk_habaru(),"falken_talk":game.can_talk_falken(),"falken_seen":game.falken_dialogue_seen,"falken_slain":get_meta(Tour.Falken.SLAIN,{}),"falken_host":str(game.falken_waiting.global_position)if is_instance_valid(game.falken_waiting)else"missing","chest":game.exploration_loot.nearest()})
     press_f();record.retry_trace.append(trigger_state("F at retry boss"))
     if is_instance_valid(game.dialogue)and game.dialogue.speaker=="Cross Gate"and game.dialogue.pages[0].get("options",[]).any(func(o):return o[0]=="talk"):game.dialogue.chosen.emit("talk")
     await drain()
     record.retry_trace.append(trigger_state("Finished retry conversation"))
   for i in 20:await physics_frame
   game.model.waves.tick(0.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility();game.explore_access._process(.2)
   var retry_party=game.model.enemies.values().filter(func(e):return e.hp>0 and game.explore_access.member(e,fight_key))
   check(not retry_party.is_empty()if boss_role=="zombie"else retry_party.any(func(e):return e.get("boss",false)),"Retry visibly spawns the native boss again")
   check(not returns[0].cleared and not returns[0].has("portal"),"Retry removes the previous cleared portal")
   if not retry_party.is_empty()and stand_off<=0:await approach_boss(Vector2(retry_party[0].pos.x,retry_party[0].pos.z)/game.model.falan_scale)
   var retry_record={"boss":route[2],"choice":record.choice,"attempt":"retry","activation":record.activation}
   await fight_with_player_inputs(fight_key,retry_record);game.explore_access._process(.2)
   await wait_for_portal(fight_key,earned+1)
   check(returns[0].cleared and returns[0].has("portal") and returns[0].victories==earned+1,"Later full victory earns one fresh portal and chest generation")
   record.retry={"passed":returns[0].cleared and returns[0].get("victories",0)==earned+1,"attack_inputs":retry_record.attack_inputs,"native_ids":retry_record.targeted_native_ids,"observations":retry_record.input_observations,"last_input":retry_record.get("last_input",{}),"phase_views":retry_record.get("phase_views",[]),"retinue_guard_checked":retry_record.get("retinue_guard_checked",false),"guards_after_boss":retry_record.get("guards_after_boss",[]),"remaining":survivors(fight_key),"record":str(returns[0])}
   if returns[0].has("portal"):
    await walk_toward(returns[0].portal,360,true)
    record.retry.portal_walked=game.player.position.distance_to(game.model.world_point(returns[0].portal,.15))<1.
    check(record.retry.portal_walked,"Actual movement reaches the later victory portal")
   var gold=game.model.gold;var items:Dictionary=get_meta("university_quest_items",{}).duplicate(true);var checkpoint=game.checkpoint
   press_f()
   if is_instance_valid(game.dialogue)and game.dialogue.speaker=="回城傳送門":game.dialogue.chosen.emit("return")
   for i in 8:await physics_frame
   check(Tour.area(game.model)=="city"and game.player.position.distance_to(game.model.world_point(game.explore_access.HOSPITAL_LANDING,.15))<.5,"Actual F portal returns to exact east hospital "+str(route[2]))
   check(gold==game.model.gold and items==get_meta("university_quest_items",{})and checkpoint==game.checkpoint,"Return preserves gold/items/home checkpoint "+str(route[2]))
  record.passed=before_failures==failures;boss_report.append(record);save_boss_report()
 if ninja_cycles:
  var proof=[];var actors=[]
  for row in boss_report:
   if row.boss not in actors:actors.append(row.boss)
  for actor in actors:
   var rows=boss_report.filter(func(r):return r.boss==actor)
   var drawn=rows.map(func(r):return int(r.get("selected_encounter",-1)));var sorted_draws=drawn.duplicate();sorted_draws.sort()
   var passed=sorted_draws==[9034,9035,9036]
   check(passed,"Three actual activations draw every original ninja alternative once without replacement")
   for row in rows:row.selection_bag_passed=passed;row.passed=row.passed and passed
   proof.append({"actor":actor,"draws":drawn,"expected":[9034,9035,9036],"passed":passed})
  var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
  var file=FileAccess.open(ACCESS_OUT+"ninja-selection-cycles-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"source_proof":"assets/references/standenemy-selection.json","cycles":proof},"  "));file.close()
  save_boss_report()
 print("EXPLORE_BOSSES_RESULT checks=",checks," failures=",failures)
 finish()


func enter_field_boss_arena(route:Array)->bool:
 var before=failures;field_route_trace=[]
 game.player.set_auto_attack(false)
 var site_id=int({15505:410,16503:16501,47017:47010}.get(int(route[0]),-1))
 var sites=Tour.Regions.Sites.SITES.filter(func(site):return int(site[2])==site_id)
 check(sites.size()==1,"Continuous native boss route has an authenticated original field entrance")
 if sites.size()!=1:return false
 var site:Array=sites[0];var area=Tour.Regions.canonical_area(site[0]);var at:Vector2=Tour.Regions.frame(area).inverse()*site[4]
 var road_start=Tour.Regions.entry_point(area)+Vector2(0,-9)if site_id==47010 else at
 Tour.travel(game,Tour.outdoor_layout(get_meta("falan_venture"),area),{"arrival":road_start,"yaw":0.,"velocity":Vector3.ZERO,"preserve_checkpoint":true})
 for i in 10:await physics_frame
 var direction:Vector2=Tour.Regions.frame(area).inverse().basis_xform(site[5]).normalized()
 check(setup_walkable(road_start if site_id==47010 else at-direction*12.),"One initial field setup is on legal ground outside the original entrance")
 game.set_process(true);game.set_physics_process(true);game.player.set_physics_process(true);game.explorer_npcs.set_process(true)
 game.army_runtime.refresh_navigation(0);game.explore_access.map_token=[];game.explore_access._process(.2)
 field_route_trace.append({"stage":"Initial field setup","area":Tour.area(game.model),"floor":game.model.falan_floor,"at":str(game.player.position)})
 var gold=game.model.gold;var items=get_meta("university_quest_items",{}).duplicate(true);var quests=game.settings.explorer_quests.duplicate(true);var home=game.checkpoint
 if site_id in preload("res://scripts/forest/forest_explore_routes.gd").RESTORED_FIELD_SITES:
  var target=site_id if site_id in[410,47010]else 16503
  var gates=game.explore_access.gates.filter(func(gate):return int(gate.get("target",-1))==target)
  check(gates.size()==1,"Original field approach exposes one named restored dungeon Cross Gate")
  if gates.is_empty():return false
  await walk_toward(gates[0].at,1200,true)
  check(game.player.position.distance_to(game.model.world_point(gates[0].at,.15))<1.,"Actual walking reaches the restored field entrance")
  press_f()
  if is_instance_valid(game.dialogue)and game.dialogue.speaker=="Cross Gate":
   var choices=game.dialogue.pages[0].get("options",[]).filter(func(option):return option[1]==gates[0].caption)
   if not choices.is_empty():game.dialogue.chosen.emit(choices[0][0])
  for i in 12:await physics_frame
  check(game.model.falan_floor==target,"Actual field-gate interaction enters the original intended dungeon")
  check(game.model.gold==gold and get_meta("university_quest_items",{})==items and game.settings.explorer_quests==quests and game.checkpoint==home,"Taking the Explore field gate preserves gold, quest items, quest flags and home")
 field_route_trace.append({"stage":"Entered from field","area":Tour.area(game.model),"floor":game.model.falan_floor,"at":str(game.player.position)})
 if site_id==410:
  var stairs=game.model.get_meta("falan_links",[]).filter(func(door):return int(door.get("floor",-1))==15505)
  check(not stairs.is_empty(),"Original Zombie B1 retains its onward stair to the original boss arena")
  if stairs.is_empty():return false
  check(await walk_door(stairs[0].at),"Actual walking crosses Zombie B1 and its original onward stair")
  for i in 12:await physics_frame
  field_route_trace.append({"stage":"Original Zombie B1 onward stair","area":Tour.area(game.model),"floor":game.model.falan_floor,"at":str(game.player.position)})
 if site_id==47010:
  for target in[2803000,47011,2804000,47013,2805000,47014,2806000,47017]:
   var source_floor=game.model.falan_floor
   var stairs=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("floor",-1))==target)
   check(not stairs.is_empty(),"Complete original Imur route retains its onward stair %d → %d"%[source_floor,target])
   if stairs.is_empty():return false
   check(await walk_door(stairs[0].at),"Actual walking follows original Imur forest/maze stair %d → %d"%[source_floor,target])
   for i in 12:await physics_frame
   check(game.model.falan_floor==target,"Original Imur onward stair enters the intended map "+str(target))
   field_route_trace.append({"stage":"Original forest/maze stair","area":Tour.area(game.model),"floor":game.model.falan_floor,"at":str(game.player.position)})
   print("IMUR_CONTINUOUS_STAIR ",field_route_trace[-1])
   if failures>before:return false
 check(game.model.falan_floor==int(route[0]),"Continuous normal route reaches its actual original boss arena")
 # Ordinary source stairs retain their normal arrival checkpoint; portal preservation is checked separately.
 check(game.model.gold==gold and get_meta("university_quest_items",{})==items and game.settings.explorer_quests==quests,"Walking the original dungeon route awards no gold, quest items or quest flags")
 print("EXPLORE_FIELD_BOSS_ROUTE ",field_route_trace)
 return failures==before

func walk_victory_exit(record:Dictionary,route:Array,evidence:Dictionary)->bool:
 var before_failures=failures;var access=game.explore_access;var win:Array=record.win
 var gates=access.gates.filter(func(g):return g.get("actor","")=="victory"and int(g.target)==int(win[0])and g.landing==Vector2i(win[1],win[2]))
 check(gates.size()==1,"Full victory exposes one named original destination exit")
 if gates.is_empty():return false
 var gate:Dictionary=gates[0];var source_area=game.model.falan_area;var source_floor=game.model.falan_floor
 var gold=game.model.gold;var items:Dictionary=get_meta("university_quest_items",{}).duplicate(true);var quests=game.settings.explorer_quests.duplicate(true);var checkpoint=game.checkpoint
 await walk_toward(gate.at,600)
 evidence.victory_exit_trace=[trigger_state("Walked to victory exit")]
 evidence.victory_exit_trace[-1].gate=str(gate)
 check(game.player.position.distance_to(game.model.world_point(gate.at,.15))<1.,"Player walks to the original post-victory exit")
 var before_model=game.model.get_instance_id();press_f()
 evidence.victory_exit_trace.append(trigger_state("F at victory exit"))
 if is_instance_valid(game.dialogue):
  var options=game.dialogue.pages[0].get("options",[]).filter(func(o):return o[1]==gate.caption)
  if not options.is_empty():game.dialogue.chosen.emit(options[0][0])
 for i in 10:await physics_frame
 evidence.victory_exit_trace.append(trigger_state("After victory exit selection"))
 evidence.victory_exit_trace[-1].merge({"floor":game.model.falan_floor,"area":game.model.falan_area,"model_changed":game.model.get_instance_id()!=before_model})
 var entered=game.model.get_instance_id()!=before_model and destination_matches(int(win[0]))
 check(entered,"Actual F enters the original post-victory destination")
 if entered:
  game.explore_access._process(.2)
  var backs=game.explore_access.gates.filter(func(g):return g.get("back",false))
  check(backs.size()==1,"Post-victory destination has a reachable return Cross Gate")
  if not backs.is_empty():
   await walk_toward(backs[0].at,240);press_f()
   if is_instance_valid(game.dialogue):
    var options=game.dialogue.pages[0].get("options",[]).filter(func(o):return o[1]==backs[0].caption)
    if not options.is_empty():game.dialogue.chosen.emit(options[0][0])
   for i in 10:await physics_frame
 check(game.model.falan_area==source_area and game.model.falan_floor==source_floor,"Actual return interaction restores the cleared arena")
 check(game.model.gold==gold and get_meta("university_quest_items",{})==items and game.settings.explorer_quests==quests and game.checkpoint==checkpoint,"Optional victory exit preserves gold, items, quest state and home")
 var passed=before_failures==failures
 var rows=preload("res://scripts/forest/forest_explore_routes.gd").data().get(str(Original.source_id(source_floor)),[])
 var matches=rows.filter(func(r):return r.get("victory_only",false)and int(r.target)==int(win[0])and Vector2i(r.landing[0],r.landing[1])==Vector2i(win[1],win[2])and str(r.actor)==str(route[2]))
 save_routes(matches.map(func(r):return {"source":int(r.source),"runtime":source_floor,"cell":str(Vector2i(r.cell[0],r.cell[1])),"target":int(r.target),"landing":str(Vector2i(r.landing[0],r.landing[1])),"status":"Walked named exit after full victory and returned to arena","after_full_victory":true,"verified_transition":entered and passed,"passed":passed}))
 return passed

func fight_with_player_inputs(fight_key:String,record:Dictionary):
 var attack_inputs=0;var target_ids={}
 var last_health="";var stagnant_inputs=0
 record.input_observations=[];record.seen_boss_ids=[];record.seen_member_ids=[];record.tab_inputs=0
 var retinue_guard=fight_key=="frostpass_slot"and game.model.falan_floor in Tour.Winter.Decree.GUARDIAN_FLOORS.slice(0,-1)
 var earned_chests=game.exploration_loot.slots.filter(func(slot):return slot.active and slot.get("boss",false)).map(func(slot):return slot.key)
 if retinue_guard:record.retinue_guard_checked=false
 for tick in 3600:
  var living=game.model.enemies.values().filter(func(e):return e.hp>0 and (fight_key.is_empty()or game.explore_access.member(e,fight_key)))
  if living.is_empty():
   for i in 8:await physics_frame
   living=game.model.enemies.values().filter(func(e):return e.hp>0 and (fight_key.is_empty()or game.explore_access.member(e,fight_key)))
   if living.is_empty():break
  if retinue_guard and not record.retinue_guard_checked and not living.any(func(e):return e.get("boss",false)):
   for i in 20:await physics_frame
   var guards=game.model.enemies.values().filter(func(e):return e.hp>0 and game.explore_access.member(e,fight_key))
   check(not guards.is_empty(),"Boss-first actual attacks leave original guards alive for the early-victory check")
   check(not Tour.Winter.Decree.cleared(get_meta("frostpass_slain",{}),game.model.falan_floor,game.model.seed_value),"Original guardian exit remains sealed while its required formation survives")
   check(not game.explore_access.encounters.values().any(func(r):return r.scope==game.explore_access.scope()and r.group==fight_key and r.cleared and r.has("portal")),"Killing only the guardian cannot create a return portal while guards remain")
   check(game.exploration_loot.slots.filter(func(slot):return slot.active and slot.get("boss",false)).all(func(slot):return slot.key in earned_chests),"No new boss weapon chest is earned while required guards remain")
   record.retinue_guard_checked=true;record.guards_after_boss=guards.map(func(e):return e.id);living=guards
  for enemy in living:
   if enemy.id not in record.seen_member_ids:
    check(game.army_runtime.enemy_target(enemy.id)!=null and boss_pages_ready(enemy),"Every required encounter member has its original prepared native body")
    record.seen_member_ids.append(enemy.id)
   if enemy.get("boss",false)and enemy.id not in record.seen_boss_ids:
    var body=game.army_runtime.enemy_target(enemy.id)
    check(body!=null and game.army_runtime.handles.has(enemy.id),"Each required boss phase enters the shared native presentation")
    check(body!=null and game.forest_enemy_visible(body),"Each required boss phase has a visible in-world body")
    check(boss_pages_ready(enemy),"Each required boss phase has its original texture pages prepared")
    record.seen_boss_ids.append(enemy.id)
    if "--phase-review"in OS.get_cmdline_user_args():
     aim_camera_at(body)
     if not boss_camera_hit(body).is_empty():
      await walk_to_clear_shot(body)
      aim_camera_at(body)
     if "--canopy-review"in OS.get_cmdline_user_args():
      var materials=game.world.fog_materials.filter(func(mat):return preload("res://scripts/forest/forest_wind_meadow_art.gd").recovered_canopy(mat))
      record.canopy_bindings=materials.map(func(mat):return {"shader":mat.shader.resource_path,"hero":str(mat.get_shader_parameter("hero_position")),"cutaway":mat.get_shader_parameter("canopy_cutaway")})
      check(not materials.is_empty()and materials.all(func(mat):return mat.get_shader_parameter("canopy_cutaway")==true and mat.get_shader_parameter("hero_position")==Vector2(game.model.hero_position.x,game.model.hero_position.z)),"Recovered leaves receive the live player position and existing combat cutaway")
     var hit=boss_camera_hit(body)
     var physical=preload("res://scripts/attack_chain.gd").world_ray(game,game.camera_rig.camera.global_position,preload("res://scripts/attack_chain.gd").aim_point(body))
     record.get_or_add("phase_views",[]).append({"boss_id":enemy.id,"hero":str(game.player.position),"body":str(body.global_position),"camera":str(game.camera_rig.camera.global_position),"obstacle":str(hit.collider.get_path())if not hit.is_empty()else"clear","physical_obstacle":str(physical.collider.get_path())if not physical.is_empty()else"clear","water_only_navigation_boundary":not physical.is_empty()and physical.collider.get_meta(preload("res://scripts/forest/forest_original_water_camera.gd").WATER_BOUNDARY,false),"camera_excludes_physical_obstacle":not physical.is_empty()and physical.collider.get_rid()in game.camera_rig.water_camera.probe.exclude})
     check(hit.is_empty(),"Rendered boss phase is unobstructed from the normal camera after actual player approach")
     var activation="-activation-%d"%int(record.activation)if int(record.get("activation",0))>0 else""
     await access_capture("boss-%s-choice-%s%s-%s-phase-%s"%[record.get("boss","retry"),record.get("choice",0),activation,record.get("attempt","initial"),record.seen_boss_ids.size()])
  if tick%30==0:
   var health=JSON.stringify(living.map(func(e):return [e.id,e.hp]))
   stagnant_inputs=stagnant_inputs+1 if health==last_health else 0;last_health=health
   if stagnant_inputs>=20:record.no_progress=true;break
   var targets=living.filter(func(e):return e.get("boss",false))if retinue_guard and living.any(func(e):return e.get("boss",false))else living
   var nearest=targets[0]
   for e in targets:
    var body=game.army_runtime.enemy_target(e.id);var previous=game.army_runtime.enemy_target(nearest.id)
    if body!=null and previous!=null and body.global_position.distance_squared_to(game.player.position)<previous.global_position.distance_squared_to(game.player.position):nearest=e
   var current_body=game.army_runtime.enemy_target(nearest.id)
   var current_at:Vector3=current_body.global_position if current_body!=null else nearest.pos
   if current_at.distance_to(game.player.position)>6.*game.model.falan_scale:
    var target=Vector2(current_at.x,current_at.z)/game.model.falan_scale
    var from=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
    await walk_toward(target+(from-target).normalized()*3.5,120)
   var proxy=game.army_runtime.enemy_target(nearest.id)
   if proxy!=null:
    game.camera_rig.yaw=atan2(game.player.position.x-proxy.global_position.x,game.player.position.z-proxy.global_position.z);game.camera_rig.reset_follow()
    for i in 4:game.camera_rig.update_camera(1./60.)
    var aim=preload("res://scripts/attack_chain.gd").aim_point(proxy)
    game.camera_rig.camera.look_at(aim)
    if game.enemy_near_crosshair(120.)==null:
     await walk_to_clear_shot(proxy)
     proxy=game.army_runtime.enemy_target(nearest.id)
     if proxy==null:await physics_frame;continue
     game.camera_rig.reset_follow()
     for i in 4:game.camera_rig.update_camera(1./60.)
     game.camera_rig.camera.look_at(preload("res://scripts/attack_chain.gd").aim_point(proxy))
     if game.enemy_near_crosshair(120.)==null:
      var select=InputEventKey.new();select.physical_keycode=KEY_TAB;select.pressed=true;game._input(select);record.tab_inputs+=1
    var screen=game.crosshair_screen_position()
    var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=screen;release.global_position=screen;release.pressed=false;game.player._input(release)
    var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=screen;click.global_position=screen;click.pressed=true;game.player._unhandled_input(click)
    var picked=game.enemy_near_crosshair(120.);var selected=game.player.active_ability.selected_primary_enemy()
    record.last_input={"target":nearest.id,"hero":str(game.player.position),"target_at":str(nearest.pos),"on_floor":game.player.is_on_floor(),"playing":game.playing,"paused":game.paused,"transitioning":game.transitioning,"visible":game.forest_enemy_visible(proxy),"picked":picked.forest_id if picked!=null else -1,"mode":game.player.active_ability.mode,"selected":selected!=null,"selected_id":selected.forest_id if selected!=null else -1,"proxy_at":str(proxy.global_position),"bounds":str(proxy.combat_bounds()),"query_shapes":proxy.find_children("*","CollisionShape3D",false,false).map(func(shape):return [str(shape.global_position),str(shape.shape.get_debug_mesh().get_aabb())]),"attack_line":preload("res://scripts/attack_chain.gd").clear_line(game,game.player.position+Vector3.UP*1.2,aim),"camera_line":preload("res://scripts/attack_chain.gd").clear_line(game,game.camera_rig.camera.global_position,aim)}
    var camera_hit=preload("res://scripts/attack_chain.gd").world_ray(game,game.camera_rig.camera.global_position,aim)
    record.last_input.camera_obstacle={"path":str(camera_hit.collider.get_path()),"at":str(camera_hit.position)}if not camera_hit.is_empty()else{}
    record.last_input.proxy_physical_clear=game.explore_access.body_clear(proxy.global_position+Vector3.UP*.15)
    record.last_input.proxy_native_clear=game.army_runtime.native.can_reach_ally(proxy.global_position,proxy.global_position,.55*game.model.falan_scale)
    if record.input_observations.size()<4:record.input_observations.append(record.last_input)
    attack_inputs+=1;target_ids[nearest.id]=true
  await physics_frame
 var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;Input.parse_input_event(release);game.player._input(release)
 if retinue_guard:check(record.retinue_guard_checked,"Each native guardian victory exercises the boss-dead/guards-alive return guard")
 record.attack_inputs=attack_inputs;record.targeted_native_ids=target_ids.keys()
 record.survivors=survivors(fight_key)

func survivors(fight_key:String)->Array:
 return game.model.enemies.values().filter(func(e):return e.hp>0 and (fight_key.is_empty()or game.explore_access.member(e,fight_key))).map(func(e):return {"id":e.id,"hp":e.hp,"at":str(e.pos),"group":game.explore_access.group(e),"slot":e.get("university_slot",-1),"player_reach":game.army_runtime.native.can_reach_ally(game.player.position,e.pos,.55*game.model.falan_scale)})

func verify_portal_pair(record:Dictionary,portal:Dictionary):
 var before=failures;var key=portal.scope+":"+portal.group
 var homes=game.explore_access.visuals.get_children().filter(func(node):return node.get_meta("explore_encounter","")==key)
 var exits=game.explore_access.gate_visuals.get_children().filter(func(node):var gate=node.get_meta("explore_gate",{});return gate.get("actor","")=="victory"and int(gate.get("target",-1))==int(portal.win[0]))
 check(homes.size()==1 and exits.size()==1,"Both intentional post-victory portals remain present")
 if homes.size()!=1 or exits.size()!=1:return
 var home:AnimatedSprite3D=homes[0].get_child(0);var exit:AnimatedSprite3D=exits[0].get_child(0)
 var home_size=home.global_transform.basis.get_scale()*home.pixel_size;var exit_size=exit.global_transform.basis.get_scale()*exit.pixel_size
 check(home_size.is_equal_approx(exit_size),"Hospital and original exit diamonds have the same visible world size")
 check(home.modulate==game.explore_access.HOSPITAL_DIAMOND_COLOR and exit.modulate==Color.WHITE,"Hospital diamond is emerald and the original exit retains gold")
 check(game.explore_access.pins().any(func(pin):return pin.label=="◇ 返回法蘭城東醫院外"and pin.color==home.modulate),"The hospital minimap diamond matches its emerald in-world portal")
 var home_labels=homes[0].get_children().filter(func(node):return node is Label3D and node.text.contains("法蘭城")and node.text.contains("東醫院外"))
 var exit_labels=exits[0].get_children().filter(func(node):return node is Label3D and node.text.contains(exits[0].get_meta("explore_gate").caption))
 check(home_labels.size()==1 and exit_labels.size()==1,"Both portals retain their existing destination labels")
 var center=(home.global_position+exit.global_position)*.5
 var axis=Vector2(exit.global_position.x-home.global_position.x,exit.global_position.z-home.global_position.z).normalized()
 var perpendicular=Vector2(-axis.y,axis.x);var framed=false;var heights=[]
 for radius in[8.,11.,14.]:
  for side in[1.,-1.]:
   var at=Vector2(center.x,center.z)/game.model.falan_scale+perpendicular*radius*side
   var point=game.model.world_point(at,.15)
   if not avoids_walk_in_doors(Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale,at):continue
   if not game.explore_access.body_clear(point)or not game.army_runtime.native.can_reach_ally(game.player.position,point,.55*game.model.falan_scale):continue
   await walk_toward(at,1200,true)
   if game.player.position.distance_to(point)>1.:continue
   var toward=Vector2(center.x,center.z)-Vector2(game.player.position.x,game.player.position.z)
   game.camera_rig.yaw=atan2(-toward.x,-toward.y)
   for i in 12:await physics_frame
   game.camera_rig.reset_follow()
   for i in 12:game.camera_rig.update_camera(1./60.)
   var camera=game.camera_rig.camera;var screens=[];heights=[]
   for sprite in[home,exit]:
    var screen=camera.unproject_position(sprite.global_position);screens.append(screen)
    var height=sprite.sprite_frames.get_frame_texture(&"default",sprite.frame).get_height()*sprite.pixel_size*sprite.global_transform.basis.get_scale().y
    heights.append(camera.unproject_position(sprite.global_position+Vector3.UP*height*.5).distance_to(camera.unproject_position(sprite.global_position-Vector3.UP*height*.5)))
   framed=screens.all(func(screen):return Rect2(Vector2(120,70),Vector2(root.size)-Vector2(240,140)).has_point(screen))and screens[0].distance_to(screens[1])>40. and absf(heights[0]/heights[1]-1.)<.15
   if framed:break
  if framed:break
 check(framed,"Actual walking reaches a normal camera view with both distinct equal-size diamonds")
 await access_capture("final-postboss-portal-pair")
 record.portal_pair={"passed":before==failures,"home_size":str(home_size),"exit_size":str(exit_size),"projected_heights":heights,"home_color":str(home.modulate),"exit_color":str(exit.modulate),"home_destination":"法蘭城東醫院外","exit_destination":exits[0].get_meta("explore_gate").caption,"capture":"final-postboss-portal-pair.png"}
 var file=FileAccess.open(ACCESS_OUT+"final-postboss-portal-pair.json",FileAccess.WRITE);file.store_string(JSON.stringify(record.portal_pair,"  "));file.close()

func verify_portal_caption(record:Dictionary,portal:Dictionary):
 if DisplayServer.get_name()=="headless":return
 var labels=[]
 for host in game.explore_access.visuals.get_children():
  if host.get_meta("explore_encounter","")!=portal.scope+":"+portal.group:continue
  for node in host.get_children():
   if node is Label3D and node.text.begins_with("F · 返回法蘭城"):labels.append(node)
 check(labels.size()==1,"One visible return portal has its named in-world caption")
 if labels.is_empty():return
 var camera=game.camera_rig.camera;var screen=camera.unproject_position(labels[0].global_position)
 record.portal_caption={"screen":str(screen),"viewport":str(root.size),"behind":camera.is_position_behind(labels[0].global_position)}
 check(not record.portal_caption.behind and Rect2(Vector2(120,35),Vector2(root.size)-Vector2(240,70)).has_point(screen),"Return portal caption stays inside the normal nearby camera view")

func wait_for_portal(fight_key:String,victories:int=1):
 for frame in 180:
  var record:Dictionary=game.explore_access.encounters.get(game.explore_access.scope()+":"+fight_key,{})
  if record.get("cleared",false)and record.has("portal")and int(record.get("victories",0))>=victories:return
  await physics_frame

func setup_walkable(at:Vector2,trigger:Vector2=Vector2.INF,trigger_radius:float=0.)->bool:
 var rejected={"physical":0,"terrain":0,"native":0}
 var info=Tour.Indoor.floor_info(game.model.falan_floor,game.model.seed_value)
 var bits=Tour.Indoor.walk_mask(game.model.falan_floor,info[0],info[2].hex_decode(),game.model.seed_value)if game.model.falan_area=="interior"else PackedByteArray()
 for ring in 9:
  for direction in 16:
   var point=game.model.world_point(at+Vector2.from_angle(direction*TAU/16.)*ring*1.5,.15)
   var local=Vector2(point.x,point.z)/game.model.falan_scale
   if trigger_radius>0 and local.distance_to(trigger)<trigger_radius+1.:continue
   if not avoids_walk_in_doors(local,local):continue
   if not bits.is_empty()and not Original.open(bits,info[0],Vector2i(((Vector2(point.x,point.z)/game.model.falan_scale-info[1])/3.).round())):continue
   if not game.explore_access.body_clear(point):rejected.physical+=1;continue
   if not game.model.terrain.disk_clear(point/game.model.falan_scale,.65):rejected.terrain+=1;continue
   if not game.army_runtime.native.can_reach_ally(point,point,.55*game.model.falan_scale):rejected.native+=1;continue
   game.player.position=point;game.model.hero_position=point;game.player.reset_physics_interpolation();return true
 print("BOSS_APPROACH_BLOCKED ",{"requested":str(at),"floor":game.model.falan_floor,"area":game.model.falan_area,"rejected":rejected,"player":str(game.player.position)})
 return false

func avoids_walk_in_doors(from:Vector2,to:Vector2)->bool:
 for link in game.model.get_meta("falan_links",[]):
  if not link.get("walk_in",false)or link.get("explore_gate_only",false):continue
  if Geometry2D.get_closest_point_to_segment(link.at,from,to).distance_squared_to(link.at)<pow(Tour.WALK_IN_RADIUS+.5,2):return false
 return true

func station_diagnostics(at:Vector2)->Dictionary:
 var rejected={"source":0,"physical":0,"door":0,"terrain":0,"scenery":0,"native":0,"valid":0}
 var info=Tour.Indoor.floor_info(game.model.falan_floor,game.model.seed_value)
 var bits=Tour.Indoor.walk_mask(game.model.falan_floor,info[0],info[2].hex_decode(),game.model.seed_value)
 var start=game.explore_access.player_path_start()
 for ring in 9:
  for direction in 16:
   var point=at+Vector2.from_angle(direction*TAU/16.)*ring*1.5
   var cell=Vector2i(((point-info[1])/3.).round());var world=game.model.world_point(point,.15)
   if not Original.open(bits,info[0],cell):rejected.source+=1;continue
   if not game.explore_access.body_clear(world):rejected.physical+=1;continue
   if game.model.get_meta("falan_links",[]).any(func(link):return point.distance_squared_to(link.at)<4.5*4.5):rejected.door+=1;continue
   if not game.model.terrain.disk_clear(world/game.model.falan_scale,.65):rejected.terrain+=1;continue
   if game.model.scenery_obstacles.values().any(func(box):return box.grow(.65).has_point(world/game.model.falan_scale)):rejected.scenery+=1;continue
   if not start.is_finite()or not game.army_runtime.native.can_reach_ally(start,world,.55*game.model.falan_scale):rejected.native+=1;continue
   rejected.valid+=1
 return {"at":str(at),"floor":game.model.falan_floor,"hero":str(game.player.position),"path_start":str(start),"rejected":rejected}

func boss_pages_ready(enemy:Dictionary)->bool:
 var roles=game.model.waves.Roles;var source:Script
 if enemy.variant==roles.GATEKEEPER_HOUND:source=preload("res://scripts/forest/pet_catalog.gd")
 elif enemy.variant==roles.CAVE_BEAR:source=preload("res://scripts/forest/crowd/habaru_sprites.gd")
 elif enemy.variant==roles.SLIME:
  source=preload("res://scripts/forest/forest_university_region.gd").bank_for(str(enemy.university_battle))if enemy.has("university_battle")else game.crowd.army.presentation.cave_sprites
 else:return true
 if source==null:return false
 var meshes=preload("res://scripts/forest/crowd/hound_sprites.gd").meshes
 if not meshes.has(source.ROOT)or game.crowd.army.meshes.get(int(enemy.variant))!=meshes[source.ROOT]:return false
 var manifest=source.motions()
 if not manifest.has("skin_pages"):return true
 var pages:Array=meshes[source.ROOT].get_meta("prepared_pages",[])
 var ready=manifest.skin_pages[int(enemy.skin)].all(func(page):return pages.any(func(prepared):return int(prepared)==int(page)))
 if not ready:print("BOSS_TEXTURE_PAGES_MISSING ",{"source":source.ROOT,"skin":enemy.skin,"required":manifest.skin_pages[int(enemy.skin)],"prepared":pages})
 return ready

func verify_waiting_host_wall(group:String):
 var host=game.habaru_waiting if group=="habaru_slot"else game.falken_waiting
 if not is_instance_valid(host)or not game.can_talk_to_host(host):return
 var processing=game.player.is_physics_processing();game.player.set_physics_process(false)
 var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 var collider=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(12,12,.2);collider.shape=box;wall.add_child(collider);game.add_child(wall)
 wall.global_position=(game.player.global_position+host.global_position)*.5+Vector3.UP*2.5*game.model.falan_scale
 wall.rotation.y=atan2(host.global_position.x-game.player.global_position.x,host.global_position.z-game.player.global_position.z)
 await physics_frame
 check(not game.can_talk_to_host(host),"An unrelated physical wall blocks the original waiting boss conversation")
 wall.free();await physics_frame;game.player.set_physics_process(processing)
 check(game.can_talk_to_host(host),"Removing the wall restores the same local waiting boss conversation")


func boss_camera_hit(enemy)->Dictionary:
 # Match the real camera: invisible water/upper-furniture navigation barriers remain movement blockers.
 return preload("res://scripts/attack_chain.gd").world_ray(game,game.camera_rig.camera.global_position,preload("res://scripts/attack_chain.gd").aim_point(enemy),1,game.camera_rig.water_camera.probe.exclude)

func aim_camera_at(enemy):
 if not is_instance_valid(enemy):return
 game.camera_rig.yaw=atan2(game.player.position.x-enemy.global_position.x,game.player.position.z-enemy.global_position.z)
 game.camera_rig.reset_follow()
 for i in 4:game.camera_rig.update_camera(1./60.)
 game.camera_rig.camera.look_at(preload("res://scripts/attack_chain.gd").aim_point(enemy))

func walk_to_clear_shot(enemy):
 if not is_instance_valid(enemy):return
 var start=game.explore_access.player_path_start()
 if not start.is_finite():return
 if start.distance_squared_to(game.player.position)>.25:await walk_toward(Vector2(start.x,start.z)/game.model.falan_scale,60)
 if not is_instance_valid(enemy):return
 var at=Vector2(enemy.global_position.x,enemy.global_position.z)/game.model.falan_scale
 var candidates=[]
 for radius in[2.,3.,4.,6.]:
  for direction in 16:candidates.append(at+Vector2.from_angle(direction*TAU/16.)*radius)
 candidates.sort_custom(func(a,b):return game.player.position.distance_squared_to(game.model.world_point(a))<game.player.position.distance_squared_to(game.model.world_point(b)))
 for point in candidates:
  var world=game.model.world_point(point,.15)
  if not game.explore_access.body_clear(world)or not game.army_runtime.native.can_reach_ally(start,world,.55*game.model.falan_scale):continue
  if not preload("res://scripts/attack_chain.gd").clear_line(game,world+Vector3.UP*1.2,preload("res://scripts/attack_chain.gd").aim_point(enemy)):continue
  await walk_toward(point,360)
  if not is_instance_valid(enemy):return
  if game.player.position.distance_to(world)>1.:continue
  aim_camera_at(enemy)
  if boss_camera_hit(enemy).is_empty():return

func approach_boss(at:Vector2):
 var start=game.explore_access.player_path_start()
 if not start.is_finite():return
 if start.distance_squared_to(game.player.position)>.25:await walk_toward(Vector2(start.x,start.z)/game.model.falan_scale,60)
 for direction in 16:
  var point=at+Vector2.from_angle(direction*TAU/16.)*9.
  var world=game.model.world_point(point,.15)
  if not game.explore_access.body_clear(world):continue
  if not game.army_runtime.native.can_reach_ally(start,world,.55*game.model.falan_scale):continue
  if not game._ryo_clear_path(game.player.position+Vector3.UP*1.2,world+Vector3.UP*1.2):continue
  if not game.army_runtime.native.can_reach_ally(world,game.model.world_point(at,.15),.55*game.model.falan_scale):continue
  if not game._ryo_clear_path(world+Vector3.UP*1.2*game.model.falan_scale,game.model.world_point(at,1.2*game.model.falan_scale)):continue
  await walk_toward(point,180)
  await walk_toward(at+(point-at).normalized()*3.5,90)
  return
func trigger_state(stage:String)->Dictionary:
 var state={"stage":stage,"speaker":game.dialogue.speaker if is_instance_valid(game.dialogue)else"closed","options":game.dialogue.pages[game.dialogue.page].get("options",[])if is_instance_valid(game.dialogue)else[],"npc":game.explorer_npcs.nearest.get("record",{}).get("id",""),"npc_prompt":is_instance_valid(game.explorer_npcs.hint)and game.explorer_npcs.hint.visible,"toast":game.forest_ui.message,"active":preload("res://scripts/forest/forest_university_region.gd").active(self,game.model.falan_floor,game.model.falan_area),"victory_pending":has_meta("university_victory"),"playing":game.playing,"paused":game.paused,"transitioning":game.transitioning,"ordinary_pause":game.ordinary_pause,"hp":game.player.hp,"equipment":is_instance_valid(game.equipment_hub),"team_picker":is_instance_valid(game.team_upgrade_picker),"combined":game.army_runtime.combined_committed,"at":str(game.player.position),"spots":game.explore_access.boss_spots.map(func(s):return [s.actor if s.has("actor")else s.get("key",""),game.player.position.distance_to(game.model.world_point(s.at))])}

 var chest=game.exploration_loot.nearest()
 state.chest={"index":chest,"slot":game.exploration_loot.slots[chest].duplicate(true)}if chest>=0 else{}
 state.access_distance=game.explore_access.interaction_distance_squared()
 if not is_finite(state.access_distance):state.access_distance=-1.
 state.chest_distance=game.player.position.distance_squared_to(game.exploration_loot.slots[chest].pos)if chest>=0 else -1.
 state.map_expanded=game.forest_ui.enemy_minimap.expanded
 state.travel_panel=is_instance_valid(game.travel_panel)
 state.pet_loadout=is_instance_valid(game.pet_loadout_panel)
 state.portals=[]
 for record in game.explore_access.encounters.values():
  if record.scope!=game.explore_access.scope()or not record.cleared or not record.has("portal"):continue
  var from=game.player.position+Vector3.UP*2.5*game.model.falan_scale;var to=game.model.world_point(record.portal,2.5*game.model.falan_scale)
  var hit=preload("res://scripts/attack_chain.gd").world_ray(game,from,to)
  state.portals.append({"at":str(record.portal),"world":str(game.model.world_point(record.portal,.05)),"sight":game._ryo_clear_path(from,to),"sight_obstacle":str(hit.collider.get_path())if not hit.is_empty()else"clear","sight_low":game._ryo_clear_path(game.player.position+Vector3.UP*1.2*game.model.falan_scale,game.model.world_point(record.portal,1.2*game.model.falan_scale))})
 state.status_panel=is_instance_valid(game.status_panel);state.settings=game.settings_open;state.roster=game.rogue_roster_open
 return state

func save_boss_report():
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
 var f=FileAccess.open(ACCESS_OUT+"bosses-"+mode+".json",FileAccess.WRITE)
 if f!=null:f.store_string(JSON.stringify({"encounters":boss_report,"checks":checks,"failures":failures},"  "));f.close()
 var path=ACCESS_OUT+"bosses-history.json"
 var history=JSON.parse_string(FileAccess.get_file_as_string(path))if FileAccess.file_exists(path)else{}
 for row in boss_report:history["%s:%s:%s:%s"%[row.map,row.boss,row.get("choice",0),mode]]=row
 f=FileAccess.open(path,FileAccess.WRITE)
 if f!=null:f.store_string(JSON.stringify(history,"  "));f.close()
