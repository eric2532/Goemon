extends SceneTree
const Document=preload("res://scripts/forest/forest_map_document.gd")
const OUT="res://build/Other Files/Map Resize/"
var game
var checks=0
var failures=0
var cfg="user://map-resize-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(240).timeout.connect(func():printerr("FAIL: map resize timeout");quit(1))
 run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func settle():
 for i in 5:await process_frame
func shot(label_:String):
 if DisplayServer.get_name()=="headless" or "--visual" not in OS.get_cmdline_user_args():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+("large-" if "--large" in OS.get_cmdline_user_args() else "")+label_+".png")
func click(button:Button):
 var event=InputEventMouseButton.new();event.position=button.get_global_rect().get_center();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
 root.push_input(event,true);event=event.duplicate();event.pressed=false;root.push_input(event,true);await settle()
func run():
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
 if "--large" in OS.get_cmdline_user_args():set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string(Document.WIND_MEADOW_LARGE_PATH)))
 if "--maximum" in OS.get_cmdline_user_args():get_meta("forest_custom_layout").map_expansion=2.25
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await settle()
 game.set_process(false);game.set_physics_process(false)
 var model=game.model;var ui=game.forest_ui
 if "--maximum" in OS.get_cmdline_user_args():
  check(model.map_expansion==2.25 and model.terrain.width==1081,"Largest saved valley loads its full heightfield")
  check(ui.bigger_map_button.disabled and not ui.smaller_map_button.disabled,"Largest saved valley presents the correct controls")
  check(game.camera_rig.camera.far>=game.preparation_size*3,"Maximum overview remains inside the camera far plane")
  await shot("03-maximum-map");await finish();return
 check(ui.map_size_controls.is_visible_in_tree() and not ui.preparation_tools_open,"Resize controls are on the main map without opening Tools")
 check(ui.smaller_map_button.disabled and not ui.bigger_map_button.disabled,"Original map shows the correct lower limit")
 for dimensions in [Vector2i(960,600),Vector2i(1280,800),Vector2i(1920,1080)]:
  root.size=dimensions;ui.sync();await settle();ui.sync();await settle()
  check(root.get_visible_rect().encloses(ui.preparation_header.get_global_rect()),"Main controls fit %s"%dimensions)
  check(not ui.preparation_header.get_global_rect().intersects(ui.start_wave_button.get_global_rect()),"Resize controls keep Start clear at %s"%dimensions)
  check(not ui.preparation_header.get_global_rect().intersects(ui.shrine_health_dock.get_global_rect()),"Resize controls keep health clear at %s"%dimensions)
 root.size=Vector2i(1280,800);ui.sync();await settle()
 game.select_build("enemy_castle");check(game.place_cell(Vector2i(-15,15)),"Add a custom castle before resizing")
 model.gold=1234;model.wave=2;model.portals[0].hp-=100;model.buildings.values()[0].hp-=20
 var before=Document.new(false);before.capture(model)
 var workers=model.workers.duplicate(true);var buildings=model.buildings.duplicate(true);var portals=model.portals.duplicate(true)
 var original=model.terrain;var position=game.player.position
 var started=Time.get_ticks_msec()
 await click(ui.bigger_map_button)
 print("MAP_RESIZE_FIRST_MS ",Time.get_ticks_msec()-started)
 check(game.model==model and model.map_expansion==1.5 and not game.map_editor.active,"Bigger resizes the same run directly")
 check(model.gold==1234 and model.wave==2 and model.workers==workers and model.buildings==buildings and model.portals==portals,"Money, wave, workers, placements and damage survive")
 check(game.player.position==position and game.build_kind=="enemy_castle","Player and active castle tool stay in place")
 var after=Document.new(false);after.capture(model);after.data.erase("map_expansion")
 check(after.data==before.data,"Every authored position, tree and road is unchanged")
 var matches=true;var padding=(model.terrain.width-original.width)/2
 for z in original.width:
  for x in original.width:
   if Vector2(x-original.width/2,z-original.width/2).length()*3>160*model.terrain_scale:continue
   if original.heights[z*original.width+x]!=model.terrain.heights[(z+padding)*model.terrain.width+x+padding]:matches=false
 check(matches,"Interior hills keep their original height samples")
 check(model.navigation_region.size==Vector2i.ONE*int(120*model.terrain_scale) and model.terrain.width==int(240*model.terrain_scale)+1,"Expanded navigation and heightfield cover the same domain")
 var nav=game.army_runtime.navigation_data(model)
 check(nav.width==model.terrain.width and nav.origin==Vector3(-360,0,-360)*model.terrain_scale and nav.heights==model.terrain.heights,"Native army receives the expanded terrain")
 game.player.position=Vector3(325*model.terrain_scale,model.surface_height(325*model.terrain_scale,0),0)
 check(not game.resize_preparation_map(-1) and model.map_expansion==1.5,"Shrinking protects characters beyond the new boundary")
 game.player.position=position
 var outer=Vector2i(int(40*model.terrain_scale)+4,0)
 check(model.enemy_castle_placement_error(outer,0).is_empty(),"Added land supports an entire level castle: "+model.enemy_castle_placement_error(outer,0))
 var route=model.enemy_grid.get_id_path(outer+Vector2i(0,-13),Vector2i(0,3))
 check(not route.is_empty(),"New land connects to the original valley through existing terrain")
 await shot("01-expanded-map")
 check(game.resize_preparation_map(-1) and model.map_expansion==1.0,"Smaller restores original dimensions without replacing the run")
 check(model.workers==workers and model.portals==portals,"Resize round trip retains live state")
 check(game.resize_preparation_map(1),"Repeated expansion works")
 check(game.place_cell(outer),"Place a castle in the added space")
 var saved=Document.new(false);saved.capture(model);var decoded=Document.new(false)
 check(Document.validate(saved.data).is_empty() and decoded.decode(saved.encode()).is_empty(),"Expanded custom maps validate and reload")
 check(decoded.data.map_expansion==1.5 and decoded.data.portals.back().x==outer.x,"Saved expansion and outer castle round trip")
 check(not game.resize_preparation_map(-1) and model.map_expansion==1.5 and model.portals.size()==portals.size()+1,"Shrink cannot crop a castle or its exit")
 check(game.resize_preparation_map(1) and model.map_expansion==2.25,"A second press expands again")
 await settle();await shot("03-maximum-map")
 check(ui.bigger_map_button.disabled and not game.resize_preparation_map(1),"Maximum size is explicit and bounded")
 check(game.resize_preparation_map(-1),"Outer castle fits when returning one size")
 game.pan=model.point(outer);game.preparation_size=300;game.update_preparation_camera();game.world.preview.hide();ui.message_left=0;ui.sync();await settle();await shot("02-new-castle")
 for flag in ["ordinary_pause","settings_open","rogue_roster_open","transitioning"]:
  game.set(flag,true);check(not game.resize_preparation_map(1),"Resize respects "+flag);game.set(flag,false)
 for invalid in [0,2,-2]:check(not game.resize_preparation_map(invalid),"Invalid direction cannot resize")
 var malformed=saved.data.duplicate(true)
 for value in [-1,0,1.2,10,NAN,"1.5"]:
  malformed.map_expansion=value;check(not Document.validate(malformed).is_empty(),"Unsupported expansion rejected: "+str(value))
 model.phase="wave";check(not game.resize_preparation_map(1),"Combat cannot resize terrain")
 model.phase="preparing";game.start_wave();model.waves.spawn_clock=10000
 check(model.waves.spawn_one([],model.portals.size()-1),"Outer castle spawns through the original wave owner")
 game.army_runtime.integration_tick(.033)
 check(not game.army_runtime.handles.is_empty() and game.army_runtime.navigation_revision==model.navigation_revision,"Native combat accepts the resized map")
 check(model.waves.active_cap()==240,"Army count remains unchanged")
 await finish()
func finish():
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await settle()
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("MAP_RESIZE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
