extends Control
const Balance=preload("res://scripts/character_balance.gd")
var game
var from_pause=false
var character_id=Balance.Roster.KAZI_ID

func _ready():
	if not Balance.Roster.is_crossgate_fighter(character_id):character_id=game.player.character_id if Balance.Roster.is_crossgate_fighter(game.player.character_id) else Balance.Roster.KAZI_ID
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.label_at(self,"CHARACTER BALANCE",Vector2(64,56),38)
	game.label_at(self,"Each fighter saves separately. Values apply before level bonuses and temporary power-ups.",Vector2(67,110),18,Color("dfc384"))
	game.label_at(self,"Editing",Vector2(67,176),20)
	var picker=OptionButton.new();picker.name="BalanceCharacter";picker.position=Vector2(168,160);picker.size=Vector2(340,52)
	for id in Balance.Roster.CROSSGATE:picker.add_item(Balance.name_for(id),id)
	picker.select(picker.get_item_index(character_id));add_child(picker)
	picker.item_selected.connect(func(index):game.show_character_balance(from_pause,picker.get_item_id(index)))
	game.label_at(self,"Current fighter: "+Balance.name_for(game.player.character_id),Vector2(560,176),18)
	var common=column(Vector2(64,245),"HEALTH, COMBAT & MOVEMENT")
	for row in Balance.COMMON_ROWS:number_row(common,row)
	var specific=column(Vector2(747,245),Balance.name_for(character_id).to_upper()+" · PLAYTEST")
	for row in Balance.special_rows(character_id):number_row(specific,row)
	if specific.find_child("Balance_combo_charge_size",true,false)!=null:
		var baseline=Label.new();baseline.name="ComboBaseline"
		baseline.text="連擊 baseline: glow 1× · effect %s× body · splash %s m"%[Balance.value({}, {},character_id,"combo_effect_height"),Balance.value({}, {},character_id,"combo_splash_radius")]
		baseline.add_theme_font_size_override("font_size",16);baseline.add_theme_color_override("font_color",Color("dfc384"));specific.add_child(baseline)
	var note=Label.new();note.text="Shared playtest controls · all fighters";note.add_theme_color_override("font_color",Color("dfc384"));specific.add_child(note)
	var invincible=CheckButton.new();invincible.name="BalanceInvincible";invincible.text="Invincible";invincible.button_pressed=game.tuning.invincible;specific.add_child(invincible)
	invincible.toggled.connect(func(enabled):game.update_tuning("invincible",enabled))
	number_row(specific,["enemy_damage","Incoming enemy damage ×",0,5,.1],true)
	var heal=Button.new();heal.text="Restore current fighter's health";heal.custom_minimum_size.y=44;specific.add_child(heal)
	heal.pressed.connect(func():game.player.hp=game.player.max_hp;game.toast("Health restored."))
	game.label_at(self,"Base DPS 250 · Melee reach ×1.25 / speed ×1.2 · Fists: extra reach/speed ×1.25 before upgrades.",Vector2(67,735),17,Color("dfc384"))
	game.label_at(self,"Saved automatically. Reset restores this fighter's defaults · Base HP 1,000.",Vector2(67,763),17,Color("dfc384"))
	game.button_at(self,"Back to Settings",Vector2(64,808),func():game.show_settings(from_pause),300).name="BalanceBack"
	game.button_at(self,"Reset "+Balance.name_for(character_id)+" balance",Vector2(746,808),func():game.reset_character_tuning(character_id);game.show_character_balance(from_pause,character_id),620).name="BalanceReset"

func column(position_: Vector2,title: String)->VBoxContainer:
	var panel=PanelContainer.new();panel.position=position_;panel.size=Vector2(620,480)
	var style=StyleBoxFlat.new();style.bg_color=Color(.145,.204,.235,.66);style.set_corner_radius_all(12);style.content_margin_left=22;style.content_margin_right=22;style.content_margin_top=20;style.content_margin_bottom=20
	panel.add_theme_stylebox_override("panel",style);add_child(panel)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	var box=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",16);scroll.add_child(box)
	var heading=Label.new();heading.text=title;heading.add_theme_font_size_override("font_size",21);heading.add_theme_color_override("font_color",Color("f4d38b"));box.add_child(heading)
	return box

func number_row(box: VBoxContainer,row: Array,shared: bool=false):
	var line=HBoxContainer.new();line.add_theme_constant_override("separation",14);box.add_child(line)
	var label=Label.new();label.text=row[1];label.add_theme_font_size_override("font_size",18);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(label)
	var spin=SpinBox.new();spin.name="Balance_"+row[0];spin.custom_minimum_size=Vector2(145,44);spin.min_value=row[2];spin.max_value=row[3]
	# Arrow increments must not round inherited HP/speed/jump values on open.
	spin.step=1 if row[0] in ["coin_count","split_count"] else .001
	spin.custom_arrow_step=row[4]
	if row[0] in ["critical_chance","dodge_chance","counter_chance"]:spin.suffix="%"
	if row[0] in ["dodge_chance","counter_chance"]:
		line.tooltip_text="Chance to avoid an incoming hit with a quick out-and-back step, without afterimages." if row[0]=="dodge_chance" else "Chance on a damaging hit or dodge to leave a shadow that attacks once for normal damage. Your own attacks stay independent."
		spin.tooltip_text=line.tooltip_text
	if row[0] in ["model_scale","attack_speed"]:
		spin.suffix="×"
		line.tooltip_text="Visual size relative to the original model. Melee reach and collision size are separate." if row[0]=="model_scale" else "Normal attack animation and contact speed, before level bonuses and power-ups. Skill durations and cooldowns stay separate."
		spin.tooltip_text=line.tooltip_text
	if row[0]=="jump_height":
		spin.suffix="×"
		line.tooltip_text="1× keeps the original jump. Applies to this fighter’s original or equipped jumps, including boss leaps. Flight and attack travel keep their own settings."
		spin.tooltip_text=line.tooltip_text
	if row[0]=="jump_drop_speed":
		spin.suffix="×"
		line.tooltip_text="Below 1× falls slower after the peak of an original or equipped jump. Flight and moves that control their own travel keep their own speed."
		spin.tooltip_text=line.tooltip_text
	if row[0]=="melee_reach":
		spin.suffix="×"
		line.tooltip_text="1× is original reach. Adjust up to 10× for longer melee weapons and hit reach. Does not change projectile travel."
		spin.tooltip_text=line.tooltip_text
	if row[0].begins_with("combo_"):
		line.tooltip_text={
			"combo_charge_size":"1× keeps this fighter's original 連擊 charge glow. Visual only; other skills keep their own glow.",
			"combo_effect_height":"Largest visible 連擊 burst dimension in base fighter heights. The default is one normal slime across. Changes neither damage nor hit area.",
			"combo_splash_radius":"Base radius around each 連擊 target; 0 hits only that target. Model growth and melee reach bonuses still apply. Keeps the same damage and cover checks."
		}[row[0]]
		spin.tooltip_text=line.tooltip_text
	spin.value=game.tuning[row[0]] if shared else game.balance_value(character_id,row[0]);line.add_child(spin)
	spin.value_changed.connect(func(value):
		if shared:game.update_tuning(row[0],value)
		else:game.update_character_tuning(character_id,row[0],value))
	if row[0]=="melee_reach":
		var help=Label.new();help.text="1× original · Up to 10× melee reach."
		help.add_theme_font_size_override("font_size",16);help.add_theme_color_override("font_color",Color("dfc384"));box.add_child(help)
