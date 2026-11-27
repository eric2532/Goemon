extends "res://tests/forest-shrine/crossgate_primary_targeting_test.gd"
const DASH_OUT="res://build/Other Files/Asset Toolkit/Accessories/Dash Boots/"

func settle(character:int):
 await super.settle(character)
 # Arrival/contact checks must not depend on the enemy's separate evasion bag.
 game.update_character_tuning(character,"accuracy",100)

func dash_equipment(character:int,enabled:bool,weapon:String="sword",shoes:bool=false):
 var slots={"1":"weapon:"+weapon}
 if enabled:slots["accessory:1"]="accessory:dash-boots"
 if shoes:slots["accessory:2"]="accessory:21817"
 check(game.save_equipment_loadouts({Gear.character_key(character):slots},{},{}),"Save Dash Boots selection for %d"%character)

func dash_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(DASH_OUT+stem+".png")==OK,"Captured "+stem)

func boots_case(character:int):
 if character in [34,36]:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE if character==36 else preload("res://scripts/kaz_skins.gd").DEFAULT
 game.settings.gear_loadouts={};await settle(character)
 var p=game.player;var kit=p.active_ability
 p.timed_dodge.shadow_counter_enabled=false
 dash_equipment(character,false)
 var target=place_target(kit.primary_reach()+26)
 await aim_sword(target)
 var start:Vector3=p.position
 click_attack();await driver.advance(1,func(_dt):advance(6,false))
 var ordinary:float=p.position.distance_to(start)
 check(not kit.state.get("approach_dashing",false) and kit.mode=="primary_approach","Without boots, fighter %d keeps the current approach"%character)
 kit.cancel(true);p.position=home;p.velocity=Vector3.ZERO
 dash_equipment(character,true)
 check(p.accessory_bonuses.get("attack_dash",0)==1,"Boots cache the dash permission for %d"%character)
 click_attack();await driver.advance(1,func(_dt):advance(6,false))
 var dashed:float=p.position.distance_to(home)
 check(kit.state.get("approach_dashing",false) and dashed>ordinary*1.3 and absf(dashed-kit.PRIMARY_DASH_SPEED*p.movement_multiplier()*6*DT)<.002,"Boots dash immediately outside the old five-unit rush for %d: %.2f vs %.2f"%[character,dashed,ordinary])
 check(p.model.current_clip.begins_with("3:") and p.invuln==0 and not p.timed_dodge.reacting,"Dash reuses the native run without dodge protection for %d"%character)
 if character==37:await dash_picture("shin-dashing")
 await driver.advance(1,func(_dt):
  for i in 260:
   advance(1,false)
   if not kit.is_attacking():break)
 check(target.hp<target.max_hp and kit.primary_combo_hits==1 and not kit.is_attacking(),"Dash stops at normal reach and completes one attack for %d"%character)
 check(not kit.state.get("approach_dashing",false),"Attack completion clears dash state for %d"%character)
 kit.cancel(true);p.position=home;p.velocity=Vector3.ZERO
 click_attack();await driver.advance(1,func(_dt):advance(3,false))
 dash_equipment(character,false);await driver.advance(1,func(_dt):advance(1,false))
 check(not p.accessory_bonuses.has("attack_dash") and not kit.state.get("approach_dashing",false),"Unequipping removes the dash immediately for %d"%character)
 kit.cancel(true)

func boots_edges():
 var p=game.player
 await settle(37);game.select_shin_skin(37,900050);p.timed_dodge.shadow_counter_enabled=false
 var kit=p.active_ability
 dash_equipment(37,true,"three-weapon",true)
 game.load_settings();Gear.apply(p)
 check(p.accessory_bonuses.get("attack_dash",0)==1 and p.accessory_bonuses.get("movement_speed",0)==3,"Dash Boots and Speed Shoes coexist and survive reload")
 var target=place_target(kit.primary_reach()+40)
 await aim_sword(target)
 click_attack();await driver.advance(1,func(_dt):advance(3,false))
 check(absf(p.position.distance_to(home)-kit.PRIMARY_DASH_SPEED*p.movement_multiplier()*3*DT)<.002,"Speed Shoes multiply the equipped dash speed")
 await driver.advance(1,func(_dt):advance(160,false))
 check(kit.primary_combo_hits==1 and p.model.weapon_combo_next==1,"Dash starts one Three-Weapon Combo step at normal contact range")
 kit.cancel(true);p.position=home;p.velocity=Vector3.ZERO;p.impact_pause=0
 dash_equipment(37,true)
 await aim_sword(target)
 tap("heavy_attack")
 check(kit.mode.is_empty(),"Right click cannot start a distant equipped dash")
 p.velocity.y=2;click_attack();p.velocity.y=0
 check(kit.mode.is_empty(),"An upward/airborne approach cannot start a dash")
 for property in ["paused","transitioning"]:
  game.set(property,true);click_attack();game.set(property,false)
  check(kit.mode.is_empty(),property+" blocks the dash click")
 click_attack();await driver.advance(1,func(_dt):advance(3,false))
 p.smoke_move=Vector2.RIGHT;await driver.advance(1,func(_dt):advance(1,false));p.smoke_move=Vector2.ZERO
 check(kit.mode.is_empty() and not kit.state.get("approach_dashing",false),"Manual movement cancels the selected dash")
 p.position=home;p.velocity=Vector3.ZERO;p.impact_pause=0
 var wall=StaticBody3D.new();var collider=CollisionShape3D.new();var box=BoxShape3D.new()
 box.size=Vector3(8,8,.2);collider.shape=box;wall.add_child(collider);game.add_child(wall)
 wall.position=home+Vector3(0,3,-8);await physics_frame;await physics_frame
 var before:Vector3=p.position;var health:float=target.hp
 click_attack();await driver.advance(1,func(_dt):advance(30,false))
 check(p.position.distance_to(before)<.1 and target.hp==health and kit.mode.is_empty(),"Cover blocks dash selection and damage")
 wall.queue_free();await physics_frame;await physics_frame
 click_attack();await driver.advance(1,func(_dt):advance(4,false))
 game.army_runtime.clear();game.model.enemies.clear();await driver.advance(1,func(_dt):advance(2,false))
 check(not kit.is_attacking() and not kit.state.get("approach_dashing",false),"Losing the enemy clears the dash without an attack")
 var nodes=0;var resources=0.0
 for i in 35:
  kit.cancel(true);p.position=home;p.velocity=Vector3.ZERO;p.impact_pause=0
  if i==5:nodes=get_node_count();resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  kit.begin_primary_approach(null,Vector3.FORWARD)
  check(kit.move_toward_primary_target(Vector3.FORWARD*30,Vector3.FORWARD,DT),"Repeated dash reuses the movement contract")
  kit.cancel(true)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Thirty warmed dash starts retain no nodes or resources")
 game.show_equipment_hub(true);await frames(2)
 var hub=game.equipment_hub;hub.show_page("accessories");hub.selected_slot="accessory:1";hub.selected_item="accessory:dash-boots";hub.equip_selected()
 check(hub.collection.has("accessory:dash-boots") and hub.accessory_buttons["accessory:1"].get_node("GearIcon").texture==Gear.ITEMS["accessory:dash-boots"].icon,"The existing Accessories page offers and equips Dash Boots")
 await dash_picture("equipped-dash-boots");game.back_from_equipment();p.set_physics_process(false);game.set_physics_process(false)

func ranged_boots(character:int,weapon:String):
 game.settings.gear_loadouts={};await settle(character)
 if character==37:game.select_shin_skin(37,900050)
 var p=game.player;var kit=p.active_ability
 p.timed_dodge.shadow_counter_enabled=false;dash_equipment(character,true,weapon)
 var target=place_target(18);await aim_sword(target)
 var start:Vector3=p.position;shots.clear();click_attack()
 await driver.advance(1,func(_dt):
  for i in 220:
   advance(1,false)
   for shot in shots:
    if shot.pool_live:shot._physics_process(DT))
 check(p.position.distance_to(start)<.1 and target.hp<target.max_hp and not kit.state.get("approach_dashing",false),"Dash Boots preserve ranged position and projectiles for "+weapon)
 for shot in shots:
  if shot.pool_live:shot.retire()

func run():
 create_timer(240).timeout.connect(func():printerr("DASH_BOOTS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(DASH_OUT);root.size=Vector2i(1280,800)
 check(Gear.ITEMS["accessory:dash-boots"].icon.resource_path.ends_with("/21903.png"),"Dash Boots use the selected original graphic 21903")
 check(is_equal_approx(preload("res://scripts/crossgate_combat.gd").PRIMARY_DASH_SPEED,preload("res://scripts/crossgate_combat.gd").PRIMARY_RUSH_SPEED*1.5),"Equipped dash is 50% faster than the previous dash and ordinary final rush")
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
 game.camera_rig.set_process_input(false);game.camera_rig.set_process_unhandled_input(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.music.stop();game.settings.forest_pet_loadout=[];game.settings.gear_loadouts={}
 game.model.waves.crossgate_pet_test=true;game.model.waves.patrol_posts.clear();game.training_dummy.position=home+Vector3.DOWN*1000
 root.gui_release_focus();driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 preload("res://scripts/character_projectile_pool.gd").service(game).launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 for character in game.player.RogueRoster.CROSSGATE:await boots_case(character)
 await boots_edges()
 for setup in [[43,"bow"],[36,"kunai"],[37,"boomerang"]]:await ranged_boots(setup[0],setup[1])
 print("DASH_BOOTS_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();current_scene=null;await frames(3)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
