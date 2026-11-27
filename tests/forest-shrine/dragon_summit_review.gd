extends "res://tests/forest-shrine/freyja_trial_review.gd"
## Full fixed layouts and direct source parties; generated maps/natural triggers remain separate.
const DRAGON_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Dragon Summit/"
var dragon_report={"maps":[],"ports":[],"actors":[],"goal_complete":false}
var view_suffix=""
func _initialize():
 create_timer(2400).timeout.connect(func():printerr("DRAGON_REVIEW_TIMEOUT");quit(1));run.call_deferred()
func maximum_party(zone:Dictionary,key:String)->Array:
 var party=super.maximum_party(zone,key)
 if zone.has("levels"):
  for i in party.size():party[i][1]=int(zone.levels[i%2])
 return party
func take_view(label_:String,cell:Vector2i,yaw:float=0.,screen_offset:float=0.):
 var label=label_+view_suffix
 await super.take_view(label,cell,yaw,screen_offset)
 if DisplayServer.get_name()=="headless":return
 var path=DRAGON_OUT+label.replace("NPCs and gates/","")+".png"
 check(DirAccess.rename_absolute(ProjectSettings.globalize_path(TRIAL_OUT+label.replace("NPCs and gates/","")+".png"),ProjectSettings.globalize_path(path))==OK,"Saved fixed source Dragon/Summit view "+label)
 server_report.captures[-1].image=path
func fixture_pool(map_:int,pool_:Dictionary,source_label:String):
 var pool:Dictionary=pool_.duplicate(true);var size:Vector2i=Original.state(map_).size
 pool.map=map_;pool.bounds=[0,0,size.x-1,size.y-1];pool.priority=1000
 if not East.zone_rows.has(map_):East.zone_rows[map_]=[]
 East.zone_rows[map_].append(pool)
 await visit(map_);var cell=clear_cell(map_,candidate_cells(map_));var old=view_suffix;view_suffix="-"+source_label
 for choice in pool.groups:await direct_group(map_,cell,choice[0],pool)
 view_suffix=old;East.zone_rows[map_].erase(pool)
 dragon_report.get_or_add("pool_fixtures",[]).append({"source":source_label,"actual_map":map_,"encounter":pool.id,"levels":pool.get("levels",[]),"groups":pool.groups,"original_generated_map_or_trigger_verified":false})
func run():
 root.size=Vector2i(1280,800);review_hp=1000000000.
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-dragon-review-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=20261127;game.tuning.invincible=true;game.player.set_auto_attack(false);freeze()
 var saved=JSON.stringify(get_meta("falan_venture"));var items:Dictionary=get_meta(Events.ITEMS,{}).duplicate(true)
 Original.Art.load_sokia_dragon_summit();var flags={};var groups={}
 var ids=Original.Art.SOKIA_DRAGON_SUMMIT_IDS.duplicate();ids.append(15577);ids.sort()
 for id in ids:
  var row:Dictionary=Original.Art.data().maps[Original.path_for(id)];flags[id]=row.sokia_visual_only
  check(row.sokia_visual_only,"Production source layout remains gated "+str(id));row.sokia_visual_only=false
 var canonical:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_dragon_summit/catalog.json"))
 for id in ids:
  print("DRAGON_SOURCE_VISIT ",id);await visit(id);var cell=clear_cell(id,candidate_cells(id));await take_view("map-"+str(id),cell)
  check((East.owns_model(game.model)if id!=15577 else Population.encounters_own(game.model))and game.model.waves.patrol_posts.is_empty(),"Existing native source owner without generic patrols "+str(id))
  if canonical.maps.has(Original.path_for(id)):
   for port in canonical.maps[Original.path_for(id)].fixed_port_candidates:
    var target=int(port.target_map)
    if not Original.owns(target):dragon_report.get_or_add("unavailable_ports",[]).append(port);continue
    var at=Original.source_point(id,Vector2i(port.cell[0],port.cell[1]));var supported=false
    for offset in [Vector2.ZERO,Vector2.UP*1.8,Vector2.DOWN*1.8,Vector2.LEFT*1.8,Vector2.RIGHT*1.8]:
     var world=game.model.world_point(at+offset,.15);supported=supported or game.army_runtime.native.can_reach(world,world,.4)
    check(supported,"Native support within existing source-port walk-in radius "+str(id)+str(port.cell))
    dragon_report.ports.append({"source":port,"native_walk_in_support":supported})
  var source=Population.server_events(id)
  for actor in source.actors.values():
   if int(actor.source)!=id:continue
   var entry:Dictionary=find_actor(actor.id);check(not entry.is_empty(),"Ordinary source actor enrolls once "+actor.id)
   if not entry.is_empty():check(Population.source_cell(game.model,Vector2(entry.node.position.x,entry.node.position.z))==Vector2i(actor.cell[0],actor.cell[1]),"Original actor source cell "+actor.id)
   dragon_report.actors.append({"id":actor.id,"source":id,"enrolled":not entry.is_empty()})
  if "--npcs"in OS.get_cmdline_user_args():
   set_meta(Events.ITEMS,{})
   for actor in source.actors.values():
    if int(actor.source)==id:await interact_source(actor.id)
   check(get_meta(Events.ITEMS,{}).is_empty(),"Initial ordinary F without prerequisites grants no item "+str(id));set_meta(Events.ITEMS,items.duplicate(true))
  for zone in East.data().zones.filter(func(z):return int(z.map)==id):
   for choice in zone.groups:
    if groups.has(choice[0]):continue
    groups[choice[0]]=true;await direct_group(id,cell,choice[0],zone)
  dragon_report.maps.append({"id":id,"size":str(Original.state(id).size)})
 var roster:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/original_crossgate/sokia_dragon_summit/encounters.json"))
 for pair in [[15590,"10029"],[15587,"10030"],[15569,"11011"]]:await fixture_pool(pair[0],roster.pools[pair[1]],"script-pool-"+pair[1])
 for config in [108,110,309]:
  var branch:Dictionary=roster.generated_branches.filter(func(b):return int(b.config)==config)[0]
  await fixture_pool(15568 if config==309 else 15572,branch.pool,"config-"+str(config))
 check(trial_report.groups.size()==9,"All eight source groups and both castle level intervals directly exercised")
 for id in flags:Original.Art.data().maps[Original.path_for(id)].sokia_visual_only=flags[id]
 set_meta(Events.ITEMS,items)
 check(JSON.stringify(get_meta("falan_venture"))==saved and get_meta(Events.ITEMS,{})==items,"Adventure/items preserved")
 dragon_report.checks=checks;dragon_report.failures=errors;dragon_report.groups=trial_report.groups
 dragon_report.captures=server_report.captures;dragon_report.ordinary_F=npc_report.actors
 dragon_report.source_sha256={}
 for path in ["res://assets/maps/original_crossgate/sokia_dragon_summit/catalog.json","res://assets/maps/original_crossgate/sokia_dragon_summit/encounters.json","res://assets/maps/original_crossgate/sokia_dragon_summit/events/data.json","res://assets/characters/crossgate/east_region/motions.json","res://scripts/forest/forest_waves.gd"]:dragon_report.source_sha256[path]=FileAccess.get_sha256(path)
 dragon_report.qualification="Complete fixed layouts and direct source parties only. Scripted pools run on their source fixed map with temporary ambient overlays; original NPC triggers/victory travel are not established. Generated pools run on private fixed-map fixtures, not72original generated floors. Hero recordingHP enlarged; enemy counts, levels and native damage/timing retained. No visual or performance signoff."
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered";var f=FileAccess.open(DRAGON_OUT+"integration-"+mode+".json",FileAccess.WRITE)
 f.store_string(JSON.stringify(dragon_report,"  "));f.close();print("DRAGON_INTEGRATION_RESULT checks=",checks," failures=",errors)
 game.army_runtime.finish_integration();game.queue_free()
 for i in 4:await process_frame
 quit(1 if errors else 0)
