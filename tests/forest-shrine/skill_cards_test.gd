extends "res://tests/forest-shrine/unified_equipment_test.gd"

const Progression=preload("res://scripts/forest/team_progression.gd")
const EVIDENCE="res://build/Other Files/Asset Toolkit/Skill Cards/"

func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames();RenderingServer.force_draw()
 check(root.get_texture().get_image().save_png(EVIDENCE+stem+".png")==OK,"Captured "+stem)

func run():
 DirAccess.make_dir_recursive_absolute(EVIDENCE)
 var bag=Progression.new();var twin=Progression.new()
 bag.rng.seed=314;twin.rng.seed=314
 var deterministic=true
 for refill in 4:
  var counts=[0,0,0]
  for draw in 20:
   var rarity=bag.draw_rarity();counts[rarity]+=1
   deterministic=deterministic and rarity==twin.draw_rarity()
  check(counts==[7,9,4] and bag.rarity_bag.is_empty(),"Each full bag draws exactly seven Silver, nine Gold and four Diamond")
 check(deterministic,"A run seed reproduces the shuffled bags")
 bag.draw_rarity();bag.reset()
 check(bag.rarity_bag.is_empty(),"Run reset starts a new bag")

 root.size=Vector2i(1280,800)
 var config=ConfigFile.new()
 config.set_value("settings","forest_level_up_cards",false)
 config.set_value("settings","volume",.37);config.save(cfg)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg
 root.add_child(game);current_scene=game;await frames()
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 check(game.settings.forest_level_up_cards and is_equal_approx(game.settings.volume,.37),"Skill cards are on for existing profiles and preserve other preferences")
 game.settings.forest_pet_loadout=[]
 game.begin_arena();game.choose_rogue_character(34);await frames()
 game.equipment_hub.enter_map();await frames()
 var p=game.player;var progression=game.model.team_progression
 check(Skills.active_slots(p).all(func(id):return id.is_empty()),"Fixture enters with an empty hotbar")
 game.award_team_kill(160);game._process(0);await frames()
 check(game.skill_card_targets().is_empty() and not is_instance_valid(game.team_upgrade_picker) and not paused,"An empty loadout never offers unequipped skills or pauses combat")
 check(progression.level==2 and progression.pending()==0 and progression.stat_points==1,"An empty loadout retains its level and stat point without queuing a card")
 key(KEY_Q);await frames();var hub=game.equipment_hub
 hub.show_page("skills");hub.selected_slot="equip";hub.assign_skill("kazi/qigong")
 key(KEY_ESCAPE);await frames()
 check(game.skill_card_targets()==["kazi/qigong"],"Only the equipped player skill can appear")
 game.award_team_kill(320);game._process(0);await frames()
 var picker=game.team_upgrade_picker
 check(is_instance_valid(picker) and paused and progression.pending()==1 and progression.offer==["kazi/qigong"] and picker.buttons.filter(func(button):return button.visible).size()==1,"One equipped skill opens one card without unrelated fillers")
 var id:String=progression.offer[0]
 var gain:int=Progression.CARD_LEVELS[progression.offer_rarities[0]]
 var saved=FileAccess.get_sha256(cfg)
 check(picker.buttons[0].find_child("Category",true,false).text=="1" and picker.buttons[0].find_child("Description",true,false)==null and picker.buttons[0].find_child("Rarity",true,false)==null,"Player cards omit the name, rarity text and description")
 picker.ready_at=0;await click(picker.buttons[0])
 check(Skills.level_for(p,id)==1+gain and progression.stat_points==2 and not paused,"A real card click raises the skill and resumes without spending stat points")
 check(saved==FileAccess.get_sha256(cfg),"Skill rewards do not rewrite saved settings or loadouts")

 var ember=Pets.key(0);var green=Pets.key(21)
 check(game.save_pet_loadout([ember,green]),"Select two test companions")
 key(KEY_Q);await frames();hub=game.equipment_hub
 hub.show_page("skills");hub.selected_slot="equip";hub.assign_skill("kazi/qigong")
 for i in [1,2]:
  hub.select_owner(i);hub.show_page("skills");hub.selected_slot="equip";hub.assign_skill("kazi/fire")
 key(KEY_ESCAPE);await frames()
 Skills.set_level(p,"kazi/qigong",25)
 check(game.skill_card_targets().size()==3 and game.skill_card_targets().has("kazi/qigong") and game.skill_card_targets().has("kazi/fire|"+ember) and game.skill_card_targets().has("kazi/fire|"+green),"The draft contains only the equipped player skill and each selected pet's equipped spell")
 progression.rarity_bag.assign([1,0,2])
 game.award_team_kill((48+64)*10);game._process(0);await frames()
 picker=game.team_upgrade_picker
 var label_:Label=picker.buttons[0].find_child("Level",true,false)
 check(progression.offer[0]=="kazi/qigong" and label_.text=="Lv 25 → 30" and progression.offer_rarities==[2,0,1],"Mixed draft shows Diamond, Silver and Gold with the exact level increase")
 check(progression.offer[1].contains("|") and progression.offer[2].contains("|") and progression.offer[1]!=progression.offer[2],"Each companion gets its own target even for the same spell")
 check(is_same(picker.buttons[0].get_theme_stylebox("normal").texture,picker.PreparationSkin.PANEL),"Skill cards use the Cross Gate ivory frame")
 for dimensions in [Vector2i(1280,800),Vector2i(960,640)]:
  root.size=dimensions;await frames(8)
  check(root.get_visible_rect().encloses(picker.panel.get_global_rect()),"Cards fit at %s"%str(dimensions))
  await capture("skill-cards-%dx%d"%[dimensions.x,dimensions.y])
 var wave_time:float=game.model.waves.wave_clock;var level_:int=progression.choice_level()
 game._physics_process(1.0)
 check(game.model.waves.wave_clock==wave_time,"Wave time stays paused while choosing")
 picker.ready_at=0;key(KEY_1);await frames()
 check(Skills.level_for(p,"kazi/qigong")==30 and progression.stat_points==4 and paused and progression.pending()==1,"Diamond honors the cap and the queued next level keeps the game paused")
 check(not game.choose_team_upgrade("kazi/qigong",level_) and not progression.offer.has("kazi/qigong"),"A capped skill leaves the draft and a stale selection cannot apply again")
 id=progression.offer[0]
 var chosen_pet=id.get_slice("|",1);var other_pet=green if chosen_pet==ember else ember
 gain=Progression.CARD_LEVELS[progression.offer_rarities[0]]
 picker.ready_at=0;picker.select(2)
 check(progression.pending()==1,"An unused keyboard slot cannot consume a queued choice")
 await click(picker.buttons[0])
 check(Skills.pet_level_for(progression,chosen_pet,"kazi/fire")==1+gain and Skills.pet_level_for(progression,other_pet,"kazi/fire")==1,"A companion card changes only the chosen pet's learned level")
 check(not paused and progression.pending()==0 and progression.stat_points==4 and Skills.level_for(p,"kazi/fire")==1,"The last card resumes combat, preserves stat points and leaves the unequipped player spell unchanged")
 var caster=game.army_runtime.pet_skills.casters[chosen_pet]
 check(Skills.level_for(caster,"kazi/fire")==1+gain,"The existing native pet caster uses the new level")
 p.position=Vector3(75,-8,75);p.velocity=Vector3.ZERO
 p._physics_process(1.0/60);p._physics_process(1.0/60)
 check(Vector2(p.position.x,p.position.z).distance_to(Vector2(75,75))<1 and p.position.y>=0,"Finishing the draft restores local fall recovery")

 for pet in [ember,green]:game.set_pet_skill_level(pet,"kazi/fire",30)
 check(game.skill_card_targets().is_empty(),"Fully leveled equipped skills never fall back to the unequipped catalog")
 game.award_team_kill(progression.kills_required()*10);game._process(0);await frames()
 check(not paused and not is_instance_valid(game.team_upgrade_picker) and progression.pending()==0 and progression.stat_points==5,"A level with all equipped skills capped keeps combat running and grants its stat point")

 game.settings.forest_level_up_cards=false;game.save_settings();game.load_settings()
 check(not progression.cards_enabled,"The new skill-card preference survives reloading")
 game.award_team_kill(progression.kills_required()*10);game._process(0)
 check(not paused and progression.pending()==0 and progression.stat_points==6,"Turning off skill cards retains ordinary XP and stat points")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(5)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SKILL_CARDS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
