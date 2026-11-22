extends "res://tests/forest-shrine/dodge_counter_stats_test.gd"
const ANIMATION_OUT="res://build/Other Files/Asset Toolkit/Counter Animation/"

func spawn(offset:Vector3)->Dictionary:
 var at=home+offset;at.y=game.model.world_height(at.x,at.z)
 var row=game.model.waves.spawn_enemy(Roles.SLIME,at);row.hp=10000000;row.max_hp=row.hp
 game.army_runtime.import_arrivals();game.army_runtime.sync_targets()
 var target=game.army_runtime.enemy_target(row.id)
 game.army_runtime.apply_hit(target.handle,{"element":"ice","status_seconds":1000.0})
 return {"id":row.id,"target":target}

func run():
 create_timer(240).timeout.connect(func():printerr("COUNTER_ANIMATION_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ANIMATION_OUT);root.size=Vector2i(960,640)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.settings.gear_loadouts={};game.begin_arena();game.choose_rogue_character(34);await frames(3);game.equipment_hub.enter_map();await frames(3)
 game.clear_menu();game.forest_ui.hide();game.playing=true;game.paused=false;paused=false
 game.music.stop();game.settings.forest_pet_loadout=[];game.model.waves.crossgate_pet_test=true;game.model.waves.patrol_posts.clear()
 home=Vector3(-120,0,125);home.y=game.model.world_height(home.x,home.z)+.05;game.model.update_vision(home)
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000
 game.camera_rig.camera.global_position=home+Vector3(3,3,9);game.camera_rig.camera.look_at(home+Vector3(0,1,-.5))
 game.camera_rig.camera.make_current()
 check(root.get_camera_3d()==game.camera_rig.camera,"Counter review uses the positioned gameplay camera")
 var p=game.player
 for id in p.RogueRoster.CROSSGATE:
  p.select_character(id);game.update_character_tuning(id,"critical_chance",0)
  for weapon in Gear.allowed(id,game.settings):
   check(game.save_equipment_loadouts({Gear.character_key(id):{"1":"weapon:"+weapon}},game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Equip counter animation %d %s"%[id,weapon])
   game.army_runtime.clear();game.model.enemies.clear();game.army_runtime.refresh_kits();await frames(2)
   planted();chance(100,100)
   var enemy=spawn(Vector3.FORWARD*1.6)
   p.take_hit_from(2,Vector3.BACK,false,enemy.id)
   var kit=p.active_ability;var model=p.model;var counter:Dictionary=kit.shin_counter
   check(not counter.is_empty(),"Counter begins for %d %s"%[id,weapon])
   if counter.is_empty():continue
   var seen={};var visible_all=true;var matches=true;var materials_match=true
   p.facing=counter.facing
   var frame_count:int=counter.attack.frames.size()
   var strip=Image.create(320*frame_count,320,false,Image.FORMAT_RGBA8) if id==34 else null
   var before_strip=strip.duplicate() if strip!=null else null
   if id==34:p.position=home+Vector3.RIGHT*4
   for i in frame_count:
    var at=(i+.5)*float(counter.attack.duration)/frame_count
    kit.tick_shin_counter((at-float(counter.elapsed))/p.attack_speed_multiplier())
    model.show_pose(int(model.normal_attack_pattern().pose),counter.elapsed,false)
    var shadow=model.stat_counter_shadow
    seen[model.shin_counter_frame]=true
    visible_all=visible_all and shadow.visible and not kit.shin_counter.is_empty()
    matches=matches and shadow.texture==model.sprite.texture and shadow.region_rect==model.sprite.region_rect and shadow.offset==model.sprite.offset
    materials_match=materials_match and shadow.material_override==model.shadow_materials[shadow.texture] and shadow.material_override.get_shader_parameter("sprite_texture")==shadow.texture
    if strip!=null and DisplayServer.get_name()!="headless":
     await frames(2);RenderingServer.force_draw()
     var screen=root.get_texture().get_image();screen.resize(480,320);screen.convert(Image.FORMAT_RGBA8)
     strip.blit_rect(screen,Rect2i(80,0,320,320),Vector2i(i*320,0))
     var material=shadow.material_override;shadow.material_override=null;RenderingServer.force_draw()
     screen=root.get_texture().get_image();screen.resize(480,320);screen.convert(Image.FORMAT_RGBA8)
     before_strip.blit_rect(screen,Rect2i(80,0,320,320),Vector2i(i*320,0));shadow.material_override=material
   check(visible_all and seen.size()==frame_count and matches,"Counter shows every original normal-attack frame through recovery for %d %s"%[id,weapon])
   check(materials_match,"Counter uses the same ground-safe artwork material for every frame %d %s"%[id,weapon])
   if strip!=null and DisplayServer.get_name()!="headless":
    check(strip.save_png(ANIMATION_OUT+"kaz-counter-after.png")==OK and before_strip.save_png(ANIMATION_OUT+"kaz-counter-unprojected.png")==OK,"Captured every Kaz counter frame with and without the ground-safe material")
   kit.tick_shin_counter((float(counter.attack.duration)-float(counter.elapsed)+.001)/p.attack_speed_multiplier())
   check(kit.shin_counter.is_empty() and model.stat_counter_shadow.visible and model.shin_counter_frame==frame_count-1,"Counter finishes on the final source frame for %d %s"%[id,weapon])
   kit.tick_shin_counter(.31)
   check(not model.stat_counter_shadow.visible,"Counter retires after full recovery for %d %s"%[id,weapon])
   model.sprite.set_instance_shader_parameter("grounded",false);model.stamp_kagerou(model.stat_counter_shadow)
   check(model.stat_counter_shadow.material_override==model.shadow_materials[model.sprite.texture] and model.stat_counter_shadow.get_instance_shader_parameter("grounded")==false,"Stamped afterimages preserve the current atlas and airborne depth for %d %s"%[id,weapon])
   model.stat_counter_shadow.hide();model.sprite.set_instance_shader_parameter("grounded",true)
 print("COUNTER_ANIMATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
 game.queue_free();current_scene=null;await frames(3)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
