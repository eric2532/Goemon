extends Control
const Balance=preload("res://scripts/forest/core_balance.gd")
const Progression=preload("res://scripts/forest/team_progression.gd")
var game
var from_pause=false
var from_map=false
var wave_box: VBoxContainer
var wave_total: Label
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.label_at(self,"CORE GAME BALANCE",Vector2(64,56),38)
	game.label_at(self,"Saved automatically · Enemy multipliers and size: next wave · Towers: immediate.\nWave composition and groups: next START · Enemy fort health and gold: next run.",Vector2(67,110),18,Color("dfc384"))
	var economy=column(Vector2(64,168),Vector2(620,570),"ECONOMY, TOWERS & ENEMIES")
	for row in Balance.ROWS:
		if row[0] in ["spawn_group_start","spawn_group_growth","boss_health","boss_speed"]:continue
		var spin=number_row(economy,row[1],"Core_"+row[0],row[2],row[3],row[4],game.core_balance[row[0]],row[4]<1)
		if row[0]=="enemy_wall_health":spin.tooltip_text="Health of each enemy wall panel, gate and tower. Breaching one leaves the statue and reinforcements active. Applies next run."
		if row[0]=="enemy_castle_health":spin.tooltip_text="Health of the Skullpion statue inside each enemy castle. Destroy every enemy statue to win. Applies next run."
		spin.value_changed.connect(func(value):game.update_core_balance(row[0],value))
	var enemies=Button.new();enemies.name="CoreEnemyBalance";enemies.text="Individual enemy balance";enemies.custom_minimum_size.y=44;economy.add_child(enemies)
	enemies.pressed.connect(func():game.show_enemy_balance(from_pause))
	var note=Label.new();note.text="Enemy size: ordinary enemies (1× = current size).\nEach enemy has its own wave count.\nFirst wave on START, then every 60 seconds.\nMovement and damage × include Skullpion.\nTowers fire automatically; no workers needed.\nCannon: 5.58× damage, 1.79× shot interval.\nTower health edits preserve damage percentage.";note.add_theme_font_size_override("font_size",17);economy.add_child(note)
	var rarity_note=Label.new();rarity_note.name="SkillCardBag";rarity_note.add_theme_font_size_override("font_size",17)
	var total:int=Progression.RARITY_MARBLES.reduce(func(sum_,count):return sum_+count,0)
	var rarities:PackedStringArray=[]
	for i in Progression.RARITIES.size():rarities.append("%s %.0f%%"%[Progression.RARITIES[i],100.0*Progression.RARITY_MARBLES[i]/total])
	rarity_note.text="Skill cards draw from a shuffled bag\n"+" · ".join(rarities);economy.add_child(rarity_note)
	var waves=column(Vector2(747,168),Vector2(620,570),"WAVE COMPOSITION")
	for row in Balance.ROWS:
		if row[0] not in ["spawn_group_start","spawn_group_growth"]:continue
		var spin=number_row(waves,row[1],"Core_"+row[0],row[2],row[3],row[4],game.core_balance[row[0]])
		spin.value_changed.connect(func(value):game.update_core_balance(row[0],value))
	var groups=Label.new();groups.text="Each spot grows independently after its group attacks.\nEvery minute releases a wave and resets group growth.\nEmpty waves keep their minute; the final wave ends arrivals.";groups.add_theme_font_size_override("font_size",17);waves.add_child(groups)
	var count=number_row(waves,"Number of waves","Core_wave_count",1,Balance.MAX_WAVES,1,game.core_balance.waves.size())
	count.value_changed.connect(func(value):
		game.resize_core_waves(int(value));refresh_waves())
	wave_total=Label.new();wave_total.add_theme_font_size_override("font_size",17);waves.add_child(wave_total)
	wave_box=VBoxContainer.new();wave_box.add_theme_constant_override("separation",12);waves.add_child(wave_box);refresh_waves()
	game.label_at(self,"Zero excludes an enemy. Each count means individual enemies, including Skullpion.",Vector2(67,763),17,Color("dfc384"))
	game.button_at(self,"Back to building map" if from_map else "Back to Settings",Vector2(64,808),func():
		if from_map:game.resume()
		else:game.show_settings(from_pause),300).name="CoreBalanceBack"
	game.button_at(self,"Reset core balance",Vector2(747,808),func():game.reset_core_balance();game.show_core_balance(from_pause,from_map),300).name="CoreBalanceReset"
func column(at: Vector2,dimensions: Vector2,title: String)->VBoxContainer:
	var panel=PanelContainer.new();panel.position=at;panel.size=dimensions
	var style=StyleBoxFlat.new();style.bg_color=Color(.145,.204,.235,.66);style.set_corner_radius_all(12)
	style.content_margin_left=22;style.content_margin_right=22;style.content_margin_top=20;style.content_margin_bottom=20
	panel.add_theme_stylebox_override("panel",style);add_child(panel)
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	var box=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",16);scroll.add_child(box)
	var heading=Label.new();heading.text=title;heading.add_theme_font_size_override("font_size",21);heading.add_theme_color_override("font_color",Color("f4d38b"));box.add_child(heading)
	return box
func number_row(box: VBoxContainer,title: String,id: String,minimum: float,maximum: float,increment: float,value: float,precise: bool=false)->SpinBox:
	var line=HBoxContainer.new();line.add_theme_constant_override("separation",10);box.add_child(line)
	var label=Label.new();label.text=title;label.add_theme_font_size_override("font_size",18);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(label)
	var spin=SpinBox.new();spin.name=id;spin.custom_minimum_size=Vector2(175,44);spin.min_value=minimum;spin.max_value=maximum;spin.step=.000001 if precise else 1;spin.custom_arrow_step=increment;spin.value=value;line.add_child(spin)
	return spin
func refresh_total():
	var total=0
	for wave in game.core_balance.waves:
		for count in wave:total+=count
	wave_total.text="%d waves · %d minutes · %d enemies"%[game.core_balance.waves.size(),game.core_balance.waves.size(),total]
func refresh_waves():
	for child in wave_box.get_children():wave_box.remove_child(child);child.queue_free()
	for index in range(game.core_balance.waves.size()):
		var title=Label.new();title.text="WAVE %d"%(index+1);title.add_theme_color_override("font_color",Color("f4d38b"));wave_box.add_child(title)
		for type in Balance.TYPES.size():
			var spin=number_row(wave_box,Balance.ENEMIES[type],"Wave_%d_enemy_%d"%[index+1,type],0,Balance.MAX_ENEMIES,1,game.core_balance.waves[index][type])
			spin.value_changed.connect(func(value):game.update_core_wave(index,type,int(value));refresh_total())
	refresh_total()
