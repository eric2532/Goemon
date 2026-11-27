extends "res://tests/forest-shrine/explore_access_test.gd"
var boss_report=[]
func _initialize():
 create_timer(7200 if "--matrix"in OS.get_cmdline_user_args() else 900).timeout.connect(func():printerr("EXPLORE_BOSSES_TIMEOUT");save_boss_report();quit(1));run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-explore-bosses-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.player.run_upgrades.damage=100000
 var cases=[[4501,Vector2i(10,12),"altar"],[15569,Vector2i(22,24),"5320"],[51805,Vector2i(10,10),"new-scientist"],[13016,Vector2i(39,18),"new-temple"]]
 if "--lizard"in OS.get_cmdline_user_args():cases=[[16520,Vector2i(10,14),"lizard"]]
 if "--diagnose"in OS.get_cmdline_user_args():cases=cases.filter(func(c):return c[2]in["5320","new-scientist","new-temple"])
 if "--endpoints"in OS.get_cmdline_user_args():
  cases=[[13016,Vector2i(39,18),"new-temple"]]
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
    if not Original.owns(id) or str(row.actor)in blocked:continue
    var declarations=[]
    for declaration in row.declarations:
     if declaration in declarations:continue
     declarations.append(declaration);cases.append([id,Vector2i(row.cell[0],row.cell[1]),str(row.actor),row.declarations.find(declaration)])
 if "--specials"in OS.get_cmdline_user_args():
  cases=[]
  var regional=preload("res://scripts/forest/forest_university_region.gd")
  for key in regional.BOSSES:
   var spec=regional.specification(key,game.model.seed_value);cases.append([spec.map,spec.cell,key])
  var dungeon=Original.generated();var terminal_floor=dungeon.floor_id("east_102",dungeon.count("east_102",game.model.seed_value))
  cases.append([terminal_floor,dungeon.doors(terminal_floor,game.model.seed_value)[0],"80023"])
  cases.append([0,Vector2i(182,101),"5237"])
  cases.append_array([[11004,Vector2i(33,21),"habaru_slot"],[11001,Vector2i(8,21),"venoa_bear_slot"],[15003,Vector2i(33,29),"undersea_slot"],[23001,Vector2i(23,9),"falken_slot"],[16508,Vector2i(25,20),"ruby_slot"],[47017,Vector2i(22,23),"grave_slot"],[15505,Vector2i(40,6),"zombie_slot"],[16503,Vector2i(25,20),"captain_slot"]])
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--source="):cases=cases.filter(func(c):return c[0]==int(arg.trim_prefix("--source=")))
  if arg.begins_with("--skip="):cases=cases.slice(int(arg.trim_prefix("--skip=")))
  if arg.begins_with("--limit="):cases=cases.slice(0,int(arg.trim_prefix("--limit=")))
 if "--unverified"in OS.get_cmdline_user_args():
  var history=JSON.parse_string(FileAccess.get_file_as_string(ACCESS_OUT+"bosses-history.json"))if FileAccess.file_exists(ACCESS_OUT+"bosses-history.json")else{}
  var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
  cases=cases.filter(func(route):var row=history.get("%s:%s:%s:%s"%[route[0],route[2],route[3]if route.size()>3 else 0,mode],{});return not row.get("passed",false)or not row.get("retry",{}).get("passed",false))
 for route in cases:
  print("EXPLORE_BOSS_CASE ",route)
  var before_failures=failures
  if is_instance_valid(game.dialogue):game.close_boss_dialogue()
  if route[0]==0 and route[2]=="5237":
   check(preload("res://scripts/forest/forest_explore_routes.gd").travel(game,100,route[1]),"Original world boss has a published walkable source field")
   for i in 10:await physics_frame
  elif Original.owns(route[0]):await visit_source(route[0],route[1])
  else:
   var info=Tour.Indoor.floor_info(route[0],game.model.seed_value)
   Tour.travel(game,Tour.Indoor.layout(route[0]),{"arrival":Tour.Indoor.safe_point(route[0],info[1]+Vector2(route[1])*3.,game.model.seed_value),"yaw":0.,"velocity":Vector3.ZERO})
   for i in 8:await physics_frame
   check(game.model.falan_floor==route[0],"Existing legacy owner loads the boss arena")
  game.player.set_auto_attack(false)
  if Original.generated().owns(route[0]):
   game.player.position=game.model.world_point(Original.generated().landing(route[0],game.model.seed_value,true),.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
   for i in 6:await physics_frame
  game.explore_access.map_token=[];game.explore_access._process(.2)
  game.army_runtime.refresh_navigation(0)
  game.explore_access.map_token=[];game.explore_access._process(.2)
  if route[2]=="lizard":
   var at=Original.source_point(16520,Vector2i(10,3))
   await approach_boss(at)
  if route[2]in["altar","5320"] or "--matrix"in OS.get_cmdline_user_args():
   var spots=game.explore_access.boss_spots.filter(func(s):return s.get("key","")==route[2]or s.get("actor","")==route[2]or s.get("group","")==route[2]or route[2]in s.get("actors",[]))
   check(not spots.is_empty(),"Scripted boss has a defined marked encounter location "+route[2])
   if not spots.is_empty():
    var spot:Dictionary=spots[0];var station=game.explore_access.safe_station(spot.at)
    check(station.is_finite(),"Scripted boss has source-open physical approach "+route[2])
    if station.is_finite():
     var approach=station
     for direction in 16:
      var point=station+Vector2.from_angle(direction*TAU/16.)*2.5
      var world=game.model.world_point(point,.15)
      if not game.explore_access.body_clear(world)or not game.army_runtime.native.can_reach_ally(world,game.model.world_point(station,.15),.55*game.model.falan_scale):continue
      if not game._ryo_clear_path(world+Vector3.UP*1.2,game.model.world_point(station,1.2)):continue
      approach=point;break
     check(approach!=station,"Boss marker has a walk-in approach")
     game.player.position=game.model.world_point(approach,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
     await walk_toward(station,90)
     check(game.player.position.distance_to(game.model.world_point(station,.15))<1.,"Player movement reaches the marked boss trigger")
     game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
     press_f()
     if is_instance_valid(game.dialogue)and game.dialogue.speaker=="選擇挑戰":
      var overlapping=game.explore_access.boss_spots.filter(func(s):return s.has("fights")and s.at.distance_squared_to(station)<5.*5.)
      var selected=overlapping.find(spot)
      if selected>=0:game.dialogue.chosen.emit(str(selected))
     if is_instance_valid(game.dialogue) and game.dialogue.speaker=="Cross Gate":
      var challenges=game.dialogue.pages[0].options.filter(func(o):return str(o[0]).begins_with("challenge:"))
      var nearby=game.explore_access.boss_spots.filter(func(s):return s.has("fights")and s.at.distance_squared_to(station)<5.*5. and game.explore_access.gates.any(func(g):return str(g.get("actor",""))==str(s.actor) and g.at.distance_squared_to(station)<5.*5.))
      var selected=nearby.find(spot)
      if selected>=0 and selected<challenges.size():game.dialogue.chosen.emit(challenges[selected][0])
      elif not challenges.is_empty():game.dialogue.chosen.emit(challenges[0][0])
     if "--diagnose"in OS.get_cmdline_user_args():print("BOSS_TRIGGER ",route[2]," at=",station," original=",spot.at," dialogue=",game.dialogue.speaker if is_instance_valid(game.dialogue) else "none"," toast=",game.forest_ui.message)
     if is_instance_valid(game.dialogue)and game.dialogue.speaker==spot.name:
      var choices:Array=game.dialogue.pages[0].options
      var answer=str(route[3])if route.size()>3 else "0"
      if choices.any(func(o):return o[0]==answer):game.dialogue.chosen.emit(answer)
      elif choices.any(func(o):return o[0]=="yes"):game.dialogue.chosen.emit("yes")
      else:await drain()
     else:await drain()
  for i in 15:await physics_frame
  game.model.waves.tick(0.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility();game.explore_access._process(.2)
  var bosses=game.model.enemies.values().filter(func(e):return e.get("boss",false))
  if route[2]=="zombie":bosses=game.model.enemies.values().filter(func(e):return e.get("university_battle","")=="zombie")
  check(not bosses.is_empty(),"Boss appears as a live native actor "+str(route[2]))
  check(bosses.any(func(e):var proxy=game.army_runtime.enemy_target(e.id);return game.army_runtime.handles.has(e.id)and proxy!=null and game.forest_enemy_visible(proxy)),"Marked boss has an in-world native body in revealed arena ground")
  var record={"map":route[0],"boss":route[2],"choice":route[3]if route.size()>3 else 0,"initial_members":game.model.enemies.size(),"bosses":bosses.map(func(e):return e.get("enemy_name","")),"ordinary_F":route[2]in["altar","5320"]or "--matrix"in OS.get_cmdline_user_args(),"qualification":"Temporary hero invulnerability/damage boost; original enemy counts, phases, damage and timing retained."}
  record.source=100 if route[0]==0 and route[2]=="5237"else Original.source_id(route[0])
  record.diagnostics={"floor":game.model.falan_floor,"source":game.model.waves.patrol_source.resource_path,"endpoint":str(game.explore_access.endpoint),"endpoint_blocker":game.model.get_meta("explore_endpoint_blocker",{}),"spots":str(game.explore_access.boss_spots),"east_blockers":get_meta("east_battle_blockers",{}),"dialogue":game.dialogue.speaker if is_instance_valid(game.dialogue) else "closed"}
  await access_capture("boss-"+str(route[2])+"-active")
  var fight_key=""if bosses.is_empty()else game.explore_access.group(bosses[0])
  if not bosses.is_empty():await approach_boss(Vector2(bosses[0].pos.x,bosses[0].pos.z)/game.model.falan_scale)
  await fight_with_player_inputs(fight_key,record)
  game.explore_access._process(.2)
  var returns=game.explore_access.encounters.values().filter(func(r):return r.scope==game.explore_access.scope() and r.group==fight_key and r.cleared and r.has("portal"))
  var portals=returns.map(func(r):return {"at":r.portal})
  check(portals.size()==1,"Complete encounter produces one optional return portal "+str(route[2]))
  if not returns.is_empty():
   check(game.explore_access.pins().any(func(p):return p.label.begins_with("✓ 已擊敗")and p.at==returns[0].at),"Discovered boss pin changes to cleared after complete victory")
   check(game.exploration_loot.slots.filter(func(s):return s.active and s.get("key","")==returns[0].chest_key).size()==1,"Complete victory creates one reachable weapon chest generation")
  record.remaining=game.model.enemies.size();record.portals=portals.size()
  if not portals.is_empty():
   var at:Vector2=portals[0].at
   check(game.army_runtime.native.can_reach_ally(game.player.position,game.model.world_point(at,.15),.55*game.model.falan_scale),"Victory portal is player-reachable "+str(route[2]))
   game.player.position=game.model.world_point(at,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
   for i in 180:await physics_frame
   await access_capture("boss-"+str(route[2])+"-portal")
   var automatic=game.explore_access.boss_spots.filter(func(s):return s.group==fight_key and s.get("record",{}).get("type","")=="StandEnemy")
   if not automatic.is_empty():
    var count_before=returns[0].victories
    game.set_meta("east_auto_cooldown",{})
    game.player.position=game.model.world_point(automatic[0].at,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
    for i in 12:await physics_frame
    load("res://scripts/forest/forest_east_region.gd").tick(game,.2)
    check(returns[0].cleared and returns[0].has("portal") and returns[0].victories==count_before,"Expired original trigger cooldown does not restart a cleared fight during looting")
    game.player.position=game.model.world_point(at,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
   if "--repeat"in OS.get_cmdline_user_args():
    var earned=returns[0].victories
    press_f()
    check(is_instance_valid(game.dialogue) and game.dialogue.pages[0].options.any(func(o):return o[0]=="retry"),"Victory portal exposes the original encounter retry")
    if is_instance_valid(game.dialogue):game.dialogue.chosen.emit("retry")
    if fight_key in["habaru_slot","falken_slot"]:
     var hosts=game.explore_access.boss_spots.filter(func(s):return s.group==fight_key)
     if not hosts.is_empty():
      game.player.position=game.model.world_point(hosts[0].at+Vector2(0,5),.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
      for i in 6:await physics_frame
      press_f();await drain()
    for i in 20:await physics_frame
    game.model.waves.tick(0.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility();game.explore_access._process(.2)
    var retry_party=game.model.enemies.values().filter(func(e):return e.hp>0 and game.explore_access.member(e,fight_key))
    check(not retry_party.is_empty()if route[2]=="zombie"else retry_party.any(func(e):return e.get("boss",false)),"Retry visibly spawns the native boss again")
    check(not returns[0].cleared and not returns[0].has("portal"),"Retry removes the previous cleared portal")
    if not retry_party.is_empty():await approach_boss(Vector2(retry_party[0].pos.x,retry_party[0].pos.z)/game.model.falan_scale)
    var retry_record={}
    await fight_with_player_inputs(fight_key,retry_record);game.explore_access._process(.2)
    check(returns[0].cleared and returns[0].has("portal") and returns[0].victories==earned+1,"Later full victory earns one fresh portal and chest generation")
    record.retry={"passed":returns[0].cleared and returns[0].get("victories",0)==earned+1,"attack_inputs":retry_record.attack_inputs,"native_ids":retry_record.targeted_native_ids,"observations":retry_record.input_observations,"remaining":str(game.model.enemies.values()),"record":str(returns[0])}
    if returns[0].has("portal"):
     game.player.position=game.model.world_point(returns[0].portal,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
   var gold=game.model.gold;var items:Dictionary=get_meta("university_quest_items",{}).duplicate(true);var checkpoint=game.checkpoint
   press_f()
   if is_instance_valid(game.dialogue)and game.dialogue.speaker=="回城傳送門":game.dialogue.chosen.emit("return")
   for i in 8:await physics_frame
   check(Tour.area(game.model)=="city"and game.player.position.distance_to(game.model.world_point(game.explore_access.HOSPITAL_LANDING,.15))<.5,"Actual F portal returns to exact east hospital "+str(route[2]))
   check(gold==game.model.gold and items==get_meta("university_quest_items",{})and checkpoint==game.checkpoint,"Return preserves gold/items/home checkpoint "+str(route[2]))
  record.passed=before_failures==failures;boss_report.append(record);save_boss_report()
 print("EXPLORE_BOSSES_RESULT checks=",checks," failures=",failures)
 finish()
func fight_with_player_inputs(fight_key:String,record:Dictionary):
 var attack_inputs=0;var target_ids={}
 record.input_observations=[];record.seen_boss_ids=[];record.tab_inputs=0
 for tick in 3600:
  var living=game.model.enemies.values().filter(func(e):return e.hp>0 and (fight_key.is_empty()or game.explore_access.member(e,fight_key)))
  if living.is_empty():
   for i in 8:await physics_frame
   living=game.model.enemies.values().filter(func(e):return e.hp>0 and (fight_key.is_empty()or game.explore_access.member(e,fight_key)))
   if living.is_empty():break
  for enemy in living:
   if enemy.get("boss",false)and enemy.id not in record.seen_boss_ids:
    var body=game.army_runtime.enemy_target(enemy.id)
    check(body!=null and game.army_runtime.handles.has(enemy.id),"Each required boss phase enters the shared native presentation")
    record.seen_boss_ids.append(enemy.id)
  if tick%30==0:
   var nearest=living[0]
   for e in living:
    if e.pos.distance_squared_to(game.player.position)<nearest.pos.distance_squared_to(game.player.position):nearest=e
   if nearest.pos.distance_to(game.player.position)>6.*game.model.falan_scale:
    var target=Vector2(nearest.pos.x,nearest.pos.z)/game.model.falan_scale
    var from=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
    await walk_toward(target+(from-target).normalized()*3.5,120)
   var proxy=game.army_runtime.enemy_target(nearest.id)
   if proxy!=null:
    game.camera_rig.yaw=atan2(game.player.position.x-nearest.pos.x,game.player.position.z-nearest.pos.z);game.camera_rig.reset_follow()
    for i in 4:game.camera_rig.update_camera(1./60.)
    var aim=preload("res://scripts/attack_chain.gd").aim_point(proxy)
    game.camera_rig.camera.look_at(aim)
    if game.enemy_near_crosshair(120.)==null:
     await walk_to_clear_shot(proxy)
     game.camera_rig.reset_follow()
     for i in 4:game.camera_rig.update_camera(1./60.)
     game.camera_rig.camera.look_at(preload("res://scripts/attack_chain.gd").aim_point(proxy))
     if game.enemy_near_crosshair(120.)==null:
      var select=InputEventKey.new();select.physical_keycode=KEY_TAB;select.pressed=true;game._input(select);record.tab_inputs+=1
    var screen=game.crosshair_screen_position()
    var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.position=screen;release.global_position=screen;release.pressed=false;game.player._input(release)
    var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=screen;click.global_position=screen;click.pressed=true;game.player._unhandled_input(click)
    if record.input_observations.size()<4:
     var picked=game.enemy_near_crosshair(120.)
     record.input_observations.append({"target":nearest.id,"hero":str(game.player.position),"target_at":str(nearest.pos),"on_floor":game.player.is_on_floor(),"playing":game.playing,"paused":game.paused,"transitioning":game.transitioning,"visible":game.forest_enemy_visible(proxy),"picked":picked.forest_id if picked!=null else -1,"mode":game.player.active_ability.mode,"selected":game.player.active_ability.selected_primary_enemy()!=null})
    attack_inputs+=1;target_ids[nearest.id]=true
  await physics_frame
 var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;Input.parse_input_event(release)
 record.attack_inputs=attack_inputs;record.targeted_native_ids=target_ids.keys()

func walk_to_clear_shot(enemy):
 var at=Vector2(enemy.global_position.x,enemy.global_position.z)/game.model.falan_scale
 var candidates=[]
 for direction in 16:candidates.append(at+Vector2.from_angle(direction*TAU/16.)*4.)
 candidates.sort_custom(func(a,b):return game.player.position.distance_squared_to(game.model.world_point(a))<game.player.position.distance_squared_to(game.model.world_point(b)))
 for point in candidates:
  var world=game.model.world_point(point,.15)
  if not game.explore_access.body_clear(world)or not game.army_runtime.native.can_reach_ally(game.player.position,world,.55*game.model.falan_scale):continue
  if not game._ryo_clear_path(game.player.position+Vector3.UP*1.2,world+Vector3.UP*1.2):continue
  if not preload("res://scripts/attack_chain.gd").clear_line(game,world+Vector3.UP*1.2,preload("res://scripts/attack_chain.gd").aim_point(enemy)):continue
  await walk_toward(point,120);return

func approach_boss(at:Vector2):
 for direction in 16:
  var point=at+Vector2.from_angle(direction*TAU/16.)*9.
  var world=game.model.world_point(point,.15)
  if not game.explore_access.body_clear(world):continue
  if not game.army_runtime.native.can_reach_ally(world,game.model.world_point(at,.15),.55*game.model.falan_scale):continue
  if not game._ryo_clear_path(world+Vector3.UP*1.2*game.model.falan_scale,game.model.world_point(at,1.2*game.model.falan_scale)):continue
  game.player.position=world;game.model.hero_position=world;game.player.reset_physics_interpolation()
  await walk_toward(at+(point-at).normalized()*3.5,90)
  return
func save_boss_report():
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
 var f=FileAccess.open(ACCESS_OUT+"bosses-"+mode+".json",FileAccess.WRITE)
 if f!=null:f.store_string(JSON.stringify({"encounters":boss_report,"checks":checks,"failures":failures},"  "));f.close()
 var path=ACCESS_OUT+"bosses-history.json"
 var history=JSON.parse_string(FileAccess.get_file_as_string(path))if FileAccess.file_exists(path)else{}
 for row in boss_report:history["%s:%s:%s:%s"%[row.map,row.boss,row.get("choice",0),mode]]=row
 f=FileAccess.open(path,FileAccess.WRITE)
 if f!=null:f.store_string(JSON.stringify(history,"  "));f.close()
