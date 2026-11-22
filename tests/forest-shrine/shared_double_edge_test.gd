extends "res://tests/forest-shrine/skill_weapon_requirements_test.gd"
const REVIEW="res://build/Other Files/Asset Toolkit/Shared Double Edge/"

func planted():
 super.planted()
 game.player.mana=game.player.max_mana
 game.player.velocity=Vector3.DOWN*30;game.player.move_and_slide()

func review_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();game.army_runtime.flush_presentation();game.crowd.army.presentation.draw_effects()
 await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(REVIEW+stem+".png")==OK,"Captured "+stem)

func run():
 create_timer(240).timeout.connect(func():printerr("SHARED_DOUBLE_EDGE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(REVIEW);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false
 game.begin_arena();game.choose_rogue_character(37);await frames(3)
 var hub=game.equipment_hub;hub.show_page("skills")
 check(hub.collection.has("skill:"+Catalog.DOUBLE_EDGE),"諸刃 has its own shared inventory entry")
 hub.selected_item="skill:"+Catalog.DOUBLE_EDGE;hub.equip_selected()
 check(hub.skill_buttons.equip.get_node("GearIcon").texture==Catalog.KAZI_ICONS[Catalog.DOUBLE_EDGE],"諸刃 reuses its original icon")
 check(Catalog.valid_loadouts(hub.spell_draft)==hub.spell_draft,"Independent skill survives loadout validation")
 await review_picture("inventory")
 hub.enter_map();await frames(3)
 var p=game.player;var army=game.army_runtime;var fx=game.crowd.army.presentation
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05
 var floor_=StaticBody3D.new();floor_.collision_layer=1
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(30,1,30);shape.shape=box;floor_.add_child(shape);game.add_child(floor_);floor_.position=home+Vector3.DOWN*.55
 await physics_frame;await physics_frame
 game.model.update_vision(home);game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000;game.training_dummy.home=game.training_dummy.position
 game.camera_rig.camera.global_position=home+Vector3(8,7,15);game.camera_rig.camera.look_at(home+Vector3(0,2,-4))
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):weapon_shots.append(shot);shot.set_physics_process(false))
 game.impact_confirmed.connect(func(target,_strength,_time):weapon_hits.append(target))
 for character in Catalog.Roster.CROSSGATE:
  if character in [34,36]:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE if character==36 else preload("res://scripts/kaz_skins.gd").DEFAULT
  p.select_character(character);p.set_auto_attack(false);game.update_character_tuning(character,"critical_chance",0)
  p.spell_loadout.equip(character,"equip",Catalog.DOUBLE_EDGE)
  p.spell_loadout.equip(character,"surge",Catalog.SURE_STRIKE)
  for weapon in Gear.allowed(character,game.settings):
   equip_weapon(character,weapon)
   for level_ in [1,30]:
    planted();p.double_edge_left=0;weapon_shots.clear();weapon_hits.clear();army.clear();game.model.enemies.clear();army.refresh_kits();fx.effects.clear()
    var direction:Vector3=game.attack_direction()
    var at=home+direction*1.6;at.y=game.model.surface_height(at.x,at.z)
    var row=game.model.waves.spawn_enemy(Roles.SLIME,at);row.hp=1000000;row.max_hp=row.hp
    army.import_arrivals();army.sync_targets()
    var target=army.enemy_target(row.id);var before:float=target.hp
    Skills.set_level(p,Catalog.DOUBLE_EDGE,level_)
    check(p.is_on_floor(),"Fixture starts planted on a collision floor")
    press_skill()
    var charged:Dictionary=p.active_ability.ticket
    check(charged.get("skill_id")==Catalog.DOUBLE_EDGE and charged.get("skill_level")==level_,"%d %s Lv%d casts independent 諸刃"%[character,weapon,level_])
    check(is_equal_approx(p.double_edge_left,10) and is_equal_approx(p.double_edge_penalty,.10 if level_==1 else .39),"Current weapon retains the exact defense penalty")
    check(not p.spell_loadout.instances.has("%d:%s"%[character,Catalog.DOUBLE_EDGE]),"Existing fighter controller owns the skill without a donor")
    check(p.spell_loadout.cooldown_for("equip")==5 and p.spell_loadout.cooldown_for("surge")==0,"諸刃 starts only its own five-second cooldown")
    for tick in 240:
     p.active_ability.tick(DT)
     for shot in weapon_shots:
      if shot.pool_live:shot._physics_process(DT)
     army.flush_presentation()
    var pattern:Dictionary=p.model.normal_attack_pattern()
    var expected=Skills.normal_damage(p)*float(charged.get("skill_rules",{}).get("damage",0))*p.damage_multiplier()*pattern.contacts.size()
    if weapon=="kunai":
     var per_shot=expected/int(pattern.projectiles)
     check(weapon_shots.size()==int(pattern.projectiles) and weapon_hits.size()>0 and weapon_shots.all(func(shot):return is_equal_approx(shot.damage,per_shot)),"Kunai preserve their original volley and exact per-projectile skill damage")
     expected=per_shot*weapon_hits.size()
    check(is_equal_approx(before-target.hp,expected),"%d %s Lv%d native contacts deal exact 諸刃 damage (%s / %s)"%[character,weapon,level_,before-target.hp,expected])
    check(fx.effects.any(func(effect):return effect.kind=="shin_double_edge"),"Confirmed contacts reuse 諸刃 feedback")
    game.forest_ui.sync()
    check(not game.forest_ui.loadout_buttons[0].disabled and "any weapon" in game.forest_ui.loadout_buttons[0].tooltip_text,"HUD keeps 諸刃 unlocked with accurate help")
    if character==37 and weapon=="sword" and level_==30:
     p.model.show_pose(5,float(pattern.contacts[0]),false);await review_picture("sword-double-edge")
    for shot in weapon_shots:
     if shot.pool_live:shot.retire()
    p.active_ability.tick_timers(1.0);p.active_ability.cancel(true);p.attack_chain.reset();p.double_edge_left=0
    p.spell_loadout.number_input(2,true);p.spell_loadout.number_input(2,false)
    check(p.active_ability.ticket.get("skill_id")==Catalog.SURE_STRIKE and p.double_edge_left==0,"Equipped 乾坤 stays distinct even with a polearm")
    check(p.spell_loadout.cooldown_for("surge")==5 and p.spell_loadout.cooldown_for("equip")==4,"乾坤 casts while 諸刃 cools down without changing its timer")
    p.active_ability.cancel(true)
    p.active_ability.tick_timers(4.0);game.forest_ui.sync()
    check(p.spell_loadout.cooldown_for("equip")==0 and game.forest_ui.loadout_cooldowns[0].text!="1.0s" and game.forest_ui.loadout_cooldowns[1].text=="1.0s","諸刃 becomes ready while 乾坤 retains its own HUD countdown")
    press_skill()
    check(p.active_ability.is_attacking() and p.active_ability.ticket.get("skill_id")==Catalog.DOUBLE_EDGE and p.spell_loadout.cooldown_for("equip")==5 and p.spell_loadout.cooldown_for("surge")==1,"諸刃 casts while 乾坤 cools down without changing its timer")
    if character==37 and weapon=="sword" and level_==30:await review_picture("independent-cooldowns")
    p.active_ability.cancel(true);press_skill()
    p.spell_loadout.number_input(2,true);p.spell_loadout.number_input(2,false)
    check(not p.active_ability.is_attacking(),"Each skill rejects another cast during its own cooldown")
    p.active_ability.tick_timers(1.0)
    p.spell_loadout.number_input(2,true);p.spell_loadout.number_input(2,false)
    check(p.active_ability.is_attacking() and p.spell_loadout.cooldown_for("equip")==4 and p.spell_loadout.cooldown_for("surge")==5,"乾坤 becomes ready independently of the refreshed 諸刃 cooldown")
    p.active_ability.cancel(true);p.active_ability.clear_cooldowns()
    check(p.spell_loadout.cooldown_for("equip")==0 and p.spell_loadout.cooldown_for("surge")==0,"The existing cooldown reset clears both independent timers")
 await frames(3)
 p.select_character(37);equip_weapon(37,"sword");planted()
 p.spell_loadout.equip(37,"surge","kazi/qigong");game.forest_ui.sync()
 check(game.forest_ui.helper_portraits[1].texture==Catalog.KAZI_ICONS["kazi/qigong"] and Catalog.KAZI_ICONS[Catalog.MAZE_QI]==Catalog.KAZI_ICONS["kazi/qigong"],"Both Qi routes share the updated inventory/hotbar icon")
 press_skill();p.active_ability.cancel(true);await frames(3)
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for repeat in 40:
  planted();press_skill();p.active_ability.tick(.1);p.active_ability.cancel(true)
 await frames(3)
 var final_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var final_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 check(final_nodes<=nodes and final_resources<=resources,"Forty warmed casts retain no extra nodes or resources (%d/%d nodes, %d/%d resources)"%[final_nodes,nodes,final_resources,resources])
 await review_picture("qi-and-double-edge-hotbar")
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SHARED_DOUBLE_EDGE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
