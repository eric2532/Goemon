extends SceneTree
const Document=preload("res://scripts/forest/forest_map_document.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const Scenery=preload("res://scripts/forest/forest_scenery.gd")
const OUT="res://build/Other Files/Map Scenery/"
var checks=0
var failures=0
var game
var config_path="user://scenery-test-%d.cfg"%OS.get_process_id()
var folder="user://scenery-test-maps-%d"%OS.get_process_id()
func _initialize():
 create_timer(240).timeout.connect(func():printerr("FAIL: scenery editor timeout");quit(1))
 node_added.connect(func(node):
  if node.get_script()==load("res://scripts/forest/forest_game.gd"):node.settings_path=config_path)
 run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func settle():
 for i in 4:await process_frame
func run():
 document_checks()
 if "--document-only" in OS.get_cmdline_user_args():await finish();return
 if DisplayServer.get_name()!="headless":root.set_flag(Window.FLAG_NO_FOCUS,true)
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
 if "--large" in OS.get_cmdline_user_args():set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string(Document.WIND_MEADOW_LARGE_PATH)))
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await settle()
 game.open_map_editor();await settle();var editor=game.map_editor;editor.map_folder=folder;editor.refresh_saved_maps()
 check(editor.active,"Existing preparation menu opens editor")
 for slot in 9:
  await key(KEY_1+slot)
  check(editor.tool==editor.palette_kinds[slot] and editor.palette_buttons[slot].button_pressed,"Number %d selects and highlights its grid asset"%(slot+1))
 check(not editor.palette_next.disabled and editor.palette_previous.disabled,"Catalog spans multiple bounded pages")
 await key(KEY_KP_7);check(editor.tool=="rock" and game.build_kind.is_empty() and not game.rogue_roster_open,"Keypad numbers choose editor assets without triggering gameplay")
 await key(KEY_BRACKETRIGHT)
 check(editor.palette_page==1 and editor.tool.is_empty() and not editor.palette_previous.disabled,"Bracket switches to next page and cancels the old placement tool")
 check(editor.palette_buttons[0].text.begins_with("1"),"Next page restarts at key 1")
 await key(KEY_1);check(editor.tool==editor.palette_kinds[9] and editor.palette_page==1,"Number keys resolve the current page")
 editor.name_field.grab_focus();var selected_tool=editor.tool;await key(KEY_BRACKETLEFT);await key(KEY_9)
 check(editor.palette_page==1 and editor.tool==selected_tool,"Typing a name cannot switch pages or tools")
 editor.choose_piece("");await key(KEY_PAGEUP);check(editor.palette_page==0,"Page Up returns to previous assets")
 await key(KEY_PAGEDOWN);check(editor.palette_page==1,"Page Down advances asset pages")
 while not editor.palette_next.disabled:await key(KEY_PAGEDOWN)
 check(editor.palette_page==ceili(editor.palette_kinds.size()/9.0)-1 and editor.palette_next.disabled,"Last catalog page is bounded")
 check(editor.palette_buttons[8].disabled,"Unused final-page slots stay disabled")
 await key(KEY_9);check(editor.tool.is_empty(),"Empty page slots cannot select or place an asset")
 editor.palette_page=0;editor.choose_piece("");editor.refresh_palette()
 if "--profile" in OS.get_cmdline_user_args():
  var baseline=Time.get_ticks_usec();game.preview_forest_map(editor.document.data);editor.document.cache_preview(game.model)
  print("SCENERY_PREVIOUS_FULL_REFRESH_MS ",(Time.get_ticks_usec()-baseline)/1000.0)
 for dimensions in [Vector2i(960,600),Vector2i(1280,800),Vector2i(1920,1080)]:
  root.size=dimensions;await settle()
  var toolbar=editor.get_node("MapEditorToolbar")
  check(root.get_visible_rect().encloses(toolbar.get_global_rect()),"Toolbar fits "+str(dimensions))
  check(toolbar.get_global_rect().encloses(editor.rotation_field.get_global_rect()),"Rotation field stays inside toolbar")
  check(root.get_visible_rect().encloses(editor.get_node("MapAssetPalette").get_global_rect()),"Numbered grid fits "+str(dimensions))
 root.size=Vector2i(1280,800);await settle()
 if "--hotkeys-only" in OS.get_cmdline_user_args():
  print("MAP_GRID_LABELS ",editor.palette_buttons.map(func(item):return item.text))
  await shot("00-grid");await finish();return
 var rock=find_cell(editor,"rock",2,45)
 check(rock!=Vector2i(999,999),"Valley has a legal enlarged rock position")
 if rock==Vector2i(999,999):await finish();return
 editor.choose_piece("rock");editor.size_field.value=2;editor.rotation_field.value=45
 await map_click(rock);await physics_frame
 check(game.model.rocks.has(rock),"Actual map click places enlarged rotated rock")
 if not game.model.rocks.has(rock):await finish();return
 check(game.model.rocks[rock]=={"scale":2.0,"rotation":45.0},"Placement uses displayed size and angle")
 var terrain_root=game.world.map_features;var preview_model=game.model
 var box:AABB=game.model.scenery_obstacles[rock]
 var query=PhysicsRayQueryParameters3D.create(box.get_center()+Vector3.UP*12,box.get_center(),1)
 var hit=game.world.get_world_3d().direct_space_state.intersect_ray(query)
 check(not hit.is_empty() and hit.collider.get_meta("halo_material","")=="stone","Placed rock has stone collision matching fitted bounds")
 editor.choose_piece("");await map_click(rock)
 check(editor.selection.get("group")=="rocks" and editor.size_field.editable,"Map selection enables scenery controls")
 var edit_clock=Time.get_ticks_usec()
 editor.size_field.value=1.5;editor.rotation_field.value=90
 print("SCENERY_TRANSFORM_PAIR_MS ",(Time.get_ticks_usec()-edit_clock)/1000.0);await settle()
 var chunk_key=Vector2i(floori(rock.x*6.0/96),floori(rock.y*6.0/96))
 var retained_chunks=game.world.scenery_chunks.duplicate()
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var warm_nodes=game.get_tree().get_node_count()
 var edit_times=[]
 for i in 12:
  edit_clock=Time.get_ticks_usec();editor.rotation_field.value=90 if i%2 else 120;edit_times.append((Time.get_ticks_usec()-edit_clock)/1000.0);await settle()
 var unchanged=true
 for key_ in retained_chunks:
  if key_!=chunk_key and game.world.scenery_chunks.get(key_)!=retained_chunks[key_]:unchanged=false
 check(unchanged,"Repeated transforms retain every unaffected scenery chunk")
 check(game.get_tree().get_node_count()==warm_nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources+2,"Repeated transforms retain bounded nodes and resources after warmup")
 edit_times.sort();print("SCENERY_REPEAT_TRANSFORM_MS median=",edit_times[6]," p95=",edit_times[11])
 editor.rotation_field.value=90
 check(game.model==preview_model and game.world.map_features==terrain_root,"Changing scenery retains terrain and the preview model")
 check(game.model.rocks[rock].scale==1.5 and game.model.rocks[rock].rotation==90,"Selected rock resizes and rotates")
 await key(KEY_R);check(game.model.rocks[rock].rotation==105,"R turns selected scenery 15 degrees")
 editor.rotation_field.get_line_edit().grab_focus();var before=editor.document.encode();await key(KEY_R);await key(KEY_2)
 check(editor.document.encode()==before and not game.rogue_roster_open,"Typing transform values cannot trigger gameplay shortcuts")
 editor.choose_piece("tree");editor.size_field.value=1.4;editor.rotation_field.value=30
 var tree=find_cell(editor,"tree",1.4,30);check(tree!=Vector2i(999,999),"Valley has a legal tree position")
 if tree==Vector2i(999,999):await finish();return
 await map_click(tree);check(game.model.tree_rotations.get(tree)==30 and is_equal_approx(game.model.trees.get(tree,0),1.4),"Tree uses chosen size and rotation")
 editor.choose_piece("");await map_click(tree);editor.rotation_field.value=120;editor.size_field.value=.7;await settle()
 check(game.model.tree_rotations.get(tree)==120 and is_equal_approx(game.model.trees.get(tree,0),.7),"Selected tree controls update runtime data")
 var corridor=game.model.waves.navigation.terrain_corridors
 var points=PackedVector3Array();var radii=PackedFloat64Array()
 for center in [rock,tree]:
  for offset in [Vector3.ZERO,Vector3(2,0,0),Vector3(4,0,0),Vector3(8,0,0),Vector3(0,0,4)]:
   for radius in [.4,1.3,3.9,8.5]:points.append(game.model.point(center)+offset);radii.append(radius)
 var probes=corridor.probe(points,radii);var probes_match=true
 for i in points.size():
  var point=points[i];point.y=game.model.surface_height(point.x,point.z)
  if (probes[i*2+1]!=0)!=game.model.waves.navigation.move_clear(point,radii[i]):probes_match=false
 check(corridor.native_sampler!=null and probes_match,"Native field probes match exact clearance around transformed scenery for both body sizes and boss radii")
 var physical_boxes=[]
 for shape:CollisionShape3D in game.world.forest_root.find_children("*","CollisionShape3D",true,false):physical_boxes.append(shape.global_transform*AABB(-shape.shape.size*.5,shape.shape.size))
 var boxes_match=physical_boxes.size()==game.model.scenery_obstacles.size()
 for box_:AABB in game.model.scenery_obstacles.values():
  if not physical_boxes.any(func(actual):return actual.is_equal_approx(box_)):boxes_match=false
 check(boxes_match,"Every tree/rock physics box matches the shared fitted native bounds after edits")
 var tree_style=editor.document.selected_item(editor.selection).duplicate()
 var terrain_before_undo=game.world.map_features
 editor.undo();await settle();editor.redo();await settle()
 check(editor.document.data.trees.any(func(item):return item==tree_style),"Undo and redo preserve tree transformations")
 check(game.world.map_features==terrain_before_undo,"Scenery undo/redo retain the terrain and foliage")
 editor.choose_piece("");await map_click(tree)
 game.pan=game.model.point(tree);game.preparation_size=100;game.update_preparation_camera();await settle();await shot("01-editor")
 editor.size_field.get_line_edit().grab_focus();editor.size_field.get_line_edit().text="0.8"
 editor.name_field.text="Scenery round trip";editor.save_map();await settle();var path=editor.document.path
 check(is_equal_approx(game.model.trees[tree],.8),"Save commits a typed size without requiring Enter first")
 var saved=editor.document.encode();check(not path.is_empty() and not editor.document.dirty,"Save writes the custom map")
 var copy=Document.new(false);check(copy.read_file(path).is_empty() and copy.encode()==saved,"Disk reload preserves scenery transforms exactly")
 editor.choose_piece("");await map_click(rock);editor.delete_selected();await settle();await physics_frame
 check(not game.model.rocks.has(rock),"Deleting a rock removes its runtime placement")
 editor.load_selected();await settle()
 if editor.confirmation.visible:editor.confirmation.confirmed.emit();editor.confirmation.hide();await settle()
 check(editor.document.encode()==saved and game.model.rocks.has(rock),"Load button restores the rock and transforms")
 var play_clock=Time.get_ticks_usec();editor.play_map();await settle()
 print("SCENERY_PLAY_MAP_MS ",(Time.get_ticks_usec()-play_clock)/1000.0," status=",editor.status.text)
 check(not editor.active and game.model.phase=="preparing" and game.model.rocks.has(rock),"Play map starts a fresh run with authored scenery")
 if not game.model.rocks.has(rock):await finish();return
 check(game.model.tree_rotations.get(tree)==120 and game.model.rocks[rock].rotation==105,"Played map retains both saved rotations")
 game.restart_area();await settle();game=current_scene
 check(game.model.rocks.has(rock) and game.model.tree_rotations.get(tree)==120,"Restart retains the selected custom map")
 game.resume();game.pan=game.model.point(rock);game.preparation_size=100;game.update_preparation_camera();await settle();await shot("02-play-map")
 game.resume();game.start_wave();await settle();game.model.waves.spawn_clock=10000
 game.army_runtime.integration_tick(.033)
 check(game.army_runtime.navigation_revision==game.model.navigation_revision,"Existing native army accepts authored scenery during play")
 var data=game.army_runtime.navigation_data(game.model)
 box=game.model.scenery_obstacles[rock]
 check(box.position in data.obstacle_min and box.end in data.obstacle_max and box.position in data.friendly_obstacle_min,"Both native teams receive fitted rock blockers")
 await finish()
func document_checks():
 var doc=Document.new(false)
 var legacy={"format":"forest_shrine_map","schema":1,"title":"Scenery checks","buildings":[],"trees":[{"x":10,"z":10,"scale":1.4}],"deposits":[],"portals":[],"roads":[]}
 check(doc.decode(JSON.stringify(legacy)).is_empty(),"Old maps load without scenery rotation or rock lists")
 check(not doc.data.trees[0].has("rotation"),"Legacy tree orientation is preserved")
 check(doc.place("rock",Vector2i(14,10),45,2).is_empty(),"Large rotated rock placement validates")
 var pick=doc.object_at(Vector2i(15,10));check(pick.get("group")=="rocks","Selection covers the enlarged rock footprint")
 check(not doc.place("tree",Vector2i(15,10),0).is_empty(),"Enlarged scenery rejects overlapping objects")
 var before=doc.encode()
 var mismatch=0
 var full_ms=0.0;var local_ms=0.0
 for z in range(6,14):
  for x in range(8,18):
   var cell=Vector2i(x,z)
   var clock=Time.get_ticks_usec();var expected=Document.validate(doc.candidate("rock",cell,45,2));full_ms+=(Time.get_ticks_usec()-clock)/1000.0
   clock=Time.get_ticks_usec();var actual=doc.placement_error("rock",cell,45,2);local_ms+=(Time.get_ticks_usec()-clock)/1000.0
   if expected.is_empty()!=actual.is_empty():mismatch+=1
 check(mismatch==0,"Local cursor validation agrees with full map validation on 80 overlap/clear positions")
 print("SCENERY_CURSOR_VALIDATION_TOTAL_MS full=",full_ms," local=",local_ms)
 for value in [0,.49,2.01,NAN,INF]:
  check(not doc.transform_scenery(pick,value,30).is_empty() and doc.encode()==before,"Invalid size is rejected atomically: "+str(value))
 for value in [-1,360,NAN,INF]:
  check(not doc.transform_scenery(pick,1,value).is_empty() and doc.encode()==before,"Invalid angle is rejected atomically: "+str(value))
 check(not doc.place("rock",Vector2i(39,10),45,2).is_empty(),"Resized rock cannot extend outside map bounds")
 var malformed=doc.data.duplicate(true);malformed.rocks="invalid"
 check(not Document.validate(malformed).is_empty(),"Malformed rock list is rejected at load boundary")
 check(doc.rotate(pick).is_empty() and doc.data.rocks[0].rotation==60,"Scenery rotates in 15 degree steps")
 check(doc.undo() and doc.encode()==before,"Undo restores exact transform data")
 check(doc.redo() and doc.data.rocks[0].rotation==60,"Redo restores rotated scenery")
 var model=Model.new();model.reset(42,{},doc.data,false)
 var baseline=Document.new(false);baseline.capture(model)
 var changed=baseline.data.duplicate(true);changed.rocks[0].scale=.5
 model.update_scenery(changed)
 var rebuilt=Model.new();rebuilt.reset(42,{},changed,false)
 var grids_match=true
 for x in range(-40,40):
  for z in range(-40,40):
   var cell=Vector2i(x,z)
   if model.allied_grid.is_point_solid(cell)!=rebuilt.allied_grid.is_point_solid(cell) or model.enemy_grid.is_point_solid(cell)!=rebuilt.enemy_grid.is_point_solid(cell):grids_match=false
 check(grids_match,"Incremental scenery grid update matches a complete rebuild")
 model.reset(42,{},doc.data,false)
 check(model.allied_grid.is_point_solid(Vector2i(15,10)) and model.enemy_grid.is_point_solid(Vector2i(15,10)),"Both grids block enlarged scenery footprint")
 check(not model.placement_error("tower",Vector2i(15,10),0).is_empty(),"Gameplay buildings cannot overlap rock extents")
 check(not model.waves.navigation.move_clear(model.point(Vector2i(14,10)),1),"Ground navigation rejects the rock center")
 check(not model.waves.navigation.line_clear(Vector3(75,.8,60),Vector3(93,.8,60)),"Rock blocks low projectiles")
 check(model.waves.navigation.line_clear(Vector3(75,5,60),Vector3(93,5,60)),"Projectiles pass above the rock")
 var old=doc.object_at(Vector2i(10,10));var angle=Document.scenery_rotation("trees",doc.selected_item(old))
 check(doc.transform_scenery(old,.5,angle).is_empty(),"Legacy tree can be resized without resetting its orientation")
 var copy=Document.new(false);check(copy.decode(doc.encode()).is_empty() and copy.encode()==doc.encode(),"Transformed trees and rocks survive normalization")
 model.reset(42,{},doc.data,false)
 check(is_equal_approx(model.scenery_obstacles[Vector2i(10,10)].size.y,4),"Authored tree collision scales with its size")
 check(doc.paint_road([Vector2i(10,10)],1).is_empty() and doc.data.trees.is_empty(),"Road painting clears transformed trees")
 check(not doc.paint_road([Vector2i(14,10)],1).is_empty(),"Roads cannot silently overlap rocks")
func find_cell(editor,kind:String,scale_:float,angle:float)->Vector2i:
 for z in range(16,34):
  for x in range(16,34):
   var cell=Vector2i(x,z)
   if editor.document.placement_error(kind,cell,angle,scale_).is_empty():return cell
 return Vector2i(999,999)
func map_click(cell:Vector2i):
 game.pan=game.model.point(cell);game.preparation_size=100;game.update_preparation_camera();await settle()
 await pointer(game.camera_rig.camera.unproject_position(game.model.point(cell)))
func pointer(position:Vector2):
 var event=InputEventMouseButton.new();event.position=position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await settle()
func key(code:int):
 var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await settle()
func shot(label_:String):
 if DisplayServer.get_name()=="headless" or "--visual" not in OS.get_cmdline_user_args():return
 RenderingServer.force_draw();await process_frame;RenderingServer.force_draw()
 root.get_texture().get_image().save_png(OUT+("large-" if "--large" in OS.get_cmdline_user_args() else "")+label_+".png")
func finish():
 if is_instance_valid(game):game.sound_library.cancel();game.music.stop();game.queue_free()
 paused=false;await settle()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
  for name in DirAccess.get_files_at(folder):DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(name)))
  DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
 print("MAP_SCENERY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
