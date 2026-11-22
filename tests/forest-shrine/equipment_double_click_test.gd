extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Gear=preload("res://scripts/forest/equipment.gd")
const Spells=preload("res://scripts/spells/spell_catalog.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Hub=preload("res://scripts/forest/equipment_hub.gd")
const OUT="res://build/Other Files/Asset Toolkit/Equipped Skills Only/"

# Supply future item categories without adding made-up gear to the live catalog.
class PlacementProbe extends Hub:
 var assigned=[]
 func equip_selected():assigned.append(selected_slot)

func pointer(control:Control,double:bool=false):
 var event=InputEventMouseButton.new();event.device=517;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.double_click=double;event.position=control.get_global_rect().get_center()
 root.push_input(event,true)
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames(3)
func activate(hub,id:String):
 var index=hub.collection.find(id);check(index>=0,"Item is in the current collection: "+id)
 if index>=0:await pointer(hub.inventory[index],true)
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)
func run():
 create_timer(240).timeout.connect(func():printerr("EQUIPMENT_DOUBLE_CLICK_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.settings.forest_pet_loadout=[Pets.key(0)];game.save_settings()
 game.begin_arena();game.choose_rogue_character(34);await frames(3)
 var p=game.player;var hub=game.equipment_hub;var saved=FileAccess.get_sha256(cfg)
 check(hub.find_child("EquipGear",true,false)==null and hub.find_child("UnequipGear",true,false)==null,"Equipment uses direct item/slot actions without redundant buttons")
 for character in Gear.Roster.CROSSGATE:
  p.select_character(character);hub.refresh_party();hub.select_owner(0);hub.show_page("skills")
  check(Spells.defaults(character).is_empty() and p.spell_loadout.assignments(character).is_empty() and p.spell_loadout.numbered_slots.size()==6 and p.spell_loadout.numbered_slots.all(func(slot):return slot.is_empty()),"Fighter %d starts with six empty skill keys"%character)
  check(hub.skill_buttons.values().all(func(button):return not button.disabled and button.get_node("GearIcon").texture==null),"Every fighter's six equipment skill slots are empty and editable")
  for action in Spells.SLOTS:
   var event=InputEventAction.new();event.action=action;event.pressed=true
   check(p.spell_loadout.input(event),"An unequipped skill key is consumed before native fallback")
  check(p.spell_loadout.instances.is_empty() and not p.active_ability.kagerou_enabled,"No built-in spell controllers or dodge toggle are prepared")
 p.select_character(34);hub.refresh_party();hub.select_owner(0);hub.show_page("skills")
 var qi=hub.collection.find("skill:kazi/qigong")
 await pointer(hub.inventory[qi])
 check(hub.spell_draft.is_empty() and hub.selected_item=="skill:kazi/qigong" and hub.detail.text==hub.inventory[qi].accessibility_name,"A single click selects and inspects a skill without equipping")
 var selected_detail=hub.detail.text;var selected_icon=hub.preview.texture;var selected_material=hub.preview.material
 var fire=hub.inventory[hub.collection.find("skill:kazi/fire")]
 var motion=InputEventMouseMotion.new();motion.device=517;motion.position=fire.get_global_rect().get_center();root.push_input(motion,true);await frames(3)
 for control in hub.inventory+hub.gear_buttons.values()+hub.accessory_buttons.values()+hub.cosmetic_buttons.values()+hub.skill_buttons.values()+hub.allowed_icons:
  control.mouse_entered.emit();control.focus_entered.emit()
 check(hub.selected_item=="skill:kazi/qigong" and hub.detail.text==selected_detail and hub.preview.texture==selected_icon and hub.preview.material==selected_material and hub.spell_draft.is_empty(),"Hover and focus preserve the clicked item's bottom-left preview across the menu")
 await pointer(fire)
 check(hub.selected_item=="skill:kazi/fire" and hub.detail.text==fire.accessibility_name and hub.detail.text!=selected_detail and hub.spell_draft.is_empty(),"Clicking another item replaces the preview without equipping")
 hub.inventory[qi].grab_focus()
 var enter=InputEventKey.new();enter.physical_keycode=KEY_ENTER;enter.keycode=KEY_ENTER;enter.pressed=true;root.push_input(enter,true)
 enter=enter.duplicate();enter.pressed=false;root.push_input(enter,true);await frames(2)
 check(hub.skill_assignment("equip")=="skill:kazi/qigong","Enter equips a focused item without a footer button")
 hub.skill_buttons.equip.grab_focus()
 enter=InputEventKey.new();enter.physical_keycode=KEY_ENTER;enter.keycode=KEY_ENTER;enter.pressed=true;root.push_input(enter,true)
 enter=enter.duplicate();enter.pressed=false;root.push_input(enter,true);await frames(2)
 check(hub.skill_assignment("equip").is_empty(),"Enter removes a focused equipped skill without a footer button")
 var ids=["kazi/qigong","kazi/fire","kazi/ice","kazi/wind","kazi/meteor",Spells.KAGEROU,Spells.COMBO,Spells.BEARS,Spells.MOON,Spells.SPIRIT,Spells.RECOVERY,Spells.SURE_STRIKE,"blademaster/mirror-image"]
 var actions=Spells.SLOTS.keys();var key=Gear.Roster.loadout_key(34,hub.preview_settings())
 for i in ids.size():
  await activate(hub,"skill:"+ids[i])
  check(hub.spell_draft[key][actions[i%6]]==ids[i],"Double-click fills empty skill slots, then replaces them in order and wraps")
 check(FileAccess.get_sha256(cfg)!=saved and game.settings.spell_loadouts[key]==hub.spell_draft[key] and hub.status.text.is_empty(),"Double-click saves skill assignments immediately")
 await capture("skills-double-click-cycle")
 var equipped_skills=hub.spell_draft[key].duplicate()
 await pointer(hub.skill_buttons.equip)
 check(hub.spell_draft[key]==equipped_skills,"Single-clicking an equipped skill only selects it")
 await pointer(hub.skill_buttons.equip,true)
 equipped_skills.erase("equip")
 check(hub.spell_draft[key]==equipped_skills and hub.skill_buttons.equip.get_node("GearIcon").texture==null,"Double-click removes only the clicked character skill")
 await pointer(hub.skill_buttons.equip,true)
 check(hub.spell_draft[key]==equipped_skills,"Double-clicking an empty skill leaves the other slots intact")
 await pointer(hub.gear_buttons["2"],true)
 check(hub.spell_draft[key]==equipped_skills and hub.draft.is_empty(),"Double-clicking a locked weapon cannot remove the selected skill")
 hub.show_page("cosmetics");await pointer(hub.color_choices["qi-red"])
 check(hub.cosmetic_draft.is_empty(),"A single cosmetic click only inspects")
 await activate(hub,"qi-red");check(hub.cosmetic_draft[Gear.character_key(34)].slots=={"1":"qi-red"},"Double-click equips the cosmetic into the first empty slot")
 await activate(hub,"qi-gold");check(hub.cosmetic_draft[Gear.character_key(34)].slots=={"1":"qi-gold"},"Alternative Qi finishes replace the same item without occupying another slot")
 await pointer(hub.cosmetic_buttons["1"]);await pointer(hub.cosmetic_buttons["1"],true)
 check(hub.cosmetic_draft[Gear.character_key(34)].slots.is_empty() and hub.cosmetic_draft[Gear.character_key(34)].qi_color=="","Double-clicking the equipped cosmetic removes its slot and Qi finish")
 var empty_cosmetics=hub.cosmetic_draft.duplicate(true)
 await pointer(hub.cosmetic_buttons["1"],true);await pointer(hub.accessory_buttons["accessory:1"],true)
 check(hub.cosmetic_draft==empty_cosmetics and hub.draft.is_empty(),"Empty cosmetic and accessory slots do not change equipment")
 # Real accessory items share the same removal path as weapons and cosmetics.
 var accessory_key=Gear.character_key(34)
 hub.draft[accessory_key]={"accessory:1":"accessory:22","accessory:2":"accessory:23"};hub.refresh()
 await pointer(hub.accessory_buttons["accessory:1"]);await pointer(hub.accessory_buttons["accessory:1"],true)
 check(hub.draft[accessory_key]=={"accessory:2":"accessory:23"},"Double-click removes only the clicked accessory")
 hub.draft.erase(accessory_key);hub.refresh()
 hub.select_owner(1);hub.show_page("skills")
 for i in 5:
  var id=["kazi/qigong","kazi/fire","kazi/ice","kazi/wind","kazi/meteor"][i]
  await activate(hub,"skill:"+id)
  check(hub.pet_skill_draft[Pets.key(0)][i%3]==id,"Pet skill double-click fills three slots then cycles replacements")
 var pet_skills=hub.pet_skill_draft[Pets.key(0)].duplicate();pet_skills[1]=""
 await pointer(hub.skill_buttons.surge);await pointer(hub.skill_buttons.surge,true)
 check(hub.pet_skill_draft[Pets.key(0)]==pet_skills,"Double-click removes only the clicked pet skill")
 hub.select_owner(0)
 # Accessories and future cosmetic items use the same five-position replacement contract.
 for category in ["accessories","cosmetics"]:
  var probe=PlacementProbe.new();probe.game=game;probe.wearer_key=Gear.character_key(34);probe.page=category
  var slots=Gear.ACCESSORY_SLOTS if category=="accessories" else Gear.COSMETIC_SLOTS
  var filled={}
  for slot in slots:filled[slot]="fixture:"+slot
  if category=="accessories":probe.draft={probe.wearer_key:filled}
  else:probe.cosmetic_draft={probe.wearer_key:{"slots":filled}}
  probe.collection=["fixture:new"]
  for i in 7:probe.auto_equip(0)
  check(probe.assigned==[slots[0],slots[1],slots[2],slots[3],slots[4],slots[0],slots[1]],"Full "+category+" replace positions in order and wrap")
  probe.free()
 p.select_character(43);hub.refresh_party();hub.select_owner(0);hub.show_page("weapons")
 for i in 4:check(game.unlock_weapon_slot(Gear.character_key(43)),"Prepare unlocked weapon slots in the isolated save")
 var default_item="weapon:"+Gear.default_weapon(43,hub.preview_settings())
 var choices=hub.collection.filter(func(id):return id!=default_item)
 for id in choices:
  await pointer(hub.inventory[hub.collection.find(id)])
  check(Gear.equipped(hub.draft,43)==id and hub.inventory[hub.collection.find(id)].get_node("Equipped").visible,"One weapon click equips and marks the active choice immediately")
 var weapons=hub.draft[Gear.character_key(43)]
 check(Gear.WEAPON_SLOTS.all(func(slot):return weapons.has(slot)),"The starting weapon and four added weapons fill the unlocked positions")
 check(weapons["1"]==choices[4],"Once the weapon row is full the next click replaces slot one")
 var replacements=choices.size()-(Gear.WEAPON_SLOTS.size()-1)
 var next_slot:String=Gear.WEAPON_SLOTS[replacements%Gear.WEAPON_SLOTS.size()]
 await pointer(hub.inventory[hub.collection.find(default_item)]);check(weapons[next_slot]==default_item and Gear.equipped(hub.draft,43)==default_item,"The next click replaces and activates weapon slot "+next_slot)
 var clicked_weapons=weapons.duplicate();var replacement=hub.replace_next.duplicate()
 await activate(hub,default_item)
 check(weapons==clicked_weapons and hub.replace_next==replacement,"Double-clicking the active weapon does not duplicate it or advance replacement")
 await capture("weapons-single-click")
 var weapons_before=weapons.duplicate()
 var remaining_weapons=weapons.duplicate();remaining_weapons.erase(next_slot);remaining_weapons.erase("active_weapon")
 hub.show_page("skills")
 await pointer(hub.gear_buttons[next_slot])
 check(hub.draft[Gear.character_key(43)]==weapons_before,"Single-clicking an equipped weapon only selects it")
 await pointer(hub.gear_buttons[next_slot],true)
 check(hub.page=="weapons" and hub.draft[Gear.character_key(43)]==remaining_weapons,"Double-click removes the clicked weapon and clears its active selection")
 p.select_character(34);hub.refresh_party();hub.select_owner(0);hub.show_page("skills")
 await pointer(hub.portrait_button)
 var skin=Gear.Roster.skin_catalog(34).keys().filter(func(id):return id!=Gear.Roster.selected_skin(34,game.settings))[0]
 var index=Gear.Roster.skin_catalog(34).keys().find(skin)
 hub.portrait_button.choices.item_selected.emit(index)
 check(hub.appearance_draft.is_empty() and is_instance_valid(hub.portrait_button.gallery),"Single-clicking a skin only selects its preview")
 hub.portrait_button.choices.item_activated.emit(index);await frames(3)
 check(game.settings.kaz_skin==skin and hub.portrait_button.gallery==null,"Double-clicking a skin equips it and closes the picker without Done")
 check(hub.skill_buttons.values().all(func(button):return button.get_node("GearIcon").texture==null),"A different skin retains its separate empty skill loadout")
 await activate(hub,"skill:kazi/qigong");await activate(hub,"skill:"+Spells.KAGEROU)
 hub.enter_map();await frames(3);game.load_settings()
 check(p.spell_loadout.spell_for(34,"equip")=="kazi/qigong" and p.spell_loadout.spell_for(34,"surge")==Spells.KAGEROU,"Double-click choices save and reload into the selected skin's keys")
 p.spell_loadout.number_input(2,true);p.spell_loadout.number_input(2,false)
 check(p.active_ability.kagerou_enabled,"An explicitly equipped Kagerou works outside its former fixed slot")
 p.spell_loadout.equip(34,"surge","")
 check(not p.active_ability.kagerou_enabled and p.spell_loadout.numbered_slots[1].is_empty(),"Removing Kagerou disables it and leaves the key empty")
 p.select_character(35);check(p.spell_loadout.assignments(35).is_empty(),"Switching characters does not copy another fighter's equipped skills")
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("EQUIPMENT_DOUBLE_CLICK_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
