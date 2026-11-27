extends "res://tests/forest-shrine/wind_tower_review.gd"
## Normal F/chat/choices and original automatic guardian registration; items are fixture contexts only.
const Region=preload("res://scripts/forest/forest_east_region.gd")
var event_report={"actors":[],"warps":[],"guardians":[],"captures":[],"goal_complete":false}
func _initialize():
 create_timer(1800).timeout.connect(func():printerr("WIND_NPC_TIMEOUT");quit(1))
 run.call_deferred()
func end_dialogue():
 if is_instance_valid(game.dialogue):game.close_boss_dialogue()
 if game.has_meta(Events.SESSION):game.remove_meta(Events.SESSION)
 game.explorer_npcs.selected={}
func press_source(id:String)->Dictionary:
 end_dialogue();game.explorer_npcs.prepare()
 var entry:Dictionary=find_actor(id);check(not entry.is_empty(),"One ordinary explorer NPC enrolls source actor "+id)
 if entry.is_empty():return{}
 var actor:Dictionary=Region.source_actors[id];var source:int=actor.source
 var station=Vector2.INF
 var center=Region.source_point(source,Vector2i(actor.cell[0],actor.cell[1]),game.model.falan_area)
 for radius in [1.,2.,3.,4.]:
  for offset in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]:
   var at=center+offset*radius;var world=game.model.world_point(at,.15)
   if not game.army_runtime.native.can_reach(world,world,.4):continue
   game.player.position=world;game.player.velocity=Vector3.ZERO;game.model.hero_position=world;game.player.reset_physics_interpolation()
   game.explorer_npcs.update_left=0;game.explorer_npcs._process(.2)
   if game.explorer_npcs.nearest.get("record",{}).get("id","")=="source:"+id:station=at;break
  if station.is_finite():break
 check(station.is_finite(),"Original actor has a reachable ordinary F station "+id)
 if not station.is_finite():return{}
 var input=InputEventKey.new();input.physical_keycode=KEY_F;input.pressed=true;game._input(input)
 var state:Dictionary=game.get_meta(Events.SESSION,{})
 check(state.get("actor",{}).get("id","")==id,"Actual F dispatches original actor program "+id)
 event_report.actors.append({"id":id,"source":source,"source_cell":actor.cell,"station":str(station),"status":state.get("status","missing"),"invisible":actor.invisible})
 return state
func answer(choice:String):
 check(is_instance_valid(game.dialogue),"Original choice has a live dialogue "+choice)
 if is_instance_valid(game.dialogue):game.dialogue.chosen.emit(choice)
func say(words:String):
 check(is_instance_valid(game.dialogue)and is_instance_valid(game.dialogue.entry),"Original phrase uses the ordinary chat field")
 if is_instance_valid(game.dialogue)and is_instance_valid(game.dialogue.entry):
  game.dialogue.entry.text=words;game.dialogue.chosen.emit("OK")
func settled():
 for i in 6:await physics_frame
 game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0)
 freeze();clear_enemies();game.model.waves.spawned=2
func capture_dialogue(label_:String):
 if DisplayServer.get_name()=="headless":return
 if is_instance_valid(game.dialogue)and game.dialogue.body.visible_characters>=0 and game.dialogue.body.visible_characters<game.dialogue.body.get_total_character_count():
  var reveal=InputEventKey.new();reveal.physical_keycode=KEY_SPACE;reveal.pressed=true;game._input(reveal)
 game.world.sync(0.);game.camera_rig.yaw=0.;game.camera_rig.pitch=game.COMBAT_CAMERA_PITCH;game.camera_rig.camera.fov=63.
 game.camera_rig.distance=game.ViewPreferences.CAMERA_DEFAULT;game.camera_rig.reset_follow();game.camera_rig.update_camera(0.,true)
 game.camera_rig.reset_physics_interpolation();game.camera_rig.camera.reset_physics_interpolation()
 for i in 4:await process_frame
 RenderingServer.force_draw();var path=WIND_OUT+"npc-"+label_+".png"
 check(root.get_texture().get_image().save_png(path)==OK,"Saved fixed original-event dialogue "+label_)
 event_report.captures.append(path)
func check_landing(expected:Array,label_:String):
 await settled();check(game.model.falan_floor==int(expected[1]),"Source event reaches original destination map "+label_)
 var ctx={};Events.source_context(game,ctx,int(expected[1]))
 var exact=ctx.get("cell",Vector2i(-1,-1))==Vector2i(expected[2],expected[3])
 check(exact,"Source event retains its exact original landing cell "+label_)
 event_report.warps.append({"actor":label_,"expected":expected,"actual_floor":game.model.falan_floor,"actual_cell":str(ctx.get("cell")),"exact":exact})
func run():
 root.size=Vector2i(1280,800);review_hp=1000000000.
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-wind-events-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.player.set_auto_attack(false);freeze()
 var saved=JSON.stringify(get_meta("falan_venture"));var saved_items:Dictionary=get_meta(Events.ITEMS,{}).duplicate(true)
 Original.Art.load_sokia_wind();var flags={}
 for id in Original.Art.SOKIA_WIND_IDS:
  var row:Dictionary=Original.Art.data().maps[Original.path_for(id)];flags[id]=row.sokia_visual_only;row.sokia_visual_only=false
 var outside=Region.source_point(300,Vector2i(462,404),"sokia_coast")
 Tour.travel(game,Tour.Regions.layout("sokia_coast"),{"arrival":outside,"yaw":0.,"velocity":Vector3.ZERO});await settled()
 var no_item=press_source("6267");check(no_item.get("status","")=="done","Natural empty inventory cannot open the sea or gain an item")
 check(get_meta(Events.ITEMS,{})==saved_items,"No entry prerequisite granted")
 var held=saved_items.duplicate(true);held.source_item_18575=1;set_meta(Events.ITEMS,held)
 var entry=press_source("6267");check(entry.get("status","")=="chat","Held item still requires the exact source phrase")
 say("wrong");check(game.model.falan_area=="sokia_coast","Wrong phrase does not travel")
 press_source("6267");say(Region.wind_events().messages["17034"]);await capture_dialogue("sea-entry")
 answer("OK");await check_landing([0,302,103,24],"6267")
 var route=Original.links(302).filter(func(link):return int(link.get("floor",-1))==301)
 check(route.size()==1,"Original Contract Sea fixed route reaches Arcas")
 if route.size()==1:Tour.enter_link(game,"interior",route[0],route[0].at);await settled()
 press_source("6271");say(Region.wind_events().messages["17034"]);answer("OK");await check_landing([0,302,17,12],"6271")
 var circles={"6255":[[0,20309,51,42],[0,20308,51,35]],"6256":[[0,20309,51,34],[0,20308,51,40]],"6257":[[0,20305,44,63],[0,20304,54,63]],"6258":[[0,20305,56,63],[0,20304,46,63]],"6259":[[0,20304,50,32],[0,20302,50,25]],"6260":[[0,20304,50,23],[0,20302,50,29]],"6261":[[0,20309,37,78],[0,20308,37,68]],"6262":[[0,20309,37,66],[0,20308,37,76]],"6263":[[0,20308,50,30],[0,20305,50,24]]}
 for id in circles:
  var actor:Dictionary=Region.source_actors[id]
  for item in [false,true]:
   await visit(int(actor.source));var items=saved_items.duplicate(true)
   if item:items.source_item_18566=1
   set_meta(Events.ITEMS,items)
   var state=press_source(id);check(state.get("status","")=="chat","R guard is retained without a synthetic trigger "+id)
   say("R");answer("YES")
   if id=="6255":await capture_dialogue("wind-circle-"+str(item))
   answer("NEXT");await check_landing(circles[id][0 if item else 1],id+str(item))
   check(get_meta(Events.ITEMS,{})==items,"Original circle preserves held items "+id)
 set_meta(Events.ITEMS,saved_items.duplicate(true));await visit(20002)
 for id in ["6268","6269"]:
  var state=press_source(id);check(state.get("status","")=="window","Original visible speaker starts source dialogue "+id)
  check(is_instance_valid(game.dialogue)and game.dialogue.body.text.contains("阿卡斯"),"Actual dialogue displays original words "+id)
  if id=="6268":await capture_dialogue("arcas")
  end_dialogue()
 press_source("6268")
 for choice in ["NEXT","NEXT","NEXT","NEXT","NEXT","NEXT","NEXT","OK"]:answer(choice)
 var arcas_key=Regional.active(self,20002,"interior");check(not arcas_key.is_empty(),"Ordinary F and every original story window start Arcas's source battle")
 game.model.waves.spawned=0;game.model.waves.tick(0.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
 check(game.model.enemies.size()==5,"Ordinary NPC dialogue dispatches all5original Arcas members")
 var handles=game.army_runtime.handles.values().duplicate()
 for tick in 180:
  for handle in handles:
   if game.army_runtime.valid(handle):game.army_runtime.apply_hit(handle,{"amount":1000000.,"accuracy":100.})
  if handles.all(func(h):return not game.army_runtime.valid(h)):break
  game.army_runtime.integration_tick(1./60.)
 game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility();game.model.waves.tick(0.,game.player.position)
 await check_landing([0,20003,43,7],"6268-victory")
 await visit(20003);var after=press_source("6272")
 check(after.get("status","")=="window"and after.context.external.bimage==102488,"Actual selected source appearance supplies the transformation predicate")
 await capture_dialogue("goddess")
 for choice in ["NEXT","NEXT","NEXT","NEXT","OK"]:answer(choice)
 await check_landing([0,1530,15,6],"6272")
 check(int(get_meta(Events.ITEMS,{}).get("source_endevent_19",0))==1,"Postbattle source EndEvent19commits only with valid return")
 for id in ["80081","80082"]:
  await visit(20306);end_dialogue();set_meta(Regional.BATTLES,{});set_meta(Regional.SLAIN,{})
  var actor:Dictionary=Region.source_actors[id];var point=Original.source_point(20306,Vector2i(actor.cell[0],actor.cell[1])+Vector2i.DOWN)
  game.player.position=game.model.world_point(point,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
  Region.tick(game,.2)
  var key=Regional.active(self,20306,"interior");check(not key.is_empty(),"Original guardian uses the existing automatic owner "+id)
  game.model.waves.spawned=0;game.model.waves.tick(0.,game.player.position)
  game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
  check(game.model.enemies.size()==7,"Automatic source trigger retains all7mandatory members "+id)
  event_report.guardians.append({"actor":id,"key":key,"members":game.model.enemies.size()});clear_enemies()
  set_meta(Regional.BATTLES,{});set_meta(Regional.SLAIN,{})
 set_meta(Events.ITEMS,saved_items);end_dialogue()
 for id in flags:Original.Art.data().maps[Original.path_for(id)].sokia_visual_only=flags[id]
 check(JSON.stringify(get_meta("falan_venture"))==saved,"User adventure preserved")
 check(get_meta(Events.ITEMS,{})==saved_items,"Fixture inventory and event flags restored")
 event_report.checks=checks;event_report.failures=errors;event_report.R_original_input_semantics="unverified; typed literalR is fixture input, not proof of original interaction binding"
 event_report.qualification="Ordinary F/chat/dialogue/warp integration. Prerequisite items are temporary fixture contexts, never granted by gameplay. Original acquisition and StandEnemy scheduling semantics remain separate; scenery/portrait approval not claimed."
 var mode="headless"if DisplayServer.get_name()=="headless"else"rendered"
 var file=FileAccess.open(WIND_OUT+"npc-integration-"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(event_report,"  ")+"\n");file.close()
 print("WIND_NPC_RESULT ",checks," checks ",errors," failures;",event_report.warps.size()," source warps;",event_report.guardians.size()," automatic parties")
 game.queue_free();await process_frame;quit(1 if errors else 0)
