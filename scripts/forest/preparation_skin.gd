extends RefCounted
## Shared recovered Cross Gate ivory frames and slate panels; nine-slice art is imported once.
const INK=Color("25343c")
const PAPER=Color("f3eed8")
const PANEL=preload("res://assets/ui/crossgate/menu/panel.svg")
const COMPACT=preload("res://assets/ui/crossgate/menu/compact.svg")
const BUTTON=preload("res://assets/ui/crossgate/menu/button.svg")
const FONT=preload("res://assets/ui/fonts/interface.tres")
static var cached_theme:Theme
const TRAY_WIDTH=740.0
static func layout_cards(control:Control,inset:float=16):
	control.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	var width=minf(TRAY_WIDTH,control.get_parent().size.x-208)
	control.offset_left=22+inset;control.offset_right=22+width-inset
	control.offset_top=-140;control.offset_bottom=-60
static func frame(texture:Texture2D,margin:float=8,content:float=10)->StyleBoxTexture:
	var box=StyleBoxTexture.new();box.texture=texture
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		box.set_texture_margin(side,margin);box.set_content_margin(side,content)
	return box
static func panel()->StyleBoxTexture:
	var box=frame(PANEL,18,20)
	box.texture_margin_top=34;box.texture_margin_right=38;box.texture_margin_bottom=22
	box.content_margin_top=34;box.content_margin_right=38;box.content_margin_bottom=22
	return box
static func compact_panel()->StyleBoxTexture:return frame(COMPACT,14,12)
static func button_style(state:String,primary:bool=false)->StyleBoxTexture:
	var box=frame(BUTTON,10,12)
	box.content_margin_top=8;box.content_margin_bottom=8
	if primary:box.modulate_color=Color("fff5d1")
	if state in ["hover","hover_pressed"]:box.modulate_color=Color("ffffff")
	if state in ["pressed","hover_pressed"]:box.modulate_color=Color("b9cdd3")
	if state=="disabled":box.modulate_color=Color(.62,.65,.65,.78)
	box.modulate_color.a*=.88
	return box
static func apply_button(button:Button,primary:bool=false):
	button.text=button.text.to_upper();button.add_theme_font_override("font",FONT);button.alignment=HORIZONTAL_ALIGNMENT_CENTER
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:button.add_theme_stylebox_override(state,button_style(state,primary))
	var focus=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=Color("f8e4a4");focus.set_border_width_all(2);focus.set_corner_radius_all(3)
	button.add_theme_stylebox_override("focus",focus)
	for key in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color"]:button.add_theme_color_override(key,INK)
	button.add_theme_color_override("font_disabled_color",Color("566068"))
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
	cached_theme=Theme.new();cached_theme.default_font_size=16;cached_theme.default_font=FONT
	cached_theme.set_color("font_color","Label",PAPER)
	cached_theme.set_stylebox("panel","PanelContainer",panel())
	for type in ["Button","OptionButton"]:
		for state in ["normal","hover","pressed","hover_pressed","disabled"]:cached_theme.set_stylebox(state,type,button_style(state))
		for key in ["font_color","font_hover_color","font_focus_color"]:cached_theme.set_color(key,type,INK)
		cached_theme.set_color("font_pressed_color",type,INK);cached_theme.set_color("font_disabled_color",type,Color("566068"))
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:cached_theme.set_stylebox(state,"CheckButton",StyleBoxEmpty.new())
	for key in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color"]:cached_theme.set_color(key,"CheckButton",PAPER)
	var focus=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=PAPER;focus.set_border_width_all(1)
	cached_theme.set_stylebox("focus","CheckButton",focus)
	cached_theme.set_stylebox("panel","PopupMenu",panel());cached_theme.set_color("font_color","PopupMenu",PAPER)
	cached_theme.set_stylebox("hover","PopupMenu",button_style("pressed"));cached_theme.set_color("font_hover_color","PopupMenu",INK)
	cached_theme.set_stylebox("panel","TooltipPanel",panel());cached_theme.set_color("font_color","TooltipLabel",PAPER)
	cached_theme.set_font_size("font_size","TooltipLabel",20)
	return cached_theme
