extends "res://tests/forest-shrine/map_scenery_test.gd"
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const STACK_OUT="res://build/Other Files/Asset Toolkit/Modular Environment/"
func blank()->Dictionary:return {"format":"forest_shrine_map","schema":1,"title":"Stacking check","buildings":[],"trees":[],"deposits":[],"roads":[],"portals":[]}
func document_checks():
 var data=blank();data.roads=[{"x":10,"z":10}]
 var doc=Document.new(false);check(doc.decode(JSON.stringify(data)).is_empty(),"Road fixture validates")
 check(doc.place("pine",Vector2i(10,10),0).is_empty(),"Planting on a worn road is allowed")
 data=blank();data.ramparts=[preload("res://scripts/forest/forest_environment_kit.gd").segment("platform_18",Vector2(8,10))]
 check(doc.decode(JSON.stringify(data)).is_empty() and doc.place("shrub",Vector2i(10,10),0).is_empty(),"Planting directly on a stone deck is allowed")
 check(doc.decode(JSON.stringify(blank())).is_empty(),"Stack fixture validates")
 for height in [0.0,6.0,12.0]:check(doc.place("stone_block",Vector2i(10,10),0,1,height).is_empty(),"Blocks stack at touching six-metre levels")
 check(doc.place("wall_cap",Vector2i(10,10),0,1,18).is_empty(),"Coping stacks on the wall")
 check(doc.place("pine",Vector2i(10,10),0,.5,18.7).is_empty(),"A tree can be planted on top of stone coping")
 check(not doc.place("stone_block",Vector2i(10,10),0,1,3).is_empty(),"Intersecting wall interiors are still detected")
 var encoded=doc.encode();var copy=Document.new(false)
 check(copy.decode(encoded).is_empty() and copy.encode()==encoded,"All five independent stacked pieces survive save/load normalization")
 var model=Model.new();model.reset(42,{},doc.data,false)
 check(model.props.size()==5 and model.scenery_obstacles.size()==5,"Same-cell layers keep independent visuals and collision")
 var navigation=Runtime.navigation_data(model)
 for anchor in model.props:
  var box:AABB=model.scenery_obstacles[anchor]
  check(box.position in navigation.obstacle_min and box.end in navigation.obstacle_max and box.position in navigation.friendly_obstacle_min,"Both native teams receive each layer's actual height")
 var top=doc.object_at(Vector2i(10,10),Scenery.anchor(doc.data.props.back()))
 check(top.index==4 and doc.transform_scenery(top,.5,90,18.7).is_empty(),"Selecting and rotating the upper tree does not edit its support")
 check(doc.undo() and doc.encode()==encoded and doc.redo(),"Layer edits retain exact undo/redo")
 for value in [-1,257,"6",null]:
  var invalid=doc.data.duplicate(true);invalid.props[1].height=value
  var before=doc.encode();check(not doc.decode(JSON.stringify(invalid)).is_empty() and doc.encode()==before,"Malformed height is rejected without replacing the map")
 for group in ["trees","rocks"]:
  var old=blank();old.props=[{"kind":"stone_block","x":10,"z":10,"scale":1,"rotation":0}]
  old[group]=[{"x":10,"z":10,"scale":1,"rotation":0,"height":6}]
  check(doc.decode(JSON.stringify(old)).is_empty(),"Original "+group+" also support independent height")
  model.reset(42,{},doc.data,false)
  check(model.scenery_obstacles.size()==2,"Original "+group+" do not overwrite the supporting block")
func surface_click(point:Vector3):
 await pointer(game.camera_rig.camera.unproject_position(point));await physics_frame;await settle()
func run():
 document_checks()
 if "--document-only" in OS.get_cmdline_user_args():await finish();return
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
 var layout=JSON.parse_string(FileAccess.get_file_as_string(Document.WIND_MEADOW_PATH))
 layout.title="Stacking check";layout.trees=layout.trees.filter(func(item):return not Rect2i(15,11,12,12).has_point(Vector2i(item.x,item.z)))
 layout.roads=layout.roads.filter(func(item):return not Rect2i(18,14,5,5).has_point(Vector2i(item.x,item.z)))
 layout.roads.append({"x":20,"z":16});set_meta("forest_custom_layout",layout)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await settle()
 game.open_map_editor();await settle();var editor=game.map_editor;editor.map_folder=folder
 var cell=Vector2i(20,16);var ground=game.model.point(cell)
 game.pan=ground;game.preparation_size=85;game.update_preparation_camera();editor.choose_piece("stone_block");await settle()
 var terrain=game.world.map_features
 for height in [0.0,6.0,12.0]:
  await surface_click(ground+Vector3.UP*height)
  check(editor.document.data.props.size()==int(height/6)+1,"Actual pointer stacks a new block at "+str(height))
 check(game.world.map_features==terrain and game.model.props.size()==3,"Stacking preserves the rendered terrain and all three layers")
 editor.choose_piece("pine");editor.size_field.value=.5;await settle();await surface_click(ground+Vector3.UP*18)
 check(game.model.props.size()==4 and is_equal_approx(editor.document.data.props.back().height,18),"Actual pointer plants the tree on the stone wall")
 editor.choose_piece("");await surface_click(ground+Vector3.UP*21)
 check(editor.selection.get("index")==3 and editor.height_field.value==18,"Ray selection finds the upper tree rather than the lower block")
 editor.rotation_field.value=90;editor.height_field.value=19;await settle()
 check(editor.document.data.props[3].rotation==90 and editor.document.data.props[3].height==19 and editor.document.data.props[0].get("height",0)==0,"Height/rotation controls edit only the selected layer")
 editor.height_field.value=18;editor.name_field.text="Stacked wall test";editor.save_map();await settle()
 var copy=Document.new(false);check(copy.read_file(editor.document.path).is_empty() and copy.data.props==editor.document.data.props,"Stacked wall saves and reloads with exact heights")
 var query=PhysicsRayQueryParameters3D.create(ground+Vector3.UP*40,ground,1)
 var hit=game.world.get_world_3d().direct_space_state.intersect_ray(query)
 check(not hit.is_empty() and hit.position.y>ground.y+20,"Physical collision reaches the planted tree above the wall")
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var nodes=get_node_count()
 for repeat in 6:editor.rotation_field.value=90 if repeat%2 else 105;await settle()
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources+2,"Repeated layer editing keeps resources and nodes bounded")
 for size_ in [Vector2i(960,600),Vector2i(1280,800)]:
  root.size=size_;await settle()
  check(editor.get_node("MapEditorToolbar").get_global_rect().encloses(editor.height_field.get_global_rect()),"Height control fits the editor at "+str(size_))
 root.size=Vector2i(1280,800);editor.choose_piece("");game.pan=ground+Vector3.UP*8;game.preparation_size=60;game.update_preparation_camera();await settle()
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(STACK_OUT+"stacking-editor.png")
 await surface_click(ground+Vector3.UP*21);editor.delete_selected();await settle()
 check(game.model.props.size()==3,"Deleting the upper tree retains all supporting blocks")
 editor.undo();await settle()
 check(game.model.props.size()==4,"Delete/undo restores just the selected layer")
 editor.play_map();await settle()
 check(not editor.active and game.model.props.size()==4,"Play map retains the complete stacked wall")
 game.restart_area();await settle();game=current_scene;game.resume()
 check(game.model.props.size()==4 and game.model.scenery_heights.size()==3,"Restart retains every independent layer and planted tree height")
 var runtime=Runtime.new();runtime.configure(null);runtime.set_navigation(1,Runtime.navigation_data(game.model))
 var handles=PackedInt64Array();var goals=PackedVector3Array();var speeds=PackedFloat32Array()
 for team in [0,1]:
  var start=ground+Vector3(-12,0,team*2-1);var goal=ground+Vector3(12,0,0)
  handles.append(runtime.spawn(500+team,team,0,start,100,.4));goals.append(goal);speeds.append(6)
 var crossed=false
 for tick in 900:
  runtime.step(1.0/60,{"goal_handles":handles,"goal_positions":goals,"goal_speeds":speeds})
  var snapshot=runtime.snapshot()
  for position:Vector3 in snapshot.positions:
   if absf(position.x-ground.x)<3.39 and absf(position.z-ground.z)<3.39:crossed=true
 var snapshot=runtime.snapshot()
 check(not crossed,"Native actors never enter the stacked wall's solid footprint")
 for index in handles.size():check(snapshot.positions[snapshot.handles.find(handles[index])].distance_to(goals[index])<1.5,"Both native teams navigate around the stacked wall")
 runtime.free()
 print("MAP_STACKING_RESULT checks=%d failures=%d"%[checks,failures]);await finish()
