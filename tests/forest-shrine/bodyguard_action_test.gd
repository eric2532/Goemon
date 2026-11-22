extends "res://tests/forest-shrine/bodyguard_test.gd"
var protected_count=0
var armed=false
var spell_case=false
var cast
var enemy

func protected_tick(dt:float):
 var p=game.player;var army=game.army_runtime
 var seconds=float(army.native.hero_dodge_threat().seconds)
 if not armed and seconds>0 and seconds<=.1:
  p.active_ability.cancel(true);p.spell_loadout.interrupt();p.mana=p.max_mana
  if spell_case:
   p.spell_loadout.instances["%d:kazi/qigong"%p.character_id].controller.clear_cooldowns()
   p.spell_loadout.magic_result={}
   p.spell_loadout._cast("kazi/qigong","special_4");cast=p.spell_loadout.current
  else:p.active_ability.start_basic_attack(Vector3.FORWARD,enemy)
  armed=true
 p._physics_process(dt)
 var action=p.active_ability.mode;var clock=p.active_ability.elapsed;var ticket=p.active_ability.ticket.duplicate(true)
 var current=p.spell_loadout.current;var charge=float(cast.controller.charge_left) if is_instance_valid(cast) else 0.0
 var velocity=p.velocity;var at=p.global_position;var hp=p.hp
 army.presentation_events.clear();army.integration_tick(dt)
 if army.presentation_events.any(func(e):return e.kind=="status" and e.get("action_index",0)==6011 and e.target_id==0):
  protected_count+=1
  check(armed and p.global_position.distance_to(at)>1 and p.hp==hp,"Protected fighter %d is pushed clear without taking the intercepted hit"%p.character_id)
  check(p.velocity==velocity,"Protected fighter %d retains movement velocity"%p.character_id)
  if spell_case:
   check(current==cast and p.spell_loadout.current==cast and charge>0 and cast.controller.charge_left==charge,"Protected fighter %d keeps the same borrowed Qi cast and charge clock"%p.character_id)
  else:
   check(not action.is_empty() and p.active_ability.mode==action and p.active_ability.elapsed==clock and p.active_ability.ticket==ticket,"Protected fighter %d keeps the attack, clock and ticket"%p.character_id)
  check(army.unit_state(army.handles[army.HOUND_ID]).action==0,"The pet protector stops its previous action")
 elif seconds<=0:armed=false
 army.flush_presentation()

func run():
 create_timer(240).timeout.connect(func():printerr("BODYGUARD_ACTION_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime
 game.set_process(false);army.set_process(false);army.set_physics_process(false);game.camera_rig.set_process(false);game.music.stop();p.set_auto_attack(false)
 army.record_events=true;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 game.training_dummy.position=home+Vector3.DOWN*1000;game.training_dummy.home=game.training_dummy.position
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 game.camera_rig.camera.global_position=home+Vector3(13,12,18);game.camera_rig.camera.look_at(home+Vector3.UP*2)
 for id in p.RogueRoster.CROSSGATE:
  for casting in [false,true]:
   p.select_character(id);p.timed_dodge.reset();p.active_ability.cancel(true);p.spell_loadout.interrupt();cast=null
   p.spell_loadout.equip(id,"special_6","");p.spell_loadout.equip(id,"special_4","kazi/qigong")
   p.position=home;p.velocity=Vector3.ZERO;p.hp=p.max_hp;p.invuln=0;p.impact_pause=0;p.combat_hold_left=0;p.smoke_mode=true;p.smoke_move=Vector2.ZERO
   await equip_pack([0],[[Pets.Spells.BODYGUARD,"",""]])
   var guard:int=army.handles[army.HOUND_ID]
   army.native.set_pose(guard,home+Vector3.RIGHT*6,0);army.native.set_guard(guard,home+Vector3.RIGHT*6,18);army.order_hounds(army.HoundOrder.HOLD)
   var point=home+Vector3.FORWARD*2.5;point.y=game.model.surface_height(point.x,point.z)
   var row=game.model.waves.spawn_enemy(0,point);row.hp=1000000;row.max_hp=row.hp
   army.import_arrivals();army.sync_targets();enemy=army.enemy_target(row.id)
   spell_case=casting;armed=false;protected_count=0
   for tick in 480:
    await driver.advance(1,protected_tick)
    if protected_count:break
   check(protected_count==1,"A native enemy hit rescues fighter %d during %s"%[id,"borrowed Qi" if casting else "normal attack"])
   if id==p.RogueRoster.SHIN_ID:await photograph("protected-qi" if casting else "protected-attack")
   if casting and protected_count:
    var left:float=cast.controller.charge_left
    await driver.advance(1,rescue_tick)
    check(p.spell_loadout.current==cast and cast.controller.charge_left<left,"The protected Qi charge advances after the push")
 # Real pet skill starts and contacts must survive the same event dispatch.
 p.select_character(p.RogueRoster.SHIN_ID);p.spell_loadout.equip(p.character_id,"special_6",Pets.Spells.BODYGUARD)
 for skill in [Pets.Spells.SURE_STRIKE,Pets.Spells.COMBO,Pets.Spells.BEE_FLURRY,"kazi/qigong"]:
  await equip_pack([0],[[skill,"",""]])
  var ally:int=army.handles[army.HOUND_ID]
  p.position=home+Vector3.RIGHT*6;p.velocity=Vector3.ZERO;p.hp=p.max_hp;p.timed_dodge.reset()
  army.native.set_pose(ally,home,0);army.native.set_guard(ally,home,18)
  enemy=spawn(Vector3.FORWARD*(10 if skill=="kazi/qigong" else 2))
  army.apply_hit(enemy.handle,{"element":"ice","status_seconds":10.0})
  army.order_hounds(army.HoundOrder.ATTACK,enemy.handle)
  var caster=army.pet_skills.casters[Pets.key(0)]
  for tick in 180:
   advance()
   if caster.current_skill==skill and army.unit_state(ally).action==1:break
  var before:Dictionary=army.unit_state(ally);var serial:int=caster.cast_serial;var ticket:Dictionary=caster.ticket.duplicate(true)
  var charge:float=caster.controllers[skill].charge_left if caster.controllers.has(skill) else 0.0
  p.position=home+Vector3.RIGHT*6;army.native.set_targets(army.external_targets());army.presentation_events.clear()
  for attempt in 2:
   before=army.unit_state(ally)
   army.apply_hit(ally,{"amount":1.0,"source_id":enemy.forest_id,"direction":Vector3.BACK})
   if p.timed_dodge.rescue_left>0:break
  var after:Dictionary=army.unit_state(ally)
  check(p.timed_dodge.rescue_left>0 and after.position.distance_to(before.position)>1,"The pet is pushed during %s"%skill)
  check(before.action==1 and after.action==before.action and after.action_time==before.action_time and after.target_id==before.target_id,"Protected pet keeps its native action clock and target during %s"%skill)
  check(caster.cast_serial==serial and caster.current_skill==skill and caster.ticket==ticket,"Protected pet keeps its prepared cast during %s"%skill)
  if caster.controllers.has(skill):check(charge>0 and caster.controllers[skill].charge_left==charge,"Protected pet keeps its ranged charge")
  else:check(caster.charge.visible,"Protected pet keeps its physical skill shine")
  army.event_log.clear()
  for tick in 120:advance()
  check(army.event_log.any(func(e):return e.kind=="pet_skill_contact" and e.source_id==army.HOUND_ID and e.projectile_id==serial),"The displaced pet completes a contact from the same %s cast"%skill)
 print("BODYGUARD_ACTION_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();await process_frame;quit(1 if failures else 0)
