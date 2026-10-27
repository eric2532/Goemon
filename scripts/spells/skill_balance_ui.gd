extends "res://scripts/character_balance_ui.gd"
const Skills=preload("res://scripts/spells/skill_balance.gd")
var skill_id=""
func _ready():
 var catalog=Skills.all()
 if not catalog.has(skill_id):skill_id=catalog.keys()[0]
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var background=ColorRect.new();background.color=Color("190912");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background)
 game.label_at(self,"SKILL BALANCE",Vector2(64,56),38)
 game.label_at(self,"Saved per skill, shared by every fighter who equips it. Changes apply to the next cast.",Vector2(67,110),18,Color("dfc384"))
 var picker=OptionButton.new();picker.name="BalanceSkill";picker.position=Vector2(64,160);picker.size=Vector2(940,52);picker.get_popup().max_size=Vector2i(0,480)
 for id in catalog:
  var spec=catalog[id]
  picker.add_item(("Goemon" if spec.source==1 else "Edo" if spec.source==2 else Skills.Catalog.Roster.name_for(spec.source))+" · "+spec.name);picker.set_item_metadata(picker.item_count-1,id)
  if id==skill_id:picker.select(picker.item_count-1)
 add_child(picker)
 picker.item_selected.connect(func(index):game.show_skill_balance(from_pause,picker.get_item_metadata(index)))
 var controls=column(Vector2(64,245),"SKILL MULTIPLIERS")
 for row in Skills.ROWS:
  var line=HBoxContainer.new();controls.add_child(line)
  var label=Label.new();label.text=row[1];label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.add_theme_font_size_override("font_size",18);line.add_child(label)
  var spin=SpinBox.new();spin.name="Skill_"+row[0];spin.min_value=row[2];spin.max_value=row[3];spin.step=.05;spin.custom_arrow_step=row[4];spin.suffix="×";spin.custom_minimum_size=Vector2(145,44)
  spin.value=Skills.value(game,skill_id,row[0]);line.add_child(spin)
  spin.editable=Skills.supports(skill_id,row[0])
  if not spin.editable:line.tooltip_text="Not used by this skill.";label.text+=" · N/A";spin.modulate=Color(.6,.6,.6)
  spin.value_changed.connect(func(value):game.update_skill_balance(skill_id,row[0],value))
 var help=column(Vector2(747,245),"HOW TO TUNE")
 var note=Label.new();note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.text="1× keeps the current approved behavior.\n\nVisual size changes the effect's appearance. Hit area changes its contact radius or reach independently.\n\nTravel speed changes projectile or attack movement. Casting animations, cooldowns and damage intervals keep their existing timing.\n\nDamage multiplies the fighter's existing damage bonuses. Utility skills show N/A for values they do not use.";note.add_theme_font_size_override("font_size",18);help.add_child(note)
 game.label_at(self,"Saved automatically. Reset restores only this skill to 1×.",Vector2(67,763),17,Color("dfc384"))
 game.button_at(self,"Back to Settings",Vector2(64,808),func():game.show_settings(from_pause),300).name="SkillBalanceBack"
 game.button_at(self,"Reset this skill",Vector2(746,808),func():game.reset_skill_balance(skill_id);game.show_skill_balance(from_pause,skill_id),620).name="SkillBalanceReset"
