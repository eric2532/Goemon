extends "res://tests/forest-shrine/equipment_hub_test.gd"
const WEAPON_OUT="res://build/Other Files/Asset Toolkit/Cross Gate Weapon Inventory/"
var weapon_shots:Array=[]
var weapon_hits:Array=[]

func weapon_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(WEAPON_OUT+stem+".png")==OK,"Rendered "+stem)

func choose_skin(character:int,skin:int):
 if character==34:game.select_kaz_skin(skin)
 elif character==Gear.Roster.MAZE_ID:game.select_kaz_skin(preload("res://scripts/kaz_skins.gd").MAZE)
 elif Gear.Roster.is_shin(character):game.select_shin_skin(character,skin)
 elif Gear.Roster.has_variant_skins(character):game.select_crossgate_skin(character,skin)

func equip_weapon(character:int,weapon:String,slot:String="1"):
 var draft=game.settings.gear_loadouts.duplicate(true)
 draft[Gear.character_key(character)]={slot:"weapon:"+weapon}
 check(game.save_equipment_loadouts(draft,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Save/equip %d %s"%[character,weapon])

func attack_case(character:int,weapon:String):
 var p=game.player;var kit=p.active_ability;var army=game.army_runtime
 kit.cancel();p.attack_chain.reset();p.velocity=Vector3.ZERO;p.position=home;p.impact_pause=0
 p.set_auto_attack(false);game.update_character_tuning(character,"critical_chance",0)
 army.clear();game.model.enemies.clear();army.refresh_kits();game.model.update_vision(home)
 game.enemies=game.enemies.filter(func(enemy):return is_instance_valid(enemy) and not enemy.is_queued_for_deletion())
 var direction:Vector3=game.attack_direction()
 var at=home+direction*(8.0 if weapon in ["kunai","boomerang","water-dragon-boomerang","beast-master"] else 1.6);at.y=game.model.surface_height(at.x,at.z)
 var row=game.model.waves.spawn_enemy(Roles.SLIME,at);row.hp=1000000;row.max_hp=row.hp
 army.import_arrivals();army.sync_targets()
 var target=army.enemy_target(row.id);var before:float=target.hp
 weapon_shots.clear();weapon_hits.clear()
 kit.start_attack()
 var pattern:Dictionary=p.model.normal_attack_pattern()
 var rate:float=p.attack_speed_multiplier()
 if weapon=="bow":
  var attack:Dictionary=p.model.motions.clips["5:%d"%p.model.direction()]
  kit.tick(maxf(0,attack.release-.001)/rate)
  check(weapon_shots.is_empty() and target.hp==before,"Bow windup cannot release or damage before its source frame")
  kit.tick(.002/rate)
  check(weapon_shots.size()==1,"The source release frame emits exactly one arrow")
 var ticks=ceili(float(pattern.duration)/rate/DT)+3
 for i in ticks:
  kit.tick(DT)
  for shot in weapon_shots:
   if shot.pool_live:shot._physics_process(DT)
 for i in 120:
  for shot in weapon_shots:
   if shot.pool_live:shot._physics_process(DT)
 var expected=pattern.contacts.size()
 var actual=before-float(target.hp)
 var multiplier:float=p.base_character_attack_multiplier() if weapon=="beast-master" else p.damage_multiplier()
 var damage=Skills.basic_damage(pattern)*multiplier*expected*int(pattern.projectiles)
 print("WEAPON_ATTACK character=",character," weapon=",weapon," contacts=",expected," hits=",weapon_hits.size()," damage=",actual," expected=",damage)
 check(is_equal_approx(actual,damage),"%d %s deals exactly its source-contact damage"%[character,weapon])
 if weapon=="bow":check(weapon_shots.size()==1 and is_zero_approx(p.melee_strike_reach()),"Bow releases one real arrow with no melee outline")
 elif weapon=="kunai":check(weapon_shots.size()==int(p.model.fighter.get("kunai_count",1)) and is_zero_approx(p.melee_strike_reach()),"Kunai keeps its original projectile count with no melee outline")
 elif weapon in ["boomerang","water-dragon-boomerang"]:check(weapon_shots.size()==1 and is_zero_approx(p.melee_strike_reach()),"Boomerang releases one curved projectile with no melee outline")
 elif weapon=="beast-master":check(weapon_shots.size()==1 and is_zero_approx(p.melee_strike_reach()),"Beast Master releases one dagger with no melee outline")
 else:check(weapon_shots.is_empty(),"Melee weapon cannot leak arrows or kunai")
 for shot in weapon_shots:
  if shot.pool_live:shot.retire()
 kit.cancel(true)

func run():
 create_timer(900).timeout.connect(func():printerr("WEAPON_EQUIPMENT_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(WEAPON_OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false
 game.save_settings()
 var p=game.player
 game.begin_arena();game.choose_rogue_character(34);await frames(3)
 var hub=game.equipment_hub;var saved_hash=FileAccess.get_sha256(cfg)
 check(hub.available_items()==["weapon:sword","weapon:beast-master"] and hub.allowed_icons.filter(func(icon):return icon.visible).size()==2 and hub.allowed_icons[0].accessibility_name=="Sword" and hub.allowed_icons[0].tooltip_text.is_empty(),"Original Kaz displays the Sword and Beast Master icons beneath his feet")
 hub.selected_item="weapon:bow";hub.equip_selected()
 check(hub.draft.is_empty(),"A forged bow selection cannot equip Original Kaz with a bow")
 check(not game.save_equipment_loadouts({Gear.character_key(34):{"1":"weapon:kunai"}},{},{}),"The save boundary rejects weapons unsupported by every outfit on that identity")
 check(not game.save_equipment_loadouts({Gear.pet_key(Pets.key(0)):{"1":"weapon:sword"}},{},{}),"Pets keep their native attacks instead of accepting character weapons")
 await weapon_picture("kaz-sword-and-beast-master")
 var copies=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 var copy=copies.make_body(34,true)
 hub.select_skin(105608)
 check(hub.available_items()==["weapon:sword","weapon:three-weapon","weapon:axe","weapon:polearm","weapon:bow","weapon:staff","weapon:unarmed","weapon:boomerang","weapon:beast-master"],"Red Hair / Black offers its matching poses, native boomerang, Three-Weapon Combo and Beast Master")
 hub.auto_equip(hub.available_items().find("weapon:bow"))
 check(p.model.appearance.key=="joy-ex:419" and p.model.current_weapon()=="bow","The bow uses Kaz's red/black source record even though other outfits share its ID")
 copies.prepare_loadout();copy.activate()
 check(copy.model.appearance.key=="joy-ex:419" and copy.model.current_weapon()=="bow","A pooled copy keeps the matching weapon after a Kaz outfit change")
 copies.dispose()
 hub.select_skin(102488)
 check(p.model.appearance.key=="ex:1727" and p.model.current_weapon()=="sword" and Gear.equipped(game.settings.gear_loadouts,34)=="weapon:bow","Original Kaz falls back to his sword while retaining the saved bow")
 hub.select_skin(105608)
 check(p.model.appearance.key=="joy-ex:419","Returning to Red Hair / Black restores the saved bow")
 hub.unequip();hub.select_skin(102488)
 saved_hash=FileAccess.get_sha256(cfg)
 p.select_character(43);hub.refresh_party()
 var lancelot_weapons=hub.available_items()
 check("weapon:beast-master" in lancelot_weapons and hub.allowed_icons.filter(func(icon):return icon.visible).size()==lancelot_weapons.size(),"Lancelot exposes every available weapon icon, including Beast Master")
 hub.auto_equip(hub.available_items().find("weapon:sword"))
 check(hub.draft[Gear.character_key(43)]["1"]=="weapon:sword" and FileAccess.get_sha256(cfg)!=saved_hash and game.settings.gear_loadouts==hub.draft,"Weapon choice saves immediately")
 hub.select_slot("2");hub.selected_item="weapon:axe";hub.equip_selected()
 check(hub.draft[Gear.character_key(43)]["1"]=="weapon:axe" and not hub.draft[Gear.character_key(43)].has("2"),"A locked slot cannot be selected; the weapon replaces the unlocked slot")
 hub.select_slot("1");hub.selected_item="weapon:sword";hub.equip_selected()
 await weapon_picture("lancelot-weapon-choices")
 await click(hub.enter_button);await frames(3)
 check(game.playing and p.model.gear_weapon=="sword" and p.model.gear_external and p.model.fighter.strike=="timed","Enter Map applies Lancelot's sword sprites and melee owner")
 check(not p.model.native_skills.values().any(func(slot):return slot[1] in ["start_random_shot","start_shadow_mirrors"]),"Equipping melee removes archer-only native shortcuts")
 game.load_settings()
 check(Gear.equipped(game.settings.gear_loadouts,43)=="weapon:sword","The chosen weapon survives save/reload")
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05;p.position=home
 game.model.update_vision(home);game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 game.camera_rig.camera.global_position=home+Vector3(8,7,15);game.camera_rig.camera.look_at(home+Vector3(0,2,-4))
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):weapon_shots.append(shot);shot.set_physics_process(false))
 game.impact_confirmed.connect(func(target,_strength,_time):weapon_hits.append(target))
 attack_case(43,"sword")
 var pose:Dictionary=p.model.motions.clips["5:4"]
 p.model.show_frame(5,"5:4",roundi(float(pose.contact)*pose.frames.size()))
 await weapon_picture("lancelot-native-sword-contact")
 var appearances=0;var combinations=0
 for character in Gear.Roster.CROSSGATE:
  p.select_character(character)
  var first_skin=Gear.Roster.selected_skin(character,game.settings)
  for skin_key in Gear.catalog()[str(character)]:
   choose_skin(character,int(skin_key));appearances+=1
   var choices=Gear.allowed(character,game.settings)
   for weapon in choices:
    equip_weapon(character,weapon);combinations+=1
    check(p.model.gear_weapon==weapon,"Equipment selects the requested weapon on the same character")
    var route:Dictionary=choices[weapon]
    if route.has("root"):check(p.model.gear_external and p.model.appearance==p.model.profile(route.root),"The weapon uses its own recovered source animation set")
    var pattern:Dictionary=p.model.normal_attack_pattern()
    check(not pattern.contacts.is_empty() and pattern.duration>0 and pattern.contacts.all(func(at):return at>=0 and at<pattern.duration),"The active attack has valid native contact/release times")
    var attack_pose:int=int(pattern.pose) if weapon=="beast-master" else 5
    for direction in range(8):
     var key="%d:%d"%[attack_pose,direction];var motion:Dictionary=p.model.body_clip(attack_pose,key)
     p.model.show_frame(attack_pose,key,0)
     check(p.model.sprite.region_rect.size==Vector2(motion.frames[0][3],motion.frames[0][4]),"Weapon drawing and source atlas dimensions agree in every direction")
    if route.has("native") or int(skin_key)==first_skin or (character==38 and int(skin_key)==120440) or (character==42 and int(skin_key)==106275):
     attack_case(character,weapon)
     var key="%d:4"%attack_pose;var attack:Dictionary=p.model.body_clip(attack_pose,key)
     p.model.show_frame(attack_pose,key,clampi(floori(float(attack.get("release",attack.duration*attack.get("contact",.5)))/float(attack.duration)*attack.frames.size()),0,attack.frames.size()-1))
     await weapon_picture("poses/%d-%s-%s"%[character,skin_key,weapon])
   await frames()
  choose_skin(character,first_skin)
 var expected_appearances=0
 for skins in Gear.catalog().values():expected_appearances+=skins.size()
 check(appearances==expected_appearances and combinations>1000,"Every current Cross Gate appearance and available weapon is covered")
 p.select_character(43);game.select_crossgate_skin(43,106125);equip_weapon(43,"bow")
 p.swap_weapon();check(p.model.gear_weapon!="bow" and Gear.equipped(game.settings.gear_loadouts,43)=="weapon:"+p.model.gear_weapon,"Cycling selects and saves the allowed equipped weapons")
 var draft=game.settings.gear_loadouts.duplicate(true);draft.erase(Gear.character_key(43))
 check(game.save_equipment_loadouts(draft,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts) and p.model.gear_weapon.is_empty() and p.model.fighter.strike=="bow" and p.model.native_skills.equip[1]=="start_random_shot","Unequip restores the original bow and archer shortcuts")
 p.select_character(36);choose_skin(36,0)
 var native_weapon=Gear.default_weapon(36,game.settings)
 equip_weapon(36,"unarmed");draft=game.settings.gear_loadouts.duplicate(true);draft.erase(Gear.character_key(36))
 check(game.save_equipment_loadouts(draft,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts) and p.model.gear_weapon.is_empty() and p.model.maze_weapon==int(Gear.allowed(36,game.settings)[native_weapon].native),"Unequip restores Maze's saved native stance")
 p.select_character(34);game.select_kaz_skin(102488);equip_weapon(34,"sword")
 p.swap_weapon();check(p.model.gear_weapon=="beast-master","Original Kaz cycles from Sword to Beast Master")
 p.swap_weapon();check(p.model.gear_weapon=="sword","Original Kaz cycles from Beast Master back to Sword")
 p.select_character(42);game.select_crossgate_skin(42,106275);equip_weapon(42,"bow")
 game.select_crossgate_skin(42,120387)
 check(p.model.gear_weapon.is_empty() and p.model.fighter.strike=="staff" and Gear.equipped(game.settings.gear_loadouts,42)=="weapon:bow","An incompatible outfit safely uses its native weapon while preserving the saved choice")
 game.select_crossgate_skin(42,106275);check(p.model.gear_weapon=="bow","Returning to a compatible outfit restores its saved weapon")
 p.select_character(43);equip_weapon(43,"sword")
 check(game.unlock_weapon_slot(Gear.character_key(43)),"A reward can open the next Lancelot weapon slot")
 var carried={Gear.character_key(43):{"1":"weapon:sword","2":"weapon:bow","active_weapon":"1"}}
 check(game.save_equipment_loadouts(carried,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Two compatible weapons can occupy distinct unlocked slots")
 p.swap_weapon()
 check(p.model.gear_weapon=="bow" and game.settings.gear_loadouts[Gear.character_key(43)]["1"]=="weapon:sword","Cycling switches the active carried weapon without replacing the other slot")
 p.swap_weapon();check(p.model.gear_weapon=="sword","Cycling carried weapons returns to the first weapon")
 game.load_settings();check(Gear.equipped(game.settings.gear_loadouts,43)=="weapon:sword" and game.settings.gear_loadouts[Gear.character_key(43)]["2"]=="weapon:bow","Multiple carried weapons and active selection survive reload")
 attack_case(43,"sword")
 await frames(3)
 var nodes=get_node_count();var created=pool.created
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 20:
  p.active_ability.cancel(true);p.attack_chain.reset();p.active_ability.start_attack()
  for tick in 100:p.active_ability.tick(DT)
 check(get_node_count()==nodes and pool.created==created and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated equipped melee attacks reuse the existing owner and warmed resources")
 game.show_equipment_hub();await frames(3);hub=game.equipment_hub
 for dimensions in [Vector2i(1280,800),Vector2i(960,640)]:
  root.size=dimensions;await frames(3)
  check(root.get_visible_rect().encloses(hub.panel.get_global_rect()),"The weapon selector fits the window")
  await weapon_picture("weapon-grid-%dx%d"%[dimensions.x,dimensions.y])
 game.queue_free();current_scene=null;paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("WEAPON_EQUIPMENT_RESULT appearances=%d combinations=%d checks=%d failures=%d"%[appearances,combinations,checks,failures]);quit(1 if failures else 0)
