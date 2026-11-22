extends "res://tests/forest-shrine/skill_baselines_test.gd"

const OUTPUT="res://build/Other Files/Qi Upgrades/"
var targets:Array=[]
var shot_times:Array[int]=[]

func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 await create_timer(.25,true).timeout
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUTPUT+name_+".png")==OK,"Captured "+name_)

func present(id:String="qi_orbs",rarity:int=0):
 var progression=game.model.team_progression
 progression.award_kills(progression.kills_required())
 game.show_team_upgrade()
 progression.offer.assign([id,"qi_area" if id=="qi_orbs" else "qi_orbs","pet_damage"])
 progression.offer_rarities.assign([rarity,0,0]);game.team_upgrade_picker.refresh()

func pick(id:String,rarity:int=0):
 present(id,rarity)
 var level_=game.model.team_progression.choice_level()
 game.team_upgrade_picker.ready_at=0
 game.team_upgrade_picker.buttons[0].pressed.emit()
 check(not is_instance_valid(game.team_upgrade_picker) and game.model.team_progression.pending()==0,"Real card button consumes exactly one "+id+" choice")
 check(not game.choose_team_upgrade(id,level_),"A stale click cannot buy the same skill rank twice")

func cast_orbs(controller,count_:int):
 var p=game.player
 controller.clear_cooldowns();p.attack_chain.reset();p.spell_loadout.magic_combo_steps=0;shots.clear()
 var before=targets.map(func(target):return target.hp)
 controller.start_cast()
 for tick in 180:controller.tick(STEP)
 check(shots.size()==count_*p.model.normal_attack_pattern().contacts.size(),"The next real cast releases %d orbs"%count_)
 var locked=shots.filter(func(shot):return shot.target!=null)
 check(locked.size()==mini(count_,targets.size())*p.model.normal_attack_pattern().contacts.size() and locked.all(func(shot):return locked.filter(func(other):return other.target==shot.target).size()==p.model.normal_attack_pattern().contacts.size()),"Extra orbs select additional distinct native targets")
 for tick in 480:
  for shot in shots:
   if shot.pool_live:
    var started=Time.get_ticks_usec();shot._physics_process(STEP);shot_times.append(Time.get_ticks_usec()-started)
 var strike_damage=Qi.DAMAGE*p.damage_multiplier()/p.model.normal_attack_pattern().contacts.size()
 var damaged=0
 for i in targets.size():
  var damage=before[i]-float(targets[i].hp)
  if damage>0:
   damaged+=1
   check(is_equal_approx(damage/strike_damage,roundf(damage/strike_damage)) and damage<=strike_damage*shots.size(),"Each actual orb contact keeps its split damage; wider hits may overlap")
 check(damaged>=mini(count_,targets.size()) and shots.all(func(shot):return not shot.pool_live and shot.target==null),"Every counted contact finishes once and clears its target")

func run():
 create_timer(180).timeout.connect(func():quit(1))
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 check(not game.settings.forest_level_up_cards and not game.model.team_progression.cards_enabled,"Normal source play keeps level-up cards disabled by default")
 var disabled=game.model.team_progression
 disabled.award_kills(20)
 check(disabled.level==2 and disabled.pending()==0 and disabled.offer.is_empty(),"Disabled cards keep XP moving without pausing for choices")
 disabled.reset();game.settings.forest_level_up_cards=true;disabled.cards_enabled=true
 var p=game.player
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 game.training_dummy.position=Vector3(0,-100,0)
 p.select_character(34);fresh()
 var home=open_home(p)
 check(home.is_finite(),"Found clear arena ground for native contacts")
 if not home.is_finite():quit(1);return
 p.position=home;game.model.update_vision(home)
 game.update_character_tuning(34,"critical_chance",0)
 check(p.spell_loadout.equip(34,"equip",Qi.ID),"Equip Qi Orbs through the normal loadout")
 var progression=game.model.team_progression
 check(progression.skills.has(Qi.ID) and progression.eligible("qi_orbs",0),"The equipped spell enables its two upgrade paths")
 game.update_skill_balance(Qi.ID,"count",10);game.update_skill_balance(Qi.ID,"hit_area",1.5);game.update_skill_balance(Qi.ID,"size",1.3)
 var saved=game.settings.skill_balance.duplicate(true)
 var before_ticket=p.attack_chain.begin(Qi.ID)
 present()
 var picker=game.team_upgrade_picker
 check(picker.buttons[0].find_child("Rank",true,false).text.contains("ORBS 10 → 12"),"Orb card previews the actual custom baseline")
 check(picker.buttons[1].find_child("Rank",true,false).text.contains("1.50 → ×1.80"),"Area card previews its multiplier above the custom baseline")
 check(picker.buttons[0].find_child("Icon",true,false).texture==Skills.Catalog.KAZI_ICONS[Qi.ID],"Skill cards reuse the recovered Qi icon")
 for button in picker.buttons:
  for label_ in ["Title","Description","Rank"]:
   check(button.get_global_rect().encloses(button.find_child(label_,true,false).get_global_rect()),"Card text fits: "+label_)
 await capture("Qi upgrade choices")
 root.size=Vector2i(960,640);await frames(3);await capture("Qi upgrade choices small")
 root.size=Vector2i(1280,800);await frames(3)
 picker.ready_at=0;picker.buttons[0].pressed.emit()
 check(progression.ranks.qi_orbs==1 and before_ticket.skill_count==10 and before_ticket.skill_hit_area==1.5,"The choice adds two orbs without changing an earlier cast ticket")
 pick("qi_area",1)
 check(progression.ranks.qi_area==2 and is_equal_approx(Skills.effective(p,Qi.ID,"hit_area"),2.1),"Silver area card adds two ranks without compounding the baseline")
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):shot.set_physics_process(false);shots.append(shot))
 var army=game.army_runtime
 for i in 14:
  var point=home+Vector3(sin(i*TAU/14),0,-cos(i*TAU/14))*(6.0+i*.6)
  point.y=game.model.surface_height(point.x,point.z)+.1
  var row=game.model.waves.spawn_enemy(0,point,-1,i);row.hp=100000;row.max_hp=row.hp;army.import_arrivals();targets.append(game.actors[row.id])
 army.integration_tick(STEP);army.sync_targets();game.crowd.present_army(army.render_snapshot(),[])
 var controller=p.spell_loadout._instance(Qi.ID).controller
 cast_orbs(controller,12)
 var victim=targets[0];var at=AttackChain.aim_point(victim,victim.global_position+Vector3.UP)
 var edge=AttackChain.aim_point(victim,at+Vector3.RIGHT*100)
 var radius=Qi.Shot.DIAMETER*.5*1.5
 for upgraded in [false,true]:
  var ticket=p.attack_chain.begin(Qi.ID)
  if not upgraded:ticket.skill_hit_area=Skills.value(game,Qi.ID,"hit_area")
  var shot=pool.launch(p,Qi.Shot,Qi.ID,{"position":edge+Vector3.RIGHT*radius*1.1,"target":victim,"velocity":Vector3.ZERO,"damage":10.0,"attack_ticket":ticket})
  var hp=victim.hp;shot._physics_process(STEP)
  check((victim.hp<hp)==upgraded,"Only the area upgrade reaches the same native target outside baseline contact")
  if shot.pool_live:shot.retire()
 pick("qi_orbs",3);pick("qi_orbs",2)
 check(progression.ranks.qi_orbs==8 and Skills.effective(p,Qi.ID,"count")==26,"Rarities stack to eight ranks / sixteen bonus orbs")
 check(not progression.eligible("qi_orbs",0),"Completed orb path is removed from later drafts")
 pick("qi_area",3);pick("qi_area",1)
 check(progression.ranks.qi_area==8 and is_equal_approx(Skills.effective(p,Qi.ID,"hit_area"),3.9),"Area path reaches its bounded 2.6-times baseline")
 for i in 100:
  progression.roll_offer();check(not progression.offer.has("qi_orbs") and not progression.offer.has("qi_area"),"Capped paths are never wasted offers")
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p)
 p.refresh_max_health(true)
 check(mirrors.cast(),"Five native-owned allies still use the shared spell owner")
 shots.clear()
 for body in mirrors.bodies:
  var cast=body.spell_loadout._instance(Qi.ID).controller;cast.clear_cooldowns();cast.start_cast()
  for tick in 180:cast.tick(STEP)
 check(shots.size()==100 and shots.all(func(shot):return shot.attack_ticket.allied and int(shot.attack_ticket.skill_count)==10 and is_equal_approx(shot.attack_ticket.skill_hit_area,1.5)),"Player skill paths leave all five allies at their own saved baseline")
 for shot in shots:shot.retire()
 mirrors.dispose();await frames()
 p.select_character(36);fresh();p.position=home
 p.active_ability.set_weapon(p.RogueRoster.MazeWeapon.FIST)
 game.update_character_tuning(36,"critical_chance",0)
 cast_orbs(p.spell_loadout._instance(Skills.Catalog.MAZE_QI).controller,24)
 p.select_character(43)
 check(not progression.eligible("qi_area",0) and progression.ranks.qi_orbs==8,"Switching away preserves run ranks without offering unused skills")
 p.select_character(34);p.position=home
 check(Skills.effective(p,Qi.ID,"count")==26,"Returning to the skill restores its earned run path")
 check(game.settings.skill_balance==saved,"Level-up choices never rewrite saved baselines")
 var config=ConfigFile.new();config.load(game.settings_path)
 check(config.get_value("settings","skill_balance")==saved,"The on-disk baseline remains unchanged too")
 game.update_skill_balance(Qi.ID,"count",32)
 controller=p.spell_loadout._instance(Qi.ID).controller
 cast_orbs(controller,48)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var created=pool.created
 for cycle in 4:
  controller.clear_cooldowns();p.attack_chain.reset();p.spell_loadout.magic_combo_steps=0;controller.start_cast()
  for tick in 180:
   controller.tick(STEP)
   for shot in pool.all[controller.pool_key]:
    if shot.pool_live:shot._physics_process(STEP)
 check(pool.created==created and pool.misses==0 and get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Overlapping 48-orb casts reuse prepared capacity without resource growth or pool misses")
 for shot in pool.all[controller.pool_key]:
  if shot.pool_live:shot.retire()
 game.update_skill_balance(Qi.ID,"count",10)
 game.preview_forest_map(game.active_forest_map(),false)
 check(p.team_progression.ranks.is_empty() and p.team_progression.skills.has(Qi.ID) and Skills.effective(p,Qi.ID,"count")==10 and Skills.effective(p,Qi.ID,"hit_area")==1.5,"A real new run clears paths, rebuilds eligibility, and keeps saved baselines")
 shot_times.sort()
 var report={"checks":checks,"failures":failures,"shot_step_p95_ms":shot_times[floori(shot_times.size()*.95)]*.001,"shot_step_max_ms":shot_times.back()*.001,"pool_misses":pool.misses}
 FileAccess.open(OUTPUT+("headless" if DisplayServer.get_name()=="headless" else "desktop")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 game.queue_free();paused=false;await frames()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("QI_UPGRADES_RESULT ",JSON.stringify(report));quit(1 if failures else 0)
