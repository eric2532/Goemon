extends Control
const Document=preload("res://scripts/forest/forest_map_document.gd")
const LABELS={"tower":"Watchtower","wall":"Wall","gate":"Gate","mine":"Mine","deposit":"Gold deposit","tree":"Tree","portal":"Spawn Portal","road":"Road · paint"}
var game
var document=Document.new()
var active=false
var map_folder=Document.MAP_FOLDER
var selection: Dictionary={}
var tool=""
var placement_rotation=0
var previous_model
var previous_position=Vector3.ZERO
var previous_pan=Vector3.ZERO
var previous_size=120.0
var name_field: LineEdit
var saved_maps: OptionButton
var palette: OptionButton
var status: Label
var dirty_label: Label
var confirmation: ConfirmationDialog
var pending_action=Callable()
var undo_button: Button
var redo_button: Button
var rotate_button: Button
var delete_button: Button
var last_preview=""
var road_width=5
var road_stroke: Array=[]
var road_last_cell=Vector2i.ZERO
func _ready():
	name="ForestMapEditor";process_mode=Node.PROCESS_MODE_ALWAYS;mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var heading=Label.new();heading.text="MAP EDITOR";heading.position=Vector2(24,20);heading.add_theme_font_size_override("font_size",28);heading.add_theme_color_override("font_color",Color("f4d38b"));heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(heading)
	var note=Label.new();note.text="Original Map is protected · Base and training dummy stay fixed";note.position=Vector2(24,58);note.add_theme_font_size_override("font_size",17);note.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(note)
	var toolbar=PanelContainer.new();toolbar.name="MapEditorToolbar";add_child(toolbar);toolbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toolbar.offset_left=16;toolbar.offset_right=-16;toolbar.offset_top=-194;toolbar.offset_bottom=-16
	var box=StyleBoxFlat.new();box.bg_color=Color("162e2a");box.border_color=Color("9b946b");box.set_border_width_all(1);box.set_corner_radius_all(9)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:box.set_content_margin(side,14)
	toolbar.add_theme_stylebox_override("panel",box)
	var rows=VBoxContainer.new();rows.add_theme_constant_override("separation",9);toolbar.add_child(rows)
	var files=HBoxContainer.new();files.add_theme_constant_override("separation",8);rows.add_child(files)
	name_field=LineEdit.new();name_field.name="ForestMapName";name_field.placeholder_text="Map name";name_field.max_length=48;name_field.custom_minimum_size=Vector2(235,40);files.add_child(name_field)
	name_field.text_changed.connect(func(value):document.rename(value);refresh_controls())
	button(files,"Save",save_map,"SaveForestMap",85)
	saved_maps=OptionButton.new();saved_maps.name="SavedForestMaps";saved_maps.custom_minimum_size=Vector2(245,40);saved_maps.size_flags_horizontal=Control.SIZE_EXPAND_FILL;saved_maps.clip_text=true;saved_maps.focus_mode=Control.FOCUS_NONE;files.add_child(saved_maps)
	button(files,"Load",load_selected,"LoadForestMap",85)
	button(files,"Twin Ramparts",load_ramparts,"RampartsForestMap",145)
	button(files,"Original Map",load_original,"OriginalForestMap",145)
	dirty_label=Label.new();dirty_label.custom_minimum_size.x=120;dirty_label.add_theme_color_override("font_color",Color("edcf87"));files.add_child(dirty_label)
	var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",8);rows.add_child(actions)
	palette=OptionButton.new();palette.name="ForestMapPalette";palette.custom_minimum_size=Vector2(200,40);palette.focus_mode=Control.FOCUS_NONE;palette.add_item("Select an object")
	for kind in LABELS:palette.add_item(LABELS[kind])
	palette.item_selected.connect(func(index):choose_piece("" if index==0 else LABELS.keys()[index-1]));actions.add_child(palette)
	var width=OptionButton.new();width.name="RoadBrushWidth";width.custom_minimum_size=Vector2(140,40);width.focus_mode=Control.FOCUS_NONE
	for amount in [1,3,5]:width.add_item("Road: %d tiles"%amount)
	width.selected=2;width.tooltip_text="Five tiles clears enough room for the giant. Roads clear trees in their painted footprint."
	width.item_selected.connect(func(index):road_width=[1,3,5][index];cancel_stroke();last_preview="");actions.add_child(width)
	button(actions,"Select",choose_piece.bind(""),"SelectMapObject",85)
	rotate_button=button(actions,"Rotate · R",rotate_selected,"RotateMapObject",110)
	delete_button=button(actions,"Delete",delete_selected,"DeleteMapObject",90)
	undo_button=button(actions,"Undo",undo,"UndoMapEdit",85);redo_button=button(actions,"Redo",redo,"RedoMapEdit",85)
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(spacer)
	button(actions,"Play map",play_map,"PlayForestMap",135);button(actions,"Back",back_to_building,"ExitForestMapEditor",85)
	var help=Label.new();help.text="Click: place/select · Drag: paint roads · R: rotate · Delete: remove · Middle drag / WASD: pan · Wheel: zoom · Ctrl/Cmd+Z: undo";help.add_theme_font_size_override("font_size",15);rows.add_child(help)
	status=Label.new();status.name="MapEditorStatus";status.add_theme_font_size_override("font_size",16);status.add_theme_color_override("font_color",Color("edcf87"));status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(status)
	confirmation=ConfirmationDialog.new();confirmation.name="MapUnsavedChanges";confirmation.title="Unsaved map changes";confirmation.ok_button_text="Discard changes";add_child(confirmation)
	confirmation.confirmed.connect(func():var action=pending_action;pending_action=Callable();if action.is_valid():action.call())
	confirmation.canceled.connect(func():pending_action=Callable())
	hide()
func button(parent: Node,text: String,action: Callable,id: String,width: float)->Button:
	var result=Button.new();result.name=id;result.text=text;result.custom_minimum_size=Vector2(width,40);result.focus_mode=Control.FOCUS_NONE
	result.add_theme_font_size_override("font_size",17);result.pressed.connect(action);parent.add_child(result);return result
func open():
	if active:return
	previous_model=game.model;previous_position=game.player.position;previous_pan=game.pan;previous_size=game.preparation_size
	document.capture(previous_model)
	var selected=game.get_tree().get_meta("forest_custom_layout",{})
	if not selected.is_empty():document.data.title=selected.title;document.saved_text=document.encode()
	elif not previous_model.ramparts.is_empty():document.data.title="Twin Ramparts";document.saved_text=document.encode()
	active=true;selection={};tool="";placement_rotation=0;name_field.text=document.data.title
	show();refresh_saved_maps();refresh_document();set_status("Choose an object to place, or Select to edit existing pieces. Play map starts a fresh run.")
func refresh_saved_maps():
	saved_maps.clear()
	for item in Document.list_maps(map_folder):
		saved_maps.add_item(item.title);saved_maps.set_item_metadata(saved_maps.item_count-1,item.path)
		if item.path==document.path:saved_maps.selected=saved_maps.item_count-1
	if saved_maps.item_count==0:saved_maps.text="No saved maps yet"
func refresh_document():
	game.preview_forest_map(document.data);game.forest_ui.hide();last_preview="";refresh_controls()
func refresh_controls():
	if not is_instance_valid(dirty_label):return
	dirty_label.text="Unsaved edits" if document.dirty else "Saved / clean"
	undo_button.disabled=document.history.is_empty();redo_button.disabled=document.future.is_empty()
	delete_button.disabled=document.selected_item(selection).is_empty()
	rotate_button.disabled=(tool not in ["tower","wall","gate","mine","portal"]) if not tool.is_empty() else selection.get("group") not in ["buildings","portals"]
func set_status(text: String):status.text=text
func choose_piece(kind: String):
	name_field.release_focus()
	cancel_stroke()
	tool=kind;selection={};last_preview="";game.world.preview.hide()
	palette.selected=0 if kind.is_empty() else LABELS.keys().find(kind)+1
	if kind=="road":set_status("Drag a road from a portal toward the base. Painted ground clears trees; five tiles fits giants.")
	elif kind=="portal":set_status("Place portal · %d° · Exit arrow points toward its road. Portals replace edge arrivals."%(placement_rotation*90))
	else:set_status("Select an object to edit." if kind.is_empty() else "Place %s · Free in the editor"%LABELS[kind])
	refresh_controls()
func rotate_selected():
	if not tool.is_empty():
		if tool in ["tower","wall","gate","mine","portal"]:placement_rotation=(placement_rotation+1)%4;last_preview="";set_status("%s · %d°"%[LABELS[tool],placement_rotation*90])
		return
	var error=document.rotate(selection)
	if error.is_empty():refresh_document();show_selection()
	else:set_status(error)
func delete_selected():
	var error=document.remove(selection)
	if error.is_empty():selection={};refresh_document();set_status("Object deleted. Undo restores it.")
	else:set_status(error)
func undo():
	if not road_stroke.is_empty():cancel_stroke();return
	if document.undo():selection={};refresh_document();set_status("Edit undone.")
func redo():
	if not road_stroke.is_empty():cancel_stroke();return
	if document.redo():selection={};refresh_document();set_status("Edit restored.")
func save_map():
	if not road_stroke.is_empty():finish_stroke()
	if name_field.text.strip_edges().is_empty():set_status("Enter a map name before saving.");return
	document.rename(name_field.text)
	for item in Document.list_maps(map_folder):
		if item.title==document.data.title and item.path!=document.path:
			pending_action=write_map;confirmation.title="Replace saved map?";confirmation.ok_button_text="Replace saved map"
			confirmation.dialog_text="A saved map named “%s” already exists. Replace that file?"%document.data.title
			confirmation.popup_centered(Vector2i(500,160));return
	write_map()
func write_map():
	var error=document.save(map_folder)
	if error.is_empty():refresh_saved_maps();set_status("Saved “%s”. Custom maps survive app rebuilds and relaunches."%document.data.title)
	else:set_status(error)
	refresh_controls()
func request_replace(action: Callable):
	if document.dirty:
		pending_action=action;confirmation.title="Unsaved map changes";confirmation.ok_button_text="Discard changes"
		confirmation.dialog_text="Discard unsaved map edits? Cancel and use Save first if you want to keep them.";confirmation.popup_centered(Vector2i(500,160))
	else:action.call()
func load_selected():
	if saved_maps.selected<0:return
	var path=saved_maps.get_item_metadata(saved_maps.selected)
	request_replace(func():
		var error=document.read_file(path)
		if not error.is_empty():set_status(error);return
		name_field.text=document.data.title;choose_piece("");refresh_document();set_status("Loaded “%s”."%document.data.title))
func load_original():
	request_replace(func():
		var error=document.load_original()
		if not error.is_empty():set_status(error);return
		name_field.text=document.data.title;choose_piece("");refresh_document();game.pan=Vector3.ZERO;game.preparation_size=120;game.update_preparation_camera();set_status("Original Map restored. Save any edits as a separate custom map."))
func load_ramparts():
	request_replace(func():
		var error=document.load_ramparts()
		if not error.is_empty():set_status(error);return
		name_field.text=document.data.title;choose_piece("");refresh_document()
		game.pan=Vector3(0,0,100);game.preparation_size=340;game.update_preparation_camera()
		set_status("Twin Ramparts loaded · Two raised wall routes and spawn portals. Original Map is still available."))
func back_to_building():request_replace(close_discard)
func close_discard():
	active=false;hide();confirmation.hide();game.model=previous_model;previous_model=null
	game.world.model=game.model;game.world.reload_map();game.player.position=previous_position;game.set_phase_view();game.pan=previous_pan;game.preparation_size=previous_size;game.update_preparation_camera();game.forest_ui.show()
func play_map():
	var error=document.play_error()
	if not error.is_empty():set_status(error);return
	game.get_tree().set_meta("forest_custom_layout",document.data.duplicate(true))
	active=false;hide();previous_model=null;game.player.position=Vector3(0,.15,18)
	game.preview_forest_map(document.data,false);game.forest_ui.show();game.toast("%s · Fresh run ready. Start a wave when ready."%document.data.title)
func text_focused()->bool:return get_viewport().gui_get_focus_owner() is LineEdit
func global_input(event):
	if confirmation.visible:return
	if not road_stroke.is_empty() and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		finish_stroke();get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo and (event.ctrl_pressed or event.meta_pressed):
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_S:save_map();get_viewport().set_input_as_handled()
		elif code==KEY_Z and not text_focused():
			if event.shift_pressed:redo()
			else:undo()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("pause") and not event.is_echo():
		if not road_stroke.is_empty():cancel_stroke()
		elif not tool.is_empty():choose_piece("")
		else:back_to_building()
		get_viewport().set_input_as_handled()
func handle_input(event):
	if confirmation.visible:return
	if text_focused():
		if event is InputEventMouseButton and event.pressed:name_field.release_focus()
		elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_MIDDLE:name_field.release_focus()
		else:return
	if event is InputEventKey and event.pressed and not event.echo:
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_R:rotate_selected()
		elif code==KEY_DELETE or code==KEY_BACKSPACE:delete_selected()
		else:return
		get_viewport().set_input_as_handled();return
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_MIDDLE:
		game.pan+=Vector3(-event.relative.x,0,-event.relative.y)*game.preparation_size/700.0;game.update_preparation_camera()
	if not road_stroke.is_empty() and event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		extend_stroke(game.model.cell_of(game.ground_at(event.position)));get_viewport().set_input_as_handled();return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:game.preparation_size=clampf(game.preparation_size-12,60,600);game.update_preparation_camera()
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:game.preparation_size=clampf(game.preparation_size+12,60,600);game.update_preparation_camera()
		elif event.button_index==MOUSE_BUTTON_RIGHT:choose_piece("")
		elif event.button_index==MOUSE_BUTTON_LEFT:
			var cell=game.model.cell_of(game.ground_at(event.position))
			if tool=="road":road_stroke=[cell];road_last_cell=cell;extend_stroke(cell)
			elif tool.is_empty():selection=document.object_at(cell);show_selection();refresh_controls()
			else:
				var error=document.place(tool,cell,placement_rotation)
				if error.is_empty():refresh_document();set_status("%s placed. Click to place another."%LABELS[tool])
				else:set_status(error)
		get_viewport().set_input_as_handled()
func extend_stroke(cell: Vector2i):
	if cell.x< -39 or cell.x>39 or cell.y< -39 or cell.y>39:return
	var previous: Vector2i=road_last_cell
	while previous!=cell:
		if previous.x!=cell.x:previous.x+=signi(cell.x-previous.x)
		else:previous.y+=signi(cell.y-previous.y)
		if previous not in road_stroke:road_stroke.append(previous)
	road_last_cell=cell
	var error=document.road_error(road_stroke,road_width)
	game.world.show_road_preview(road_stroke,road_width,error.is_empty());last_preview=""
func finish_stroke():
	var error=document.paint_road(road_stroke,road_width);road_stroke=[]
	if error.is_empty():refresh_document();set_status("Road painted. One Undo restores the stroke and cleared trees.")
	else:game.world.preview.hide();set_status(error)
func cancel_stroke():
	road_stroke=[];last_preview=""
	if is_instance_valid(game.world):game.world.preview.hide()
func show_selection():
	var item=document.selected_item(selection)
	if item.is_empty():game.world.preview.hide();set_status("The base is protected." if selection.get("group")=="shrine" else "Select a structure, tree or gold deposit.");return
	var dimensions=Vector2i.ONE
	if selection.group=="buildings":dimensions=game.model.dimensions(item.kind,int(item.rotation),int(item.get("span",0)))
	elif selection.group=="deposits":dimensions=Vector2i(3,2)
	var cell=Vector2i(item.x,item.z)
	if selection.group=="portals":cell-=Vector2i(2,2);dimensions=Vector2i(5,5)
	game.world.show_editor_marker(cell,dimensions,true,true)
	set_status("Selected %s · R rotates structures/portals · Delete removes · Undo restores"%item.get("kind",selection.group))
func tick(delta: float):
	if not confirmation.visible and not text_focused():
		var move=Input.get_vector("move_left","move_right","move_forward","move_back")
		game.pan+=Vector3(move.x,0,move.y)*delta*game.preparation_size*.7
		game.pan.x=clampf(game.pan.x,-235,235);game.pan.z=clampf(game.pan.z,-235,235);game.update_preparation_camera()
	if tool.is_empty() or confirmation.visible or not road_stroke.is_empty():return
	var cell=game.model.cell_of(game.ground_at(get_viewport().get_mouse_position()));var key="%s:%s:%d"%[tool,cell,placement_rotation]
	if key==last_preview:return
	last_preview=key
	var error=document.road_error([cell],road_width) if tool=="road" else document.placement_error(tool,cell,placement_rotation)
	if tool=="road":game.world.show_road_preview([cell],road_width,error.is_empty())
	elif tool=="portal":game.world.show_portal_preview(cell,placement_rotation,error.is_empty())
	elif tool in ["tree","deposit"]:game.world.show_editor_marker(cell,Vector2i(3,2) if tool=="deposit" else Vector2i.ONE,error.is_empty())
	else:game.world.show_preview(tool,cell,placement_rotation,error.is_empty())
