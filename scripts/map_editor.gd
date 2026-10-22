extends CanvasLayer
## A local map-building workspace with an isolated 3D preview.
const Document=preload("res://scripts/map_document.gd")
const Pieces=preload("res://scripts/map_pieces.gd")
const MAP_FOLDER="user://maps"
var game: Node
var document
var root: Control
var view: SubViewportContainer
var viewport: SubViewport
var scene: Node3D
var preview
var camera: Camera3D
var name_field: LineEdit
var status: Label
var selected_label: Label
var dirty_label: Label
var selected_uid=-1
var selected_kind=""
var tool="select"
var placement_rotation=0
var grid_size=2.0
var focus_point=Vector3(0,0,205)
var zoom=285.0
var dragging=false
var current_path=""
var ghost: Node3D
var outline: Node3D
var pointer=Vector3.ZERO
var pointer_valid=false
var marker_overlay: Control
var palette_buttons: Dictionary={}
var undo_button: Button
var redo_button: Button
var selection_buttons: Array=[]
var dialog_open=false
func _ready():
 layer=30;process_mode=Node.PROCESS_MODE_ALWAYS
 root=Control.new();root.name="MapBuilderUI";root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root)
 root.theme=editor_theme()
 var background=ColorRect.new();background.color=Color("132829");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(background)
 view=SubViewportContainer.new();view.name="MapCanvas";view.stretch=true
 view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);view.offset_left=280;view.offset_top=92;view.offset_right=-20;view.offset_bottom=-120
 root.add_child(view);view.gui_input.connect(_view_input)
 viewport=SubViewport.new();viewport.own_world_3d=true;viewport.gui_disable_input=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_2X;view.add_child(viewport)
 scene=Node3D.new();viewport.add_child(scene)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.1;camera.far=900;scene.add_child(camera);camera.current=true
 current_path=document.file_path
 build_ui()
 marker_overlay=Control.new();marker_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;marker_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);view.add_child(marker_overlay)
 refresh_preview();update_camera()
 set_status("Choose a piece, then click the map. Start from this garden or create a blank map.")
func editor_theme()->Theme:
 var theme=Theme.new();theme.default_font_size=16
 theme.set_color("font_color","Label",Color("d9e7dd"))
 for state in ["normal","hover","pressed","focus","disabled"]:
  var box=StyleBoxFlat.new();box.bg_color=Color("24423f") if state=="normal" else Color("3c6155")
  if state=="disabled":box.bg_color=Color("233333")
  box.corner_radius_top_left=6;box.corner_radius_top_right=6;box.corner_radius_bottom_left=6;box.corner_radius_bottom_right=6
  box.content_margin_left=12;box.content_margin_right=12;box.content_margin_top=9;box.content_margin_bottom=9
  if state=="focus":box.set_border_width_all(2);box.border_color=Color("dfc88c")
  theme.set_stylebox(state,"Button",box)
 var panel=StyleBoxFlat.new();panel.bg_color=Color("192f30");panel.set_corner_radius_all(10);theme.set_stylebox("panel","PanelContainer",panel)
 return theme
func label(parent: Node,text_value: String,size: int=16,color: Color=Color("d9e7dd"))->Label:
 var n=Label.new();n.text=text_value;n.add_theme_font_size_override("font_size",size);n.add_theme_color_override("font_color",color);parent.add_child(n);return n
func button(parent: Node,text_value: String,callback: Callable)->Button:
 var n=Button.new();n.text=text_value;n.pressed.connect(callback);parent.add_child(n);return n
func panel_at(position: Vector2,size: Vector2)->VBoxContainer:
 var panel=PanelContainer.new();panel.position=position;panel.size=size;root.add_child(panel)
 var margin=MarginContainer.new();for key in ["margin_left","margin_right","margin_top","margin_bottom"]:margin.add_theme_constant_override(key,14)
 panel.add_child(margin);var column=VBoxContainer.new();column.add_theme_constant_override("separation",8);margin.add_child(column);return column
func build_ui():
 var header=HBoxContainer.new();header.position=Vector2(20,18);header.size=Vector2(1400,56);header.add_theme_constant_override("separation",12);root.add_child(header)
 label(header,"MAP BUILDER",24,Color("f1d590"))
 name_field=LineEdit.new();name_field.name="MapName";name_field.text=document.data.title;name_field.max_length=48;name_field.custom_minimum_size=Vector2(285,44);name_field.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 name_field.text_changed.connect(func(value):document.rename(value);refresh_controls());header.add_child(name_field)
 dirty_label=label(header,"",14,Color("f1d590"));dirty_label.custom_minimum_size.x=80
 var save_button=button(header,"Save",save_map);save_button.name="SaveMap"
 button(header,"Load",show_load_dialog).name="LoadMap"
 button(header,"Play Map",play_map).name="PlayMap"
 button(header,"Main menu",func():confirm_discard(close_editor)).name="ExitMapBuilder"
 var left=PanelContainer.new();left.position=Vector2(20,92);left.set_anchors_preset(Control.PRESET_LEFT_WIDE);left.offset_top=92;left.offset_bottom=-120;left.offset_left=20;left.offset_right=260;root.add_child(left)
 var margin=MarginContainer.new();left.add_child(margin)
 for key in ["margin_left","margin_right","margin_top","margin_bottom"]:margin.add_theme_constant_override(key,12)
 var column=VBoxContainer.new();column.add_theme_constant_override("separation",8);margin.add_child(column)
 label(column,"PIECE LIBRARY",17,Color("f1d590"))
 var select_button=button(column,"Select / inspect  [V]",select_tool);select_button.name="SelectTool"
 var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
 var palette=VBoxContainer.new();palette.size_flags_horizontal=Control.SIZE_EXPAND_FILL;palette.add_theme_constant_override("separation",5);scroll.add_child(palette)
 for group in ["Ground","Structures","Nature","Gameplay"]:
  label(palette,group.to_upper(),13,Color("aac4ae"))
  for kind in Pieces.CATALOG:
   if Pieces.CATALOG[kind].group!=group:continue
   var b=button(palette,Pieces.CATALOG[kind].name,choose_piece.bind(kind));b.name="Palette_"+kind;b.toggle_mode=true;b.alignment=HORIZONTAL_ALIGNMENT_LEFT
   palette_buttons[kind]=b
 var row=HBoxContainer.new();column.add_child(row)
 button(row,"Starter",func():confirm_discard(new_map.bind(true)))
 button(row,"Blank",func():confirm_discard(new_map.bind(false)))
 var grid_row=HBoxContainer.new();column.add_child(grid_row);label(grid_row,"Snap")
 var grid=OptionButton.new();grid.add_item("1m");grid.add_item("2m");grid.add_item("4m");grid.selected=1
 grid.item_selected.connect(func(index):grid_size=[1.0,2.0,4.0][index]);grid_row.add_child(grid)
 button(grid_row,"Fit",fit_map)
 var bottom=PanelContainer.new();bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);bottom.offset_top=-106;bottom.offset_bottom=-14;bottom.offset_left=20;bottom.offset_right=-20;root.add_child(bottom)
 var bottom_margin=MarginContainer.new();bottom.add_child(bottom_margin)
 for key in ["margin_left","margin_right","margin_top","margin_bottom"]:bottom_margin.add_theme_constant_override(key,10)
 var rows=VBoxContainer.new();rows.add_theme_constant_override("separation",6);bottom_margin.add_child(rows)
 var actions=HBoxContainer.new();actions.add_theme_constant_override("separation",7);rows.add_child(actions)
 undo_button=button(actions,"Undo",undo);redo_button=button(actions,"Redo",redo)
 selection_buttons.append(button(actions,"Move [G]",move_selected))
 selection_buttons.append(button(actions,"Rotate [R]",rotate_selected))
 selection_buttons.append(button(actions,"Duplicate",duplicate_selected))
 selection_buttons.append(button(actions,"Delete",delete_selected))
 selection_buttons.append(button(actions,"Route ↑",reorder_selected.bind(-1)))
 selection_buttons.append(button(actions,"Route ↓",reorder_selected.bind(1)))
 selected_label=label(actions,"",14,Color("f1d590"));selected_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 status=label(rows,"",14);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 var tip=Label.new();tip.text="Left click: place / select   ·   Right drag: pan   ·   Wheel: zoom   ·   WASD: pan   ·   Ctrl/Cmd+Z: undo   ·   R: rotate"
 tip.add_theme_font_size_override("font_size",13);tip.modulate=Color("d8e1c7");tip.position=Vector2(298,76);root.add_child(tip)
func refresh_preview():
 if is_instance_valid(preview):scene.remove_child(preview);preview.queue_free()
 preview=load("res://scripts/map_builder_world.gd").new();preview.map_data=document.data.duplicate(true);preview.editor_labels=true;scene.add_child(preview)
 draw_grid();refresh_controls();update_outline();refresh_marker_labels()
func draw_grid():
 var grid_root=Node3D.new();grid_root.name="EditorGrid";preview.add_child(grid_root)
 var material=Geo.mat("819b82")
 for x in range(-80,81,8):Geo.box(grid_root,Vector3(x,.09,205),Vector3(.055,.015,310),material)
 for z in range(50,361,8):Geo.box(grid_root,Vector3(0,.09,z),Vector3(160,.015,.055),material)
func refresh_controls():
 if not is_instance_valid(dirty_label):return
 dirty_label.text="Unsaved" if document.dirty else ("Saved" if not current_path.is_empty() else "Starter")
 undo_button.disabled=document.history.is_empty();redo_button.disabled=document.future.is_empty()
 var entry=document.item(selected_uid)
 var valid=not entry.is_empty()
 for b in selection_buttons:b.disabled=not valid
 selection_buttons[2].disabled=not valid or entry.get("kind","") in Pieces.SINGLETONS
 selection_buttons[3].disabled=selection_buttons[2].disabled
 selection_buttons[4].disabled=not valid or entry.get("kind")!="waypoint"
 selection_buttons[5].disabled=selection_buttons[4].disabled
 selected_label.text=(Pieces.CATALOG[entry.kind].name+" · %dm, %dm" % [entry.x,entry.z]) if valid else "Select a piece to edit"
 for kind in palette_buttons:palette_buttons[kind].set_pressed_no_signal(tool=="place" and selected_kind==kind)
func set_status(text_value: String,error: bool=false):
 status.text=text_value;status.modulate=Color("ffa893") if error else Color("c7d9cb")
func update_camera():
 camera.size=zoom;camera.position=focus_point+Vector3(0,180,125);camera.look_at(focus_point);update_marker_labels()
func fit_map():focus_point=Vector3(0,0,205);zoom=285;update_camera()
func snap_point(p: Vector3)->Vector3:return Vector3(snappedf(p.x,grid_size),0,snappedf(p.z,grid_size))
func screen_point(local: Vector2)->Vector3:
 var origin=camera.project_ray_origin(local);var direction=camera.project_ray_normal(local)
 if absf(direction.y)<.0001:return Vector3(INF,0,INF)
 return origin+direction*(-origin.y/direction.y)
func _view_input(event):
 if dialog_open:return
 if event is InputEventMouseMotion:
  pointer=snap_point(screen_point(event.position));pointer_valid=document.valid_point(pointer)
  if dragging:
   focus_point+=Vector3(-event.relative.x,0,-event.relative.y)*zoom/maxf(1,view.size.y);update_camera()
  update_ghost()
 elif event is InputEventMouseButton:
  if event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:dragging=event.pressed
  if not event.pressed:return
  if event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom=clampf(zoom*.9,35,350);update_camera()
  elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom=clampf(zoom*1.1,35,350);update_camera()
  elif event.button_index==MOUSE_BUTTON_LEFT:
   var p=screen_point(event.position)
   if tool=="place":place_at(p)
   elif tool=="move":
    if document.move_item(selected_uid,snap_point(p)):tool="select";clear_ghost();refresh_preview();set_status("Piece moved.")
    else:set_status("Choose a position inside the map.",true)
   else:select_at(p)
  view.accept_event()
func _input(event):
 if dialog_open or not event is InputEventKey or not event.pressed or event.echo:return
 if root.get_viewport().gui_get_focus_owner() is LineEdit:return
 var shortcut=event.ctrl_pressed or event.meta_pressed
 if shortcut and event.keycode==KEY_S:save_map()
 elif shortcut and event.keycode==KEY_Z:
  if event.shift_pressed:redo()
  else:undo()
 elif shortcut and event.keycode==KEY_Y:redo()
 elif event.keycode==KEY_R:rotate_selected()
 elif event.keycode==KEY_G:move_selected()
 elif event.keycode==KEY_V:select_tool()
 elif event.keycode in [KEY_DELETE,KEY_BACKSPACE]:delete_selected()
 elif event.keycode==KEY_ESCAPE:
  if tool!="select":select_tool()
  else:confirm_discard(close_editor)
 else:return
 get_viewport().set_input_as_handled()
func _process(delta):
 update_marker_labels()
 if dialog_open or root.get_viewport().gui_get_focus_owner() is LineEdit:return
 if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):return
 var motion=Vector3.ZERO
 if Input.is_physical_key_pressed(KEY_W):motion.z-=1
 if Input.is_physical_key_pressed(KEY_S):motion.z+=1
 if Input.is_physical_key_pressed(KEY_A):motion.x-=1
 if Input.is_physical_key_pressed(KEY_D):motion.x+=1
 if motion!=Vector3.ZERO:
  focus_point+=motion.normalized()*zoom*.5*delta;focus_point.x=clampf(focus_point.x,-100,100);focus_point.z=clampf(focus_point.z,30,380);update_camera()
func choose_piece(kind: String):
 if not Pieces.CATALOG.has(kind):return
 tool="place";selected_kind=kind;placement_rotation=0;clear_ghost();refresh_controls()
 set_status("Place "+Pieces.CATALOG[kind].name+". R rotates. "+("This moves the existing marker." if kind in Pieces.SINGLETONS else "Click repeatedly to add more."))
func select_tool():tool="select";selected_kind="";clear_ghost();refresh_controls();set_status("Click a piece to select it. G moves it; R rotates it.")
func place_at(p: Vector3):
 var uid=document.place(selected_kind,snap_point(p),placement_rotation)
 if uid<0:set_status("Place inside the field. A map holds up to 512 pieces and 64 route points.",true);return
 selected_uid=uid;refresh_preview();set_status("Placed "+Pieces.CATALOG[selected_kind].name+". Your draft is ready to save.")
func select_at(p: Vector3):
 selected_uid=-1
 # Gameplay markers take priority over scenery, and ground is selected last.
 var candidates=document.data.pieces.duplicate();candidates.reverse()
 for group in ["Gameplay","Structures","Nature","Ground"]:
  for entry in candidates:
   if Pieces.CATALOG[entry.kind].group!=group:continue
   var local=(p-document.point(entry)).rotated(Vector3.UP,-deg_to_rad(entry.rotation));var half: Vector2=Pieces.CATALOG[entry.kind].size*.5+Vector2.ONE*.7
   if absf(local.x)<=half.x and absf(local.z)<=half.y:selected_uid=entry.uid;break
  if selected_uid>=0:break
 refresh_controls();update_outline()
func move_selected():
 var entry=document.item(selected_uid)
 if entry.is_empty():return
 tool="move";selected_kind=entry.kind;placement_rotation=entry.rotation;clear_ghost();refresh_controls();set_status("Click the map to move this piece. Esc cancels.")
func rotate_selected():
 if tool in ["place","move"]:
  placement_rotation=posmod(placement_rotation+90,360)
  if tool=="move":document.rotate_item(selected_uid);refresh_preview()
  update_ghost();set_status("Rotation: %d°" % placement_rotation);return
 if document.rotate_item(selected_uid):refresh_preview();set_status("Rotated 90°.")
func duplicate_selected():
 var uid=document.duplicate_item(selected_uid)
 if uid<0:set_status("This marker cannot be duplicated, or there is no room beside it.",true);return
 selected_uid=uid;refresh_preview();move_selected()
func delete_selected():
 if document.remove_item(selected_uid):selected_uid=-1;refresh_preview();set_status("Piece deleted. Undo restores it.")
 else:set_status("Hero spawn, enemy entrance and shrine are required. You can move them.",true)
func reorder_selected(step: int):
 if document.reorder_waypoint(selected_uid,step):refresh_preview();set_status("Route order updated. The road now follows the new order.")
 else:set_status("Select a route waypoint that can move earlier or later.",true)
func undo():
 if document.undo():select_tool();name_field.text=document.data.title;refresh_preview();set_status("Undid the last edit.")
func redo():
 if document.redo():select_tool();name_field.text=document.data.title;refresh_preview();set_status("Redid the edit.")
func update_outline():
 if is_instance_valid(outline):outline.queue_free();outline=null
 var entry=document.item(selected_uid)
 if entry.is_empty():return
 outline=Node3D.new();scene.add_child(outline);outline.position=document.point(entry)+Vector3.UP*.2;outline.rotation_degrees.y=entry.rotation
 draw_outline(outline,Pieces.CATALOG[entry.kind].size+Vector2.ONE,Geo.mat("ffe0a0",0,.4))
func draw_outline(parent: Node3D,size: Vector2,material: Material):
 for side in [-1,1]:
  Geo.box(parent,Vector3(side*size.x*.5,0,0),Vector3(.15,.04,size.y),material)
  Geo.box(parent,Vector3(0,0,side*size.y*.5),Vector3(size.x,.04,.15),material)
func clear_ghost():
 if is_instance_valid(ghost):ghost.queue_free();ghost=null
func update_ghost():
 if tool not in ["place","move"] or selected_kind.is_empty():clear_ghost();return
 if not is_instance_valid(ghost):
  ghost=Pieces.build(scene,selected_kind,false)
  for mesh in ghost.find_children("*","MeshInstance3D",true,false):
   var material=mesh.material_override.duplicate();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color.a=.5;mesh.material_override=material
  draw_outline(ghost,Pieces.CATALOG[selected_kind].size,Geo.mat("ffe0a0",0,.4))
 ghost.visible=pointer_valid;ghost.position=pointer+Vector3.UP*.2;ghost.rotation_degrees.y=placement_rotation
func new_map(starter: bool):
 if starter:document.reset_template()
 else:document.reset_blank()
 document.saved_text="";current_path="";selected_uid=-1;name_field.text=document.data.title;select_tool();fit_map();refresh_preview()
 set_status("New draft. Add pieces and save when ready.")
func file_name(title: String)->String:
 var value=title.strip_edges().validate_filename().replace(" ","-").left(64)
 return value if not value.is_empty() else "my-map"
func save_map(after_save: Callable=Callable()):
 document.rename(name_field.text)
 if name_field.text.strip_edges().is_empty():set_status("Give your map a name first.",true);return
 var path=MAP_FOLDER.path_join(file_name(document.data.title)+".json")
 if FileAccess.file_exists(path) and path!=current_path:
  ask("Replace saved map?","A saved map already uses this name. Replace it?",func():write_save(path,after_save));return
 write_save(path,after_save)
func write_save(path: String,after_save: Callable=Callable()):
 var error=document.save(path)
 if error!=OK:set_status("Could not save this map ("+error_string(error)+"). Your draft is still here.",true);return
 current_path=path;refresh_controls();set_status("Saved “"+document.data.title+"”. Load it here any time.")
 if after_save.is_valid():after_save.call()
func load_path(path: String):
 var error=document.read_file(path)
 if not error.is_empty():set_status(error+" Your current draft is unchanged.",true);return
 current_path=path;selected_uid=-1;name_field.text=document.data.title;select_tool();fit_map();refresh_preview();set_status("Loaded “"+document.data.title+"”.")
func show_load_dialog():
 var dialog=AcceptDialog.new();dialog.title="Your saved maps";dialog.min_size=Vector2i(470,340);root.add_child(dialog)
 var list=ItemList.new();list.custom_minimum_size=Vector2(430,250);dialog.add_child(list)
 var files=DirAccess.get_files_at(MAP_FOLDER);var paths=[]
 for file in files:
  if not file.ends_with(".json"):continue
  var path=MAP_FOLDER.path_join(file);var doc=Document.new();var error=doc.read_file(path)
  list.add_item(doc.data.title if error.is_empty() else file+" (unreadable)");paths.append(path)
 dialog.ok_button_text="Load selected";dialog.get_ok_button().disabled=paths.is_empty()
 if not paths.is_empty():list.select(0)
 else:list.add_item("No saved maps yet. Name your map and press Save.")
 dialog.confirmed.connect(func():
  var selected=list.get_selected_items()
  if not selected.is_empty() and selected[0]<paths.size():
   var path=paths[selected[0]];dialog_open=false;dialog.queue_free()
   var candidate=Document.new();var error=candidate.read_file(path)
   if not error.is_empty():set_status(error+" Your draft is unchanged.",true)
   else:confirm_discard(load_path.bind(path))
 )
 dialog.canceled.connect(func():dialog_open=false;dialog.queue_free())
 dialog_open=true;dialog.popup_centered()
func ask(title: String,message: String,callback: Callable):
 var dialog=ConfirmationDialog.new();dialog.title=title;dialog.dialog_text=message;dialog.min_size=Vector2i(460,160);root.add_child(dialog)
 dialog.confirmed.connect(func():dialog_open=false;dialog.queue_free();callback.call())
 dialog.canceled.connect(func():dialog_open=false;dialog.queue_free())
 dialog_open=true;dialog.popup_centered()
func confirm_discard(callback: Callable):
 if not document.dirty:callback.call();return
 var dialog=ConfirmationDialog.new();dialog.title="Keep your changes?";dialog.dialog_text="Your map has unsaved changes. Save them before continuing?"
 dialog.ok_button_text="Save & continue";dialog.add_button("Discard changes",false,"discard");dialog.min_size=Vector2i(510,160);root.add_child(dialog)
 dialog.confirmed.connect(func():
  dialog_open=false;dialog.queue_free();save_map(callback)
 )
 dialog.custom_action.connect(func(action):
  if action=="discard":
   dialog_open=false;dialog.queue_free()
   if callback.get_method()=="close_editor":
    if document.saved_text.is_empty():document.reset_template()
    else:document.decode(document.saved_text)
   callback.call()
 )
 dialog.canceled.connect(func():dialog_open=false;dialog.queue_free())
 dialog_open=true;dialog.popup_centered()
func play_map():
 var errors=document.validate()
 if not errors.is_empty():
  set_status(errors[0],true);ask("Map needs a small fix","\n".join(errors.slice(0,6))+"\n\nFix these placements, then press Play Map.",func():pass);return
 game.map_editor_draft=document;game.play_custom_map(document.data)
func close_editor():
 game.map_editor_draft=document;game.map_editor=null;game.get_tree().paused=false;game.paused=false;game.hud.show()
 game.show_main_menu();queue_free()

func refresh_marker_labels():
 if not is_instance_valid(marker_overlay):return
 for child in marker_overlay.get_children():marker_overlay.remove_child(child);child.queue_free()
 for entry in document.data.pieces:
  if Pieces.CATALOG[entry.kind].group!="Gameplay":continue
  var text=Label.new();text.mouse_filter=Control.MOUSE_FILTER_IGNORE;text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  text.set_meta("uid",entry.uid);text.size=Vector2(80,24);text.add_theme_font_size_override("font_size",13)
  text.add_theme_color_override("font_outline_color",Color("172724"));text.add_theme_constant_override("outline_size",3)
  text.modulate=Color("f5dfa0") if entry.kind in ["tower","mine","base"] else Color("a5f0d6")
  marker_overlay.add_child(text)
 update_marker_labels()
func update_marker_labels():
 if not is_instance_valid(marker_overlay):return
 var route_points=document.find_kind("waypoint")
 for text in marker_overlay.get_children():
  var entry=document.item(text.get_meta("uid"))
  if entry.is_empty():text.hide();continue
  var compact={"tower":"T","mine":"M","spawn":"HERO","enemy":"ENEMY","base":"SHRINE"}
  var full={"tower":"Tower","mine":"Mine","spawn":"Hero spawn","enemy":"Entrance","base":"Shrine"}
  text.text=(compact if zoom>170 else full).get(entry.kind,"")
  if entry.kind=="waypoint":text.text=str(route_points.find(entry)+1)
  var screen=camera.unproject_position(document.point(entry)+Vector3.UP)
  text.position=screen-Vector2(40,14 if entry.kind=="waypoint" else 25)
  text.visible=Rect2(Vector2.ZERO,view.size).has_point(screen)
