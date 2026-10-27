extends Control
var game
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art=TextureRect.new();art.name="GoemonTitleArt";art.texture=preload("res://assets/ui/maroon/goemon_title_illidan_blademaster.png")
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_SCALE
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(art)
	resized.connect(layout_art.bind(art));layout_art(art)
	var paper=PanelContainer.new();paper.name="TitleFrame";paper.add_theme_stylebox_override("panel",game.forest_ui.PreparationSkin.panel())
	add_child(paper);paper.anchor_left=.05;paper.anchor_right=.05;paper.anchor_top=.44;paper.anchor_bottom=.44
	paper.offset_right=320;paper.offset_bottom=244
	resized.connect(layout_frame.bind(paper));layout_frame(paper)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",14);paper.add_child(column)
	for item in [["Play",game.begin_forest,"ForestPlay"],["Settings",func():game.show_settings(false),"ForestSettings"],["Quit",game.quit_clean,"ForestQuit"]]:
		var button=game.forest_ui.make_preparation_button(item[0],item[1],280,item[0]=="Play")
		button.name=item[2];button.custom_minimum_size.y=56;button.add_theme_font_size_override("font_size",20);column.add_child(button)
func layout_art(art:TextureRect):
	# Align the cover image left so the supplied Goemon logo remains intact.
	var fit=maxf(size.x/art.texture.get_width(),size.y/art.texture.get_height())
	art.size=art.texture.get_size()*fit;art.position=Vector2(0,(size.y-art.size.y)*.5)
func layout_frame(paper:Control):
	# Keep the menu inside the artwork's clear left margin on smaller windows.
	paper.scale=Vector2.ONE*minf(1.0,size.x/1280.0)
