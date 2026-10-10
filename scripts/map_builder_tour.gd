extends Node
var game: Node
var checks=0
var failures=0
var captures=[]
var report_dir=""
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;push_error("FAIL: "+label)
 else:print("PASS: ",label)
func frames(count: int):
 for i in range(count):await get_tree().process_frame
func click_at(position: Vector2):
 var motion=InputEventMouseMotion.new();motion.position=position;motion.global_position=position;Input.parse_input_event(motion)
 await frames(2)
 for held in [true,false]:
  var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=held;event.position=position;event.global_position=position
  Input.parse_input_event(event);Input.flush_buffered_events();await frames(2)
func click_control(control: Control):await click_at(control.get_global_rect().get_center())
func key(code: int,ctrl: bool=false,shift: bool=false):
 for held in [true,false]:
  var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=held;event.ctrl_pressed=ctrl;event.shift_pressed=shift
  Input.parse_input_event(event);Input.flush_buffered_events();await frames(2)
func canvas_point(editor,p: Vector3)->Vector2:return editor.view.global_position+editor.camera.unproject_position(p)
func shot(name: String):
 await frames(8);var path=report_dir.path_join(name+".png")
 var error=get_viewport().get_texture().get_image().save_png(path);check(error==OK,"Capture "+name);captures.append(ProjectSettings.globalize_path(path))
func choose(editor,kind: String):
 var b=editor.palette_buttons[kind];var scroll=b.get_parent().get_parent() as ScrollContainer
 scroll.ensure_control_visible(b);await frames(3);await click_control(b)
 check(editor.selected_kind==kind,"Native palette selects "+kind)
func run():
 report_dir="res://build/map-builder/tour" if OS.has_feature("editor") else "user://build/map-builder/tour"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_dir))
 if DisplayServer.get_name()=="headless":check(false,"Builder tour needs rendering");finish();return
 get_tree().root.size=Vector2i(1440,900);Input.use_accumulated_input=false;await frames(3)
 var b=game.menu.find_child("MapBuilderButton",true,false)
 check(b!=null,"Main menu includes Build Your Own Map button")
 await click_control(b);await frames(8)
 var editor=game.map_editor
 check(is_instance_valid(editor),"Native main-menu click opens builder")
 if not is_instance_valid(editor):finish();return
 await shot("01-map-builder-starter")
 var count=editor.document.data.pieces.size()
 await choose(editor,"lantern")
 await click_at(canvas_point(editor,Vector3(34,0,154)))
 check(editor.document.data.pieces.size()==count+1,"Native map click places scenery")
 var uid=editor.selected_uid
 await key(KEY_V);await click_at(canvas_point(editor,Vector3(34,0,154)));await key(KEY_R)
 check(editor.document.item(uid).rotation==90,"Native R rotates selected scenery")
 await key(KEY_G);await click_at(canvas_point(editor,Vector3(36,0,160)))
 check(editor.document.item(uid).x==36 and editor.document.item(uid).z==160,"Native G and click move selected scenery")
 await key(KEY_Z,true);check(editor.document.item(uid).z==154,"Native Ctrl+Z undoes move")
 await key(KEY_Z,true,true);check(editor.document.item(uid).z==160,"Native Ctrl+Shift+Z redoes move")
 editor.name_field.text="Map Builder Tour "+str(Time.get_ticks_usec());editor.document.rename(editor.name_field.text)
 await click_control(editor.root.find_child("SaveMap",true,false))
 check(not editor.document.dirty and not editor.current_path.is_empty(),"Native Save button persists map")
 var path=editor.current_path
 await click_control(editor.root.find_child("LoadMap",true,false));await frames(2)
 check(editor.dialog_open,"Native Load button opens saved map list")
 # Cancel the chooser without touching any existing user's maps.
 await key(KEY_ESCAPE);await frames(3)
 check(not editor.dialog_open,"Escape closes map chooser")
 editor.select_tool();editor.focus_point=Vector3(25,0,283);editor.zoom=84;editor.update_camera()
 await shot("02-map-builder-new-assets")
 var blockers=editor.document.place("wall",Vector3(0,0,180));editor.refresh_preview()
 await click_control(editor.root.find_child("PlayMap",true,false))
 check(editor.dialog_open and not game.playing,"Blocked route refuses Play Map")
 await key(KEY_ESCAPE);editor.document.remove_item(blockers);editor.refresh_preview();editor.fit_map()
 await click_control(editor.root.find_child("PlayMap",true,false));await frames(8)
 check(game.playing and game.world.get("custom_map")==true,"Native Play Map opens playable custom siege")
 check(game.encounters.site_states.size()==12 and game.encounters.mine_states.size()==4,"Custom starter supports tower and mine construction")
 game.player.select_character(10);game.reset_player_at(Vector3(0,.15,202));game.camera_rig.reset_follow();await frames(6)
 await shot("03-custom-map-ranger-gameplay")
 await key(KEY_ESCAPE);await frames(3)
 var return_button=game.menu.find_child("ReturnToMapBuilder",true,false)
 check(return_button!=null,"Pause menu has Return to map builder")
 await click_control(return_button);await frames(6)
 check(is_instance_valid(game.map_editor) and game.map_editor.document.data.title.begins_with("Map Builder Tour"),"Native return click preserves map draft")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 game.map_editor.close_editor();await frames(4);game.sound_library.cancel();game.music.stop()
 finish()
func finish():
 var result={"suite":"map-builder-v243","checks":checks,"failures":failures,"screenshots":captures}
 FileAccess.open(report_dir.path_join("verification-manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("MAP_BUILDER_TOUR_RESULT checks=",checks," failures=",failures," captures=",captures.size())
 get_tree().quit(1 if failures else 0)
