extends "res://tests/forest-shrine/crossgate_shin_skills_test.gd"
const SHADOW_OUT="res://build/Other Files/Asset Toolkit/Mirror Movement/Archer/"
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Balance=preload("res://scripts/spells/skill_balance.gd")
var shot_counts={}
var arrow_samples=[]
var live_arrows:Array[Node3D]=[]
var measure_shadows=false

func capture(filename:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(SHADOW_OUT+filename)==OK,"Captured "+filename)

func run():
 create_timer(240).timeout.connect(func():printerr("LANCELOT_SHADOW_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 DirAccess.make_dir_recursive_absolute(SHADOW_OUT)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 var p=game.player;var army=game.army_runtime
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 p.select_character(Roster.LANCELOT_ID);fresh()
 game.select_crossgate_skin(Roster.LANCELOT_ID,105206)
 game.settings.disable_character_cooldowns=false;game.tuning.invincible=false
 var kit=p.active_ability;var loadout=p.spell_loadout;var visual=p.model
 check(loadout.equip(Roster.LANCELOT_ID,"equip",loadout.Catalog.BARRAGE_SHADOWS),"Black Lancelot equips Barrage Shadows on key 1")
 check(loadout.equip(Roster.LANCELOT_ID,"surge",loadout.Catalog.SURE_STRIKE),"Lancelot equips 乾坤 on key 2")
 check(loadout.equip(Roster.LANCELOT_ID,"special_6",loadout.Catalog.KAGEROU),"Lancelot equips 陽炎 on key 6")
 var home=Vector3(-120,0,125);home.y=game.model.world_height(home.x,home.z)+.05
 game.model.update_vision(home);settle(home)
 var dummy=game.training_dummy;dummy.position=home+Vector3.FORWARD*10;dummy.home=dummy.position
 check(p.is_on_floor(),"Lancelot starts grounded on the actual map")
 check(Balance.all().has("lancelot/sure-strike") and Balance.all().has("lancelot/kagerou"),"Native skill tuning identifies Lancelot's skills")
 var pool=Pool.service(game)
 pool.launched.connect(func(arrow):
  if arrow.kind!="crossgate_arrow":return
  arrow.set_physics_process(false);live_arrows.append(arrow)
  if not measure_shadows:return
  var body=arrow.hero
  shot_counts[body.get_instance_id()]=int(shot_counts.get(body.get_instance_id(),0))+1
  arrow_samples.append({"damage":arrow.damage,"ticket":arrow.attack_ticket.duplicate(),"owner":body})
 )
 game.impact_confirmed.connect(func(victim,_strength,_time):victims.append(victim))
 press(KEY_2)
 check(kit.ticket.action=="shin_sure_strike" and visual.combo_glow.visible and victims.is_empty(),"Key 2 charges 乾坤 without early damage")
 step_player(28)
 check(kit.clip=="5" and not visual.combo_glow.visible,"乾坤 uses Lancelot's original bow action after the shine")
 await capture("sure-strike-windup.png")
 step_player(50)
 check(victims.is_empty() and live_arrows.size()==1 and live_arrows[0].pool_live,"乾坤 releases one arrow and deals no damage before it arrives")
 var charged_arrow=live_arrows[0]
 charged_arrow._physics_process(.04)
 await capture("sure-strike-arrow-flight.png")
 for i in 120:
  if charged_arrow.pool_live:charged_arrow._physics_process(STEP)
 check(victims==[dummy] and not charged_arrow.pool_live,"乾坤 explodes once at arrow contact without a second direct hit")
 check(game.crowd.army.presentation.effects.any(func(row):return row.kind=="shin_sure_strike"),"乾坤 reuses the recovered impact art")
 await capture("sure-strike-impact.png")
 step_player(100);press(KEY_2)
 check(not kit.is_attacking() and kit.shin_sure_cooldown>0,"乾坤 retains its five-second cooldown")
 for level_ in [1,30]:
  live_arrows.clear();kit.cancel(true);kit.clear_cooldowns();p.attack_chain.reset()
  Balance.set_level(p,"lancelot/random-shot",level_);kit.start_random_shot()
  for i in 1000:kit.tick(STEP)
  check(live_arrows.size()==level_+2 and live_arrows.all(func(arrow):return is_equal_approx(arrow.damage,250.0*.85*p.damage_multiplier())),"Player 亂射 Lv%d releases %d arrows at 85%% base damage"%[level_,level_+2])
  for arrow in live_arrows:
   if arrow.pool_live:arrow.retire()
  live_arrows.clear()
 press(KEY_6);game.forest_ui.sync()
 Balance.set_modifier(p,"lancelot/kagerou","fixture",{"chance":1})
 var health=p.hp;p.invuln=0;p.take_hit(30,Vector3.RIGHT);visual.tick_kagerou_dodge(.1)
 check(kit.kagerou_enabled and p.hp==health and game.forest_ui.loadout_cooldowns[5].text=="ON","Key 6 toggles dodge; a chance modifier makes this visual check deterministic")
 check(visual.kagerou_shadows.any(func(shadow):return shadow.visible),"陽炎 shows Lancelot's prepared afterimage")
 await capture("kagerou.png")
 press(KEY_6);visual.tick_kagerou_dodge(2)
 Balance.set_modifier(p,"lancelot/kagerou","fixture",{})
 check(not kit.kagerou_enabled,"Key 6 toggles 陽炎 off")
 kit.cancel(true);fresh();settle(home);dummy.position=home+Vector3.DOWN*100
 army.set_navigation(9933,army.navigation_data(game.model));army.record_events=false;game.hit_stop=0
 var point=home+Vector3.FORWARD*18
 var row=game.model.waves.spawn_enemy(0,point);row.hp=100000000;row.max_hp=row.hp
 army.import_arrivals();army.sync_targets()
 var enemy:Ninja=game.actors[row.id]
 army.apply_hit(enemy.handle,{"element":"ice","status_seconds":1000.0})
 p.team_progression.level=7;p.team_progression.stat_ranks.attack=3;p.refresh_max_health(true)
 p.run_upgrades.damage=3;p.apply_food_buff("damage_mult")
 game.settings.skill_balance={"lancelot/random-shot":{"damage":1.7}}
 check(loadout.equip(Roster.LANCELOT_ID,"surge",loadout.Catalog.RANDOM_SHOT),"The caster equips 亂射 on key 2 without changing the dedicated shadow attack")
 p.attack_chain.count=8
 var expected_chain=p.attack_chain.damage_multiplier()
 var expected_damage=250.0*.85*p.damage_multiplier()*1.29
 var expected_skill=Balance.effective(p,"lancelot/random-shot","damage")
 var target_health:float=army.unit_state(enemy.handle).hp
 var mirrors=kit.mirrors
 Balance.set_level(p,"lancelot/barrage-shadows",1)
 press(KEY_1)
 check(mirrors.handles.size()==1 and is_equal_approx(mirrors.bodies[0].damage_multiplier(),p.damage_multiplier()),"Level 1 creates one shadow at 100% caster damage")
 await capture("level-01-one-shadow.png")
 var distant=home+Vector3.LEFT*96
 distant.y=game.model.world_height(distant.x,distant.z)
 army.set_pose(enemy.handle,distant,0);army.sync_targets()
 var shadow=mirrors.bodies[0]
 var origin:Vector3=shadow.auto_aim_origin()
 var target:=AttackChain.aim_point(enemy,origin)
 check(origin.distance_to(target)>80 and origin.distance_to(target)<kit.projectile_range() and AttackChain.clear_line(shadow,origin,target),"Distant enemy has a clear shot within bow range")
 var worker_jobs: int=army.worker_jobs
 var shot_seen=false
 for i in 240:
  if army.begin_integration(STEP):army.finish_integration()
  else:army.integration_tick(STEP)
  for arrow in live_arrows:
   if arrow.pool_live:arrow._physics_process(STEP)
  live_arrows=live_arrows.filter(func(arrow):return arrow.pool_live)
  if not shot_seen and not live_arrows.is_empty():
   shot_seen=true
   await capture("shadow-arrow-in-flight.png")
  if i%20==0:await physics_frame
 check(army.worker_jobs>worker_jobs and shot_seen and enemy.hp<target_health,"Stationary shadow shoots and damages the distant enemy through the native worker (released %s, target HP %.0f)"%[shot_seen,enemy.hp])
 army.set_pose(enemy.handle,point,0);army.sync_targets()
 target_health=enemy.hp
 mirrors.clear();kit.clear_cooldowns()
 Balance.set_level(p,"lancelot/barrage-shadows",30)
 Balance.set_level(p,"lancelot/random-shot",30)
 press(KEY_1)
 check(mirrors.handles.size()==7 and is_equal_approx(mirrors.left,30),"Key 1 summons seven level-30 native shadows for 30 seconds")
 if mirrors.handles.size()!=7:
  game.queue_free();paused=false;await frames(4);quit(1);return
 var handles=mirrors.handles.duplicate();var bodies=mirrors.bodies.duplicate()
 var positions=mirrors.bodies.map(func(body):return body.position)
 check(bodies.all(func(body):return body.character_id==Roster.LANCELOT_ID and body.model.variant_skin==visual.variant_skin and is_equal_approx(body.model.sprite.modulate.a,.65)),"All shadows retain the selected skin with 30% less transparency (65% opacity)")
 check(visual.sprite.modulate==Color.WHITE,"The original Lancelot stays opaque")
 press(KEY_1)
 check(mirrors.handles==handles and kit.mirror_cooldown>0,"The existing mirror cooldown prevents immediate replacement")
 game.camera_rig.camera.global_position=home+Vector3(0,18,30)
 game.camera_rig.camera.look_at(home+Vector3(0,1,-4))
 measure_shadows=true
 var times=[]
 for i in 1600:
  var started=Time.get_ticks_usec()
  army.step(STEP,{"targets":army.external_targets()})
  for arrow in live_arrows:
   if arrow.pool_live:arrow._physics_process(STEP)
  live_arrows=live_arrows.filter(func(arrow):return arrow.pool_live)
  game.crowd.army.presentation.tick(STEP)
  times.append(Time.get_ticks_usec()-started)
  if i==80:
   await capture("level-30-seven-shadows.png")
  if i==400:p.position=home+Vector3(25,0,0)
  if i%60==0:await physics_frame
 check(shot_counts.size()==7 and shot_counts.values().all(func(count):return count>=64),"Every shadow repeats complete level-30 thirty-two-arrow 亂射 volleys")
 check(arrow_samples.all(func(sample):return is_equal_approx(sample.damage,expected_damage) and is_equal_approx(sample.ticket.skill_damage,expected_skill) and is_equal_approx(sample.ticket.damage_multiplier,expected_chain) and sample.ticket.allied and sample.ticket.action=="lancelot_random_shot"),"Every shadow arrow matches Lancelot's level, attack allocation, food, run and skill damage without player hit-stop ownership")
 check(army.unit_state(enemy.handle).hp<target_health,"Shadow arrows deal real damage to the native enemy")
 check(bodies.all(func(body):return body.action_history.all(func(index):return index==0) and body.actions.size()==1),"Shadows use only 亂射, never normal attacks or other skills")
 for i in 7:check(Vector2(bodies[i].position.x-positions[i].x,bodies[i].position.z-positions[i].z).length()<.08,"Shadow %d stays where it was left, even after Lancelot moves"%i)
 check(game.hit_stop==0 and p.impact_pause==0,"Simultaneous shadow impacts do not pause the player")
 await frames(2)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var created=pool.created;var misses=pool.misses
 for repeat_ in 6:
  p.position=home
  check(mirrors.cast(),"Repeated shadow cast reuses seven prepared bodies")
  for i in 180:
   army.step(STEP,{"targets":army.external_targets()})
   for arrow in live_arrows:
    if arrow.pool_live:arrow._physics_process(STEP)
   live_arrows=live_arrows.filter(func(arrow):return arrow.pool_live)
   game.crowd.army.presentation.tick(STEP)
  army.presentation_events.clear()
 check(mirrors.bodies==bodies and get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated seven-shadow use retains warmed nodes/resources")
 check(pool.created==created and pool.misses==misses,"Repeated simultaneous volleys retain the prepared projectile capacity")
 # An existing shadow reads the caster's current arrow level at the next volley.
 var body=bodies[0]
 for level_ in [1,30]:
  body.active_ability.cancel(true);body.active_ability.clear_cooldowns();body.attack_left=0
  Balance.set_level(p,"lancelot/random-shot",level_);arrow_samples.clear()
  body.active_ability.start_random_shot()
  var snapshot=body.active_ability.ticket.duplicate(true)
  Balance.set_level(p,"lancelot/random-shot",30 if level_==1 else 1)
  for i in 1000:body.active_ability.tick(STEP)
  check(arrow_samples.size()==level_+2 and arrow_samples.all(func(sample):return sample.ticket.skill_level==level_ and is_equal_approx(sample.damage,expected_damage)),"Existing shadow uses caster 亂射 Lv%d and keeps all %d arrows on its cast snapshot"%[level_,level_+2])
  check(snapshot.skill_level==level_,"Arrow-level changes do not change the already-started shadow volley")
  for arrow in live_arrows:
   if arrow.pool_live:arrow.retire()
  live_arrows.clear()
 handles=mirrors.handles.duplicate();mirrors.tick(mirrors.left-.01)
 check(mirrors.handles==handles,"Shadows remain alive immediately before the 30-second expiry")
 mirrors.tick(.02)
 check(mirrors.handles.is_empty() and handles.all(func(handle):return not army.valid(handle)) and bodies.all(func(body):return not body.leased and body.shadow_source==null and not body.visible),"Expiry retires native handles, visuals and source references")
 check(bodies.all(func(body):return pool.all.values().all(func(group):return group.all(func(arrow):return not arrow.pool_live or arrow.hero!=body))),"Expiry releases in-flight shadow arrows and old damage tickets")
 kit.clear_cooldowns();settle(home);press(KEY_1)
 check(mirrors.handles.size()==7,"Key 1 can summon again after expiry")
 p.select_character(Roster.MAZE_ID)
 check(mirrors.handles.is_empty(),"Switching character clears the shadow group")
 p.select_character(Roster.LANCELOT_ID);fresh();settle(home);kit.clear_cooldowns();press(KEY_1)
 kit.die()
 check(mirrors.handles.is_empty(),"Player death clears the shadow group")
 times.sort()
 print("LANCELOT_SHADOW_PERFORMANCE step_p95_us=%d step_max_us=%d pool_created=%d pool_misses=%d arrows=%d"%[times[int(times.size()*.95)],times.back(),pool.created,pool.misses,arrow_samples.size()])
 var config=game.settings_path;game.queue_free();current_scene=null;paused=false;await frames(4)
 if FileAccess.file_exists(config):DirAccess.remove_absolute(ProjectSettings.globalize_path(config))
 print("LANCELOT_SHADOW_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
