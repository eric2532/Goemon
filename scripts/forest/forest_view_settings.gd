extends Control
const Prefs=preload("res://scripts/forest/forest_view_preferences.gd")
var game
var from_pause=false
func _ready():
	name="ForestViewSettings";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sidebar=Control.new();sidebar.name="ViewSettingsSidebar";sidebar.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(sidebar)
	sidebar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);sidebar.offset_left=-468;sidebar.offset_right=-48
	game.label_at(sidebar,"CAMERA & HUD",Vector2(0,200),30,Color("f4d38b"))
	var panel=PanelContainer.new();panel.position=Vector2(0,250);panel.size=Vector2(420,460)
	var box=StyleBoxFlat.new();box.bg_color=Color("102b37");box.set_corner_radius_all(12)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:box.set_content_margin(side,22)
	panel.add_theme_stylebox_override("panel",box);sidebar.add_child(panel)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",10);panel.add_child(column)
	var distance_value=value_row(column,"Combat camera distance","CameraDistanceValue")
	var distance=slider(column,"CombatCameraDistance",Prefs.CAMERA_MIN,Prefs.CAMERA_MAX,Prefs.CAMERA_STEP,game.settings.forest_camera_distance)
	distance_value.text="%.1f"%distance.value
	distance.value_changed.connect(func(value):game.set_forest_camera_distance(value);distance_value.text="%.1f"%value)
	var position_value=value_row(column,"Character position","CharacterPositionValue")
	var position_slider=slider(column,"CharacterScreenPosition",Prefs.CHARACTER_OFFSET_MIN*100,Prefs.CHARACTER_OFFSET_MAX*100,1,game.settings.forest_character_screen_offset*100)
	position_value.text=position_text(position_slider.value)
	position_slider.tooltip_text="Move right to place your character lower and see more ahead.\nOffsets use a percentage of screen height; framing stops near the screen edge."
	position_slider.value_changed.connect(func(value):game.set_forest_character_screen_offset(value/100.0);position_value.text=position_text(value))
	var directions=HBoxContainer.new();column.add_child(directions)
	for text in ["← Higher","Lower →"]:
		var direction=Label.new();direction.text=text;direction.add_theme_font_size_override("font_size",14);direction.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		if text=="Lower →":direction.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		directions.add_child(direction)
	var scale_value=value_row(column,"HUD size","HUDScaleValue")
	var hud=slider(column,"HUDScale",Prefs.HUD_MIN*100,Prefs.HUD_MAX*100,5,game.settings.forest_hud_scale*100)
	scale_value.text="%d%%"%hud.value
	hud.value_changed.connect(func(value):game.set_forest_hud_scale(value/100.0);scale_value.text="%d%%"%value)
	var crosshair=CheckButton.new();crosshair.name="ShowCrosshairToggle";crosshair.text="Show third-person crosshair"
	crosshair.button_pressed=game.settings.forest_show_crosshair;crosshair.custom_minimum_size=Vector2(350,40);crosshair.add_theme_font_size_override("font_size",18)
	crosshair.tooltip_text="Show the gold aiming crosshair in third person. Hiding it keeps attack aiming unchanged.\nMaster Chief always uses his first-person rifle reticle."
	crosshair.toggled.connect(game.set_forest_show_crosshair);column.add_child(crosshair)
	var note=Label.new();note.text="Saved automatically.\nBuilding-map zoom uses the mouse wheel.";note.add_theme_font_size_override("font_size",16);note.add_theme_color_override("font_color",Color("dfc384"));column.add_child(note)
	var reset=game.button_at(self,"Reset camera & HUD",Vector2.ZERO,func():distance.value=Prefs.CAMERA_DEFAULT;position_slider.value=Prefs.CHARACTER_OFFSET_DEFAULT*100;hud.value=Prefs.HUD_DEFAULT*100;crosshair.button_pressed=true,350)
	remove_child(reset);column.add_child(reset);reset.name="ResetViewSettings";reset.custom_minimum_size=Vector2(350,46)
	game.button_at(sidebar,"Back to Settings",Vector2(0,756),func():game.show_settings(from_pause),300).name="ViewSettingsBack"
func position_text(value: float)->String:
	if is_zero_approx(value):return "Default"
	return "%d%% %s"%[absf(value),"lower" if value>0 else "higher"]
func value_row(column: VBoxContainer,title: String,id: String)->Label:
	var row=HBoxContainer.new();column.add_child(row)
	var label=Label.new();label.text=title;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.add_theme_font_size_override("font_size",18);row.add_child(label)
	var value=Label.new();value.name=id;value.add_theme_font_size_override("font_size",18);value.add_theme_color_override("font_color",Color("f4d38b"));row.add_child(value);return value
func slider(column: VBoxContainer,id: String,minimum: float,maximum: float,increment: float,value: float)->HSlider:
	var control=HSlider.new();control.name=id;control.min_value=minimum;control.max_value=maximum;control.step=increment;control.value=value;control.custom_minimum_size=Vector2(350,32);column.add_child(control);return control
