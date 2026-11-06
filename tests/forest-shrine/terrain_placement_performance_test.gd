extends "res://tests/forest-shrine/map_scenery_test.gd"
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const PROFILE_OUT="res://build/Other Files/Asset Toolkit/Modular Environment/"
func run():
 root.size=Vector2i(1280,800);root.content_scale_size=Vector2i.ZERO
 var layout=JSON.parse_string(FileAccess.get_file_as_string(Document.WIND_MEADOW_LARGE_PATH if "--large" in OS.get_cmdline_user_args() else Document.WIND_MEADOW_PATH))
 layout.trees=layout.trees.filter(func(item):return not Rect2i(-30,9,15,16).has_point(Vector2i(item.x,item.z)))
 set_meta("forest_custom_layout",layout)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await settle();game.open_map_editor();await settle()
 var editor=game.map_editor;var baseline="--baseline" in OS.get_cmdline_user_args();var report={"baseline":baseline,"large":"--large" in OS.get_cmdline_user_args(),"samples":[]}
 var cell=Vector2i(-24,14);var features=game.world.map_features;var original=game.model;var ground=features.get_node("WindMeadowValley");var collider=ground.get_node("ValleyTerrainCollision")
 var foliage={};var materials=game.world.fog_materials.size();var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for chunk in ground.get_children():
  if str(chunk.name).begins_with("Foliage_"):foliage[str(chunk.name)]=chunk.get_instance_id()
 for kind in ["tower","stone_block","platform_18","corner_18"]:
  for repeat in 2:
   await process_frame
   var first=editor.document.data.get("ramparts",[]).size();var clock=Time.get_ticks_usec()
   var error=editor.document.place(kind,Vector2(cell),0)
   var validated=Time.get_ticks_usec()
   if error.is_empty():editor.refresh_document()
   var refreshed=Time.get_ticks_usec()
   if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
   else:await process_frame
   var rendered=Time.get_ticks_usec();await settle();await physics_frame
   var sample={"kind":kind,"repeat":repeat,"validate_ms":(validated-clock)/1000.0,"refresh_ms":(refreshed-validated)/1000.0,"total_ms":(refreshed-clock)/1000.0}
   sample.first_render_ms=(rendered-clock)/1000.0
   report.samples.append(sample);print("PLACEMENT_PROFILE ",JSON.stringify(sample));check(error.is_empty(),kind+": actual editor placement succeeds: "+error)
   if not baseline:
    check(game.model==original and game.world.map_features==features and ground.get_node("ValleyTerrainCollision")==collider,"Edits retain the model, terrain, base collision and scenery root")
    var changed=0
    for name_ in foliage:
     if ground.get_node(NodePath(name_)).get_instance_id()!=foliage[name_]:changed+=1
    check(changed<=16,"Only local foliage is regenerated")
   var probe=game.model.point(cell)+Vector3(6,0,0) if Document.Kit.is_module(kind) else game.model.point(cell)
   var hit=game.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(probe+Vector3.UP*45,probe-Vector3.UP*3,1))
   check(not hit.is_empty(),kind+": placed content has physics")
   if Document.Kit.is_module(kind):
    check(absf(hit.position.y-game.model.surface_height(probe.x,probe.z))<.025,kind+": physics and native support heights agree")
    check(Runtime.navigation_data(game.model).pieces.size()==game.model.ramparts.size()*10,"Native navigation receives changed terrain")
   editor.selection={"group":"ramparts","index":first} if Document.Kit.is_module(kind) else editor.document.object_at(cell)
   clock=Time.get_ticks_usec();editor.delete_selected();report.samples.back().delete_ms=(Time.get_ticks_usec()-clock)/1000.0;await settle()
   if not baseline:
    check(game.model==original and game.world.map_features==features,"Deletion retains the original terrain/model")
    check(game.world.fog_materials.size()==materials,"Removed route materials do not accumulate")
 if not baseline:
  check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources+2,"Repeated placement/deletion keeps nodes and resources bounded")
  game.pan=game.model.point(cell);game.preparation_size=100;game.update_preparation_camera();await settle()
  editor.document.place("platform_18",Vector2(cell),0);editor.refresh_document();await settle()
  var base_model=editor.previous_model;editor.close_discard();await settle()
  check(game.model==base_model and game.world.map_features==features and game.model.ramparts.is_empty(),"Discard restores the original run and routes without rebuilding the meadow")
 var file=FileAccess.open(PROFILE_OUT+("large-" if report.large else "standard-")+("placement-before.json" if baseline else "placement-after.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "));file.close()
 print("TERRAIN_PLACEMENT_PERFORMANCE_RESULT checks=%d failures=%d"%[checks,failures]);await finish()
