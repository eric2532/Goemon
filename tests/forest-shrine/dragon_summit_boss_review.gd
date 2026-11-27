extends "res://tests/forest-shrine/wind_tower_npcs_review.gd"
## Original ordinary F, dialogue choices, source parties and declared battle returns.
const BOSS_OUT="res://build/Other Files/Asset Toolkit/Sokia Venoa Coverage/Dragon Summit/"
var boss_report={"fights":[],"goal_complete":false}
func _initialize():
 create_timer(1800).timeout.connect(func():printerr("DRAGON_BOSS_TIMEOUT");quit(1));run.call_deferred()
func press_source(id:String)->Dictionary:
 if id!="5320":return super.press_source(id)
 end_dialogue();game.explorer_npcs.prepare()
 var actor:Dictionary=Region.source_actors[id];var center=Region.source_point(int(actor.source),Vector2i(actor.cell[0],actor.cell[1]),"interior")
 var radius=0.
 for member in East.data().groups["dragon:11013"].members:radius=maxf(radius,East.radius(int(member[0])))
 for distance in [2.,3.,4.,4.75]:
  for direction in 16:
   var at=center+Vector2.from_angle(direction*TAU/16.)*distance;var world=game.model.world_point(at,.15)
   var cell:Vector2i=East.source_cell(game.model,at)-Original.crop(game.model.falan_floor).position;var floor_:Dictionary=Original.state(game.model.falan_floor)
   if not Original.open(floor_.bits,floor_.size,cell):continue
   if not game.army_runtime.native.can_reach(world,world,radius):continue
   game.player.position=world;game.player.velocity=Vector3.ZERO;game.model.hero_position=world;game.player.reset_physics_interpolation()
   game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
   if game.explorer_npcs.nearest.get("record",{}).get("id","")!="source:"+id:continue
   var input=InputEventKey.new();input.physical_keycode=KEY_F;input.pressed=true;game._input(input)
   var state:Dictionary=game.get_meta(Events.SESSION,{})
   check(state.get("actor",{}).get("id","")==id,"Original F from a legal station with full retinue clearance "+id)
   event_report.actors.append({"id":id,"source":actor.source,"source_cell":actor.cell,"station":str(at),"native_largest_radius":radius,"status":state.get("status","missing")})
   return state
 return super.press_source(id)
func capture_dialogue(label_:String):
 if DisplayServer.get_name()=="headless":return
 await super.capture_dialogue(label_)
 var path=BOSS_OUT+"boss-dialogue-"+label_+".png"
 check(DirAccess.rename_absolute(ProjectSettings.globalize_path(event_report.captures[-1]),ProjectSettings.globalize_path(path))==OK,"Saved original Dragon boss dialogue")
 event_report.captures[-1]=path
func run():
 root.size=Vector2i(1280,800);review_hp=1000000000.
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-dragon-boss-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=20261127;game.tuning.invincible=true;game.player.set_auto_attack(false);freeze()
 var saved=JSON.stringify(get_meta("falan_venture"));var items:Dictionary=get_meta(Events.ITEMS,{}).duplicate(true)
 Original.Art.load_sokia_dragon_summit();var flags={};var old_actors={}
 for map_ in Original.Art.SOKIA_DRAGON_SUMMIT_IDS:
  var row:Dictionary=Original.Art.data().maps[Original.path_for(map_)];flags[map_]=row.sokia_visual_only;row.sokia_visual_only=false
 Region.residents()
 var cases=[["5320",15569,11011,15569,22,21],["5326",15587,10030,15576,8,8],["5327",15587,10030,15576,8,8],["5333",15590,10029,15584,24,42],["5340",15589,10030,15583,24,37]]
 if "--wind-only"in OS.get_cmdline_user_args():cases=cases.filter(func(c):return c[0]=="5320")
 for values in cases:
  var id:String=values[0];var map_:int=values[1];var encounter:int=values[2]
  var actor:Dictionary=Population.server_events(map_).actors[id].duplicate(true);actor.invisible=false
  old_actors[id]=Region.source_actors.get(id,{});Region.source_actors[id]=actor
  for generation in 2:
   end_dialogue();set_meta(Regional.BATTLES,{});set_meta(Regional.SLAIN,{})
   await visit(map_);game.player.max_hp=review_hp;game.player.hp=review_hp;game.tuning.invincible=true
   var state=press_source(id);check(state.get("status","")=="window","Original F opens the boss script "+id)
   if generation==0:await capture_dialogue(id)
   for step in 8:
    state=game.get_meta(Events.SESSION,{})
    if state.get("status","")!="window":break
    answer(str(state.pending.choices[0]))
   var key=Regional.active(game.get_tree(),map_,"interior")
   check(not key.is_empty(),"Original dialogue choices trigger the source encounter "+id)
   if key.is_empty():boss_report.fights.append({"actor":id,"generation":generation,"blocked":game.get_meta(Events.SESSION,{})});continue
   game.model.waves.spawned=0;game.model.waves.tick(0.,game.player.position)
   game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
   var ids=game.model.enemies.keys();var handles=[];var exact=true;var counts={}
   var expected=3 if id=="5320"else 1
   check(ids.size()==expected,"Original boss and all mandatory retinue spawn "+id)
   var group:Dictionary=East.data().groups["dragon:"+str(11013 if encounter==11011 else encounter)]
   if ids.is_empty():
    var specification:Dictionary=Regional.specification(key,game.model.seed_value);var state_:Dictionary=East.state(game.model)
    var center:Vector2i=specification.cell-Original.crop(map_).position;var origin=game.player.position/game.model.falan_scale;var observations=[]
    for row in group.members:
     var radius:float=East.radius(int(row[0]));var reach=origin;var self_reachable:bool=game.army_runtime.native.can_reach(reach*game.model.falan_scale,reach*game.model.falan_scale,radius)
     if not self_reachable:
      var hero_cell=Vector2i(((Vector2(origin.x,origin.z)-state_.origin)/3.).round());var xy:Vector2=state_.origin+Vector2(hero_cell)*3.
      reach=Vector3(xy.x,game.model.surface_height(xy.x,xy.y),xy.y)
     var open_count=0;var clear_count=0;var reachable_count=0;var both_count=0;var samples=[]
     for y in range(maxi(0,center.y-12),mini(state_.size.y,center.y+13)):
      for x in range(maxi(0,center.x-12),mini(state_.size.x,center.x+13)):
       var cell=Vector2i(x,y)
       if not Original.open(state_.bits,state_.size,cell):continue
       open_count+=1;var xy:Vector2=state_.origin+Vector2(cell)*3.;var point=Vector3(xy.x,game.model.surface_height(xy.x,xy.y),xy.y)
       var clear:bool=game.model.waves.navigation.move_clear(point,radius);var reachable:bool=game.army_runtime.native.can_reach(reach*game.model.falan_scale,point*game.model.falan_scale,radius)
       if clear:clear_count+=1
       if reachable:reachable_count+=1
       if clear and reachable:
        both_count+=1
        if samples.size()<5:samples.append({"cell":str(cell),"point":str(point)})
     observations.append({"species":row[0],"radius":radius,"hero_self_reachable":self_reachable,"reach_origin":str(reach),"open_candidates":open_count,"move_clear_candidates":clear_count,"reachable_candidates":reachable_count,"both_candidates":both_count,"samples":samples})
    boss_report.get_or_add("spawn_diagnostics",[]).append({"actor":id,"generation":generation,"phase":game.model.phase,"spawned":game.model.waves.spawned,"hero":str(game.player.position),"falan_scale":game.model.falan_scale,"specification":specification,"observations":observations})
   for enemy in game.model.enemies.values():
    var handle:int=game.army_runtime.handles.get(enemy.id,0);handles.append(handle)
    var source_id=str(enemy.get("source_enemy",""));var at=group.source_members.find_custom(func(m):return str(m.enemy_id)==source_id)
    if at<0:exact=false;continue
    var member:Array=group.members[at]
    exact=exact and handle!=0 and enemy.enemy_name==group.source_members[at].name and int(enemy.level)>=int(member[1])and int(enemy.level)<=int(member[2])and int(enemy.get("source_encounter",-1))==encounter and enemy.get("source_group","")=="dragon:"+str(11013 if encounter==11011 else encounter)
    counts[source_id]=int(counts.get(source_id,0))+1
   for member in group.source_members:exact=exact and int(counts.get(str(member.enemy_id),0))==int(member.count[0])
   check(exact,"Actual scripted native party keeps exact source names/IDs/levels/counts "+id)
   game.player.max_hp=review_hp;game.player.hp=review_hp;game.tuning.invincible=false;game.player.invuln=0.;game.player.model.clear_kagerou_dodge()
   game.army_runtime.record_events=true;game.army_runtime.compact_scene_events=false;game.army_runtime.event_log.clear()
   for tick in 1200:
    game.player.invuln=maxf(0.,game.player.invuln-1./60.);game.player.model.tick_kagerou_dodge(1./60.);game.army_runtime.integration_tick(1./60.)
   var contacts=game.army_runtime.event_log.filter(func(e):return e.kind=="external_damage"and e.external_kind==0 and e.source_id in ids)
   check(not ids.is_empty()and ids.all(func(unit):return contacts.any(func(e):return e.source_id==unit)),"Every original scripted member delivers native contact "+id)
   check(game.player.hp<review_hp,"Source scripted party damages the live hero "+id)
   for tick in 180:
    for handle in handles:
     if game.army_runtime.valid(handle):game.army_runtime.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
    if handles.all(func(h):return not game.army_runtime.valid(h)):break
    game.army_runtime.integration_tick(1./60.)
   game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
   check(game.model.enemies.is_empty()and handles.all(func(h):return not game.army_runtime.valid(h)),"Source boss death clears every native handle "+id)
   game.model.waves.tick(0.,game.player.position)
   for i in 6:await physics_frame
   game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0);freeze()
   var context={};Events.source_context(game,context,int(values[3]))
   var landing=context.get("cell",Vector2i(-1,-1));var expected_cell=Vector2i(values[4],values[5])
   check(game.model.falan_floor==int(values[3])and landing==expected_cell,"Declared source battle return preserves exact map/cell "+id)
   boss_report.fights.append({"actor":id,"generation":generation,"encounter":encounter,"members":ids.size(),"identities":counts,"contacts":contacts.size(),"expected_return":[values[3],values[4],values[5]],"actual_floor":game.model.falan_floor,"actual_cell":str(landing)})
 for id in flags:Original.Art.data().maps[Original.path_for(id)].sokia_visual_only=flags[id]
 for id in old_actors:
  if old_actors[id].is_empty():Region.source_actors.erase(id)
  else:Region.source_actors[id]=old_actors[id]
 end_dialogue();set_meta(Regional.BATTLES,{});set_meta(Regional.SLAIN,{});set_meta(Events.ITEMS,items)
 check(JSON.stringify(get_meta("falan_venture"))==saved and get_meta(Events.ITEMS,{})==items,"Adventure/items preserved without prerequisite grants")
 boss_report.checks=checks;boss_report.failures=errors;boss_report.ordinary_F=event_report.actors;boss_report.captures=event_report.captures
 boss_report.qualification="Actual original F and dialogue paths, native parties and declared returns. Review flags are temporary; natural entry, original mode2result semantics, probability/AI, loss/escape/repeat behavior and full scenery remain separate. Recording heroHP enlarged, enemy party/damage/timing retained."
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered";var prefix="bosses-wind-diagnostic-"if "--wind-only"in OS.get_cmdline_user_args()else"bosses-";var f=FileAccess.open(BOSS_OUT+prefix+mode+".json",FileAccess.WRITE)
 f.store_string(JSON.stringify(boss_report,"  "));f.close();print("DRAGON_BOSS_RESULT checks=",checks," failures=",errors)
 game.army_runtime.finish_integration();game.queue_free()
 for i in 4:await process_frame
 quit(1 if errors else 0)
