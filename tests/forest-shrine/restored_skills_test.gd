extends "res://tests/forest-shrine/weapon_equipment_test.gd"
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const RESTORED_OUT="res://build/Other Files/Asset Toolkit/Restored Skills/"

func key(number:int):
 game.player.spell_loadout.number_input(number,true)
 game.player.spell_loadout.number_input(number,false)

func planted():
 var p=game.player
 p.active_ability.cancel(true);p.active_ability.clear_cooldowns();p.attack_chain.reset()
 p.position=home;p.velocity=Vector3.DOWN;p.move_and_slide()
 p.dodge_time=0;p.impact_pause=0;p.invuln=0;game.hit_stop=0

func capture_skill(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(RESTORED_OUT+stem+".png")==OK,"Captured "+stem)

func run():
 create_timer(240).timeout.connect(func():printerr("RESTORED_SKILLS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(RESTORED_OUT);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false
 game.begin_arena();game.choose_rogue_character(43);await frames(3)
 var p=game.player;var army=game.army_runtime;var hub=game.equipment_hub
 game.settings.weapon_slot_unlocks={Gear.character_key(43):2}
 hub.draft={Gear.character_key(43):{"1":"weapon:bow","2":"weapon:polearm"}}
 hub.show_page("skills")
 var original=FileAccess.get_sha256(cfg)
 for id in [Catalog.BARRAGE_SHADOWS,Catalog.COUNTER]:
  check(hub.collection.has("skill:"+id),"Restored skill is listed: "+id)
  hub.auto_equip(hub.collection.find("skill:"+id))
  check(hub.skill_icon(id)==Catalog.KAZI_ICONS[id],"Inventory uses the requested existing-art icon")
 var loadout_key=Catalog.Roster.loadout_key(43,game.settings)
 check(hub.spell_draft[loadout_key].equip==Catalog.BARRAGE_SHADOWS and hub.spell_draft[loadout_key].surge==Catalog.COUNTER,"Double-click fills chosen skill slots")
 check(FileAccess.get_sha256(cfg)!=original and game.settings.spell_loadouts[loadout_key]==hub.spell_draft[loadout_key],"Skill edits save immediately")
 for size_ in [Vector2i(1280,800),Vector2i(960,640)]:
  root.size=size_;await capture_skill("equipment-%dx%d"%[size_.x,size_.y])
 hub.enter_map();await frames(3);game.load_settings()
 check(p.spell_loadout.spell_for(43,"equip")==Catalog.BARRAGE_SHADOWS and p.spell_loadout.spell_for(43,"surge")==Catalog.COUNTER,"Both skills save and reload")
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home);game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 army.clear();game.model.enemies.clear();army.refresh_kits()
 var at=home+Vector3.FORWARD*8;at.y=game.model.surface_height(at.x,at.z)
 var row=game.model.waves.spawn_enemy(Roles.SLIME,at);row.hp=10000000;row.max_hp=row.hp
 army.import_arrivals();army.sync_targets()
 var enemy=army.enemy_target(row.id)
 army.apply_hit(enemy.handle,{"element":"ice","status_seconds":1000.0})
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):weapon_shots.append(shot);shot.set_physics_process(false))
 game.camera_rig.camera.global_position=home+Vector3(8,12,20);game.camera_rig.camera.look_at(home+Vector3(0,2,-4))
 for character in Catalog.Roster.CROSSGATE:
  if character in [34,36]:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE if character==36 else preload("res://scripts/kaz_skins.gd").DEFAULT
  p.select_character(character);await frames(1)
  check(p.spell_loadout.equip(character,"equip",Catalog.BARRAGE_SHADOWS) and p.spell_loadout.equip(character,"surge",Catalog.COUNTER),"Both skills equip on Cross Gate fighter %d"%character)
  check(not p.spell_loadout.instances.has("%d:%s"%[character,Catalog.BARRAGE_SHADOWS]) and not p.spell_loadout.instances.has("%d:%s"%[character,Catalog.COUNTER]),"Restored skills reuse the active combat owner")
  for weapon in Gear.allowed(character,game.settings):
   equip_weapon(character,weapon);planted()
   key(1)
   check((p.active_ability.mirror_cooldown>0)==(weapon=="bow"),"Barrage requires the active bow: %d %s"%[character,weapon])
   if weapon=="bow":
    var body=p.active_ability.mirrors.bodies[0]
    check(body.model.current_weapon()=="bow" and body.model.combo_glow!=null,"Borrowed bow shadows prepare the equipped source weapon and charge art")
    weapon_shots.clear()
    for i in 360:
     army.step(DT,{"targets":army.external_targets()})
     for shot in weapon_shots:
      if shot.pool_live:shot._physics_process(DT)
     game.crowd.army.presentation.tick(DT)
     if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(DT)
     if i%60==0:await physics_frame
    check(weapon_shots.size()>=3,"Borrowed bow shadows fire complete barrages through the native owner")
    for shot in weapon_shots:
     if shot.pool_live:shot.retire()
    weapon_shots.clear()
   if p.active_ability.mirrors!=null:p.active_ability.mirrors.clear()
   planted()
   check(p.active_ability.shin_counter_armed==(weapon=="polearm"),"Counter is passive only with the active spear: %d %s"%[character,weapon])
   key(2);key(2)
   check(p.active_ability.shin_counter_armed==(weapon=="polearm") and not p.active_ability.is_attacking(),"Counter key cannot toggle or start an arming animation")
   if weapon=="polearm":
    p.active_ability.counter_after_hit(Vector3.BACK,row.id)
    check(p.model.shin_counter_fx.visible and p.active_ability.shin_counter.ticket.skill_id==Catalog.COUNTER,"Equipped counter uses prepared effect and shared level")
    p.active_ability.clear_shin_counter()
   planted()
 p.select_character(37);equip_weapon(37,"bow");planted()
 Skills.set_level(p,Catalog.BARRAGE_SHADOWS,30);key(1)
 check(p.active_ability.mirrors.handles.size()==7,"Leveling a borrowed barrage prepares its larger shadow count")
 p.active_ability.mirrors.clear()
 p.select_character(43);equip_weapon(43,"bow");planted()
 Skills.set_level(p,Catalog.BARRAGE_SHADOWS,30);Skills.set_level(p,Catalog.RANDOM_SHOT,1)
 var kit=p.active_ability;var mirrors=kit.mirrors
 key(1)
 check(mirrors.handles.size()==7 and mirrors.left==30 and p.spell_loadout.cooldown_for("equip")==22,"Key 1 creates seven level-30 stationary shadows and starts the existing cooldown")
 var handles=mirrors.handles.duplicate();var bodies=mirrors.bodies.duplicate();var positions=bodies.map(func(body):return body.position)
 key(1);check(mirrors.handles==handles,"Cooldown blocks immediate recast")
 var health:float=enemy.hp
 for i in 360:
  army.step(DT,{"targets":army.external_targets()})
  for shot in weapon_shots:
   if shot.pool_live:shot._physics_process(DT)
  weapon_shots=weapon_shots.filter(func(shot):return shot.pool_live)
  game.crowd.army.presentation.tick(DT)
  if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(DT)
  if i%60==0:await physics_frame
 check(enemy.hp<health and bodies.all(func(body):return body.action_history.size()>0),"All seven shadows fire and damage a real native enemy")
 for i in bodies.size():check(Vector2(bodies[i].position.x-positions[i].x,bodies[i].position.z-positions[i].z).length()<.08,"Shadow stays at its summon point")
 root.size=Vector2i(1280,800);await capture_skill("seven-shadows")
 if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(2)
 await frames(3)
 var nodes=get_node_count();var created=pool.created;var misses=pool.misses
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat_ in 5:
  kit.clear_cooldowns();key(1)
  for i in 180:
   army.step(DT,{"targets":army.external_targets()})
   for shot in weapon_shots:
    if shot.pool_live:shot._physics_process(DT)
   weapon_shots=weapon_shots.filter(func(shot):return shot.pool_live)
   game.crowd.army.presentation.tick(DT)
   if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(DT)
 if is_instance_valid(game.native_ink_feedback):game.native_ink_feedback.tick(2)
 await frames(3)
 check(mirrors.bodies==bodies and get_node_count()==nodes and pool.created==created and pool.misses==misses,"Repeated seven-shadow casts reuse warmed bodies and arrows")
 check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated shadow casts do not grow warmed resources")
 print("RESTORED_POOL nodes=",nodes," after=",get_node_count()," created=",created," after=",pool.created," misses=",misses," after=",pool.misses)
 check(p.spell_loadout.equip(43,"equip","") and mirrors.handles.is_empty(),"Unequipping barrage retires its native shadows")
 for shot in weapon_shots:
  if shot.pool_live:shot.retire()
 home=enemy.global_position+Vector3.BACK*2;home.y=game.model.surface_height(home.x,home.z)+.05
 game.camera_rig.camera.global_position=home+Vector3(8,9,15);game.camera_rig.camera.look_at(home+Vector3(0,1,-2))
 p.select_character(37);equip_weapon(37,"polearm");planted()
 var before:float=p.hp;health=enemy.hp
 p.take_hit_from(5,Vector3.BACK,false,row.id)
 check(p.hp<before and p.active_ability.shin_counter.target==enemy and p.model.shin_counter_fx.visible,"Taking damage starts the original counter effect against its attacker")
 await capture_skill("counter-effect")
 for i in 120:p.active_ability.tick_shin_counter(DT)
 check(enemy.hp<health and p.active_ability.shin_counter_armed,"Counter damages its native attacker and remains armed")
 key(2);check(p.active_ability.shin_counter_armed,"The equipped key cannot switch the passive off")
 p.active_ability.cancel();check(p.active_ability.shin_counter_armed,"Combat cancellation leaves the passive ready")
 planted();p.spell_loadout.equip(37,"surge","")
 check(not p.active_ability.shin_counter_armed and p.spell_loadout.numbered_slots[1].is_empty(),"Unequipping counter disables the passive and clears its key")
 p.select_character(43);equip_weapon(43,"polearm");planted()
 var counter_fx=p.model.shin_counter_fx
 for repeat_ in 5:
  planted();key(2);health=enemy.hp;p.take_hit_from(2,Vector3.BACK,false,row.id)
  for i in 120:
   p.active_ability.tick(DT);p.active_ability.tick_shin_counter(DT)
  check(enemy.hp<health and p.model.shin_counter_fx==counter_fx,"Borrowed polearm counter repeatedly damages through the same prepared effect")
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("RESTORED_SKILLS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
