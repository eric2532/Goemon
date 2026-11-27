extends "res://tests/forest-shrine/four_crossgate_cast_test.gd"
const CosmeticCatalog=preload("res://scripts/forest/cosmetic_catalog.gd")

func run():
 create_timer(900).timeout.connect(func():printerr("BAU_GALLERY_TIMEOUT");quit(1))
 root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var catalog=Gear.Roster.skin_catalog(52)
 check(catalog.size()==19,"Bau exposes 19 skins")
 check(catalog.has(120384) and catalog.has(120385),"Bau keeps both original soccer variants")
 for skin in Gear.Roster.FourCastSkins.BAU_HIDDEN:
  var key="52:%d"%skin
  var gen_key="54:%d"%skin
  check(not catalog.has(skin) and Gear.Roster.GEN.skins.has(skin),"Both martial special skins belong to Gen")
  check(Gear.Roster.valid_loadout_key(key) and Gear.Roster.valid_loadout_key("54:%d"%skin) and not Gear.Roster.valid_loadout_key("53:%d"%skin),"Gen and archived Bau loadout keys remain valid")
  var source_root=Gear.Roster.skin_root(54,skin)
  check(Gear.Roster.skin_root(52,skin)==source_root,"Legacy Bau art lookups reuse Gen's prepared art")
  check(ResourceLoader.exists(source_root+"portrait.png") and FileAccess.file_exists(source_root+"motions.json"),"Gen retains the original prepared artwork")
  game.settings.bau_skin=skin;game.settings.skin_equipment[key]={"weapon":0,"primary_kunai":false}
  game.settings.spell_loadouts[key]={"equip":Gear.Spells.BODYGUARD}
  game.settings.skin_equipment.erase(gen_key);game.settings.spell_loadouts.erase(gen_key)
  game.save_settings();game.load_settings()
  check(game.settings.bau_skin==Gear.Roster.BAU.skin_default,"Loading a hidden selection safely restores Bau's default")
  check(game.settings.skin_equipment.get(key)=={"weapon":0,"primary_kunai":false},"Save/reload retains archived equipment")
  check(game.settings.skin_equipment.get(gen_key)==game.settings.skin_equipment[key],"Gen inherits the skin's original stance preferences")
  check(game.settings.spell_loadouts.get(gen_key)=={"equip":Gear.Spells.BODYGUARD} and game.settings.spell_loadouts.get(key)==game.settings.spell_loadouts[gen_key],"Gen inherits the skin's spells while retaining the original assignment")
  game.settings.gen_skin=skin
  check(game.skin_equipment(54)==game.settings.skin_equipment[key] and game.player.spell_loadout.assignments(54).get("equip")==Gear.Spells.BODYGUARD,"The new Gen skin reads both recovered saved choices")
  game.settings.skin_equipment[gen_key]={"weapon":1,"primary_kunai":true}
  game.settings.spell_loadouts[gen_key]={"equip":Gear.Spells.KAGEROU}
  game.save_settings();game.load_settings()
  check(game.settings.skin_equipment.get(gen_key)=={"weapon":1,"primary_kunai":true} and game.settings.spell_loadouts.get(gen_key)=={"equip":Gear.Spells.KAGEROU},"Newer Gen stance and spell edits win on repeated load")
  check(game.settings.skin_equipment.get(key)=={"weapon":0,"primary_kunai":false} and game.settings.spell_loadouts.get(key)=={"equip":Gear.Spells.BODYGUARD},"A second save/reload keeps both original Bau records")
 for character in CAST:
  check(Gear.Roster.skin_catalog(character).size()==CAST[character],"Other gallery counts remain correct")
 game.settings.bau_skin=105000;game.settings.forest_pet_loadout=[]
 game.settings.cosmetic_loadouts[Gear.character_key(54)]={"qi_color":"","slots":{"1":"cosmetic:119802","2":"cosmetic:119010"}}
 game.save_settings();game.begin_arena();game.choose_rogue_character(52);await frames(3)
 var hub=game.equipment_hub
 check(hub!=null,"Bau enters through the normal Equipment flow")
 var picker=hub.portrait_button
 check(picker.character==52 and picker.catalog==catalog,"The actual Bau Equipment picker receives the corrected gallery")
 if picker!=null:
  picker.pressed.emit();await frames(3)
  check(picker.choices.item_count==19,"The open gallery contains exactly 19 cards")
  for i in picker.choices.item_count:
   check(picker.choices.get_item_metadata(i) not in Gear.Roster.FourCastSkins.BAU_HIDDEN,"No hidden entry becomes a visible card")
  if DisplayServer.get_name()!="headless":
   var path="res://build/Other Files/Asset Toolkit/Bau El Gen Sarah/Bau Skin Correction/"
   DirAccess.make_dir_recursive_absolute(path);await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png(path+"bau-gallery.png")==OK,"Captured Bau's rendered skin gallery")
  picker.gallery.hide();await frames(2)
 game.player.select_character(54);hub.refresh_party();await frames(2)
 check(hub.portrait_button.character==54 and hub.portrait_button.catalog.size()==18,"Changing the leader updates Equipment to Gen's 18 skins")
 hub.enter_button.pressed.emit();await frames(3)
 game.show_equipment_hub(true);await frames(3)
 hub=game.equipment_hub
 var visual=game.player.model
 var gen_picker=hub.portrait_button
 check(gen_picker.character==54 and gen_picker.catalog.size()==18,"The actual Gen Equipment picker offers all 18 skins")
 if gen_picker!=null:
  for skin in Gear.Roster.FourCastSkins.BAU_HIDDEN:
   gen_picker.pressed.emit();await frames(2)
   var choice=-1
   for i in gen_picker.choices.item_count:
    if gen_picker.choices.get_item_metadata(i)==skin:choice=i
   check(choice>=0,"Gen's open gallery includes special skin %d"%skin)
   if choice<0:continue
   gen_picker.choices.select(choice);gen_picker.choices.ensure_current_is_visible();await frames(2)
   if DisplayServer.get_name()!="headless":
    var path="res://build/Other Files/Asset Toolkit/Bau El Gen Sarah/Bau Skin Correction/"
    DirAccess.make_dir_recursive_absolute(path);await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png(path+"gen-gallery-%d.png"%skin)==OK,"Captured Gen's rendered skin gallery")
   gen_picker.choices.item_activated.emit(choice);await frames(2)
   check(game.settings.gen_skin==skin and visual==game.player.model and visual.variant_skin==skin,"The real gallery selects Gen skin %d on the existing model"%skin)
   check(visual.native_root==Gear.Roster.skin_root(54,skin) and visual.profile(visual.native_root).id==skin,"Gen loads the matching original source manifest")
   check(game.forest_ui.PaintedHeads.portrait(54,game.settings)!=null,"Gen's selected skin has its matching prepared HUD head")
   var weapon=str(visual.profile(visual.native_root).weapon)
   check(weapon in Gear.allowed(54,game.settings),"Gen offers the skin's recovered native weapon")
   equip_weapon(54,weapon)
   check(visual.current_weapon()==weapon,"Gen equips its original %s stance"%weapon)
   for direction in 8:
    var pose="5:%d"%direction;var motion:Dictionary=visual.body_clip(5,pose)
    visual.show_frame(5,pose,int(motion.contact*motion.frames.size()))
    check(not motion.frames.is_empty() and not motion.contacts.is_empty() and visual.attack_sound(false,0,motion)!=null,"Gen's original facing %d retains attack frames, contact and audio"%direction)
    visual.cosmetic_layers.update(.016,visual.sprite,pose,true)
    check(CosmeticCatalog.frame_anchors(visual.sprite.texture.resource_path).has(Vector2i(visual.sprite.region_rect.position)) and visual.cosmetic_layers.nodes.slice(0,2).all(func(node):return node.visible and node.texture!=null),"Reassigned Gen skin keeps both prepared cosmetic attachments")
   var copies=preload("res://scripts/warcraft_mirrors.gd").new(game.player,0)
   for i in 3:
    check(copies.reinforce(54,game.player.position+Vector3(i*2,0,-8)),"Reassigned Gen skin uses the existing native army copy owner")
    var copy=copies.bodies.back()
    check(copy.model.variant_skin==skin and copy.model.current_weapon()==weapon,"Native Gen copies retain the reassigned skin and native weapon")
    var clip:Dictionary=copy.model.body_clip(5,"5:4")
    copy.model.show_frame(5,"5:4",int(clip.contact*clip.frames.size()));copy.model._process(.016)
    check(copy.model.cosmetic_layers.selected==visual.cosmetic_layers.selected,"Native Gen copies retain both selected cosmetics")
   copies.dispose();await frames(2)
   game.save_settings();game.load_settings()
   check(game.settings.gen_skin==skin and Gear.Roster.selected_skin(54,game.settings)==skin and visual.variant_skin==skin,"Gen's reassigned selection survives save/reload")
 print("BAU_GALLERY_RESULT checks=%d failures=%d"%[checks,failures])
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
