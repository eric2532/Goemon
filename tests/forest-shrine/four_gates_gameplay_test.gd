extends SceneTree
var game
var checks=0
var failures=0
var config_path="user://four-gates-test-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func frames(n:int=3):
 for i in n:await process_frame
func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 var folder=OS.get_environment("FOUR_GATES_OUTPUT_DIR")
 if folder.is_empty():return
 DirAccess.make_dir_recursive_absolute(folder)
 await frames(5);RenderingServer.force_draw();root.get_texture().get_image().save_png(folder+"/"+label_+".png")
func run():
 # Kai Highway is the new default; exercise the preserved Four Gates preset.
 set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_four_gates.json")))
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await frames()
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 check(game.model.portals.size()==8 and game.model.buildings.values().filter(func(b):return b.kind=="gate").size()==4,"Four Gates retains four gates and eight portals")
 check(game.world.portal_nodes.size()==8 and game.world.portal_nodes.all(func(p):return p.visible and is_equal_approx(p.position.y,18)),"All eight physical portals are visible on raised walls before wave one")
 check(game.pan.length()<1 and game.preparation_size>=500,"Building camera frames all four sides around the base")
 await capture("four-gates-overview")
 for point in [Vector2(0,84),Vector2(-84,0),Vector2(0,-84),Vector2(84,0)]:
  var hit=game.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,70,point.y),Vector3(point.x,-2,point.y),1))
  check(not hit.is_empty() and absf(hit.position.y-9)<.02,"Native ramp floor matches model height at "+str(point))
 var roads=game.world.map_features.get_node("RoadTiles").multimesh
 for cell in [Vector2i(0,14),Vector2i(-14,0),Vector2i(0,-14),Vector2i(14,0)]:
  if DisplayServer.get_name()=="headless":continue
  var index=game.model.roads.keys().find(cell)
  var pose=roads.get_instance_transform(index)
  check(absf(absf(pose.basis.x.x)*6-6)<.01 and absf(absf(pose.basis.z.z)*6-6)<.01,"Road tiles cover a full six metres without ramp seams at "+str(cell))
 game.open_map_editor();await frames();var editor=game.map_editor
 check(editor.document.data.title=="Four Gates" and not editor.document.dirty,"Map editor opens the new preset with its correct clean name")
 check(editor.find_child("FourGatesForestMap",true,false)!=null and editor.find_child("RampartsForestMap",true,false)!=null and editor.find_child("OriginalForestMap",true,false)!=null,"Editor offers the new map and both earlier maps")
 await capture("four-gates-editor")
 editor.load_original();await frames();check(game.model.portals.is_empty() and game.model.ramparts.is_empty(),"Original Map still restores its flat layout")
 editor.load_ramparts();await frames();check(game.model.portals.size()==2 and game.model.ramparts.size()==5,"Twin Ramparts still restores the prior southern approach")
 if editor.has_method("load_four_gates"):
  editor.load_four_gates();await frames();check(game.model.portals.size()==8 and game.model.ramparts.size()==20,"Four Gates button restores all four approaches")
 else:check(false,"Editor can restore Four Gates")
 editor.close_discard();await frames()
 check(game.model.portals.size()==8 and game.pan.length()<1,"Closing the editor restores the current four-sided run and camera")
 var doc=game.MapDocument.new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 check(game.active_forest_map().get("portals",[]).is_empty(),"An explicitly selected old/custom map takes precedence over the new default");remove_meta("forest_custom_layout")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 print("FOUR_GATES_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
