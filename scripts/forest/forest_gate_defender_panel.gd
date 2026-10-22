extends Control
var game
const PreparationSkin=preload("res://scripts/forest/preparation_skin.gd")
func _ready():
 process_mode=Node.PROCESS_MODE_ALWAYS;theme=PreparationSkin.theme();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
 var shade=ColorRect.new();shade.color=Color(0,0,0,.65);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
 var panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);panel.offset_left=-340;panel.offset_right=340;panel.offset_top=-290;panel.offset_bottom=290;add_child(panel)
 panel.add_theme_stylebox_override("panel",PreparationSkin.panel())
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",14);panel.add_child(column)
 column.add_child(PreparationSkin.heading("GATE DEFENDERS"))
 var help=Label.new();help.text="One character per gate · Duplicate characters welcome\nDefenders use their own attacks and skills near their gate.\nKnocked out defenders recover after 15 seconds.";help.add_theme_font_size_override("font_size",16);column.add_child(help)
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
 var rows=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rows.add_theme_constant_override("separation",14);scroll.add_child(rows)
 for gate in game.gate_defenders.gates():
  var row=HBoxContainer.new();rows.add_child(row)
  var label_=Label.new();label_.text=game.gate_defenders.gate_name(gate);label_.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label_)
  var picker=OptionButton.new();picker.name="GateChoice%d"%gate.id;picker.custom_minimum_size=Vector2(210,44);row.add_child(picker)
  for id in game.player.RogueRoster.selection_ids():
   if game.player.RogueRoster.supports_gate_defender(id):picker.add_item(game.player.RogueRoster.name_for(id) if id>=3 else game.player.ROSTER[id].name,id)
  picker.select(picker.get_item_index(game.gate_defenders.units[gate.id].character_id))
  if picker.selected<0:picker.text="Choose defender"
  picker.item_selected.connect(func(index):game.gate_defenders.assign(gate.id,picker.get_item_id(index)))
 if game.gate_defenders.units.is_empty():
  var empty=Label.new();empty.text="Place a gate to add its defender.";rows.add_child(empty)
 var done=Button.new();done.text="Done · Saved automatically";PreparationSkin.apply_button(done,true);done.custom_minimum_size.y=48;done.pressed.connect(close);column.add_child(done)
func _unhandled_input(event):
 if event.is_action_pressed("ui_cancel"):
  close();get_viewport().set_input_as_handled()
func close():
 game.ordinary_pause=false;game.paused=true;game.get_tree().paused=true;game.forest_ui.sync();queue_free()
