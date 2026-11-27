extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Balance=preload("res://scripts/character_balance.gd")
const Gear=preload("res://scripts/forest/equipment.gd")
const Skills=preload("res://scripts/spells/skill_balance.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const OUT="res://build/Other Files/Asset Toolkit/Dodge Counter/"
const DT=1.0/60
var home=Vector3(40,0,60)
var shots:Array=[]
var victims:Array=[]
var times:Array=[]

func chance(dodge:float,counter:float):
 var p=game.player
 game.update_character_tuning(p.character_id,"dodge_chance",dodge)
 game.update_character_tuning(p.character_id,"counter_chance",counter)

func planted():
 var p=game.player
 p.active_ability.cancel(true);p.active_ability.clear_shin_counter();p.active_ability.shin_counter_equipped=false
 p.active_ability.kagerou_enabled=false;p.model.clear_kagerou_dodge();p.attack_chain.reset()
 p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.invuln=0;p.dodge_time=0;p.impact_pause=0;p.hp=p.max_hp
 p.model.show_pose(0,0,true);game.crowd.army.presentation.clear()
 victims.clear();shots.clear();game.hit_stop=0

func spawn(offset:Vector3)->Dictionary:
 var at=home+offset;at.y=game.model.surface_height(at.x,at.z)
 var row=game.model.waves.spawn_enemy(Roles.SLIME,at);row.hp=10000000;row.max_hp=row.hp
 game.army_runtime.import_arrivals();game.army_runtime.sync_targets()
 var target=game.army_runtime.enemy_target(row.id)
 game.army_runtime.apply_hit(target.handle,{"element":"ice","status_seconds":1000.0})
 return {"id":row.id,"target":target}

func advance(count:int):
 var p=game.player
 for i in count:
  var start=Time.get_ticks_usec()
  p.model.tick_kagerou_dodge(DT);p.active_ability.tick_shin_counter(DT)
  for shot in shots:
   if shot.pool_live:shot._physics_process(DT)
  game.crowd.army.presentation.tick(DT)
  times.append(Time.get_ticks_usec()-start)

func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)

func run():
 create_timer(300).timeout.connect(func():printerr("DODGE_COUNTER_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false
 game.tuning.invincible=false;game.tuning.enemy_damage=1
 for node in [game,game.player,game.camera_rig]:node.set_process_input(false);node.set_process_unhandled_input(false)
 game.music.stop();game.training_dummy.position=home+Vector3.DOWN*1000
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 game.camera_rig.camera.global_position=home+Vector3(4,4,9);game.camera_rig.camera.look_at(home+Vector3.UP*1.2)
 var p=game.player;var army=game.army_runtime;var pool=Pool.service(game)
 pool.launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 game.impact_confirmed.connect(func(target,_strength,_time):victims.append(target))
 var state=game.model.team_progression;state.reset()
 for id in p.RogueRoster.CROSSGATE:
  if id in [34,36]:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE if id==36 else preload("res://scripts/kaz_skins.gd").DEFAULT
  check(Balance.value({}, {},id,"dodge_chance")==5 and Balance.value({}, {},id,"counter_chance")==5,"Fighter %d has independent 5%% baseline chances"%id)
  var cleaned=Balance.sanitized({"dodge_chance":-10,"counter_chance":150},id)
  check(cleaned.dodge_chance==0 and cleaned.counter_chance==100 and Balance.sanitized({"dodge_chance":NAN,"counter_chance":"bad"},id).is_empty(),"Fighter %d validates saved chance percentages"%id)
  p.select_character(id);game.update_character_tuning(id,"critical_chance",0)
  for weapon in Gear.allowed(id,game.settings):
   check(game.save_equipment_loadouts({Gear.character_key(id):{"1":"weapon:"+weapon}},game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Equip %d %s"%[id,weapon])
   check(p.character_id==id and p.model.current_weapon()==Gear.allowed(id,game.settings)[weapon].get("base_weapon",weapon),"The requested fighter appearance and weapon are actually active")
   army.clear();game.model.enemies.clear();army.refresh_kits();await frames(2)
   var row=spawn(Vector3(0,0,-1.6));var enemy=row.target
   var other=spawn(Vector3(3,0,-1.6)).target
   planted();chance(100,100)
   var hp:float=p.hp;var enemy_hp:float=enemy.hp;var other_hp:float=other.hp
   p.take_hit_from(2,Vector3.BACK,false,row.id)
   var kit=p.active_ability;var shadow=p.model.stat_counter_shadow
   check(p.hp==hp and p.velocity==Vector3.ZERO and p.invuln==0 and p.model.kagerou_tick==0,"%d %s dodges damage and knockback"%[id,weapon])
   check(not kit.shin_counter.is_empty() and kit.shin_counter.basic and shadow.visible and (p.model.shin_counter_fx==null or not p.model.shin_counter_fx.visible),"%d %s starts one independent counter without EX energy"%[id,weapon])
   check(kit.shin_counter.ticket.action=="stat_counter" and not kit.shin_counter.ticket.has("skill_id") and kit.shin_counter_chain==0,"Basic retaliation has no Counter skill bonus or speed streak")
   var anchor:Vector3=shadow.global_position
   for click in 100:tap("light_attack")
   check(kit.is_attacking() and shadow.visible,"Repeated left clicks leave the independent counter running")
   p.position=home+Vector3.RIGHT*10
   advance(13)
   check(shadow.global_position.is_equal_approx(anchor) and p.model.kagerou_shadows.all(func(s):return not s.visible),"The counter stays at contact and stat dodge emits no afterimages")
   if id==34:
    game.camera_rig.camera.global_position=home+Vector3(5,6,16);game.camera_rig.camera.look_at(home+Vector3(5,1,0))
    await capture("dodge-counter-independent")
    game.camera_rig.camera.global_position=home+Vector3(4,4,9);game.camera_rig.camera.look_at(home+Vector3.UP*1.2)
   advance(227)
   var expected=Skills.basic_damage(p.model.normal_attack_pattern())*p.damage_multiplier()
   check(is_equal_approx(enemy_hp-enemy.hp,expected) and victims.count(enemy)==1 and other.hp==other_hp,"%d %s counters only its attacker once for normal damage (%.1f / %.1f)"%[id,weapon,enemy_hp-enemy.hp,expected])
   check(p.model.sprite.position.is_zero_approx() and p.model.kagerou_tick<0 and not shadow.visible and kit.shin_counter.is_empty(),"Step and counter retire cleanly")
   check(p.impact_pause==0,"Detached melee/projectile impact cannot pause the main attack")
   for shot in shots:
    if shot.pool_live:shot.retire()
  planted();chance(0,0)
  var before:float=p.hp;p.take_hit(2,Vector3.BACK)
  check(p.hp<before and p.model.kagerou_tick<0 and p.active_ability.shin_counter.is_empty(),"Zero chances keep ordinary damage for %d"%id)

 game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").DEFAULT
 p.select_character(34);game.save_equipment_loadouts({},game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts)
 planted();chance(100,0)
 p.take_hit(2,Vector3.BACK);advance(13)
 var peak:Vector3=p.model.sprite.position
 check(not peak.is_zero_approx() and p.model.kagerou_shadows.all(func(s):return not s.visible) and not p.model.stat_counter_shadow.visible,"Dodge alone shows only the moving character")
 await capture("dodge-without-shadow")
 p.take_hit(2,Vector3.LEFT,true)
 check(p.hp==p.max_hp and p.model.kagerou_tick==13,"An overlapping projectile cannot restart the same dodge")
 advance(15);check(p.model.sprite.position==peak,"Stat dodge holds the same retreat as 陽炎")
 advance(12);check(p.model.sprite.position.is_zero_approx() and p.model.kagerou_tick<0,"Stat dodge returns exactly home at tick 40")

 army.clear();game.model.enemies.clear();army.refresh_kits();await frames(2)
 var row=spawn(Vector3(0,0,-1.6));var enemy=row.target
 planted();chance(0,100)
 var health:float=p.hp;p.take_hit_from(2,Vector3.BACK,false,row.id)
 check(p.hp<health and p.invuln==.85 and not p.active_ability.shin_counter.is_empty(),"A real damaging hit also rolls the basic counter without removing hit recovery")
 var counter:Dictionary=p.active_ability.shin_counter
 p.take_hit_from(2,Vector3.BACK,false,row.id)
 check(p.active_ability.shin_counter==counter and p.active_ability.shin_counter_pending.is_empty(),"Invulnerable contacts cannot queue counters")
 advance(240)
 check(victims.count(enemy)==1,"Damaging-hit counter connects once")
 planted();chance(0,100);p.dodge_time=.28;p.invuln=.32
 p.take_hit_from(2,Vector3.BACK,true,row.id)
 check(p.hp==p.max_hp and not p.active_ability.shin_counter.is_empty() and p.model.kagerou_tick<0,"A manually evaded hit can also trigger the independent counter")
 advance(240)
 planted();chance(0,100);p.active_ability.kagerou_enabled=true
 Skills.set_modifier(p,"kazi/kagerou","counter-fixture",{"chance":1.0})
 p.take_hit_from(2,Vector3.BACK,false,row.id);advance(13)
 check(p.hp==p.max_hp and p.model.kagerou_shadows.any(func(s):return s.visible) and p.model.stat_counter_shadow.visible,"Equipped 陽炎 afterimages and the independent counter coexist")
 advance(227);Skills.set_modifier(p,"kazi/kagerou","counter-fixture",{})
 planted();chance(100,100)
 p.take_hit_from(2,Vector3.BACK,false,2147483647)
 check(p.active_ability.shin_counter.is_empty(),"A retired or unknown attacker cannot redirect a counter to another enemy")
 planted();chance(100,100);p.hp=1;chance(0,100);p.take_hit_from(10000,Vector3.BACK,false,row.id)
 check(p.hp==0 and p.active_ability.shin_counter.is_empty() and not p.model.stat_counter_shadow.visible,"Lethal damage cannot leave a live counter")
 game.playing=true;game.model.phase="wave";p.hp=p.max_hp;planted()

 # A real native contact enters the same hit/dodge path, without a second simulation.
 army.clear();game.model.enemies.clear();army.refresh_kits();await frames(2)
 var at=home+Vector3.FORWARD*2;at.y=game.model.surface_height(at.x,at.z)
 var native_row=game.model.waves.spawn_enemy(0,at);native_row.hp=10000000;native_row.max_hp=native_row.hp
 army.import_arrivals();army.record_events=true;chance(100,100)
 var contact=false
 for i in 150:
  army.integration_tick(DT);advance(1)
  if army.event_log.any(func(event):return event.kind=="external_damage" and event.target_id==0):contact=true;break
 check(contact and p.hp==p.max_hp and not p.active_ability.shin_counter.is_empty(),"Native enemy damage triggers dodge and counter together")
 planted();chance(100,100)
 for repeat in 4:p.take_hit_from(2,Vector3.BACK,false,native_row.id);advance(240)
 await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var misses=pool.misses
 for repeat in 30:p.take_hit_from(2,Vector3.BACK,false,native_row.id);advance(240)
 await frames(3)
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources and pool.misses==misses,"Thirty repeated dodge/counters retain no nodes/resources or pool misses")
 var repeated_node_delta=get_node_count()-nodes;var repeated_resource_delta=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources
 planted();chance(100,100);p.take_hit_from(2,Vector3.BACK,false,native_row.id);p.select_character(37)
 check(not p.character_models[34].stat_counter_shadow.visible and p.character_models[34].kagerou_tick<0,"Switching fighter clears the previous reaction and shadow")

 state.reset();state.stat_points=200;chance(5,5)
 game.show_status_panel();await frames(2)
 var panel=game.status_panel
 for id in ["dodge_chance","counter_chance"]:
  var scroll:ScrollContainer=panel.buttons[id].get_parent().get_parent();scroll.ensure_control_visible(panel.buttons[id]);await frames(2)
  panel.buttons[id].pressed.emit()
  check(state.stat_ranks[id]==1 and p.combat_tuning(id)==6,"Stats spends one shared point for one percentage point on "+id)
  var before=state.stat_points
  for i in 94:panel.buttons[id].pressed.emit()
  check(p.combat_tuning(id)==100 and panel.buttons[id].disabled and not game.spend_level_stat(id) and state.stat_points==before-94,"Chance cap prevents wasted points for "+id)
  await capture("stats-"+id)
 root.size=Vector2i(960,640);await capture("stats-960x640")
 game.close_status_panel();state.reset()
 check(p.combat_tuning("dodge_chance")==5 and p.combat_tuning("counter_chance")==5,"A new run clears allocations and preserves the character baseline")
 game.update_character_tuning(p.character_id,"dodge_chance",23);game.update_character_tuning(p.character_id,"counter_chance",31)
 game.load_settings()
 check(p.combat_tuning("dodge_chance")==23 and p.combat_tuning("counter_chance")==31,"Both per-character values survive settings reload")
 times.sort()
 var report={"checks":checks,"failures":failures,"samples":times.size(),"step_p95_us":times[int(times.size()*.95)],"step_max_us":times.back(),"repeated_node_delta":repeated_node_delta,"repeated_resource_delta":repeated_resource_delta,"pool_misses":pool.misses-misses}
 FileAccess.open(OUT+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("DODGE_COUNTER_RESULT ",JSON.stringify(report))
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
