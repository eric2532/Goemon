extends "res://scripts/character_balance_ui.gd"
const Skills=preload("res://scripts/spells/skill_balance.gd")
var skill_id=""
func _ready():
 var catalog=Skills.all().duplicate()
 for id in catalog.keys():
  if not Skills.Catalog.available(catalog[id]) or id==Skills.Catalog.MAZE_QI:catalog.erase(id)
 if not catalog.has(skill_id):skill_id=catalog.keys()[0]
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var background=ColorRect.new();background.color=Color("17242aa3");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background)
 game.label_at(self,"SKILL BALANCE",Vector2(64,56),38)
 game.label_at(self,"Run levels are shared by skill and reset on a new run. Saved adjustments apply to the next cast.",Vector2(67,110),18,Color("dfc384"))
 var picker=OptionButton.new();picker.name="BalanceSkill";picker.position=Vector2(64,160);picker.size=Vector2(940,52);picker.get_popup().max_size=Vector2i(0,480)
 for id in catalog:
  var spec=catalog[id]
  picker.add_item(("Goemon" if spec.source==1 else "Edo" if spec.source==2 else Skills.Catalog.Roster.name_for(spec.source))+" · "+spec.name);picker.set_item_metadata(picker.item_count-1,id)
  if id==skill_id:picker.select(picker.item_count-1)
 add_child(picker)
 picker.item_selected.connect(func(index):game.show_skill_balance(from_pause,picker.get_item_metadata(index)))
 var controls=column(Vector2(64,245),"SKILL BASELINE")
 for row in [["level","Run skill level",1,30],["bonus","Manual extra hits / targets",0,96]]:
  var line=HBoxContainer.new();controls.add_child(line)
  var label=Label.new();label.text=row[1];label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.add_theme_font_size_override("font_size",18);line.add_child(label)
  var spin=SpinBox.new();spin.name="RunSkill_"+row[0];spin.min_value=row[2];spin.max_value=row[3];spin.step=1;spin.custom_minimum_size=Vector2(145,44)
  var manual=game.player.team_progression.skill_modifiers.get(Skills.Levels.family(skill_id),{}).get("manual",{}) if game.player.team_progression!=null else {}
  spin.value=Skills.level_for(game.player,skill_id) if row[0]=="level" else float(manual.get("count",0))
  spin.editable=game.player.team_progression!=null and (row[0]=="level" or Skills.rules_for(game.player,skill_id).has("count"));line.add_child(spin)
  var field:String=row[0]
  spin.value_changed.connect(func(value):
   if field=="level":Skills.set_level(game.player,skill_id,value)
   else:Skills.set_modifier(game.player,skill_id,"manual",{"count":value})
   update_summary())
 for row in Skills.rows(skill_id):
  var count_offset=Skills.baseline(skill_id,"count") if row[0]=="count" and Skills.rules_for(game.player,skill_id).has("count") else 0.0
  var line=HBoxContainer.new();controls.add_child(line)
  var label=Label.new();label.text="Saved extra hits / targets" if count_offset else row[1];label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.add_theme_font_size_override("font_size",18);line.add_child(label)
  var spin=SpinBox.new();spin.name="Skill_"+row[0];spin.min_value=row[2];spin.max_value=row[3];spin.step=1 if row[0]=="count" else .05;spin.custom_arrow_step=row[4];spin.suffix="" if row[0]=="count" else "×";spin.custom_minimum_size=Vector2(145,44)
  if count_offset:spin.min_value-=count_offset;spin.max_value-=count_offset
  spin.value=Skills.value(game,skill_id,row[0])-count_offset;line.add_child(spin)
  spin.editable=Skills.supports(skill_id,row[0])
  if not spin.editable:line.tooltip_text="Not used by this skill.";label.text+=" · N/A";spin.modulate=Color(.6,.6,.6)
  spin.value_changed.connect(func(value):game.update_skill_balance(skill_id,row[0],value+count_offset);update_summary())
 var help=column(Vector2(747,245),"HOW TO TUNE")
 var summary=Label.new();summary.name="RunSkillSummary";summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;summary.add_theme_font_size_override("font_size",18);help.add_child(summary)
 update_summary()
 var baseline=Label.new();baseline.name="SkillBaseline";baseline.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 baseline.text="Saved size and hit-area adjustments start at 1×. Level growth, food and item bonuses apply separately."
 var count_=Skills.count_spec(skill_id)
 if not count_.is_empty() and not Skills.rules_for(game.player,skill_id).has("count"):baseline.text+="\n%s: %d."%[count_[1],count_[0]]
 if skill_id.ends_with("/combo"):baseline.text+="\n連擊 uses its Character Balance glow, burst height and splash radius as the 1× base."
 baseline.add_theme_font_size_override("font_size",18);help.add_child(baseline)
 var note=Label.new();note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.text="Run level and manual extra counts reset on a new run. Spend shared points in I → Skills.\n\nSaved adjustments remain separate and are kept between runs. Extra hit/target adjustments add to the level's count.\n\nItems and special upgrades can modify these values too. Changes apply to new casts. Visual size and physical hit area are independent.";note.add_theme_font_size_override("font_size",18);help.add_child(note)
 game.label_at(self,"Run controls reset on a new run. Saved adjustments are saved automatically.",Vector2(67,763),17,Color("dfc384"))
 game.button_at(self,"Back to Settings",Vector2(64,808),func():game.show_settings(from_pause),300).name="SkillBalanceBack"
 game.button_at(self,"Reset this skill",Vector2(746,808),func():game.reset_skill_balance(skill_id);game.show_skill_balance(from_pause,skill_id),620).name="SkillBalanceReset"

func update_summary():
 var node=find_child("RunSkillSummary",true,false)
 if node==null:return
 var rules=Skills.rules_for(game.player,skill_id)
 node.text="Run level %d / 30"%Skills.level_for(game.player,skill_id)
 if rules.is_empty():node.text+="\nExisting behavior retained; progression numbers are not defined yet."
 var names={"damage":"Base damage ×","count":"Hits / targets / copies","critical_bonus":"Extra critical-chance points","size":"Impact size ×","hit_area":"Hit area ×","chance":"Success chance","healing":"Missing HP restored","effect_tier":"Effect tier","base_damage":"Total base damage per target","secondary_damage":"Follow-up damage ×","defense_penalty":"Defense penalty"}
 if not rules.is_empty() and Skills.Levels.family(skill_id) in Skills.Levels.SHINE_FAMILIES:
  var tier=Skills.Levels.shine_tier(Skills.level_for(game.player,skill_id))
  node.text+="\nCasting shine: EX" if tier==Skills.Levels.EX_TIER else "\nOriginal casting shine tier: %d"%(tier+1)
 for key in rules:
  if key=="size" and Skills.Levels.family(skill_id)=="double-edge":continue
  var value=rules[key]
  if key=="count":value=Skills.effective(game.player,skill_id,key)
  if key in ["chance","healing","defense_penalty"]:value="%.1f%%"%(float(value)*100)
  elif key=="effect_tier":value=Skills.effect_tier_name(skill_id,int(value))
  node.text+="\n%s: %s"%[names.get(key,key),str(value)]
