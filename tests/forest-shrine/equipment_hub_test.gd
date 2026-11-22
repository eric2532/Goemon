extends "res://tests/forest-shrine/pet_attack_skills_test.gd"
const Gear=preload("res://scripts/forest/equipment.gd")
const Skills=preload("res://scripts/spells/skill_balance.gd")
const QiShot=preload("res://scripts/qigong_projectile.gd")
const Evidence="res://build/Other Files/Asset Toolkit/Equipment Hub/"
var colored_launches:Array=[]

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(Evidence+stem+".png")==OK,"Captured "+stem)
func click(control:Control):
 var event=InputEventMouseButton.new();event.device=517;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=control.get_global_rect().get_center()
 root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func cast_qi(caster:Hero,id:String="kazi/qigong"):
 var controller=caster.spell_loadout._instance(id).controller
 controller.cancel(true);controller.clear_cooldowns();caster.attack_chain.reset();shots.clear()
 controller.start_cast()
 for tick in 360:
  controller.tick(DT)
  if not controller.is_attacking():break
 return controller

func run():
 create_timer(240).timeout.connect(func():printerr("EQUIPMENT_HUB_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(Evidence);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.settings.forest_pet_loadout=[Pets.key(0),Pets.key(21),Pets.key(41),Pets.key(61),Pets.key(81)]
 var hero_key=Gear.character_key(34);var pet_key=Gear.pet_key(Pets.key(0))
 var legacy={hero_key:{"crystal":"qi-red"},pet_key:{"10":"qi-gold"}}
 var migrated={hero_key:{"qi_color":"qi-red"},pet_key:{"qi_color":"qi-gold"}}
 check(Gear.migrated_cosmetics({},legacy)==migrated and Gear.sanitized(legacy).is_empty(),"Both old crystal slots and generic slots migrate into cosmetics without occupying gear slots")
 check(Gear.migrated_cosmetics({hero_key:{"qi_color":"qi-violet"}},legacy)[hero_key].qi_color=="qi-violet","An existing cosmetic selection takes priority over old gear saves")
 check(Gear.migrated_cosmetics({hero_key:{"qi_color":""}},legacy)[hero_key].qi_color=="","A saved regular-blue choice cannot be replaced by an old colored item")
 for value in [null,[],{"character:1":{"crystal":"qi-red"}},{hero_key:{"head":"qi-red"}},{hero_key:{"crystal":"missing"}},{"pet:missing":{"crystal":"qi-red"}}]:
  check(Gear.sanitized(value).is_empty(),"Invalid wearers, slots and items are rejected safely")
 game.settings.volume=.37;game.save_settings()
 var config=ConfigFile.new();config.load(cfg);config.set_value("unrelated","preserve","marker");config.save(cfg)
 config.set_value("settings","gear_loadouts",legacy);config.save(cfg);game.load_settings()
 check(game.settings.cosmetic_loadouts==migrated and game.settings.gear_loadouts.is_empty(),"Loading actual old saved settings separates and preserves each wearer's cosmetic color")
 game.settings.cosmetic_loadouts={};game.save_settings()
 var saved_hash=FileAccess.get_sha256(cfg)
 game.begin_arena();game.choose_rogue_character(34);await frames(3)
 var hub=game.equipment_hub
 check(is_instance_valid(hub) and not game.playing and game.paused and paused and game.model.phase=="preparing","The pre-map hub blocks simulation until Enter Map")
 check(hub.inventory.size()==48 and hub.gear_buttons.size()==5 and hub.accessory_buttons.size()==5 and hub.cosmetic_buttons.size()==5 and hub.skill_buttons.size()==6 and hub.owners.size()==6,"Four equipment rows and a 48-cell collection share the six existing wearers")
 check(not hub.gear_buttons["1"].disabled and hub.gear_buttons.values().slice(1).all(func(slot):return slot.disabled and slot.get_node("Lock").visible),"Only the first weapon slot starts open")
 check(hub.gear_buttons.values().all(func(slot):return slot.get_node("Lock") is TextureRect and slot.get_node("Lock").texture.resource_path.ends_with("equipment/lock.svg") and slot.get_node("Lock").get_rect().get_center()==slot.size*.5),"Weapon locks use a centered icon matching the inventory palette")
 check(hub.available_items()==["weapon:sword"] and hub.allowed_icons.filter(func(icon):return icon.visible).size()==1,"Kaz retains his skin's sword-only equipment contract")
 check(hub.panel.get_node("MainCharacterHeading").text=="MAIN CHARACTER" and hub.panel.get_node("PetsHeading").text=="PETS" and hub.party[1].position.x-hub.party[0].get_rect().end.x>hub.party[2].position.x-hub.party[1].get_rect().end.x,"One main character is labeled and separated from the five pet slots")
 var hover_draft=hub.draft.duplicate(true)
 hub.inventory[0].mouse_entered.emit()
 check(hub.detail.text.is_empty() and hub.preview.texture==null and hub.draft==hover_draft and hub.selected_item.is_empty(),"Hover leaves the bottom panel and selection unchanged")
 check((hub.inventory+hub.gear_buttons.values()+hub.accessory_buttons.values()+hub.cosmetic_buttons.values()+hub.skill_buttons.values()+hub.allowed_icons).all(func(control):return control.tooltip_text.is_empty()),"Equipment descriptions stay in the bottom panel without duplicate hover tooltips")
 hub.allowed_icons[0].mouse_entered.emit()
 check(hub.detail.text.is_empty(),"Supported weapon icons do not replace the bottom panel on hover")
 await click(hub.inventory[0])
 check(hub.detail.text=="Sword" and hub.selected_item=="weapon:sword" and Gear.equipped(hub.draft,34)=="weapon:sword" and hub.draft[hero_key].active_weapon=="1","A single click describes and equips the weapon immediately")
 hub.draft.clear();hub.refresh()
 check(hub.gear_buttons["1"].position.y<hub.accessory_buttons["accessory:1"].position.y and hub.accessory_buttons["accessory:1"].position.y<hub.cosmetic_buttons["1"].position.y,"Weapons, accessories and cosmetics remain visible together")
 check(game.forest_ui.find_child("PreparationBuilds",true,false)==null and game.forest_ui.find_child("PreparationHireGuards",true,false)==null,"Build and Mercenaries buttons stay absent")
 await picture("equipment-layout")
 await click(hub.skill_tab)
 check(hub.page=="accessories" and hub.available_items().size()==13 and hub.available_items().has("accessory:dash-boots") and hub.inventory.slice(0,13).all(func(slot):return not slot.disabled),"The Accessories tab offers the twelve selected original items and Dash Boots")
 await click(hub.cosmetics_tab)
 check(hub.color_choices.size()==Gear.COLORS.size()+1 and hub.available_items().all(func(id):return not id.begins_with("skin:")) and hub.cosmetic_buttons["1"].get_node("GearIcon").texture==null,"Cosmetics contains item choices and keeps all five slots free of the character skin")
 var cosmetic_bounds=hub.orb.atlas.get_image().get_region(hub.orb.region).get_used_rect()
 var cosmetic_size=Vector2(cosmetic_bounds.size)*64.0/hub.orb.get_size()
 var skill_size=Vector2(hub.Spells.KAZI_ICONS["kazi/qigong"].get_image().get_used_rect().size)
 check(cosmetic_size.distance_to(skill_size)<2.0 and hub.orb.atlas==hub.ORBS,"Cosmetic orbs match the small skill icon while preserving their original artwork")
 check(hub.color_choices.values().all(func(hit):return hit.get_node("ItemIcon").texture==hub.orb),"Regular blue, every tint and chrome share the same padded cosmetic icon")
 var preview_original_skin=Gear.Roster.selected_skin(34,game.settings)
 var alternate_skin=Gear.Roster.skin_catalog(34).keys().filter(func(id):return id!=preview_original_skin)[0]
 await click(hub.portrait_button)
 check(is_instance_valid(hub.portrait_button.gallery) and hub.portrait_button.gallery.visible,"Clicking the main character model opens the existing skin gallery")
 var skin_index=Gear.Roster.skin_catalog(34).keys().find(alternate_skin)
 hub.portrait_button.choices.select(skin_index)
 check(hub.portrait_button.status.text=="Unsaved","The equipment skin gallery identifies its unsaved draft")
 await picture("model-skin-picker")
 hub.portrait_button.choices.item_activated.emit(skin_index);await frames(3)
 check(hub.portrait_button.gallery==null,"Double-clicking a skin applies the draft and closes the gallery without Done")
 check(hub.appearance_draft.is_empty() and game.settings.kaz_skin==alternate_skin and game.player.model.kaz_skin==alternate_skin and FileAccess.get_sha256(cfg)!=saved_hash,"Choosing a skin saves and updates the live character immediately")
 check(hub.party[0].icon==hub.portrait.texture,"The character button follows the draft game model immediately after a skin change")
 hub.select_category_slot("cosmetics","1");hub.set_cosmetic_color("qi-gold")
 check(hub.cosmetic_draft[hero_key].slots=={"1":"qi-gold"} and Gear.sanitized_cosmetics(hub.cosmetic_draft)==hub.cosmetic_draft,"The first cosmetic position now equips and validates cosmetic items")
 hub.unequip()
 check(hub.cosmetic_draft[hero_key].slots.is_empty() and game.settings.kaz_skin==alternate_skin,"Unequipping cosmetic slot one preserves the equipped skin")
 hub.select_category_slot("cosmetics","4");hub.set_cosmetic_color("qi-red")
 check(hub.cosmetic_draft[hero_key].slots=={"4":"qi-red"} and hub.cosmetic_buttons["4"].get_node("GearIcon").texture!=null,"Qi cosmetics equip into the chosen cosmetic slot")
 await click(hub.color_choices["qi-red"])
 check(hub.cosmetic_buttons["4"].get_node("GearIcon").texture==hub.orb and hub.preview.texture==hub.orb,"Equipped cosmetics and the selected preview keep the same small icon")
 check(hub.detail.text=="Red Qi" and not hub.detail.text.contains("only"),"Cosmetic descriptions stay concise and do not declare all cosmetics statless")
 check(hub.describe({"name":"Test charm","description":"A lucky charm.","stats":{"health":20}})=="Test charm\nA lucky charm. · Health +20","Item titles appear above their descriptions and stat bonuses")
 var preserved=hub.cosmetic_draft.duplicate(true)
 hub.select_item(hub.collection.size())
 check(hub.cosmetic_draft==preserved,"Empty inventory cells cannot overwrite cosmetics")
 hub.set_cosmetic_color("qi-chrome")
 check(hub.preview.material.get_shader_parameter("chrome")==true,"Rainbow chrome retains its shared material")
 await picture("cosmetics-layout")
 game.back_from_equipment();await frames(3)
 check(game.settings.kaz_skin==alternate_skin and game.settings.cosmetic_loadouts[hero_key].qi_color=="qi-chrome","Back retains the equipped appearance and cosmetics")
 game.choose_rogue_character(34);await frames(3);hub=game.equipment_hub
 hub.show_page("cosmetics")
 for i in 5:
  hub.select_owner(i);hub.set_cosmetic_color(Gear.COLORS.keys()[i%Gear.COLORS.size()])
 check(hub.cosmetic_draft[hero_key].qi_color=="qi-red" and hub.cosmetic_draft[pet_key].qi_color=="qi-gold","Fighters and pets keep independent cosmetic slots and Qi colors")
 check(hub.cosmetic_buttons["1"].get_node("GearIcon").texture!=null and not hub.portrait_button.visible,"Pet cosmetic items use the first slot without a character skin picker")
 hub.select_owner(5);hub.set_cosmetic_color("")
 check(Gear.color(hub.cosmetic_draft,hub.owners[5])==Color.WHITE,"Regular blue remains selectable")
 hub.select_owner(0);hub.show_page("weapons")
 hub.select_slot("2");check(hub.selected_slot=="1","Locked weapon slots cannot become equip destinations")
 check(not game.save_equipment_loadouts({hero_key:{"2":"weapon:sword"}},{},{}),"The save boundary rejects weapons in locked slots")
 check(Gear.migrated_gear({hero_key:{"10":"weapon:sword"}},game.settings)=={hero_key:{"1":"weapon:sword"}},"Legacy weapons move safely from arbitrary old slots into the initial weapon slot")
 var unlock_path=game.settings_path;game.settings_path="user://missing-equipment-folder/settings.cfg"
 check(not game.unlock_weapon_slot(hero_key) and Gear.unlocked(hero_key,game.settings)==1,"A failed unlock save rolls back the slot count")
 game.settings_path=unlock_path
 for count in range(2,6):
  check(game.unlock_weapon_slot(hero_key) and Gear.unlocked(hero_key,game.settings)==count and not hub.gear_buttons[str(count)].disabled,"Reward-ready unlocks open and persist the next weapon slot")
 check(not game.unlock_weapon_slot(hero_key) and not game.unlock_weapon_slot(pet_key),"Weapon unlocks stop at five and cannot alter native pet attacks")
 game.load_settings()
 check(Gear.unlocked(hero_key,game.settings)==5 and Gear.unlocked(Gear.character_key(43),game.settings)==1,"Unlocks survive reload and remain fighter-specific")
 check(Gear.sanitized_unlocks({hero_key:99,pet_key:2,"character:1":3}).is_empty(),"Malformed and unsupported unlock records are rejected")
 for dimensions in [Vector2i(1280,800),Vector2i(960,640)]:
  root.size=dimensions;await frames(4)
  check(root.get_visible_rect().encloses(hub.panel.get_global_rect()),"The equipment layout fits "+str(dimensions))
  for category in ["weapons","accessories","cosmetics"]:
   hub.show_page(category);await frames(2)
   for control in hub.party+hub.gear_buttons.values()+hub.accessory_buttons.values()+hub.cosmetic_buttons.values()+[hub.inventory_scroll,hub.equipment_tab,hub.skill_tab,hub.cosmetics_tab,hub.enter_button]:
    check(hub.panel.get_global_rect().encloses(control.get_global_rect()),"Equipment controls remain inside the scaled page")
   check(hub.inventory_grid.size.x<=hub.inventory_scroll.size.x,"The expanded collection fits without horizontal clipping")
   await picture("layout-%s-%dx%d"%[category,dimensions.x,dimensions.y])
 hub.add_inventory_cells(80);await frames(3)
 hub.inventory_scroll.scroll_vertical=1000;await frames(2)
 check(hub.inventory_scroll.scroll_vertical>0,"Collections larger than the viewport can scroll")
 hub.refresh();hub.inventory_scroll.scroll_vertical=0
 root.size=Vector2i(1280,800);await frames(3)
 hub.show_page("weapons")
 for character in Gear.Roster.CROSSGATE:
  if character in [34,36]:hub.appearance_draft.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE if character==36 else preload("res://scripts/kaz_skins.gd").DEFAULT
  game.player.select_character(character);hub.refresh_party();hub.select_owner(0)
  check(hub.portrait.texture is AtlasTexture and hub.party[0].text==Gear.Roster.name_for(Gear.Roster.gallery_id(character)),"The equipment portrait follows Cross Gate gallery fighter %d"%character)
  check(hub.party[0].icon is AtlasTexture and hub.party[0].icon.atlas==hub.portrait.texture.atlas and hub.party[0].icon.region==hub.portrait.texture.region and hub.party[0].icon.margin==hub.portrait.texture.margin,"The main-character button uses the same full game model as the equipment preview")
  hub.select_owner(1)
  check(hub.party[1].icon==Pets.portrait(Pets.skin(hub.owners[1].trim_prefix("pet:"))) and hub.party[0].icon is AtlasTexture,"Selecting a pet preserves the hero model and existing pet art")
  hub.select_owner(0)
  check(hub.allowed_icons.filter(func(icon):return icon.visible).size()==hub.available_items().size(),"Weapon permissions follow each Cross Gate skin")
 game.player.select_character(42);hub.refresh_party();hub.select_owner(0)
 hub.appearance_draft.emilia_skin=120387;hub.draft[Gear.character_key(42)]={"1":"weapon:bow"};hub.refresh()
 check(hub.gear_buttons["1"].get_node("GearIcon").modulate.r<1 and hub.gear_buttons["1"].get_meta("description").contains("Unavailable") and hub.gear_buttons["1"].tooltip_text.is_empty(),"A saved weapon unsupported by the previewed skin stays saved and visibly unavailable")
 await picture("unavailable-weapon-layout")
 hub.appearance_draft.erase("emilia_skin");hub.draft.erase(Gear.character_key(42))
 hub.appearance_draft.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE
 game.player.select_character(36);hub.refresh_party();hub.select_owner(0)
 hub.selected_item="weapon:unarmed";hub.equip_selected()
 check(hub.preview.texture==Gear.ITEMS["weapon:unarmed"].icon and hub.preview.get_node_or_null("FistBadge")==null,"The approved fist art stays unframed and uses shared scaling")
 await picture("fist-layout")
 hub.draft.clear();hub.appearance_draft.kaz_skin=preload("res://scripts/kaz_skins.gd").DEFAULT
 game.player.select_character(34);hub.refresh_party();hub.apply_changes();hub.select_owner(1)
 var cosmetics_before_picker=hub.cosmetic_draft.duplicate(true)
 game.show_pet_loadout();await frames(3)
 check(is_instance_valid(game.pet_loadout_panel) and paused and not game.playing,"The existing pet picker opens before map entry")
 var chosen=game.pet_loadout_panel
 chosen.remove(0);chosen.apply();game.close_pet_loadout();await frames(3)
 check(is_instance_valid(game.equipment_hub) and hub.wearer_key==hub.owners[1] and hub.cosmetic_draft==cosmetics_before_picker and paused,"Removing a pet keeps the inspected slot and preserves keyed gear drafts")
 game.show_pet_loadout();await frames();game.pet_loadout_panel.toggle(0);game.pet_loadout_panel.apply();game.close_pet_loadout();await frames()
 check(hub.owners.has(pet_key) and hub.cosmetic_draft[pet_key]["qi_color"]=="qi-gold","Reselecting a pet restores its own gear")
 var path=game.settings_path;var before=FileAccess.get_sha256(path)
 var settings_identity=game.settings;var saved_settings=game.settings.duplicate(true)
 game.settings_path="user://missing-equipment-folder/settings.cfg";hub.enter_map()
 check(is_instance_valid(game.equipment_hub) and not game.playing and is_same(settings_identity,game.settings) and game.settings==saved_settings and FileAccess.get_sha256(path)==before,"A failed save preserves the old settings and keeps the hub open")
 game.settings_path=path
 var corrupt=path+".corrupt";var file=FileAccess.open(corrupt,FileAccess.WRITE);file.store_string("[broken\n");file.close()
 var corrupt_hash=FileAccess.get_sha256(corrupt);game.settings_path=corrupt
 check(not game.save_equipment_loadouts(hub.draft,hub.skill_draft,hub.cosmetic_draft) and FileAccess.get_sha256(corrupt)==corrupt_hash,"An unreadable existing config is preserved instead of overwritten")
 game.settings_path=path;DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt))
 check(not game.save_equipment_loadouts({hero_key:{"head":"qi-red"}},{},{}) and game.settings==saved_settings,"Invalid gear cannot be saved into incompatible slots")
 check(not game.save_equipment_loadouts({},{hero_key:{"1":"qi-red"}},{}) and game.settings.skill_item_loadouts.is_empty(),"Cosmetic colors cannot be placed in skill-item slots")
 check(not game.save_equipment_loadouts({},{},{hero_key:{"qi_color":"missing"}}),"Unknown cosmetics cannot be saved")
 hub.select_owner(0);hub.select_skin(alternate_skin)
 check(not game.save_equipment_loadouts(hub.draft,hub.skill_draft,hub.cosmetic_draft,{"volume":0}),"Appearance commits cannot modify unrelated settings")
 await click(hub.enter_button)
 check(game.settings.kaz_skin==alternate_skin and game.player.model.kaz_skin==alternate_skin,"Enter Map commits the previewed skin using the existing model owner")
 check(game.equipment_hub==null and game.playing and game.model.phase=="wave" and not paused,"Enter Map commits gear and starts normal gameplay")
 check(game.army_runtime.navigation_revision==game.model.navigation_revision,"Map navigation is warmed before the first combat step")
 var saved_cosmetics=game.settings.cosmetic_loadouts.duplicate(true);game.load_settings()
 check(game.settings.cosmetic_loadouts==saved_cosmetics and is_equal_approx(game.settings.volume,.37),"Gear save/reload preserves all wearers and unrelated settings")
 check(game.settings.gear_loadouts.is_empty() and game.settings.skill_item_loadouts.is_empty(),"Cosmetics persist independently without occupying either equipment loadout")
 config.load(cfg);check(config.get_value("unrelated","preserve","")=="marker","Atomic settings replacement preserves unknown configuration sections")
 game.model.team_progression.reset()
 check(game.settings.cosmetic_loadouts==saved_cosmetics,"New run levels do not clear saved equipment")
 var army=game.army_runtime;var p=game.player
 game.model.falan_floor=0;game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true;army.record_events=true
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):
  shot.set_physics_process(false);shots.append(shot)
  if shot is QiShot:
   colored_launches.append({"wearer":Gear.wearer(shot.hero),"color":shot.attack_ticket.get("qi_color",Color.WHITE),"tint":shot.visual.get_instance_shader_parameter("qi_tint"),"chrome":shot.visual.get_instance_shader_parameter("qi_chrome"),"damage":shot.damage}))
 for character in Gear.Roster.CROSSGATE:
  p.select_character(character);p.position=home;p.velocity=Vector3.ZERO
  var controller=cast_qi(p)
  var expected=Gear.color(saved_cosmetics,Gear.character_key(character))
  check(not shots.is_empty() and shots.all(func(shot):return shot.attack_ticket.qi_color==expected and shot.visual.get_instance_shader_parameter("qi_tint")==expected),"Cross Gate fighter %d uses only its own gear color"%character)
  check(shots.size()==1 and shots[0].damage==Skills.normal_damage(p)*1.5,"Gear preserves level-one count and damage")
  controller.cancel(true)
 p.select_character(34);p.position=home
 var original_skin=Gear.Roster.selected_skin(34,game.settings)
 var alternate=Gear.Roster.skin_catalog(34).keys().filter(func(id):return id!=original_skin)[0]
 game.select_kaz_skin(alternate)
 var changed_skin=cast_qi(p)
 check(shots.size()==1 and shots[0].attack_ticket.qi_color==Gear.COLORS["qi-red"].color,"Changing a character's appearance keeps its own gear color")
 changed_skin.cancel(true);game.select_kaz_skin(original_skin)
 var alias=cast_qi(p,Pets.Spells.MAZE_QI)
 check(shots.size()==1 and shots[0].attack_ticket.qi_color==Gear.COLORS["qi-red"].color,"The old Qi ID uses the same wearer gear")
 alias.cancel(true)
 var chrome_saved=saved_cosmetics.duplicate(true);chrome_saved[hero_key]={"qi_color":"qi-chrome"}
 check(game.save_equipment_loadouts({},{},chrome_saved),"Rainbow chrome saves through the existing cosmetic record")
 game.load_settings()
 check(game.settings.cosmetic_loadouts==chrome_saved,"Rainbow chrome survives save/reload with other wearers unchanged")
 for character in Gear.Roster.CROSSGATE:
  p.select_character(character);p.position=home
  game.settings.cosmetic_loadouts[Gear.character_key(character)]={"qi_color":"qi-chrome"}
  var chrome_cast=cast_qi(p)
  check(shots.size()==1 and shots[0].attack_ticket.qi_chrome and shots[0].visual.get_instance_shader_parameter("qi_chrome")==1.0 and shots[0].damage==Skills.normal_damage(p)*1.5,"Cross Gate fighter %d uses chrome on its existing unchanged Qi projectile"%character)
  chrome_cast.cancel(true)
 p.select_character(34);p.position=home
 var chrome_alias=cast_qi(p,Pets.Spells.MAZE_QI)
 check(shots.size()==1 and shots[0].attack_ticket.qi_chrome,"The old Qi alias also carries the chrome cast snapshot")
 game.settings.cosmetic_loadouts[hero_key]={"qi_color":"qi-red"}
 check(shots.all(func(shot):return shot.attack_ticket.qi_chrome and shot.visual.get_instance_shader_parameter("qi_chrome")==1.0),"Changing the selected cosmetic cannot recolor an already released chrome orb")
 for shot in shots:shot.retire()
 chrome_alias.cancel(true)
 check(game.save_equipment_loadouts({},{},saved_cosmetics),"Restore each wearer's original cosmetic after the chrome sweep")
 var removed=saved_cosmetics.duplicate(true);removed[hero_key]={"qi_color":""};game.save_equipment_loadouts({},{},removed)
 Skills.set_modifier(p,"kazi/qigong","legacy-color",{"qi_color":Color.RED})
 var regular=cast_qi(p)
 check(shots.size()==1 and shots[0].visual.get_instance_shader_parameter("qi_tint")==Color.WHITE and shots[0].visual.get_instance_shader_parameter("qi_chrome")==0.0,"Regular blue resets pooled tint/chrome and wins over a legacy run-wide color modifier")
 regular.cancel(true);Skills.set_modifier(p,"kazi/qigong","legacy-color",{});game.save_equipment_loadouts({},{},saved_cosmetics)
 # All selected families use the same native skill path with independent color tickets.
 await equip_pack([0,21,41,61,81],[["kazi/qigong","",""],["kazi/qigong","",""],["kazi/qigong","",""],["kazi/qigong","",""],["kazi/qigong","",""]])
 colored_launches.clear()
 for i in 5:spawn(Vector3((i-2)*10,0,-4))
 for tick in 720:advance()
 for skin in [0,21,41,61,81]:
  var key=Gear.pet_key(Pets.key(skin));var emitted=colored_launches.filter(func(row):return row.wearer==key)
  var chrome=1.0 if saved_cosmetics.get(key,{}).get("qi_color","")=="qi-chrome" else 0.0
  check(not emitted.is_empty() and emitted.all(func(row):return row.color==Gear.color(saved_cosmetics,key) and row.tint==row.color and row.chrome==chrome),"Native pet %d casts only its own color/chrome alongside the other pets"%skin)
 var created=pool.created;await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for tick in 720:advance()
 await frames(3)
 check(pool.created==created and pool.misses==0 and get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated five-pet color casts retain warmed nodes, resources and pool capacity")
 check(army.pet_skills.casters.size()==5,"Equipment reuses the five native pet casters")
 if DisplayServer.get_name()!="headless":
  var intervals=[];var previous=Time.get_ticks_usec()
  for i in 120:
   advance();await process_frame
   var now=Time.get_ticks_usec();intervals.append(now-previous);previous=now
  intervals.sort();print("EQUIPMENT_RENDERED_FRAME_US p95=",intervals[floori(intervals.size()*.95)]," max=",intervals.back())
 game.camera_rig.set_process(false);game.camera_rig.camera.global_position=home+Vector3(10,20,30);game.camera_rig.camera.look_at(home+Vector3(0,2,-6))
 game.forest_ui.sync();await picture("map-hud-without-build-or-mercenaries")
 var handle:int=army.handles[army.HOUND_ID]
 army.apply_hit(handle,{"amount":100.0})
 var hp:float=army.unit_state(handle).hp
 game.save_equipment_loadouts({},{},removed)
 check(army.handles[army.HOUND_ID]==handle and army.unit_state(handle).hp==hp,"Gear changes preserve living pets and their health")
 for voice in game.voices:voice.stop()
 shots.clear();game.queue_free();current_scene=null;paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("EQUIPMENT_HUB_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
