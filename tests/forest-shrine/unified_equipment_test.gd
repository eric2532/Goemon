extends SceneTree
const OUT="res://build/Other Files/Asset Toolkit/Unified Equipment/"
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const Skills=preload("res://scripts/spells/skill_balance.gd")
var game
var checks=0
var failures=0
var cfg="user://unified-equipment-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(180).timeout.connect(func():printerr("Unified Equipment timeout");quit(1))
 run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+message)
func frames(n:int=3):
 for i in n:await process_frame
func key(code:int,shift:bool=false):
 var event=InputEventKey.new();event.physical_keycode=code;event.shift_pressed=shift;event.pressed=true;game._input(event)
func click(control:Control):
 var event=InputEventMouseButton.new();event.device=104;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=control.get_global_rect().get_center()
 root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func capture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)
func fit(hub):
 check(root.get_visible_rect().encloses(hub.panel.get_global_rect()),"Unified Equipment fits the viewport")
 check(hub.panel.get_global_rect().encloses(hub.stats.panel.get_global_rect()),"Stat cards fit Equipment")
 check(not hub.stats.panel.get_global_rect().intersects(hub.inventory_scroll.get_global_rect()),"Stats clear the item collection")
 for plus in hub.stats.buttons.values():check(hub.stats.panel.get_global_rect().encloses(plus.get_global_rect()),"Stat upgrade fits")
 for slot in hub.skill_buttons.values():
  if slot.visible:check(hub.panel.get_node("EquippedItemsFrame").get_global_rect().encloses(slot.get_global_rect()),"Skill slot fits inside the equipment frame")
 if is_instance_valid(hub.pet_picker) and hub.pet_picker.visible:check(hub.panel.get_global_rect().encloses(hub.pet_picker.get_global_rect()),"Pet collection fits Equipment")
func run():
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(4)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.settings.forest_pet_loadout=[Pets.key(0),Pets.key(21)]
 game.begin_arena();game.choose_rogue_character(34);await frames()
 var hub=game.equipment_hub;var p=game.player;var xp=game.model.team_progression
 check(is_instance_valid(hub) and hub.stats.embedded and not is_instance_valid(game.status_panel),"Stats live inside pre-map Equipment")
 check(not game.playing and game.paused and paused,"Pre-map Equipment retains pause")
 check(hub.stats.buttons.size()==9 and hub.stats.values.size()==11,"Magic defense has an upgrade and an effective value")
 var stats=hub.stats
 check(stats.overview_content.visible and not stats.character_stats_content.visible and stats.tabs[0].button_pressed,"Equipment opens on the character's live stats")
 check(stats.attack_damage.text=="50" and stats.attack_damage.tooltip_text.begins_with("Per hit"),"A fresh normal attack shows the actual per-hit damage as a whole number")
 var magic_row:Label=stats.overview_values[3]
 var magic_defense_row:Label=stats.overview_values[10]
 var ordered_rows=[stats.overview_values[0],stats.attack_damage,magic_row,stats.overview_values[5],magic_defense_row]
 for i in range(1,ordered_rows.size()):check(ordered_rows[i].position.y-ordered_rows[i-1].position.y==29,"The top combat stats appear consecutively in the requested order")
 check(magic_row.text=="50" and magic_row.accessibility_name=="Magic damage","Magic damage starts at 50")
 check(magic_defense_row.text=="0" and magic_defense_row.accessibility_name=="Magic defense","Magic defense starts at zero")
 var shields=stats.overview_content.find_children("*","TextureRect",false,false).filter(func(view):return view.texture==stats.Icons.STATS.defense)
 check(shields.size()==2 and shields[0].self_modulate==Color.WHITE and shields[1].self_modulate.b>shields[1].self_modulate.g,"Magic defense reuses the shield texture with a purple tint")
 check(not stats.overview_values.has(2) and stats.overview_values.values().all(func(value):return "." not in value.text),"The character overview omits the duplicate physical multiplier and uses whole numbers")
 fit(hub);await capture("equipment-combat-stats")
 xp.award_kills(48);p.refresh_max_health(true);hub.refresh()
 hub.show_page("skills");hub.selected_slot="equip";hub.assign_skill("kazi/qigong");await frames()
 Skills.set_level(p,"kazi/qigong",2);hub.refresh()
 check(hub.skill_assignment("equip")=="skill:kazi/qigong" and hub.skill_levels.equip.text=="Lv2","Equipped character skill displays its learned level")
 check(hub.find_children("UpgradeSkill_*","Button",true,false).is_empty(),"Equipment has no skill point buttons")
 var saved=FileAccess.get_sha256(cfg)
 await click(stats.tabs[1])
 check(stats.character_stats_content.visible and not stats.overview_content.visible and not stats.tabs[0].button_pressed and hub.page=="skills","Upgrades opens independently of the item collection")
 await click(hub.stats.buttons.attack)
 check(xp.stat_ranks.attack==1 and xp.stat_points==1 and hub.stats.values[2].text=="x%.2f"%p.damage_multiplier(),"A stat click spends one shared point before entering the map")
 await click(hub.skill_buttons.equip)
 check(not game.spend_level_skill("kazi/qigong") and Skills.level_for(p,"kazi/qigong")==2 and xp.stat_points==1,"Inspecting a skill keeps its level and available stat points")
 await click(hub.stats.buttons.defense)
 check(xp.stat_points==0 and hub.stats.point_label.text=="0" and hub.stats.buttons.values().all(func(plus):return plus.disabled),"Stat upgrade buttons disable at zero points")
 check(FileAccess.get_sha256(cfg)==saved,"Upgrades do not rewrite saved loadouts")
 xp.stat_points=1;hub.refresh();await click(stats.buttons.magic_power)
 check(stats.overview_values[5].text=="14" and magic_defense_row.text=="4","Physical Defense points affect only the physical stat")
 xp.stat_points=1;hub.refresh();await click(stats.buttons.magic_defense)
 check(xp.stat_points==0 and xp.stat_ranks.magic_defense==1 and magic_defense_row.text=="14" and stats.values[10].text=="14","Magic defense spends a shared point and immediately refreshes both tabs")
 await capture("equipment-character-upgrades")
 await click(stats.tabs[0])
 check(stats.attack_damage.text==str(roundi(50.0*p.damage_multiplier())) and xp.stat_ranks.magic_power==1 and magic_row.text==str(roundi(50.0*p.magic_damage_multiplier())),"Combat stats show the independent Attack and Magic power upgrades")
 hub.show_page("accessories");hub.selected_slot="accessory:1";hub.selected_item="accessory:217";hub.equip_selected()
 check(stats.overview_content.visible and stats.attack_damage.text==str(roundi(100.0*p.base_damage_multiplier()+p.base_magic_damage())) and stats.attack_damage.tooltip_text.begins_with("Fire"),"Fire Earrings show spell damage plus base magic damage")
 hub.unequip()
 check(stats.attack_damage.text==str(roundi(50.0*p.damage_multiplier())),"Removing Fire Earrings restores the weapon damage display")
 root.size=Vector2i(960,640);await frames();fit(hub);await capture("equipment-combat-stats-small")
 await click(stats.tabs[1]);fit(hub);await capture("equipment-character-upgrades-small");await click(stats.tabs[0])
 root.size=Vector2i(1280,800);await frames()
 await click(hub.party[1]);hub.show_page("skills");hub.selected_slot="equip";hub.assign_skill("kazi/fire");await frames()
 check(stats.pet_stats_content.visible and not stats.overview_content.visible and not stats.tabs[0].visible,"Pet inspection occupies the same panel and hides character tabs")
 xp.stat_points=1;xp.pet_skill_levels={Pets.key(0):{"fire":2}};hub.refresh();saved=FileAccess.get_sha256(cfg)
 await click(hub.skill_buttons.equip)
 check(not game.spend_pet_skill(Pets.key(0),"kazi/fire") and hub.skill_levels.equip.text=="Lv2" and xp.stat_points==1,"Inspecting a pet skill displays its own level without spending points")
 check(FileAccess.get_sha256(cfg)==saved,"Pet skill inspection preserves saved loadouts")
 await capture("equipment-pet-skills")
 await click(hub.party[3]);var picker=hub.pet_picker
 check(is_instance_valid(picker) and picker.embedded and not is_instance_valid(game.pet_loadout_panel),"Pet collection lives inside Equipment")
 picker.filter(Pets.category(41));await frames();await click(picker.cards[41])
 check(Pets.key(41) in game.settings.forest_pet_loadout and hub.owners.size()==4,"An inline pet click saves and refreshes the party")
 check(Skills.pet_level_for(xp,Pets.key(0),"kazi/fire")==2,"Adding a pet preserves learned levels")
 await capture("equipment-pet-collection")
 hub.select_owner(4)
 var prior=game.settings.forest_pet_loadout.duplicate();var path=game.settings_path;game.settings_path="user://missing-unified-equipment-folder/settings.cfg"
 picker.toggle(61);game.settings_path=path
 check(game.settings.forest_pet_loadout==prior and picker.selected==Pets.sanitized(prior) and not picker.status.text.is_empty(),"Failed pet save rolls back the inline picker")
 picker.status.text="";picker.refresh()
 picker.filter("All")
 hub.select_owner(4);picker.toggle(61);hub.select_owner(5);picker.toggle(81)
 check(game.settings.forest_pet_loadout.size()==5,"Inline collection retains the five-pet limit")
 hub.select_owner(2);hub.change_pet();picker.toggle(82)
 check(game.settings.forest_pet_loadout[1]==Pets.key(82) and game.settings.forest_pet_loadout.size()==5,"A full party replaces the selected pet slot")
 hub.change_pet();await click(hub.party[2].get_node("RemovePet"))
 check(game.settings.forest_pet_loadout.size()==4 and Pets.key(82) not in game.settings.forest_pet_loadout and hub.page!="pets","Removing the selected pet closes its open replacement catalog")
 await click(hub.party[5]);check(hub.page=="pets","Empty party slots open the same pet collection")
 for dimensions in [Vector2i(1280,800),Vector2i(960,640)]:
  root.size=dimensions;await frames();fit(hub);await capture("equipment-%dx%d"%[dimensions.x,dimensions.y])
 var warm_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var warm_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for i in 30:hub.show_page("skills");hub.show_page("pets");hub.select_owner(i%hub.owners.size())
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==warm_nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))==warm_resources,"Tab and owner changes reuse controls/resources")
 hub.enter_map();await frames();check(game.playing and not is_instance_valid(game.equipment_hub) and not game.paused,"Enter Map retains the normal transition")
 key(KEY_I);key(KEY_P,true);await frames()
 check(not is_instance_valid(game.status_panel) and not is_instance_valid(game.pet_loadout_panel) and not is_instance_valid(game.equipment_hub),"I and Shift+P do not open separate windows")
 key(KEY_Q);await frames();hub=game.equipment_hub
 check(is_instance_valid(hub) and game.paused and paused and hub.stats.point_label.text==str(xp.stat_points),"Q opens the combined window in battle")
 check(not game.spend_level_skill("kazi/qigong") and not game.spend_pet_skill(Pets.key(0),"kazi/fire") and xp.stat_points==1,"In-game Equipment also rejects skill purchases")
 check(Skills.level_for(p,"kazi/qigong")==2 and Skills.pet_level_for(xp,Pets.key(0),"kazi/fire")==2,"Reopening retains learned levels")
 key(KEY_ESCAPE);await frames();check(not is_instance_valid(game.equipment_hub) and not game.paused and not paused,"Esc resumes the battle")
 key(KEY_Q);await frames();key(KEY_Q);await frames();check(not is_instance_valid(game.equipment_hub) and not game.paused,"Q also closes Equipment")
 key(KEY_P);await frames();check(not game.army_runtime.pending_hounds.is_empty() or not game.army_runtime.handles.is_empty(),"Plain P still summons through the native pet owner")
 key(KEY_Q);await frames();game.back_from_equipment();await frames(6)
 warm_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));warm_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for i in 5:
  key(KEY_Q);await frames();game.equipment_hub.show_page("pets");key(KEY_ESCAPE);await frames(6)
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==warm_nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))<=warm_resources,"Repeated combined-window use retains no controls/resources")
 p.select_character(Skills.Catalog.Roster.LANCELOT_ID);key(KEY_Q);await frames();hub=game.equipment_hub
 hub.selected_slot="1";hub.selected_item="weapon:sword";hub.equip_selected()
 hub.show_page("accessories");hub.selected_slot="accessory:1";hub.selected_item="accessory:241";hub.equip_selected()
 var multiplier=p.damage_multiplier()*p.attack_chain.damage_multiplier()
 check(hub.stats.attack_damage.text==str(roundi(50.0*multiplier)),"The bow-only accessory leaves sword damage in the overview")
 hub.show_page("weapons");hub.selected_item="weapon:bow";hub.equip_selected()
 check(hub.stats.attack_damage.text==str(roundi(212.5*multiplier)) and hub.stats.attack_damage.tooltip_text.begins_with("Random Shot · per arrow"),"Equipping Bow shows the per-arrow damage of the active Random Shot accessory")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(5);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("UNIFIED_EQUIPMENT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
