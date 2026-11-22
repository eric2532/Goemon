extends Control
const Pets=preload("res://scripts/forest/pet_catalog.gd")
const PreparationSkin=preload("res://scripts/forest/preparation_skin.gd")
const PANEL_SIZE=Vector2(850,760)
var game
var embedded=false
var panel:PanelContainer
var selected:Array[String]=[]
var category="All"
var slots:Array[Button]=[]
var cards:Array[Button]=[]
var category_picker:OptionButton
var count:Label
var status:Label
var target_slot=-1
var remove_button:Button

func label(value:String,font_size:int=16)->Label:
 var node=Label.new();node.text=value;node.add_theme_font_size_override("font_size",font_size);return node
func button(value:String,action:Callable)->Button:
 var node=Button.new();node.text=value;node.pressed.connect(action);node.custom_minimum_size.y=36;return node
func card(size_:Vector2,action:Callable)->Button:
 var node=button("",action);node.custom_minimum_size=size_;node.toggle_mode=true
 node.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;node.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
 node.expand_icon=true;node.add_theme_constant_override("icon_max_width",64)
 node.add_theme_font_size_override("font_size",13)
 return node
func _ready():
 name="PetLoadoutPanel";texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;process_mode=Node.PROCESS_MODE_ALWAYS;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 selected=Pets.sanitized(game.settings.forest_pet_loadout)
 if selected.size()<Pets.MAX_ACTIVE:target_slot=selected.size()
 if embedded:
  make_equipment_picker();refresh();return
 var shade=ColorRect.new();shade.color=Color(0,0,0,.25);add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel=PanelContainer.new();panel.theme=PreparationSkin.theme();panel.add_theme_stylebox_override("panel",PreparationSkin.panel());add_child(panel)
 panel.size=PANEL_SIZE
 var margin=MarginContainer.new();panel.add_child(margin)
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",10);margin.add_child(column)
 var heading=HBoxContainer.new();column.add_child(heading)
 var title=label("YOUR COMPANIONS",25);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(title)
 var close=button("Close",game.close_pet_loadout);close.name="ClosePetLoadout";heading.add_child(close)
 remove_button=button("Remove",func():remove(target_slot));heading.add_child(remove_button)
 var row=HBoxContainer.new();column.add_child(row);row.add_child(label("Battle pack",19));count=label("");count.size_flags_horizontal=Control.SIZE_EXPAND_FILL;count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;row.add_child(count)
 var chosen=HBoxContainer.new();chosen.add_theme_constant_override("separation",8);column.add_child(chosen)
 for i in Pets.MAX_ACTIVE:
  var slot=card(Vector2(0,112),select_slot.bind(i));slot.name="PetSlot%d"%i;slot.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;slot.add_theme_constant_override("icon_max_width",48);slot.size_flags_horizontal=Control.SIZE_EXPAND_FILL;chosen.add_child(slot);slots.append(slot)
 var filters=HBoxContainer.new();column.add_child(filters);filters.add_child(label("Pet family",16))
 category_picker=OptionButton.new();category_picker.custom_minimum_size.y=36;category_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_child(category_picker)
 for group in Pets.categories():category_picker.add_item(group)
 category_picker.item_selected.connect(func(index):filter(category_picker.get_item_text(index)))
 var scroll=ScrollContainer.new();scroll.name="PetChoices";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;column.add_child(scroll)
 var grid=GridContainer.new();grid.columns=7;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);scroll.add_child(grid)
 for i in Pets.COUNT:
  var entry=card(Vector2(106,112),toggle.bind(i));entry.name="SelectPet%d"%i;entry.icon=Pets.portrait(i)
  entry.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  grid.add_child(entry);cards.append(entry)
 status=label("",14);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status);status.hide()
 resized.connect(layout);layout();refresh();category_picker.grab_focus()
func layout():
 var factor=minf(1.0,minf((size.x-24)/PANEL_SIZE.x,(size.y-24)/PANEL_SIZE.y))
 panel.scale=Vector2.ONE*factor;panel.position=(size-PANEL_SIZE*factor)*.5

func make_equipment_picker():
 panel=PanelContainer.new();panel.theme=PreparationSkin.theme();panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new());add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",8);panel.add_child(column)
 var filters=HBoxContainer.new();column.add_child(filters)
 category_picker=OptionButton.new();category_picker.custom_minimum_size=Vector2(0,36);category_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_child(category_picker)
 for group in Pets.categories():category_picker.add_item(group)
 category_picker.item_selected.connect(func(index):filter(category_picker.get_item_text(index)))
 count=label("",14);filters.add_child(count)
 var scroll=ScrollContainer.new();scroll.name="PetChoices";scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;column.add_child(scroll)
 var grid=GridContainer.new();grid.columns=5;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);scroll.add_child(grid)
 for i in Pets.COUNT:
  var entry=card(Vector2(100,106),toggle.bind(i));entry.name="SelectPet%d"%i;entry.icon=Pets.portrait(i)
  entry.add_theme_color_override("font_disabled_color",PreparationSkin.INK)
  entry.clip_text=true;entry.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;grid.add_child(entry);cards.append(entry)
 status=label("",12);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
func refresh():
 var names:Dictionary=game.settings.forest_pet_names
 status.visible=not status.text.is_empty()
 count.text="Slot %d · %d / %d"%[target_slot+1,selected.size(),Pets.MAX_ACTIVE] if target_slot>=0 else "Select a pet slot"
 if is_instance_valid(remove_button):remove_button.disabled=target_slot<0 or target_slot>=selected.size()
 for i in slots.size():
  var filled=i<selected.size();slots[i].disabled=i>selected.size();slots[i].set_pressed_no_signal(i==target_slot)
  slots[i].icon=Pets.portrait(Pets.skin(selected[i])) if filled else null
  slots[i].text=Pets.display_name(Pets.skin(selected[i]),names) if filled else "%d · Empty"%(i+1)
  slots[i].tooltip_text="" if filled else "Add a pet"
 for i in cards.size():
  var equipped=selected.find(Pets.key(i))
  cards[i].set_pressed_no_signal(equipped>=0)
  cards[i].disabled=equipped>=0 or target_slot<0 or target_slot>selected.size()
  var name_=Pets.display_name(i,names)
  cards[i].text=name_+("\n✓ Slot %d"%(equipped+1) if equipped>=0 else "")
  cards[i].tooltip_text=name_+("\nEquipped · Slot %d"%(equipped+1) if equipped>=0 else "")
  cards[i].accessibility_name=cards[i].tooltip_text
  cards[i].visible=Pets.listed(i) and (category=="All" or Pets.category(i)==category or (category=="Aura & effects" and Pets.effect(i)))
 category_picker.select(Pets.categories().find(category))
func toggle(index:int):
 if embedded and not is_visible_in_tree():return
 if index<0 or index>=Pets.COUNT or not Pets.available(index) or target_slot<0 or target_slot>selected.size() or target_slot>=Pets.MAX_ACTIVE:return
 var id=Pets.key(index)
 if id in selected:return
 if target_slot==selected.size():selected.append(id)
 else:selected[target_slot]=id
 if apply() and embedded:game.equipment_hub.finish_pet_change(target_slot)
func select_slot(index:int):
 if index<0 or index>selected.size() or index>=Pets.MAX_ACTIVE:return
 target_slot=index;refresh()
func remove(index:int):
 if index<0 or index>=selected.size():return
 selected.remove_at(index)
 apply()
func filter(group:String):category=group;refresh()
func apply()->bool:
 var saved=game.save_pet_loadout(selected)
 status.text="" if saved else "Could not save the loadout. Your previous selection is unchanged."
 if not saved:selected=Pets.sanitized(game.settings.forest_pet_loadout)
 if saved and embedded:game.equipment_hub.refresh_party()
 refresh()
 return saved
