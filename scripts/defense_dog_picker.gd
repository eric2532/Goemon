extends Control
## A paused companion roster. Portraits show the actual Blender models.
var game: Node
var roster_property="kennel"
var heading="C A S T L E   K E N N E L"
var subtitle="Choose an ally. Dogs leave the castle, hunt raiders, and fight for the shrine."
var unit_label="DOGS"
var summon_prefix="DogSummon_"
var close_name="DogRosterClose"
var summon_method="summon_defense_dog"
var close_method="close_dog_roster"
var hotkey="G"
var input_action="summon_dogs"
var other_action="summon_heroes"
var other_roster_method="show_hero_roster"
var full_text="PACK FULL"

func label(words: String,point_size: int,tint: Color=Color("eaf1ed"))->Label:
	var node=Label.new();node.text=words
	node.add_theme_font_size_override("font_size",point_size)
	node.add_theme_color_override("font_color",tint)
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return node

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	var roster=game.get(roster_property)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(center)
	var layout=VBoxContainer.new();layout.custom_minimum_size.x=1200;layout.add_theme_constant_override("separation",12);center.add_child(layout)
	layout.add_child(label(heading,34,Color("f1d198")))
	layout.add_child(label(subtitle,17,Color("c0d4d5")))
	var status="%d GOLD     ·     %d / %d %s" % [game.encounters.money,roster.living_count(),roster.capacity(),unit_label]
	status+="     ·     READY TO SUMMON" if roster.cooldown_left<=0 else "     ·     COOLDOWN %.1fs — resume to recharge" % roster.cooldown_left
	layout.add_child(label(status,18,Color("9be4d4")))
	var grid=GridContainer.new();grid.columns=5;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);layout.add_child(grid)
	var first: Button=null
	for data in roster.definitions():
		var tint=Color(data.color)
		var button=Button.new();button.name=summon_prefix+data.id
		button.custom_minimum_size=Vector2(228,292);button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		button.disabled=not roster.can_summon(data.id)
		button.tooltip_text=roster.reason(data.id) if button.disabled else "Summon %s from the castle for %d gold" % [data.name,data.cost]
		var style=StyleBoxFlat.new();style.bg_color=Color("142c36");style.border_color=Color(tint,.5);style.set_border_width_all(1);style.set_corner_radius_all(10)
		var active=style.duplicate();active.bg_color=Color("25434b");active.border_color=tint;active.set_border_width_all(2)
		var disabled=style.duplicate();disabled.bg_color=Color("182a30");disabled.border_color=Color("52646a")
		button.add_theme_stylebox_override("normal",style);button.add_theme_stylebox_override("hover",active);button.add_theme_stylebox_override("focus",active);button.add_theme_stylebox_override("pressed",active);button.add_theme_stylebox_override("disabled",disabled)
		button.pressed.connect(Callable(game,summon_method).bind(data.id));grid.add_child(button)
		var contents=VBoxContainer.new();contents.mouse_filter=Control.MOUSE_FILTER_IGNORE
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);contents.offset_left=14;contents.offset_right=-14;contents.offset_top=10;contents.offset_bottom=-12;contents.add_theme_constant_override("separation",4);button.add_child(contents)
		var portrait=TextureRect.new();portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
		portrait.custom_minimum_size=Vector2(196,112);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(data.portrait):portrait.texture=load(data.portrait)
		portrait.modulate=Color(1,1,1,.55) if button.disabled else Color.WHITE
		contents.add_child(portrait)
		contents.add_child(label(data.name,24,tint))
		contents.add_child(label(data.role,11,Color("c8d7d5")))
		var description=label(data.description,14,Color("b9cfce"));description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.custom_minimum_size=Vector2(196,36);contents.add_child(description)
		contents.add_child(label("%d HP   ·   %d %s" % [data.hp,data.damage,"PER HIT" if roster_property=="barracks" else "ATTACK"],13))
		var price=label("SUMMON  /  %d GOLD" % data.cost,17,tint)
		if button.disabled:
			if not ResourceLoader.exists(data.asset):price.text="UNAVAILABLE"
			elif roster.living_count()>=roster.capacity():price.text=full_text
			elif roster.cooldown_left>0:price.text="RECHARGING"
			else:price.text="NEED %d GOLD" % maxi(0,data.cost-game.encounters.money)
		contents.add_child(price)
		if first==null and not button.disabled:first=button
	var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",24);layout.add_child(footer)
	var close=Button.new();close.name=close_name;close.text=hotkey+" / Esc · Back to battle";close.custom_minimum_size=Vector2(270,44);close.pressed.connect(Callable(game,close_method));footer.add_child(close)
	footer.add_child(label("G · Dogs   /   H · Characters   ·   Time is paused.\nEach roster recharges in 3 seconds of battle time. Allies stay until defeated.",15,Color("a9c3c4")))
	if first!=null:first.grab_focus()
	else:close.grab_focus()

func _input(event):
	if not is_visible_in_tree():return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed(input_action) or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled();game.call(close_method)
		elif event.is_action_pressed(other_action):
			get_viewport().set_input_as_handled();game.call(other_roster_method)
