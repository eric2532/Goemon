extends "res://tests/forest-shrine/sokia_server_maps_review.gd"
## Source NPCs and proven ports only; unsupported original state is reported, never bypassed.
const Events=preload("res://scripts/forest/forest_east_events.gd")
const NPC_OUT=SERVER_OUT+"NPCs and gates/"
var npc_report={"maps":[],"actors":[],"branches":[],"ports":[],"captures":[],"goal_complete":false}
func _initialize():
 create_timer(1500).timeout.connect(func():printerr("SOKIA_SERVER_NPC_TIMEOUT");quit(1))
 run.call_deferred()
func context()->Dictionary:
 return {"items":{},"gold":5000,"level":100,"group":1,"seed":341,"external":{},"bags":{},"refills":{},"now":1000000.,"hp":100.,"max_hp":100.}
func branch(id:String,answers:Array,ctx:Dictionary={})->Dictionary:
 var source:Dictionary=Population.server_events();var actor:Dictionary=source.actors[id]
 var session=Events.begin_context(actor,source.scripts[actor.script],context()if ctx.is_empty()else ctx)
 for answer in answers:
  if session.status!="window":break
  Events.choose_context(session,answer)
 npc_report.branches.append({"actor":id,"status":session.status,"destination":session.get("destination",[]),"blocker":session.get("blocker",{}),"items":session.context.items})
 return session
func source_branches():
 for row in [["5288","YES",[0,15549,11,19]],["5288","NO",[0,15549,15,19]],["5291","YES",[0,15560,15,19]],["5291","NO",[0,15560,11,19]],["6705","YES",[0,13505,10,19]]]:
  var result=branch(row[0],[row[1]])
  check(result.status=="warp"and result.destination==row[2],"Source choice retains its exact original landing "+row[0]+row[1])
 for id in ["5294","5297"]:
  var unknown=branch(id,["OK"])
  check(unknown.status=="blocked"and unknown.blocker.reason.contains("itemspace"),"Unknown original inventory capacity stays guarded "+id)
  var ctx=context();ctx.external.itemspace=1
  var allowed=branch(id,["OK"],ctx)
  check(allowed.status=="warp"and Events.item_count(allowed.context.items,18782)==1,"Known source capacity preserves the original reward/warp "+id)
 var unknown_skill=branch("6710",[])
 check(unknown_skill.status=="blocked"and unknown_skill.blocker.reason.contains("skilllevel"),"Original skill predicate is not assumed true")
 var solo=branch("6713",["OK"])
 check(solo.status=="warp"and solo.destination==[0,13503,41,39],"No-item solo source exit retains its original target")
 for id in ["5330","5331","5338"]:
  var result=branch(id,["NEXT","NEXT","NEXT","OK"])
  check(result.status=="warp"and result.destination==[0,15575,24,20],"Shared source scene retains every speaker and exact return "+id)
 var lottery=branch("6915",["NEXT","NEXT","NEXT","YES"])
 check(lottery.status=="blocked"and lottery.blocker.reason.contains("itemspace"),"Paid lottery cannot spend gold under unknown original capacity")
func freeze():
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.explorer_clock.load_hour(12);game.explorer_clock.update_lighting()
func visit(id:int):
 var candidates=candidate_cells(id);check(not candidates.is_empty(),"Source map has a valid visit point "+str(id))
 if candidates.is_empty():return
 Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Original.source_point(id,candidates[0]),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 5:await physics_frame
 game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0);freeze()
 clear_enemies();game.model.waves.spawned=2;game.exploration_loot.clear();game.explorer_npcs.prepare()
func find_actor(id:String):
 var entries=game.explorer_npcs.actors.filter(func(entry):return entry.record.id=="source:"+id)
 return entries[0]if entries.size()==1 else{}
func interact_source(id:String):
 var entry:Dictionary=find_actor(id);check(not entry.is_empty(),"Exactly one existing NPC owner enrolls source actor "+id)
 if entry.is_empty():return
 var record:Dictionary=entry.node.get_meta("npc_record");var source:Dictionary=Population.server_events(game.model.falan_floor);var art:Dictionary=source.art.get(record.token,{})
 var cell=Vector2i(record.cell[0],record.cell[1]);var floor_:int=game.model.falan_floor
 check(Population.source_cell(game.model,Vector2(entry.node.position.x,entry.node.position.z))==cell,"NPC retains its original map cell "+id)
 if art.has("body_foot"):check(is_equal_approx(entry.node.offset.y,float(art.body_foot)-float(art.rect[3])*.5),"Measured body foot meets original ground without changing scale "+id)
 var station=Vector2i(-1,-1)
 var source_floor:Dictionary=Original.state(floor_)
 for radius in [1,2]:
  for offset in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
   var candidate=cell+offset*radius;var at=game.model.world_point(Original.source_point(floor_,candidate),.15)
   if not Original.open(source_floor.bits,source_floor.size,candidate-Original.crop(floor_).position):continue
   if not game.army_runtime.native.can_reach(at,at,.4):continue
   game.player.position=at;game.model.hero_position=at;game.player.reset_physics_interpolation()
   game.camera_rig.yaw=0.;game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
   if game.explorer_npcs.nearest.get("record",{}).get("id","")=="source:"+id:station=candidate;break
  if station.x>=0:break
 check(station.x>=0,"Original actor has an ordinary reachable F station "+id)
 if station.x<0:return
 var event=InputEventKey.new();event.physical_keycode=KEY_F;event.pressed=true;game._input(event)
 var session:Dictionary=game.get_meta(Events.SESSION,{})
 if record.has("quest_action"):
  check(session.get("actor",{}).get("id","")==id,"Actual F uses original source program "+id)
 else:check(is_instance_valid(game.dialogue),"Ordinary source conversation/sign opens through existing dialogue "+id)
 npc_report.actors.append({"id":id,"source_map":floor_,"cell":record.cell,"station":str(station),"status":session.get("status","conversation"),"blocker":session.get("blocker",{}),"destination":session.get("destination",[]),"original_graphic":record.graphic,"source_key":art.get("key","invisible source anchor")})
 if is_instance_valid(game.dialogue):game.close_boss_dialogue()
 game.explorer_npcs.selected={}
 for i in 5:await physics_frame
 freeze()
 if game.model.falan_floor!=floor_:await visit(floor_)
 await take_view("NPCs and gates/%d-npc-%s"%[floor_,id],station,0.,.12)
 if game.has_meta(Events.SESSION):game.remove_meta(Events.SESSION)
func source_ports():
 for row in [[5005,Vector2i(18,14),5006,Vector2i(7,10)],[5006,Vector2i(7,10),5005,Vector2i(18,14)],[13504,Vector2i(11,64),13502,Vector2i(45,24)]]:
  await visit(row[0]);var links=Original.links(row[0]).filter(func(link):return int(link.get("floor",-1))==row[2]and link.at.distance_squared_to(Original.source_point(row[0],row[1]))<.01)
  check(links.size()==1,"Exactly one source fixed port "+str(row[0])+"→"+str(row[2]))
  if links.size()!=1:continue
  check(links[0].arrival.distance_squared_to(Original.source_point(row[2],row[3]))<.01,"Fixed port preserves exact original landing")
  Tour.enter_link(game,"interior",links[0],links[0].at)
  for i in 6:await physics_frame
  freeze()
  check(game.model.falan_floor==row[2],"Existing travel owner realizes source fixed port")
  npc_report.ports.append({"source":row[0],"cell":str(row[1]),"target":row[2],"arrival":str(row[3]),"runtime_target":game.model.falan_floor})
 var ghana=Original.links(5005).filter(func(link):return int(link.get("floor",-1))==3000)
 check(ghana.size()==1 and ghana[0].arrival==Vector2(9,18),"Source return to existing Ghana owner preserves53,56")
 if ghana.size()==1:
  await visit(5005);Tour.enter_link(game,"interior",ghana[0],ghana[0].at)
  for i in 6:await physics_frame
  freeze()
  check(game.model.falan_area=="ghana","Existing village owner realizes the original Ghana return")
  var local=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
  check(Population.source_cell(game.model,local)==Vector2i(53,56),"Ghana transfer preserves the exact original53,56 landing")
  npc_report.ports.append({"source":5005,"cell":"(5, 4)","target":3000,"arrival":"(53, 56)","runtime_area":game.model.falan_area})
 check(not Original.links(13502).any(func(link):return int(link.get("floor",-1))==13504),"One-way source reference does not invent an inbound13504 door")
func run():
 root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NPC_OUT));source_branches()
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-server-npcs-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.player.set_auto_attack(false);game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"));Original.Art.load_sokia_server();var flags={}
 for id in Original.Art.SOKIA_SERVER_IDS:
  var source:Dictionary=Original.Art.data().maps[Original.path_for(id)];flags[id]=source.sokia_visual_only;source.sokia_visual_only=false
 for id in Original.Art.SOKIA_SERVER_IDS:
  await visit(id)
  check(Population.encounters_own(game.model),"Existing source encounter adapter owns this map without a regional generic pool "+str(id))
  for i in 3:game.model.waves.tick(1.,game.player.position)
  check(game.model.enemies.is_empty(),"Stationary NPC review cannot create an invented ambient party "+str(id))
  var actors=Population.server_events().actors.values().filter(func(actor):return int(actor.source)==id)
  var enrolled=game.explorer_npcs.actors.filter(func(entry):return entry.node.get_meta("npc_record",{}).get("dialogue_owner","")=="sokia_server")
  check(enrolled.size()==actors.size(),"Exact source NPC roster with one visible owner on "+str(id))
  check(not game.explorer_npcs.actors.any(func(entry):return entry.record.id in["source:807215","source:807216"]),"Uncorroborated later source actors remain excluded")
  for actor in actors:await interact_source(actor.id)
  npc_report.maps.append({"source_map":id,"npc_ids":actors.map(func(actor):return actor.id),"source_ambient_zones":Population.server_data().zones.filter(func(zone):return int(zone.map)==id).map(func(zone):return int(zone.id))})
 await source_ports()
 var graph=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Source events/source-graph.json"))
 npc_report.external_gate_candidates=graph.event_warps.filter(func(row):return int(row.source_map)not in Original.Art.SOKIA_SERVER_IDS and row.candidate_destinations.any(func(dest):return int(dest.target_map)in Original.Art.SOKIA_SERVER_IDS))
 npc_report.destination_adapters=[]
 var targets={}
 for row in graph.event_warps:
  if int(row.source_map)not in Original.Art.SOKIA_SERVER_IDS:continue
  for dest in row.candidate_destinations:targets[str([dest.target_map,dest.arrival])]=dest
 for dest in targets.values():
  var target:int=dest.target_map;var cell=Vector2i(dest.arrival[0],dest.arrival[1])
  npc_report.destination_adapters.append({"source_target":target,"representative_cell":str(cell),"adapter_available":load("res://scripts/forest/forest_east_region.gd").can_travel_source(game,target,cell),"qualification":"Unavailable event adapter is not proof that the map is absent game-wide; source predicates remain separately guarded."})
 for id in flags:Original.Art.data().maps[Original.path_for(id)].sokia_visual_only=flags[id]
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Source NPC/port QA preserves saved adventure state")
 npc_report.checks=checks;npc_report.failures=errors;npc_report.captures=server_report.captures
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
 var file=FileAccess.open(NPC_OUT+"review-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(npc_report,"  "));file.close()
 print("SOKIA_SERVER_NPC_RESULT checks=",checks," failures=",errors," actors=",npc_report.actors.size()," captures=",npc_report.captures.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
