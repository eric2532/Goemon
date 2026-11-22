extends Button
## Picture gallery shared by the character card's existing skin catalogs.
const Roster=preload("res://scripts/rogue_roster.gd")
const PreparationSkin=preload("res://scripts/forest/preparation_skin.gd")
signal skin_selected(id:int)
var catalog:Dictionary
var character:int
var selected_id:int
var show_caption=true
var selection_is_draft=false
var gallery:PopupPanel
var choices:ItemList
var status:Label

func _ready():
	pressed.connect(open_gallery)
	get_viewport().size_changed.connect(fit_gallery)
	refresh()

func refresh():
	if catalog.is_empty():hide();return
	show()
	var label_=str(catalog.get(selected_id,["Saved appearance"])[0])
	text="Skins · "+label_ if show_caption else ""
	if not is_instance_valid(choices):return
	for i in choices.item_count:
		var id:int=choices.get_item_metadata(i)
		choices.set_item_text(i,("✓ " if id==selected_id else "")+str(catalog[id][0]).replace(" / ","\n"))
		if id==selected_id:choices.select(i)
	status.text="Unsaved" if selection_is_draft else "Equipped: "+label_+" · Selection is saved."

func select_skin(id:int):
	if not catalog.has(id):return
	selected_id=id
	skin_selected.emit(id)
	refresh()
	if is_instance_valid(gallery):gallery.hide()

func open_gallery():
	if is_instance_valid(gallery):return
	gallery=PopupPanel.new();gallery.name="SkinGallery";gallery.theme=PreparationSkin.theme()
	gallery.add_theme_stylebox_override("panel",PreparationSkin.panel())
	add_child(gallery)
	var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);gallery.add_child(column)
	var heading=HBoxContainer.new();column.add_child(heading)
	var title=Label.new();title.text=Roster.name_for(character)+" · SKINS";title.add_theme_font_size_override("font_size",24)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(title)
	var close=Button.new();close.text="Close";close.pressed.connect(gallery.hide);heading.add_child(close)
	var cancel=InputEventKey.new();cancel.keycode=KEY_ESCAPE
	close.shortcut=Shortcut.new();close.shortcut.events=[cancel]
	PreparationSkin.apply_button(close)
	choices=ItemList.new();choices.name="SkinChoices";choices.size_flags_vertical=Control.SIZE_EXPAND_FILL
	choices.max_columns=5;choices.same_column_width=true;choices.fixed_column_width=148
	choices.icon_mode=ItemList.ICON_MODE_TOP;choices.fixed_icon_size=Vector2i(120,140);choices.max_text_lines=3
	choices.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	choices.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	for state in ["selected","selected_focus","hovered_selected"]:choices.add_theme_stylebox_override(state,PreparationSkin.button_style("pressed"))
	choices.add_theme_stylebox_override("hovered",StyleBoxEmpty.new())
	choices.add_theme_color_override("font_color",PreparationSkin.PAPER)
	choices.add_theme_color_override("font_selected_color",PreparationSkin.INK)
	choices.add_theme_color_override("font_hovered_color",PreparationSkin.PAPER)
	choices.add_theme_constant_override("v_separation",12);choices.add_theme_constant_override("h_separation",8)
	choices.add_theme_font_size_override("font_size",14)
	column.add_child(choices)
	var portraits=load("res://scripts/rogue_roster_picker.gd")
	for id in catalog:
		var portrait=portraits.selection_texture(character,{Roster.skin_setting(character):id})
		var index=choices.add_item(str(catalog[id][0]),portrait)
		choices.set_item_metadata(index,id)
		choices.set_item_tooltip_enabled(index,false)
	choices.item_activated.connect(func(index):select_skin(choices.get_item_metadata(index)))
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(status)
	gallery.popup_hide.connect(func():
		gallery.queue_free();gallery=null;choices=null;status=null;grab_focus())
	refresh()
	fit_gallery()
	choices.grab_focus();choices.ensure_current_is_visible()

func fit_gallery():
	if not is_instance_valid(gallery):return
	var bounds=Vector2i(get_viewport_rect().size)-Vector2i(48,48)
	var dimensions=Vector2i(mini(850,bounds.x),mini(650,bounds.y))
	gallery.min_size=Vector2i.ZERO;gallery.max_size=dimensions;gallery.min_size=dimensions
	gallery.popup_centered(dimensions)
