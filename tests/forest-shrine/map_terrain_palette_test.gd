extends "res://tests/forest-shrine/map_scenery_test.gd"
const Kit=preload("res://scripts/forest/forest_environment_kit.gd")
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const PALETTE_OUT="res://build/Other Files/Asset Toolkit/Modular Environment/"
func blank()->Dictionary:return {"format":"forest_shrine_map","schema":1,"title":"Terrain palette test","buildings":[],"trees":[],"deposits":[],"portals":[],"roads":[]}
func document_checks():
 for kind in Kit.LABELS:
  for turn in 4:
   var doc=Document.new(false);doc.decode(JSON.stringify(blank()))
   var cell=Vector2(12.5,12);var error=doc.place(kind,cell,turn,1,.1)
   check(error.is_empty(),kind+": half-cell placement and rotation: "+error)
   check(doc.data.ramparts==Kit.placement(kind,cell,turn,.1),kind+": physical segments preserve grouped identity")
   var count=doc.data.ramparts.size();var selection=doc.object_at(Vector2i(cell),null,count-1)
   check(selection.get("index")==0 and doc.selected_item(selection).kind==kind,kind+": every segment selects the whole module")
   var encoded=doc.encode();var copy=Document.new(false)
   check(copy.decode(encoded).is_empty() and copy.encode()==encoded,kind+": exact save/load normalization")
   for step in 4:check(doc.rotate(selection).is_empty(),kind+": selected quarter turn")
   check(doc.encode()==encoded,kind+": four rotations preserve the original module")
   check(doc.transform_terrain(selection,turn,42.25).is_empty() and doc.selected_item(selection).height==42.25,kind+": height works above the raised courtyard")
   check(doc.undo() and doc.encode()==encoded and doc.redo(),kind+": height edit undo/redo")
   check(doc.remove(selection).is_empty() and doc.data.ramparts.is_empty(),kind+": delete removes all grouped segments")
   check(doc.undo() and doc.data.ramparts.size()==count,kind+": undo restores the complete module")
   for corruption in ["kind","geometry","incomplete"]:
    var invalid=doc.data.duplicate(true)
    if corruption=="kind":invalid.ramparts[0].kit.kind="res://untrusted.tscn"
    elif corruption=="geometry":invalid.ramparts[0].h1+=.2
    else:invalid.ramparts[0].kit.rotation=45
    var before=doc.encode();check(not doc.decode(JSON.stringify(invalid)).is_empty() and doc.encode()==before,kind+": malformed module cannot replace the map")
 var doc=Document.new(false);doc.decode(JSON.stringify(blank()))
 check(not doc.place("corner_18",Vector2(39,39),0).is_empty(),"The whole module must stay inside the actual map")
 check(not doc.place("platform_18",Vector2.ZERO,0).is_empty(),"Terrain placement preserves the protected base")
 check(doc.place("platform_18",Vector2(10,10),0).is_empty() and not doc.place("platform_18",Vector2(10,10),0).is_empty(),"An accidental duplicate cannot double the terrain")
 var legacy=blank();legacy.ramparts=Kit.segments("ramp_6",Vector2(10,10))
 check(doc.decode(JSON.stringify(legacy)).is_empty() and doc.data.ramparts==JSON.parse_string(JSON.stringify(legacy.ramparts)),"Legacy ungrouped terrain remains unchanged")
 for path in [Document.WIND_MEADOW_PATH,Document.WIND_MEADOW_LARGE_PATH]:
  var data=JSON.parse_string(FileAccess.get_file_as_string(path));var scaled=Document.new(false);scaled.decode(JSON.stringify(data))
  check(scaled.place("platform_18",Vector2(55,55),0).is_empty(),"Terrain placement uses the full standard/large map domain")
func top_view(point:Vector3,size_:float=100):
 game.pan=point;game.preparation_size=size_;game.update_preparation_camera();await settle()
 var camera=game.camera_rig.camera;camera.global_position=point+Vector3.UP*200;camera.look_at(point,Vector3.FORWARD)
func click_world(point:Vector3):
 await pointer(game.camera_rig.camera.unproject_position(point));await physics_frame;await settle()
func run():
 document_checks()
 if "--document-only" in OS.get_cmdline_user_args():await finish();return
 root.size=Vector2i(1280,800);root.content_scale_size=Vector2i.ZERO
 var original_pointer=root.get_mouse_position()
 var layout=JSON.parse_string(FileAccess.get_file_as_string(Document.WIND_MEADOW_PATH));layout.raised_castle=false;layout.title="Terrain palette test"
 for group in ["trees","roads"]:layout[group]=layout[group].filter(func(item):return not Rect2i(-33,-14,30,43).has_point(Vector2i(item.x,item.z)))
 set_meta("forest_custom_layout",layout)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await settle();game.open_map_editor();await settle()
 var editor=game.map_editor;editor.map_folder=folder;var placed=[];var index=0
 for kind in Kit.LABELS:
  var slot=editor.palette_kinds.find(kind)
  while editor.palette_page<slot/9:await key(KEY_PAGEDOWN)
  while editor.palette_page>slot/9:await key(KEY_PAGEUP)
  await key(KEY_1+slot%9)
  check(editor.tool==kind and editor.palette_buttons[slot%9].button_pressed,kind+": real page/number key selects the module")
  check(editor.rotation_field.editable and not editor.size_field.editable and editor.height_field.editable,kind+": module controls expose quarter turns and height")
  editor.rotation_field.value=0;editor.height_field.value=1;editor.height_field.value=0;await key(KEY_T)
  check(editor.placement_rotation==1 and editor.rotation_field.value==90,kind+": T rotates the placement ghost 90 degrees")
  var cell=Vector2(-24+(index%2)*10,-8+(index/2)*8);var point=Vector3(cell.x*6,0,cell.y*6)
  await top_view(point);var mouse=InputEventMouseMotion.new();mouse.position=game.camera_rig.camera.unproject_position(point);root.warp_mouse(mouse.position);await settle();editor.tick(1.0/60)
  check(editor.terrain_cell==cell and game.world.preview.visible and game.world.ghost_kind==kind,kind+": native scene preview follows the snapped cursor")
  if editor.terrain_cell!=cell or not game.world.preview.visible:print("TERRAIN_PREVIEW_DIAGNOSTIC expected=",cell," actual=",editor.terrain_cell," visible=",game.world.preview.visible," ghost=",game.world.ghost_kind," mouse=",get_root().get_mouse_position()," event=",mouse.position," hover=",root.gui_get_hovered_control())
  if index==0:
   var model=game.model;var terrain=game.world.map_features;var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var elapsed=[]
   for sample in 24:
    mouse.position=game.camera_rig.camera.unproject_position(point+Vector3((sample%5)*3,0,0));root.warp_mouse(mouse.position);await process_frame
    var start=Time.get_ticks_usec();editor.tick(1.0/60);elapsed.append((Time.get_ticks_usec()-start)/1000.0);await settle()
   elapsed.sort();print("TERRAIN_PALETTE_HOVER_MS median=",elapsed[12]," p95=",elapsed[22])
   check(game.model==model and game.world.map_features==terrain,"Moving a terrain ghost does not rebuild the model or terrain")
   check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources+2,"Repeated terrain preview keeps nodes/resources bounded")
  var first=editor.document.data.get("ramparts",[]).size();await click_world(point)
  var count=Kit.segments(kind,cell,1).size()
  check(game.model.ramparts.size()==first+count and editor.document.data.ramparts[first].kit.kind==kind,kind+": real click commits native terrain segments")
  var part:Dictionary=game.model.ramparts[first];var p=Vector2(part.ax+part.bx,part.az+part.bz)*3
  var probe=Vector3(p.x,game.model.surface_height(p.x,p.y),p.y)
  var hit=game.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(probe+Vector3.UP*30,probe-Vector3.UP,1))
  check(not hit.is_empty() and absf(hit.position.y-probe.y)<.025,kind+": committed physics agrees with navigation height")
  editor.choose_piece("");await top_view(probe);await click_world(probe)
  check(editor.selection.get("group")=="ramparts" and editor.selection.get("index")==first,kind+": clicking the physical deck selects its module")
  await key(KEY_T)
  check(editor.document.data.ramparts[first].kit.rotation==2 and game.model.ramparts.size()==first+count,kind+": rotating a selected junction keeps all its segments")
  placed.append(first);index+=1
 var last=placed.back();var part:Dictionary=game.model.ramparts[last+1];var p=Vector2(part.ax+part.bx,part.az+part.bz)*3
 var probe=Vector3(p.x,game.model.surface_height(p.x,p.y),p.y)
 await top_view(probe);await click_world(probe)
 check(editor.selection.index==last,"T-junction side branch selects the whole junction")
 editor.height_field.value=42.2;await settle();await physics_frame
 var elevation=editor.height_field.value+6
 var raised:Dictionary=game.model.ramparts[last+1];var start=Vector3((raised.ax+raised.bx)*3,elevation,(raised.az+raised.bz)*3)
 var hit=game.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start+Vector3.UP*30,start-Vector3.UP,1))
 check(not hit.is_empty() and absf(hit.position.y-elevation)<.025,"Editing Height rebuilds physical terrain above the old 30-metre limit")
 var runtime=Runtime.new();runtime.configure(null);runtime.set_navigation(1,Runtime.navigation_data(game.model))
 var first:Dictionary=game.model.ramparts[last];var goal=Vector3((first.ax+first.bx)*3,elevation,(first.az+first.bz)*3)
 var handle:int=runtime.spawn(900,0,0,start,100,.4)
 for step in 1200:runtime.step(1.0/60,{"goal_handles":PackedInt64Array([handle]),"goal_positions":PackedVector3Array([goal]),"goal_speeds":PackedFloat32Array([6])})
 var snapshot=runtime.snapshot();check(snapshot.positions[snapshot.handles.find(handle)].distance_to(goal)<1,"Native soldiers navigate a palette-authored raised T after height editing")
 runtime.free();editor.height_field.value=0;await settle()
 var count=game.model.ramparts.size();editor.delete_selected();await settle()
 check(game.model.ramparts.size()==count-2,"Deleting a T removes both physical segments")
 editor.undo();await settle();check(game.model.ramparts.size()==count,"Undo restores the whole T")
 editor.redo();await settle();editor.undo();await settle()
 editor.name_field.text="Terrain palette test";editor.save_map();await settle()
 var copy=Document.new(false);check(copy.read_file(editor.document.path).is_empty() and copy.data.ramparts==editor.document.data.ramparts,"Save/load retains every module identity, turn and elevation")
 game.pan=Vector3(-110,0,24);game.preparation_size=240;game.update_preparation_camera();await settle()
 for page in [2,3]:
  editor.palette_page=page;editor.refresh_palette();await settle()
  for dimensions in [Vector2i(960,600),Vector2i(1280,800)]:
   root.size=dimensions;await settle()
   check(root.get_visible_rect().encloses(editor.get_node("MapAssetPalette").get_global_rect()),"Terrain palette stays inside the viewport on page "+str(page+1)+" at "+str(dimensions))
  await RenderingServer.frame_post_draw
  if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(PALETTE_OUT+"terrain-palette-page-%d.png"%(page+1))
 editor.play_map();await settle();check(not editor.active and game.model.ramparts.size()==count,"Play map uses all palette-authored terrain")
 var native=Runtime.navigation_data(game.model);check(native.pieces.size()==count*10,"Native armies receive every authored segment")
 game.restart_area();await settle();game=current_scene;game.resume()
 check(game.model.ramparts.size()==count and game.model.ramparts[last].kit.kind=="t_junction_18","Restart preserves grouped terrain modules")
 root.warp_mouse(original_pointer)
 print("MAP_TERRAIN_PALETTE_RESULT checks=%d failures=%d"%[checks,failures]);await finish()
