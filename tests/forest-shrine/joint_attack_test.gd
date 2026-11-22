extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Joint Attack/"
const DT=1.0/60
const Gear=preload("res://scripts/forest/equipment.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
var home=Vector3(40,0,60)
var driver
var samples:Array[int]=[]

func advance():
 var start=Time.get_ticks_usec()
 game.player._physics_process(DT);game.army_runtime.integration_tick(DT)
 game.crowd.army.presentation.tick(DT)
 samples.append(Time.get_ticks_usec()-start)

func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.flush_presentation();await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)

func run():
 create_timer(300).timeout.connect(func():printerr("JOINT_ATTACK_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.music.stop();game.settings.forest_pet_loadout=[];game.settings.forest_pet_skills={}
 game.training_dummy.position=home+Vector3.DOWN*1000
 game.model.waves.crossgate_pet_test=true;game.model.waves.patrol_posts.clear()
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 var p=game.player;var army=game.army_runtime
 game.camera_rig.yaw=0;game.camera_rig.camera.global_position=home+Vector3(6,6,12);game.camera_rig.camera.look_at(home+Vector3(0,1,-1))
 army.record_events=true
 var fx=game.crowd.army.presentation
 for count_ in range(2,11):
  fx.clear();fx.joint_attack_feedback({"joint_count":count_,"target_id":9000,"position":home+Vector3.UP})
  var glyphs=fx.effects.filter(func(effect):return effect.kind=="joint-glyph")
  check(glyphs.size()==(10 if count_==10 else 9) and glyphs[0].glyph==count_-2,"Original HitCombo glyphs select the native count %d"%count_)
  check(glyphs[1].glyph==9 and glyphs[8].glyph==13 and (count_!=10 or glyphs[9].glyph==16),"Original letters and ten-participant Great cue remain intact")
  fx.tick(.9)
  if count_ in [2,6,10]:await capture("original-hitcombo-%d"%count_)
 fx.clear()
 for i in 100:fx.joint_attack_feedback({"joint_count":2,"target_id":9000,"position":home+Vector3.UP})
 check(fx.effects.size()==9,"Repeated participant contacts reuse the visible title")
 fx.joint_attack_feedback({"joint_count":3,"target_id":9000,"position":home+Vector3.UP})
 check(fx.effects.size()==9 and fx.effects[0].count==3,"A growing group replaces the previous title")
 fx.tick(4.1)
 check(fx.effects.is_empty(),"Original titles expire without retained effect records")
 var capacity=fx.effect_capacity;fx.effect_capacity=8
 fx.joint_attack_feedback({"joint_count":2,"target_id":9000,"position":home+Vector3.UP})
 check(fx.effects.is_empty(),"A full effect budget omits the whole title instead of truncating its letters")
 fx.effect_capacity=capacity
 for i in 100:fx.joint_attack_feedback({"joint_count":2,"target_id":9000+i,"position":home+Vector3.UP})
 check(fx.effects.size()<=capacity and fx.effects.size()%9==0,"Simultaneous target titles stay inside the shared effect budget")
 fx.clear()
 fx.joint_attack_feedback({"joint_count":10,"target_id":9000,"position":home+Vector3.UP});fx.tick(4.1)
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for i in 30:
  fx.joint_attack_feedback({"joint_count":10,"target_id":9000,"position":home+Vector3.UP});fx.tick(4.1)
 check(fx.effects.is_empty() and int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))==resources,"Thirty warmed titles retain no nodes, resources or records")
 for id in p.RogueRoster.CROSSGATE:
  army.clear();game.model.enemies.clear();p.select_character(id)
  var allowed=Gear.allowed(id,game.settings)
  var weapon="sword" if allowed.has("sword") else "unarmed" if allowed.has("unarmed") else allowed.keys()[0]
  check(game.save_equipment_loadouts({Gear.character_key(id):{"1":"weapon:"+weapon}},game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Equip a native melee weapon for %d"%id)
  p.active_ability.cancel(true);p.active_ability.clear_shin_counter();p.timed_dodge.reset();p.attack_chain.reset()
  p.position=home;p.velocity=Vector3.ZERO;p.smoke_mode=true;p.smoke_move=Vector2.ZERO;p.facing=Vector3.FORWARD;p.impact_pause=0;p.invuln=100;p.set_auto_attack(false)
  game.update_character_tuning(id,"critical_chance",0)
  army.refresh_kits()
  var at=home+Vector3.FORWARD*1.6;at.y=game.model.surface_height(at.x,at.z)
  var row=game.model.waves.spawn_enemy(0,at);row.hp=10000000;row.max_hp=row.hp
  army.import_arrivals();army.sync_targets()
  var target=army.enemy_target(row.id)
  army.apply_hit(target.handle,{"element":"ice","status_seconds":1000.0})
  var pet=army.spawn(army.HOUND_ID,1,19,home+Vector3(1.4,0,-2),3000,.3)
  check(pet!=0 and army.native.set_pet_skin(pet,0),"Prepare a native companion for %d"%id)
  army.native.set_guard(pet,home,18)
  var clicked=false;var joined=false
  for tick in 300:
   var state=army.unit_state(pet)
   if not clicked and int(state.get("action",0))==1:
    tap("light_attack");clicked=true
   await driver.advance(1,func(_dt):advance())
   if army.event_log.any(func(event):return event.kind=="damage" and int(event.get("joint_count",0))>=2):
    joined=true;break
  check(clicked and joined,"Ordinary player and real native pet contacts naturally form a joint attack for %d"%id)
  var events=army.event_log.filter(func(event):return event.kind=="damage" and int(event.get("joint_count",0))>=2)
  if not events.is_empty():
   var event=events.back()
   check(event.target_id==row.id and event.joint_count==2 and float(event.joint_total)>float(event.amount),"Native joint metadata names two distinct participants and the same target for %d"%id)
  if id==p.RogueRoster.KAZI_ID:
   await capture("native-player-pet-contact")
   for i in 3:
    await driver.advance(18,func(_dt):advance())
    await capture("native-player-pet-combo-%d"%i)
  army.native.set_guard(pet,home,0);p.active_ability.cancel(true)
  await driver.advance(1,func(_dt):
   for i in 60:advance())
  var before:float=target.hp
  p.attack_chain.reset()
  var ticket=p.attack_chain.make_ticket("shin_basic");ticket.normal_attack_damage=100
  target.take_hit(100,Vector3.FORWARD,false,ticket)
  check(is_equal_approx(before-float(target.hp),100),"A later solo attack gets no stale combo bonus for %d"%id)
  if id==p.RogueRoster.KAZI_ID:
   for excluded in [{"action":"crossgate_bow","projectile":true},{"action":"shin_basic","skill_id":"test_skill"},{"action":"stat_counter"}]:
    await driver.advance(1,func(_dt):
     for i in 30:advance())
    army.event_log.clear();p.attack_chain.reset();army.native.set_guard(pet,home,18)
    var pet_contact=false
    for tick in 300:
     await driver.advance(1,func(_dt):advance())
     if army.event_log.any(func(event):return event.kind=="damage" and event.source_id==army.HOUND_ID):
      pet_contact=true;break
    army.native.set_guard(pet,home,0);army.event_log.clear()
    var shot=p.attack_chain.make_ticket(str(excluded.action));shot.merge(excluded,true)
    target.take_hit(100,Vector3.FORWARD,false,shot)
    check(pet_contact and army.event_log.any(func(event):return event.kind=="damage") and not army.event_log.any(func(event):return int(event.get("joint_count",0))>=2),"Skill, projectile and counter tickets cannot join normal melee")
 samples.sort()
 print("JOINT_ATTACK_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"manual_step_p95_us":samples[int(samples.size()*.95)],"manual_step_max_us":samples.back()}))
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
