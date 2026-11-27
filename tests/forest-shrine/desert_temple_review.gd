extends "res://tests/forest-shrine/freyja_trial_review.gd"
## Direct original parties on complete source maps. Held quest item is fixture-only.
const DESERT_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Desert Temple/"
var desert_report={"maps":[],"ports":[],"actors":[],"goal_complete":false}
func _initialize():
 create_timer(1800).timeout.connect(func():printerr("DESERT_REVIEW_TIMEOUT");quit(1));run.call_deferred()
func maximum_party(zone:Dictionary,key:String)->Array:
 var result=super.maximum_party(zone,key)
 if zone.has("levels"):
  for i in result.size():result[i][1]=int(zone.levels[i%2])
 return result
func take_view(label_:String,cell:Vector2i,yaw:float=0.,screen_offset:float=0.):
 if label_.begins_with("group-"):
  if not desert_report.has("party_diagnostics"):desert_report.party_diagnostics=[]
  var actual=[]
  for e in game.model.enemies.values():actual.append({"id":e.id,"source_enemy":e.get("source_enemy"),"name":e.get("enemy_name"),"level":e.get("level"),"skin":e.get("skin"),"encounter":e.get("snow_encounter"),"group":e.get("source_group"),"native_handle":game.army_runtime.handles.get(e.id,0)})
  desert_report.party_diagnostics.append({"label":label_,"enemies":actual})
 await super.take_view(label_,cell,yaw,screen_offset)
 if DisplayServer.get_name()=="headless":return
 var target=DESERT_OUT+label_.replace("NPCs and gates/","")+".png"
 check(DirAccess.rename_absolute(ProjectSettings.globalize_path(TRIAL_OUT+label_.replace("NPCs and gates/","")+".png"),ProjectSettings.globalize_path(target))==OK,"Saved fixed Desert Temple gameplay view "+label_)
 server_report.captures[-1].image=target
func run():
 root.size=Vector2i(1280,800);review_hp=1000000000.;DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NPC_OUT))
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-desert-temple-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=20261127;game.tuning.invincible=true;game.player.set_auto_attack(false);freeze()
 var saved=JSON.stringify(get_meta("falan_venture"));var items:Dictionary=get_meta(Events.ITEMS,{}).duplicate(true);var held=items.duplicate(true);held.source_item_18462=1
 set_meta(Events.ITEMS,held);Original.Art.load_sokia_desert_temple();var flags={};var groups={}
 for id in Original.Art.SOKIA_DESERT_TEMPLE_IDS:
  var row:Dictionary=Original.Art.data().maps[Original.path_for(id)];flags[id]=row.sokia_visual_only;check(row.sokia_visual_only,"Production Desert Temple remains review-only "+str(id));row.sokia_visual_only=false
 for id in flags:
  await visit(id);var cell=clear_cell(id,candidate_cells(id));await take_view("map-"+str(id),cell)
  check(East.owns_model(game.model)and game.model.waves.patrol_posts.is_empty(),"One native source owner; no generic patrol pool "+str(id))
  for source in Original.Art.data().maps[Original.path_for(id)].fixed_port_candidates:
   var at=Original.source_point(id,Vector2i(source.cell[0],source.cell[1]));var links=Original.links(id).filter(func(link):return link.at.distance_squared_to(at)<.01 and int(link.get("floor",-1))==int(source.target_map))
   check(links.size()==1,"One directed source port "+str(id)+str(source.cell))
   var supported=false
   for offset in [Vector2.ZERO,Vector2.UP*1.8,Vector2.DOWN*1.8,Vector2.LEFT*1.8,Vector2.RIGHT*1.8]:
    var world=game.model.world_point(at+offset,.15);supported=supported or game.army_runtime.native.can_reach(world,world,.4)
   check(supported,"Native support within existing source-port walk-in radius "+str(id)+str(source.cell))
   var exact=links.size()==1 and links[0].get("source_arrival",links[0].arrival).distance_squared_to(Original.source_point(int(source.target_map),Vector2i(source.arrival[0],source.arrival[1])))<.01
   check(exact,"Original source arrival anchor "+str(id)+str(source.cell));desert_report.ports.append({"source":source,"native_walk_in_support":supported,"exact_destination":exact})
  var source=Population.server_events(id)
  for actor in source.actors.values():
   if int(actor.source)!=id:continue
   var entry:Dictionary=find_actor(actor.id);check(not entry.is_empty(),"Ordinary source actor enrolls "+actor.id)
   if not entry.is_empty():check(East.source_cell(game.model,Vector2(entry.node.position.x,entry.node.position.z))==Vector2i(actor.cell[0],actor.cell[1]),"Original actor cell preserved "+actor.id)
   desert_report.actors.append({"id":actor.id,"source":id,"enrolled":not entry.is_empty()})
  if "--npcs"in OS.get_cmdline_user_args():
   set_meta(Events.ITEMS,{})
   for actor in source.actors.values():
    if int(actor.source)==id:await interact_source(actor.id)
   check(get_meta(Events.ITEMS,{}).is_empty(),"No quest item/flag granted by initial ordinary F without prerequisites "+str(id));set_meta(Events.ITEMS,held.duplicate(true))
  for zone in East.data().zones.filter(func(z):return int(z.map)==id):
   for choice in zone.groups:
    if groups.has(choice[0]):continue
    groups[choice[0]]=true;await direct_group(id,cell,choice[0],zone)
  desert_report.maps.append({"id":id,"size":str(Original.state(id).size)})
 check(groups.size()==7,"All seven fixed-map source parties directly exercised")
 if "--approach-pool"in OS.get_cmdline_user_args():
  var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_desert_temple/encounters.json"))
  var pool:Dictionary=source.generated_approach.pool.duplicate(true)
  pool.map=13022;pool.bounds=[0,0,19,19];pool.priority=100
  East.zone_rows[13022].append(pool)
  await visit(13022);var cell=clear_cell(13022,candidate_cells(13022))
  for choice in pool.groups:await direct_group(13022,cell,choice[0],pool)
  East.zone_rows[13022].erase(pool)
  check(East.zone_at(13022,cell).id==7029,"Temporary approach-pool fixture restores the fixed floor's original encounter")
  desert_report.generated_approach_pool={"config":303,"encounter":15003,"levels":[26,28],"groups":pool.groups,"actual_review_floor":13022,"original_generated_maps_verified":false,"qualification":"Required approach's source parties directly exercised on a temporary legal fixed-floor fixture. This does not verify generated geometry, five-floor traversal, moving entrance or original random distribution."}
 # Removed prerequisite before a queued party commits must not leave a stale gated draw.
 await visit(13016);var pocket=Vector2i(30,30);var at=game.model.world_point(Original.source_point(13016,pocket),.15)
 game.player.position=at;game.model.hero_position=at;game.player.reset_physics_interpolation();set_meta(Events.ITEMS,items.duplicate(true))
 var general:int=East.data().species.find_custom(func(s):return int(s.id)==101931)
 game.model.waves.snow_pending=[[general,28,"11040","desert:7021"]];game.model.waves.snow_last=at/game.model.falan_scale;game.model.waves.spawn_clock=10.
 game.model.waves.tick_map_encounters(at/game.model.falan_scale)
 check(game.model.waves.snow_pending.is_empty()and game.model.enemies.is_empty(),"Removed item clears queued gated party before native spawn")
 for id in flags:Original.Art.data().maps[Original.path_for(id)].sokia_visual_only=flags[id]
 set_meta(Events.ITEMS,items);check(JSON.stringify(get_meta("falan_venture"))==saved,"Adventure preserved");check(get_meta(Events.ITEMS,{})==items,"Source inventory restored without quest grant")
 desert_report.checks=checks;desert_report.failures=errors;desert_report.groups=trial_report.groups;desert_report.captures=server_report.captures;desert_report.ordinary_F=npc_report.actors
 desert_report.source_sha256={}
 for path in ["res://assets/maps/original_crossgate/sokia_desert_temple/catalog.json","res://assets/maps/original_crossgate/sokia_desert_temple/encounters.json","res://assets/maps/original_crossgate/sokia_desert_temple/events/data.json","res://scripts/forest/forest_waves.gd","res://scripts/forest/crowd/east_region_sprites.gd"]:desert_report.source_sha256[path]=FileAccess.get_sha256(path)
 desert_report.qualification="Complete source maps, direct source parties and native contact/cleanup only. Temporary held18462is fixture context, not natural acquisition. Original count/probability/AI, keeper/chest predicates, source-frame/motion and complete scenery approval remain separate. Hero recording HP enlarged; enemy counts/levels/damage/timing unchanged."
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered";var f=FileAccess.open(DESERT_OUT+"integration-"+mode+".json",FileAccess.WRITE);f.store_string(JSON.stringify(desert_report,"  "));f.close()
 print("DESERT_INTEGRATION_RESULT checks=",checks," failures=",errors)
 game.army_runtime.finish_integration();game.queue_free()
 for i in 4:await process_frame
 quit(1 if errors else 0)
