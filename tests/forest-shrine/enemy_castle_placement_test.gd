extends SceneTree
const Document=preload("res://scripts/forest/forest_map_document.gd")
const OUT="res://build/Other Files/Enemy Castle Testing/"
var game
var checks=0
var failures=0
var config_path="user://castle-placement-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(180).timeout.connect(func():printerr("FAIL: castle placement timeout");quit(1))
 run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func settle():
 for i in 5:await process_frame
func run():
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await settle()
 var model=game.model;var count=model.portals.size();var trees=model.trees.size()
 game.model.gold=0;game.forest_ui.open_build_menu();await settle()
 var button=game.forest_ui.find_child("EnemyCastle",true,false)
 check(button!=null and button.is_visible_in_tree() and not button.disabled,"Free castle tool is visible and enabled with zero gold")
 button.pressed.emit();await settle()
 check(game.build_kind=="enemy_castle","The build card selects castle placement")
 var cell=Vector2i(-20,20) # Clear of the raised castle's side stairs.
 check(model.enemy_castle_placement_error(cell,0).is_empty(),"The default valley has usable castle ground without deleting hills")
 if not model.enemy_castle_placement_error(cell,0).is_empty():await finish();return
 game.update_build_preview(cell);await settle()
 check(game.world.ghost_kind=="enemy_castle" and game.world.ghost_art.visible,"A full castle ghost previews the placement")
 check(game.world.ghost_art.has_node("SkullpionStatue/CarvedSkullpion"),"Castle placement previews the same destructible Skullpion statue")
 var meshes=game.world.ghost_art.find_children("*","MultiMeshInstance3D",true,false)
 check(not meshes.is_empty(),"The preview reuses the batched castle walls")
 var event=InputEventKey.new();event.physical_keycode=KEY_R;event.pressed=true;game._unhandled_input(event)
 check(game.build_rotation==1,"R rotates the preparation placement")
 game.build_rotation=0
 game.settings.volume=.65
 var sound_cursor=game.placement_audio.voice_cursor
 check(game.place_cell(cell),"The normal click placement path adds the free castle")
 check(game.placement_audio.voice_cursor==sound_cursor+1 and game.placement_audio.voices[sound_cursor%4].stream==game.placement_audio.PLACEMENT,"A successful castle placement plays the shared Warcraft construction cue")
 check(model.gold==0 and model.portals.size()==count+1 and model.trees.size()<trees,"Placement costs nothing and clears only the build footprint's trees")
 var castle=game.enemy_objectives.back()
 check(castle.objective_index==count and castle.sections.size()==model.portals[count].sections.size(),"The added castle uses the existing objective and breakable sections")
 check(castle.hp==model.balance.enemy_castle_health and castle.sections[0].hp==model.balance.enemy_wall_health,"The new keep and walls inherit balance settings")
 check(not game.place_cell(cell) and model.portals.size()==count+1,"Duplicate placement cannot overlap the first castle")
 check(game.placement_audio.voice_cursor==sound_cursor+1,"A rejected castle placement stays silent")
 check(not model.enemy_castle_placement_error(Vector2i.ZERO,0).is_empty(),"The player's castle stays protected")
 check(not model.enemy_castle_placement_error(Vector2i(119,119),0).is_empty(),"A castle and its exit cannot extend outside the map")
 check(not model.enemy_castle_placement_error(Vector2i(30,30),-1).is_empty(),"Invalid rotation cannot commit")
 check(not model.enemy_castle_placement_error(Vector2i(35,30),0).is_empty(),"Steep terrain cannot receive an unsupported castle")
 var saved=Document.new(false);saved.capture(model)
 check(Document.validate(saved.data).is_empty(),"A map with more than four castles validates for saving")
 var reloaded=Document.new(false)
 check(reloaded.decode(saved.encode()).is_empty() and reloaded.data.portals.size()==count+1,"The added castle survives map serialization")
 var revision=model.navigation_revision
 check(model.camp_grid_cells.size()>0 and revision>0,"Native navigation receives the new castle collision revision")
 game.pan=model.point(cell);game.preparation_size=235;game.update_preparation_camera();game.update_build_preview(Vector2i(15,17));await settle()
 if "--visual" in OS.get_cmdline_user_args():await shot("01-free-castle")
 var cancel=InputEventMouseButton.new();cancel.button_index=MOUSE_BUTTON_RIGHT;cancel.pressed=true;game._unhandled_input(cancel)
 check(game.build_kind.is_empty() and not game.world.preview.visible,"Right click exits castle placement")
 game.start_wave();model.waves.spawn_clock=10000;await settle()
 check(model.phase=="wave" and model.waves.spawn_one([],count),"The placed castle releases enemies through the existing wave runtime")
 check(model.enemies.values().any(func(e):return e.get("portal_index",-1)==count),"Reinforcements retain the added castle's ownership")
 for i in 10:await physics_frame
 check(model.enemies.keys().any(func(id):return game.army_runtime.handles.has(id)),"Reinforcements enter the existing native army owner")
 check(model.place_enemy_castle(Vector2i(15,17),0).is_empty(),"Castle placement is blocked during combat")
 model.damage_enemy_objective(count,999999);castle.sync()
 check(castle.dead and model.active_enemy_camps()==count and model.phase=="wave","Destroying the added keep stops its reinforcements without winning early")
 model.phase="preparing";game.set_phase_view();await settle()
 game.open_map_editor();game.map_editor.load_wind_meadow_large();await settle()
 check(game.map_editor.active and game.model.terrain_scale==3.0 and game.model.navigation_region.size==Vector2i(240,240),"Bigger map previews a valley with 2.25 times the existing area")
 check(game.map_editor.previous_model==model,"The size preview preserves the current run until Play map")
 check(game.model.terrain.width==481 and game.model.has_enemy_castles(),"Larger terrain keeps the production castle and native heightfield contracts")
 var big=game.model
 check(big.portals.size()==4 and big.buildings.size()==model.buildings.size(),"The bigger preset retains the central fort and four original enemy objectives")
 check(big.enemy_castle_placement_error(cell,0).is_empty(),"The larger valley also has valid free castle sites")
 if "--visual" in OS.get_cmdline_user_args():await shot("02-bigger-map-preview")
 game.map_editor.close_discard();await settle()
 check(game.model==model and model.gold==0 and model.portals.size()==count+1,"Back restores the exact previous run including its placed castle and money")
 game.open_map_editor();game.map_editor.load_wind_meadow_large();await settle();game.map_editor.play_map();await settle()
 check(not game.map_editor.active and game.model.terrain_scale==3.0 and game.model.phase=="preparing","Play map commits the selected size as a fresh preparation run")
 var outer=Vector2i(85,25)
 check(game.model.enemy_castle_placement_error(outer,0).is_empty(),"Land beyond the old map boundary accepts a complete castle")
 game.select_build("enemy_castle");game.build_rotation=0
 check(game.place_cell(outer),"A castle can be built in the new outer space")
 check(game.enemy_objectives.back().position.x>480,"The placed outer castle occupies newly available playable ground")
 var grid_cell=outer+Vector2i(0,-10)
 check(not game.model.enemy_grid.is_point_solid(grid_cell),"Cleared trees do not leave stale navigation blockers in the new exit")
 saved.capture(game.model)
 check(Document.validate(saved.data).is_empty() and reloaded.decode(saved.encode()).is_empty(),"The large map saves and reloads with its supported terrain size")
 var nav=preload("res://scripts/forest/crowd/army_runtime.gd").navigation_data(game.model)
 check(nav.width==481 and nav.origin==Vector3(-720,0,-720) and nav.heights==game.model.terrain.heights,"Native armies use the exact larger physics terrain")
 check(game.preparation_zoom_limits().y==1800 and game.world.playable_bounds.size==Vector2(1404,1404),"Camera zoom and player bounds cover the enlarged battlefield")
 if "--visual" in OS.get_cmdline_user_args():
  game.build_kind="";game.world.preview.hide();await settle();await shot("03-large-valley")
 game.start_wave();game.model.waves.spawn_clock=10000;await settle()
 check(game.model.waves.spawn_one([],4),"The outer castle spawns reinforcements beyond the original terrain bounds")
 check(game.model.waves.active_cap()==240,"The larger map preserves the existing army cap")
 await finish()
func shot(label_:String):
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT));await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+label_+".png")
func finish():
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await settle()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 if has_meta("forest_custom_layout"):remove_meta("forest_custom_layout")
 print("ENEMY_CASTLE_PLACEMENT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
