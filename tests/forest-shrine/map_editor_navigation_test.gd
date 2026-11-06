extends SceneTree
const Document=preload("res://scripts/forest/forest_map_document.gd")
const OUT="res://build/Other Files/Map Editor Navigation/"
var game
var cfg="user://editor-navigation-%d.cfg"%OS.get_process_id()
var report={"scenarios":[]};var suffix=""
var checks=0
var failures=0
func _initialize():
 create_timer(300).timeout.connect(func():printerr("FAIL: editor navigation timeout");quit(1))
 run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func frames(count_:int=4):
 for i in count_:await process_frame
func stats(values:Array)->Dictionary:
 values.sort();return {"median":values[values.size()/2],"p95":values[ceili(values.size()*.95)-1],"max":values.back()}
func run():
 if "--saved" in OS.get_cmdline_user_args():suffix="saved-"
 if "--entry-only" in OS.get_cmdline_user_args():suffix+="entry-"
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800)
 if "--large" in OS.get_cmdline_user_args():set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string(Document.WIND_MEADOW_LARGE_PATH)))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--layout="):set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--layout="))))
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 var original=game.model;var features=game.world.map_features;original.gold-=123
 var workers=original.workers.duplicate(true);var gold=original.gold
 var entry_clock=Time.get_ticks_usec();game.open_map_editor();var opening_ms=(Time.get_ticks_usec()-entry_clock)/1000.0
 report.opening_ms=opening_ms;print("EDITOR_OPEN_MS ",opening_ms)
 check(game.model!=original and original.gold==gold and original.workers==workers,"Opening isolates the paused run and preserves worker data/gold")
 if "--baseline" not in OS.get_cmdline_user_args():check(game.world.map_features==features,"Opening reuses existing rendered terrain and scenery")
 if "--entry-only" in OS.get_cmdline_user_args():
  var clock=Time.get_ticks_usec();game.map_editor.close_discard();report.closing_ms=(Time.get_ticks_usec()-clock)/1000.0;print("EDITOR_CLOSE_MS ",report.closing_ms)
  check(game.model==original and game.model.gold==gold and game.model.workers==workers,"Discard restores the original run exactly")
  if "--baseline" not in OS.get_cmdline_user_args():check(game.world.map_features==features,"Discard retains compatible terrain and scenery")
  check(game.player.team_progression==original.team_progression,"Discard restores the player team-progression binding")
  await frames();var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  for i in 3:game.open_map_editor();game.map_editor.close_discard();await frames()
  check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources+2,"Repeated open/discard retains bounded nodes and resources")
  check(original.workers==workers and original.gold==gold,"Repeated entry preserves the original run")
  await finish();return
 await frames();game.set_process("--live" in OS.get_cmdline_user_args())
 report.measurement="live game with timed editor probe" if game.is_processing() else "manual editor tick with live rendering"
 if game.is_processing():suffix+="live-"
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 for size_ in ([] if "--tools-only" in OS.get_cmdline_user_args() else [game.preparation_map_frame().size,120.0]):
  for kind in ["","tower","tree","portal","road"]:
   game.map_editor.choose_piece(kind);game.pan=Vector3(80,0,70);game.preparation_size=size_;game.update_preparation_camera()
   var intervals=[];var ticks=[];var cold=[];var cpu=[];var gpu=[];var draws=[];var primitives=[];var previous=Time.get_ticks_usec()
   for i in 110:
    var motion=InputEventMouseMotion.new();motion.position=Vector2(500+i%25*5,250+i%12*3);motion.relative=Vector2(sin(i*.07)*3,cos(i*.07)*2);motion.button_mask=MOUSE_BUTTON_MASK_MIDDLE
    root.push_input(motion,true)
    var tick_clock=Time.get_ticks_usec()
    game.map_editor.tick(1.0/60.0)
    var tick_ms=(Time.get_ticks_usec()-tick_clock)/1000.0
    if i<20:cold.append(tick_ms)
    await process_frame
    var now=Time.get_ticks_usec()
    if i>=20:
     intervals.append((now-previous)/1000.0);ticks.append(tick_ms)
     cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()));gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
     draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
    previous=now
   var result={"tool":kind,"size":size_,"interval_ms":stats(intervals),"tick_ms":stats(ticks),"warmup_tick_ms":stats(cold),"render_cpu_ms":stats(cpu),"render_gpu_ms":stats(gpu),"draw_calls":stats(draws),"primitives":stats(primitives)}
   check(intervals.size()==90 and ticks.size()==90,"Pan scenario records every sampled frame")
   check(editor_unchanged(),"Pan/hover retains authored data and native ownership")
   if "--baseline" not in OS.get_cmdline_user_args():check(result.tick_ms.p95<5.0,"Pan cursor work stays below 5 ms at p95")
   report.scenarios.append(result);print("NAVIGATION ",JSON.stringify(result))
   if kind.is_empty() and DisplayServer.get_name()!="headless":
    RenderingServer.force_draw();root.get_texture().get_image().save_png(OUT+suffix+("large-" if "--large" in OS.get_cmdline_user_args() else "")+("before-" if "--baseline" in OS.get_cmdline_user_args() else "after-")+str(size_)+".png")
 var selections=[]
 for index in game.map_editor.palette_kinds.size():
  var editor=game.map_editor;editor.palette_page=index/9;editor.refresh_palette()
  var motion=InputEventMouseMotion.new();motion.position=Vector2(500,260);root.push_input(motion,true)
  var event=InputEventKey.new();event.physical_keycode=KEY_1+index%9;event.pressed=true
  var clock=Time.get_ticks_usec();root.push_input(event,true);var input_ms=(Time.get_ticks_usec()-clock)/1000.0
  clock=Time.get_ticks_usec();editor.tick(1.0/60.0);var preview_ms=(Time.get_ticks_usec()-clock)/1000.0
  clock=Time.get_ticks_usec();var dirty=editor.document.dirty;var dirty_ms=(Time.get_ticks_usec()-clock)/1000.0
  selections.append({"tool":editor.tool,"input_ms":input_ms,"preview_ms":preview_ms,"dirty_ms":dirty_ms,"selection_and_preview_ms":input_ms+preview_ms})
  event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
  check(editor.tool==editor.palette_kinds[index],"Palette keyboard navigation selects "+editor.palette_kinds[index])
 report.selections=selections;print("EDITOR_SELECTIONS ",JSON.stringify(selections))
 var editor=game.map_editor;editor.choose_piece("road");game.pan=Vector3(80,0,70);game.preparation_size=120;game.update_preparation_camera()
 var intervals=[];var work=[];var previous=Time.get_ticks_usec()
 for i in 120:
  var event=InputEventMagnifyGesture.new();event.position=Vector2(500,260);event.factor=1.01 if i%20<10 else 1/1.01
  var clock=Time.get_ticks_usec();root.push_input(event,true);editor.tick(1.0/60.0);work.append((Time.get_ticks_usec()-clock)/1000.0)
  await process_frame;var now=Time.get_ticks_usec();intervals.append((now-previous)/1000.0);previous=now
 var zoom={"tool":"road","navigation":"pinch","interval_ms":stats(intervals),"editor_ms":stats(work)};report.scenarios.append(zoom);print("NAVIGATION ",JSON.stringify(zoom))
 check(absf(game.preparation_size-120)<.001,"Repeated pinch/reverse restores the editor scale")
 check(zoom.editor_ms.p95<5.0,"Zoom cursor work stays below 5 ms at p95")
 var motion=InputEventMouseMotion.new();motion.position=editor.get_node("MapAssetPalette").get_global_rect().get_center();root.push_input(motion,true)
 editor.document.gate_validation_hash=-1;editor.tick(1.0/60.0)
 check(editor.document.gate_validation_hash==-1 and not game.world.preview.visible,"Palette hover skips map picking/validation and hides the ghost")
 editor.document.cache_preview(game.model)
 var pan=game.pan;Input.action_press("move_right");editor.tick(1.0/60.0);Input.action_release("move_right")
 check(game.pan.distance_to(pan)>0,"Keyboard navigation still pans")
 motion.position=Vector2(500,260);motion.relative=Vector2(100000,100000);motion.button_mask=MOUSE_BUTTON_MASK_MIDDLE;root.push_input(motion,true)
 var bounds=game.model.world_bounds().grow(-game.model.CELL)
 check(game.pan.x>=bounds.position.x and game.pan.z>=bounds.position.y and game.pan.x<=bounds.end.x and game.pan.z<=bounds.end.y,"Drag clamps immediately inside map bounds")
 check(editor_unchanged(),"Zoom and UI navigation retain the authored map")
 await finish()
func finish():
 var file=FileAccess.open(OUT+suffix+("large-" if "--large" in OS.get_cmdline_user_args() else "")+("before" if "--baseline" in OS.get_cmdline_user_args() else "after")+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames();DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("MAP_EDITOR_NAVIGATION_RESULT scenarios=%d checks=%d failures=%d"%[report.scenarios.size(),checks,failures]);quit(1 if failures else 0)

func editor_unchanged()->bool:
 return game.map_editor.document.history.is_empty() and not game.map_editor.document.dirty and game.model.army_runtime==game.army_runtime
