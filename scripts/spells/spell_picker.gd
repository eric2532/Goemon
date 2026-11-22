extends PanelContainer
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const Jumps=preload("res://scripts/jump_style.gd")
var game:Node
var fighter:OptionButton
var choices:Dictionary={}
var jump_choice:OptionButton
var weapon_row:HBoxContainer
var weapons:Array[OptionButton]=[]
var skin_picker:Button
var active_weapon:OptionButton
var sixth_row:HBoxContainer
var sixth_skill:Label
var note:Label
var syncing=false

func _ready():
 name="SpellEquipment";process_mode=Node.PROCESS_MODE_ALWAYS
 set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 fit_window();get_viewport().size_changed.connect(fit_window)
 var style=StyleBoxFlat.new();style.bg_color=Color(.145,.204,.235,.66);style.border_color=Color("e5ddbf");style.set_border_width_all(2);style.set_corner_radius_all(12)
 for side in ["left","right","top","bottom"]:style.set("content_margin_"+side,22)
 add_theme_stylebox_override("panel",style)
 var layout=VBoxContainer.new();layout.add_theme_constant_override("separation",12);add_child(layout)
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;layout.add_child(scroll)
 var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",9);scroll.add_child(column)
 var title=Label.new();title.text="LOADOUT · WEAPONS, SKILLS & JUMP";title.add_theme_font_size_override("font_size",23);column.add_child(title)
 fighter=OptionButton.new();fighter.name="SpellFighter";fighter.custom_minimum_size.y=42;column.add_child(fighter)
 for id in Catalog.Roster.selection_ids():
  fighter.add_item("Goemon" if id==1 else "Edo" if id==2 else Catalog.Roster.name_for(id),id)
  if id==Catalog.Roster.gallery_id(game.player.character_id):fighter.select(fighter.item_count-1)
 fighter.item_selected.connect(func(_index):refresh())
 skin_picker=preload("res://scripts/character_skin_picker.gd").new();skin_picker.name="LoadoutSkin";skin_picker.custom_minimum_size.y=42
 column.add_child(skin_picker)
 skin_picker.skin_selected.connect(func(id):
  var character=fighter.get_selected_id()
  if character==Catalog.Roster.KAZI_ID:game.select_kaz_skin(id)
  elif Catalog.Roster.is_shin(character):game.select_shin_skin(character,id)
  else:game.select_crossgate_skin(character,id)
  refresh())
 active_weapon=OptionButton.new();active_weapon.name="SkinWeapon";active_weapon.custom_minimum_size.y=42;column.add_child(active_weapon)
 active_weapon.item_selected.connect(func(index):
  if syncing:return
  game.select_skin_weapon(selected_character(),index);refresh())
 var help=Label.new();help.text="Keys 1–6 use your equipped skills.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(help)
 weapon_row=HBoxContainer.new();weapon_row.add_theme_constant_override("separation",9);column.add_child(weapon_row)
 for slot in 2:
  var weapon=OptionButton.new()
  weapon.name="MazePrimary" if slot==0 else "MazeSecondary"
  weapon.size_flags_horizontal=Control.SIZE_EXPAND_FILL;weapon.custom_minimum_size.y=42
  var prefix="Primary · " if slot==0 else "Secondary · "
  weapon.add_item(prefix+"Katana",0)
  weapon.add_item(prefix+"Dagger",1)
  weapon.item_selected.connect(select_weapon.bind(slot))
  weapon_row.add_child(weapon);weapons.append(weapon)
 var jump_row=HBoxContainer.new();jump_row.add_theme_constant_override("separation",9);column.add_child(jump_row)
 var jump_label=Label.new();jump_label.text="Jump Style";jump_row.add_child(jump_label)
 jump_choice=OptionButton.new();jump_choice.name="JumpStyleSlot";jump_choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;jump_choice.custom_minimum_size.y=42;jump_row.add_child(jump_choice)
 jump_choice.add_item("Original character jump");jump_choice.set_item_metadata(0,"")
 for id in Jumps.STYLES:
  jump_choice.add_item(Jumps.STYLES[id].name);jump_choice.set_item_metadata(jump_choice.item_count-1,id)
  jump_choice.set_item_tooltip(jump_choice.item_count-1,Jumps.STYLES[id].description)
 jump_choice.item_selected.connect(func(index):
  if syncing:return
  game.player.jump_style.equip(selected_character(),jump_choice.get_item_metadata(index));refresh())
 jump_row.hide()
 for action in Catalog.SLOTS:
  var row=HBoxContainer.new();row.add_theme_constant_override("separation",9);column.add_child(row)
  var key=Label.new();key.text=Catalog.SLOTS[action];key.custom_minimum_size.x=30;row.add_child(key)
  if action=="special_6":
   sixth_skill=Label.new();sixth_skill.mouse_filter=Control.MOUSE_FILTER_STOP
   row.add_child(sixth_skill);row.custom_minimum_size.y=42;sixth_row=row
  var option=OptionButton.new();option.name="SpellSlot_"+action;option.size_flags_horizontal=Control.SIZE_EXPAND_FILL;option.custom_minimum_size.y=42;row.add_child(option);choices[action]=option
  option.get_popup().max_size=Vector2i(0,440)
  option.add_item("Original character ability");option.set_item_metadata(0,"")
  for id in Catalog.all():
   if id==Catalog.MAZE_QI:continue
   var spec:Dictionary=Catalog.all()[id]
   if not Catalog.available(spec):continue
   var source="Goemon" if spec.source==1 else "Edo" if spec.source==2 else Catalog.Roster.name_for(spec.source)
   option.add_item(source+" · "+spec.name);option.set_item_metadata(option.item_count-1,id)
   option.set_item_tooltip(option.item_count-1,str(spec.get("description",spec.name)))
  option.item_selected.connect(func(index):
   if syncing:return
   game.player.spell_loadout.equip(selected_character(),action,option.get_item_metadata(index));refresh())
 note=Label.new();note.name="SpellLoadoutSummary";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(note)
 var footer=HBoxContainer.new();layout.add_child(footer)
 var reset=Button.new();reset.text="Clear skills";reset.custom_minimum_size=Vector2(290,42);footer.add_child(reset)
 reset.pressed.connect(func():
  for action in Catalog.SLOTS:game.player.spell_loadout.equip(selected_character(),action,"")
  refresh())
 var close=Button.new();close.text="Done";close.custom_minimum_size=Vector2(180,42);footer.add_child(close);close.pressed.connect(queue_free)
 refresh();fighter.grab_focus()

func fit_window():
 offset_left=-minf(350,get_viewport_rect().size.x*.5-16);offset_right=-offset_left
 offset_top=-minf(345,get_viewport_rect().size.y*.5-16);offset_bottom=-offset_top

func selected_character()->int:
 return Catalog.Roster.skin_character(fighter.get_selected_id(),game.settings)

func select_weapon(index:int,slot:int):
 if syncing:return
 game.select_maze_primary(index==1 if slot==0 else index==0,selected_character())
 refresh()

func refresh():
 syncing=true
 var character=selected_character()
 var maze=Catalog.Roster.has_crossgate_throws(character)
 var gallery_character=fighter.get_selected_id()
 skin_picker.character=gallery_character;skin_picker.catalog=Catalog.Roster.skin_catalog(gallery_character)
 skin_picker.selected_id=Catalog.Roster.selected_skin(gallery_character,game.settings);skin_picker.refresh()
 var available:Array=game.skin_weapon_choices(character)
 active_weapon.clear();active_weapon.visible=not available.is_empty();active_weapon.disabled=available.size()<2
 for name_ in available:active_weapon.add_item("Weapon · "+name_)
 if not available.is_empty():
  var fallback=int(game.skin_primary_kunai(character)) if maze else int(Catalog.Roster.crossgate_profile(character).get("start_weapon",0))
  active_weapon.select(game.skin_weapon(character,fallback,available.size()-1))
 active_weapon.tooltip_text="Only weapons with recovered animations for this skin are available."
 var primary_setting:String=Catalog.Roster.crossgate_profile(character).get("primary_setting","")
 weapon_row.visible=not primary_setting.is_empty()
 if weapon_row.visible:
  weapons[0].select(int(game.skin_primary_kunai(character)))
  weapons[1].select(1-int(game.skin_primary_kunai(character)))
 sixth_row.visible=Catalog.hotbar(character).size()>5
 sixth_skill.hide()
 choices.special_6.visible=Catalog.Roster.is_crossgate_fighter(character)
 var overrides=game.player.spell_loadout.assignments(character)
 var jump_id=game.player.jump_style.assignment(character)
 var native_slots=game.player.spell_loadout.native_slots_for(character)
 jump_choice.select(0)
 for index in jump_choice.item_count:
  if jump_choice.get_item_metadata(index)==jump_id:jump_choice.select(index);break
 for action in choices:
  if action=="special_6" and not Catalog.Roster.is_crossgate_fighter(character):continue
  choices[action].get_parent().show()
  var option:OptionButton=choices[action];var selected=str(overrides.get(action,""));option.select(0)
  for index in option.item_count:
   if option.get_item_metadata(index)==selected:option.select(index);break
  var native_slot:Array=native_slots[Catalog.SLOTS.keys().find(action)]
  option.set_item_text(0,"Empty" if Catalog.Roster.is_crossgate_fighter(character) else "Original · "+(str(native_slot[0]) if not native_slot.is_empty() else "Empty"))
 note.text="Space · Dodge when ! appears. Shift + Space · Jump.\n"
 for id in overrides.values():
  if Catalog.all()[id].get("air_attack",false):
   note.text+=Catalog.all()[id].description+"\n";break
 note.text+="Weapons and skills save for this skin. Q / Esc returns to the fighter gallery." if not skin_picker.catalog.is_empty() else "Saved per fighter. Q / Esc returns to the fighter gallery."
 syncing=false

func _input(event:InputEvent):
 if event.is_echo():return
 if event.is_action_pressed("pause") or event.is_action_pressed("character_toggle"):
  get_viewport().set_input_as_handled();queue_free()
