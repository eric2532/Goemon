extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Gear=preload("res://scripts/forest/equipment.gd")
const OUT="res://build/Other Files/Asset Toolkit/Equipment Hub/Icon Scaling/"

func picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Captured "+stem)

func run():
 create_timer(180).timeout.connect(func():printerr("WEAPON_ICON_SCALING_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.settings.forest_pet_loadout=[]
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE
 game.begin_arena();game.choose_rogue_character(34);await frames(3)
 var hub=game.equipment_hub
 hub.selected_item="weapon:unarmed";hub.equip_selected()
 var items=hub.available_items();var fist_index=items.find("weapon:unarmed")
 var dagger:AtlasTexture=Gear.ITEMS["weapon:kunai"].icon
 check(Gear.ITEMS["weapon:kunai"].name=="Dagger" and Gear.ITEMS["weapon:kunai"].weapon=="kunai","Dagger retains the saved weapon and attack route")
 check(dagger.atlas==load("res://assets/ui/crossgate/weapons/defaults/knife.png") and dagger.region==Rect2(0,0,24,23) and dagger.get_size()==Vector2(37,37),"Original dagger pixels use a smaller centered footprint without altering the source")
 check(game.skin_weapon_choices(36)==["Katana","Dagger","Fist"] and not "Kunai" in preload("res://scripts/spells/spell_catalog.gd").BLADE_DANCE_DESCRIPTION,"Weapon choices and Blade Dance consistently call the item Dagger")
 for dimensions in [Vector2i(1280,800),Vector2i(960,640)]:
  hub.selected_item="weapon:unarmed";hub.equip_selected()
  root.size=dimensions;await frames(4)
  var scale_:float=hub.panel.scale.x
  check(hub.inventory_grid.columns==6 and hub.inventory.filter(func(cell):return cell.visible).size()==48,"Six cells per row preserve all 48 visible weapon collection slots")
  check(hub.inventory_grid.size.x<=hub.inventory_scroll.size.x-hub.inventory_scroll.get_v_scroll_bar().size.x,"Six larger cells fit beside the scrollbar")
  var equipped_frame=Rect2(hub.panel.global_position+Vector2(40,206)*scale_,Vector2(352,388)*scale_)
  for slots in [hub.gear_buttons,hub.accessory_buttons,hub.cosmetic_buttons,hub.skill_buttons]:
   for slot in slots.values():
    check(equipped_frame.encloses(slot.get_global_rect()),"All four equipment rows stay inside the ivory frame")
    var icon:TextureRect=slot.get_node("GearIcon")
    check(icon.size==Vector2(44,44) and slot.get_global_rect().encloses(icon.get_global_rect()),"Every equipped item and skill has a larger icon inside its slot")
  var collection_frame=Rect2(hub.panel.global_position+Vector2(462,206)*scale_,Vector2(560,388)*scale_)
  for tab in [hub.equipment_tab,hub.skill_tab,hub.cosmetics_tab,hub.skills_tab]:
   check(collection_frame.encloses(tab.get_global_rect()),"All four tabs fit inside the collection frame")
  for category in ["weapons","accessories","cosmetics","skills"]:
   hub.show_page(category);await frames(3)
   check(collection_frame.encloses(hub.inventory_scroll.get_global_rect()) and hub.inventory_grid.size.x<=hub.inventory_scroll.size.x-hub.inventory_scroll.get_v_scroll_bar().size.x,"Each category grid fits the inner frame beside its scrollbar")
  hub.show_page("cosmetics");await frames(3)
  hub.inventory_scroll.scroll_vertical=10000;await frames(2)
  check(hub.inventory_scroll.scroll_vertical>0 and hub.inventory[47].get_global_rect().end.y<=hub.inventory_scroll.get_global_rect().end.y,"The last collection row remains reachable by scrolling")
  await picture("cosmetics-%dx%d"%[dimensions.x,dimensions.y])
  hub.show_page("weapons");hub.inventory_scroll.scroll_vertical=0
  hub.selected_item="weapon:unarmed";hub.refresh();await frames(3)
  for i in items.size():
   var row:TextureRect=hub.allowed_icons[i];var cell:TextureRect=hub.inventory[i].get_node("ItemIcon")
   check(row.get_global_rect().size.is_equal_approx(Vector2.ONE*20*scale_) and cell.get_global_rect().size.is_equal_approx(Vector2.ONE*64*scale_),"Every weapon shares the same responsive row and collection scale")
   check(row.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED and cell.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"Weapon art retains its aspect ratio")
   check(hub.inventory[i].get_global_rect().encloses(cell.get_global_rect()),"Scaled weapon art stays inside its collection cell")
  check(hub.inventory[fist_index].get_node("ItemIcon").material==hub.fist_material and hub.preview.material==hub.fist_material and hub.fist_material.get_shader_parameter("tint").r>1.0,"Fist badges share the brighter white tint while preserving original artwork")
  check(hub.allowed_icons[fist_index].texture==Gear.ITEMS["weapon:unarmed"].icon and hub.preview.texture==Gear.ITEMS["weapon:unarmed"].icon,"The responsive views retain the approved bandaged fist")
  check(hub.gear_buttons["1"].get_node("GearIcon").get_global_rect().size.is_equal_approx(Vector2.ONE*44*scale_) and hub.preview.get_global_rect().size.is_equal_approx(Vector2.ONE*64*scale_),"Equipped and preview fist icons follow the same parent scale")
  await picture("equipment-%dx%d"%[dimensions.x,dimensions.y])
  hub.selected_item="weapon:kunai";hub.equip_selected();await frames(3)
  var dagger_index=items.find("weapon:kunai")
  check(dagger_index>=0 and hub.allowed_icons[dagger_index].texture==dagger and hub.inventory[dagger_index].get_node("ItemIcon").texture==dagger and hub.preview.texture==dagger and hub.gear_buttons["1"].get_node("GearIcon").texture==dagger,"Allowed row, collection, preview and equipped slot share the smaller Dagger art")
  check(hub.inventory[dagger_index].accessibility_name=="Dagger","Collection identifies the item as Dagger")
  await picture("dagger-equipment-%dx%d"%[dimensions.x,dimensions.y])
 game.player.select_character(37);hub.refresh_party();hub.select_owner(0)
 check(hub.panel.get_children().all(func(node):return not node is Label or node.text!="Shin"),"Shin is named only in the top owner row")
 root.size=Vector2i(1280,800)
 for category in ["weapons","accessories","cosmetics","skills"]:
  hub.show_page(category);hub.inventory_scroll.scroll_vertical=0;await picture("shin-"+category+"-updated")
 game.player.select_character(36);hub.refresh_party();hub.select_owner(0)
 hub.enter_map();await frames(3)
 var ui=game.forest_ui;ui.set_process(false)
 var p=game.player
 for dimensions in [Vector2i(1280,800),Vector2i(960,640)]:
  root.size=dimensions
  for factor in [.65,1.0,1.25]:
   game.settings.forest_hud_scale=factor
   var sizes:Array=[]
   for weapon in ["sword","unarmed","kunai"]:
    var draft={Gear.character_key(36):{"1":"weapon:"+weapon}}
    check(game.save_equipment_loadouts(draft,{},{}),"Equip the comparison weapon in the isolated test save")
    ui.sync();await frames(4)
    var icons=[ui.primary_icon,ui.secondary_icon,ui.leader_utility_icon]
    for i in icons.size():
     var icon:TextureRect=icons[i]
     check(icon.texture==Gear.ITEMS["weapon:"+weapon].icon and icon.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"HUD uses the shared weapon texture with preserved proportions")
     if weapon=="sword":sizes.append(icon.get_global_rect().size)
     else:check(icon.get_global_rect().size.is_equal_approx(sizes[i]),"Weapon slots retain the same HUD scale while art keeps its own proportions")
     if weapon=="kunai":check(icon.texture==dagger and "Dagger" in (ui.ben_utility_tile.tooltip_text if i==2 else icon.tooltip_text),"HUD presents the smaller Dagger with its correct name")
   await picture("hud-%dx%d-%.2f"%[dimensions.x,dimensions.y,factor])
 game.sound_library.cancel();game.music.stop();game.queue_free();current_scene=null;paused=false;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("WEAPON_ICON_SCALING_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
