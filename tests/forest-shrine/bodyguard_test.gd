extends "res://tests/forest-shrine/pet_attack_skills_test.gd"
const RESCUE_OUT="res://build/Other Files/Asset Toolkit/Bodyguard/"

func rescue_tick(dt:float):
 game.player._physics_process(dt)
 game.army_runtime.integration_tick(dt)
 game.army_runtime.flush_presentation()

func photograph(name_:String):
 if DisplayServer.get_name()=="headless":return
 await frames(2)
 game.player.timed_dodge._process(0)
 RenderingServer.force_draw()
 check(root.get_texture().get_image().save_png(RESCUE_OUT+name_+".png")==OK,"Captured "+name_)

func clear_setup_fx():
 var fx=game.crowd.army.presentation
 fx.effects.clear();fx.label_ages.fill(0)
 for label in fx.labels:label.hide()

func run():
 create_timer(240).timeout.connect(func():printerr("BODYGUARD_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(RESCUE_OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime
 army.record_events=true
 game.set_process(false);army.set_process(false);army.set_physics_process(false)
 game.camera_rig.set_process(false);game.music.stop();p.set_auto_attack(false)
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 game.training_dummy.position=home+Vector3.DOWN*1000;game.training_dummy.home=game.training_dummy.position
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 game.camera_rig.camera.global_position=home+Vector3(13,12,18);game.camera_rig.camera.look_at(home+Vector3.UP*2)
 check(Pets.skill_codes([Pets.Spells.BODYGUARD,"",""])[0]==22,"護衛 appends its native code without changing saved technique IDs")
 check(Pets.Spells.all()[Pets.Spells.BODYGUARD].name=="護衛" and Pets.Spells.KAZI_ICONS.has(Pets.Spells.BODYGUARD),"The equipment catalog has the recovered skill and exclamation icon")
 for id in p.RogueRoster.CROSSGATE:
  p.select_character(id);p.timed_dodge.reset();p.hp=p.max_hp
  check(p.spell_loadout.equip(id,"special_6",Pets.Spells.BODYGUARD),"Equip automatic 護衛 for fighter %d"%id)
  await equip_pack([0],[["","",""]])
  var handle:int=army.handles[army.HOUND_ID]
  var enemy=spawn(Vector3(0,0,-24))
  p.position=home+Vector3.RIGHT*6;p.velocity=Vector3.ZERO;p.invuln=0;p.combat_hold_left=0
  army.native.set_pose(handle,home,0);army.native.set_targets(army.external_targets())
  var rescued=0;var hp_before=p.hp
  for attempt in 2:
   army.native.set_pose(handle,home,0);p.position=home+Vector3.RIGHT*6
   army.native.set_targets(army.external_targets())
   p.active_ability.start_attack()
   var ally_before:float=army.unit_state(handle).hp
   clear_setup_fx()
   army.apply_hit(handle,{"amount":10.0,"source_id":enemy.forest_id,"direction":Vector3.BACK})
   if p.timed_dodge.rescue_left>0:
    rescued+=1
    check(not p.active_ability.is_attacking() and p.dodge_time==0,"護衛 interrupts the attack for fighter %d"%id)
    check(army.unit_state(handle).hp==ally_before,"The protected pet takes no transferred damage for fighter %d"%id)
    check(army.unit_state(handle).position.z>home.z+1,"The rescued pet is pushed clear for fighter %d"%id)
    p.invuln=10 # Taking over must bypass an unrelated immunity window.
    await driver.advance(4,rescue_tick)
    if id==p.RogueRoster.SHIN_ID:await photograph("character-dash")
    await driver.advance(16,rescue_tick)
    check(p.hp<hp_before,"The protector actually takes the hit for fighter %d"%id)
    check(p.timed_dodge.rescue_left==0 and p.global_position.distance_to(home+Vector3(0,0,-.8))<3,"The dash finishes in front of the ally for fighter %d"%id)
    if id==p.RogueRoster.SHIN_ID:await photograph("character-took-hit")
   else:
    p.active_ability.cancel(true)
    check(army.unit_state(handle).hp<ally_before,"The failed draw leaves the normal hit intact for fighter %d"%id)
  check(rescued==1,"Exactly one rescue in two eligible draws for fighter %d"%id)
  check(p.spell_loadout.equip(id,"special_6","") and not p.timed_dodge.bodyguard_equipped,"Removing 護衛 disables automatic rescue for fighter %d"%id)
 # The same skill on each original pet family protects another pet and then attacks.
 p.select_character(p.RogueRoster.SHIN_ID);p.position=home+Vector3.RIGHT*40
 army.record_events=false
 for skin in [0,21,41,61,81]:
  await equip_pack([skin,1],[[Pets.Spells.BODYGUARD,"",""],["","",""]])
  var guard:int=army.handles[army.HOUND_ID-skin];var ally:int=army.handles[army.HOUND_ID-1]
  army.native.set_pet_growth(guard,10000,0);army.native.set_pet_growth(ally,10000,0)
  var enemy=spawn(Vector3(0,0,-6));var rescued=0
  for attempt in 2:
   army.native.set_pose(guard,home+Vector3.RIGHT*6,0);army.native.set_pose(ally,home,0)
   army.native.set_targets(army.external_targets())
   var before:float=army.unit_state(guard).hp
   clear_setup_fx();army.presentation_events.clear()
   army.apply_hit(ally,{"amount":10.0,"source_id":enemy.forest_id,"direction":Vector3.BACK})
   var started=army.presentation_events.any(func(e):return e.kind=="status" and e.get("action_index",0)==6010 and e.source_id==army.HOUND_ID-skin)
   if started:
    rescued+=1
    await driver.advance(4,rescue_tick)
    check(army.unit_state(guard).position.y>home.y+.2,"Pet family %d visibly jumps into the rescue"%skin)
    check(game.crowd.army.presentation.effects.any(func(e):return e.kind=="bodyguard-mark"),"Pet rescue displays the recovered exclamation mark")
    if skin==0:await photograph("pet-jump")
    await driver.advance(16,rescue_tick)
    check(army.unit_state(guard).hp<before,"Pet family %d takes the transferred hit"%skin)
    var foe_hp=enemy.hp
    await driver.advance(180,rescue_tick)
    check(enemy.hp<foe_hp,"Pet family %d attacks the nearby enemy after rescue"%skin)
    if skin==0:await photograph("pet-follow-up")
   army.event_log.clear()
  check(rescued==1,"Pet family %d uses a 50%% shuffle bag"%skin)
 # Warm one setup, then repeat rescues without creating presentation resources.
 p.select_character(p.RogueRoster.SHIN_ID);var ordinary_max:float=p.max_hp;p.max_hp=10000;p.hp=10000
 p.spell_loadout.equip(p.character_id,"special_6",Pets.Spells.BODYGUARD)
 await equip_pack([0],[["","",""]])
 var ally:int=army.handles[army.HOUND_ID];army.native.set_pet_growth(ally,10000,0)
 var source=spawn(Vector3(0,0,-24));var nodes=0;var resources=0.0;var successes=0
 for attempt in 40:
  p.position=home+Vector3.RIGHT*6;p.velocity=Vector3.ZERO;p.invuln=0
  army.native.set_pose(ally,home,0);army.native.set_pose(source.handle,home+Vector3(0,0,-24),0)
  army.native.set_targets(army.external_targets())
  army.apply_hit(ally,{"amount":2.0,"source_id":source.forest_id,"direction":Vector3.BACK})
  if p.timed_dodge.rescue_left>0:successes+=1
  await driver.advance(14,rescue_tick)
  if attempt==5:nodes=get_node_count();resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 check(successes==20,"Forty repeated eligible hits produce twenty rescues")
 var node_delta=get_node_count()-nodes;var resource_delta=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
 check(node_delta<=0 and resource_delta<=0,"Repeated rescues retain no warmed nodes or resources: nodes %+d, resources %+.0f"%[node_delta,resource_delta])
 p.max_hp=ordinary_max;p.hp=minf(p.hp,ordinary_max)
 game.show_equipment_hub(true);await frames(2)
 var hub=game.equipment_hub;hub.show_page("skills");await frames(2)
 check(hub.available_items().has("skill:"+Pets.Spells.BODYGUARD),"Character Equipment lists 護衛 with the current weapon")
 hub.selected_item="skill:"+Pets.Spells.BODYGUARD;hub.refresh()
 await photograph("equipment")
 hub.select_owner(1);hub.show_page("skills");hub.selected_slot="equip";hub.assign_skill(Pets.Spells.BODYGUARD)
 check(hub.skill_assignment("equip")=="skill:"+Pets.Spells.BODYGUARD and Pets.skill_slots(game.settings.forest_pet_skills,Pets.key(0)).has(Pets.Spells.BODYGUARD),"Pet Equipment equips and saves 護衛 through the real skill slot")
 await photograph("pet-equipment")
 game.back_from_equipment()
 print("BODYGUARD_GAME_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();await process_frame;quit(1 if failures else 0)
