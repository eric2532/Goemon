extends "res://tests/forest-shrine/bodyguard_test.gd"
const LevelSkills=preload("res://scripts/spells/skill_balance.gd")

func probe(level_:int,guard:int,ally:int,enemy:Ninja):
 var p=game.player;var army=game.army_runtime;var success=false
 for attempt in 100:
  p.position=home+Vector3.RIGHT*(6 if guard==0 else 40);p.velocity=Vector3.ZERO;p.invuln=0
  if guard:army.native.set_pose(guard,home+Vector3.RIGHT*6,0)
  army.native.set_pose(ally,home,0);army.native.set_pose(enemy.handle,home+Vector3(0,0,-24),0)
  army.native.set_targets(army.external_targets());army.presentation_events.clear()
  var hp_before:float=army.unit_state(guard).hp if guard else p.hp
  army.apply_hit(ally,{"amount":50.0,"source_id":enemy.forest_id,"direction":Vector3.BACK})
  success=p.timed_dodge.rescue_left>0 if guard==0 else army.presentation_events.any(func(e):return e.kind=="status" and e.get("action_index",0)==6010)
  if not success:continue
  await driver.advance(14,rescue_tick)
  var hp_after:float=army.unit_state(guard).hp if guard else p.hp
  check(is_equal_approx(hp_before-hp_after,50*(1-.01*(level_-1))),"%s Lv%d takes exactly the reduced intercepted damage: %.3f"%["Pet" if guard else "Character",level_,hp_before-hp_after])
  break
 check(success,"%s Lv%d activates through the real native hit path"%["Pet" if guard else "Character",level_])

func run():
 create_timer(180).timeout.connect(func():printerr("BODYGUARD_LEVELS_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime;var progression=game.model.team_progression
 game.set_process(false);army.set_process(false);army.set_physics_process(false);game.camera_rig.set_process(false);game.music.stop();p.set_auto_attack(false)
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true;army.record_events=false
 game.training_dummy.position=home+Vector3.DOWN*1000;game.training_dummy.home=game.training_dummy.position
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 p.select_character(p.RogueRoster.SHIN_ID);p.hp=p.max_hp;p.spell_loadout.equip(p.character_id,"special_6",Pets.Spells.BODYGUARD)
 for level_ in range(1,31):
  var rules=LevelSkills.Levels.stats(Pets.Spells.BODYGUARD,level_)
  check(is_equal_approx(rules.chance,minf(1,.5+.01*(level_-1))) and is_equal_approx(rules.defense_bonus,.01*(level_-1)),"Shared 護衛 rules match both bonuses at Lv%d"%level_)
 check(LevelSkills.level_preview(Pets.Spells.BODYGUARD,30).contains("29% intercepted damage"),"Upgrade preview explains that only intercepted damage is reduced")
 progression.stat_points=2;game.show_status_panel();await frames(2)
 check(game.spend_level_skill(Pets.Spells.BODYGUARD) and LevelSkills.level_for(p,Pets.Spells.BODYGUARD)==2 and progression.stat_points==1,"A real character upgrade spends one point on 護衛")
 game.close_status_panel();await frames(2)
 await equip_pack([0],[["","",""]]);var ally:int=army.handles[army.HOUND_ID];army.native.set_pet_growth(ally,10000,0)
 var enemy=spawn(Vector3(0,0,-24))
 for level_ in [2,11,30]:
  LevelSkills.set_level(p,Pets.Spells.BODYGUARD,level_)
  await probe(level_,0,ally,enemy)
 for skin in [0,21,41,61,81]:
  p.position=home+Vector3.RIGHT*40
  await equip_pack([skin,1],[[Pets.Spells.BODYGUARD,"",""],["","",""]])
  var guard:int=army.handles[army.HOUND_ID-skin];ally=army.handles[army.HOUND_ID-1]
  army.native.set_pet_growth(guard,10000,0);army.native.set_pet_growth(ally,10000,0)
  var caster=army.pet_skills.casters[Pets.key(skin)]
  game.show_status_panel();await frames(2);progression.stat_points=1
  check(game.spend_pet_skill(Pets.key(skin),Pets.Spells.BODYGUARD) and LevelSkills.level_for(caster,Pets.Spells.BODYGUARD)==2 and LevelSkills.level_for(p,Pets.Spells.BODYGUARD)==30 and progression.stat_points==0,"Pet %d upgrades independently through the real point-spending path"%skin)
  game.close_status_panel();await frames(2);enemy=spawn(Vector3(0,0,-24))
  for level_ in [2,11,30]:
   game.set_pet_skill_level(Pets.key(skin),Pets.Spells.BODYGUARD,level_)
   await probe(level_,guard,ally,enemy)
  check(LevelSkills.summary(caster,Pets.Spells.BODYGUARD).contains("29% intercepted damage"),"Pet %d tooltip shows its own Lv30 defense bonus"%skin)
 print("BODYGUARD_LEVELS_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();await process_frame;quit(1 if failures else 0)
