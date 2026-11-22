extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Gear=preload("res://scripts/forest/equipment.gd")
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const OUT="res://build/Other Files/Asset Toolkit/Equipment Shortcut/"

func q(pressed:bool=true,echo:bool=false):
 var event=InputEventKey.new();event.physical_keycode=KEY_Q;event.pressed=pressed;event.echo=echo
 root.push_input(event,true)

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)

func run():
 create_timer(180).timeout.connect(func():printerr("EQUIPMENT_SHORTCUT_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.settings.forest_pet_loadout=[]
 game.begin_arena();game.choose_rogue_character(43);await frames(3)
 var hub=game.equipment_hub
 check(not game.equipment_from_game and hub.enter_button.text=="Enter Map","Initial equipment keeps Enter Map")
 var restrictions={Catalog.RANDOM_SHOT:"bow",Catalog.BARRAGE_SHADOWS:"bow",Catalog.COUNTER:"polearm"}
 for character in Gear.Roster.CROSSGATE:
  if character==Gear.Roster.MAZE_ID:hub.appearance_draft.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE
  game.player.select_character(character);hub.refresh_party();hub.show_page("skills")
  for weapon in Gear.allowed(character,hub.preview_settings()):
   hub.draft={Gear.character_key(character):{"1":"weapon:"+weapon}};hub.refresh()
   for skill in restrictions:
    var available="skill:"+skill in hub.available_items()
    check(available==(weapon==restrictions[skill]),"Fighter %d with %s offers %s only with its weapon"%[character,weapon,skill])
    var before=hub.spell_draft.duplicate(true)
    hub.assign_skill(skill)
    check(available or hub.spell_draft==before,"Unavailable skill cannot enter draft through direct assignment")
    hub.assign_skill("")
   check("skill:"+Catalog.BEARS in hub.collection,"Unrestricted summon remains available")
 game.player.select_character(43);hub.refresh_party();hub.show_page("skills")
 var owner=Gear.character_key(43);var key=Gear.Roster.loadout_key(43,hub.preview_settings())
 game.settings.weapon_slot_unlocks={owner:3}
 hub.draft={owner:{"1":"weapon:sword","2":"weapon:bow","3":"weapon:polearm","active_weapon":"1"}};hub.refresh()
 check(restrictions.keys().all(func(id):return "skill:"+id in hub.collection),"Inactive carried Bow and Spear make their skills available")
 hub.selected_slot="equip";hub.assign_skill(Catalog.BARRAGE_SHADOWS)
 hub.selected_slot="surge";hub.assign_skill(Catalog.COUNTER)
 hub.selected_slot="sky_strike";hub.assign_skill(Catalog.BEARS)
 var icon=Catalog.KAZI_ICONS[Catalog.BEARS]
 check(icon.resource_path.ends_with("summon-bears.png") and not icon.get_image().is_invisible(),"Summon uses the original 穴熊 sprites")
 check(hub.inventory[hub.collection.find("skill:"+Catalog.BEARS)].get_node("ItemIcon").texture==icon,"Summon inventory uses the shared original sprite texture")
 icon.get_image().save_png(OUT+"summon-bears.png")
 await picture("carried-weapons-skills")
 hub.draft[owner].erase("2");hub.refresh()
 check(hub.enter_button.disabled and hub.status.text.contains("Bow"),"Removing required Bow blocks entry with a clear reason")
 var saved=FileAccess.get_sha256(cfg)
 check(not game.save_equipment_loadouts(hub.draft,hub.skill_draft,hub.cosmetic_draft,hub.appearance_draft,hub.spell_draft,hub.pet_skill_draft),"Save boundary rejects a missing required weapon")
 hub.enter_map()
 check(is_instance_valid(game.equipment_hub) and FileAccess.get_sha256(cfg)==saved and hub.draft[owner]["2"]=="weapon:bow","Invalid loadout cannot enter or change saved data, and restores the previous equipment")
 await picture("missing-bow-warning")
 hub.draft[owner]["2"]="weapon:bow";hub.refresh()
 check(not hub.enter_button.disabled,"Restoring the weapon enables entry")
 hub.enter_map();await frames(3)
 check(game.playing and not is_instance_valid(game.equipment_hub),"Valid starting loadout enters the map")
 game.forest_ui.sync()
 check(game.forest_ui.helper_portraits[2].texture==icon,"Summon hotbar shares the three-bear icon")
 await picture("summon-hotbar")
 var wave=game.model.wave;var phase=game.model.phase;var position=game.player.position
 var health=game.player.hp;var runtime=game.army_runtime;var snapshot=game.model.waves.pending
 saved=FileAccess.get_sha256(cfg)
 q();await frames(2);q(false)
 hub=game.equipment_hub
 check(is_instance_valid(hub) and not game.rogue_roster_open and paused,"Physical Q opens paused Equipment during play")
 check(hub.enter_button.text=="Return","In-game equipment offers Return without a Save step")
 q(true,true);await frames(1)
 check(is_instance_valid(game.equipment_hub),"Repeated held Q does not close equipment")
 hub.show_page("skills");hub.selected_slot="special_4";hub.assign_skill(Catalog.KAGEROU)
 await picture("q-equipment")
 q();q(false);await frames(2)
 check(not is_instance_valid(game.equipment_hub) and not paused and not game.rogue_roster_open,"Q closes equipment and resumes battle")
 check(FileAccess.get_sha256(cfg)!=saved and game.player.spell_loadout.assignments(43).special_4==Catalog.KAGEROU,"Closing with Q retains immediately equipped skills")
 q();q(false);await frames(2);hub=game.equipment_hub
 hub.show_page("skills");hub.selected_slot="special_4";hub.assign_skill(Catalog.KAGEROU);hub.enter_map();await frames(2)
 check(not is_instance_valid(game.equipment_hub) and not paused and game.player.spell_loadout.assignments(43).special_4==Catalog.KAGEROU,"Return resumes with the equipped skill")
 check(game.model.wave==wave and game.model.phase==phase and game.player.position==position and game.player.hp==health and game.army_runtime==runtime and game.model.waves.pending==snapshot,"Equipment preserves the current wave, player and army without restarting")
 game.show_pause();q();q(false);await frames(2)
 check(is_instance_valid(game.equipment_hub),"Q also opens equipment from the pause menu")
 game.back_from_equipment();await frames(2)
 check(paused and game.ordinary_pause and not is_instance_valid(game.equipment_hub),"Back restores the original pause state")
 game.resume();root.size=Vector2i(960,640);q();q(false);await frames(2)
 await picture("q-equipment-small")
 game.back_from_equipment()
 var path=game.settings_path
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("EQUIPMENT_SHORTCUT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
