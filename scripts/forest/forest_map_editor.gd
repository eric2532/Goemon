extends Control
const Document=preload("res://scripts/forest/forest_map_document.gd")
const LABELS={"tower":"Guard Tower","cannon_tower":"Cannon Tower","barracks":"Farm","wall":"Wall","gate":"Gate","tree":"Tree","rock":"Mossy Rock","portal":"Spawn Portal","road":"Road · paint"}
const GRID_LABELS={"tower":"Tower","cannon_tower":"Cannon","rock":"Rock","portal":"Portal","road":"Road","platform_18":"Plat18","causeway_36":"Span36","ramp_6":"Ramp+6","ramp_12":"Ramp12","platform_30":"Plat30","corner_18":"Corner","t_junction_18":"T Join"}
var game
var document=Document.new(false)
var active=false
var map_folder=Document.MAP_FOLDER
var selection: Dictionary={}
var tool=""
var placement_rotation=0
var scenery_rotation=0.0
var placement_scale=1.0
var size_field:SpinBox
var rotation_field:SpinBox
var height_field:SpinBox
var placement_height=0.0
var picked_anchor=null
var picked_terrain=-1
var terrain_cell=Vector2.ZERO
var terrain_height=0.0
var terrain_auto_height=true
var terrain_ground
var previous_model
var preview_layout:Dictionary={}
var previous_position=Vector3.ZERO
var previous_pan=Vector3.ZERO
var previous_size=120.0
var name_field: LineEdit
var saved_maps: OptionButton
var palette_kinds:Array=LABELS.keys()+Document.Scenery.CATALOG.keys()+Document.Kit.LABELS.keys()
var palette_page=0
var palette_buttons:Array[Button]=[]
var palette_page_label:Label
var palette_previous:Button
var palette_next:Button
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
	theme=preload("res://scripts/forest/preparation_skin.gd").theme()
	name="ForestMapEditor";process_mode=Node.PROCESS_MODE_ALWAYS;mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var heading=Label.new();heading.text="MAP EDITOR";heading.position=Vector2(24,20);heading.add_theme_font_size_override("font_size",28);heading.add_theme_color_override("font_color",Color("f4d38b"));heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(heading)
	var note=Label.new();note.text="Falan Arena · Four-sided survival";note.position=Vector2(24,58);note.add_theme_font_size_override("font_size",17);note.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(note)
	var palette_panel=PanelContainer.new();palette_panel.name="MapAssetPalette";add_child(palette_panel);palette_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	palette_panel.offset_left=-430;palette_panel.offset_right=-16;palette_panel.offset_top=16;palette_panel.offset_bottom=240
	var palette_style=StyleBoxFlat.new();palette_style.bg_color=Color(.145,.204,.235,.66);palette_style.set_corner_radius_all(9)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:palette_style.set_content_margin(side,10)
	palette_panel.add_theme_stylebox_override("panel",palette_style)
	var palette_rows=VBoxContainer.new();palette_rows.add_theme_constant_override("separation",6);palette_panel.add_child(palette_rows)
	var palette_title=Label.new();palette_title.text="BUILD · 1–9";palette_rows.add_child(palette_title)
	var grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",5);grid.add_theme_constant_override("v_separation",5);palette_rows.add_child(grid)
	for slot in 9:
		var item=button(grid,"",choose_palette_slot.bind(slot),"MapAssetSlot%d"%(slot+1),124);item.add_theme_font_size_override("font_size",16);item.toggle_mode=true;palette_buttons.append(item)
	var pages=HBoxContainer.new();pages.add_theme_constant_override("separation",6);palette_rows.add_child(pages)
	palette_previous=button(pages,"Prev [",change_palette_page.bind(-1),"PreviousAssetPage",95)
	palette_page_label=Label.new();palette_page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;palette_page_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;pages.add_child(palette_page_label)
	palette_next=button(pages,"Next ]",change_palette_page.bind(1),"NextAssetPage",95)
	palette_previous.tooltip_text="Previous asset page · [ or Page Up";palette_next.tooltip_text="Next asset page · ] or Page Down"
	var toolbar=PanelContainer.new();toolbar.name="MapEditorToolbar";add_child(toolbar);toolbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toolbar.offset_left=16;toolbar.offset_right=-16;toolbar.offset_top=-292;toolbar.offset_bottom=-16
	var box=StyleBoxFlat.new();box.bg_color=Color(.145,.204,.235,.66);box.border_color=Color("e5ddbf");box.set_border_width_all(1);box.set_corner_radius_all(9)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:box.set_content_margin(side,14)
	toolbar.add_theme_stylebox_override("panel",box)
	var rows=VBoxContainer.new();rows.add_theme_constant_override("separation",9);toolbar.add_child(rows)
	var files=HBoxContainer.new();files.add_theme_constant_override("separation",8);rows.add_child(files)
	name_field=LineEdit.new();name_field.name="ForestMapName";name_field.placeholder_text="Map name";name_field.max_length=48;name_field.custom_minimum_size=Vector2(235,40);files.add_child(name_field)
	name_field.text_changed.connect(func(value):document.rename(value);refresh_controls())
	button(files,"Save",save_map,"SaveForestMap",85)
	saved_maps=OptionButton.new();saved_maps.name="SavedForestMaps";saved_maps.custom_minimum_size=Vector2(245,40);saved_maps.size_flags_horizontal=Control.SIZE_EXPAND_FILL;saved_maps.clip_text=true;saved_maps.focus_mode=Control.FOCUS_NONE;files.add_child(saved_maps)
	button(files,"Load",load_selected,"LoadForestMap",85)
	dirty_label=Label.new();dirty_label.custom_minimum_size.x=120;dirty_label.add_theme_color_override("font_color",Color("edcf87"));files.add_child(dirty_label)
	var presets=HBoxContainer.new();presets.add_theme_constant_override("separation",8);rows.add_child(presets)
	button(presets,"Falan Arena",load_wind_meadow,"WindMeadowForestMap",165)
	var properties=HBoxContainer.new();properties.add_theme_constant_override("separation",8);rows.add_child(properties)
	var size_label=Label.new();size_label.text="Scenery size";properties.add_child(size_label)
	size_field=SpinBox.new();size_field.name="ScenerySize";size_field.min_value=Document.Scenery.MIN_SCALE;size_field.max_value=Document.Scenery.MAX_SCALE;size_field.step=.1;size_field.value=1;size_field.suffix="×";size_field.custom_minimum_size=Vector2(120,40);properties.add_child(size_field)
	var rotation_label=Label.new();rotation_label.text="Rotation";properties.add_child(rotation_label)
	rotation_field=SpinBox.new();rotation_field.name="SceneryRotation";rotation_field.min_value=0;rotation_field.max_value=359;rotation_field.step=1;rotation_field.suffix="°";rotation_field.custom_minimum_size=Vector2(120,40);properties.add_child(rotation_field)
	var height_label=Label.new();height_label.text="Height";properties.add_child(height_label)
	height_field=SpinBox.new();height_field.name="SceneryHeight";height_field.max_value=Document.Scenery.MAX_HEIGHT;height_field.step=.1;height_field.suffix="m";height_field.custom_minimum_size=Vector2(110,40);height_field.tooltip_text="Height above terrain. Placement automatically stacks on the surface you click; select a piece to edit its height.";properties.add_child(height_field)
	size_field.value_changed.connect(func(_value):change_scenery())
	rotation_field.value_changed.connect(func(_value):change_scenery())
	height_field.value_changed.connect(func(_value):
		if Document.Kit.is_module(tool):terrain_auto_height=false
		change_scenery())
	var hint=Label.new();hint.text="Click a piece to stack";hint.add_theme_font_size_override("font_size",15);properties.add_child(hint)
	var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",8);rows.add_child(actions)
	var map_size=OptionButton.new();map_size.name="ForestMapSize";map_size.custom_minimum_size=Vector2(150,40);map_size.focus_mode=Control.FOCUS_NONE
	map_size.add_item("New preset…");map_size.add_item("Standard Meadow");map_size.add_item("Large Meadow · 2.25×")
	map_size.tooltip_text="Load a fresh layout. Resize your current map with Bigger / Smaller on the main map page."
	map_size.item_selected.connect(func(index):
		map_size.selected=0
		if index==1:load_wind_meadow()
		elif index==2:load_wind_meadow_large())
	presets.add_child(map_size)
	var width=OptionButton.new();width.name="RoadBrushWidth";width.custom_minimum_size=Vector2(140,40);width.focus_mode=Control.FOCUS_NONE
	for amount in [1,3,5]:width.add_item("Road: %d tiles"%amount)
	width.selected=2;width.tooltip_text="Roads clear trees in their painted footprint."
	width.item_selected.connect(func(index):road_width=[1,3,5][index];cancel_stroke();last_preview="");presets.add_child(width)
	button(actions,"Select",choose_piece.bind(""),"SelectMapObject",85)
	rotate_button=button(actions,"Rotate · R",rotate_selected,"RotateMapObject",110)
	delete_button=button(actions,"Delete",delete_selected,"DeleteMapObject",90)
	undo_button=button(actions,"Undo",undo,"UndoMapEdit",85);redo_button=button(actions,"Redo",redo,"RedoMapEdit",85)
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(spacer)
	button(actions,"Play map",play_map,"PlayForestMap",135);button(actions,"Back",back_to_building,"ExitForestMapEditor",85)
	var help=Label.new();help.text="1–9: build tool · [ / ]: asset pages · Click: place/select · R: rotate · Delete: remove · Middle drag / WASD: pan · Wheel / pinch / + −: zoom · Ctrl/Cmd+Z: undo";help.add_theme_font_size_override("font_size",15);help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(help)
	status=Label.new();status.name="MapEditorStatus";status.add_theme_font_size_override("font_size",16);status.add_theme_color_override("font_color",Color("edcf87"));status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;rows.add_child(status)
	confirmation=ConfirmationDialog.new();confirmation.name="MapUnsavedChanges";confirmation.title="Unsaved map changes";confirmation.ok_button_text="Discard changes";add_child(confirmation)
	confirmation.confirmed.connect(func():var action=pending_action;pending_action=Callable();if action.is_valid():action.call())
	confirmation.canceled.connect(func():pending_action=Callable())
	# Prepare the palette once so the first cursor preview does not load a GLB.
	for kind in palette_kinds:
		if Document.Scenery.is_piece(kind):preload("res://scripts/forest/forest_wind_meadow_assets.gd").source(Document.Scenery.asset(kind))
		elif Document.Kit.is_module(kind):Document.Kit.scene(kind)
	refresh_palette();hide()
func piece_label(kind:String)->String:return Document.Kit.LABELS[kind] if Document.Kit.is_module(kind) else LABELS[kind] if LABELS.has(kind) else Document.Scenery.CATALOG[kind].label
func grid_label(kind:String)->String:return GRID_LABELS.get(kind,piece_label(kind)) if Document.Kit.is_module(kind) else GRID_LABELS.get(kind,LABELS[kind]) if LABELS.has(kind) else Document.Scenery.CATALOG[kind].short
func refresh_palette():
	var pages=maxi(1,ceili(palette_kinds.size()/9.0));palette_page=clampi(palette_page,0,pages-1)
	palette_page_label.text="%d / %d"%[palette_page+1,pages]
	palette_previous.disabled=palette_page==0;palette_next.disabled=palette_page==pages-1
	for slot in 9:
		var index=palette_page*9+slot;var item=palette_buttons[slot]
		item.disabled=index>=palette_kinds.size()
		item.text="%d · %s"%[slot+1,grid_label(palette_kinds[index])] if not item.disabled else "%d · —"%(slot+1)
		item.text=item.text.to_upper()
		item.tooltip_text="%d · %s"%[slot+1,piece_label(palette_kinds[index])] if not item.disabled else "Empty slot"
		item.set_pressed_no_signal(not item.disabled and palette_kinds[index]==tool)
func choose_palette_slot(slot:int):
	var index=palette_page*9+slot
	if slot>=0 and slot<9 and index<palette_kinds.size():choose_piece(palette_kinds[index])
func change_palette_page(direction:int):
	var next=clampi(palette_page+direction,0,maxi(0,ceili(palette_kinds.size()/9.0)-1))
	if next==palette_page:return
	palette_page=next;choose_piece("");set_status("Asset page %d · Press 1–9 or click a piece."%(palette_page+1))
func button(parent: Node,text: String,action: Callable,id: String,width: float)->Button:
	var result=Button.new();result.name=id;result.text=text;result.custom_minimum_size=Vector2(width,40);result.focus_mode=Control.FOCUS_NONE
	preload("res://scripts/forest/preparation_skin.gd").apply_button(result);result.add_theme_font_size_override("font_size",17);result.pressed.connect(action);parent.add_child(result);return result
func open():
	if active:return
	previous_model=game.model;previous_position=game.player.position;previous_pan=game.pan;previous_size=game.preparation_size
	document.capture(previous_model)
	var selected=game.get_tree().get_meta("forest_custom_layout",{})
	if not selected.is_empty():document.data.title=selected.title;document.saved_text=document.encode()
	elif previous_model.terrain_source=="wind_meadow":document.data.title=("Falan Arena" if previous_model.terrain_detail==Document.Model.Arena.ID else "Wind Meadow Valley");document.saved_text=document.encode()
	elif previous_model.terrain_source=="blood_gulch":document.data.title="Blood Gulch Castle";document.saved_text=document.encode()
	elif previous_model.terrain_source=="kai_highway":document.data.title="Kai Highway Castle";document.saved_text=document.encode()
	elif not previous_model.ramparts.is_empty():document.data.title="Four Gates" if previous_model.portals.size()==8 else "Twin Ramparts";document.saved_text=document.encode()
	preview_layout={};active=true;selection={};tool="";placement_rotation=0;scenery_rotation=0;placement_scale=1;name_field.text=document.data.title
	show();refresh_saved_maps();refresh_document(false,true);set_status("Choose an object to place, or Select to edit existing pieces. Play map starts a fresh run.")
func refresh_saved_maps():
	saved_maps.clear()
	for item in Document.list_maps(map_folder):
		saved_maps.add_item(item.title);saved_maps.set_item_metadata(saved_maps.item_count-1,item.path)
		if item.path==document.path:saved_maps.selected=saved_maps.item_count-1
	if saved_maps.item_count==0:saved_maps.text="No saved maps yet"
func refresh_document(scenery_only:bool=false,reuse_world:bool=false):
	var terrain_changed=false
	if not preview_layout.is_empty():
		scenery_only=true
		for key in ["terrain_source","terrain_detail","falan_area","terrain_scale","map_expansion","raised_castle","deposits","portals","roads"]:
			if preview_layout.get(key)!=document.data.get(key):scenery_only=false;break
		terrain_changed=preview_layout.get("ramparts")!=document.data.get("ramparts")
		if terrain_changed and game.model.terrain_source!="wind_meadow":scenery_only=false
	if scenery_only:
		var occupied=game.model.occupancy.duplicate();var regions=[]
		if terrain_changed:regions=game.model.update_editor_terrain(document.data)
		if preview_layout.get("buildings")!=document.data.get("buildings"):
			game.model.update_scenery(document.data);game.model.update_editor_buildings(document.data)
			game.world.sync(0)
		else:game.model.update_scenery(document.data)
		if terrain_changed:game.world.reload_terrain_routes()
		preload("res://scripts/forest/forest_wind_meadow_art.gd").refresh_foliage(game.world,occupied,regions)
		game.world.reload_scenery()
	else:game.preview_forest_map(document.data,true,reuse_world)
	preview_layout=document.data
	document.cache_preview(game.model)
	game.forest_ui.hide();last_preview="";refresh_controls()
func refresh_controls(check_dirty:bool=true):
	if not is_instance_valid(dirty_label):return
	if check_dirty:dirty_label.text="Unsaved edits" if document.dirty else "Saved / clean"
	undo_button.disabled=document.history.is_empty();redo_button.disabled=document.future.is_empty()
	delete_button.disabled=document.selected_item(selection).is_empty()
	rotate_button.disabled=(tool not in ["tower","cannon_tower","wall","gate","mine","barracks","portal"] and not Document.Scenery.is_piece(tool) and not Document.Kit.is_module(tool)) if not tool.is_empty() else selection.get("group") not in ["buildings","portals","trees","rocks","props","ramparts"]
	var scenery=Document.Scenery.is_piece(tool) or (tool.is_empty() and selection.get("group") in Document.Scenery.GROUPS)
	var terrain=Document.Kit.is_module(tool) or (tool.is_empty() and selection.get("group")=="ramparts")
	size_field.editable=scenery;rotation_field.editable=scenery or terrain
	rotation_field.set_block_signals(true);rotation_field.step=90 if terrain else 1;rotation_field.max_value=270 if terrain else 359;rotation_field.set_block_signals(false)
	height_field.editable=terrain or (scenery and tool.is_empty())
	var item=document.selected_item(selection)
	size_field.set_value_no_signal(item.scale if scenery and tool.is_empty() else placement_scale)
	rotation_field.set_value_no_signal(Document.scenery_rotation(selection.group,item) if scenery and tool.is_empty() else scenery_rotation)
	height_field.set_value_no_signal(float(item.get("height",0)) if scenery and tool.is_empty() else placement_height)
	if terrain:
		rotation_field.set_value_no_signal(int(item.rotation)*90 if tool.is_empty() else placement_rotation*90)
		height_field.set_value_no_signal(float(item.height) if tool.is_empty() else terrain_height)
		height_field.tooltip_text="Terrain base elevation in metres. Follows the ground until edited. T rotates 90 degrees."
	else:height_field.tooltip_text="Height above terrain. Placement stacks on the surface you click; select a piece to edit its height."
	refresh_palette()
func change_scenery():
	if Document.Kit.is_module(tool):
		placement_rotation=posmod(roundi(rotation_field.value/90),4);terrain_height=height_field.value;last_preview="";refresh_controls(false);return
	if tool.is_empty() and selection.get("group")=="ramparts":
		var terrain_error=document.transform_terrain(selection,posmod(roundi(rotation_field.value/90),4),height_field.value)
		if terrain_error.is_empty():refresh_document();show_selection()
		else:refresh_controls();set_status(terrain_error)
		return
	if Document.Scenery.is_piece(tool):
		placement_scale=size_field.value;scenery_rotation=rotation_field.value;last_preview=""
		set_status("Place %s · %.1f× · %d°"%[piece_label(tool),placement_scale,scenery_rotation]);return
	var error=document.transform_scenery(selection,size_field.value,rotation_field.value,height_field.value)
	if error.is_empty():refresh_document(true);show_selection()
	else:refresh_controls();set_status(error)
func set_status(text: String):status.text=text
func choose_piece(kind: String):
	if not kind.is_empty() and kind not in palette_kinds:return
	for field in [name_field,size_field.get_line_edit(),rotation_field.get_line_edit(),height_field.get_line_edit()]:field.release_focus()
	cancel_stroke()
	tool=kind;selection={};last_preview="";game.world.preview.hide()
	if Document.Kit.is_module(kind):
		terrain_auto_height=true
		terrain_ground=Document.Model.create_terrain(game.model.terrain_source,game.model.terrain_scale,game.model.map_expansion,game.model.raised_castle,game.model.terrain_detail,game.model.falan_area);terrain_ground.configure([])
	if not kind.is_empty() and kind not in palette_kinds.slice(palette_page*9,palette_page*9+9):palette_page=palette_kinds.find(kind)/9
	if Document.Kit.is_module(kind):set_status("Place %s · R turns 90° · 3m snap · Height sets the base elevation"%piece_label(kind))
	elif Document.Scenery.is_piece(kind):set_status("Place %s · Click a piece to stack · Select edits Size, Rotation and Height"%piece_label(kind))
	elif kind=="wall":set_status("Place gameplay wall · Use Wall Piece / Stone Block on scenery pages for stacked walls.")
	elif kind=="road":set_status("Drag a road from a portal toward the base. Painted ground clears trees; five tiles fits giants.")
	elif kind=="portal":set_status("Place portal · %d° · Exit arrow points toward its road. Portals replace edge arrivals."%(placement_rotation*90))
	else:set_status("Select an object to edit." if kind.is_empty() else "Place %s · Free in the editor"%piece_label(kind))
	refresh_controls(false)
func rotate_selected():
	if not tool.is_empty():
		if Document.Kit.is_module(tool):placement_rotation=(placement_rotation+1)%4;last_preview="";refresh_controls(false);return
		if Document.Scenery.is_piece(tool):
			scenery_rotation=fposmod(scenery_rotation+Document.Scenery.TURN,360);last_preview="";refresh_controls(false);set_status("Place %s · %.1f× · %d°"%[piece_label(tool),placement_scale,scenery_rotation]);return
		if tool in ["tower","cannon_tower","wall","gate","mine","barracks","portal"]:placement_rotation=(placement_rotation+1)%4;last_preview="";set_status("%s · %d°"%[piece_label(tool),placement_rotation*90])
		return
	var error=document.rotate(selection)
	if error.is_empty():refresh_document(selection.get("group") in Document.Scenery.GROUPS);show_selection()
	else:set_status(error)
func delete_selected():
	var error=document.remove(selection)
	if error.is_empty():
		var scenery=selection.get("group") in Document.Scenery.GROUPS
		selection={};refresh_document(scenery);set_status("Object deleted. Undo restores it.")
	else:set_status(error)
func undo():
	if not road_stroke.is_empty():cancel_stroke();return
	if document.undo():selection={};refresh_document();set_status("Edit undone.")
func redo():
	if not road_stroke.is_empty():cancel_stroke();return
	if document.redo():selection={};refresh_document();set_status("Edit restored.")
func commit_scenery_field():
	for field in [size_field,rotation_field,height_field]:
		if field.get_line_edit().has_focus():field.apply();return
func save_map():
	commit_scenery_field()
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
func load_wind_meadow_large():
	request_replace(func():
		var error=document.load_wind_meadow_large()
		if not error.is_empty():set_status(error);return
		name_field.text=document.data.title;choose_piece("");refresh_document()
		var frame=game.preparation_map_frame();game.pan=frame.pan;game.preparation_size=frame.size;game.update_preparation_camera()
		set_status("Large Falan Arena · 2.25× the area · Play map starts a fresh run. Save to keep a custom layout; Back restores your current run."))
func load_wind_meadow():
	request_replace(func():
		var error=document.load_wind_meadow()
		if not error.is_empty():set_status(error);return
		name_field.text=document.data.title;choose_piece("");refresh_document()
		var frame=game.preparation_map_frame();game.pan=frame.pan;game.preparation_size=frame.size;game.update_preparation_camera()
		set_status("Falan Arena loaded · Survive enemies arriving from four sides."))
func back_to_building():request_replace(close_discard)
func close_discard():
	var preview=game.model;var reuse=game.world.can_reuse_map(previous_model)
	active=false;hide();confirmation.hide();game.model=previous_model;previous_model=null
	game.world.model=game.model
	if reuse:game.world.reload_preview(preview)
	else:game.world.reload_map()
	game.player.team_progression=game.model.team_progression
	game.player.position=previous_position;game.set_phase_view();game.pan=previous_pan;game.preparation_size=previous_size;game.update_preparation_camera();game.forest_ui.show()
func play_map():
	commit_scenery_field()
	var error=document.play_error()
	if not error.is_empty():set_status(error);return
	var layout=document.data.duplicate(true)
	var tree=get_tree()
	tree.set_meta("forest_custom_layout",layout)
	if layout.has("falan_areas"):tree.set_meta("falan_venture",layout)
	else:tree.remove_meta("falan_venture")
	active=false;hide();previous_model=null;game.player.position=Vector3(0,.15,18)
	game.preview_forest_map(document.data,false);game.forest_ui.show();game.toast("%s · Fresh run ready. Start a wave when ready."%document.data.title)
func text_focused()->bool:return get_viewport().gui_get_focus_owner() is LineEdit
func map_cell(screen:Vector2,pick_scenery:bool=false)->Vector2i:
	placement_height=0;picked_anchor=null;picked_terrain=-1
	var camera=game.camera_rig.camera;var origin=camera.project_ray_origin(screen);var direction=camera.project_ray_normal(screen)
	var query=PhysicsRayQueryParameters3D.create(origin,origin+direction*2000,1)
	var excluded:Array[RID]=[]
	while true:
		var hit=game.world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():break
		var body=hit.collider
		var authored:Vector3=hit.position/game.model.falan_scale
		if pick_scenery and body.has_meta("map_terrain_index"):
			picked_terrain=int(body.get_meta("map_terrain_index"));return game.model.cell_of(authored)
		if Document.Kit.is_module(tool) and body is StaticBody3D and game.world.is_ancestor_of(body):
			terrain_cell=(Vector2(authored.x,authored.z)/3).round()*.5
			if terrain_auto_height:terrain_height=maxf(0,terrain_ground.height(terrain_cell.x*6,terrain_cell.y*6))
			return game.model.cell_of(authored)
		if body.has_meta("map_scenery_cell") and (pick_scenery or Document.Scenery.is_piece(tool)):
			picked_anchor=body.get_meta("map_scenery_cell");var cell=Document.Scenery.cell(picked_anchor)
			placement_height=maxf(0,game.model.scenery_obstacles[picked_anchor].end.y-game.model.point(cell).y)
			return cell
		if body.has_meta("halo_ground_model") or body.get_meta("forest_terrain",false):return game.model.cell_of(authored)
		if Document.Scenery.is_piece(tool) and body is StaticBody3D and game.world.is_ancestor_of(body):
			var cell=game.model.cell_of(authored)
			placement_height=maxf(0,authored.y-game.model.point(cell).y)
			var building:Dictionary=game.model.buildings.get(game.model.occupancy.get(cell,-1),{})
			if not building.is_empty():placement_height=maxf(placement_height,game.model.center(building).y+preload("res://scripts/forest/forest_structure_profile.gd").height(building.kind)-game.model.point(cell).y)
			return cell
		# Placement follows terrain; a tall roof must not shift the clicked grid cell.
		excluded.append(hit.rid);query.exclude=excluded
	return game.model.cell_of((origin+direction*(-origin.y/direction.y))/game.model.falan_scale) if absf(direction.y)>.001 else Vector2i.ZERO
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
		if event is InputEventMouseButton and event.pressed:get_viewport().gui_get_focus_owner().release_focus()
		elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_MIDDLE:get_viewport().gui_get_focus_owner().release_focus()
		else:return
	if game._preparation_zoom_input(event,true):get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo:
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if event.ctrl_pressed or event.meta_pressed or event.alt_pressed:return
		if code>=KEY_1 and code<=KEY_9:choose_palette_slot(code-KEY_1)
		elif code>=KEY_KP_1 and code<=KEY_KP_9:choose_palette_slot(code-KEY_KP_1)
		elif code in [KEY_BRACKETLEFT,KEY_PAGEUP]:change_palette_page(-1)
		elif code in [KEY_BRACKETRIGHT,KEY_PAGEDOWN]:change_palette_page(1)
		elif code==KEY_T:rotate_selected()
		elif code==KEY_DELETE or code==KEY_BACKSPACE:delete_selected()
		else:return
		get_viewport().set_input_as_handled();return
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_MIDDLE:
		game.pan+=game.preparation_pan_direction(-event.relative)*game.preparation_size/700.0;game.clamp_preparation_pan();game.update_preparation_camera()
	if not road_stroke.is_empty() and event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		extend_stroke(map_cell(event.position));get_viewport().set_input_as_handled();return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_RIGHT:choose_piece("")
		elif event.button_index==MOUSE_BUTTON_LEFT:
			var cell=map_cell(event.position,tool.is_empty())
			if tool=="road":road_stroke=[cell];road_last_cell=cell;extend_stroke(cell)
			elif tool.is_empty():
				selection=document.object_at(cell,picked_anchor,picked_terrain,not game.model.shrine().is_empty());show_selection();refresh_controls(false)
			else:
				var position_=terrain_cell if Document.Kit.is_module(tool) else Vector2(cell)
				var height_=terrain_height if Document.Kit.is_module(tool) else placement_height
				var error=document.place(tool,position_,scenery_rotation if Document.Scenery.is_piece(tool) else placement_rotation,placement_scale,height_)
				if error.is_empty():refresh_document(Document.Scenery.is_piece(tool));set_status("%s placed. Click to place another, or Select to resize / rotate it."%piece_label(tool))
				else:set_status(error)
		get_viewport().set_input_as_handled()
func extend_stroke(cell: Vector2i):
	if not game.model.navigation_region.grow(-1).has_point(cell):return
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
	if item.is_empty():game.world.preview.hide();set_status("The base is protected." if selection.get("group")=="shrine" else "Select a structure or scenery piece.");return
	if selection.group=="ramparts":
		game.world.show_terrain_preview(item.kind,Vector2(item.x,item.z),int(item.rotation),float(item.height),true,true)
		set_status("Selected %s · R turns 90° · Height edits elevation · Delete removes the whole module"%piece_label(item.kind));return
	var dimensions=Vector2i.ONE
	if selection.group=="buildings":dimensions=game.model.dimensions(item.kind,int(item.rotation),int(item.get("span",0)))
	elif selection.group=="deposits":dimensions=Vector2i(3,2)
	var cell=Vector2i(item.x,item.z)
	if selection.group=="portals":cell-=Vector2i(2,2);dimensions=Vector2i(5,5)
	if selection.group in Document.Scenery.GROUPS:
		var cells=Document.scenery_footprint(selection.group,item);cell=cells.front();dimensions=cells.back()-cell+Vector2i.ONE
	game.world.show_editor_marker(cell,dimensions,true,true)
	if selection.group in Document.Scenery.GROUPS:game.world.preview.position.y+=float(item.get("height",0))
	set_status("Selected %s · Size / Rotation edit scenery · T rotates · Delete removes · Undo restores"%item.get("kind",selection.group))
func tick(delta: float):
	if not confirmation.visible and not text_focused():
		var move=Input.get_vector("move_left","move_right","move_forward","move_back")
		if not move.is_zero_approx():
			game.pan+=game.preparation_pan_direction(move)*delta*game.preparation_size*.7
			game.clamp_preparation_pan();game.update_preparation_camera()
	if tool.is_empty() or confirmation.visible or not road_stroke.is_empty():return
	if get_viewport().gui_get_hovered_control()!=null:
		game.world.preview.hide();last_preview="";return
	var cell=map_cell(get_viewport().get_mouse_position());var position_=terrain_cell if Document.Kit.is_module(tool) else Vector2(cell)
	var height_=terrain_height if Document.Kit.is_module(tool) else placement_height
	var key="%s:%s:%d:%f:%f:%f"%[tool,position_,placement_rotation,placement_scale,scenery_rotation,height_]
	if key==last_preview:return
	last_preview=key
	var error=document.road_error([cell],road_width) if tool=="road" else document.placement_error(tool,position_,scenery_rotation if Document.Scenery.is_piece(tool) else placement_rotation,placement_scale,height_)
	if Document.Kit.is_module(tool):
		height_field.set_value_no_signal(terrain_height)
		game.world.show_terrain_preview(tool,terrain_cell,placement_rotation,terrain_height,error.is_empty())
	elif tool=="road":game.world.show_road_preview([cell],road_width,error.is_empty())
	elif tool=="portal":game.world.show_portal_preview(cell,placement_rotation,error.is_empty())
	elif Document.Scenery.is_piece(tool):
		height_field.set_value_no_signal(placement_height)
		game.world.show_scenery_preview(tool,cell,placement_scale,scenery_rotation,error.is_empty(),placement_height)
	elif tool=="deposit":game.world.show_editor_marker(cell,Vector2i(3,2),error.is_empty())
	else:game.world.show_preview(tool,cell,placement_rotation,error.is_empty())
