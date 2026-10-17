extends SceneTree
var game
var checks=0
var failures=0
var config_path="user://twin-ramparts-gameplay-%d.cfg"%OS.get_process_id()
var folder="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/twin-ramparts-20261017"
func _initialize():
 create_timer(90).timeout.connect(func():printerr("FAIL: Raised walls gameplay timeout");quit(1))
 run.call_deferred()
func frames(n: int=3):
 for i in n:await process_frame
func check(ok: bool,note: String):
 checks+=1;print("PASS: " if ok else "FAIL: ",note)
 if not ok:failures+=1
func capture(label_: String):
 if not "--visual" in OS.get_cmdline_user_args():return
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(folder+"/"+label_+".png")==OK,"Native wall route capture "+label_)
func ray_floor(x: float,z: float)->Dictionary:
 var query=PhysicsRayQueryParameters3D.create(Vector3(x,70,z),Vector3(x,-2,z),1)
 return game.world.get_world_3d().direct_space_state.intersect_ray(query)
func run():
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
 await frames()
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 check(game.model.ramparts.size()==5 and game.model.portals.size()==2,"A fresh game opens the new two-wall layout")
 check(game.preparation_size>=300 and game.pan.z>=80,"Building view frames both wall routes and their portals")
 check(game.world.portal_nodes.size()==2 and game.world.portal_nodes.all(func(p):return p.visible and is_equal_approx(p.position.y,18)),"Both physical spawn portals are visible on the wall before wave one")
 await capture("building-layout")
 for p in [Vector2(-96,192),Vector2(96,192),Vector2(0,138),Vector2(0,84)]:
  var hit=ray_floor(p.x,p.y)
  check(not hit.is_empty() and absf(hit.position.y-game.model.surface_height(p.x,p.y))<.02,"Native collision agrees with route elevation at "+str(p))
 check(game.world.playable_bounds.has_point(Vector2(96,210)),"Combat bounds include the distant wall portals")
 # Presets remain available in the actual editor and do not replace user files.
 var editor_folder="user://twin-ramparts-editor-%d"%OS.get_process_id()
 game.open_map_editor();await frames()
 var editor=game.map_editor;editor.map_folder=editor_folder
 check(editor.active and editor.document.data.ramparts.size()==5 and not editor.document.dirty,"Editor opens the default wall layout as a clean editable map")
 check(editor.find_child("RampartsForestMap",true,false)!=null and editor.find_child("OriginalForestMap",true,false)!=null,"Both the new preset and protected Original Map have editor buttons")
 editor.load_original();await frames()
 check(editor.document.data.ramparts.is_empty() and game.model.ramparts.is_empty(),"Original Map button restores the existing flat map")
 editor.load_ramparts();await frames()
 check(game.model.ramparts.size()==5 and game.world.portal_nodes.size()==2,"Twin Ramparts button restores both solid routes and portals")
 editor.name_field.text="Raised Wall Save Test";editor.save_map()
 var saved=editor.document.path;var loaded=game.MapDocument.new()
 check(loaded.read_file(saved).is_empty() and loaded.data.ramparts.size()==5,"Editor Save writes the raised layout as a separate custom map")
 await capture("map-editor-presets")
 editor.close_discard();await frames()
 check(game.model.ramparts.size()==5 and game.pan.z==100 and game.preparation_size==340,"Closing the editor restores the run and its camera framing")
 var custom=loaded.data.duplicate(true);custom.ramparts=[];custom.title="Existing Custom Map"
 set_meta("forest_custom_layout",custom)
 check(game.active_forest_map().title=="Existing Custom Map","An explicitly selected custom map takes precedence over the new default")
 remove_meta("forest_custom_layout")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(saved));DirAccess.remove_absolute(ProjectSettings.globalize_path(editor_folder))
 game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
 game.player.select_character(5);game.player.smoke_mode=true;game.player.smoke_move=Vector2(0,1);game.tuning.invincible=true
 game.player.position=Vector3(0,.1,55);game.player.velocity=Vector3.ZERO
 var c=game.player.active_ability;c.reset_run();c.player.pos=game.player.position
 for i in 900:c.physics_step(1.0/60)
 check(game.player.position.z>114 and game.player.position.y>17.9,"Ninja physically walks up the continuous ramp onto the wall ("+str(game.player.position)+")")
 game.player.smoke_move=Vector2.ZERO
 var portal=game.model.portals[0];var spawn=game.model.waves.routes.exit_point(portal,0);spawn.y=18
 var e=game.model.waves.spawn_enemy(0,spawn);e.road_path=game.model.waves.routes.guidance(spawn,0);e.portal_index=0
 game.sync_enemies();await frames()
 check(absf(game.actors[e.id].global_position.y-18)<.01,"The combat enemy proxy stands on the same elevated surface")
 game.player.position=Vector3(-96,18.1,185);game.player.velocity=Vector3.ZERO;c.player.pos=game.player.position
 for i in 20:c._move_body(1.0/60)
 game.model.update_vision(game.player.position)
 var enemy_start: Vector3=e.pos
 for i in 180:game.model.waves.tick_enemy(e,1.0/60,game.player.position)
 await frames()
 check(e.pos.z<enemy_start.z-3 and e.pos.y==18,"A spawned enemy walks toward the player on top of the wall")
 check(game.forest_enemy_visible(game.actors[e.id]) and game.model.events.any(func(event):return event.kind=="hero_hit"),"Elevated enemies remain visible and can engage a player on the same wall")
 game.world.update_fog();game.camera_rig.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 game.camera_rig.camera.position=Vector3(-134,36,165);game.camera_rig.camera.look_at(Vector3(-96,25,197))
 await capture("portal-on-wall")
 game.camera_rig.camera.position=Vector3(62,45,172);game.camera_rig.camera.look_at(Vector3(0,14,112))
 await capture("gate-ramp-junction")
 game.player.active_ability.cancel();game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 game.queue_free();paused=false;await frames();await create_timer(.35).timeout
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 print("TWIN_RAMPARTS_GAMEPLAY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
