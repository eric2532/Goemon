extends "res://tests/forest-shrine/sokia_cape_review.gd"
## Fresh F triggers, partial reentry and scoped run cleanup use the existing native owner.
var lifecycle={"rounds":[],"limits":["Fresh explicit source interactions may repeat; original server cooldown/respawn scheduling is unverified.","Leaving an unfinished real-time fight retains its dead slots and resumes survivors, an existing regional adaptation.","Seed/same-seed ledger reset checks use direct fixture resets and real map reloads; they are not a recorded title/new-game UI traversal."]}
func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-cape-lifecycle-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.tuning.invincible=true;game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"))
 for generation in 2:
  await scripted_fights()
  check(cape_report.scripted.size()==2,"Both fresh source F interactions complete in generation"+str(generation))
  lifecycle.rounds.append(cape_report.scripted.duplicate(true))
 var actor:Dictionary=Population.cape_data().actors["5305"]
 var trigger_row:Dictionary=cape_report.scripted.filter(func(row):return row.npc=="5305")[0]
 var trigger=Vector2i(trigger_row.trigger_cell[0],trigger_row.trigger_cell[1])
 await enter_cape(15526,trigger)
 Events.source_actor(game,actor)
 var key=Regional.active(self,15526,"interior")
 check(not key.is_empty(),"A third explicit Lorens trigger starts after completed visits")
 game.model.waves.tick(1.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
 check(game.model.enemies.size()==5,"Fresh Lorens formation is complete after prior slain slots")
 if game.model.enemies.is_empty():
  printerr("CAPE_LIFECYCLE_EMPTY ",{"trigger":trigger,"player":game.player.position,"key":key,"battle":get_meta(Regional.BATTLES,{})});quit(1);return
 var first:Dictionary=game.model.enemies.values()[0]
 var handle:int=game.army_runtime.handles[first.id];var slot:int=first.university_slot
 var departed=game.army_runtime.handles.values().duplicate()
 for attempt in 20:
  game.army_runtime.apply_hit(handle,{"amount":1000000.,"accuracy":100.});game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
  if not game.model.enemies.has(first.id):break
 check(game.model.enemies.size()==4 and get_meta(Regional.SLAIN,{}).has(Regional.slain_key(key,15526,slot)),"One native defeat persists in the current unfinished source fight")
 await enter_cape(15525,Vector2i(16,11))
 check(Regional.active(self,15526,"interior")==key and Regional.active(self,15525,"interior").is_empty(),"Leaving retains only the unfinished fight on its own source map")
 check(departed.all(func(old):return not game.army_runtime.apply_hit(old,{"amount":1.}).accepted),"Leaving retires every old native handle")
 await enter_cape(15526,trigger)
 game.model.waves.tick(1.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
 check(game.model.enemies.size()==4,"Reentry resumes the four surviving source members")
 check(game.model.enemies.values().all(func(row):return row.university_slot!=slot),"Reentry does not resurrect the defeated native slot")
 var surviving=game.army_runtime.handles.values().duplicate()
 var battles:Dictionary=get_meta(Regional.BATTLES,{})
 battles.zombie={"map":51031,"complete":true};set_meta(Regional.BATTLES,battles)
 var slain:Dictionary=get_meta(Regional.SLAIN,{})
 var foreign=Vector2i(51031,0);slain[foreign]=true;set_meta(Regional.SLAIN,slain)
 game.run_seed=41829559
 await enter_cape(15526,trigger)
 Events.source_actor(game,actor)
 var fresh=Regional.active(self,15526,"interior")
 check(fresh==key and not get_meta(Regional.BATTLES,{})[fresh].complete,"A new seed replaces stale Cape state with a fresh source formation")
 check(Cape.specifications.size()==1,"New-seed Cape specifications stay bounded to the new trigger")
 check(get_meta(Regional.SLAIN,{}).has(foreign) and not get_meta(Regional.SLAIN,{}).keys().any(func(old):return old is String and old.begins_with("sokia:")),"New-seed cleanup removes only Cape dead slots")
 check(get_meta(Regional.BATTLES,{}).get("zombie",{}).get("complete",false),"Unrelated regional completion state remains intact")
 check(surviving.all(func(old):return not game.army_runtime.apply_hit(old,{"amount":1.}).accepted),"New-seed world reload rejects every previous native handle")
 game.model.waves.tick(1.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
 check(game.model.enemies.size()==5,"New-seed source fight has all five mandatory native members")
 # Production begin_saved_falan clears these shared ledgers before a fresh adventure.
 remove_meta(Regional.BATTLES);remove_meta(Regional.SLAIN);remove_meta("university_victory")
 await enter_cape(15526,trigger)
 Cape.prepare_run(game)
 check(Cape.specifications.is_empty(),"Same-seed new-adventure ledger reset also clears old Cape specifications")
 Events.source_actor(game,actor)
 game.model.waves.tick(1.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
 check(game.model.enemies.size()==5,"Same-seed fresh ledger can start the complete source fight again")
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Lifecycle fixture preserves the adventure document")
 lifecycle.checks=checks;lifecycle.failures=errors;lifecycle.source_scripted=cape_report.scripted;lifecycle.goal_complete=false
 var file=FileAccess.open(CAPE_OUT+"lifecycle.json",FileAccess.WRITE);file.store_string(JSON.stringify(lifecycle,"  "));file.close()
 print("SOKIA_CAPE_LIFECYCLE_RESULT checks=",checks," failures=",errors," rounds=",lifecycle.rounds.size())
 game.queue_free();await process_frame;quit(1 if errors else 0)
func enter_cape(id:int,cell:Vector2i):
 var layout:Dictionary=Tour.Indoor.layout(id);layout.seed=game.run_seed
 Tour.travel(game,layout,{"arrival":Original.source_point(id,cell),"yaw":0.,"velocity":Vector3.ZERO})
 for i in 4:await physics_frame
 game.army_runtime.finish_integration();game.army_runtime.refresh_navigation(0)
 game.paused=false;game.transitioning=false;game.ordinary_pause=false;paused=false
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 clear_enemies();game.model.waves.spawned=0
