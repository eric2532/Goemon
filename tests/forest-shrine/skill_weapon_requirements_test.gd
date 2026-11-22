extends "res://tests/forest-shrine/weapon_equipment_test.gd"
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const REQUIREMENTS_OUT="res://build/Other Files/Asset Toolkit/Skill Weapon Requirements/"

func press_skill():
 game.player.spell_loadout.number_input(1,true)
 game.player.spell_loadout.number_input(1,false)

func planted():
 var p=game.player
 p.active_ability.cancel(true);p.active_ability.clear_cooldowns();p.attack_chain.reset()
 p.position=home;p.velocity=Vector3.DOWN;p.move_and_slide()
 p.dodge_time=0;p.impact_pause=0;game.hit_stop=0

func lock_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(REQUIREMENTS_OUT+stem+".png")==OK,"Captured skill lock feedback: "+stem)

func run():
 create_timer(240).timeout.connect(func():printerr("SKILL_WEAPON_REQUIREMENTS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(REQUIREMENTS_OUT);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false
 game.begin_arena();game.choose_rogue_character(43);await frames(3)
 var hub=game.equipment_hub
 hub.show_page("skills")
 check(hub.collection.has("skill:"+Catalog.RANDOM_SHOT),"亂射 is available in the shared skill collection")
 hub.selected_item="skill:"+Catalog.RANDOM_SHOT;hub.equip_selected()
 check(hub.item_data(hub.selected_item).description.begins_with("Requires an active Bow."),"Inventory explains the active bow requirement")
 if DisplayServer.get_name()!="headless":
  await frames(3);await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(REQUIREMENTS_OUT+"bow-requirement.png")==OK,"Captured bow requirement in the skill inventory")
 hub.enter_map();await frames(3)
 var p=game.player;var army=game.army_runtime
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home);game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 army.clear();game.model.enemies.clear();army.refresh_kits()
 var at=home+Vector3.FORWARD*8;at.y=game.model.surface_height(at.x,at.z)
 var row=game.model.waves.spawn_enemy(Roles.SLIME,at);row.hp=1000000;row.max_hp=row.hp
 army.import_arrivals();army.sync_targets()
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):weapon_shots.append(shot);shot.set_physics_process(false))
 # Every currently selected Cross Gate appearance uses the same active-weapon rule.
 for character in Catalog.Roster.CROSSGATE:
  if character in [34,36]:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE if character==36 else preload("res://scripts/kaz_skins.gd").DEFAULT
  p.select_character(character);await frames(1)
  check(p.spell_loadout.equip(character,"equip",Catalog.RANDOM_SHOT),"Fighter %d can retain a bow skill assignment"%character)
  check(p.spell_loadout.equip(character,"surge",Catalog.COUNTER) and p.spell_loadout.equip(character,"special_5",Catalog.BARRAGE_SHADOWS) and p.spell_loadout.equip(character,"special_6",Catalog.KAGEROU),"Equip weapon-specific and unrestricted skills for lock feedback")
  for weapon in Gear.allowed(character,game.settings):
   equip_weapon(character,weapon);planted();weapon_shots.clear()
   check(p.model.current_weapon()==weapon,"Fighter %d identifies active %s"%[character,weapon])
   check(Catalog.weapon_compatible(Catalog.all()[Catalog.RANDOM_SHOT],p.model)==(weapon=="bow"),"Only an active bow satisfies 亂射")
   game.forest_ui.sync()
   check(not game.forest_ui.loadout_buttons[5].disabled and game.forest_ui.helper_portraits[5].modulate==Color.WHITE,"An unrestricted skill stays available with every weapon")
   for entry in [[0,Catalog.RANDOM_SHOT],[1,Catalog.COUNTER],[4,Catalog.BARRAGE_SHADOWS]]:
    var index:int=entry[0];var locked=not Catalog.weapon_compatible(Catalog.all()[entry[1]],p.model)
    var ui=game.forest_ui
    check(ui.loadout_buttons[index].disabled==locked,"Weapon-specific skill button follows active weapon: "+entry[1])
    check((ui.loadout_cooldowns[index].text=="Locked")==locked and (ui.helper_portraits[index].modulate.a<1.0)==locked,"Locked skill has a visible label and dimmed icon")
    check(("Locked · Requires an active" in ui.loadout_buttons[index].tooltip_text)==locked,"Locked skill tooltip explains its weapon and clears on unlock")
   press_skill()
   if weapon=="bow":
    check(p.is_on_floor() and p.active_ability.ticket.get("action")=="lancelot_random_shot","Fighter %d starts 亂射 with the equipped bow"%character)
    check(p.active_ability.ticket.get("skill_id")==Catalog.RANDOM_SHOT,"Borrowed bow keeps the shared skill's level and tuning")
    for i in 600:
     p.active_ability.tick(DT)
     if not p.active_ability.is_attacking():break
    check(weapon_shots.size()==3 and not p.active_ability.is_attacking(),"Level-one 亂射 releases exactly three arrows and finishes")
   else:
    check(not p.active_ability.is_attacking() and p.active_ability.random_shot_cooldown==0 and weapon_shots.is_empty(),"Incompatible weapon cannot cast, release arrows or spend cooldown")
    p.active_ability.start_random_shot();p.active_ability.start_shadow_mirrors()
    check(not p.active_ability.is_attacking() and p.active_ability.random_shot_cooldown==0 and p.active_ability.mirror_cooldown==0,"Native bow entry points also reject an incompatible weapon")
   for shot in weapon_shots:
    if shot.pool_live:shot.retire()
   p.active_ability.cancel(true)
  check(p.spell_loadout.spell_for(character,"equip")==Catalog.RANDOM_SHOT,"Weapon changes preserve the assigned skill")
 p.select_character(43);planted()
 game.settings.weapon_slot_unlocks[Gear.character_key(43)]=2
 var carried={Gear.character_key(43):{"1":"weapon:sword","2":"weapon:bow","active_weapon":"1"}}
 check(game.save_equipment_loadouts(carried,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Carry sword and bow in separate unlocked slots")
 planted();press_skill();game.forest_ui.sync()
 check(game.forest_ui.loadout_buttons[0].disabled,"Carried inactive Bow leaves its skill visibly locked")
 await lock_picture("sword-locks-bow-and-spear")
 check(not p.active_ability.is_attacking() and p.active_ability.random_shot_cooldown==0,"Carrying an inactive bow does not permit 亂射")
 p.swap_weapon();planted();press_skill()
 check(p.model.current_weapon()=="bow" and p.active_ability.is_attacking() and p.spell_loadout.cooldown_for("equip")>0,"Z activates the bow and enables 亂射 with its normal cooldown")
 game.forest_ui.sync()
 check(not game.forest_ui.loadout_buttons[0].disabled and game.forest_ui.loadout_buttons[1].disabled,"Z unlocks Bow skills while keeping Counter locked")
 await lock_picture("bow-unlocks-bow-skills")
 p.active_ability.cancel(true);p.swap_weapon();planted();press_skill()
 check(p.model.current_weapon()=="sword" and not p.active_ability.is_attacking(),"Swapping back to sword blocks the same assigned skill again")
 for weapon in ["sword","polearm"]:
  p.select_character(37);equip_weapon(37,weapon);planted()
  p.spell_loadout.equip(37,"surge",Catalog.COUNTER)
  check(p.active_ability.shin_counter_armed==(weapon=="polearm"),"Counter requires the active spear")
  planted();p.active_ability.clear_shin_counter();p.active_ability.start_shin_area_cast(true)
  check(p.active_ability.is_attacking()==(weapon=="polearm"),"一石二鳥 requires the active spear")
 game.settings.weapon_slot_unlocks[Gear.character_key(37)]=2
 carried={Gear.character_key(37):{"1":"weapon:sword","2":"weapon:polearm","active_weapon":"1"}}
 check(game.save_equipment_loadouts(carried,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Carry sword and spear in unlocked slots")
 check(not p.active_ability.shin_counter_armed,"An inactive carried spear cannot enable passive Counter")
 p.swap_weapon()
 check(p.model.current_weapon()=="polearm" and p.active_ability.shin_counter_armed and not p.active_ability.is_attacking(),"Z enables passive Counter immediately without an arming cast")
 game.forest_ui.sync()
 check(game.forest_ui.loadout_cooldowns[1].text=="Passive" and "Always active" in game.forest_ui.loadout_buttons[1].tooltip_text,"HUD explains passive Counter")
 p.active_ability.counter_after_hit(Vector3.BACK,row.id)
 p.swap_weapon()
 check(not p.active_ability.shin_counter_armed and p.active_ability.shin_counter.is_empty() and p.active_ability.shin_counter_pending.is_empty() and not p.model.shin_counter_fx.visible,"Switching away clears pending counters and their effect")
 p.swap_weapon()
 check(p.active_ability.shin_counter_armed,"Switching back restores Counter without a key press")
 p.active_ability.cancel()
 check(p.active_ability.shin_counter_armed,"Combat interruption cannot turn off passive Counter")
 p.spell_loadout.equip(37,"surge","")
 check(not p.active_ability.shin_counter_armed,"Removing the equipped skill disables Counter")
 game.forest_ui.sync()
 check(game.forest_ui.loadout_buttons[1].disabled and game.forest_ui.loadout_cooldowns[1].text!="Locked" and not game.forest_ui.helper_portraits[1].visible,"Removing Counter restores an empty slot without stale lock feedback")
 p.select_character(36)
 for weapon in ["unarmed","kunai","sword"]:
  equip_weapon(36,weapon);planted();p.active_ability.start_assassination(army.enemy_target(row.id))
  check(p.active_ability.assassinating()==(weapon=="sword"),"Assassination requires the active katana")
 p.active_ability.cancel(true)
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SKILL_WEAPON_REQUIREMENTS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
