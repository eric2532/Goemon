extends "res://tests/forest-shrine/original_maps_test.gd"
## Native room art replaces visible approximations; existing room physics stays authoritative.
func _initialize():
 create_timer(900).timeout.connect(func():printerr("SOKIA_ROOM_VISUAL_TIMEOUT");quit(1))
 run.call_deferred()
func snapped_pose(pose:Transform3D)->String:
 return str([pose.origin.snapped(Vector3.ONE*.001),pose.basis.x.snapped(Vector3.ONE*.001),pose.basis.y.snapped(Vector3.ONE*.001),pose.basis.z.snapped(Vector3.ONE*.001)])
func physics(root_:Node3D)->Array:
 var rows=[]
 for node in root_.find_children("*","CollisionShape3D",true,false):
  var shape:Shape3D=node.shape;var detail=""
  if shape is BoxShape3D:detail=str(shape.size)
  elif shape is ConcavePolygonShape3D:detail=var_to_bytes(shape.get_faces()).hex_encode().sha256_text()
  elif shape is ConvexPolygonShape3D:detail=var_to_bytes(shape.points).hex_encode().sha256_text()
  else:detail=str(shape.get_debug_mesh().get_aabb())
  rows.append(str([shape.get_class(),detail,snapped_pose(root_.global_transform.affine_inverse()*node.global_transform),node.disabled]))
 rows.sort();return rows
func run():
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-sokia-room-visuals-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.run_seed=41829558;game.set_process(false)
 var saved=JSON.stringify(get_meta("falan_venture"));var records=[]
 for id in [3350,3352,3001,3002,3008,3010,3012,3013,3014,3020,3021,3099]:
  print("SOKIA_ROOM_VISUAL_ENTER ",id)
  Tour.travel(game,Tour.Indoor.layout(id),{"arrival":Vector2.ZERO,"yaw":0.,"velocity":Vector3.ZERO})
  game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
  for i in 3:await process_frame
  check(not Original.owns(id),"Existing room retains layout, exits and walking ownership: "+str(id))
  check(Tour.Indoor.floor_info(id)==Tour.Regions.Sites.ROOMS[id],"Original legacy navigation resource unchanged: "+str(id))
  var physical=game.world.map_features.find_child("SokiaPreservedRoomPhysics",true,false)
  var visual=game.world.map_features.find_child("SokiaNativeRoomVisuals",true,false)
  check(physical!=null and visual!=null,"Separate native art and preserved room physics: "+str(id))
  if physical==null or visual==null:continue
  var baseline=Node3D.new();root.add_child(baseline)
  Tour.Indoor.build_legacy(baseline,id,game.model.seed_value)
  var actual=physics(physical);var expected=physics(baseline)
  check(actual==expected,"Every collider shape and transform retained: "+str(id))
  check(visual.find_children("*","CollisionObject3D",true,false).is_empty(),"Native art contributes no additional collision: "+str(id))
  check(physical.find_children("*","GeometryInstance3D",true,false).all(func(n):return not n.is_visible_in_tree()),"Only native room artwork remains visible: "+str(id))
  var offset:Vector2=Tour.Indoor.floor_info(id)[1]-Original.floor_info(id)[1]
  check(visual.position.is_equal_approx(Vector3(offset.x,0,offset.y)),"Native art follows the existing source-coordinate frame: "+str(id))
  records.append({"map":id,"colliders":actual.size(),"source_offset":str(offset)})
  baseline.queue_free();await process_frame
 check(JSON.stringify(get_meta("falan_venture"))==saved,"Adventure data preserved")
 var file=FileAccess.open("res://build/Other Files/Asset Toolkit/Sokia Region Reconstruction/room-visual-preservation.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"  "));file.close()
 print("SOKIA_ROOM_VISUAL_RESULT rooms=",records.size()," checks=",checks," failures=",failures)
 game.queue_free();await process_frame;quit(1 if failures else 0)
