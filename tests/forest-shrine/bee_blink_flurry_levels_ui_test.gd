extends "res://tests/forest-shrine/pet_attack_skills_test.gd"
const Skills=preload("res://scripts/spells/skill_balance.gd")
const ID=Pets.Spells.BEE_FLURRY
const UI_OUT="res://build/Other Files/Asset Toolkit/Bee Blink Flurry/"

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(UI_OUT+stem+".png")==OK,"Captured "+stem)

func run():
 create_timer(180).timeout.connect(func():printerr("BEE_LEVELS_UI_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(UI_OUT);root.size=Vector2i(1280,800)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow();await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime;var state=game.model.team_progression
 game.set_process(false);army.set_process(false);army.set_physics_process(false);game.music.stop();p.select_character(34)
 game.model.waves.crossgate_pet_test=true;game.model.waves.patrol_posts.clear()
 home.y=game.model.surface_height(home.x,home.z)+.05
 state.reset();state.stat_points=60
 check(p.spell_loadout.equip(34,"equip",ID) and Skills.level_skills().has(ID),"Bee Blink Flurry equips and accepts shared upgrade points")
 game.show_status_panel();await frames()
 var panel=game.status_panel;panel.show_skills(true)
 check(panel.skill_ids[0]==ID and not panel.skill_buttons[0].disabled,"Skills tab shows the equipped level-one flurry")
 check(panel.skill_buttons[0].tooltip_text.contains("+5% crit") and panel.skill_buttons[0].tooltip_text.contains("+10% crit"),"Upgrade preview shows the five-point critical increase")
 panel.skill_buttons[0].pressed.emit()
 check(Skills.level_for(p,ID)==2 and state.stat_points==59,"One point buys main-character level two")
 for i in 28:panel.skill_buttons[0].pressed.emit()
 var before=state.stat_points
 check(Skills.level_for(p,ID)==30 and before==31 and panel.skill_buttons[0].disabled,"Main-character progression stops at thirty after twenty-nine points")
 panel.skill_buttons[0].pressed.emit()
 check(state.stat_points==before and not game.spend_level_skill(ID),"Level-thirty stale clicks cannot consume another point")
 await picture("main-skill-level-30")
 game.close_status_panel();await frames()
 await equip_pack([61],[[ID,"",""]])
 var caster=army.pet_skills.casters[Pets.key(61)]
 check(Skills.level_for(caster,ID)==1 and Skills.level_for(p,ID)==30,"The bee starts at its independent level one")
 game.show_status_panel();await frames();panel=game.status_panel
 panel.find_child("PetsTab",true,false).pressed.emit();await frames()
 check(panel.pets_content.visible and not panel.pet_skill_buttons[0].disabled,"Pets tab offers the bee's equipped flurry")
 panel.pet_skill_buttons[0].pressed.emit()
 check(Skills.level_for(caster,ID)==2 and Skills.level_for(p,ID)==30 and state.stat_points==30,"A pet upgrade spends one point without changing the main character")
 await picture("bee-skill-level-2")
 for i in 28:panel.pet_skill_buttons[0].pressed.emit()
 before=state.stat_points
 check(Skills.level_for(caster,ID)==30 and before==2 and panel.pet_skill_buttons[0].disabled,"Bee progression also stops at thirty")
 panel.pet_skill_buttons[0].pressed.emit()
 check(state.stat_points==before and not game.spend_pet_skill(Pets.key(61),ID),"Capped pet requests preserve remaining points")
 root.size=Vector2i(960,640);await picture("bee-skill-level-30-small")
 check(panel.panel.get_global_rect().encloses(panel.pet_skill_buttons[0].get_global_rect()),"The pet upgrade remains usable at the smaller window size")
 game.close_status_panel();await frames()
 print("BEE_LEVELS_UI_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();current_scene=null;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
