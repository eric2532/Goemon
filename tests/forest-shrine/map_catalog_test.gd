extends "res://tests/forest-shrine/map_scenery_test.gd"
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Catalog=preload("res://scripts/forest/forest_scenery.gd")
const CATALOG_OUT="res://build/Other Files/Asset Toolkit/Map Catalog/"
func blank():
 var doc=Document.new(false)
 doc.decode(JSON.stringify({"format":"forest_shrine_map","schema":1,"title":"Catalog check","buildings":[],"trees":[],"deposits":[],"roads":[],"portals":[]}))
 return doc
func map_click(cell:Vector2i):
 game.pan=game.model.point(cell);game.preparation_size=100;game.update_preparation_camera();await settle()
 # Newly permitted hillside cells must be visible to the test pointer.
 var camera=game.camera_rig.camera;camera.global_position=game.model.point(cell)+Vector3.UP*180;camera.look_at(game.model.point(cell),Vector3.FORWARD)
 await pointer(camera.unproject_position(game.model.point(cell)))
func catalog_checks():
 for kind in Catalog.CATALOG:
  var doc=blank();var cell=Vector2i(10,10)
  check(doc.place(kind,cell,0).is_empty(),kind+": allowed catalog placement")
  var pick=doc.object_at(cell)
  check(pick.get("group")=="props" and doc.selected_item(pick).get("kind")==kind,kind+": selection retains asset identity")
  check(doc.transform_scenery(pick,1.2,90).is_empty() and doc.rotate(pick).is_empty(),kind+": resize/rotation use existing history")
  var encoded=doc.encode();check(doc.undo() and doc.redo() and doc.encode()==encoded,kind+": exact undo/redo")
  var copy=Document.new(false);check(copy.decode(encoded).is_empty() and copy.encode()==encoded,kind+": saved-map normalization retains kind and transform")
  var model=Model.new();model.reset(42,{},doc.data,false)
  check(model.props[cell].kind==kind and not model.waves.navigation.move_clear(model.point(cell),.4),kind+": existing navigation uses fitted blockers")
  var data=preload("res://scripts/forest/crowd/army_runtime.gd").navigation_data(model);var box:AABB=model.scenery_obstacles[cell]
  check(box.position in data.obstacle_min and box.end in data.friendly_obstacle_max,kind+": both native teams share the blocker")
  var parts=Assets.source(Catalog.asset(kind));check(not parts.is_empty(),kind+": imported render mesh exists, including mesh-root GLBs")
  if kind in ["cedar","pine","sakura"]:
   check(parts.size()==2 and parts.any(func(part):return part.name=="Canopy") and parts.any(func(part):return part.name=="Body"),kind+": meadow bark and leaf canopy remain separate")
  var root_=Node3D.new();root.add_child(root_)
  Assets.batch(root_,Catalog.asset(kind),[Transform3D.IDENTITY,Transform3D.IDENTITY],Catalog.wind(kind))
  check(root_.get_child_count()==parts.size() and root_.get_child(0).multimesh.instance_count==2,kind+": placements share a batched mesh")
  if kind in ["cedar","pine","sakura"]:
   var leaf=root_.get_children().filter(func(item):return item.name.contains("Canopy"))[0]
   check(leaf.material_override is ShaderMaterial and leaf.material_override.get_shader_parameter("tree")==true and leaf.material_override.get_shader_parameter("canopy")==true,kind+": shared meadow wind and hero cutaway are enabled")
  if Catalog.asset(kind).begins_with(Catalog.CEDAR):check(root_.get_child(0).material_override==preload("res://assets/models/cedar_pass/shared_matte.tres"),kind+": existing matte/vertex-color contract is preserved")
  root_.free()
  var before=doc.encode();var bad=doc.data.duplicate(true);bad.props[0].kind="res://untrusted.glb"
  check(not doc.decode(JSON.stringify(bad)).is_empty() and doc.encode()==before,kind+": file paths cannot bypass the asset allowlist")
 for kind in ["cedar","pine","sakura","bamboo"]:
  var road_doc=blank();road_doc.place(kind,Vector2i(10,10),0)
  check(road_doc.paint_road([Vector2i(10,10)],1).is_empty() and road_doc.data.props.is_empty(),kind+": road brush reuses tree clearing")
  check(road_doc.undo() and road_doc.data.props[0].kind==kind,kind+": undo restores the cleared tree and its style")
 for kind in ["stone_block","wall_cap","wall_corner","wall_piece","fence"]:
  for angle in [0,90,180,270]:
   var doc=blank();var cell=Vector2i(10,10);var next=cell+(Vector2i.RIGHT if angle%180==0 else Vector2i.DOWN)
   check(Catalog.footprint(cell,Catalog.bounds(kind,1,angle)).size()==1,kind+": quarter turns retain a six-metre footprint")
   check(doc.place(kind,cell,angle).is_empty() and doc.place(kind,next,angle).is_empty(),kind+": modules tile edge-to-edge")
 var doc=blank();doc.place("shrub",Vector2i(10,10),0)
 check(not doc.place("rock",Vector2i(10,10),0).is_empty(),"New scenery cannot overlap original trees/rocks")
 check(not doc.paint_road([Vector2i(10,10)],1).is_empty(),"Roads do not silently overwrite authored scenery")
 var bad=doc.data.duplicate(true);bad.props[0].rotation=360
 check(not Document.validate(bad).is_empty(),"Catalog rotations have the same file validation")
 check(not doc.place("unknown_asset",Vector2i(20,20),0).is_empty(),"Unknown catalog IDs cannot create or load a model")
 var oversized=blank();check(oversized.save(folder).is_empty(),"Save-size check begins with a real valid map")
 var saved_bytes=FileAccess.get_file_as_string(oversized.path);oversized.data.extra_note="x".repeat(Document.MAX_BYTES)
 check(not oversized.save(folder).is_empty() and FileAccess.get_file_as_string(oversized.path)==saved_bytes,"Oversized saves cannot replace a valid map with a file the loader would reject")
func run():
 catalog_checks()
 if "--document-only" in OS.get_cmdline_user_args():await finish();return
 if DisplayServer.get_name()!="headless":root.set_flag(Window.FLAG_NO_FOCUS,true)
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
 var layout=JSON.parse_string(FileAccess.get_file_as_string(Document.WIND_MEADOW_LARGE_PATH if "--large" in OS.get_cmdline_user_args() else Document.WIND_MEADOW_PATH))
 layout.trees=layout.trees.filter(func(item):return not Rect2i(14,14,22,22).has_point(Vector2i(item.x,item.z)))
 layout.title="Catalog check";set_meta("forest_custom_layout",layout)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await settle()
 game.open_map_editor();await settle();var editor=game.map_editor;editor.map_folder=folder;editor.refresh_saved_maps()
 var terrain=game.world.map_features;var cells={};var index=0
 for kind in Catalog.CATALOG:
  var slot=editor.palette_kinds.find(kind);var page=slot/9
  while editor.palette_page<page:await key(KEY_PAGEDOWN)
  while editor.palette_page>page:await key(KEY_PAGEUP)
  await key(KEY_1+slot%9)
  check(editor.tool==kind,kind+": actual page/number key chooses this asset")
  editor.size_field.value=1;editor.rotation_field.value=0
  var cell=Vector2i(16+(index%4)*4,16+(index/4)*4)
  if not editor.document.placement_error(kind,cell,90,1.1).is_empty():cell=find_cell(editor,kind,1.1,90)
  check(cell!=Vector2i(999,999),kind+": legal valley placement exists")
  if cell==Vector2i(999,999):await finish();return
  await map_click(cell);await physics_frame
  check(game.model.props.get(cell,{}).get("kind")==kind,kind+": real map click places the chosen piece")
  if not game.model.props.has(cell):await finish();return
  cells[kind]=cell;index+=1
  var box:AABB=game.model.scenery_obstacles[cell]
  var query=PhysicsRayQueryParameters3D.create(box.get_center()+Vector3.UP*(box.size.y+8),box.get_center(),1)
  var hit=game.world.get_world_3d().direct_space_state.intersect_ray(query)
  check(not hit.is_empty() and hit.collider.get_meta("halo_material","")==Catalog.material(kind),kind+": fitted physical collision has the existing impact material")
  editor.choose_piece("");await map_click(cell);editor.rotation_field.value=90;editor.size_field.value=1.1
  var transformed=editor.selection.get("group")=="props" and game.model.props[cell].rotation==90 and is_equal_approx(game.model.props[cell].scale,1.1)
  if not transformed:print("CATALOG_TRANSFORM_DIAGNOSTIC ",kind," cell=",cell," selection=",editor.selection," data=",game.model.props[cell]," status=",editor.status.text)
  check(transformed,kind+": selected piece uses existing transform controls")
 check(game.world.map_features==terrain,"All thirteen additions and transformations retain terrain/foliage")
 var sample=cells.cedar;game.pan=game.model.point(Vector2i(22,22));game.preparation_size=210;game.update_preparation_camera()
 for page in [1,2]:editor.palette_page=page;editor.refresh_palette();await settle();await shot("page-%d"%(page+1))
 editor.choose_piece("")
 for kind in ["cedar","pine","sakura"]:
  game.pan=game.model.point(cells[kind])+Vector3.UP*4;game.preparation_size=60;game.update_preparation_camera();await settle();await shot("tree-"+kind)
 editor.selection=editor.document.object_at(cells.fence);editor.show_selection();editor.refresh_controls()
 var snapshot=editor.document.encode();var nodes=root.get_tree().get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var times=[]
 for i in 12:
  var clock=Time.get_ticks_usec();editor.rotation_field.value=90 if i%2 else 105;times.append((Time.get_ticks_usec()-clock)/1000.0);await settle()
 check(root.get_tree().get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources+2,"Repeated mixed-catalog edits keep nodes/resources bounded")
 times.sort();print("CATALOG_EDIT_MS median=",times[6]," p95=",times[11])
 editor.name_field.text="Mixed scenery";editor.save_map();await settle();var path=editor.document.path
 var copy=Document.new(false);check(copy.read_file(path).is_empty() and copy.data.props==editor.document.data.props,"Save/reload preserves all thirteen assets and transforms")
 var last=cells.fence;editor.choose_piece("");await map_click(last);editor.delete_selected();editor.undo();editor.redo();editor.undo();await settle()
 check(game.model.props.has(last),"Delete/undo/redo restores catalog geometry and collisions")
 editor.play_map();await settle();check(not editor.active and game.model.props.size()==Catalog.CATALOG.size(),"Play map includes every catalog placement")
 game.restart_area();await settle();game=current_scene;game.resume()
 check(game.model.props.size()==Catalog.CATALOG.size() and game.model.props[sample].kind=="cedar","Restart retains the mixed custom layout")
 game.pan=game.model.point(Vector2i(22,22));game.preparation_size=210;game.update_preparation_camera();await settle();await shot("play-map")
 game.resume();game.start_wave();await settle();game.model.waves.spawn_clock=10000;game.army_runtime.integration_tick(.033)
 check(game.army_runtime.navigation_revision==game.model.navigation_revision,"The existing native army accepts the catalog map")
 if DisplayServer.get_name()!="headless" and "--visual" in OS.get_cmdline_user_args():
  game.set_process(false);game.set_physics_process(false);game.army_runtime.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
  var home=(game.model.point(cells.cedar)+game.model.point(cells.pine)+game.model.point(cells.sakura))/3.0
  game.player.position=home+Vector3(0,0,18);game.player.position.y=game.model.surface_height(game.player.position.x,game.player.position.z)+.15
  game.forest_ui.hide();game.ui.hide();var camera=game.camera_rig.camera
  camera.global_position=home+Vector3(20,18,38);camera.look_at(home+Vector3.UP*7);await settle();await shot("ground-foliage")
 await finish()
func shot(label_:String):
 if DisplayServer.get_name()=="headless" or "--visual" not in OS.get_cmdline_user_args():return
 RenderingServer.force_draw();await process_frame;RenderingServer.force_draw()
 root.get_texture().get_image().save_png(CATALOG_OUT+("large-" if "--large" in OS.get_cmdline_user_args() else "")+label_+".png")
func finish():
 print("MAP_CATALOG_RESULT checks=%d failures=%d"%[checks,failures]);await super.finish()
