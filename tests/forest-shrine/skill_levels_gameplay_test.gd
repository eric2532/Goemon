extends "res://tests/forest-shrine/crossgate_blast_coverage_test.gd"
const ProjectilePool=preload("res://scripts/character_projectile_pool.gd")
const Evidence="res://build/Other Files/Skill Levels/"
var launched:Array=[]
var allied_shots:Array=[]

func shot_picture(filename:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.hide();game.army_runtime.flush_presentation();game.crowd.army.presentation.draw_effects()
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(Evidence+filename+".png")==OK,"Rendered "+filename)

func release_cast(cast):
 cast.cancel(true);cast.clear_cooldowns();game.player.attack_chain.reset();launched.clear()
 game.player.mana=game.player.max_mana
 cast.start_cast()
 for i in 360:
  var before=launched.size()
  cast.tick(DT)
  if cast.punches() and launched.size()>before:
   check(cast.native_contact==1,"The complete Qi volley releases on the first native contact")
  if not cast.is_attacking():break

func retire_shots():
 for shot in launched:
  if shot.pool_live:shot.retire()
 launched.clear()

func run():
 create_timer(240).timeout.connect(func():printerr("SKILL_LEVEL_GAMEPLAY_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(Evidence)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 for node in [game,game.player,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 var p=game.player;var army=game.army_runtime
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 game.model.falan_floor=0;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*1000
 var pool=ProjectilePool.service(game)
 pool.launched.connect(func(shot):
  shot.set_physics_process(false)
  if shot.hero==p:launched.append(shot)
  elif shot.hero.ai_controlled:allied_shots.append(shot))
 for fighter in p.RogueRoster.CROSSGATE:
  p.select_character(fighter);fresh();game.reset_character_tuning(fighter);game.update_character_tuning(fighter,"critical_chance",0)
  p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD
  await driver.advance(20,advance)
  for id in ["kazi/qigong","kazi/moon"]:
   var cast=p.spell_loadout._instance(id).controller
   for level_ in [1,30]:
    Skills.set_level(p,id,level_)
    release_cast(cast)
    var count_=1 if level_==1 else 16
    var damage=1.5 if level_==1 else 7.3
    if id=="kazi/moon":count_=3 if level_==1 else 10;damage=1.4 if level_==1 else 5.75
    check(launched.size()==count_,"Fighter %d %s Lv%d has the total cast projectile count, not count × native contacts"%[fighter,id,level_])
    if id=="kazi/qigong":check(launched.all(func(shot):return shot.start_delay>=0.0 and shot.start_delay<=.05),"Every Qi orb starts within the same 50 ms volley window")
    check(launched.all(func(shot):return is_equal_approx(shot.damage,damage*Skills.normal_damage(p))),"Each projectile retains its specified normal-attack multiplier")
    if not launched.is_empty():
     var first=launched[0];var before=first.attack_ticket.duplicate(true)
     Skills.set_level(p,id,1 if level_==30 else 30)
     check(first.attack_ticket==before,"Level changes do not rewrite released spell tickets")
    if fighter==34 and id=="kazi/qigong" and level_==30:
     game.camera_rig.camera.global_position=home+Vector3(16,13,24);game.camera_rig.camera.look_at(home+Vector3(0,2,-8))
     for tick in 12:
      for shot in launched:shot._physics_process(DT)
      if tick in [2,5,11]:await shot_picture("qi-volley-%02d-ms"%roundi((tick+1)*DT*1000))
     check(launched.all(func(shot):return shot.start_delay<=0.0),"All sixteen Qi orbs have left the caster together")
    retire_shots()
   cast.cancel(true)
 p.select_character(34);fresh();p.position=home;p.facing=Vector3.FORWARD
 await driver.advance(20,advance)
 army.clear();army.refresh_kits();var victim=spawn(Vector3(0,0,-10))
 game.camera_rig.set_process(false)
 game.camera_rig.camera.global_position=home+Vector3(22,15,25);game.camera_rig.camera.look_at(home+Vector3(0,3,-9))
 for kind in ["fire","ice","wind","meteor"]:
  var id="kazi/"+kind;var cast=p.spell_loadout._instance(id).controller
  for level_ in [1,10,11,19,20,30]:
   Skills.set_level(p,id,level_);release_cast(cast)
   check(not launched.is_empty(),"%s Lv%d launches at a living native enemy"%[kind,level_])
   var before=victim.hp
   var pulses={"fire":1,"ice":3,"wind":4,"meteor":2}[kind]
   for shot in launched:
    check(shot.effect_tier==Skills.Levels.shine_tier(level_),"Original effect tier matches level band")
    for phase in pulses:shot.pulse(AttackChain.aim_point(victim),10,shot.cast_hits[phase])
   check(is_equal_approx(before-victim.hp,100.0*level_+50.0),"%s Lv%d total damage is split across native contacts, overlapping areas and pulses (got %.2f)"%[kind,level_,before-victim.hp])
   if level_ in [1,11,20] and DisplayServer.get_name()!="headless":
    for i in (15 if kind=="ice" else 27 if kind=="fire" else 10 if kind=="wind" else 24):
     for shot in launched:
      if shot.pool_live:shot._physics_process(DT)
    await shot_picture("%s-level-%02d"%[kind,level_])
   retire_shots()
   if level_ in [1,11,20,30]:
    release_cast(cast);before=victim.hp
    for tick in 600:
     for shot in launched:
      if shot.pool_live:shot._physics_process(DT)
    check(is_equal_approx(before-victim.hp,100.0*level_+50.0),"%s Lv%d actual projectile timing and collision deliver the per-target budget (got %.2f)"%[kind,level_,before-victim.hp])
    retire_shots()
  cast.cancel(true)
 Skills.set_level(p,"kazi/fire",30)
 check(Skills.set_modifier(p,"kazi/fire","test-item",{"count":3}),"An item can add three targets")
 check(Skills.effective(p,"kazi/fire","count")==10,"Lv30 Fire plus item has ten targets")
 Skills.set_modifier(p,"kazi/fire","test-item",{})
 check(Skills.effective(p,"kazi/fire","count")==7,"Removing an item restores the level count")
 # Nearby unselected enemies must not turn a one-target spell into an unlimited area attack.
 army.clear();army.refresh_kits()
 var crowd=[]
 for i in 11:crowd.append(spawn(Vector3((i-5)*.7,0,-10)))
 for kind in ["fire","ice","wind","meteor"]:
  var id="kazi/"+kind;var cast=p.spell_loadout._instance(id).controller
  for level_ in [1,30]:
   Skills.set_level(p,id,level_)
   Skills.set_modifier(p,id,"count-item",{"count":3} if level_==30 else {})
   var health=crowd.map(func(enemy):return enemy.hp)
   release_cast(cast)
   var selected=launched[0].attack_ticket.element_target_ids if not launched.is_empty() else {}
   check(selected.size()==(1 if level_==1 else 10),"%s Lv%d selects exactly the level plus item target limit"%[kind,level_])
   for tick in 600:
    for shot in launched:
     if shot.pool_live:shot._physics_process(DT)
    if kind=="fire" and level_==30 and tick==30:await shot_picture("fire-ten-targets")
   for i in crowd.size():
    var expected=100.0*level_+50.0 if selected.has(crowd[i].get_instance_id()) else 0.0
    check(is_equal_approx(health[i]-crowd[i].hp,expected),"%s Lv%d crowded target %d receives only its own cast budget (%.2f vs %.2f)"%[kind,level_,i,health[i]-crowd[i].hp,expected])
   retire_shots();Skills.set_modifier(p,id,"count-item",{})
 army.clear();army.refresh_kits();victim=spawn(Vector3(0,0,-10))
 check(not Skills.set_level(p,"kazi/fire",NAN) and not Skills.set_modifier(p,"kazi/fire","bad",{"count":INF}),"Nonfinite modifier inputs are rejected")
 Skills.set_modifier(p,"kazi/fire","penalty-a",{"damage":-.8});Skills.set_modifier(p,"kazi/fire","penalty-b",{"damage":-.8})
 check(Skills.effective(p,"kazi/fire","damage")==0,"Stacked item penalties cannot turn damage negative")
 Skills.set_modifier(p,"kazi/fire","penalty-a",{});Skills.set_modifier(p,"kazi/fire","penalty-b",{})
 Skills.set_level(p,"maze/qigong",20)
 check(Skills.level_for(p,"kazi/qigong")==20,"Gold and other Qi colors share one learned level")
 Skills.set_modifier(p,"kazi/qigong","color-item",{"qi_color":Color.RED})
 var qi=p.spell_loadout._instance("kazi/qigong").controller
 for row in [[9,0],[10,10],[19,10],[20,20],[29,20],[30,30]]:
  Skills.set_level(p,"kazi/qigong",row[0]);release_cast(qi)
  check(not launched.is_empty() and launched.all(func(shot):return shot.attack_ticket.critical_chance==row[1]),"Qi Lv%d snapshots its skill-only critical milestone"%row[0])
  check(not launched.is_empty() and launched.all(func(shot):return shot.visual.material_override==(shot.ex_material if row[0]==30 else shot.material)),"Qi Lv%d selects the correct pooled projectile art"%row[0])
  retire_shots()
 Skills.set_level(p,"kazi/qigong",29);release_cast(qi)
 check(not launched.is_empty() and launched.all(func(shot):return shot.visual.material_override==shot.material),"A returned EX projectile resets to ordinary art on reuse")
 retire_shots()
 Skills.set_level(p,"kazi/qigong",30)
 var moon=p.spell_loadout._instance("kazi/moon").controller
 Skills.set_level(p,"kazi/moon",30);release_cast(moon)
 check(launched.all(func(shot):return shot.attack_ticket.critical_chance==0),"Qi critical milestones do not leak into Moon Wave")
 for tick in 6:
  for shot in launched:
   if shot.pool_live:shot._physics_process(DT)
 await shot_picture("moon-level-30")
 retire_shots()
 release_cast(qi)
 check(launched.all(func(shot):return shot.attack_ticket.qi_color==Color.RED and shot.visual.get_instance_shader_parameter("qi_tint")==Color.RED),"A color item uses per-instance shader parameters")
 for tick in 6:
  for shot in launched:
   if shot.pool_live:shot._physics_process(DT)
 await shot_picture("qi-level-30-red-item")
 retire_shots();Skills.set_modifier(p,"kazi/qigong","color-item",{})
 release_cast(qi)
 check(launched.all(func(shot):return shot.visual.get_instance_shader_parameter("qi_tint")==Color.WHITE),"Removing a Qi color item resets reused projectile instances")
 var regular_count=launched.size()
 retire_shots()
 var chrome_owner=preload("res://scripts/forest/equipment.gd").wearer(p)
 game.settings.cosmetic_loadouts[chrome_owner]={"qi_color":"qi-chrome"}
 release_cast(qi)
 check(launched.size()==regular_count and regular_count>0 and launched.all(func(shot):return shot.attack_ticket.qi_chrome and shot.visual.get_instance_shader_parameter("qi_chrome")==1.0),"Level-30 chrome Qi retains the same complete volley as regular blue")
 await shot_picture("qi-level-30-chrome")
 retire_shots()
 # Warm the repeated workload before checking allocation and timing.
 for i in 2:release_cast(qi);retire_shots()
 await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var misses=pool.misses
 var times=[]
 for i in 12:
  var start=Time.get_ticks_usec();release_cast(qi);retire_shots();times.append(Time.get_ticks_usec()-start)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated leveled Qi casts reuse prepared nodes and resources")
 check(pool.misses==misses,"Repeated leveled Qi casts do not allocate missed projectile leases")
 times.sort();print("LEVELED_QI_CAST_US p95=",times[floori(times.size()*.95)]," max=",times.back())
 game.settings.cosmetic_loadouts.erase(chrome_owner)
 p.select_character(35);fresh();p.position=home
 var heal=p.spell_loadout._instance("uru/recovery").controller
 for row in [[1,200.0,0],[10,290.0,1],[11,300.0,1],[20,390.0,2],[25,440.0,2],[26,450.0,2],[30,490.0,4]]:
  Skills.set_level(p,"uru/recovery",row[0]);p.max_hp=2000;p.hp=1000;p.mana=p.max_mana
  heal.start_recovery()
  if int(row[0]) in [1,11,20,26] and DisplayServer.get_name()!="headless":
   for i in 43:heal.tick(DT)
   await shot_picture("recovery-level-%02d"%int(row[0]))
  for i in 100:heal.tick(DT)
  check(is_equal_approx(p.hp-1000,row[1]) and heal.tier==row[2],"Recovery Lv%d heals current missing HP once and uses its original tier"%row[0])
  for i in 100:heal.tick(DT)
  check(is_equal_approx(p.hp-1000,row[1]),"Recovery does not leave six automatic heal charges")
 Skills.set_level(p,"uru/recovery",1);Skills.set_modifier(p,"uru/recovery","healing-item",{"healing":.1})
 p.hp=1000;p.mana=p.max_mana;heal.start_recovery();Skills.set_modifier(p,"uru/recovery","healing-item",{})
 for i in 100:heal.tick(DT)
 check(is_equal_approx(p.hp,1300),"Healing item modifiers are snapshotted when casting")
 p.hp=1500;heal.start_recovery();p.hp=500
 for i in 100:heal.tick(DT)
 check(is_equal_approx(p.hp,800),"Recovery uses missing HP when the heal resolves, including damage taken during casting")
 p.hp=p.max_hp;heal.start_recovery()
 for i in 100:heal.tick(DT)
 check(p.hp==p.max_hp,"Recovery never exceeds full health")
 p.hp=100;p.mana=p.max_mana;heal.start_recovery();p.hp=0
 for i in 100:heal.tick(DT)
 check(p.hp==0,"Recovery cannot revive a dead caster")
 heal.cancel();p.hp=p.max_hp
 p.select_character(36);fresh();p.position=home;p.facing=Vector3.FORWARD
 await driver.advance(20,advance)
 Skills.set_level(p,"kazi/qigong",30);p.spell_loadout.equip(36,"special_4","kazi/qigong")
 var mirror=p.spell_loadout._instance("blademaster/mirror-image").controller.mirrors
 for level_ in [1,30]:
  Skills.set_level(p,"blademaster/mirror-image",level_)
  check(mirror.cast(),"Maze mirrors find valid clear ground")
  check(mirror.handles.size()==(3 if level_==1 else 9),"Maze mirror count follows the skill level")
  var damage=.85 if level_==1 else 2.3
  check(mirror.bodies.slice(0,mirror.handles.size()).all(func(body):return is_equal_approx(body.damage_multiplier(),p.damage_multiplier()*damage)),"Each native-owned mirror inherits caster damage once")
  await shot_picture("maze-copies-level-%02d"%level_)
  if level_==30:
   var misses_before=pool.misses;allied_shots.clear()
   var controllers=[]
   for body in mirror.bodies.slice(0,mirror.handles.size()):
    var cast=body.spell_loadout._instance("kazi/qigong").controller
    cast.clear_cooldowns();cast.start_cast();controllers.append(cast)
   for frame in 360:
    for cast in controllers:cast.tick(DT)
   check(allied_shots.size()==144,"Nine native-owned allies simultaneously release 16 Qi blasts each")
   check(pool.misses==misses_before,"Simultaneous allied casts use capacity prepared before combat")
   for shot in allied_shots:
    if shot.pool_live:shot.retire()
   allied_shots.clear()
  mirror.clear()
 p.select_character(43);fresh();p.position=home;p.facing=Vector3.FORWARD
 await driver.advance(20,advance)
 var shadow=p.active_ability.mirrors
 for level_ in [1,30]:
  Skills.set_level(p,"lancelot/barrage-shadows",level_)
  check(shadow.cast(),"Archer shadows find valid clear ground")
  check(shadow.handles.size()==(1 if level_==1 else 7),"Archer shadow count follows the skill level")
  shadow.clear()
 p.team_progression.reset()
 check(Skills.level_for(p,"kazi/qigong")==1 and p.team_progression.skill_modifiers.is_empty(),"A new run resets skill levels and item modifiers")
 game.show_skill_balance(true,"kazi/qigong");await frames(3)
 var ui=game.menu.find_child("SkillBalance",true,false)
 check(ui!=null and ui.find_child("RunSkill_level",true,false).max_value==30,"Existing Skill Balance offers manual run levels")
 ui.find_child("RunSkill_level",true,false).value=30
 check(Skills.level_for(p,"kazi/qigong")==30,"The manual level control changes the shared run skill level")
 ui.find_child("RunSkill_bonus",true,false).value=3
 check(Skills.effective(p,"kazi/qigong","count")==19,"The manual extra-count control uses the item modifier path")
 ui.find_child("Skill_count",true,false).value=1
 check(Skills.effective(p,"kazi/qigong","count")==20 and game.settings.skill_balance["kazi/qigong"].count==9,"Saved extra-count controls preserve compatible saved tuning")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(Evidence+"run-level-controls.png")==OK,"Captured level controls")
 print("SKILL_LEVEL_GAMEPLAY checks=%d failures=%d"%[checks,failures])
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
