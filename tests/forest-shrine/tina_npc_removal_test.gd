extends "res://tests/forest-shrine/tina_explorer_review.gd"
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Travel=preload("res://scripts/forest/forest_explorer_travel.gd")
const REMOVAL="res://build/Other Files/Asset Toolkit/Tina Recovery/NPC Removal/"
func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 DisplayServer.window_move_to_foreground()
 if is_instance_valid(game.dialogue):await reveal()
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(REMOVAL+stem+".png")==OK,"Captured "+stem)
func run():
 root.size=Vector2i(1440,900);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REMOVAL))
 var key=Pets.key(0);var metadata={"items":{"18465":1},"now":{"61021":1},"board":["keep"],"pet_training":{key:[34]}}
 var retired=["pet/34","kazi/fire",Pets.Spells.BODYGUARD]
 var path="/tmp/crossgate-tina-removal-%d.cfg"%OS.get_process_id()
 var config=ConfigFile.new();config.set_value("settings","explorer_quests",metadata);config.set_value("settings","forest_pet_skills",{key:retired});config.save(path)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=path
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.set_process(false)
 check(Pets.SKILLS.size()==12 and not Pets.SKILLS.keys().any(func(id):return id.begins_with("pet/")),"NPC-only techniques are removed from the active catalog")
 check(Pets.skill_codes([Pets.Spells.SURE_STRIKE,"kazi/fire",Pets.Spells.BODYGUARD])==PackedInt32Array([1,6,22]),"Ordinary skills and shared Bodyguard retain stable native codes")
 check(Pets.skill_id(17).is_empty() and Pets.skill_id(22)==Pets.Spells.BODYGUARD and Pets.native_mana_costs().size()==22,"Retired native slots are inactive without shifting Bodyguard")
 check(game.settings.forest_pet_skills[key]==["","kazi/fire",Pets.Spells.BODYGUARD],"Retired teaching slots cannot run while ordinary assignments survive")
 for field in metadata:check(game.settings.explorer_quests[field]==metadata[field],"Inactive saved NPC metadata is preserved: "+field)
 check(game.settings.explorer_quests.retired_pet_skills[key]==retired,"Previous teaching assignments are retained as inactive saved data")
 check(game.save_settings()==OK,"Removal keeps the normal preference writer")
 game.load_settings()
 check(game.settings.explorer_quests.retired_pet_skills[key]==retired and game.settings.forest_pet_skills[key][1]=="kazi/fire","Preference reload preserves retired data and active skills")
 for route in [[51005,Vector2i(38,46),12],[4208,Vector2i(18,13),12],[4230,Vector2i(22,13),0],[32181,Vector2i(94,66),12],[32193,Vector2i(33,39),12]]:
  game.explorer_clock.load_hour(route[2]);await visit_source(route[0],route[1]);game.explorer_npcs.prepare()
  check(game.world.find_child("SourceTinaNPCs",true,false)==null and game.explorer_npcs.actors.is_empty(),"Removed Tina NPC actors, prompts and services in "+str(route[0]))
  check(not game.explorer_npcs.interact(),"Removed NPC interaction cannot open a service")
  if route[0]==51005:await picture("tina-without-npcs")
 var saved=game.settings.explorer_quests.duplicate(true);var gold=game.model.gold
 var press=InputEventKey.new();press.physical_keycode=KEY_J;press.pressed=true;game._input(press)
 check(is_instance_valid(game.dialogue) and game.dialogue.speaker=="區域旅行","J offers direct area travel instead of quest inventory")
 await picture("direct-region-travel")
 Travel.choose("area:999999",game);check(game.model.gold==gold and game.settings.explorer_quests==saved,"Travel choices cannot spend gold or alter retained NPC data")
 Travel.choose("area:32181",game)
 for i in 8:await physics_frame
 check(game.model.falan_floor==32181,"Linked areas stay enterable without NPCs or quests")
 check(Travel.open(game),"Direct travel opens again after changing areas")
 Travel.choose("area:14036",game)
 for i in 8:await physics_frame
 check(game.model.falan_floor==14036,"Former NPC-gated rooms remain directly enterable")
 check(Travel.open(game),"The recovered room retains a direct return route")
 Travel.choose("area:4200",game)
 for i in 8:await physics_frame
 check(Original.source_id(game.model.falan_floor)==4200,"Direct return to Tina remains available")
 check(game.settings.explorer_quests==saved,"Exploration no longer executes or rewrites NPC quest state")
 finish()
