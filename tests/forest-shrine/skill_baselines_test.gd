extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Skills=preload("res://scripts/spells/skill_balance.gd")
const Qi=preload("res://scripts/qigong_combat.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const OUT="res://build/Other Files/Skill Baselines/"
const STEP=1.0/60
var shots:Array=[]

func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Captured "+name_)

func run():
 create_timer(180).timeout.connect(func():quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var p=game.player
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 game.training_dummy.position=Vector3(0,-100,0)
 for id in Skills.all():
  for row in Skills.rows(id):
   check(game.SkillBalance.value(game,id,row[0])==Skills.baseline(id,row[0]),"Original baseline %s / %s"%[id,row[0]])
  check(Skills.sanitized({id:{"count":NAN}}).is_empty(),"Count validation for "+id)
 check(Skills.sanitized({Qi.ID:{"count":12.4}})=={Qi.ID:{"count":12.0}},"Projectile count rounds to whole orbs")
 check(Skills.sanitized({Qi.ID:{"count":999}})=={Qi.ID:{"count":32.0}},"Projectile count stays bounded")
 check(Skills.sanitized({Qi.ID:{"count":8}}).is_empty(),"Original count saves sparsely")
 for id in ["kazi/combo","shin/combo","bog/combo","shin/sure-strike","shin/double-edge","shin/two-birds","shin/counter","shin/meditation","maze/blade-dance","saizo/assassination","mountain-king/avatar","mountain-king/taunt"]:
  check(Skills.all().has(id) and Skills.all()[id].native,"Native skill retains its editable original baseline: "+id)
 check(not Skills.supports("shin/meditation","hit_area") and not Skills.supports("kazi/kagerou","hit_area"),"Utility skills do not advertise a damage area")
 game.update_skill_balance(Qi.ID,"count",12)
 game.update_skill_balance(Qi.ID,"size",1.5)
 game.update_skill_balance("kazi/moon","count",9)
 game.load_settings()
 check(Skills.value(game,Qi.ID,"count")==12 and Skills.value(game,"kazi/moon","count")==9,"Independent integer baselines survive save/reload")
 game.reset_skill_balance("kazi/moon")
 check(Skills.value(game,"kazi/moon","count")==6 and Skills.value(game,Qi.ID,"count")==12,"Reset restores the selected skill's own count")
 game.show_skill_balance(false,Qi.ID);await frames()
 var editor=game.menu.find_child("SkillBalance",true,false)
 check(editor.find_child("Skill_count",true,false).step==1 and editor.find_child("SkillBaseline",true,false).text.contains("8"),"Editor shows integer orb count and its original eight-orb baseline")
 await capture("Qi settings")
 game.show_skill_balance(false,"shin/sure-strike");await frames()
 editor=game.menu.find_child("SkillBalance",true,false)
 check(editor.find_child("Skill_size",true,false).editable and editor.find_child("Skill_hit_area",true,false).editable,"Native skill exposes real visual and area controls")
 await capture("Shin skill settings")
 game.resume()
 p.select_character(34);fresh()
 var home=open_home(p)
 check(home.is_finite(),"Found open, level Wind Meadow ground for all twelve native target paths")
 if not home.is_finite():quit(1);return
 game.model.update_vision(home)
 p.global_position=home
 game.update_character_tuning(34,"critical_chance",0)
 var army=game.army_runtime
 var targets:Array=[]
 for i in 12:
  var point=home+Vector3(sin(i*TAU/12),0,-cos(i*TAU/12))*(20.0+i*1.5)
  point.y=game.model.surface_height(point.x,point.z)+.1
  var row=game.model.waves.spawn_enemy(0,point,-1,i);row.hp=100000;row.max_hp=row.hp
  army.import_arrivals();targets.append(game.actors[row.id])
 army.integration_tick(STEP);army.sync_targets();game.crowd.present_army(army.render_snapshot(),[])
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):shot.set_physics_process(false);shots.append(shot))
 var instance=p.spell_loadout._instance(Qi.ID)
 var qi=instance.controller
 for count_ in [8,12,1,32]:
  game.reset_skill_balance(Qi.ID);game.update_skill_balance(Qi.ID,"count",count_)
  p.attack_chain.reset();p.spell_loadout.magic_combo_steps=0;qi.clear_cooldowns();shots.clear()
  var before=targets.map(func(target):return float(army.unit_state(target.handle).hp))
  qi.start_cast()
  if count_==8:game.update_skill_balance(Qi.ID,"count",12)
  for tick in 180:qi.tick(STEP)
  check(shots.size()==count_*2,"Qi releases exactly %d orbs from its cast snapshot"%count_)
  var locked=shots.filter(func(shot):return shot.target!=null)
  check(locked.size()==mini(count_,12)*2 and locked.all(func(shot):return locked.filter(func(other):return other.target==shot.target).size()==2),"Qi count %d selects distinct nearest targets and leaves excess shots untargeted"%count_)
  if count_==12:
   game.camera_rig.camera.global_position=home+Vector3(9,10,18)
   game.camera_rig.camera.look_at(home+Vector3.UP)
   for tick in 18:
    for shot in shots:
     if shot.pool_live:shot._physics_process(STEP)
   await capture("Twelve Qi orbs")
  for tick in 360:
   for shot in shots:
    if shot.pool_live:shot._physics_process(STEP)
  var damaged=0
  for i in targets.size():
   var damage=before[i]-float(army.unit_state(targets[i].handle).hp)
   if damage>0:damaged+=1;check(is_equal_approx(damage,750),"An orb keeps one original 750-damage contact (got %s)"%damage)
  check(damaged==mini(count_,12),"Qi count %d damages %d native targets"%[count_,damaged])
  check(shots.all(func(shot):return not shot.pool_live and shot.target==null),"Finished orbs clear targets and return to the pool")
 check(pool.misses==0,"Count changes prepare projectile capacity outside combat")
 await verify_independent_area(p,pool,targets[0])
 game.reset_skill_balance(Qi.ID)
 game.reset_skill_balance("kazi/fire")
 game.update_skill_balance(Qi.ID,"count",32)
 var warm_nodes=get_node_count();var warm_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var created=pool.created
 for cycle in 4:
  qi.clear_cooldowns();p.attack_chain.reset();shots.clear();qi.start_cast()
  for tick in 180:
   qi.tick(STEP)
   for shot in pool.all[qi.pool_key]:
    if shot.pool_live:shot._physics_process(STEP)
 check(get_node_count()==warm_nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=warm_resources and pool.created==created and pool.misses==0,"Repeated casts reuse prepared nodes/resources without pool misses")
 for shot in pool.all[qi.pool_key]:
  if shot.pool_live:shot.retire()
 game.reset_skill_balance(Qi.ID)
 for id in ["kazi/moon","kazi/wind","kazi/fire","kazi/ice","kazi/meteor"]:
  game.update_skill_balance(id,"count",9)
  var cast=p.spell_loadout._instance(id).controller
  p.attack_chain.reset();p.spell_loadout.magic_combo_steps=0;cast.clear_cooldowns();shots.clear();cast.start_cast()
  for tick in 360:cast.tick(STEP)
  check(shots.size()==18,"%s uses its own nine-projectile / target baseline"%id)
  for shot in shots:shot.retire()
  cast.cancel();game.reset_skill_balance(id)
 p.spell_loadout.equip(34,"equip",Qi.ID)
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p)
 check(mirrors.cast(),"Five native-owned allies are prepared for simultaneous count tuning")
 for count_ in [12,16]:
  game.update_skill_balance(Qi.ID,"count",count_)
  shots.clear()
  for body in mirrors.bodies:
   var cast=body.spell_loadout._instance(Qi.ID).controller
   cast.clear_cooldowns();cast.start_cast()
   for tick in 180:cast.tick(STEP)
  check(shots.size()==5*count_*2 and shots.all(func(shot):return shot.hero.mirror_copy and shot.attack_ticket.allied and int(shot.attack_ticket.skill_count)==count_),"Five allies release %d distinct counted volleys"%count_)
  for shot in shots:shot.retire()
 check(pool.misses==0,"Live count edits also prepare all allied projectile owners")
 mirrors.dispose();await frames();game.reset_skill_balance(Qi.ID)
 p.select_character(37);fresh();p.global_position=home
 army.integration_tick(STEP)
 var driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 await driver.advance(1,func(_dt):
  for tick in 20:p._physics_process(STEP))
 game.update_skill_balance("shin/combo","count",3)
 p.active_ability.start_combo()
 check(p.active_ability.ticket.get("skill_id","")=="shin/combo","Native combo identifies its own character baseline")
 for tick in 240:p._physics_process(STEP)
 check(p.active_ability.combo_strikes==3 and not p.active_ability.is_attacking(),"Native Shin combo obeys its three-strike setting")
 game.reset_skill_balance("shin/combo")
 var victim=targets[0]
 var victim_origin:Vector3=victim.global_position
 army.set_pose(victim.handle,home+Vector3.FORWARD*p.active_ability.melee_visual_reach()*.8,0);army.sync_targets()
 p.global_position=home;p.facing=Vector3.FORWARD
 game.update_skill_balance("shin/sure-strike","size",3)
 game.update_skill_balance("shin/sure-strike","hit_area",.1)
 p.attack_chain.reset();p.active_ability.ticket=p.attack_chain.begin("shin_sure_strike")
 var before=victim.hp
 p.active_ability.ticket.shin_blast_forward=Vector3.FORWARD
 p.active_ability.start_sure_strike_attack();p.active_ability.advance_attack(p.active_ability.duration+.001);army.flush_presentation()
 check(victim.hp==before,"A larger native skill visual does not override its small hit area")
 var fx=game.crowd.army.presentation
 check(not fx.effects.any(func(effect):return effect.kind=="shin_sure_strike"),"A missed weapon cannot create a body explosion even with a large visual setting")
 game.update_skill_balance("shin/sure-strike","size",.5)
 game.update_skill_balance("shin/sure-strike","hit_area",1)
 p.active_ability.ticket=p.attack_chain.begin("shin_sure_strike")
 p.active_ability.ticket.shin_blast_forward=Vector3.FORWARD
 p.active_ability.start_sure_strike_attack();p.active_ability.advance_attack(p.active_ability.duration+.001);army.flush_presentation()
 check(victim.hp<before,"A smaller native visual still hits inside its original damage area")
 game.reset_skill_balance("shin/sure-strike")
 army.set_pose(victim.handle,victim_origin,0);army.sync_targets()
 p.select_character(36);fresh();p.global_position=home;p.active_ability.set_weapon(p.RogueRoster.MazeWeapon.KUNAI)
 game.update_skill_balance("maze/blade-dance","count",10)
 shots.clear();p.active_ability.start_blade_dance();p.active_ability.throw_blade_dance()
 check(shots.size()==10 and shots.all(func(shot):return shot.attack_ticket.skill_id=="maze/blade-dance"),"Blade Dance uses its own ten-target baseline")
 for shot in shots:shot.retire()
 game.reset_skill_balance("maze/blade-dance")
 check(Skills.value(game,"saizo/blade-dance","count")==6,"Maze edits leave Saizo's six-kunai baseline intact")
 p.select_character(p.RogueRoster.LANCELOT_ID);fresh();p.global_position=home
 await driver.advance(1,func(_dt):
  for tick in 20:p._physics_process(STEP))
 game.update_skill_balance("lancelot/random-shot","count",4)
 shots.clear();p.active_ability.start_random_shot()
 game.update_skill_balance("lancelot/random-shot","count",6)
 for tick in 500:p._physics_process(STEP)
 check(shots.size()==4 and shots.all(func(shot):return shot.attack_ticket.skill_id=="lancelot/random-shot" and int(shot.attack_ticket.skill_count)==4),"亂射 keeps its four-arrow baseline throughout the volley after an edit")
 for shot in shots:shot.retire()
 game.reset_skill_balance("lancelot/random-shot")
 game.queue_free();paused=false;await frames()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SKILL_BASELINES_RESULT checks=%d failures=%d skills=%d"%[checks,failures,Skills.all().size()]);quit(1 if failures else 0)

func verify_independent_area(p,pool,target):
 p.spell_loadout._instance("kazi/fire")
 var Shot=Qi.Shot
 var at=AttackChain.aim_point(target,target.global_position+Vector3.UP)
 var radius=Shot.DIAMETER*.5
 for spec in [[3.0,1.0,false],[1.0,2.0,true]]:
  game.update_skill_balance(Qi.ID,"size",spec[0]);game.update_skill_balance(Qi.ID,"hit_area",spec[1])
  var ticket=p.attack_chain.begin(Qi.ID)
  var shot=pool.launch(p,Shot,Qi.ID,{"position":at+Vector3.RIGHT*radius*1.5,"target":target,"velocity":Vector3.ZERO,"damage":10.0,"attack_ticket":ticket})
  var before=target.hp
  shot._physics_process(STEP)
  check((target.hp<before)==spec[2],"Qi visual %s× / area %s× changes only the intended contact radius"%[spec[0],spec[1]])
  if shot.pool_live:shot.retire()
 var Element=Qi.Element
 for spec in [[3.0,1.0,false],[1.0,2.0,true]]:
  game.update_skill_balance("kazi/fire","size",spec[0]);game.update_skill_balance("kazi/fire","hit_area",spec[1])
  var shot=pool.launch(p,Element,"kazi/fire",{"kind":"fire","position":at+Vector3.RIGHT*3.0,"effect_height":5.0,"damage":10.0,"attack_ticket":p.attack_chain.begin("kazi/fire")})
  var before=target.hp
  shot.pulse(shot.global_position,2.0,{})
  check((target.hp<before)==spec[2],"Fire visual %s× / area %s× changes only the intended damage area"%[spec[0],spec[1]])
  shot.retire()

func open_home(p)->Vector3:
 for candidate in [Vector3(-150,0,127),Vector3(-120,0,125),Vector3(-90,0,130),Vector3(-150,0,90),Vector3(100,0,100),Vector3(120,0,120),Vector3(-110,0,80),Vector3(80,0,100)]:
  candidate.y=game.model.surface_height(candidate.x,candidate.z)+.05
  p.global_position=candidate
  var clear=true
  for i in 12:
   var point=candidate+Vector3(sin(i*TAU/12),0,-cos(i*TAU/12))*(20.0+i*1.5)
   point.y=game.model.surface_height(point.x,point.z)+.05
   if not p.active_ability.combo_landing(candidate,point).is_finite() or not AttackChain.clear_line(p,candidate+Vector3.UP,point+Vector3.UP):
    clear=false;break
  if clear:return candidate
 return Vector3.INF
