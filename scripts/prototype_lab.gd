class_name PrototypeLab
extends Control

var game: Node
var status: Label

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.label_at(self,"PROTOTYPE LAB",Vector2(54,52),42)
	game.label_at(self,"Pause. Experiment. Find your rhythm.",Vector2(57,110),18,Color("f4d38b"))
	game.label_at(self,"Changes save automatically. Practice spawns stay in this area until you restart. Survival rules stay fixed.",Vector2(57,145),16)
	column("01  /  HERO",PrototypeTuning.PLAYER_ROWS,Vector2(56,205),true)
	column("02  /  COINS & GOLDEN SURGE",PrototypeTuning.COIN_ROWS,Vector2(502,205))
	column("03  /  ENCOUNTERS",PrototypeTuning.ENEMY_ROWS,Vector2(948,205),false,true)
	status=game.label_at(self,"F1 or ESC resumes · R changes your left-click moveset.",Vector2(57,748),17,Color("f4d38b"))
	game.button_at(self,"Resume",Vector2(56,803),game.resume,220).grab_focus()
	game.button_at(self,"Restore tuning defaults",Vector2(302,803),func():
		game.tuning=PrototypeTuning.DEFAULTS.duplicate()
		game.player.max_hp=game.tuning.max_hp
		game.player.hp=game.player.max_hp
		game.save_settings()
		game.show_lab(),300)
	game.button_at(self,"Pause menu",Vector2(628,803),game.show_pause,240)

func column(title: String,rows: Array,pos: Vector2,hero: bool=false,encounters: bool=false):
	var panel=PanelContainer.new()
	panel.position=pos
	panel.size=Vector2(416,510)
	var style=StyleBoxFlat.new()
	style.bg_color=Color("102b37")
	style.corner_radius_top_left=10
	style.corner_radius_top_right=10
	style.corner_radius_bottom_left=10
	style.corner_radius_bottom_right=10
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=16
	style.content_margin_bottom=16
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var scroll=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box=VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",12)
	scroll.add_child(box)
	var heading=Label.new()
	heading.text=title
	heading.add_theme_font_size_override("font_size",19)
	heading.add_theme_color_override("font_color",Color("f4d38b"))
	box.add_child(heading)
	for row in rows:
		if row[0]=="charge_time":continue
		if game.SURVIVAL_MODE and (row[0].begins_with("respawn_") or row[0]=="boss_hp_mult"):continue
		number_row(box,row)
	if hero:
		toggle(box,"Invincible","invincible")
		var row=HBoxContainer.new()
		box.add_child(row)
		var label=Label.new()
		label.text="Current HP"
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var spin=SpinBox.new()
		spin.min_value=1
		spin.max_value=2000
		spin.value=game.player.hp
		spin.custom_minimum_size=Vector2(116,36)
		row.add_child(spin)
		spin.value_changed.connect(func(v): game.player.hp=clampf(v,1,game.player.max_hp))
		action(box,"Restore full health",func():
			game.player.hp=game.player.max_hp
			spin.value=game.player.hp
			status.text="Vitality restored.")
	if encounters:
		toggle(box,"Freeze enemy AI","freeze_ai")
		action(box,"Spawn ninjas",func(): status.text="Spawned %d ninjas. Resume to fight." % game.spawn_practice(false))
		action(box,"Spawn stationary practice dummies",func(): status.text="Spawned %d dummies. Dummies stay still and take damage." % game.spawn_practice(true))
		action(box,"Clear practice spawns",func(): game.clear_practice(); status.text="Practice spawns removed. Area enemies preserved.")
		action(box,"Apply HP values to living enemies",func():
			for e in game.enemies:
				if is_instance_valid(e) and not e.dead:
					e.max_hp=(580+e.boss_style*70)*game.tuning.boss_hp_mult if e.boss else game.tuning.enemy_hp*Ninja.HEALTH[e.variant]
					e.hp=e.max_hp
					e.bar.scale.x=1
			status.text="Living enemies healed to the configured maximum HP.")

func number_row(box: VBoxContainer,row: Array):
	var line=HBoxContainer.new()
	box.add_child(line)
	var label=Label.new()
	label.text=row[1]
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var spin=SpinBox.new()
	spin.custom_minimum_size=Vector2(112,36)
	spin.min_value=row[2]
	spin.max_value=row[3]
	spin.step=row[4]
	spin.value=game.tuning[row[0]]
	line.add_child(spin)
	spin.value_changed.connect(func(value): game.update_tuning(row[0],value))

func toggle(box: VBoxContainer,title: String,key: String):
	var button=CheckButton.new()
	button.text=title
	button.button_pressed=game.tuning[key]
	box.add_child(button)
	button.toggled.connect(func(value): game.update_tuning(key,value))

func action(box: VBoxContainer,title: String,callback: Callable):
	var button=Button.new()
	button.text=title
	button.custom_minimum_size.y=36
	box.add_child(button)
	button.pressed.connect(callback)
