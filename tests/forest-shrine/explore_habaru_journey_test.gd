extends "res://tests/forest-shrine/explore_bosses_test.gd"
## One setup in Alyut; every subsequent move uses normal walking or F.
var journey=[]

func _initialize():
 create_timer(900).timeout.connect(func():printerr("HABARU_JOURNEY_TIMEOUT");save_journey();quit(1));run.call_deferred()

func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-habaru-journey-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 set_test_seed();game.tuning.invincible=true;game.player.run_upgrades.damage=10000;game.player.set_auto_attack(false)
 check(preload("res://scripts/forest/forest_explore_routes.gd").travel(game,2400,Vector2i(51,45)),"Initial setup loads the normal Alyut village street")
 for i in 12:await physics_frame
 check(Tour.area(game.model)=="north_coast"and Tour.Regions.village_contains("north_coast",Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale),"Journey starts inside the continuously joined original village")
 mark("Alyut street")
 var gate=Tour.Regions.village_transform("alyut")*Tour.Regions.ALYUT_SOUTH_GATE
 await walk_checkpoint(gate,"Alyut south gate")
 if failures:save_journey();finish();return
 for at:Vector2 in Tour.Regions.HABARU_TRAIL.north_coast:
  await walk_checkpoint(at,"Original dry trail")
  if failures:save_journey();finish();return
 if failures:save_journey();finish();return
 var mouth=Tour.Regions.site_links("north_coast").filter(func(link):return int(link.site)==11005)
 check(mouth.size()==1,"Normal trail has one Alyut-side cave entrance")
 if mouth.is_empty():save_journey();finish();return
 await walk_checkpoint(mouth[0].trail_sign,"Cave trail sign")
 var back=Tour.Regions.frame("north_coast").inverse().basis_xform(Vector2.RIGHT).normalized()
 await walk_checkpoint(mouth[0].at-back*6.,"Cave mouth approach")
 if failures:save_journey();finish();return
 await walk_toward(mouth[0].at,900)
 for i in 12:await physics_frame
 check(game.model.falan_floor==11005,"Actual village trail enters original Habaru Alyut floor")
 mark("Habaru Alyut entrance");await access_capture("journey-habaru-entrance")
 var stairs=game.model.get_meta("falan_links",[]).filter(func(link):return int(link.get("floor",-1))==11004)
 check(stairs.size()==1,"Original onward stair reaches the bear arena")
 if stairs.is_empty():save_journey();finish();return
 check(await walk_door(stairs[0].at),"Actual walking uses the original cave stair")
 for i in 12:await physics_frame
 check(game.model.falan_floor==11004,"Original stair enters the bear arena")
 mark("Bear arena stair")
 var spots=game.explore_access.boss_spots.filter(func(spot):return spot.group=="habaru_slot")
 check(not spots.is_empty(),"Bear encounter has its discovered map marker")
 var boss_at:Vector2=Tour.Regions.Sites.HABARU_FORMATION[0]
 await walk_toward(boss_at+Vector2(0,5),900,true)
 check(is_instance_valid(game.habaru_waiting)and game.habaru_waiting.is_visible_in_tree(),"Original bear model is visible when approached from the stairs")
 check(game.can_talk_to_host(game.habaru_waiting),"Player-side original conversation prompt is reachable on foot")
 await access_capture("journey-habaru-waiting");mark("Visible bear and conversation")
 press_f();check(is_instance_valid(game.dialogue),"Actual F starts the original bear conversation")
 await drain()
 for i in 15:await physics_frame
 game.model.waves.tick(0.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
 for victory in 2:
  var party=game.model.enemies.values().filter(func(e):return e.has("habaru_slot")and e.hp>0)
  check(party.size()==10,"Full ten-member original bear party spawns for victory "+str(victory+1))
  var record={"boss":"journey-habaru"}
  await fight_with_player_inputs("habaru_slot",record);await wait_for_portal("habaru_slot",victory+1)
  var returns=game.explore_access.encounters.values().filter(func(r):return r.scope==game.explore_access.scope()and r.group=="habaru_slot"and r.cleared and r.has("portal"))
  check(returns.size()==1,"Full party victory leaves exactly one optional return portal")
  if returns.is_empty():save_journey();finish();return
  var loot=game.exploration_loot
  var chests=loot.slots.filter(func(slot):return slot.active and slot.get("boss",false))
  check(chests.size()==1,"Each bear victory leaves one earned weapon chest")
  if not chests.is_empty():
   var chest=chests[0];await walk_toward(Vector2(chest.pos.x,chest.pos.z)/game.model.falan_scale,900,true);press_f()
   if is_instance_valid(game.dialogue)and game.dialogue.pages[0].get("options",[]).any(func(o):return o[0]=="loot"):game.dialogue.chosen.emit("loot")
   check(loot.opened_chests.has(chest.key)and chest.sword in game.settings.chest_swords,"Actual walking and F claim the guaranteed boss weapon")
  await walk_toward(returns[0].portal,900,true)
  check(game.player.position.distance_to(game.model.world_point(returns[0].portal,.15))<1.,"Return portal is reachable from the earned chest")
  await access_capture("journey-habaru-portal-"+str(victory+1));mark("Looted victory "+str(victory+1))
  var gold=game.model.gold;var items=get_meta("university_quest_items",{}).duplicate(true);var quests=game.settings.explorer_quests.duplicate(true);var checkpoint=game.checkpoint;var weapons=game.settings.chest_swords.duplicate();var accessories=game.settings.accessory_drops.duplicate(true)
  press_f();check(is_instance_valid(game.dialogue)and game.dialogue.speaker=="回城傳送門","Actual F opens the optional return portal")
  if is_instance_valid(game.dialogue):game.dialogue.chosen.emit("retry"if victory==0 else"return")
  for i in 15:await physics_frame
  if victory==0:
   await walk_toward(boss_at+Vector2(0,5),900,true)
   press_f()
   if is_instance_valid(game.dialogue)and game.dialogue.speaker=="Cross Gate"and game.dialogue.pages[0].get("options",[]).any(func(o):return o[0]=="talk"):game.dialogue.chosen.emit("talk")
   check(is_instance_valid(game.dialogue),"Retry walks to the visible bear and repeats its original F conversation")
   await drain()
   for i in 20:await physics_frame
   game.model.waves.tick(0.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility();game.explore_access._process(.2)
   mark("Repeated original bear conversation")
  if victory==1:
   check(Tour.area(game.model)=="city"and game.player.position.distance_to(game.model.world_point(game.explore_access.HOSPITAL_LANDING,.15))<.5,"Later victory returns directly outdoors beside the east hospital")
   check(game.model.gold==gold and get_meta("university_quest_items",{})==items and game.settings.explorer_quests==quests and game.checkpoint==checkpoint and game.settings.chest_swords==weapons and game.settings.accessory_drops==accessories,"Taking the portal preserves home, gold, items, weapons, accessories and quests")
   await access_capture("journey-east-hospital");mark("East hospital outdoor landing")
 save_journey();print("HABARU_JOURNEY_RESULT checks=",checks," failures=",failures);finish()

func walk_checkpoint(at:Vector2,label_:String):
 await walk_toward(at,1800,true)
 check(Tour.area(game.model)=="north_coast"and game.player.position.distance_to(game.model.world_point(at,.15))<1.,"Actual walking reaches "+label_+" "+str(at))
 mark(label_)

func mark(label_:String):
 journey.append({"stage":label_,"area":Tour.area(game.model),"floor":game.model.falan_floor,"at":str(game.player.position),"failures":failures})
 print("HABARU_JOURNEY ",journey[-1])
 save_journey()

func save_journey():
 var file=FileAccess.open(ACCESS_OUT+"habaru-continuous-journey.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"source_maps":[2400,100,11005,11004,1000],"qualification":"One direct setup in Alyut; actual walking/F thereafter. Temporary hero invulnerability and damage boost; original enemies/phases retained.","stages":journey,"checks":checks,"failures":failures,"passed":failures==0 and not journey.is_empty()and journey[-1].stage=="East hospital outdoor landing"},"  "));file.close()
