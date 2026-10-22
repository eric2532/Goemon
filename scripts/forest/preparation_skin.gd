extends RefCounted
## Original Kenney Adventure artwork, CC0; frames resize with nine-slice margins.
const INK=Color("443b2b")
const PAPER=Color("fff1d2")
const PANEL=preload("res://assets/ui/kenney_adventure/panel_brown_corners_a.svg")
const BUTTON=preload("res://assets/ui/kenney_adventure/button_brown.svg")
const RED=preload("res://assets/ui/kenney_adventure/button_red.svg")
const DISABLED=preload("res://assets/ui/kenney_adventure/button_grey.svg")
const BANNER=preload("res://assets/ui/kenney_adventure/banner_classic_curtain.svg")
static var cached_theme:Theme
const TRAY_WIDTH=700.0
static func layout_cards(control:Control):
	control.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	var width=minf(TRAY_WIDTH-32,control.get_parent().size.x-48)
	control.anchor_left=.5;control.anchor_right=.5
	control.offset_left=-width*.5;control.offset_right=width*.5;control.offset_top=-90;control.offset_bottom=-16
static func frame(texture:Texture2D,margin:float=8,content:float=10)->StyleBoxTexture:
	var box=StyleBoxTexture.new();box.texture=texture
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		box.set_texture_margin(side,margin);box.set_content_margin(side,content)
	return box
static func panel()->StyleBoxTexture:return frame(PANEL,16,20)
static func button_style(state:String,primary:bool=false)->StyleBoxTexture:
	var box=frame(DISABLED if state=="disabled" else RED if primary or state in ["pressed","hover_pressed"] else BUTTON,8,10)
	box.content_margin_top=6;box.content_margin_bottom=6
	if state in ["hover","hover_pressed"]:box.modulate_color=Color(1.08,1.06,1.01)
	if state=="disabled":box.modulate_color=Color(.86,.86,.82)
	return box
static func apply_button(button:Button,primary:bool=false):
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:button.add_theme_stylebox_override(state,button_style(state,primary))
	var focus=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=Color("c3943b");focus.set_border_width_all(2);focus.set_corner_radius_all(4)
	button.add_theme_stylebox_override("focus",focus)
	for key in ["font_color","font_hover_color","font_focus_color"]:button.add_theme_color_override(key,PAPER if primary else INK)
	button.add_theme_color_override("font_pressed_color",PAPER);button.add_theme_color_override("font_hover_pressed_color",PAPER)
	button.add_theme_color_override("font_disabled_color",Color("626256"))
	button.add_theme_font_size_override("font_size",16)
static func apply_card(button:Button,texture:Texture2D):
	apply_button(button)
	button.icon=texture;button.expand_icon=true;button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP;button.add_theme_constant_override("icon_max_width",30)
	button.add_theme_font_size_override("font_size",14)
	button.custom_minimum_size=Vector2(128,74);button.size_flags_horizontal=Control.SIZE_FILL
	button.tooltip_text=""
static func theme()->Theme:
	if cached_theme!=null:return cached_theme
	cached_theme=Theme.new();cached_theme.default_font_size=16
	cached_theme.set_color("font_color","Label",INK)
	for type in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","hover_pressed","disabled"]:cached_theme.set_stylebox(state,type,button_style(state))
		for key in ["font_color","font_hover_color","font_focus_color"]:cached_theme.set_color(key,type,INK)
		cached_theme.set_color("font_pressed_color",type,PAPER);cached_theme.set_color("font_disabled_color",type,Color("626256"))
	cached_theme.set_stylebox("panel","PopupMenu",panel());cached_theme.set_color("font_color","PopupMenu",INK)
	cached_theme.set_stylebox("hover","PopupMenu",button_style("pressed"));cached_theme.set_color("font_hover_color","PopupMenu",PAPER)
	return cached_theme
static func heading(text:String)->PanelContainer:
	var view=PanelContainer.new();view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var box=frame(BANNER,12,8);box.texture_margin_left=54;box.texture_margin_right=54
	box.content_margin_left=24;box.content_margin_right=24;box.content_margin_top=4;box.content_margin_bottom=11
	view.add_theme_stylebox_override("panel",box)
	var label=Label.new();label.text=text;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",16);label.add_theme_color_override("font_color",PAPER);view.add_child(label)
	return view
