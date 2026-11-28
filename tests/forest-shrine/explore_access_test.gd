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
 set_test_seed()
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

func walk_toward(at:Vector2,frames:int=120,full_path:bool=false,direct_input:bool=false):
 var from=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
 var points:Array[Vector2]=[at]
 var plan={"direct":true}
 var segment_clear=game._ryo_clear_path(game.player.position+Vector3.UP*1.2,game.model.world_point(at,1.2))
 var indoor=game.model.falan_area=="interior"
 var incidental_doors=game.model.get_meta("falan_links",[]).filter(func(link):return full_path and link.get("walk_in",false)and not link.get("explore_gate_only",false)and link.at.distance_squared_to(at)>pow(Tour.WALK_IN_RADIUS+.4,2)and link.at.distance_squared_to(from)>pow(Tour.WALK_IN_RADIUS+.4,2)).map(func(link):return link.at)
 if not direct_input and (indoor or full_path)and segment_clear:
  var steps=maxi(1,ceili(from.distance_to(at)/.75))
  for i in range(1,steps+1):
   var sample=from.lerp(at,float(i)/steps)
   if incidental_doors.any(func(door):return door.distance_squared_to(sample)<=pow(Tour.WALK_IN_RADIUS+.4,2))or not game.explore_access.body_clear(game.model.world_point(sample,.15)):
    segment_clear=false;break
 if not direct_input and (indoor or full_path)and not segment_clear:
  var info=Tour.Indoor.floor_info(game.model.falan_floor,game.model.seed_value)if indoor else[game.model.terrain.mask_image().get_size(),game.model.terrain.mask_origin(),""]
  var bits=Tour.Indoor.walk_mask(game.model.falan_floor,info[0],info[2].hex_decode(),game.model.seed_value)if indoor else PackedByteArray()
  # Match the existing graveyard terrain/chart, including its retained native approach maze.
  if indoor and game.model.falan_floor==Tour.Dungeons.GRAVE and not Original.owns(game.model.falan_floor):info[0].y+=Tour.Indoor.GRAVE_MAZE_SIZE.y
  var step=.75;var first=Vector2i.ZERO;var last=Vector2i(((at-from)/step).round())
  var low=Vector2i(((info[1]-from)/step).ceil());var high=Vector2i(((info[1]+Vector2(info[0])*3.-from)/step).floor())
  # Start local on continental maps; retain the full source fallback for long maze detours.
  var full_region=Rect2i(low,high-low+Vector2i.ONE);var path=[];var started=Time.get_ticks_msec()
  for margin in[32,128,-1]:
   var region=full_region if margin<0 else Rect2i(first.min(last)-Vector2i.ONE*margin,(first-last).abs()+Vector2i.ONE*(margin*2+1)).intersection(full_region)
   var grid=AStarGrid2D.new();grid.region=region;grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
   for y in range(region.position.y,region.end.y):
    for x in range(region.position.x,region.end.x):
     var cell=Vector2i(x,y)
     var source_point=from+Vector2(cell)*step;var source_cell=Vector2i(((source_point-info[1])/3.).round())
     var point=game.model.world_point(source_point,.15)
     var open=Original.open(bits,info[0],source_cell)if indoor else game.model.terrain.disk_clear(point/game.model.falan_scale,.65)
     var door=incidental_doors.any(func(center):return center.distance_squared_to(source_point)<=pow(Tour.WALK_IN_RADIUS+.4,2))
     grid.set_point_solid(cell,door or not open or not game.explore_access.body_clear(point))
   if region.has_point(first):grid.set_point_solid(first,false)
   if region.has_point(last):grid.set_point_solid(last,false)
   if region.has_point(first)and region.has_point(last):path=grid.get_id_path(first,last)
   plan={"direct":false,"region":str(region),"steps":path.size(),"margin":margin,"from":str(from),"target":str(at),"elapsed_msec":Time.get_ticks_msec()-started}
   if not path.is_empty()or region==full_region:break
  print("EXPLORE_WALK_PLAN ",plan)
  if full_path and path.is_empty():return
  if not path.is_empty():
   points.clear()
   for cell in path.slice(1,path.size()-1):points.append(from+Vector2(cell)*step)
   points.append(at)
 if full_path:frames=maxi(frames,points.size()*32)
 Input.action_press("move_forward")
 var id=game.model.get_instance_id()
 for i in frames:
  from=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
  while points.size()>1 and from.distance_squared_to(points[0])<.2*.2:points.pop_front()
  var direction=(points[0]-from).normalized();game.camera_rig.yaw=atan2(-direction.x,-direction.y)
  await physics_frame
  if game.model.get_instance_id()!=id:break
  if Vector2(game.player.position.x,game.player.position.z).distance_squared_to(at*game.model.falan_scale)<pow(.4*game.model.falan_scale,2):break
 if game.model.get_instance_id()==id and Vector2(game.player.position.x,game.player.position.z).distance_squared_to(at*game.model.falan_scale)>pow(.8*game.model.falan_scale,2):
  print("EXPLORE_WALK_INCOMPLETE ",{"target":str(at),"actual":str(game.player.position),"floor":game.model.falan_floor,"changed_map":game.model.get_instance_id()!=id,"input":str(Input.get_vector("move_left","move_right","move_forward","move_back")),"physics":game.player.is_physics_processing(),"on_floor":game.player.is_on_floor(),"mode":game.player.active_ability.mode,"blocks_movement":game.player.active_ability.blocks_movement(),"plan":plan,"next_point":str(points[0]),"points_left":points.size(),"slides":range(game.player.get_slide_collision_count()).map(func(j):var c=game.player.get_slide_collision(j);return {"collider":str(c.get_collider().get_path())if is_instance_valid(c.get_collider())else"removed","point":str(c.get_position()),"normal":str(c.get_normal())}),"paused":game.paused,"transitioning":game.transitioning})
 Input.action_release("move_forward");game.player.velocity=Vector3.ZERO

func set_test_seed():
 var seed_=20261127
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--seed="):seed_=int(arg.trim_prefix("--seed="))
 game.run_seed=seed_;game.model.seed_value=seed_
 print("EXPLORE_TEST_SEED ",seed_)

func visit_source(id:int,cell:Vector2i):
 if Original.generated().owns(id)or Original.Beast.owns(id):
  var point=Original.source_point(id,cell,game.model.seed_value)
  Tour.travel(game,Original.layout(id),{"arrival":Tour.Indoor.safe_point(id,point,game.model.seed_value),"yaw":0.,"velocity":Vector3.ZERO})
  for i in 8:await physics_frame
  check(game.model.falan_floor==id,"Existing generated owner loads source area "+str(id))
  return
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
    if Original.owns(source)or source in[100,300,1000,1500,2000,2100,2300,2400,3000,3200]:continue
    if not Tour.Indoor.Data.FLOORS.has(source)and not Tour.Regions.Sites.ROOMS.has(source)and not Tour.Falken.owns(source)and not Tour.Prayer.owns(source):continue
   elif not Original.owns(source):continue
   for row in rows[key]:
    if row.get("victory_only",false):continue
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
   for destination in destinations:
    cases.append([Original.runtime_id(int(npc.source)),Vector2i(npc.cell[0],npc.cell[1]),int(destination[0]),false,Vector2i(destination[1],destination[2]),action,str(npc.id)])
    if action=="music_secret":cases.append([4417,Vector2i(npc.cell[0],npc.cell[1]),int(destination[0]),false,Vector2i(destination[1],destination[2]),action,str(npc.id)])
  cases.append([23001,Vector2i(25,27),23001,false,Vector2i(23,23),"falken_seal","restricted_door"])
  var definitions=cases.map(func(c):return {"source":Original.source_id(c[0]),"runtime":c[0],"cell":[c[1].x,c[1].y],"target":c[2],"landing":[c[4].x,c[4].y],"action":c[5],"actor":c[6],"type":"Manual NPC access","name":c[5],"evidence":"scripts/forest/forest_falken_route.gd"if c[5]=="falken_seal"else"assets/maps/falan/university_region/population.json"})
  var file=FileAccess.open(ACCESS_OUT+"manual-access-routes.json",FileAccess.WRITE);file.store_string(JSON.stringify({"routes":definitions},"  "));file.close()
 if "--fields"in OS.get_cmdline_user_args():
  cases=[]
  var rows=preload("res://scripts/forest/forest_explore_routes.gd").data()
  for source in[100,300,1000,1500,2000,2100,2300,2400,3000,3200]:
   for row in rows.get(str(source),[]):
    if row.get("victory_only",false):continue
    var fields=row.script.split("|",true)
    cases.append([source,Vector2i(row.cell[0],row.cell[1]),int(row.target),row.get("type","")=="Warp"and fields.size()>4 and fields[4]=="15",Vector2i(row.landing[0],row.landing[1])])
 if "--wells"in OS.get_cmdline_user_args():
  cases=[]
  for row in preload("res://scripts/forest/forest_explore_routes.gd").data().get("3000",[]):
   if str(row.actor)=="6515"and int(row.target)==5005:cases.append([3000,Vector2i(row.cell[0],row.cell[1]),5005,false,Vector2i(5,4)])
  cases.append([5005,Vector2i(18,14),5006,false,Vector2i(7,10)])
  check(cases.size()==2,"Pinned Ghana well entrance and original house doorway are both represented")
 if "--inline-frontages"in OS.get_cmdline_user_args():
  cases=[]
  var inventory=JSON.parse_string(FileAccess.get_file_as_string(ACCESS_OUT+"runtime-inventory.json"))
  var available=inventory.maps.filter(func(row):return row.available_source).map(func(row):return int(row.source))
  for rows in preload("res://scripts/forest/forest_explore_routes.gd").data().values():
   for row in rows:
    if not row.get("explore_inline",false)or int(row.source)not in available:continue
    var fields=row.script.split("|",true)
    cases.append([Original.runtime_id(int(row.source)),Vector2i(row.cell[0],row.cell[1]),int(row.target),fields.size()>4 and fields[4]=="15",Vector2i(row.landing[0],row.landing[1])])
 if "--namespace-repairs"in OS.get_cmdline_user_args():
  cases=[]
  for rows in preload("res://scripts/forest/forest_explore_routes.gd").data().values():
   for row in rows:
    if int(row.target)in[32050,32051,30195,32203]:cases.append([Original.runtime_id(int(row.source)),Vector2i(row.cell[0],row.cell[1]),int(row.target),false,Vector2i(row.landing[0],row.landing[1])])
  check(cases.size()==17,"All ship-room, memorial and mall entrances have actual route cases")
 if "--book-exits"in OS.get_cmdline_user_args():cases=[[31806,Vector2i(28,18),33000,false,Vector2i(574,318)],[31807,Vector2i(36,24),300,false,Vector2i(653,178)]]
 if "--namespace-first-routes"in OS.get_cmdline_user_args():
  cases=[]
  var bindings=JSON.parse_string(FileAccess.get_file_as_string(ACCESS_OUT+"Namespace review/local-EX-bindings.json"))
  var inventory=JSON.parse_string(FileAccess.get_file_as_string(ACCESS_OUT+"runtime-inventory.json"))
  var available=inventory.maps.filter(func(row):return row.available_source).map(func(row):return int(row.source))
  var rows=[]
  for group_ in preload("res://scripts/forest/forest_explore_routes.gd").data().values():rows.append_array(group_)
  for binding in bindings:
   var choices=rows.filter(func(row):return int(row.target)==int(binding.map)and int(row.source)in available and not row.get("victory_only",false))
   choices.sort_custom(func(a,b):return int(a.source)!=int(binding.map)and int(b.source)==int(binding.map))
   if choices.is_empty():continue # Gallery32065 is reachable after original boss1101960; test its actual victory exit.
   var row:Dictionary=choices[0]
   cases.append([Original.runtime_id(int(row.source)),Vector2i(row.cell[0],row.cell[1]),int(row.target),false,Vector2i(row.landing[0],row.landing[1])])
  check(cases.size()==18,"Every reviewed namespace has an actual entrance case or the original victory-only gallery encounter")
 if "--source-repairs"in OS.get_cmdline_user_args():
  cases=[]
  for rows in preload("res://scripts/forest/forest_explore_routes.gd").data().values():
   for row in rows:
    if row.has("source_repair"):cases.append([Original.runtime_id(int(row.source)),Vector2i(row.cell[0],row.cell[1]),int(row.target),false,Vector2i(row.landing[0],row.landing[1])])
  check(cases.size()==3,"Each authenticated arena-return typo has its own actual interaction case")
 if "--native-frontages"in OS.get_cmdline_user_args():
  cases=[]
  var routes=preload("res://scripts/forest/forest_explore_routes.gd").data()
  for rows in routes.values():
   for row in rows:
    if str(row.actor)not in["6081","6094"]:continue
    cases.append([Original.runtime_id(int(row.source)),Vector2i(row.cell[0],row.cell[1]),int(row.target),false,Vector2i(row.landing[0],row.landing[1])])
  check(cases.size()==2,"Pinned town quest frontages are present in the Explore route catalog")
 if "--housing"in OS.get_cmdline_user_args():
  cases=[]
  for rows in preload("res://scripts/forest/forest_explore_routes.gd").data().values():
   for row in rows:
    if row.get("type","")=="HouseWarp2":cases.append([Original.runtime_id(int(row.source)),Vector2i(row.cell[0],row.cell[1]),int(row.target),false,Vector2i(row.landing[0],row.landing[1]),"housing",str(row.actor)])
 if "--generated-entrances"in OS.get_cmdline_user_args():
  cases=[]
  var generated=Original.generated()
  for key in generated.SPECS:
   var spec:Dictionary=generated.SPECS[key];var first=generated.floor_id(key,1);var state=Original.state(first,game.model.seed_value)
   var landing=Vector2i(((generated.landing(first,game.model.seed_value,true)-state.origin)/3.).round())
   var entry=load("res://scripts/forest/forest_east_region.gd").prepare_field_entry(key,game.model.seed_value)if int(spec.entry[0])==100 and spec.get("east",false)else generated.entry_cell(key,game.model.seed_value)
   cases.append([Original.runtime_id(int(spec.entry[0])),entry,first,false,landing,"generated:"+key,"generated:"+key])
  var definitions=cases.map(func(c):return {"source":Original.source_id(c[0]),"runtime":c[0],"cell":[c[1].x,c[1].y],"target":c[2],"landing":[c[4].x,c[4].y],"action":c[5],"actor":c[6],"type":"Generated branch access","name":c[5],"seed":game.model.seed_value,"evidence":"scripts/forest/forest_original_dungeons.gd"})
  var file=FileAccess.open(ACCESS_OUT+"generated-access-routes.json",FileAccess.WRITE);file.store_string(JSON.stringify({"routes":definitions},"  "));file.close()
 if "--generated-returns"in OS.get_cmdline_user_args():
  cases=[]
  var generated=Original.generated()
  for key in generated.SPECS:
   var spec:Dictionary=generated.SPECS[key]
   if spec.end.is_empty():continue
   var last:int=generated.floor_id(key,generated.count(key,game.model.seed_value));var state=Original.state(last,game.model.seed_value)
   var landing=Vector2i(((generated.landing(last,game.model.seed_value,false)-state.origin)/3.).round())
   cases.append([Original.runtime_id(int(spec.end[0])),Vector2i(spec.end[1],spec.end[2]),last,false,landing,"generated:"+key+":return","generated:"+key])
  var definitions=cases.map(func(c):return {"source":Original.source_id(c[0]),"runtime":c[0],"cell":[c[1].x,c[1].y],"target":c[2],"landing":[c[4].x,c[4].y],"action":c[5],"actor":c[6],"type":"Generated endpoint return","name":c[5],"seed":game.model.seed_value,"evidence":"scripts/forest/forest_original_dungeons.gd"})
  var file=FileAccess.open(ACCESS_OUT+"generated-return-routes.json",FileAccess.WRITE);file.store_string(JSON.stringify({"routes":definitions},"  "));file.close()
 if "--generated-floors"in OS.get_cmdline_user_args():
  cases=[]
  var generated=Original.generated()
  for key in preload("res://assets/maps/falan/explore-dungeon-specs.gd").SPECS:
   for n in range(1,generated.count(key,game.model.seed_value)+1):
    var id=generated.floor_id(key,n);var state=Original.state(id,game.model.seed_value)
    var links=Original.links(id,game.model.seed_value)
    if links.size()<2:continue
    var link:Dictionary=links[1];var target=int(link.floor);var target_state=Original.state(target,game.model.seed_value)
    var cell=Vector2i(((link.at-state.origin)/3.).round())
    var landing=Vector2i(((link.arrival-target_state.origin)/3.).round())+Original.crop(target).position
    cases.append([id,cell,target,false,landing,"generated:"+key+":floor:%d"%n,"generated:"+key])
  var definitions=cases.map(func(c):return {"source":c[0],"runtime":c[0],"cell":[c[1].x,c[1].y],"target":c[2],"landing":[c[4].x,c[4].y],"action":c[5],"actor":c[6],"type":"Generated floor stair","name":Original.title(c[0]),"seed":game.model.seed_value,"evidence":"assets/maps/falan/explore-dungeon-specs.gd"})
  var file=FileAccess.open(ACCESS_OUT+"generated-floor-routes.json",FileAccess.WRITE);file.store_string(JSON.stringify({"routes":definitions},"  "));file.close()
 if "--native-field-doors"in OS.get_cmdline_user_args():
  cases=[]
  for port in preload("res://scripts/forest/forest_sokia_scenery.gd").COAST_PORTS:
   cases.append([300,Vector2i(port[0],port[1]),Original.source_id(int(port[2])),false,Vector2i(port[3],port[4]),"native-field:"+port[6],port[5]])
  for site in Tour.Regions.Sites.SITES:
   if site[3]=="village":continue # Joined villages retain continuous outdoor walking, not a scene transfer.
   var source=300 if site[0]in Tour.SouthPopulation.SOKIA_AREAS else 100
   var cell=Vector2i((site[4]/3.).round());var target=int(site[2]);var arrival:Vector2=site[6]
   if target in preload("res://scripts/forest/forest_explore_routes.gd").RESTORED_FIELD_SITES:
    var entry:Array=[target,site[6]]if target in[410,47010]else Tour.Dungeons.ENTRANCES[target]
    target=int(entry[0]);arrival=entry[1]
   var info=Tour.Indoor.floor_info(target,game.model.seed_value)
   var landing=Vector2i(((arrival-info[1])/3.).round())+(Original.crop(target).position if Original.owns(target)else Vector2i.ZERO)
   var area=Tour.Regions.canonical_area(site[0])
   var entrance_at:Vector2=Tour.Regions.frame(area).inverse()*site[4]+(Vector2(0,12)if int(site[2])==47010 else Vector2.ZERO)
   var entered_floor=target if int(site[2])in preload("res://scripts/forest/forest_explore_routes.gd").RESTORED_FIELD_SITES else int(Tour.Dungeons.ENTRANCES.get(target,[target,site[6]])[0])
   cases.append([source,cell,Original.source_id(target),false,landing,"native-field:"+site[3],site[1],area,entrance_at,entered_floor,int(site[2])])
  var definitions=cases.map(func(c):return {"source":c[0],"runtime":c[0],"cell":[c[1].x,c[1].y],"target":c[2],"landing":[c[4].x,c[4].y],"type":"Native field door","name":c[6],"native_destination_runtime":c[9]if c.size()>9 else Original.runtime_id(c[2]),"original_site":c[10]if c.size()>10 else null,"qualification":"Explore Cross Gate restores a removed or physically obstructed field entrance to a complete existing dungeon."if c.size()>10 and c[10]in preload("res://scripts/forest/forest_explore_routes.gd").RESTORED_FIELD_SITES else"Existing native entrance and its retained arena adaptation; not proof of visiting an alternate original source layout.","seed":game.model.seed_value,"evidence":"forest_sokia_scenery.gd COAST_PORTS / freyja_destinations_data.gd SITES"})
  var file=FileAccess.open(ACCESS_OUT+"native-field-routes.json",FileAccess.WRITE);file.store_string(JSON.stringify({"routes":definitions},"  "));file.close()
 if "--native-maze-floors"in OS.get_cmdline_user_args():
  cases=[]
  var ids=[51009,51010]
  for n in Original.Beast.COUNT:ids.append(Original.Beast.FIRST+n)
  for id:int in ids:
   var next=51010 if id==51009 else 51303 if id==51010 else 16511 if id==Original.Beast.FIRST+Original.Beast.COUNT-1 else id+1
   var links=Original.links(id,game.model.seed_value).filter(func(link):return int(link.get("floor",-1))==next)
   check(not links.is_empty(),"Native maze floor retains its original onward stair "+str(id))
   if links.is_empty():continue
   var state=Original.state(id,game.model.seed_value);var target=Original.state(next,game.model.seed_value)
   var cell=Vector2i(((links[0].at-state.origin)/3.).round())+Original.crop(id).position
   var landing=Vector2i(((links[0].arrival-target.origin)/3.).round())+Original.crop(next).position
   cases.append([id,cell,next,false,landing,"generated:native-maze","native-maze:"+str(id)])
  var definitions=cases.map(func(c):return {"source":Original.source_id(c[0]),"runtime":c[0],"cell":[c[1].x,c[1].y],"target":c[2],"landing":[c[4].x,c[4].y],"type":"Native maze stair","name":Original.title(c[0]),"seed":game.model.seed_value})
  var file=FileAccess.open(ACCESS_OUT+"native-maze-floor-routes.json",FileAccess.WRITE);file.store_string(JSON.stringify({"routes":definitions},"  "));file.close()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--source="):cases=cases.filter(func(c):return c[0]==int(arg.trim_prefix("--source=")))
  if arg.begins_with("--target="):cases=cases.filter(func(c):return c[2]==int(arg.trim_prefix("--target=")))
 if "--unverified"in OS.get_cmdline_user_args():
  var history=JSON.parse_string(FileAccess.get_file_as_string(ACCESS_OUT+"routes-history.json"))if FileAccess.file_exists(ACCESS_OUT+"routes-history.json")else{}
  cases=cases.filter(func(route):return not history.values().any(func(row):return row.get("passed",false)and row.get("verified_transition",false)and (row.get("return_walked",false)or row.get("ordinary_walk_contract","")=="continuous-entry-exit-v1"or row.get("after_full_victory",false))and int(row.source)==Original.source_id(route[0])and int(row.get("runtime",Original.runtime_id(int(row.source))))==int(route[0])and int(row.target)==route[2]and row.get("cell","")==str(route[1])and row.get("landing","")==str(route[4])))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--skip="):cases=cases.slice(int(arg.trim_prefix("--skip=")))
  if arg.begins_with("--limit="):cases=cases.slice(0,int(arg.trim_prefix("--limit=")))
 for route in cases:
  print("EXPLORE_ROUTE_CASE ",route)
  var before_failures=failures
  var generated_target=route.size()>5 and str(route[5]).begins_with("generated:")
  var target_runtime=route[2]if generated_target else Original.runtime_id(route[2])
  if is_instance_valid(game.dialogue):game.close_boss_dialogue()
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.explorer_npcs.set_process(false)
  var exact_phase=game.explorer_clock.TINA_VARIANTS.has(Original.source_id(target_runtime))or game.explorer_clock.MUSIC_VARIANTS.has(Original.source_id(target_runtime))
  var phase_target=target_runtime if exact_phase else route[0]
  if route[2]==4100:
   check(Original.state(4100,game.model.seed_value).size==Vector2i(150,150),"Astia uses its complete recovered town instead of the obsolete boundary crop")
   check(Original.source_point(4100,Vector2i(61,130))==Vector2(0,9),"Full Astia preserves the original playable boundary and saved-position coordinates")
  if game.explorer_clock.phase_floor(phase_target)!=phase_target:
   for hour in[12.,0.]:
    game.explorer_clock.load_hour(hour)
    if game.explorer_clock.phase_floor(phase_target)==phase_target:break
  var field=route[0]in[100,300,1000,1500,2000,2100,2300,2400,3000,3200]
  var native_field=route.size()>8 and str(route[5]).begins_with("native-field:")
  if field:
   if native_field:
    Tour.travel(game,Tour.outdoor_layout(get_meta("falan_venture"),route[7]),{"arrival":route[8],"yaw":0.,"velocity":Vector3.ZERO,"preserve_checkpoint":true})
    check(Tour.area(game.model)==route[7],"Native entrance uses its original outdoor view")
   else:check(preload("res://scripts/forest/forest_explore_routes.gd").travel(game,route[0],route[1]),"Published source region supplies the entrance approach")
   for i in 10:await physics_frame
  elif game.model.falan_area!="interior"or game.model.falan_floor!=route[0]:await visit_source(route[0],route[1])
  game.army_runtime.refresh_navigation(0)
  game.explorer_npcs.prepare()
  var info=Tour.Indoor.floor_info(game.model.falan_floor,game.model.seed_value)if not field else[Vector2i.ZERO,Vector2.ZERO,""]
  var bits=Tour.Indoor.walk_mask(game.model.falan_floor,info[0],info[2].hex_decode(),game.model.seed_value)if not field else PackedByteArray()
  var source_at=Original.source_point(route[0],route[1],game.model.seed_value)if Original.generated().owns(route[0])or Original.Beast.owns(route[0])else load("res://scripts/forest/forest_east_region.gd").source_point(Original.source_id(route[0]),route[1],game.model.falan_area);var prepared=false
  if native_field:source_at=route[8]
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
  if "--normal-approach"in OS.get_cmdline_user_args()and route[0]==51031 and route[2]==32467:
   var point=game.model.world_point(Original.source_point(51031,Vector2i(304,429)),.15)
   check(game.explore_access.body_clear(point),"Southern-road approach starts on the preserved original road")
   check(Original.source_point(51031,Vector2i(304,429))==Vector2(-183,312),"Extending Shalena preserves its existing road and saved-position coordinates")
   game.player.position=point;game.model.hero_position=point;game.player.reset_physics_interpolation()
  if "--normal-approach"in OS.get_cmdline_user_args()and route[0]==36003:
   var point=game.model.world_point(Original.source_point(36003,Vector2i(1,7)),.15)
   check(game.explore_access.body_clear(point),"Poka approach begins at the original outdoor-entry stair")
   game.player.position=point;game.model.hero_position=point;game.player.reset_physics_interpolation()
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
    report.append({"source":Original.source_id(route[0]),"runtime":route[0],"cell":str(route[1]),"target":route[2],"landing":str(route[4]),"status":"Original automatic warp walked and destination exited","ordinary_walk_contract":"continuous-entry-exit-v1","verified_transition":approached and left,"passed":failures==before_failures});save_routes(report);continue
   var expected_arrival:Vector2=load("res://scripts/forest/forest_east_region.gd").source_point(route[2],route[4],game.model.falan_area)
   var ordinary=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("floor",link.get("site",-1)))==target_runtime and link.at.distance_squared_to(source_at)<9.*9. and not preload("res://scripts/forest/forest_explore_routes.gd").restricted(link)and (target_runtime!=route[0]or link.get("source_arrival",link.get("arrival",Vector2.INF)).distance_squared_to(expected_arrival)<.25))
   if not ordinary.is_empty():
    var entered=await walk_door(ordinary[0].at)
    var reached=destination_matches(int(route[9]),true)if native_field else destination_matches(route[2],generated_target)
    check(entered and reached,"Ordinary working entrance reaches its retained native destination"if native_field else"Ordinary working entrance remains walkable")
    if exact_phase:check(game.model.falan_floor==target_runtime,"Ordinary entrance reaches the exact requested day/night source variant")
    var entered_at=game.player.position
    if reached and target_runtime==route[0]:check(Vector2(entered_at.x,entered_at.z).distance_to(expected_arrival*game.model.falan_scale)<8.*game.model.falan_scale,"Same-map door reaches the intended side of the original barrier")
    var left=false
    if entered:left=await leave_ordinary()
    check(left,"Ordinary destination can be left through its original exit")
    report.append({"source":Original.source_id(route[0]),"runtime":route[0],"cell":str(route[1]),"target":route[2],"landing":str(route[4]),"status":"Original door walked and destination exited","native_destination_runtime":int(route[9])if native_field else game.explorer_clock.phase_floor(target_runtime),"ordinary_walk_contract":"continuous-entry-exit-v1","phase_contract":"exact-phase-v1"if exact_phase else"","entered_at":str(entered_at),"verified_transition":entered and left,"passed":failures==before_failures});save_routes(report);continue
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
  if "--normal-approach"not in OS.get_cmdline_user_args():
   game.player.position=game.model.world_point(approaches[0],.15);game.player.reset_physics_interpolation();game.model.hero_position=game.player.position
  game.set_process(true)
  await walk_toward(station,10000 if "--normal-approach"in OS.get_cmdline_user_args()else 120,"--normal-approach"in OS.get_cmdline_user_args())
  check(Vector2(game.player.position.x,game.player.position.z).distance_to(station*game.model.falan_scale)<.8*game.model.falan_scale,"Actual movement reaches the Cross Gate %d"%route[0])
  var gold=game.model.gold;var items:Dictionary=get_meta("university_quest_items",{}).duplicate(true);var quests=game.settings.explorer_quests.duplicate(true);var checkpoint=game.checkpoint
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
   var expected=Original.source_point(target_runtime,route[4],game.model.seed_value)
   check(Vector2(entered_at.x,entered_at.z).distance_to(expected*game.model.falan_scale)<8.*game.model.falan_scale,"Cross Gate reaches the selected destination entrance")
  check(game.model.gold==gold and get_meta("university_quest_items",{})==items and game.settings.explorer_quests==quests,"Explore transfer grants no prerequisite, completion or reward")
  check(game.checkpoint==checkpoint,"Explore bypass preserves the existing home checkpoint")
  game.explore_access._process(.2)
  await access_capture("gate-%d-%d-destination"%[route[0],route[2]])
  if route[2]==4100 and "--astia-streets"in OS.get_cmdline_user_args():
   game.explorer_npcs.prepare()
   var npcs=game.explorer_npcs.actors.filter(func(entry):return str(entry.record.id).trim_prefix("source:")=="5255")
   check(npcs.size()==1,"The original arrival district restores Hank in his original source placement")
   if not npcs.is_empty():
    var npc:Dictionary=npcs[0];var point:Vector3=npc.get("interaction_point",npc.node.global_position)
    await walk_toward(Vector2(point.x,point.z)/game.model.falan_scale,1200,true)
    game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
    check(not game.explorer_npcs.nearest.is_empty()and str(game.explorer_npcs.nearest.record.id).trim_prefix("source:")=="5255"and is_instance_valid(game.explorer_npcs.hint)and game.explorer_npcs.hint.visible,"Player movement reaches Hank's visible original conversation prompt")
    press_f()
    if is_instance_valid(game.dialogue)and game.dialogue.pages[0].get("options",[]).any(func(o):return o[0]=="talk"):game.dialogue.chosen.emit("talk")
    check(is_instance_valid(game.dialogue)and game.dialogue.speaker==str(npc.record.name),"Actual F starts Hank's original conversation from the player side")
    if is_instance_valid(game.dialogue):game.close_boss_dialogue()
   var exits=game.explore_access.gates.filter(func(g):return str(g.get("actor",""))=="5255"and int(g.get("target",0))==400)
   check(exits.size()==1,"The original NPC exit has one named Explore Cross Gate")
   var escaped=false;var returned=false
   if not exits.is_empty():
    await walk_toward(exits[0].at,900,true);press_f()
    if is_instance_valid(game.dialogue):
     var options=game.dialogue.pages[0].options.filter(func(o):return o[1]==exits[0].caption)
     if not options.is_empty():game.dialogue.chosen.emit(options[0][0])
    for i in 10:await physics_frame
    escaped=destination_matches(400)
    check(escaped,"Actual F follows Hank's original exit to Shalena without awarding his quest item")
    game.explore_access._process(.2)
    var returns=game.explore_access.gates.filter(func(g):return g.get("back",false))
    if not returns.is_empty():
     await walk_toward(returns[0].at,900,true);press_f()
     if is_instance_valid(game.dialogue):
      var options=game.dialogue.pages[0].options.filter(func(o):return o[1]==returns[0].caption)
      if not options.is_empty():game.dialogue.chosen.emit(options[0][0])
     for i in 10:await physics_frame
     returned=game.model.falan_floor==4100
    check(returned,"The actual return interaction restores the original arrival district")
   check(game.model.gold==gold and get_meta("university_quest_items",{})==items and game.settings.explorer_quests==quests and game.checkpoint==checkpoint,"NPC-exit travel grants no item18640, quest reward or home change")
   save_routes([{"source":4100,"runtime":4100,"cell":str(Vector2i(111,85)),"target":400,"landing":str(Vector2i(304,429)),"status":"Original NPC exit walked, F entered and actual return restored arrival district","return_walked":returned,"verified_transition":escaped,"passed":before_failures==failures}])
   game.explore_access._process(.2)
   context.astia_original_exit={"escaped":escaped,"returned_to_town":returned,"actual_floor":game.model.falan_floor}
  var backs=game.explore_access.gates.filter(func(g):return g.get("back",false))
  context.return_diagnostics={"prepared":game.explore_access.map_token,"native_ready":game.army_runtime.configured_model==game.model and game.army_runtime.navigation_revision==game.model.navigation_revision,"bookmark":game.explore_access.pending_return,"registered":game.explore_access.returns.get(game.explore_access.scope(),{}),"safe":str(game.explore_access.safe_station(Vector2(entered_at.x,entered_at.z)/game.model.falan_scale)),"gates":game.explore_access.gates,"at":gate_diagnostics(Vector2(entered_at.x,entered_at.z)/game.model.falan_scale,route[0])}
  check(backs.size()==1,"Destination has exactly one usable Explore return")
  var return_walked=false
  if not backs.is_empty():
   await walk_toward(backs[0].at,1200 if "--astia-streets"in OS.get_cmdline_user_args()else 240,"--astia-streets"in OS.get_cmdline_user_args())
   return_walked=game.player.position.distance_to(game.model.world_point(backs[0].at,.15))<1.
   check(return_walked,"Actual movement reaches the destination return Cross Gate")
   press_f()
   if is_instance_valid(game.dialogue):
    var option=game.dialogue.pages[0].options.filter(func(o):return o[1]==backs[0].caption)
    if not option.is_empty():game.dialogue.chosen.emit(option[0][0])
   for i in 8:await physics_frame
   check((game.model.falan_area==source_area and destination_matches(route[0]))if field else game.model.falan_floor==game.explorer_clock.phase_floor(route[0]),"Actual F leaves the destination and returns to original entrance")
   check(game.checkpoint==checkpoint,"Returning through the Explore bypass preserves the same home checkpoint")
  report.append({"source":Original.source_id(route[0]),"runtime":route[0],"cell":str(route[1]),"target":route[2],"landing":str(route[4])if route.size()>4 else"","action":route[5]if route.size()>5 else"","actor":route[6]if route.size()>6 else"","station":str(station),"entered_at":str(entered_at),"verified_transition":transferred,"return_walked":return_walked,"actual_return":game.model.falan_floor,"passed":failures==before_failures,"interaction":context})
  save_routes(report)
  await access_capture("gate-%d-%d"%[route[0],route[2]])
 save_routes(report)
 print("EXPLORE_ROUTES_RESULT checks=",checks," failures=",failures)

func walk_door(at:Vector2)->bool:
 var before=game.model.get_instance_id();var attempts=[];var source_floor=game.model.falan_floor;var source_area=Tour.area(game.model)
 var start=game.explore_access.player_path_start()
 if not start.is_finite():
  var here=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
  for radius in[3.,4.5,6.,9.,12.]:
   for direction in 16:
    var candidate=here+Vector2.from_angle(direction*TAU/16.)*radius
    var world=game.model.world_point(candidate,.15)
    if not game.explore_access.body_clear(world)or not game.model.terrain.disk_clear(world/game.model.falan_scale,.55):continue
    if not game.army_runtime.native.can_reach_ally(world,world,.55*game.model.falan_scale):continue
    if not game._ryo_clear_path(game.player.position+Vector3.UP*1.2,world+Vector3.UP*1.2):continue
    game.set_process(true);await walk_toward(candidate,120)
    if before!=game.model.get_instance_id():return true
    start=game.explore_access.player_path_start()
    if start.is_finite():break
   if start.is_finite():break
 if not start.is_finite():
  print("EXPLORE_DOOR_START_BLOCKED ",{"area":source_area,"floor":source_floor,"door":str(at),"player":str(game.player.position)});return false
 if start.distance_squared_to(game.player.position)>.25:await walk_toward(Vector2(start.x,start.z)/game.model.falan_scale,60)
 var source_info=Tour.Indoor.floor_info(source_floor,game.model.seed_value)if source_area=="interior"and Original.owns(source_floor)else[]
 var source_bits=Tour.Indoor.walk_mask(source_floor,source_info[0],source_info[2].hex_decode(),game.model.seed_value)if not source_info.is_empty()else PackedByteArray()
 var approaches=[]
 for radius in[6.,9.,12.]:
  for direction in 16:approaches.append(at+Vector2.from_angle(direction*TAU/16.)*radius)
 for approach:Vector2 in approaches:
  var point=game.model.world_point(approach,.15)
  var probe={"at":str(approach),"body":game.explore_access.body_clear(point),"terrain":game.model.terrain.disk_clear(point/game.model.falan_scale,.55),"to_door":game.army_runtime.native.can_reach_ally(point,game.model.world_point(at,.15),.55*game.model.falan_scale),"from_player":game.army_runtime.native.can_reach_ally(start,point,.55*game.model.falan_scale),"sight":game._ryo_clear_path(point+Vector3.UP*1.2,game.model.world_point(at,1.2))}
  probe.source_open=source_info.is_empty()or Original.open(source_bits,source_info[0],Vector2i(((approach-source_info[1])/3.).round()))
  attempts.append(probe)
  # Original door centers may lie beyond navigation; prove entry by crossing on foot.
  if not(probe.source_open and probe.body and probe.terrain):continue
  game.set_process(true)
  await walk_toward(approach,1200,true)
  if before!=game.model.get_instance_id():
   print("EXPLORE_DOOR_ENTERED ",{"from_area":source_area,"from_floor":source_floor,"door":str(at),"area":Tour.area(game.model),"floor":game.model.falan_floor,"player":str(game.player.position)});return true
  if game.player.position.distance_to(point)>1.:continue
  # Cross the physical threshold with actual input; its trigger can precede a closed wall cell.
  await walk_toward(at,180,false,true)
  for i in 8:await physics_frame
  if before!=game.model.get_instance_id():
   print("EXPLORE_DOOR_ENTERED ",{"from_area":source_area,"from_floor":source_floor,"door":str(at),"area":Tour.area(game.model),"floor":game.model.falan_floor,"player":str(game.player.position)});return true
 print("EXPLORE_DOOR_BLOCKED ",{"area":source_area,"floor":source_floor,"door":str(at),"player":str(game.player.position),"probes":attempts})
 return false

func leave_ordinary()->bool:
 var links=game.model.get_meta("falan_links",[]).filter(func(link):return link.get("walk_in",false)and not preload("res://scripts/forest/forest_explore_routes.gd").restricted(link))
 links.sort_custom(func(a,b):return game.player.position.distance_squared_to(game.model.world_point(a.at))<game.player.position.distance_squared_to(game.model.world_point(b.at)))
 for link in links:
  if await walk_door(link.at):return true
 return false

func save_routes(report:Array):
 for row in report:row.get_or_add("seed",game.model.seed_value)
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
 var path=ACCESS_OUT+"routes-"+mode+".json"
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify({"routes":report,"checks":checks,"failures":failures},"  "));f.close()
 var history_path=ACCESS_OUT+"routes-history.json"
 var history=JSON.parse_string(FileAccess.get_file_as_string(history_path)) if FileAccess.file_exists(history_path) else {}
 for row in report:
  var identity=str(row.source)
  if Original.generated().owns(int(row.get("runtime",-1)))and Original.runtime_id(int(row.source))!=int(row.runtime):identity="runtime:"+str(row.runtime)
  history["%s:%s:%s:%s:%s"%[identity,row.get("cell",""),row.target,row.get("landing",""),mode]]=row
 f=FileAccess.open(history_path,FileAccess.WRITE);f.store_string(JSON.stringify(history,"  "));f.close()

func destination_matches(source:int,runtime:bool=false)->bool:
 var area=Tour.area(game.model)
 if source==1000:return area=="city"
 if source==1500:return area=="castle"
 if source in[2100,2300,3000,3200]:return area==preload("res://scripts/forest/forest_east_region.gd").SOURCE_VILLAGES[source]
 if source==100:return area in Tour.SouthPopulation.FREYJA_AREAS or area in["east_gate","north_coast"]
 if source==300:return area in["sokia_coast","sokia_desert","ghana_road","ghana_north_road"]
 if source in[2000,2400]:return area==("east_gate"if source==2000 else"north_coast") and Tour.Regions.village_contains(area,Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale)
 return game.model.falan_floor==game.explorer_clock.phase_floor(source if runtime else Original.runtime_id(source))

func gate_diagnostics(at:Vector2,target:int)->Dictionary:
 var routes=preload("res://scripts/forest/forest_explore_routes.gd");var model=game.model
 var info=Tour.Indoor.floor_info(model.falan_floor,model.seed_value);var bits=Tour.Indoor.walk_mask(model.falan_floor,info[0],info[2].hex_decode(),model.seed_value)
 var cell=Vector2i(((at-info[1])/3.).round());var point=model.world_point(at,.15)
 return {"floor":model.falan_floor,"area":model.falan_area,"player":str(game.player.position),"requested":str(at),"candidates":routes.candidates(game),"station":str(game.explore_access.safe_station(at)),"source_open":Tour.Winter.Recovered.open(bits,info[0],cell),"body_clear":game.explore_access.body_clear(point),"terrain":model.terrain.disk_clear(point/model.falan_scale,.65),"native_reach":game.army_runtime.native.can_reach_ally(game.player.position,point,.55*model.falan_scale)}
