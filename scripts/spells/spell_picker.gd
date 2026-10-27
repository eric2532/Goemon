extends PanelContainer
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const Jumps=preload("res://scripts/jump_style.gd")
var game:Node
var fighter:OptionButton
var choices:Dictionary={}
var jump_choice:OptionButton
var note:Label
var syncing=false

func _ready():
 name="SpellEquipment";process_mode=Node.PROCESS_MODE_ALWAYS
 set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 offset_left=-350;offset_right=350;offset_top=-minf(345,get_viewport_rect().size.y*.5-16);offset_bottom=-offset_top
 var style=StyleBoxFlat.new();style.bg_color=Color(.16,.045,.09,.95);style.border_color=Color("c9c5d2");style.set_border_width_all(2);style.set_corner_radius_all(12)
 for side in ["left","right","top","bottom"]:style.set("content_margin_"+side,22)
 add_theme_stylebox_override("panel",style)
 var layout=VBoxContainer.new();layout.add_theme_constant_override("separation",12);add_child(layout)
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;layout.add_child(scroll)
 var column=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",9);scroll.add_child(column)
 var title=Label.new();title.text="SKILLS & JUMP · EQUIP ANY FIGHTER";title.add_theme_font_size_override("font_size",23);column.add_child(title)
 fighter=OptionButton.new();fighter.name="SpellFighter";fighter.custom_minimum_size.y=42;column.add_child(fighter)
 for id in Catalog.Roster.selection_ids():
  fighter.add_item("Goemon" if id==1 else "Edo" if id==2 else Catalog.Roster.name_for(id),id)
  if id==game.player.character_id:fighter.select(fighter.item_count-1)
 fighter.item_selected.connect(func(_index):refresh())
 var help=Label.new();help.text="1–5 cast your equipped skills. Existing E/R/T shortcuts remain available.\nSpells keep their behavior and cooldown. Jump Style changes\nSpace movement; attacks and this fighter's animations stay separate.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(help)
 var jump_row=HBoxContainer.new();jump_row.add_theme_constant_override("separation",9);column.add_child(jump_row)
 var jump_label=Label.new();jump_label.text="Jump Style";jump_row.add_child(jump_label)
 jump_choice=OptionButton.new();jump_choice.name="JumpStyleSlot";jump_choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;jump_choice.custom_minimum_size.y=42;jump_row.add_child(jump_choice)
 jump_choice.add_item("Original character jump");jump_choice.set_item_metadata(0,"")
 for id in Jumps.STYLES:
  jump_choice.add_item(Jumps.STYLES[id].name);jump_choice.set_item_metadata(jump_choice.item_count-1,id)
  jump_choice.set_item_tooltip(jump_choice.item_count-1,Jumps.STYLES[id].description)
 jump_choice.item_selected.connect(func(index):
  if syncing:return
  game.player.jump_style.equip(fighter.get_selected_id(),jump_choice.get_item_metadata(index));refresh())
 for action in Catalog.SLOTS:
  var row=HBoxContainer.new();row.add_theme_constant_override("separation",9);column.add_child(row)
  var key=Label.new();key.text=Catalog.SLOTS[action];key.custom_minimum_size.x=30;row.add_child(key)
  var option=OptionButton.new();option.name="SpellSlot_"+action;option.size_flags_horizontal=Control.SIZE_EXPAND_FILL;option.custom_minimum_size.y=42;row.add_child(option);choices[action]=option
  option.get_popup().max_size=Vector2i(0,440)
  option.add_item("Original character ability");option.set_item_metadata(0,"")
  for id in Catalog.all():
   var spec:Dictionary=Catalog.all()[id]
   var source="Goemon" if spec.source==1 else "Edo" if spec.source==2 else Catalog.Roster.name_for(spec.source)
   option.add_item(source+" · "+spec.name);option.set_item_metadata(option.item_count-1,id)
   option.set_item_tooltip(option.item_count-1,str(spec.get("description",spec.name)))
  option.item_selected.connect(func(index):
   if syncing:return
   game.player.spell_loadout.equip(fighter.get_selected_id(),action,option.get_item_metadata(index));refresh())
 note=Label.new();note.name="SpellLoadoutSummary";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(note)
 var footer=HBoxContainer.new();layout.add_child(footer)
 var reset=Button.new();reset.text="Restore original skills & jump";reset.custom_minimum_size=Vector2(290,42);footer.add_child(reset)
 reset.pressed.connect(func():
  for action in Catalog.SLOTS:game.player.spell_loadout.equip(fighter.get_selected_id(),action,"")
  game.player.jump_style.equip(fighter.get_selected_id(),"")
  refresh())
 var close=Button.new();close.text="Done";close.custom_minimum_size=Vector2(180,42);footer.add_child(close);close.pressed.connect(queue_free)
 refresh();fighter.grab_focus()

func refresh():
 syncing=true
 var character=fighter.get_selected_id()
 var overrides=game.player.spell_loadout.assignments(character)
 var jump_id=game.player.jump_style.assignment(character)
 jump_choice.select(0)
 for index in jump_choice.item_count:
  if jump_choice.get_item_metadata(index)==jump_id:jump_choice.select(index);break
 for action in choices:
  var option:OptionButton=choices[action];var selected=str(overrides.get(action,""));option.select(0)
  for index in option.item_count:
   if option.get_item_metadata(index)==selected:option.select(index);break
  var native_slot:Array=Catalog.hotbar(character)[Catalog.SLOTS.keys().find(action)]
  option.set_item_text(0,"Original · "+(str(native_slot[0]) if not native_slot.is_empty() else "Empty"))
 note.text=(Jumps.STYLES[jump_id].description+"\n" if Jumps.STYLES.has(jump_id) else "")+"Saved per fighter. Q / Esc returns to the fighter gallery."
 syncing=false

func _input(event:InputEvent):
 if event.is_echo():return
 if event.is_action_pressed("pause") or event.is_action_pressed("character_toggle"):
  get_viewport().set_input_as_handled();queue_free()
