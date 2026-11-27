extends "res://tests/forest-shrine/tina_explorer_review.gd"
const ACCESS_OUT="res://build/Other Files/Asset Toolkit/Explore Access/"
func _initialize():
 create_timer(3600 if "--routes"in OS.get_cmdline_user_args() else 240).timeout.connect(func():printerr("EXPLORE_ACCESS_TIMEOUT");quit(1))
 run.call_deferred()
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-explore-access-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.player.set_auto_attack(false)
 if "--routes"in OS.get_cmdline_user_args():
  await route_checks();finish();return
 var access=game.explore_access
 var city:Dictionary=get_meta("falan_venture").falan_areas.city
 Tour.travel(game,city,{"arrival":access.HOSPITAL_LANDING,"yaw":PI*.5,"velocity":Vector3.ZERO})
 for i in 6:await physics_frame
 var landing:Vector3=game.player.position
 check(Tour.area(game.model)=="city","Hospital landing is outdoors in current city")
 check(game.model.terrain.disk_clear(landing/game.model.falan_scale,.65),"Hospital landing has player clearance")
 check(not game.model.scenery_obstacles.values().any(func(box):return box.grow(.65).has_point(landing/game.model.falan_scale)),"Hospital landing is outside building collision")
 check(game.model.get_meta("falan_links",[]).all(func(link):return Vector2(landing.x,landing.z).distance_to(link.at*game.model.falan_scale)>Tour.WALK_IN_RADIUS*game.model.falan_scale+1.),"Hospital landing avoids all active doorways")
 check(game.army_runtime.native.can_reach_ally(landing,game.model.world_point(access.HOSPITAL_DOOR+Vector2(3,0),.15),.55*game.model.falan_scale),"Outdoor landing connects to hospital frontage")
 await access_capture("east-hospital-landing")
 await visit_source(11004,Vector2i(33,21))
 var boss_at:Vector2=Tour.Regions.Sites.HABARU_FORMATION[0]
 game.player.position=game.model.world_point(boss_at+Vector2(0,5),.15);game.player.velocity=Vector3.ZERO
 game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
 for i in 6:await physics_frame
 check(is_instance_valid(game.habaru_waiting)and game.habaru_waiting.is_visible_in_tree(),"Approachable Habaru host is visible before fight")
 press_f();check(is_instance_valid(game.dialogue),"Actual F opens Habaru conversation")
 await drain()
 for i in 12:await physics_frame
 game.model.waves.tick(0.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
 var party=game.model.enemies.values().filter(func(e):return e.has("habaru_slot"))
 check(party.size()==10,"Complete original Habaru party spawns")
 check(party.any(func(e):return e.get("boss",false)and game.army_runtime.handles.has(e.id)),"Boss has a live native in-world body")
 await access_capture("habaru-active")
 var boss=party.filter(func(e):return e.get("boss",false))
 if not boss.is_empty():await defeat_ids([boss[0].id])
 access._process(.2)
 check(access.pins().all(func(p):return not p.label.begins_with("◇")),"Boss death alone never completes surviving retinue")
 await defeat_ids(party.map(func(e):return e.id))
 access._process(.2)
 var portals=access.pins().filter(func(p):return p.label.begins_with("◇"))
 check(portals.size()==1,"Complete victory creates exactly one return portal")
 if not portals.is_empty():
  var at:Vector2=portals[0].at
  check(game.army_runtime.native.can_reach_ally(game.player.position,game.model.world_point(at,.15),.55*game.model.falan_scale),"Portal belongs to player's reachable arena ground")
  game.player.position=game.model.world_point(at,.15);game.player.reset_physics_interpolation();game.model.hero_position=game.player.position
  for i in 180:await physics_frame
  await access_capture("habaru-victory-portal")
  var gold=game.model.gold;var items:Dictionary=get_meta("university_quest_items",{}).duplicate(true);var quests=game.settings.explorer_quests.duplicate(true)
  press_f()
  if is_instance_valid(game.dialogue)and game.dialogue.speaker=="回城傳送門":game.dialogue.chosen.emit("return")
  for i in 8:await physics_frame
  check(Tour.area(game.model)=="city"and game.player.position.distance_to(game.model.world_point(access.HOSPITAL_LANDING,.15))<.5,"Actual F returns to exact east hospital outdoor landing")
  check(game.model.gold==gold and get_meta("university_quest_items",{})==items and game.settings.explorer_quests==quests,"Portal leaves gold, quest inventory and quest state intact")
 print("EXPLORE_ACCESS_RESULT checks=",checks," failures=",failures)
 finish()
func press_f():
 var key=InputEventKey.new();key.physical_keycode=KEY_F;key.pressed=true;game._input(key)
func defeat_ids(ids:Array):
 for id in ids:
  var handle:int=game.army_runtime.handles.get(id,0)
  if handle!=0:game.army_runtime.apply_hit(handle,{"amount":100000000.,"accuracy":100.})
 for i in 20:
  game.army_runtime.integration_tick(1./60.);game.army_runtime.dispatch_events()
  await physics_frame
 game.army_runtime.sync_compatibility()
func access_capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.camera_rig.reset_follow()
 for i in 12:game.camera_rig.update_camera(1./60.)
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ACCESS_OUT+label_+".png")

func walk_toward(at:Vector2,frames:int=120):
 var from=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
 var direction=(at-from).normalized();game.camera_rig.yaw=atan2(-direction.x,-direction.y)
 Input.action_press("move_forward")
 var id=game.model.get_instance_id()
 for i in frames:
  await physics_frame
  if game.model.get_instance_id()!=id:break
  if Vector2(game.player.position.x,game.player.position.z).distance_squared_to(at*game.model.falan_scale)<pow(.4*game.model.falan_scale,2):break
 Input.action_release("move_forward");game.player.velocity=Vector3.ZERO

func visit_source(id:int,cell:Vector2i):
 if Original.owns(id):
  await super.visit_source(id,cell)
  return
 var point=load("res://scripts/forest/forest_east_region.gd").source_point(Original.source_id(id),cell)
 Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Tour.Indoor.safe_point(id,point,game.model.seed_value),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 8:await physics_frame
 check(game.model.falan_floor==id,"Existing legacy owner loads source area "+str(id))

func route_checks():
 var report=[]
 var cases=[[51021,Vector2i(9,7),4331],[51002,Vector2i(31,24),15006],[16512,Vector2i(40,53),16515],[3350,Vector2i(10,10),3352],[15551,Vector2i(60,56),15552],[5009,Vector2i(8,6),15504],[33609,Vector2i(30,6),59721]]
 if "--fengnu"in OS.get_cmdline_user_args():cases=cases.filter(func(r):return r[0]==3350)
 if "--sweep"in OS.get_cmdline_user_args()or "--legacy-entrances"in OS.get_cmdline_user_args():
  cases=[]
  var rows=preload("res://scripts/forest/forest_explore_routes.gd").data()
  for key in rows:
   var source=Original.runtime_id(int(key))
   if "--legacy-entrances"in OS.get_cmdline_user_args():
    if Original.owns(source)or source in[100,300,1000,2000,2400]:continue
    if not Tour.Indoor.Data.FLOORS.has(source)and not Tour.Regions.Sites.ROOMS.has(source)and not Tour.Falken.owns(source)and not Tour.Prayer.owns(source):continue
   elif not Original.owns(source):continue
   for row in rows[key]:
    var fields=row.script.split("|",true)
    cases.append([source,Vector2i(row.cell[0],row.cell[1]),int(row.target),row.get("type","")=="Warp" and fields.size()>4 and fields[4]=="15",Vector2i(row.landing[0],row.landing[1])])
 if "--actions"in OS.get_cmdline_user_args():
  cases=[]
  var routes=preload("res://scripts/forest/forest_explore_routes.gd")
  var npcs=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/university_region/population.json")).npcs
  for npc in npcs:
   var action:String=npc.get("quest_action","")
   var destinations:Array=routes.ALTERNATIVES.get(action,[]).duplicate()
   var target:Array=routes.ACTIONS.get(action,[])
   if action.begins_with("ice:"):target=preload("res://assets/maps/falan/university_region/ice_events.gd").EVENTS.get(action.trim_prefix("ice:"),{}).get("target",[])
   if not target.is_empty()and target not in destinations:destinations.append(target)
   for destination in destinations:cases.append([Original.runtime_id(int(npc.source)),Vector2i(npc.cell[0],npc.cell[1]),int(destination[0]),false,Vector2i(destination[1],destination[2]),action,str(npc.id)])
  var definitions=cases.map(func(c):return {"source":Original.source_id(c[0]),"runtime":c[0],"cell":[c[1].x,c[1].y],"target":c[2],"landing":[c[4].x,c[4].y],"action":c[5],"actor":c[6],"type":"Manual NPC access","name":c[5],"evidence":"assets/maps/falan/university_region/population.json"})
  var file=FileAccess.open(ACCESS_OUT+"manual-access-routes.json",FileAccess.WRITE);file.store_string(JSON.stringify({"routes":definitions},"  "));file.close()
 if "--fields"in OS.get_cmdline_user_args():
  cases=[]
  var rows=preload("res://scripts/forest/forest_explore_routes.gd").data()
  for source in[100,300,1000,2000,2400]:
   for row in rows.get(str(source),[]):
    var fields=row.script.split("|",true)
    cases.append([source,Vector2i(row.cell[0],row.cell[1]),int(row.target),row.get("type","")=="Warp"and fields.size()>4 and fields[4]=="15",Vector2i(row.landing[0],row.landing[1])])
 if "--generated-entrances"in OS.get_cmdline_user_args():
  cases=[]
  var generated=Original.generated()
  for key in generated.SPECS:
   var spec:Dictionary=generated.SPECS[key];var first=generated.floor_id(key,1);var state=Original.state(first,game.model.seed_value)
   var landing=Vector2i(((generated.landing(first,game.model.seed_value,true)-state.origin)/3.).round())
   cases.append([Original.runtime_id(int(spec.entry[0])),generated.entry_cell(key,game.model.seed_value),first,false,landing,"generated:"+key,"generated:"+key])
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--source="):cases=cases.filter(func(c):return c[0]==int(arg.trim_prefix("--source=")))
  if arg.begins_with("--skip="):cases=cases.slice(int(arg.trim_prefix("--skip=")))
  if arg.begins_with("--limit="):cases=cases.slice(0,int(arg.trim_prefix("--limit=")))
 if "--unverified"in OS.get_cmdline_user_args():
  var history=JSON.parse_string(FileAccess.get_file_as_string(ACCESS_OUT+"routes-history.json"))if FileAccess.file_exists(ACCESS_OUT+"routes-history.json")else{}
  cases=cases.filter(func(route):return not history.values().any(func(row):return row.get("passed",false)and row.get("verified_transition",false)and int(row.source)==Original.source_id(route[0])and int(row.target)==route[2]and row.get("cell","")==str(route[1])and row.get("landing","")==str(route[4])))
 for route in cases:
  print("EXPLORE_ROUTE_CASE ",route)
  var before_failures=failures
  var generated_target=route.size()>5 and str(route[5]).begins_with("generated:")
  var target_runtime=route[2]if generated_target else Original.runtime_id(route[2])
  if is_instance_valid(game.dialogue):game.close_boss_dialogue()
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.explorer_npcs.set_process(false)
  var field=route[0]in[100,300,1000,2000,2400]
  if field:
   check(preload("res://scripts/forest/forest_explore_routes.gd").travel(game,route[0],route[1]),"Published source region supplies the entrance approach")
   for i in 10:await physics_frame
  else:await visit_source(route[0],route[1])
  game.army_runtime.refresh_navigation(0)
  game.explorer_npcs.prepare()
  var info=Tour.Indoor.floor_info(game.model.falan_floor,game.model.seed_value)if not field else[Vector2i.ZERO,Vector2.ZERO,""]
  var bits=Tour.Indoor.walk_mask(game.model.falan_floor,info[0],info[2].hex_decode(),game.model.seed_value)if not field else PackedByteArray()
  var source_at=load("res://scripts/forest/forest_east_region.gd").source_point(Original.source_id(route[0]),route[1],game.model.falan_area);var prepared=false
  var old_triggers=preload("res://scripts/forest/forest_explore_routes.gd").candidates(game).filter(func(g):return g.get("target",-1)==route[2]and g.get("exclude_trigger",Rect2()).has_area()).map(func(g):return g.exclude_trigger)
  for ring in 9:
   for direction in 16:
    var at=source_at+Vector2.from_angle(direction*TAU/16.)*ring*1.5
    if old_triggers.any(func(rect):return rect.has_point(at)):continue
    if not field and not Tour.Indoor.open_cell(bits,info[0],roundi((at.x-info[1].x)/3.),roundi((at.y-info[1].y)/3.)):continue
    var world=game.model.world_point(at,.15)
    if not game.explore_access.body_clear(world) or not game.model.terrain.disk_clear(world/game.model.falan_scale,.65):continue
    if not game.army_runtime.native.can_reach_ally(world,world,.55*game.model.falan_scale):continue
    game.player.position=world;game.model.hero_position=world;game.player.reset_physics_interpolation();prepared=true;break
   if prepared:break
  game.set_physics_process(true);game.player.set_physics_process(true);game.explorer_npcs.set_process(true)
  game.explore_access.map_token=[];game.explore_access._process(.2)
  var candidates=game.explore_access.gates.filter(func(g):return g.get("target",-1)==route[2] and (route.size()<5 or g.landing==route[4]))
  candidates.sort_custom(func(a,b):return a.at.distance_squared_to(source_at)<b.at.distance_squared_to(source_at))
  if candidates.is_empty():
   if route.size()>3 and route[3]:
    var approached=false
    for direction in 16:
     var approach=source_at+Vector2.from_angle(direction*TAU/16.)*4.5;var world=game.model.world_point(approach,.15)
     if not game.explore_access.body_clear(world) or not game.army_runtime.native.can_reach_ally(world,game.model.world_point(source_at,.15),.55*game.model.falan_scale):continue
     game.player.position=world;game.model.hero_position=world;game.player.reset_physics_interpolation();approached=true;break
    if approached:game.set_process(true);await walk_toward(source_at,180)
    for i in 8:await physics_frame
    check(approached and destination_matches(route[2]),"Original automatic warp remains walkable")
    var left=await leave_ordinary()
    check(left,"Original automatic destination has a walkable exit")
    report.append({"source":Original.source_id(route[0]),"runtime":route[0],"cell":str(route[1]),"target":route[2],"landing":str(route[4]),"status":"Original automatic warp walked and destination exited","verified_transition":approached and left,"passed":failures==before_failures});save_routes(report);continue
   var ordinary=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("floor",link.get("site",-1)))==target_runtime and link.at.distance_squared_to(source_at)<9.*9. and not preload("res://scripts/forest/forest_explore_routes.gd").restricted(link))
   if not ordinary.is_empty():
    var entered=await walk_door(ordinary[0].at)
    check(entered and destination_matches(route[2],generated_target),"Ordinary working entrance remains walkable")
    var left=false
    if entered:left=await leave_ordinary()
    check(left,"Ordinary destination can be left through its original exit")
    report.append({"source":Original.source_id(route[0]),"runtime":route[0],"cell":str(route[1]),"target":route[2],"landing":str(route[4]),"status":"Original door walked and destination exited","verified_transition":entered and left,"passed":failures==before_failures});save_routes(report);continue
   report.append({"source":Original.source_id(route[0]),"runtime":route[0],"cell":str(route[1]),"target":route[2],"blocker":"No reachable gate produced","gates":game.explore_access.gates,"diagnostics":gate_diagnostics(source_at,route[2])})
   save_routes(report)
   check(false,"Repaired route has a reachable named Cross Gate %d → %d"%[route[0],route[2]]);continue
  var gate:Dictionary=candidates[0];var station:Vector2=gate.at
  var approaches=[]
  var excluded:Rect2=gate.get("exclude_trigger",Rect2())
  var edges=[excluded.position,Vector2(excluded.end.x,excluded.position.y),excluded.end,Vector2(excluded.position.x,excluded.end.y)]if excluded.has_area()else[]
  for direction in 16:
   var p=station+Vector2.from_angle(direction*TAU/16.)*3.
   if excluded.has_area()and excluded.has_point(p):continue
   var crosses=false
   for i in edges.size():
    if Geometry2D.segment_intersects_segment(p,station,edges[i],edges[(i+1)%edges.size()])!=null:crosses=true;break
   if crosses:continue
   if not field and not Tour.Indoor.open_cell(bits,info[0],roundi((p.x-info[1].x)/3.),roundi((p.y-info[1].y)/3.)):continue
   var point=game.model.world_point(p,.15)
   if not game.explore_access.body_clear(point):continue
   if not game._ryo_clear_path(point+Vector3.UP*1.2*game.model.falan_scale,game.model.world_point(station,1.2*game.model.falan_scale)):continue
   if game.model.terrain.disk_clear(point/game.model.falan_scale,.55)and game.army_runtime.native.can_reach_ally(point,game.model.world_point(station,.15),.55*game.model.falan_scale):approaches.append(p)
  check(not approaches.is_empty(),"Gate has an actual walk-in approach %d"%route[0])
  if approaches.is_empty():
   report.append({"source":Original.source_id(route[0]),"runtime":route[0],"cell":str(route[1]),"target":route[2],"landing":str(route[4])if route.size()>4 else"","passed":false,"blocker":"No physical walk-in approach found by fixture","station":str(station)});save_routes(report);continue
  game.player.position=game.model.world_point(approaches[0],.15);game.player.reset_physics_interpolation();game.model.hero_position=game.player.position
  game.set_process(true)
  await walk_toward(station)
  check(Vector2(game.player.position.x,game.player.position.z).distance_to(station*game.model.falan_scale)<.8*game.model.falan_scale,"Actual movement reaches the Cross Gate %d"%route[0])
  var gold=game.model.gold;var items:Dictionary=get_meta("university_quest_items",{}).duplicate(true);var quests=game.settings.explorer_quests.duplicate(true)
  var source_area=game.model.falan_area
  var context={"before_map":game.model.falan_floor,"hero":str(game.player.position),"gate":str(station),"gate_sight":game._ryo_clear_path(game.player.position+Vector3.UP*2.5*game.model.falan_scale,game.model.world_point(station,2.5)),"paused":game.paused,"transitioning":game.transitioning,"dialogue":game.dialogue.speaker if is_instance_valid(game.dialogue)else"closed"}
  var before_model=game.model.get_instance_id()
  context.rays=[]
  for height in [1.,1.5,2.5]:
   var query=PhysicsRayQueryParameters3D.create(game.player.position+Vector3.UP*height*game.model.falan_scale,game.model.world_point(station,height*game.model.falan_scale),1);query.hit_from_inside=true
   var hit=game.get_world_3d().direct_space_state.intersect_ray(query)
   context.rays.append({"height":height,"collider":str(hit.collider.get_path())if not hit.is_empty()else"clear","position":str(hit.get("position",Vector3.ZERO))})
  press_f()
  if is_instance_valid(game.dialogue):
   var options:Array=game.dialogue.pages[0].options
   var option=options.filter(func(o):return o[1]==gate.caption)
   check(not option.is_empty(),"Actual gate menu names intended destination")
   if not option.is_empty():game.dialogue.chosen.emit(option[0][0])
  context.transitions=[]
  for i in 8:
   await physics_frame
   context.transitions.append({"floor":game.model.falan_floor,"area":game.model.falan_area,"position":str(game.player.position)})
  var transferred=before_model!=game.model.get_instance_id()
  check(transferred and destination_matches(route[2],generated_target),"Actual F loads intended destination %d"%route[2])
  var entered_at=game.player.position
  if route.size()>4 and Original.owns(target_runtime):
   var expected=Original.source_point(target_runtime,route[4])
   check(Vector2(entered_at.x,entered_at.z).distance_to(expected*game.model.falan_scale)<8.*game.model.falan_scale,"Cross Gate reaches the selected destination entrance")
  check(game.model.gold==gold and get_meta("university_quest_items",{})==items and game.settings.explorer_quests==quests,"Explore transfer grants no prerequisite, completion or reward")
  game.explore_access._process(.2)
  var backs=game.explore_access.gates.filter(func(g):return g.get("back",false))
  context.return_diagnostics={"prepared":game.explore_access.map_token,"native_ready":game.army_runtime.configured_model==game.model and game.army_runtime.navigation_revision==game.model.navigation_revision,"bookmark":game.explore_access.pending_return,"registered":game.explore_access.returns.get(game.explore_access.scope(),{}),"safe":str(game.explore_access.safe_station(Vector2(entered_at.x,entered_at.z)/game.model.falan_scale)),"gates":game.explore_access.gates,"at":gate_diagnostics(Vector2(entered_at.x,entered_at.z)/game.model.falan_scale,route[0])}
  check(backs.size()==1,"Destination has exactly one usable Explore return")
  if not backs.is_empty():
   game.player.position=game.model.world_point(backs[0].at,.15);game.player.reset_physics_interpolation();game.model.hero_position=game.player.position
   press_f()
   if is_instance_valid(game.dialogue):
    var option=game.dialogue.pages[0].options.filter(func(o):return o[1]==backs[0].caption)
    if not option.is_empty():game.dialogue.chosen.emit(option[0][0])
   for i in 8:await physics_frame
   check((game.model.falan_area==source_area and destination_matches(route[0]))if field else game.model.falan_floor==game.explorer_clock.phase_floor(route[0]),"Actual F leaves the destination and returns to original entrance")
  report.append({"source":Original.source_id(route[0]),"runtime":route[0],"cell":str(route[1]),"target":route[2],"landing":str(route[4])if route.size()>4 else"","action":route[5]if route.size()>5 else"","actor":route[6]if route.size()>6 else"","station":str(station),"entered_at":str(entered_at),"verified_transition":transferred,"actual_return":game.model.falan_floor,"passed":failures==before_failures,"interaction":context})
  save_routes(report)
  await access_capture("gate-%d-%d"%[route[0],route[2]])
 save_routes(report)
 print("EXPLORE_ROUTES_RESULT checks=",checks," failures=",failures)

func walk_door(at:Vector2)->bool:
 var before=game.model.get_instance_id()
 for direction in 16:
  var approach=at+Vector2.from_angle(direction*TAU/16.)*6.
  var point=game.model.world_point(approach,.15)
  if not game.explore_access.body_clear(point)or not game.model.terrain.disk_clear(point/game.model.falan_scale,.55):continue
  if not game.army_runtime.native.can_reach_ally(point,game.model.world_point(at,.15),.55*game.model.falan_scale):continue
  if not game._ryo_clear_path(point+Vector3.UP*1.2,game.model.world_point(at,1.2)):continue
  game.player.position=point;game.model.hero_position=point;game.player.reset_physics_interpolation();game.falan_crossing_position=approach
  game.set_process(true)
  await walk_toward(at,180)
  for i in 8:await physics_frame
  if before!=game.model.get_instance_id():return true
 return false

func leave_ordinary()->bool:
 var links=game.model.get_meta("falan_links",[]).filter(func(link):return link.get("walk_in",false)and not preload("res://scripts/forest/forest_explore_routes.gd").restricted(link))
 links.sort_custom(func(a,b):return game.player.position.distance_squared_to(game.model.world_point(a.at))<game.player.position.distance_squared_to(game.model.world_point(b.at)))
 for link in links:
  if await walk_door(link.at):return true
 return false

func save_routes(report:Array):
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
 var path=ACCESS_OUT+"routes-"+mode+".json"
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify({"routes":report,"checks":checks,"failures":failures},"  "));f.close()
 var history_path=ACCESS_OUT+"routes-history.json"
 var history=JSON.parse_string(FileAccess.get_file_as_string(history_path)) if FileAccess.file_exists(history_path) else {}
 for row in report:history["%s:%s:%s:%s:%s"%[row.source,row.get("cell",""),row.target,row.get("landing",""),mode]]=row
 f=FileAccess.open(history_path,FileAccess.WRITE);f.store_string(JSON.stringify(history,"  "));f.close()

func destination_matches(source:int,runtime:bool=false)->bool:
 var area=Tour.area(game.model)
 if source==1000:return area=="city"
 if source==100:return area in Tour.SouthPopulation.FREYJA_AREAS or area in["east_gate","north_coast"]
 if source==300:return area in["sokia_coast","sokia_desert","ghana_road","ghana_north_road"]
 if source in[2000,2400]:return area==("east_gate"if source==2000 else"north_coast") and Tour.Regions.village_contains(area,Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale)
 return game.model.falan_floor==game.explorer_clock.phase_floor(source if runtime else Original.runtime_id(source))

func gate_diagnostics(at:Vector2,target:int)->Dictionary:
 var routes=preload("res://scripts/forest/forest_explore_routes.gd");var model=game.model
 var info=Tour.Indoor.floor_info(model.falan_floor,model.seed_value);var bits=Tour.Indoor.walk_mask(model.falan_floor,info[0],info[2].hex_decode(),model.seed_value)
 var cell=Vector2i(((at-info[1])/3.).round());var point=model.world_point(at,.15)
 return {"floor":model.falan_floor,"area":model.falan_area,"player":str(game.player.position),"requested":str(at),"candidates":routes.candidates(game),"station":str(game.explore_access.safe_station(at)),"source_open":Tour.Winter.Recovered.open(bits,info[0],cell),"body_clear":game.explore_access.body_clear(point),"terrain":model.terrain.disk_clear(point/model.falan_scale,.65),"native_reach":game.army_runtime.native.can_reach_ally(game.player.position,point,.55*model.falan_scale)}
