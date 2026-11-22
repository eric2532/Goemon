extends Control
const Gear=preload("res://scripts/forest/equipment.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const MenuSkin=preload("res://scripts/forest/preparation_skin.gd")
const Gallery=preload("res://scripts/rogue_roster_picker.gd")
const SkinPicker=preload("res://scripts/character_skin_picker.gd")
const BAG=preload("res://assets/ui/crossgate/equipment/inventory.png")
const ORBS=preload("res://assets/characters/crossgate/qigong/orbs.png")
const TINT=preload("res://assets/ui/crossgate/equipment/tint.gdshader")
const Spells=preload("res://scripts/spells/spell_catalog.gd")
const Skills=preload("res://scripts/spells/skill_balance.gd")
const Status=preload("res://scripts/forest/character_status_panel.gd")
const SIZE=Vector2(1440,760)
const CAPACITY=48
const INVENTORY_COLUMNS=6
const SKILL_PAGES=["skills","pet_skills"]
const PET_INSPIRED_SKILLS=[Spells.BEE_FLURRY]
var game
var panel:Control
var draft:Dictionary={}
var skill_draft:Dictionary={}
var cosmetic_draft:Dictionary={}
var appearance_draft:Dictionary={}
var spell_draft:Dictionary={}
var pet_skill_draft:Dictionary={}
var pet_skills_edited:Dictionary={}
var page="weapons"
var equipment_tab:Button
var skill_tab:Button
var cosmetics_tab:Button
var skills_tab:Button
var pet_skills_tab:Button
var pet_picker:Control
var color_choices:Dictionary={}
var inventory_scroll:ScrollContainer
var inventory_grid:GridContainer
var owners:Array[String]=[]
var wearer_key=""
var selected_pet_slot=-1
var pet_return_page="skills"
var change_pet_button:Button
var pet_name_field:LineEdit
var save_pet_name_button:Button
var party:Array[Button]=[]
var pet_slot_styles:Dictionary={}
var gear_buttons:Dictionary={}
var accessory_buttons:Dictionary={}
var cosmetic_buttons:Dictionary={}
var skill_buttons:Dictionary={}
var skill_levels:Dictionary={}
var passive_heading:Label
var passive_slot:Panel
var passive_icon:TextureRect
var stats:Control
var inventory:Array[Button]=[]
var collection:Array=[]
var replace_next:Dictionary={}
var selected_item=""
var selected_slot="1"
var pictured_wearer=""
var detail:Label
var status:Label
var portrait:TextureRect
var portrait_button:SkinPicker
var allowed_icons:Array[TextureRect]=[]
var preview:TextureRect
var enter_button:Button
var color_materials:Dictionary={}
var orb:AtlasTexture
var slot_style:StyleBoxTexture
var fist_material:ShaderMaterial
var character_preview:SubViewportContainer
var preview_body:Sprite3D
var preview_camera:Camera3D
var preview_layers=preload("res://scripts/forest/cosmetic_layers.gd").new()
var preview_key=""

func text(value:String,at:Vector2,extent:Vector2,font_size:int=18,color:Color=MenuSkin.PAPER)->Label:
 var node=Label.new();node.text=value;node.position=at;node.size=extent
 node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",color)
 node.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(node);return node
func button(value:String,at:Vector2,extent:Vector2,action:Callable)->Button:
 var node=Button.new();node.text=value;node.position=at;node.size=extent;node.pressed.connect(action)
 panel.add_child(node);return node
func picture(texture:Texture2D,at:Vector2,extent:Vector2,parent:Control=null)->TextureRect:
 var node=TextureRect.new();node.texture=texture;node.position=at;node.size=extent
 node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 node.mouse_filter=Control.MOUSE_FILTER_IGNORE;(parent if parent!=null else panel).add_child(node);return node
func frame(rect:Rect2)->Panel:
 var node=Panel.new();node.position=rect.position;node.size=rect.size
 node.add_theme_stylebox_override("panel",MenuSkin.panel());node.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(node);return node
func style_slot(hit:Button):
 for state in ["normal","hover","pressed","hover_pressed","disabled"]:hit.add_theme_stylebox_override(state,slot_style)
 picture(null,Vector2(8,2),Vector2(44,44),hit).name="GearIcon"
 hit.pressed.connect(inspect_control.bind(hit))

func _ready():
 name="EquipmentHub";process_mode=Node.PROCESS_MODE_ALWAYS;theme=MenuSkin.theme()
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 read_loadouts()
 fist_material=ShaderMaterial.new();fist_material.shader=TINT;fist_material.set_shader_parameter("tint",Color(1.12,1.12,1.12))
 var background=TextureRect.new();background.texture=preload("res://assets/ui/maroon/blue_cross_gate_title_roster.png")
 background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shade=ColorRect.new();shade.color=Color(.035,.06,.07,.9);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel=Control.new();panel.size=SIZE;add_child(panel)
 text("EQUIPMENT",Vector2(22,17),Vector2(700,38),30)
 text("MAIN CHARACTER",Vector2(24,57),Vector2(198,24),15).name="MainCharacterHeading"
 text("PETS",Vector2(248,57),Vector2(640,24),15).name="PetsHeading"
 for i in 6:
  var choice=button("",Vector2(24 if i==0 else 248+(i-1)*160,83),Vector2(198 if i==0 else 152,70),game.choose_character_from_equipment if i==0 else select_owner.bind(i))
  choice.name="EquipmentWearer%d"%i;choice.toggle_mode=true;choice.expand_icon=true
  choice.add_theme_constant_override("icon_max_width",56);choice.add_theme_font_size_override("font_size",14)
  choice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;party.append(choice)
  var outline=Panel.new();outline.name="SelectedOutline";outline.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var gold=StyleBoxFlat.new();gold.bg_color=Color.TRANSPARENT;gold.border_color=Status.GOLD;gold.set_border_width_all(3);gold.set_corner_radius_all(4)
  outline.add_theme_stylebox_override("panel",gold);choice.add_child(outline);outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);outline.hide()
 party[0].tooltip_text="Choose a character"
 frame(Rect2(20,172,410,470)).name="EquippedItemsFrame";frame(Rect2(442,172,618,470)).name="CollectionFrame"
 var cell=AtlasTexture.new();cell.atlas=BAG;cell.region=Rect2(24,49,48,48);cell.filter_clip=true
 slot_style=StyleBoxTexture.new();slot_style.texture=cell
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:slot_style.set_texture_margin(side,5)
 portrait=picture(null,Vector2(84,202),Vector2(312,124));portrait.name="EquipmentCharacter"
 character_preview=SubViewportContainer.new();character_preview.name="EquippedAppearance"
 character_preview.position=portrait.position;character_preview.size=portrait.size;character_preview.stretch=true
 character_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(character_preview)
 var viewport=SubViewport.new();viewport.size=Vector2i(portrait.size);viewport.own_world_3d=true;viewport.transparent_bg=true
 viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE;character_preview.add_child(viewport)
 preview_body=Sprite3D.new();preview_body.region_enabled=true;preview_body.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 preview_body.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;viewport.add_child(preview_body)
 preview_body.set_instance_shader_parameter("grounded",false)
 preview_camera=Camera3D.new();preview_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;preview_camera.keep_aspect=Camera3D.KEEP_HEIGHT
 preview_camera.position=Vector3(0,1.8,10);preview_camera.size=4.4;viewport.add_child(preview_camera)
 portrait_button=SkinPicker.new();portrait_button.name="EquipmentSkinPicker"
 portrait_button.character=Gear.Roster.gallery_id(game.player.character_id);portrait_button.catalog=Gear.Roster.skin_catalog(portrait_button.character)
 portrait_button.selected_id=Gear.Roster.selected_skin(portrait_button.character,preview_settings())
 portrait_button.show_caption=false;portrait_button.selection_is_draft=true
 portrait_button.position=portrait.position;portrait_button.size=portrait.size;portrait_button.accessibility_name="Change skin"
 portrait_button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 for state in ["normal","hover","pressed","disabled"]:portrait_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
 portrait_button.skin_selected.connect(select_skin);panel.add_child(portrait_button)
 for i in Gear.ITEMS.values().filter(func(item):return item.has("weapon")).size():
  var icon=picture(null,Vector2.ZERO,Vector2(20,20));icon.name="AllowedWeapon%d"%i
  allowed_icons.append(icon)
 var rows=[["Weapons","weapons",Gear.WEAPON_SLOTS,gear_buttons],["Accessories","accessories",Gear.ACCESSORY_SLOTS,accessory_buttons],["Cosmetics","cosmetics",Gear.COSMETIC_SLOTS,cosmetic_buttons]]
 for row_index in rows.size():
  var row=rows[row_index];var y=340+row_index*68
  text(row[0],Vector2(48,y-20),Vector2(350,20),16)
  for i in row[2].size():
   var slot:String=row[2][i]
   var hit=button("",Vector2(48+i*70,y),Vector2(60,48),select_category_slot.bind(row[1],slot))
   hit.gui_input.connect(slot_input.bind(hit,row[1],slot))
   hit.name="EquipmentSlot_"+slot if row_index==0 else row[1]+"Slot_"+slot
   style_slot(hit);row[3][slot]=hit
   var lock_icon=picture(preload("res://assets/ui/crossgate/equipment/lock.svg"),Vector2(14,8),Vector2(32,32),hit)
   lock_icon.name="Lock";lock_icon.hide()
 text("Skills",Vector2(48,524),Vector2(350,20),16)
 for i in Spells.SLOTS.size():
  var action:String=Spells.SLOTS.keys()[i]
  var hit=button("",Vector2(48+i*58,544),Vector2(48,48),select_category_slot.bind("skills",action));hit.name="SkillSlot_"+action
  hit.gui_input.connect(slot_input.bind(hit,"skills",action))
  style_slot(hit);hit.get_node("GearIcon").position=Vector2(2,2);skill_buttons[action]=hit
  skill_levels[action]=text("",Vector2(51+i*58,545),Vector2(42,16),10)
  skill_levels[action].add_theme_color_override("font_outline_color",Color("19212b"))
  skill_levels[action].add_theme_constant_override("outline_size",3)
 passive_heading=text("Passive Skills",Vector2(248,524),Vector2(150,20),16)
 passive_slot=Panel.new();passive_slot.name="PetPassiveSlot";passive_slot.position=Vector2(248,544);passive_slot.size=Vector2(48,48)
 passive_slot.add_theme_stylebox_override("panel",slot_style);passive_slot.mouse_filter=Control.MOUSE_FILTER_PASS;panel.add_child(passive_slot)
 passive_icon=picture(null,Vector2(2,2),Vector2(44,44),passive_slot)
 equipment_tab=button("Weapons",Vector2(474,210),Vector2(100,37),show_page.bind("weapons"));equipment_tab.name="WeaponsPage"
 skill_tab=button("Accessories",Vector2(580,210),Vector2(110,37),show_page.bind("accessories"));skill_tab.name="AccessoriesPage"
 cosmetics_tab=button("Cosmetics",Vector2(696,210),Vector2(100,37),show_page.bind("cosmetics"));cosmetics_tab.name="CosmeticsPage"
 skills_tab=button("Skills",Vector2(802,210),Vector2(86,37),show_page.bind("skills"));skills_tab.name="SkillsPage"
 pet_skills_tab=button("Pet Skills",Vector2(894,210),Vector2(112,37),show_page.bind("pet_skills"));pet_skills_tab.name="PetSkillsPage"
 for tab in [equipment_tab,skill_tab,cosmetics_tab,skills_tab,pet_skills_tab]:tab.toggle_mode=true;tab.add_theme_font_size_override("font_size",13)
 inventory_scroll=ScrollContainer.new();inventory_scroll.name="EquipmentCollection";inventory_scroll.position=Vector2(474,257);inventory_scroll.size=Vector2(548,332)
 inventory_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(inventory_scroll)
 inventory_grid=GridContainer.new();inventory_grid.columns=INVENTORY_COLUMNS;inventory_grid.add_theme_constant_override("h_separation",8);inventory_grid.add_theme_constant_override("v_separation",4);inventory_scroll.add_child(inventory_grid)
 add_inventory_cells(CAPACITY)
 orb=orb_texture();preview=picture(null,Vector2(28,653),Vector2(64,64))
 detail=text("",Vector2(107,656),Vector2(780,60),16);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 detail.vertical_alignment=VERTICAL_ALIGNMENT_TOP
 detail.max_lines_visible=3;detail.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;detail.clip_text=true
 status=text("",Vector2(24,728),Vector2(860,23),14)
 button("Back",Vector2(1265,17),Vector2(143,34),game.back_from_equipment)
 enter_button=button("Enter Map",Vector2(909,664),Vector2(139,46),enter_map);enter_button.name="EnterEquipmentMap"
 if game.equipment_from_game:enter_button.text="Return"
 for id in Gear.COLORS:
  var material=ShaderMaterial.new();material.shader=TINT;material.set_shader_parameter("tint",Gear.COLORS[id].color);color_materials[id]=material
  material.set_shader_parameter("chrome",id=="qi-chrome")
 stats=Status.new();stats.game=game;stats.embedded=true;panel.add_child(stats)
 stats.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);stats.position=Vector2(1080,172);stats.size=Vector2(340,470)
 pet_name_field=LineEdit.new();pet_name_field.name="PetName"
 pet_name_field.position=Vector2(48,289);pet_name_field.size=Vector2(143,28)
 pet_name_field.max_length=Pets.MAX_NAME_LENGTH;pet_name_field.accessibility_name="Pet name"
 pet_name_field.add_theme_font_size_override("font_size",14)
 pet_name_field.text_submitted.connect(func(_name):save_pet_name())
 panel.add_child(pet_name_field)
 save_pet_name_button=button("Save",Vector2(198,289),Vector2(64,28),save_pet_name);save_pet_name_button.name="SavePetName"
 save_pet_name_button.accessibility_name="Save pet name";stats.style_button(save_pet_name_button)
 change_pet_button=button("Change pet",Vector2(269,289),Vector2(110,28),change_pet);change_pet_button.name="ChangePet";stats.style_button(change_pet_button)
 for state in ["normal","hover","pressed","hover_pressed","disabled"]:
  var style=MenuSkin.button_style(state);style.content_margin_right=30
  pet_slot_styles[state]=style
 for i in range(1,party.size()):
  var remove_button=Button.new();remove_button.name="RemovePet";remove_button.text="×"
  stats.style_button(remove_button);remove_button.pressed.connect(remove_pet.bind(i-1))
  party[i].add_child(remove_button);remove_button.size=Vector2(24,24)
  remove_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT,Control.PRESET_MODE_KEEP_SIZE,4)
 resized.connect(layout);layout();refresh_party();party[0].grab_focus()

func add_inventory_cells(count:int):
 while inventory.size()<count:
  var index=inventory.size();var item=Button.new();item.name="InventorySlot%d"%index;item.custom_minimum_size=Vector2(82,80)
  item.pressed.connect(select_item.bind(index));item.gui_input.connect(inventory_input.bind(index));inventory_grid.add_child(item);style_slot(item)
  item.get_node("GearIcon").position=Vector2(9,8);item.get_node("GearIcon").size=Vector2(64,64);item.get_node("GearIcon").name="ItemIcon"
  var mark=Label.new();mark.name="Equipped";mark.text="✓";mark.position=Vector2(65,0);mark.mouse_filter=Control.MOUSE_FILTER_IGNORE
  mark.add_theme_color_override("font_color",MenuSkin.INK);item.add_child(mark);inventory.append(item)
func orb_texture()->AtlasTexture:
 var texture=AtlasTexture.new();texture.atlas=ORBS;texture.region=Rect2(0,0,63,62)
 # Transparent padding matches the small skill icon without changing the original orb or chrome UVs.
 texture.margin=Rect2(23,24,47,48);texture.filter_clip=true;return texture
func layout():
 var factor=minf(1.0,minf((size.x-24)/SIZE.x,(size.y-24)/SIZE.y))
 panel.scale=Vector2.ONE*factor;panel.position=(size-SIZE*factor)*.5
func preview_settings()->Dictionary:
 var settings:Dictionary=game.settings.duplicate();settings.merge(appearance_draft,true);return settings
func refresh_party():
 var saved_skills=Pets.sanitized_skills(game.settings.get("forest_pet_skills",{}))
 for key in pet_skills_edited:
  if pet_skill_draft.has(key):saved_skills[key]=pet_skill_draft[key]
  else:saved_skills.erase(key)
 pet_skill_draft=saved_skills
 owners.assign([Gear.character_key(Gear.Roster.skin_character(game.player.character_id,preview_settings()))])
 for key in Pets.sanitized(game.settings.forest_pet_loadout):owners.append(Gear.pet_key(key))
 if selected_pet_slot>=0:
  selected_pet_slot=mini(selected_pet_slot,owners.size()-1)
  wearer_key=owners[selected_pet_slot+1] if selected_pet_slot+1<owners.size() else ""
 elif wearer_key not in owners:wearer_key=owners[0];selected_slot=first_slot_for(page)
 for i in party.size():
  var filled=i<owners.size();party[i].disabled=i>owners.size()
  party[i].text=wearer_name(owners[i]) if filled else "Add pet" if i==owners.size() else "—";party[i].icon=wearer_portrait(owners[i]) if filled else null
  if i>0:
   party[i].clip_text=true
   var remove_button:Button=party[i].get_node("RemovePet")
   remove_button.visible=filled
   remove_button.tooltip_text="Remove "+party[i].text if filled else ""
   remove_button.accessibility_name=remove_button.tooltip_text
   for state in pet_slot_styles:
    if filled:party[i].add_theme_stylebox_override(state,pet_slot_styles[state])
    elif party[i].has_theme_stylebox_override(state):party[i].remove_theme_stylebox_override(state)
 refresh()
func wearer_name(key:String)->String:
 if key.is_empty():return "Empty pet slot"
 return Gear.Roster.name_for(Gear.Roster.gallery_id(int(key.trim_prefix("character:")))) if key.begins_with("character:") else Pets.display_name(Pets.skin(key.trim_prefix("pet:")),game.settings.forest_pet_names)
func wearer_portrait(key:String)->Texture2D:
 if key.is_empty():return null
 return Gallery.selection_texture(int(key.trim_prefix("character:")),preview_settings()) if key.begins_with("character:") else Pets.portrait(Pets.skin(key.trim_prefix("pet:")))
func first_slot_for(category:String)->String:
 return "equip" if category in SKILL_PAGES else Gear.ACCESSORY_SLOTS[0] if category=="accessories" else "1"
func select_owner(index:int):
 if index<0 or index>=party.size():return
 selected_pet_slot=mini(index-1,owners.size()-1) if index>0 else -1
 wearer_key=owners[index] if index<owners.size() else "";selected_item=""
 if page=="pets":page=pet_return_page
 selected_slot=first_slot_for(page);refresh()
 if wearer_key.is_empty():show_page("pets")
func change_pet():
 show_page(pet_return_page if page=="pets" else "pets")
func save_pet_name():
 if not wearer_key.begins_with("pet:"):return
 var key=wearer_key.trim_prefix("pet:")
 if not game.save_pet_name(key,pet_name_field.text):
  status.text="Could not save the pet name. Try again."
  return
 pet_name_field.text=game.settings.forest_pet_names.get(key,"")
 pet_name_field.release_focus()
 refresh_party()
 status.text="Pet name saved."
func finish_pet_change(slot:int):
 selected_pet_slot=slot;page=pet_return_page;selected_item=""
 selected_slot=first_slot_for(page);refresh_party()
func remove_pet(slot:int):
 var selected=Pets.sanitized(game.settings.forest_pet_loadout)
 if slot<0 or slot>=selected.size():return
 selected.remove_at(slot)
 if not game.save_pet_loadout(selected):
  status.text="Could not save the loadout. Your previous selection is unchanged."
  return
 if slot<selected_pet_slot:selected_pet_slot-=1
 elif slot==selected_pet_slot:
  if page=="pets":page=pet_return_page;selected_slot=first_slot_for(page)
  selected_item=""
 refresh_party()
func show_page(value:String):
 value={"character":"weapons","skill":"accessories"}.get(value,value)
 if value not in ["weapons","accessories","cosmetics","skills","pet_skills","pets"]:return
 if value in SKILL_PAGES and wearer_key.is_empty():
  selected_pet_slot=-1;wearer_key=owners[0]
 if value=="pets" and page!="pets":pet_return_page=page
 if value=="pets" and selected_pet_slot<0 and owners.size()<=Pets.MAX_ACTIVE:
  selected_pet_slot=owners.size()-1;wearer_key=""
 if value=="pets" and not is_instance_valid(pet_picker):
  pet_picker=preload("res://scripts/forest/pet_loadout_panel.gd").new();pet_picker.game=game;pet_picker.embedded=true;panel.add_child(pet_picker)
  pet_picker.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);pet_picker.position=Vector2(474,257);pet_picker.size=Vector2(548,332)
 if not (value in SKILL_PAGES and page in SKILL_PAGES):selected_slot=first_slot_for(value)
 page=value;selected_item="";refresh()
func active_loadout()->Dictionary:return cosmetic_draft if page=="cosmetics" else draft
func select_skin(id:int):
 if not wearer_key.begins_with("character:"):return
 var character=Gear.Roster.gallery_id(int(wearer_key.trim_prefix("character:")))
 if not Gear.Roster.skin_catalog(character).has(id):return
 appearance_draft[Gear.Roster.skin_setting(character)]=id
 pictured_wearer="";apply_changes()
func available_items()->Array:
 if wearer_key.is_empty():return []
 if page=="pets":return []
 if page in SKILL_PAGES:
  var ids=Pets.SKILLS.keys() if wearer_key.begins_with("pet:") else skills_for_weapons().filter(func(id):return Spells.available(Spells.all()[id]))
  var pet_inspired=page=="pet_skills"
  return ids.filter(func(id):return id!=Spells.MAZE_QI and (id in PET_INSPIRED_SKILLS)==pet_inspired).map(func(id):return "skill:"+id)
 if page=="cosmetics":
  var result=[""]+Gear.COLORS.keys()
  result.append_array(Gear.ITEMS.keys().filter(func(id):return Gear.ITEMS[id].get("category","")=="cosmetics" and Gear.can_equip(wearer_key,id,preview_settings())))
  return result
 return Gear.ITEMS.keys().filter(func(id):return (Gear.ITEMS[id].has("weapon") if page=="weapons" else not Gear.ITEMS[id].has("weapon") and Gear.ITEMS[id].get("category","character") in ["character","accessories"]) and Gear.can_equip(wearer_key,id,preview_settings()))
func item_data(id:String)->Dictionary:
 if id.begins_with("skill:"):
  var skill_id=id.trim_prefix("skill:")
  var spec:Dictionary=Spells.all().get(skill_id,{})
  var description=Spells.mana_description(skill_id)
  if not spec.get("description","").is_empty():description+="\n"+spec.description
  return {"name":spec.get("name",""),"description":description,"icon":skill_icon(skill_id)}
 if Gear.COLORS.has(id) or id.is_empty():return {"name":Gear.COLORS[id].name+" Qi" if Gear.COLORS.has(id) else "Regular Qi","icon":orb,"description":""}
 var data:Dictionary=Gear.item_data(id,game.settings)
 data.description=data.get("description","Ranged arrows" if data.get("weapon","")=="bow" else "")
 return data
func inspect_control(control:Control):
 if not control.has_meta("description"):return
 detail.text=control.get_meta("description");preview.texture=control.get_meta("icon") if control.has_meta("icon") else null;preview.material=control.get_meta("material") if control.has_meta("material") else null
func set_cosmetic_color(id:String):
 if page!="cosmetics" or wearer_key not in owners or (not id.is_empty() and not Gear.COLORS.has(id)):return
 var slots=Gear.cosmetic_slots(cosmetic_draft,wearer_key)
 for slot in slots.keys():
  if Gear.COLORS.has(slots[slot]):slots.erase(slot)
 var slot=selected_slot if selected_slot in Gear.COSMETIC_SLOTS else "1"
 if not id.is_empty():slots[slot]=id
 cosmetic_draft[wearer_key]={"qi_color":id,"slots":slots};selected_slot=slot;selected_item=id
 apply_changes()
func select_category_slot(category:String,slot:String):
 if category in SKILL_PAGES:
  if not editable_skill(slot):return
  if category=="skills":
   if page in SKILL_PAGES:category=page
   elif skill_assignment(slot).trim_prefix("skill:") in PET_INSPIRED_SKILLS:category="pet_skills"
 if category=="weapons" and int(slot)>Gear.unlocked(wearer_key,game.settings):return
 page=category;selected_slot=slot;selected_item=""
 if category in SKILL_PAGES:selected_item=skill_assignment(slot)
 elif category=="cosmetics":selected_item=Gear.cosmetic_slots(cosmetic_draft,wearer_key).get(slot,"")
 else:selected_item=draft.get(wearer_key,{}).get(slot,"")
 refresh()
func select_slot(slot:String):select_category_slot(page,slot)
func slot_input(event:InputEvent,hit:Button,category:String,slot:String):
 var activate=event.is_action_pressed("ui_accept") and not event.is_echo()
 if not hit.disabled and (activate or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and event.double_click)):
  hit.accept_event();select_category_slot(category,slot)
  var filled=has_skill_override(slot) if category in SKILL_PAGES else Gear.cosmetic_slots(cosmetic_draft,wearer_key).has(slot) if category=="cosmetics" else draft.get(wearer_key,{}).has(slot)
  if filled:unequip()
func select_item(index:int):
 if index<0 or index>=collection.size():return
 selected_item=collection[index]
 refresh()
func inventory_input(event:InputEvent,index:int):
 if (event.is_action_pressed("ui_accept") and not event.is_echo()) or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and (page=="weapons" or event.double_click)):
  inventory[index].accept_event();auto_equip(index)
func auto_equip(index:int):
 if index<0 or index>=collection.size():return
 selected_item=collection[index]
 if page=="cosmetics" and selected_item.is_empty():set_cosmetic_color("");return
 var slots:Array
 var equipped={}
 if page in SKILL_PAGES:
  slots=Spells.SLOTS.keys().filter(editable_skill)
  for slot in slots:equipped[slot]=skill_assignment(slot)
 elif page=="cosmetics":
  slots=Gear.COSMETIC_SLOTS;equipped=Gear.cosmetic_slots(cosmetic_draft,wearer_key)
 else:
  slots=Gear.WEAPON_SLOTS.filter(func(slot):return int(slot)<=Gear.unlocked(wearer_key,game.settings)) if page=="weapons" else Gear.ACCESSORY_SLOTS
  equipped=draft.get(wearer_key,{}).duplicate()
  if page=="weapons" and not equipped.has("1") and wearer_key.begins_with("character:"):
   var native=Gear.default_weapon(int(wearer_key.trim_prefix("character:")),preview_settings())
   if not native.is_empty():equipped["1"]="weapon:"+native
 if slots.is_empty():return
 var match_slot=slots.filter(func(slot):return equipped.get(slot,"")==selected_item)
 if page=="cosmetics" and Gear.COLORS.has(selected_item):match_slot=slots.filter(func(slot):return Gear.COLORS.has(equipped.get(slot,"")))
 if page in SKILL_PAGES and wearer_key.begins_with("pet:"):match_slot=slots.filter(func(slot):return not str(equipped.get(slot,"")).is_empty() and Pets.Levels.family(str(equipped[slot]).trim_prefix("skill:"))==Pets.Levels.family(selected_item.trim_prefix("skill:")))
 var empty=slots.filter(func(slot):return str(equipped.get(slot,"")).is_empty())
 var key=wearer_key+":"+page
 if page in SKILL_PAGES:
  var owner=Gear.Roster.loadout_key(int(wearer_key.trim_prefix("character:")),preview_settings()) if wearer_key.begins_with("character:") else wearer_key
  key=owner+":skills"
 if not match_slot.is_empty():selected_slot=match_slot[0]
 elif not empty.is_empty():selected_slot=empty[0]
 else:
  var next=int(replace_next.get(key,0))%slots.size();selected_slot=slots[next];replace_next[key]=(next+1)%slots.size()
 if page=="weapons" and selected_slot!="1" and not draft.get(wearer_key,{}).has("1") and equipped.has("1"):
  if not draft.has(wearer_key):draft[wearer_key]={}
  draft[wearer_key]["1"]=equipped["1"]
 equip_selected()
func equip_selected():
 if selected_item not in available_items() or wearer_key not in owners:return
 if page in SKILL_PAGES:
  assign_skill(selected_item.trim_prefix("skill:"));return
 if page=="cosmetics":
  if selected_item.is_empty() or Gear.COLORS.has(selected_item):set_cosmetic_color(selected_item);return
  var slots=Gear.cosmetic_slots(cosmetic_draft,wearer_key)
  for slot in slots.keys():
   if slots[slot]==selected_item:slots.erase(slot)
  slots[selected_slot]=selected_item
  cosmetic_draft[wearer_key]={"qi_color":cosmetic_draft.get(wearer_key,{}).get("qi_color",""),"slots":slots}
 else:
  if not Gear.can_equip(wearer_key,selected_item,preview_settings()):return
  if page=="weapons" and (selected_slot not in Gear.WEAPON_SLOTS or int(selected_slot)>Gear.unlocked(wearer_key,game.settings)):return
  if page=="accessories" and selected_slot not in Gear.ACCESSORY_SLOTS:return
  if not draft.has(wearer_key):draft[wearer_key]={}
  for slot in Gear.SLOTS:
   var other:String=draft[wearer_key].get(slot,"")
   if other==selected_item or (Gear.ITEMS[selected_item].has("primary") and Gear.ITEMS.get(other,{}).has("primary")):draft[wearer_key].erase(slot)
  draft[wearer_key][selected_slot]=selected_item
  if page=="weapons":draft[wearer_key].active_weapon=selected_slot
 apply_changes()
func unequip():
 if page in SKILL_PAGES:
  assign_skill("");return
 elif page=="cosmetics":
  var slots=Gear.cosmetic_slots(cosmetic_draft,wearer_key);var id=slots.get(selected_slot,"");slots.erase(selected_slot)
  cosmetic_draft[wearer_key]={"qi_color":"" if Gear.COLORS.has(id) else cosmetic_draft.get(wearer_key,{}).get("qi_color",""),"slots":slots}
 elif draft.get(wearer_key,{}).has(selected_slot):
  draft[wearer_key].erase(selected_slot)
  if draft[wearer_key].get("active_weapon","")==selected_slot:draft[wearer_key].erase("active_weapon")
  if draft[wearer_key].is_empty():draft.erase(wearer_key)
 selected_item="";apply_changes()
func describe(data:Dictionary)->String:
 var title=str(data.get("name",""));var lines=[]
 var description=str(data.get("description",""))
 if not description.is_empty() and description!=title:lines.append(description)
 for stat in data.get("stats",{}):lines.append("%s %s%s"%[str(stat).capitalize(),"+" if float(data.stats[stat])>=0 else "",str(data.stats[stat])])
 return title+("\n"+" · ".join(lines) if not lines.is_empty() else "")
func fill_control(hit:Button,id:String,empty:String="",skin:bool=false):
 var icon:TextureRect=hit.get_node("GearIcon") if hit.has_node("GearIcon") else hit.get_node("ItemIcon")
 var data=item_data(id) if not id.is_empty() or skin else {}
 icon.texture=data.get("icon");icon.material=fist_material if id=="weapon:unarmed" else color_materials.get(id);icon.modulate=Color.WHITE
 var description=describe(data) if not data.is_empty() else empty
 hit.accessibility_name=description;hit.set_meta("description",description);hit.set_meta("icon",icon.texture);hit.set_meta("material",icon.material)
func refresh():
 var settings=preview_settings();var character=int(wearer_key.trim_prefix("character:")) if wearer_key.begins_with("character:") else -1
 var gallery_character=Gear.Roster.gallery_id(character)
 if portrait_button.character!=gallery_character and is_instance_valid(portrait_button.gallery):portrait_button.gallery.hide()
 portrait_button.character=gallery_character;portrait_button.catalog=Gear.Roster.skin_catalog(gallery_character) if character>=0 else {}
 portrait_button.selected_id=Gear.Roster.selected_skin(gallery_character,settings) if character>=0 else 0
 portrait_button.refresh()
 var portrait_key=wearer_key+str(Gear.Roster.selected_skin(character,settings) if character>=0 else 0)
 if pictured_wearer!=portrait_key:
  if character>=0:
   portrait.texture=wearer_portrait(wearer_key);party[0].icon=portrait.texture
  else:portrait.texture=wearer_portrait(wearer_key)
  if wearer_key.begins_with("pet:"):
   var key=wearer_key.trim_prefix("pet:")
   pet_name_field.placeholder_text=Pets.display_name(Pets.skin(key),{})
   pet_name_field.text=game.settings.forest_pet_names.get(key,"")
  pictured_wearer=portrait_key
 pet_name_field.visible=wearer_key.begins_with("pet:")
 save_pet_name_button.visible=pet_name_field.visible
 passive_heading.visible=pet_name_field.visible;passive_slot.visible=passive_heading.visible
 var passive_key=wearer_key.trim_prefix("pet:");var passive_skin=Pets.skin(passive_key) if passive_slot.visible else -1
 var passive=Pets.passive(passive_skin)
 var passive_level=game.model.team_progression.pet_passive_level(passive_key)
 passive_icon.texture=Status.passive_texture(passive_skin)
 passive_slot.accessibility_name=passive.get("name","No passive skill")
 passive_slot.accessibility_description=Pets.passive_hint(passive_skin,passive_level)
 passive_slot.tooltip_text=passive_slot.accessibility_name
 if not passive.is_empty():passive_slot.tooltip_text+=(" · Lv %d"%passive_level if passive.upgrade else "")+"\n"+passive_slot.accessibility_description
 for i in party.size():
  var active=i==selected_pet_slot+1 if selected_pet_slot>=0 else i==0
  party[i].set_pressed_no_signal(active);party[i].get_node("SelectedOutline").visible=active
 change_pet_button.visible=selected_pet_slot>=0 and (page=="pets" or not wearer_key.is_empty())
 change_pet_button.text="Cancel change" if page=="pets" else "Change pet"
 equipment_tab.set_pressed_no_signal(page=="weapons");skill_tab.set_pressed_no_signal(page=="accessories");cosmetics_tab.set_pressed_no_signal(page=="cosmetics")
 skills_tab.set_pressed_no_signal(page=="skills")
 pet_skills_tab.set_pressed_no_signal(page=="pet_skills")
 inventory_scroll.visible=page!="pets"
 if is_instance_valid(pet_picker):pet_picker.visible=page=="pets"
 if is_instance_valid(pet_picker):
  pet_picker.selected=Pets.sanitized(game.settings.forest_pet_loadout);pet_picker.target_slot=selected_pet_slot;pet_picker.refresh()
 var supported=Gear.ITEMS.keys().filter(func(id):return Gear.ITEMS[id].has("weapon") and id not in Gear.CHEST_SWORDS and Gear.can_equip(wearer_key,id,settings))
 for i in allowed_icons.size():
  var icon=allowed_icons[i];icon.visible=i<supported.size();icon.texture=Gear.ITEMS[supported[i]].icon if icon.visible else null
  icon.position=Vector2(48+i*24,296)
  icon.material=fist_material if icon.visible and supported[i]=="weapon:unarmed" else null
  var description=describe(item_data(supported[i])) if icon.visible else ""
  icon.accessibility_name=description;icon.set_meta("description",description);icon.set_meta("icon",icon.texture)
 var equipped:Dictionary=draft.get(wearer_key,{})
 var cosmetics=Gear.cosmetic_slots(cosmetic_draft,wearer_key)
 refresh_character_preview(character,cosmetics)
 var current=Gear.equipped(draft,character) if character>=0 else ""
 var fallback=Gear.default_weapon(character,settings) if character>=0 and (current.is_empty() or not Gear.can_equip(wearer_key,current,settings)) else ""
 for slots in [gear_buttons,accessory_buttons,cosmetic_buttons]:
  for slot in slots:
   var hit:Button=slots[slot];var weapon_row=is_same(slots,gear_buttons);var cosmetic_row=is_same(slots,cosmetic_buttons)
   var locked=weapon_row and int(slot)>Gear.unlocked(wearer_key,game.settings)
   var id:String=cosmetics.get(slot,"") if cosmetic_row else equipped.get(slot,"")
   if weapon_row and slot=="1" and id.is_empty() and not fallback.is_empty():id="weapon:"+fallback
   fill_control(hit,id,"Locked" if locked else "Empty")
   if weapon_row and Gear.ITEMS.has(id) and not Gear.can_equip(wearer_key,id,settings):
    hit.get_node("GearIcon").modulate=Color(.45,.45,.45,.7)
    var description=str(hit.get_meta("description"))+"\nUnavailable for skin"
    hit.accessibility_name=description;hit.set_meta("description",description)
   hit.disabled=locked or wearer_key.is_empty();hit.get_node("Lock").visible=locked
   hit.get_node("GearIcon").visible=not locked
   var category="weapons" if weapon_row else "cosmetics" if cosmetic_row else "accessories"
   hit.self_modulate=Color("ffe3a0") if page==category and slot==selected_slot and not locked else Color.WHITE
 var valid_skills=skills_for_weapons() if character>=0 else []
 for action in skill_buttons:
  var hit:Button=skill_buttons[action];var index=Spells.SLOTS.keys().find(action)
  var id=skill_assignment(action);var data=item_data(id) if not id.is_empty() else {}
  hit.visible=character>=0 or index<Pets.MAX_SKILLS;hit.disabled=not editable_skill(action)
  hit.get_node("GearIcon").texture=data.get("icon")
  var description=str(index+1)+" · "+describe(data) if not data.is_empty() else str(index+1)+" · Empty"
  var missing_weapon=not id.is_empty() and character>=0 and id.trim_prefix("skill:") not in valid_skills
  hit.get_node("GearIcon").modulate=Color(.45,.45,.45,.7) if missing_weapon else Color.WHITE
  if missing_weapon:description+="\nRequired weapon is not equipped."
  hit.accessibility_name=description;hit.set_meta("description",description);hit.set_meta("icon",data.get("icon"))
  hit.self_modulate=Color("ffe3a0") if page in SKILL_PAGES and selected_slot==action else Color.WHITE
  var skill_id=id.trim_prefix("skill:");var pet_key=wearer_key.trim_prefix("pet:")
  var has_level=not skill_id.is_empty() and not (Skills.rules_for(game.player,skill_id) if character>=0 else Skills.Levels.stats(skill_id,1)).is_empty()
  var level_=Skills.level_for(game.player,skill_id) if character>=0 else Skills.pet_level_for(game.model.team_progression,pet_key,skill_id)
  skill_levels[action].visible=hit.visible;skill_levels[action].text="Lv%d"%level_ if has_level else "—"
 collection=available_items()
 var minimum_cells=INVENTORY_COLUMNS*4 if page=="pet_skills" else CAPACITY
 var visible_cells=maxi(minimum_cells,ceili(float(collection.size())/INVENTORY_COLUMNS)*INVENTORY_COLUMNS)
 add_inventory_cells(visible_cells);color_choices.clear()
 for i in inventory.size():
  var hit=inventory[i];var filled=i<collection.size();hit.visible=i<visible_cells;hit.disabled=not filled
  hit.set_pressed_no_signal(false);hit.self_modulate=Color.WHITE;hit.get_node("Equipped").hide()
  if not filled:
   fill_control(hit,"","");continue
  var id:String=collection[i];fill_control(hit,id,"",id.is_empty())
  var is_equipped=id in cosmetics.values() if page=="cosmetics" else id in equipped.values()
  if page in SKILL_PAGES:is_equipped=Spells.SLOTS.keys().any(func(action):return skill_assignment(action)==id)
  if page=="cosmetics":
   if id.is_empty() or Gear.COLORS.has(id):
    color_choices[id]=hit
    if id.is_empty():is_equipped=cosmetic_draft.get(wearer_key,{}).get("qi_color","").is_empty()
  hit.get_node("Equipped").visible=is_equipped
  hit.self_modulate=Color("ffe3a0") if id==selected_item else Color.WHITE
 detail.text="";preview.texture=null;preview.material=null
 if not selected_item.is_empty() and selected_item in collection:
  var index=collection.find(selected_item);inspect_control(inventory[index])
 var issue=Gear.skill_weapon_error(draft,spell_draft,Gear.Roster.skin_character(game.player.character_id,settings),settings)
 if not issue.is_empty() or enter_button.disabled:status.text=issue
 enter_button.disabled=not issue.is_empty();enter_button.tooltip_text=issue
 stats.wearer_key=("pet:" if wearer_key.is_empty() else wearer_key) if selected_pet_slot>=0 else wearer_key;stats.refresh()

func refresh_character_preview(character:int,cosmetics:Dictionary):
 character_preview.visible=character>=0;portrait.visible=character<0
 portrait.size=Vector2(312,82) if selected_pet_slot>=0 else Vector2(312,124)
 if character<0:return
 var visual=game.player.model
 var ids=Gear.COSMETIC_SLOTS.map(func(slot):return cosmetics.get(slot,"")).filter(func(id):return Gear.Cosmetics.items().has(id))
 var frame:Array=visual.body_clip(0,"0:5").frames[0]
 var key=visual.atlases[int(frame[0])].resource_path+":"+str(frame)+":"+str(visual.sprite.pixel_size)+":"+str(ids)
 if preview_key==key:return
 preview_key=key
 preview_body.texture=visual.atlases[int(frame[0])];preview_body.material_override=visual.body_materials[preview_body.texture]
 preview_body.region_rect=Rect2(frame[1],frame[2],frame[3],frame[4]);preview_body.pixel_size=visual.sprite.pixel_size
 preview_body.offset=Vector2(float(frame[5])+float(frame[3])*.5,visual.FEET_OFFSET_PIXELS-float(frame[6])-float(frame[4])*.5)
 Gear.Cosmetics.prepare_heads([preview_body.texture]);preview_layers.configure(preview_body,ids)
 # Frame the wearer alone so equipping cosmetics cannot move or resize the character.
 var bounds=preview_bounds(preview_body)
 preview_layers.update(0,preview_body,"0:5",false)
 preview_camera.size=maxf(4.4,maxf(bounds.size.y+.4,(bounds.size.x+.4)*character_preview.size.y/character_preview.size.x))
 preview_camera.position=Vector3(bounds.get_center().x,bounds.get_center().y,10)

func preview_bounds(sprite:Sprite3D)->Rect2:
 return Rect2((sprite.offset-sprite.region_rect.size*.5)*sprite.pixel_size,sprite.region_rect.size*sprite.pixel_size)

func _process(delta:float):
 if character_preview.visible:preview_layers.update(delta,preview_body,"0:5",false)

func skills_for_weapons()->Array:
 var weapons=Gear.carried_weapons(draft,int(wearer_key.trim_prefix("character:")),preview_settings())
 return Spells.all().keys().filter(func(id):return Spells.has_required_weapon(Spells.all()[id],weapons))

func skill_icon(id:String)->Texture2D:
 if id==Spells.KAGEROU:return Spells.KAGEROU_ICON
 if Spells.KAZI_ICONS.has(id):return Spells.KAZI_ICONS[id]
 return Gear.Roster.portrait(int(Spells.all().get(id,{}).get("source",34)))

func editable_skill(action:String)->bool:
 if wearer_key.is_empty():return false
 var index=Spells.SLOTS.keys().find(action)
 if index<0:return false
 if wearer_key.begins_with("pet:"):return index<Pets.MAX_SKILLS
 return true

func skill_overrides()->Dictionary:
 var character=int(wearer_key.trim_prefix("character:"));var key=Gear.Roster.loadout_key(character,preview_settings())
 return spell_draft.get(key,spell_draft.get(str(character),{}))

func skill_assignment(action:String)->String:
 if wearer_key.is_empty():return ""
 if wearer_key.begins_with("pet:"):
  var index=Spells.SLOTS.keys().find(action)
  var slots=Pets.skill_slots(pet_skill_draft,wearer_key.trim_prefix("pet:"))
  return "skill:"+str(slots[index]) if index>=0 and index<slots.size() and not str(slots[index]).is_empty() else ""
 var id:String=skill_overrides().get(action,"")
 return "skill:"+id if not id.is_empty() else ""

func has_skill_override(action:String)->bool:
 if wearer_key.begins_with("pet:"):return not skill_assignment(action).is_empty()
 return skill_overrides().has(action)

func assign_skill(id:String):
 if not editable_skill(selected_slot) or (not id.is_empty() and "skill:"+id not in available_items()):return
 if wearer_key.begins_with("pet:"):
  var key=wearer_key.trim_prefix("pet:");var slots=Pets.skill_slots(pet_skill_draft,key).duplicate();var index=Spells.SLOTS.keys().find(selected_slot)
  for i in slots.size():
   if i!=index and not id.is_empty() and Pets.Levels.family(slots[i])==Pets.Levels.family(id):
    status.text="Choose three different attacks for this pet.";return
  slots[index]=id;pet_skill_draft[key]=slots;pet_skill_draft=Pets.sanitized_skills(pet_skill_draft);pet_skills_edited[key]=true
 else:
  var character=int(wearer_key.trim_prefix("character:"));var key=Gear.Roster.loadout_key(character,preview_settings());var slots=skill_overrides().duplicate()
  if id.is_empty():slots.erase(selected_slot)
  else:slots[selected_slot]=id
  if slots.is_empty() and ":" not in key:spell_draft.erase(key)
  else:spell_draft[key]=slots
 selected_item="skill:"+id if not id.is_empty() else "";apply_changes()

func read_loadouts():
 draft=Gear.migrated_gear(game.settings.get("gear_loadouts",{}),game.settings)
 skill_draft=Gear.sanitized(game.settings.get("skill_item_loadouts",{}),"skill").duplicate(true)
 cosmetic_draft=Gear.sanitized_cosmetics(game.settings.get("cosmetic_loadouts",{})).duplicate(true)
 spell_draft=Spells.valid_loadouts(game.settings.get("spell_loadouts",{})).duplicate(true)
 pet_skill_draft=Pets.sanitized_skills(game.settings.get("forest_pet_skills",{})).duplicate(true)
 appearance_draft.clear();pet_skills_edited.clear()

func apply_changes()->bool:
 var settings=preview_settings()
 var issue=Gear.skill_weapon_error(draft,spell_draft,Gear.Roster.skin_character(game.player.character_id,settings),settings)
 var saved=game.save_equipment_loadouts(draft,skill_draft,cosmetic_draft,appearance_draft,spell_draft,pet_skill_draft)
 if saved:appearance_draft.clear()
 else:read_loadouts();pictured_wearer=""
 status.text="";refresh_party()
 if not saved:status.text=issue if not issue.is_empty() else "Could not equip. Your previous equipment is unchanged."
 return saved

func enter_map():
 if apply_changes():game.enter_equipped_map()
