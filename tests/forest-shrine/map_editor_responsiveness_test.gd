extends SceneTree
const Document=preload("res://scripts/forest/forest_map_document.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const OUT="res://build/Other Files/Map Editor Responsiveness/"
var game
var checks=0
var failures=0
var cfg="user://editor-response-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(240).timeout.connect(func():printerr("FAIL: editor responsiveness timeout");quit(1))
 run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func frames():
 for i in 4:await process_frame
func input(event):root.push_input(event,true)
func key(code:int,ctrl:bool=false,echo:bool=false):
 var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;event.ctrl_pressed=ctrl;event.echo=echo;input(event)
 event=event.duplicate();event.pressed=false;event.echo=false;input(event)
func wheel(at:Vector2,up:bool=true,factor:float=1.0):
 var motion=InputEventMouseMotion.new();motion.position=at;input(motion)
 var event=InputEventMouseButton.new();event.position=at;event.factor=factor;event.pressed=true
 event.button_index=MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN;input(event)
 event=event.duplicate();event.pressed=false;input(event)
func view(size_:float):game.preparation_size=size_;game.update_preparation_camera()
func run():
 document_checks()
 if "--document-only" in OS.get_cmdline_user_args():await finish();return
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
 if "--large" in OS.get_cmdline_user_args():set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string(Document.WIND_MEADOW_LARGE_PATH)))
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.open_map_editor();await frames();var editor=game.map_editor
 var cursor_times=[]
 for kind in ["tower","cannon_tower","barracks","wall","gate","tree","rock"]:
  var clock=Time.get_ticks_usec()
  for x in range(16,36):editor.document.placement_error(kind,Vector2i(x,20),0)
  cursor_times.append((Time.get_ticks_usec()-clock)/20000.0)
 print("EDITOR_CURSOR_MS_PER_CELL ",cursor_times)
 var cell=Vector2i.ZERO
 for z in range(16,36):
  for x in range(16,36):
   if editor.document.placement_error("barracks",Vector2i(x,z),0).is_empty():cell=Vector2i(x,z);break
  if cell!=Vector2i.ZERO:break
 check(cell!=Vector2i.ZERO,"A legal building site exists")
 if cell==Vector2i.ZERO:await finish();return
 var features=game.world.map_features;var terrain=game.model.terrain;var preview=game.model
 var retained=game.world.structure_nodes.duplicate();var scenery=game.world.scenery_chunks.duplicate()
 var foliage=game.world.map_features.get_node("WindMeadowValley");var ground_chunks={};var original_foliage={}
 for chunk in foliage.get_children():
  if chunk.name.begins_with("Foliage_"):ground_chunks[chunk.name]=chunk;original_foliage[chunk.name]=foliage_buffers(chunk)
 var clock=Time.get_ticks_usec();var error=editor.document.place("tower",cell,0)
 if error.is_empty():editor.refresh_document()
 print("EDITOR_BUILDING_PLACE_MS ",(Time.get_ticks_usec()-clock)/1000.0)
 check(error.is_empty() and game.model.occupancy.has(cell),"Building placement updates the preview")
 check(game.world.map_features==features and game.model==preview and game.model.terrain==terrain,"Building edits retain terrain meshes, collision and model")
 var same=true
 for id in retained:
  if game.world.structure_nodes.get(id)!=retained[id]:same=false
 check(same,"Adding a building retains all existing building nodes")
 check(game.world.scenery_chunks==scenery,"Building edits retain every unchanged scenery batch")
 var changed=0;var clear_ground=true
 for name_ in ground_chunks:
  if foliage.get_node(NodePath(name_))!=ground_chunks[name_]:
   changed+=1
   for batch in foliage.get_node(NodePath(name_)).get_children():
    for i in batch.multimesh.instance_count:
     if game.model.occupancy.has(game.model.cell_of(batch.global_transform*batch.multimesh.get_instance_transform(i).origin)):clear_ground=false
 check(changed>=1 and changed<=4,"Only local ground foliage chunks are regenerated")
 check(clear_ground,"Refreshed foliage leaves occupied building ground clear")
 var id=game.model.occupancy[cell];editor.selection=editor.document.object_at(cell)
 await frames();await physics_frame
 var physical=game.world.structure_nodes[id].find_children("*","CollisionShape3D",true,false)
 check(not physical.is_empty(),"New building retains physical collision")
 var encoded=editor.document.encode();editor.rotate_selected();await frames()
 check(game.model.buildings[game.model.occupancy[cell]].rotation==1,"Rotation replaces the changed building through the normal lifecycle")
 editor.undo();await frames();check(editor.document.encode()==encoded,"Undo restores exact authored building data")
 editor.redo();await frames();check(game.model.buildings[game.model.occupancy[cell]].rotation==1,"Redo restores building rotation")
 editor.selection=editor.document.object_at(cell)
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var nodes=get_node_count();var edit_times=[]
 for i in 12:
  clock=Time.get_ticks_usec();editor.rotate_selected();edit_times.append((Time.get_ticks_usec()-clock)/1000.0);await frames()
 edit_times.sort();print("EDITOR_REPEAT_BUILDING_MS median=",edit_times[6]," p95=",edit_times[11])
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources+2,"Repeated edits retain bounded nodes and resources")
 check(game.world.map_features==features and game.model.terrain==terrain,"Repeated edits retain terrain and its collision")
 check_navigation(editor)
 var deleted_id=game.model.occupancy[cell];var deleted_node=game.world.structure_nodes[deleted_id]
 editor.delete_selected();await frames();await physics_frame
 check(not game.model.occupancy.has(cell) and not game.world.structure_nodes.has(deleted_id) and not is_instance_valid(deleted_node),"Deletion removes occupancy and the current physical/visual node")
 check_navigation(editor)
 var restored=true
 for name_ in original_foliage:
  if foliage_buffers(foliage.get_node(NodePath(name_)))!=original_foliage[name_]:restored=false
 check(restored,"Deleting the building restores the original local foliage exactly")
 editor.undo();await frames();check(game.model.occupancy.has(cell),"Undo restores a deleted building")
 game.pan=game.model.point(cell);view(90);await frames()
 await shot("building")
 editor.choose_piece("")
 var at=Vector2(560,270);var point=game.ground_at(at)
 view(120);point=game.ground_at(at);wheel(at)
 check(is_equal_approx(game.preparation_size,120/game.PREPARATION_ZOOM_STEP),"Editor wheel uses proportional zoom")
 check(game.camera_rig.camera.unproject_position(point).distance_to(at)<.1,"Editor zoom retains the pointed world location")
 wheel(at,false);check(is_equal_approx(game.preparation_size,120),"Reverse wheel returns to the same scale")
 wheel(at,true,.25);check(game.preparation_size<120 and game.preparation_size>120/game.PREPARATION_ZOOM_STEP,"Fractional scrolling supports fine editor zoom")
 view(120);var pinch=InputEventMagnifyGesture.new();pinch.position=at;pinch.factor=1.5;input(pinch)
 check(is_equal_approx(game.preparation_size,80),"Trackpad pinch magnifies the editor")
 pinch.factor=2.0/3.0;input(pinch);check(is_equal_approx(game.preparation_size,120),"Reverse pinch restores the editor view")
 var scroll=InputEventPanGesture.new();scroll.position=at;scroll.delta=Vector2(0,-.5);input(scroll)
 check(game.preparation_size<120 and game.preparation_size>100,"Trackpad scrolling supports fine editor zoom")
 view(120);key(KEY_EQUAL);check(game.preparation_size<120,"Plus zooms into the editor")
 key(KEY_MINUS);check(is_equal_approx(game.preparation_size,120),"Minus zooms back out")
 key(KEY_EQUAL,true);key(KEY_EQUAL,false,true);check(is_equal_approx(game.preparation_size,120),"Modified keys and echo cannot zoom unexpectedly")
 for i in 60:wheel(at)
 check(game.preparation_size==game.preparation_zoom_limits().x,"Editor reaches the existing close construction limit")
 view(120);editor.name_field.grab_focus();key(KEY_MINUS)
 check(game.preparation_size==120,"Typing a map name does not zoom")
 editor.choose_piece("rock");editor.size_field.get_line_edit().grab_focus();key(KEY_MINUS)
 check(game.preparation_size==120,"Typing a size does not zoom")
 editor.choose_piece("");wheel(editor.get_node("MapAssetPalette").get_global_rect().get_center())
 check(game.preparation_size==120,"Scrolling the asset palette cannot zoom through the UI")
 var motion=InputEventMouseMotion.new();motion.position=at;input(motion)
 editor.confirmation.popup_centered();key(KEY_EQUAL);pinch.factor=1.5;input(pinch)
 check(game.preparation_size==120,"Unsaved-changes confirmation blocks camera input")
 editor.confirmation.hide();game.pan=game.model.point(cell);view(30);await frames();await shot("zoom")
 var authored=editor.document.encode();editor.play_map();await frames()
 check(not editor.active and game.model.phase=="preparing" and game.model.occupancy.has(cell),"Play map starts a fresh run with the edited building")
 var played=Document.new(false);played.capture(game.model);played.data.title=editor.document.data.title
 check(played.encode()==authored,"Play map retains the complete authored layout")
 game.start_wave();await frames();game.model.waves.spawn_clock=10000;game.army_runtime.integration_tick(.033)
 check(game.army_runtime.navigation_revision==game.model.navigation_revision,"The existing native army accepts the edited building map")
 await finish()
func foliage_buffers(chunk:Node3D)->Array:
 return chunk.get_children().map(func(batch):return [batch.name,batch.multimesh.buffer])
func check_navigation(editor):
 var rebuilt=Model.new();rebuilt.reset(42,{},editor.document.data,false);var same=true
 for x in range(game.model.navigation_region.position.x,game.model.navigation_region.end.x):
  for z in range(game.model.navigation_region.position.y,game.model.navigation_region.end.y):
   var cell=Vector2i(x,z)
   if game.model.allied_grid.is_point_solid(cell)!=rebuilt.allied_grid.is_point_solid(cell) or game.model.enemy_grid.is_point_solid(cell)!=rebuilt.enemy_grid.is_point_solid(cell) or game.model.enemy_grid.get_point_weight_scale(cell)!=rebuilt.enemy_grid.get_point_weight_scale(cell):same=false
 check(same,"Incremental building grids and enemy weights match a complete model rebuild")
func document_checks():
 var doc=Document.new(false)
 doc.decode(JSON.stringify({"format":"forest_shrine_map","schema":1,"title":"Editor cursor checks","buildings":[],"trees":[],"deposits":[],"roads":[],"portals":[]}))
 doc.place("gate",Vector2i(10,10),0);doc.place("rock",Vector2i(14,10),0,2);doc.place("wall",Vector2i(10,14),0)
 var mismatch=0
 for kind in ["tower","cannon_tower","barracks","wall","gate"]:
  for rotation in 4:
   for cell in [Vector2i.ZERO,Vector2i(10,10),Vector2i(10,9),Vector2i(9,10),Vector2i(10,11),Vector2i(12,10),Vector2i(14,10),Vector2i(10,14),Vector2i(18,18),Vector2i(38,38),Vector2i(-39,-39)]:
    var full=Document.validate(doc.candidate(kind,cell,rotation));var local=doc.building_error(kind,cell,rotation)
    if full.is_empty()!=local.is_empty():mismatch+=1;printerr("CURSOR_MISMATCH ",kind," ",cell," ",rotation," full=",full," local=",local)
 check(mismatch==0,"Local building validation agrees with full validation on 220 placements")
 for rotation in [-1,4,NAN,INF]:check(not doc.building_error("tower",Vector2i(20,20),rotation).is_empty(),"Invalid building rotation is rejected")
 for kind in ["tower","cannon_tower","barracks","wall","gate"]:
  var model=Model.new();model.reset(42,{},doc.data,false)
  var current=doc.data.duplicate(true)
  for rotation in 4:
   var next=doc.candidate(kind,Vector2i(20,20),rotation)
   model.update_editor_buildings(next)
   var rebuilt=Model.new();rebuilt.reset(42,{},next,false);var matches=true
   for x in range(16,28):
    for z in range(16,28):
     var cell=Vector2i(x,z)
     if model.allied_grid.is_point_solid(cell)!=rebuilt.allied_grid.is_point_solid(cell) or model.enemy_grid.is_point_solid(cell)!=rebuilt.enemy_grid.is_point_solid(cell) or model.enemy_grid.get_point_weight_scale(cell)!=rebuilt.enemy_grid.get_point_weight_scale(cell):matches=false
   check(matches,kind+": incremental rotation agrees with a fresh navigation model")
  model.update_editor_buildings(current)
  check(not model.occupancy.has(Vector2i(20,20)),kind+": deletion restores clear ground")
 var tower_doc=Document.new(false);tower_doc.decode(doc.encode());tower_doc.place("tower",Vector2i(20,20),0)
 var staffed=Model.new();staffed.reset(42,{},tower_doc.data,false)
 var tower_id=staffed.occupancy[Vector2i(20,20)];var guard=staffed.workers.values().filter(func(w):return w.job==tower_id)
 check(guard.is_empty(),"An editor tower starts autonomous without consuming a worker")
 staffed.workforce.recruit(true)
 var old_guard:Dictionary=staffed.workers.values()[0];staffed.workforce.release_job(old_guard)
 old_guard.job=tower_id;old_guard.state="garrison";old_guard.pos=staffed.center(staffed.buildings[tower_id])
 staffed.update_editor_buildings(doc.data)
 check(staffed.workers.values().all(func(w):return w.job!=tower_id and w.state!="garrison"),"Removing an editor tower uses normal worker release")
func shot(label_:String):
 if DisplayServer.get_name()=="headless":return
 RenderingServer.force_draw();await process_frame;RenderingServer.force_draw()
 root.get_texture().get_image().save_png(OUT+("large-" if "--large" in OS.get_cmdline_user_args() else "")+label_+".png")
func finish():
 if is_instance_valid(game):game.sound_library.cancel();game.music.stop();game.queue_free()
 paused=false;await frames();DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("EDITOR_RESPONSIVENESS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
