extends Control
const Document=preload("res://scripts/forest/forest_map_document.gd")
var game
func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art=TextureRect.new();art.name="GoemonTitleArt";art.texture=preload("res://assets/ui/maroon/blue_cross_gate_title_roster.png")
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var heading=Label.new();heading.name="GoemonTitleHeading";heading.text="Cross Gate"
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
	heading.add_theme_font_size_override("font_size",58);heading.add_theme_constant_override("outline_size",8)
	add_child(heading);heading.anchor_left=.05;heading.anchor_right=.05;heading.anchor_top=.44;heading.anchor_bottom=.44
	heading.offset_right=320;heading.offset_top=-84;heading.offset_bottom=-10
	var paper=PanelContainer.new();paper.name="TitleFrame";paper.add_theme_stylebox_override("panel",game.forest_ui.PreparationSkin.panel())
	add_child(paper);paper.anchor_left=.05;paper.anchor_right=.05;paper.anchor_top=.44;paper.anchor_bottom=.44
	paper.offset_right=320
	var web=OS.has_feature("web")
	var falan_path=Document.WEB_FALAN_PATH if web else Document.MAP_FOLDER.path_join(Document.saved_filename("Freyja and Falan - Test"))
	var has_falan=FileAccess.file_exists(falan_path)
	paper.offset_bottom=244 if web or not has_falan else 314
	var resize_menu=func():
		# Keep the menu inside the artwork's clear left margin on smaller windows.
		paper.scale=Vector2.ONE*minf(1.0,size.x/1280.0)
		heading.scale=paper.scale
	resized.connect(resize_menu);resize_menu.call()
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",14);paper.add_child(column)
	var items=[]
	if not web:items.append(["Arena · Slime Waves",game.begin_arena,"ForestPlay"])
	if web:
		var joining:bool=not game.web_coop.join_code().is_empty()
		items.append(["Join Co-op" if joining else "Freyja and Falan",game.web_coop.begin if joining else game.begin_saved_falan.bind(falan_path),"ForestPlay"])
		items.append(["Play Solo" if joining else "Host Co-op",game.begin_saved_falan.bind(falan_path) if joining else game.web_coop.begin,"ForestCoop"])
	elif has_falan:items.append(["Freyja and Falan",game.begin_saved_falan.bind(falan_path),"ForestFalan"])
	items.append(["Settings",func():game.show_settings(false),"ForestSettings"])
	if not web:items.append(["Quit",game.quit_clean,"ForestQuit"])
	for item in items:
		var button=game.forest_ui.make_preparation_button(item[0],item[1],280,item[2]=="ForestPlay")
		button.name=item[2];button.custom_minimum_size.y=56;button.add_theme_font_size_override("font_size",20);column.add_child(button)
