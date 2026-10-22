extends SceneTree
var game
var checks=0
var failures=0
var config_path="user://blood-gulch-gameplay-%d.cfg"%OS.get_process_id()
const OUTPUT="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/blood-gulch-castle"
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1;print("PASS: " if ok else "FAIL: ",label_)
 if not ok:failures+=1
func frames(count_:int=4):
 for i in count_:await process_frame
func capture(label_:String):
 if "--capture" not in OS.get_cmdline_user_args():return
 await create_timer(.7).timeout;await frames(8);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUTPUT+"/"+label_+".png")
func verify_boundary_player_contact():
 # Exercise the real Chief capsule/gravity where the native floor extends beyond
 # the conservative navigation grid; rectangular bounds cannot hide a seam fall.
 var mesh=load("res://assets/maps/blood_gulch/terrain.res") as ArrayMesh
 var points=mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX] as PackedVector3Array
 var best=Vector3.INF;var best_radius=0.0
 for at in range(0,points.size(),3):
  var a:Vector3=points[at];var b:Vector3=points[at+1];var c:Vector3=points[at+2]
  var p=(a+b+c)/3.0
  if game.model.terrain.contains(p.x,p.z) or not game.world.playable_bounds.grow(-3).has_point(Vector2(p.x,p.z)):continue
  if absf((b-a).cross(c-a).normalized().y)<.97:continue
  var ab=Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z));var bc=Vector2(b.x,b.z).distance_to(Vector2(c.x,c.z));var ca=Vector2(c.x,c.z).distance_to(Vector2(a.x,a.z))
  var twice_area=absf((b.x-a.x)*(c.z-a.z)-(b.z-a.z)*(c.x-a.x))
  # Centroid-to-edge distance, rather than inradius, contains the capsule.
  var radius=twice_area/(3.0*maxf(ab,maxf(bc,ca)))
  if radius>best_radius:best_radius=radius;best=p
 check(best_radius>.4,"A native boundary cap has room for the real player capsule")
 if best_radius<=.4:return
 game.player.position=best+Vector3.UP*.5;game.player.velocity=Vector3.ZERO
 game.paused=false;paused=false;game.player.set_physics_process(true)
 for i in 90:await physics_frame
 game.player.set_physics_process(false)
 check(game.player.is_on_floor() and absf(game.player.position.y-best.y)<.15 and Vector2(game.player.position.x-best.x,game.player.position.z-best.z).length()<.5,"Master Chief stands on the native canyon-edge floor without falling or bounds rescue")
func run():
 # The source launcher also supplies its regular initial scene.
 await frames(2)
 if is_instance_valid(current_scene):current_scene.queue_free()
 await frames(3);paused=false
 set_meta("forest_painterly_preview",true)
 if has_meta("forest_custom_layout"):remove_meta("forest_custom_layout")
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await frames()
 game.playing=true;game.ordinary_pause=false;game.rogue_roster_open=false;game.clear_menu();game.forest_ui.show();game.set_phase_view()
 check(game.model.terrain_source=="blood_gulch","A fresh game defaults to Blood Gulch Castle")
 check(game.model.portals.size()==8,"The default game loads eight enemy approaches")
 check(game.world.map_features.get_node_or_null("BloodGulchTerrain")!=null,"The playable scene builds the recovered canyon")
 var custom=load("res://scripts/forest/forest_map_document.gd").new();custom.load_original();custom.data.title="Existing Saved Castle"
 set_meta("forest_custom_layout",custom.data)
 check(game.active_forest_map().title=="Existing Saved Castle" and game.active_forest_map().get("terrain_source","")=="","An explicitly selected saved map takes precedence over the new default")
 remove_meta("forest_custom_layout")
 await capture("preparation-overview")
 if "--capture" in OS.get_cmdline_user_args():
  var scenic=Camera3D.new();game.add_child(scenic);scenic.fov=62;scenic.far=900;scenic.position=Vector3(150,95,180);scenic.look_at(Vector3(0,7,0));scenic.make_current()
  game.forest_ui.hide();await capture("castle-blood-gulch");game.forest_ui.show();game.camera_rig.camera.make_current();scenic.queue_free()
 game.open_map_editor();await frames()
 var editor=game.map_editor
 check(editor.active and editor.name_field.text=="Blood Gulch Castle","The map editor recognizes the native terrain title")
 var button=editor.find_child("BloodGulchForestMap",true,false)
 check(button is Button,"The editor exposes the new native map preset")
 check(editor.find_child("KaiHighwayForestMap",true,false) is Button and editor.find_child("OriginalForestMap",true,false) is Button,"Existing terrain presets remain available")
 editor.load_original();await frames()
 check(game.model.terrain_source=="","The editor can return to the protected original map")
 if button is Button:button.pressed.emit();await frames()
 check(game.model.terrain_source=="blood_gulch" and editor.name_field.text=="Blood Gulch Castle","The actual preset button restores canyon terrain and name")
 editor.name_field.text="My Bright Castle";editor.document.rename("My Bright Castle");editor.play_map();await frames()
 check(not editor.active and get_meta("forest_custom_layout",{}).get("title")=="My Bright Castle","Playing an edited native map retains its chosen title")
 game.open_map_editor();await frames()
 check(editor.active and editor.name_field.text=="My Bright Castle","Reopening a custom native map preserves its saved name")
 editor.close_discard();await frames()
 if has_meta("forest_custom_layout"):remove_meta("forest_custom_layout")
 game.player.select_character(18);game.start_wave();game.model.waves.spawn_clock=100000;game.model.waves.pending=999;game.tuning.invincible=true
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false);game.camera_focused=true
 game.player.position=Vector3(0,game.model.surface_height(0,84)+.15,84);game.camera_rig.yaw=0;game.camera_rig.pitch=0;game.camera_rig.sync_character_view();game.camera_rig.update_camera(0)
 game.player.master_chief_combat.select_slot(4);await frames()
 check(game.model.phase=="wave" and not game.paused,"The native map starts ordinary castle combat")
 check(game.camera_rig.first_person_viewmodel.visible,"Master Chief retains the first-person weapon view on the native map")
 var camera=game.camera_rig.camera
 camera.make_current();await capture("chief-castle-daylight")
 # A broader playable-eye-level look exposes the open canyon field and sky.
 game.player.position=Vector3(0,game.model.surface_height(0,110)+.15,110);game.camera_rig.yaw=PI;game.camera_rig.pitch=-.04;game.camera_rig.update_camera(0)
 await capture("chief-open-field")
 await verify_boundary_player_contact()
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(config_path):DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 print("BLOOD_GULCH_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
