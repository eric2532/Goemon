extends "res://tests/forest-shrine/pet_attack_skills_test.gd"
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const Skills=preload("res://scripts/spells/skill_balance.gd")
const REVIEW="res://build/Other Files/Overkill/"
var victims:Array[int]=[]
var samples:Array[int]=[]
func overkill_step(_dt:float=DT):
 var start=Time.get_ticks_usec()
 game.player._physics_process(DT)
 advance()
 game.crowd.army.presentation.tick(DT)
 samples.append(Time.get_ticks_usec()-start)
func picture(name_:String):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.flush_presentation();game.forest_ui.sync();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(REVIEW+name_+".png")==OK,"Captured "+name_)
func settle(id:int):
 game.player.spell_loadout.interrupt()
 if is_instance_valid(game.player.active_ability):game.player.active_ability.cancel(true)
 game.army_runtime.clear();game.model.enemies.clear();game.army_runtime.refresh_kits()
 game.player.select_character(id);fresh()
 var p=game.player;p.position=home;p.hp=p.max_hp;p.dodge_time=0;p.impact_pause=0
 p.active_ability.clear_cooldowns();game.paused=false;game.ordinary_pause=false
 game.update_character_tuning(id,"critical_chance",0)
 game.update_character_tuning(id,"combo_splash_radius",0)
 await driver.advance(25,overkill_step)
func player_case(id:int,bee:bool,original:bool=false):
 await settle(id)
 var p=game.player;var army=game.army_runtime;var fx=game.crowd.army.presentation
 var skill=Pets.Spells.BEE_FLURRY if bee else Catalog.COMBO
 check(p.spell_loadout.equip(id,"equip" if bee else "surge","" if original else skill),"Fighter %d equips %s"%[id,skill])
 var nodes=0;var resources=0.0
 var enemy=spawn(Vector3(0,0,-4),1);enemy.freeze_for(1000)
 var handle:int=enemy.handle;var target_id:int=enemy.forest_id;var start=p.global_position;var kills:int=game.kills
 victims.clear()
 if original:p.active_ability.start_combo()
 else:tap("equip" if bee else "surge")
 var instance=p.spell_loadout.current
 var kit=p.active_ability if instance==null else instance.controller
 check(kit.is_attacking(),"Fighter %d starts the sequence"%id)
 var expected=5 if bee else int(kit.skill_count(kit.SHIN_COMBO_LIMIT if kit.cast_model().fighter.get("weapon_skills",false) else kit.COMBO_LIMIT,kit.ticket))
 var held=false;var middle=false
 for frame in 700:
  await driver.advance(1,overkill_step)
  if not held and is_instance_valid(enemy) and enemy.dead and kit.is_attacking():
   held=true
   nodes=get_node_count();resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
   check(enemy.sequence_users==1 and not army.valid(handle) and enemy.collision_layer==0,"Lethal contact retires native combat immediately while retaining the body")
   check(enemy.combat_segment_contact(start+Vector3.UP,start+Vector3.FORWARD*10+Vector3.UP,2).is_empty(),"Ordinary strikes cannot hit the overkill body")
   check(not fx.corpses.filter(func(row):return fx.corpse_held(row)).is_empty(),"The pooled corpse remains visible during the sequence")
   if id==34:await picture("%s-first-lethal"%["bee" if bee else "combo"])
  if held and not middle and id==34 and victims.size()==3:
   middle=true;await picture("%s-overkill"%["bee" if bee else "combo"])
  if not kit.is_attacking():break
 var count_=expected
 check(held and victims.size()==count_ and victims.all(func(victim):return victim==target_id),"Fighter %d finishes all %d %s contacts on the defeated target (got %d)"%[id,count_,"bee" if bee else "combo",victims.size()])
 check(game.kills-kills==1,"Overkill awards exactly one kill")
 check(not kit.is_attacking() and kit.combo_cooldown>0,"Full sequence ends with its cooldown")
 if bee:check(p.global_position.distance_to(start)<.03,"Bee returns to its original position")
 check(fx.corpses.all(func(row):return not fx.corpse_held(row)),"Completion releases every held corpse")
 await driver.advance(150,overkill_step)
 check(not is_instance_valid(enemy) and fx.corpses.is_empty(),"Normal death animation and facade cleanup complete")
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Warmed impacts and cleanup release their nodes and resources")
func pet_case(skill:String):
 var p=game.player;var army=game.army_runtime
 p.spell_loadout.interrupt()
 if is_instance_valid(p.active_ability):p.active_ability.cancel(true)
 p.position=home+Vector3.RIGHT*50
 var skins=[0,21,41,61,81]
 await equip_pack(skins,skins.map(func(_skin):return [skill,"",""]))
 var ids=[];var kills:int=game.kills
 for skin in skins:
  var at:Vector3=army.unit_state(army.handles[army.HOUND_ID-skin]).position
  var enemy=spawn(at-home+Vector3.FORWARD*3,1);enemy.freeze_for(1000);ids.append(enemy.forest_id)
 victims.clear();army.event_log.clear()
 for frame in 500:
  await driver.advance(1,advance)
  game.crowd.army.presentation.tick(DT)
  if frame==55:await picture("pets-"+skill.get_file())
 var contacts=army.event_log.filter(func(event):return event.kind=="pet_skill_contact")
 var count_=5 if skill==Pets.Spells.BEE_FLURRY else 3
 for skin in skins:
  var source=army.HOUND_ID-skin
  var own=contacts.filter(func(event):return event.source_id==source)
  var expected=count_ if skill==Pets.Spells.BEE_FLURRY else int(Skills.effective(army.pet_skills.casters[Pets.key(skin)],skill,"count"))*Pets.attack_pattern(skin).contacts.size()
  check(own.size()==expected and own.all(func(event):return event.target_id==own[0].target_id),"Pet %d completes %d contacts on its one defeated target (got %d)"%[skin,expected,own.size()])
 check(game.kills-kills==5 and ids.all(func(id):return victims.count(id)>1),"Five simultaneous casters finish overkill without extra deaths")
 check(game.crowd.army.presentation.corpses.is_empty(),"Pet completion releases all corpse records")
func cancellation_case():
 await settle(34)
 var p=game.player;var army=game.army_runtime;var fx=game.crowd.army.presentation
 check(p.spell_loadout.equip(34,"equip",Pets.Spells.BEE_FLURRY),"Equip cancellation case")
 var enemy=spawn(Vector3(0,0,-4),1);enemy.freeze_for(1000)
 victims.clear();tap("equip")
 for frame in 100:
  await driver.advance(1,overkill_step)
  if not victims.is_empty():break
 check(enemy.dead and enemy.sequence_users==1,"Cancellation case starts after a lethal hit")
 enemy.retain_sequence()
 p.spell_loadout.interrupt()
 check(enemy.sequence_users==1 and fx.corpses.any(func(row):return fx.corpse_held(row)),"One cancellation leaves another sequence's body intact")
 enemy.release_sequence();var count_=victims.size()
 await driver.advance(150,overkill_step)
 check(victims.size()==count_ and not is_instance_valid(enemy) and fx.corpses.is_empty(),"Final release cleans up without late contacts")
func run():
 create_timer(420).timeout.connect(func():printerr("OVERKILL_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(REVIEW);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 for node in [game,game.player,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*1000
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false;game.army_runtime.record_events=true
 game.impact_confirmed.connect(func(enemy,_strength,_time):victims.append(enemy.forest_id))
 game.camera_rig.camera.global_position=home+Vector3(8,9,16);game.camera_rig.camera.look_at(home+Vector3(0,1,-3))
 var roster=[] if "--originals" in OS.get_cmdline_user_args() else [Catalog.Roster.KAZI_ID,Catalog.Roster.SHIN_ID,Catalog.Roster.BOG_ID,35] if "--visual" in OS.get_cmdline_user_args() else game.player.RogueRoster.CROSSGATE
 for id in roster:
  await player_case(id,false)
  await player_case(id,true)
 for id in [Catalog.Roster.KAZI_ID,Catalog.Roster.SHIN_ID,Catalog.Roster.BOG_ID]:await player_case(id,false,true)
 await cancellation_case()
 if "--originals" not in OS.get_cmdline_user_args():
  await pet_case(Pets.Spells.BEE_FLURRY)
  await pet_case(Pets.Spells.COMBO)
 samples.sort();print("OVERKILL_STEP_US p95=",samples[floori(samples.size()*.95)]," max=",samples.back())
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("OVERKILL_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
