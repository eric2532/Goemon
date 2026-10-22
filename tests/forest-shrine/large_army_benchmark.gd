extends SceneTree
## Real foreground game, normal kit stats, explicit per-death reinforcements.
class Battle extends "res://scripts/forest/forest_game.gd":
 # The scripted camera never needs mouse capture; leave the user's pointer
 # available so leaving this profiling window does not require pausing combat.
 func _sync_camera_mouse():
  if is_instance_valid(camera_rig) and camera_rig.has_method("sync_character_view"):camera_rig.sync_character_view()
  if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
const Metrics=preload("res://tests/forest-shrine/army_benchmark_metrics.gd")
var game
var army
var enemy_count=240
var ally_count=96
var scenario="castle"
var duration=8.0
var out="/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Large Army Rebuild/Benchmarks"
var diagnostic=false
var options={}
var phase="loading"
var spawn_started=0
var started=0
var previous=0
var initial_sim=0.0
var initial_steps=0
var initial_worker_jobs=0
var initial_helper_overlaps=0
var frames_ms=[]
var cpu_ms=[]
var gpu_ms=[]
var memory=[]
var min_enemy=100000
var min_ally=100000
var replacements=0
var initial_counts={}
var initial_replacements=0
var reveal={}
var enemy_points=PackedVector3Array()
var ally_points=PackedVector3Array()
var enemy_cursor=0
var ally_cursor=0
var stopped=false
var focus_frames=0
var status_second=0
var start_memory=0
var initial_presentations=0
var initial_retirement_visits=0
var initial_registered_updates=0
var initial_registered_fallbacks=0
var activity=[]
var bucket_time=0.0
var bucket_counts={}
var fingerprints={}
var source_revision=""
var collapse_done=false
var topology_events=[]
var engine_physics=[]
var engine_process=[]
var collision_pairs=[]
func _initialize():
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--"):
   var parts=argument.substr(2).split("=",true,1);options[parts[0]]=parts[1] if parts.size()>1 else "true"
 enemy_count=int(options.get("per-team","240"));ally_count=int(options.get("allies",str(enemy_count)));scenario=options.get("scenario","castle");duration=float(options.get("duration","8"));out=options.get("out",out);diagnostic=options.has("diagnostic")
 setup.call_deferred()
func setup():
 if enemy_count<1 or enemy_count>2000 or ally_count<1 or ally_count>2000 or scenario not in ["open","castle","collapse"]:printerr("Invalid benchmark parameters");quit(2);return
 seed(71021);Engine.time_scale=1;Engine.physics_ticks_per_second=60;Engine.max_physics_steps_per_frame=64;Engine.max_fps=0;OS.low_processor_usage_mode=false
 root.size=Vector2i(1280,800);root.title="Goemon · Large Army Benchmark · %d enemies + %d allies"%[enemy_count,ally_count]
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 set_meta("forest_army_guard_poses",not options.has("always-write-poses"));set_meta("forest_army_parallel_movement",not options.has("serial-movement"));set_meta("forest_army_query_static",not options.has("kinematic-proxies"));set_meta("forest_army_backend","native");set_meta("forest_army_worker",not options.has("synchronous"));set_meta("forest_army_shared_snapshots",not options.has("eager-facades"));set_meta("forest_fighter",11);set_meta("forest_painterly_preview",true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new()
 if options.get("map","kai_highway")=="blood_gulch":doc.load_blood_gulch()
 else:doc.load_kai_highway()
 set_meta("forest_custom_layout",doc.data)
 set_meta("forest_army_mesh_lods",not options.has("full-detail"))
 set_meta("forest_army_bounded_queries",not options.has("full-combat-scans"))
 game=Battle.new();game.settings_path="user://large-army-benchmark-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 for i in 3:await process_frame
 set_meta("forest_army_registered_facades",not options.has("generic-facades"))
 set_meta("forest_army_plain_fields",not options.has("guarded-field-writes"))
 set_meta("forest_army_profile_facades",options.has("profile-facades"))
 army=game.army_runtime;army.collect_stats=true;army.profile_enabled=true;army.compact_scene_events=not options.has("full-scene-events")
 if options.has("await-focus") and DisplayServer.get_name()!="headless":
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true)
  DisplayServer.window_move_to_foreground()
  var focus_started=Time.get_ticks_msec()
  while not DisplayServer.window_is_focused():
   if Time.get_ticks_msec()-focus_started>60000:printerr("FAIL: Foreground test window did not receive focus within60s");quit(2);return
   await process_frame
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 var center:Vector3=game.model.center(game.model.buildings.values().filter(func(b):return b.kind=="shrine")[0]);var radius=0.0
 for b in game.model.buildings.values():
  if b.kind in ["wall","gate"]:radius=maxf(radius,Vector2(game.model.center(b).x-center.x,game.model.center(b).z-center.z).length())
 print("BENCHMARK_LAYOUT source=",game.model.terrain_source," center=",center," fort_radius=",radius," hills=",game.model.terrain.heights.size()," bridges=",game.model.terrain.bridges.count(1))
 for x in range(game.model.navigation_region.position.x,game.model.navigation_region.end.x):
  for z in range(game.model.navigation_region.position.y,game.model.navigation_region.end.y):reveal[Vector2i(x,z)]=true
 var focus=center+Vector3(0,0,110) if scenario=="open" else center
 enemy_points=spawn_points(focus,radius+13 if scenario!="open" else 8,radius+135 if scenario!="open" else 90,3.9,enemy_count)
 ally_points=spawn_points(focus,radius+2 if scenario!="open" else 2,radius+20 if scenario!="open" else 45,.4,ally_count)
 if enemy_points.size()<enemy_count or ally_points.size()<ally_count:printerr("Not enough legal native terrain spawn points");quit(2);return
 game.start_wave();root.title="Goemon Army Benchmark %d + %d"%[enemy_count,ally_count];root.grab_focus()
 game.model.waves.pending=100000000;game.model.waves.spawn_clock=100000000
 game.model.visible_cells=reveal.duplicate();game.model.explored=reveal.duplicate()
 game.player.position=center+Vector3(0,2,12);game.player.velocity=Vector3.ZERO
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 game.camera_rig.camera.global_position=focus+Vector3(120,155,175);game.camera_rig.camera.look_at(focus+Vector3.UP*3);game.camera_rig.camera.fov=65
 spawn_started=Time.get_ticks_usec()
 for i in enemy_count:spawn_enemy()
 for i in ally_count:spawn_ally(i%5)
 game.explorer_helpers.sync_targets();army.import_arrivals()
 army.unit_died.connect(reinforce)
 # Let actual physics own all action/animation clocks throughout warmup.
 var press=InputEventAction.new();press.action="light_attack";press.pressed=true;Input.parse_input_event(press);Input.flush_buffered_events()
 for path in ["scripts/player.gd","scripts/forest/forest_game.gd","scripts/forest/crowd/army_coordinator.gd","scripts/forest/crowd/army_runtime.gd","scripts/forest/forest_gate_defenders.gd","scripts/forest/crowd/army_snapshot.gd","scripts/forest/crowd/army_enemy_target.gd","scripts/forest/crowd/army_ally_target.gd","scripts/forest/crowd/army_helper_unit.gd","scripts/forest/forest_workforce.gd","scripts/forest/forest_ryo_economy.gd","scripts/forest/forest_thirstquencher_visual.gd","assets/materials/thirstquencher_crowd.gdshader","assets/materials/ally_crowd.gdshader","scripts/forest/crowd/army_renderer.gd","scripts/forest/explorer_helpers.gd","native/terrain_math/crowd/core.cpp","native/terrain_math/crowd/terrain.cpp","native/terrain_math/crowd/terrain.h","native/terrain_math/crowd/combat.cpp","native/terrain_math/crowd_binding.cpp","native/terrain_math/bin/libgoemon_terrain_math.macos.universal.dylib"]:fingerprints[path]=FileAccess.get_sha256("res://"+path)
 for path in ["scripts/forest/crowd/army_mesh_lod.gd","assets/characters/ally_crowd/lod_11.res","assets/characters/ally_crowd/lod_5.res","assets/characters/ally_crowd/lod_7.res","assets/characters/ally_crowd/lod_8.res","assets/characters/ally_crowd/lod_10.res"]:fingerprints[path]=FileAccess.get_sha256("res://"+path)
 var revision_output=[]
 if OS.execute("/usr/bin/git",["-C",ProjectSettings.globalize_path("res://"),"rev-parse","HEAD"],revision_output)==0:source_revision=str(revision_output[0]).strip_edges()
 phase="warmup"
 await create_timer(2.0).timeout
 initial_replacements=replacements
 initial_retirement_visits=int(army.get("retirement_rows_visited")) if army.get("retirement_rows_visited")!=null else 0
 initial_registered_updates=army.registered_facade_updates;initial_registered_fallbacks=army.registered_facade_fallbacks
 start_memory=OS.get_static_memory_usage();initial_counts=army.observed_counts.duplicate(true);initial_sim=army.simulation_seconds;initial_steps=army.simulation_steps;initial_worker_jobs=army.worker_jobs;initial_helper_overlaps=army.helper_overlap_calls;initial_presentations=army.presentation_frames;army.profile_totals.clear();army.native.simulation_profile(true);army.native.query_stats(true);bucket_counts=army.observed_counts.duplicate(true)
 root.grab_focus()
 started=Time.get_ticks_usec();previous=started;phase="measuring"
 print("BENCHMARK_STATE ",JSON.stringify(blocked_state()))
 print("BENCHMARK_STARTED enemies=",enemy_count," allies=",ally_count," scenario=",scenario," duration=",duration," pid=",OS.get_process_id()," spawn_warmup_ms=",(started-spawn_started)/1000.0)
func spawn_points(center:Vector3,near:float,far:float,radius:float,wanted:int)->PackedVector3Array:
 var points=PackedVector3Array();var m=game.model;var grid=m.enemy_grid if radius>1 else m.allied_grid
 for attempt in maxi(100000,wanted*200):
  var angle=float(attempt)*2.399963229728653;var u=fposmod(float(attempt)*.618033988749895,.999999)
  var distance=sqrt(lerpf(near*near,far*far,u));var p=center+Vector3(cos(angle),0,sin(angle))*distance;var cell=m.cell_of(p)
  if not grid.region.has_point(cell) or grid.is_point_solid(cell) or not m.terrain.contains(p.x,p.z) or not m.terrain.disk_clear(p,radius):continue
  p.y=m.surface_height(p.x,p.z)+.12;points.append(p)
  if points.size()>=wanted:break
 return points
func spawn_enemy():
 var kind=[0,1,3][enemy_cursor%3];var point:Vector3=enemy_points[enemy_cursor%enemy_points.size()];enemy_cursor+=1
 var row=game.model.waves.spawn_enemy(kind,point)
 var handle:int=army.spawn(row.id,0,kind,point,row.hp,load("res://scripts/forest/forest_enemy_roles.gd").footprint_radius(kind))
 if handle==0:printerr("FAIL: Reinforcement enemy allocation rejected");stopped=true;return
 var actor=army.enemy_target(row.id);game.actors[row.id]=actor;game.enemies.append(actor)
func spawn_ally(slot:int,unit:Node=null):
 var h=game.explorer_helpers
 if unit==null:unit=h.make_unit(slot)
 var point:Vector3=ally_points[ally_cursor%ally_points.size()];ally_cursor+=1
 unit.summon(null,point,0)
 if not army.valid(unit.handle):printerr("FAIL: Reinforcement ally allocation rejected");stopped=true
func reinforce(event:Dictionary):
 if stopped:return
 if event.team==0:spawn_enemy()
 else:
  var unit=army.allies.get(event.target_id)
  if is_instance_valid(unit):spawn_ally(unit.slot,unit)
  else:printerr("FAIL: Dead ally lost its owned facade");stopped=true
 replacements+=1
func blocked_state()->Dictionary:
 var state={"tree_paused":paused,"model_phase":game.model.phase,"player_hp":game.player.hp}
 for field in ["playing","paused","ordinary_pause","settings_open","rogue_roster_open","transitioning","camera_focused"]:state[field]=game.get(field)
 state.map_editor=game.map_editor.active
 return state
func _process(_delta:float)->bool:
 if phase!="measuring":return false
 var now=Time.get_ticks_usec()
 if DisplayServer.get_name()!="headless" and DisplayServer.window_is_focused():focus_frames+=1
 var elapsed=(now-started)/1000000.0
 if scenario=="collapse" and not collapse_done and elapsed>=minf(15,duration*.25):
  collapse_done=true;var breach_started=Time.get_ticks_usec();var gates=[]
  for b in game.model.buildings.values().duplicate():
   if b.kind=="gate" and not b.get("breached",false):gates.append(b.id);game.model.damage_building(b.id,b.hp+1)
  game.world.sync(0);topology_events.append({"seconds":elapsed,"gates":gates,"synchronous_ms":(Time.get_ticks_usec()-breach_started)/1000.0})
 if elapsed>=bucket_time+10:
  append_activity(elapsed)
 if int((now-started)/1000000)>=status_second+10:
  status_second=int((now-started)/1000000);print("BENCHMARK_PROGRESS seconds=",status_second," frames=",frames_ms.size()," active=",army.latest.teams.count(0),"/",army.latest.teams.count(1)," events=",army.observed_counts," blocked=",blocked_state())
 frames_ms.append((now-previous)/1000.0);previous=now
 var snapshot:Dictionary=army.latest
 if snapshot.has("teams"):
  min_enemy=mini(min_enemy,snapshot.teams.count(0));min_ally=mini(min_ally,snapshot.teams.count(1))
 engine_physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000);engine_process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000);collision_pairs.append(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
 cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()));gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
 if memory.is_empty() or (now-started)/1000000>memory.back()[0]+1:memory.append([(now-started)/1000000.0,OS.get_static_memory_usage(),Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
 if not game.playing or game.model.phase!="wave" or stopped or now-started>=duration*1000000:
  phase="finished";finish.call_deferred()
 return false
func append_activity(elapsed:float):
 var counts=army.observed_counts
 var event_count=func(key):return int(counts.get(key,0))-int(bucket_counts.get(key,0))
 activity.append({"seconds":elapsed-bucket_time,"attacks":event_count.call("melee")+event_count.call("bullet")+event_count.call("landing_pulse"),"damage_events":event_count.call("damage")+event_count.call("external_damage"),"deaths":event_count.call("death")})
 bucket_time=elapsed;bucket_counts=counts.duplicate(true)
func finish():
 stopped=true
 Input.action_release("light_attack")
 var elapsed=(Time.get_ticks_usec()-started)/1000000.0;var counts={}
 for key in army.observed_counts:counts[key]=int(army.observed_counts[key])-int(initial_counts.get(key,0))
 append_activity(elapsed)
 var steps=maxi(1,army.simulation_steps-initial_steps);var cpu={}
 for key in army.profile_totals:cpu[key]=army.profile_totals[key]/steps
 var report={"enemies":enemy_count,"allies":ally_count,"minimum_enemies":min_enemy,"minimum_allies":min_ally,"scenario":scenario,"wall_seconds":elapsed,"simulation_seconds":army.simulation_seconds-initial_sim,"frames":frames_ms.size(),"attacks":int(counts.get("melee",0))+int(counts.get("bullet",0))+int(counts.get("landing_pulse",0)),"damage_events":int(counts.get("damage",0))+int(counts.get("external_damage",0)),"deaths":int(counts.get("death",0)),"replacements":replacements-initial_replacements,"foreground":DisplayServer.get_name()!="headless" and RenderingServer.get_rendering_device()!=null and float(focus_frames)/maxi(1,frames_ms.size())>=.95,"focus_fraction":float(focus_frames)/maxi(1,frames_ms.size()),"gpu_timing_available":gpu_ms.any(func(ms):return ms>0),"normal_stats":not game.tuning.invincible and not game.tuning.freeze_ai and Engine.time_scale==1,"frame_ms":frames_ms,"dropped_hits":army.event_gaps,"fps":frames_ms.size()/maxf(.001,elapsed),"frame_times":Metrics.summary(frames_ms),"render_cpu":Metrics.summary(cpu_ms),"render_gpu":Metrics.summary(gpu_ms),"physics_phases_ms":cpu,"events":counts,"spawn_warmup_ms":(started-spawn_started)/1000.0,"memory_samples":memory,"initial_memory":start_memory,"final_memory":OS.get_static_memory_usage(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"presentation":game.crowd.army.counts(),"terrain_source":game.model.terrain_source,"terrain_hash":FileAccess.get_sha256("res://assets/maps/%s/surface.res"%game.model.terrain_source),"map_hash":FileAccess.get_sha256("res://assets/maps/forest_%s.json"%game.model.terrain_source),"device":RenderingServer.get_rendering_device().get_device_name() if RenderingServer.get_rendering_device()!=null else "headless","processor":OS.get_processor_name(),"process_id":OS.get_process_id(),"resolution":[root.size.x,root.size.y]}
 report.mesh_lods=get_meta("forest_army_mesh_lods")
 report.bounded_combat_queries=get_meta("forest_army_bounded_queries")
 report.compact_scene_events=army.compact_scene_events
 report.registered_facades=get_meta("forest_army_registered_facades") and get_meta("forest_army_plain_fields") and not get_meta("forest_army_profile_facades")
 report.registered_facade_updates=army.registered_facade_updates-initial_registered_updates;report.registered_facade_fallbacks=army.registered_facade_fallbacks-initial_registered_fallbacks
 report.plain_fields=get_meta("forest_army_plain_fields");report.profile_facades=get_meta("forest_army_profile_facades")
 # Godot publishes the previous one-second maximum, not each tick duration.
 report.engine_monitor_sampling="Per-render samples of Godot one-second maxima; not per-tick averages"
 report.guarded_poses=get_meta("forest_army_guard_poses");report.shared_snapshot_enabled=army.shared_snapshot_enabled
 report.query_proxies_static=get_meta("forest_army_query_static");report.worker_enabled=army.worker_enabled;report.worker_jobs=army.worker_jobs-initial_worker_jobs;report.helper_overlap_calls=army.helper_overlap_calls-initial_helper_overlaps
 report.engine_physics_ms=Metrics.summary(engine_physics);report.engine_process_ms=Metrics.summary(engine_process);report.collision_pairs=Metrics.summary(collision_pairs)
 report.retirement_rows_visited=int(army.get("retirement_rows_visited"))-initial_retirement_visits if army.get("retirement_rows_visited")!=null else -1
 report.presentation_frames=army.presentation_frames-initial_presentations
 var kernel:Dictionary=army.native.simulation_profile(false);report.native_phases_ms={}
 for key in ["total_ms","grid_ms","decisions_ms","movement_ms","combat_ms","animation_ms"]:report.native_phases_ms[key]=kernel[key]/maxi(1,kernel.steps)
 report.facade_phases_ms={}
 for key in kernel:
  if key.begins_with("facade_") and key.ends_with("_ms"):report.facade_phases_ms[key]=kernel[key]/maxi(1,kernel.steps)
 report.navigation_work={}
 for key in kernel:
  if key.begins_with("nav_"):report.navigation_work[key]=kernel[key]/maxi(1,kernel.steps) if key.ends_with("_ms") else kernel[key]
 report.movement_jobs=kernel.movement_jobs;report.parallel_movement=get_meta("forest_army_parallel_movement");report.shared_enemy_updates=kernel.shared_enemy_updates;report.shared_ally_updates=kernel.shared_ally_updates
 report.native_query_work=army.native.query_stats(false);report.native_query_work.air_considered=kernel.air_considered;report.native_query_work.air_kept=kernel.air_kept;report.native_query_work.capsule_tests=kernel.capsule_tests
 report.presentation_ms_per_render=float(army.profile_totals.get("presentation",0)+army.profile_totals.get("presentation_tick",0))/maxi(1,report.presentation_frames)
 report.activity=activity;report.source_revision=source_revision;report.source_hashes=fingerprints;report.topology_events=topology_events
 if not report.gpu_timing_available:report.render_gpu=null
 report.blocked_state=blocked_state()
 report.errors=Metrics.violations(report)
 if elapsed<duration-.2:report.errors.append("Battle stopped before requested duration")
 DirAccess.make_dir_recursive_absolute(out)
 var stem="%s-%d-%d-%d"%[scenario,enemy_count,ally_count,int(Time.get_unix_time_from_system())]
 var file=FileAccess.open(out+"/"+stem+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 if DisplayServer.get_name()!="headless":
  root.get_texture().get_image().save_png(out+"/"+stem+".png")
 report.erase("frame_ms");report.erase("memory_samples");print("LARGE_ARMY_RESULT ",JSON.stringify(report))
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 quit(0 if report.errors.is_empty() or diagnostic else 1)
