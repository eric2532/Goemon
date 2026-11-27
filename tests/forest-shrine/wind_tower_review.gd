extends "res://tests/forest-shrine/freyja_trial_review.gd"
## Source-party QA on complete source maps; no persistent access/item grants.
const WIND_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Wind Tower/"
const Regional=preload("res://scripts/forest/forest_university_region.gd")
var wind_report={"maps":[],"ports":[],"scripted":[],"goal_complete":false}
var wind_actors:Dictionary
func direct_group(id:int,cell:Vector2i,key:String,zone:Dictionary):
 await super.direct_group(id,cell,key,zone)
 if not trial_report.groups[-1].generations.any(func(g):return g.has("unverified")):return
 var at=game.player.position;var bounds=AABB(at-Vector3(24,12,24)*game.model.falan_scale,Vector3(48,24,48)*game.model.falan_scale)
 var nearby=game.army_runtime.query_aabb(bounds,0);var states=[]
 for handle in nearby:states.append({"handle":str(handle),"valid":game.army_runtime.valid(handle),"state":str(game.army_runtime.unit_state(handle))})
 if not wind_report.has("failed_placement_diagnostics"):wind_report.failed_placement_diagnostics=[]
 wind_report.failed_placement_diagnostics.append({"group":key,"phase":game.model.phase,"floor":game.model.falan_floor,"hero":str(at),"hp":game.player.hp,"building_1":game.model.buildings.get(1,{}).duplicate(true),"spawn_clock":game.model.waves.spawn_clock,"pending":game.model.waves.snow_pending,"nearby":states,"handles":game.army_runtime.handles.size(),"model_enemies":game.model.enemies.size()})
func _initialize():
 create_timer(1800).timeout.connect(func():printerr("WIND_REVIEW_TIMEOUT");quit(1))
 run.call_deferred()
func take_view(label_:String,cell:Vector2i,yaw:float=0.,screen_offset:float=0.):
 await super.take_view(label_,cell,yaw,screen_offset)
 if DisplayServer.get_name()=="headless":return
 var path=WIND_OUT+label_+".png"
 check(DirAccess.rename_absolute(ProjectSettings.globalize_path(TRIAL_OUT+label_+".png"),ProjectSettings.globalize_path(path))==OK,"Saved fixed Wind gameplay view "+label_)
 server_report.captures[-1].image=path
func source_boss(id:String):
 var actor:Dictionary=wind_actors.actors.filter(func(a):return a.id==id)[0]
 var floor_:int=actor.source;var source_encounter=10007 if id=="6268"else 10010 if id=="80081"else 10011
 for generation in 2:
  await visit(floor_);game.get_tree().set_meta(Regional.BATTLES,{});game.get_tree().set_meta(Regional.SLAIN,{})
  game.player.clear_food_buffs();game.player.max_hp=review_hp;game.player.hp=review_hp;game.tuning.invincible=true
  var source_cell=Vector2i(actor.cell[0],actor.cell[1]);var station=Original.safe_cell(floor_,source_cell+Vector2i.DOWN)
  var at=game.model.world_point(Original.source_point(floor_,station),.15)
  game.player.position=at;game.player.velocity=Vector3.ZERO;game.model.hero_position=at;game.player.reset_physics_interpolation()
  var baseline=game.army_runtime.handles.size()
  Events.source_actor(game,actor,wind_actors.scripts.get(actor.script,{}))
  for step in 16:
   var session:Dictionary=game.get_meta(Events.SESSION,{})
   if session.get("status","")!="window":break
   Events.respond(game,int(session.serial),str(session.pending.choices[0]))
  var key=Regional.active(game.get_tree(),floor_,"interior")
  check(not key.is_empty(),"Original actor/script starts its exact source battle "+id)
  if key.is_empty():continue
  game.model.waves.spawned=0;game.model.waves.tick(0.,at)
  game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
  var ids=game.model.enemies.keys();var handles=[];var expected=5 if id=="6268"else 7
  check(ids.size()==expected,"Every mandatory original scripted member spawns "+id)
  var group:Dictionary=East.data().groups["wind:"+str(source_encounter)];var counts={};var exact=true
  for enemy in game.model.enemies.values():
   var handle:int=game.army_runtime.handles.get(enemy.id,0);handles.append(handle)
   var source_id=str(enemy.get("source_enemy",""));var index=group.source_members.find_custom(func(m):return str(m.enemy_id)==source_id)
   if index<0:exact=false;continue
   var detail:Dictionary=group.source_members[index];var member:Array=group.members[index]
   counts[source_id]=int(counts.get(source_id,0))+1
   exact=exact and handle!=0 and enemy.enemy_name==detail.name and int(enemy.level)>=int(member[1])and int(enemy.level)<=int(member[2])and int(enemy.source_encounter)==source_encounter and enemy.source_group=="wind:"+str(source_encounter)
  for detail in group.source_members:exact=exact and int(counts.get(str(detail.enemy_id),0))==int(detail.count[0])
  check(exact,"Scripted party retains original names, IDs, levels and exact mandatory counts "+id)
  if generation==0:await take_view("scripted-"+id,station,PI*.5)
  game.player.max_hp=review_hp;game.player.hp=review_hp
  game.army_runtime.record_events=true;game.army_runtime.compact_scene_events=false;game.army_runtime.event_log.clear()
  game.tuning.invincible=false;game.player.invuln=0.;game.player.model.clear_kagerou_dodge()
  for tick in 1200:
   game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.);game.army_runtime.integration_tick(1./60.)
  var contacts=game.army_runtime.event_log.filter(func(e):return e.kind=="external_damage"and e.external_kind==0 and e.source_id in ids)
  check(not ids.is_empty()and ids.all(func(unit):return contacts.any(func(e):return e.source_id==unit)),"Every scripted member delivers native contact "+id)
  check(game.player.hp<review_hp,"Scripted party damages live hero "+id)
  for tick in 180:
   for handle in handles:
    if game.army_runtime.valid(handle):game.army_runtime.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
   if handles.all(func(h):return not game.army_runtime.valid(h)):break
   game.army_runtime.integration_tick(1./60.)
  game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
  check(game.model.enemies.is_empty()and game.army_runtime.handles.size()==baseline,"Scripted party clears and pooled native handles return to baseline "+id)
  game.model.waves.tick(0.,game.player.position)
  if id=="6268":
   for i in 6:await physics_frame
   freeze();check(game.model.falan_floor==20003,"Original Arcas victory transfer reaches20003")
  wind_report.scripted.append({"actor":id,"generation":generation,"encounter":source_encounter,"members":ids.size(),"contacts":contacts.size(),"identities":counts,"runtime_floor_after":game.model.falan_floor})
  if game.has_meta(Events.SESSION):game.remove_meta(Events.SESSION)
  if is_instance_valid(game.dialogue):game.close_boss_dialogue()
 game.get_tree().set_meta(Regional.BATTLES,{});game.get_tree().set_meta(Regional.SLAIN,{})
func run():
 var focused="--focus-placement"in OS.get_cmdline_user_args()
 review_hp=1000000000.;root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-wind-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.player.set_auto_attack(false);freeze()
 var saved=JSON.stringify(get_meta("falan_venture"));var saved_items=JSON.stringify(get_meta(Events.ITEMS,{}))
 Original.Art.load_sokia_wind();var flags={};var groups={}
 for id in Original.Art.SOKIA_WIND_IDS:
  var row:Dictionary=Original.Art.data().maps[Original.path_for(id)]
  flags[id]=row.sokia_visual_only;check(row.sokia_visual_only and not Original.owns(id),"Normal Wind access stays gated "+str(id));row.sokia_visual_only=false
 wind_actors=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_wind_tower/events/data.json"))
 for id in Original.Art.SOKIA_WIND_IDS:
  if focused and id not in [301,20301]:continue
  print("WIND_SOURCE_VISIT ",id);await visit(id)
  check(East.owns_model(game.model)and game.model.waves.patrol_posts.is_empty(),"One native source owner, no generic patrol pool "+str(id))
  var cell=clear_cell(id,candidate_cells(id));await take_view("map-"+str(id),cell)
  var native_ports=[]
  for link in Original.links(id):native_ports.append({"target":link.get("floor",-1),"area":link.get("area",""),"arrival":str(link.arrival),"source_at":str(link.at)})
  for source in Original.Art.data().maps[Original.path_for(id)].fixed_port_candidates:
   var at_=Original.source_point(id,Vector2i(source.cell[0],source.cell[1]))
   var candidates=Original.links(id).filter(func(link):return link.at.distance_squared_to(at_)<.01 and(int(link.get("floor",-1))==int(source.target_map)or int(source.target_map)==300 and link.get("area","")=="sokia_coast"))
   check(candidates.size()==1,"One directed link for every original port "+str(id)+":"+str(source.cell))
   var center_supported=game.army_runtime.native.can_reach(game.model.world_point(at_,.15),game.model.world_point(at_,.15),.4)
   var supported=center_supported
   for offset in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
    var near=game.model.world_point(at_+offset*1.8,.15)
    supported=supported or game.army_runtime.native.can_reach(near,near,.4)
   check(supported,"Native player support within original walk-in radius "+str(id)+":"+str(source.cell))
   var exact=false
   if candidates.size()==1:
    var expected=Original.source_point(int(source.target_map),Vector2i(source.arrival[0],source.arrival[1]))if int(source.target_map)!=300 else Tour.Regions.frame("sokia_coast").inverse()*(Vector2(source.arrival[0],source.arrival[1])*3.)
    exact=candidates[0].get("source_arrival",candidates[0].arrival).distance_squared_to(expected)<.01
   check(exact,"Original destination anchor retained "+str(id)+":"+str(source.cell))
   wind_report.ports.append({"source":source,"native_center_support":center_supported,"native_walk_in_support":supported,"exact_destination_anchor":exact})
  if id==20301:
   var port=Original.source_point(id,Vector2i(50,99));var approach=port+Vector2.UP*1.8
   game.player.position=game.model.world_point(approach,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
   game.falan_crossing_position=port+Vector2.UP*2.8
   check(Tour.cross_on_foot(game),"Actual reachable on-foot crossing uses original20301(50,99)anchor")
   for i in 6:await physics_frame
   freeze();check(game.model.falan_floor==301,"Boundary tower port reaches original Arcas map")
   await visit(id)
  for zone in East.data().zones.filter(func(z):return int(z.map)==id):
   for choice in zone.groups:
    if groups.has(choice[0]):continue
    groups[choice[0]]=true;await direct_group(id,cell,choice[0],zone)
  wind_report.maps.append({"id":id,"ports":native_ports,"source_npcs_pending":wind_actors.actors.filter(func(a):return int(a.source)==id).map(func(a):return a.id)})
 if not focused:
  for id in ["80081","80082","6268"]:await source_boss(id)
 for id in flags:Original.Art.data().maps[Original.path_for(id)].sokia_visual_only=flags[id]
 check(groups.size()==(13 if focused else 16),"Every requested ambient source group directly exercised")
 check(JSON.stringify(get_meta("falan_venture"))==saved,"User adventure preserved")
 check(JSON.stringify(get_meta(Events.ITEMS,{}))==saved_items,"No source item or quest grant")
 wind_report.checks=checks;wind_report.failures=errors;wind_report.groups=trial_report.groups;wind_report.captures=server_report.captures
 wind_report.qualification="Temporary in-memory map review only. Source scripts directly invoked for combat QA; ordinary F/invisible event integration, original probability/AI and visual approval remain required. Hero HP enlarged for contact recording, enemy damage/counts/levels/timing unchanged."
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
 var file=FileAccess.open(WIND_OUT+("focused-placement-"if focused else"integration-")+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(wind_report,"  ")+"\n");file.close()
 print("WIND_SOURCE_RESULT ",checks," checks ",errors," failures;",groups.size()," ambient groups;",wind_report.scripted.size()," scripted generations")
 game.queue_free();await process_frame;quit(1 if errors else 0)
