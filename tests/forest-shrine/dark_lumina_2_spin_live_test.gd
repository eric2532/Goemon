extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
const OUT="res://build/Other Files/Asset Toolkit/Dark Lumina 2/Spin and Walking/"
func tree_counts(node:Node,result:Dictionary):
 var script=node.get_script()
 var key=script.resource_path if script!=null else node.get_class()
 result[key]=result.get(key,0)+1
 for child in node.get_children():tree_counts(child,result)
func run():
 create_timer(180).timeout.connect(func():printerr("DL2_LIVE_TIMEOUT");quit(1))
 var map=preload("res://scripts/forest/forest_map_document.gd").new();map.load_wind_meadow()
 await setup_fixture(map.data)
 DisplayServer.window_set_title("Goemon · DL2 twelve-boss spin check (DEBUG)")
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground()
 game.tuning.invincible=true
 var p=game.player;p.select_character(Dark.PLAYER);fresh()
 var origin=Vector3(0,game.model.surface_height(0,140)+.1,140);p.position=origin
 game.camera_rig.camera.global_position=origin+Vector3(50,40,50);game.camera_rig.camera.look_at(origin+Vector3(0,3,-18))
 var owner=game.army_runtime
 for i in 12:game.model.waves.spawn_enemy(Dark.ROLE,origin+Vector3((i%4-1.5)*15,0,-12-floori(i/4.0)*15))
 owner.import_arrivals();owner.sync_targets()
 game.set_process_input(false);game.set_process_unhandled_input(false);p.set_process_input(false);p.set_process_unhandled_input(false)
 game.set_physics_process(true);p.set_physics_process(true);p.model.show()
 var previous=Time.get_ticks_usec();var intervals=[];var focused=0;var samples=[]
 var spin_units={};var spin_frames=0;var warmed_nodes=0;var warmed_resources=0.0
 var peak_dust=0;var peak_debris=0;var presentation_nodes=0;var before_tree={};var cpu=[];var physics=[]
 for frame in 1800:
  await process_frame
  var now=Time.get_ticks_usec()
  if frame>901 and frame!=1201:
   intervals.append((now-previous)/1000.0);cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000);physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
  previous=now
  if root.has_focus():focused+=1
  if frame in [120,300,480,660,840,1020,1200,1380,1560]:p.active_ability.start_dark_attack(Dark.SPIN)
  game.camera_rig.camera.global_position=origin+Vector3(50,40,50);game.camera_rig.camera.look_at(origin+Vector3(0,3,-18))
  var presentation=game.crowd.army.presentation
  peak_dust=maxi(peak_dust,presentation.batches["dark-spin_dust"].multimesh.visible_instance_count)
  peak_debris=maxi(peak_debris,presentation.batches["dark-spin_debris"].multimesh.visible_instance_count)
  var snapshot=owner.latest
  if snapshot.has("actions"):
   for i in snapshot.actions.size():
    if snapshot.kinds[i]==Dark.ROLE and snapshot.actions[i]==217:spin_units[snapshot.handles[i]]=true;spin_frames+=1
  if frame==900:
   warmed_nodes=get_node_count();warmed_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);presentation_nodes=presentation.get_child_count();tree_counts(root,before_tree)
  if frame in [900,1200,1500,1799]:samples.append({"frame":frame,"nodes":get_node_count(),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
  if frame in [145,700,1200]:
   await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"live-%d.png"%frame)
 check(not spin_units.is_empty(),"Native enemies reach recovered spin in ordinary AI combat")
 check(peak_dust>=16 and peak_debris>=2,"Ordinary combat presents dust and original floor debris")
 check(game.crowd.army.presentation.get_child_count()==presentation_nodes,"Repeated native/player spins keep prepared presentation nodes stable")
 var after_tree={};tree_counts(root,after_tree);var growth={}
 for key in after_tree:
  if after_tree[key]!=before_tree.get(key,0):growth[key]=after_tree[key]-before_tree.get(key,0)
 intervals.sort();cpu.sort();physics.sort()
 var result={"checks":checks,"failures":failures,"rendered_frames":1800,"focused_frames":focused,"native_spin_units":spin_units.size(),"native_spin_frames":spin_frames,"dust_peak":peak_dust,"debris_peak":peak_debris,"node_growth_after_warmup":get_node_count()-warmed_nodes,"resource_growth_after_warmup":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-warmed_resources,"resource_samples":samples,"rendered_frame_ms":{"p50":intervals[intervals.size()/2],"p95":intervals[int(intervals.size()*.95)],"p99":intervals[int(intervals.size()*.99)],"max":intervals.back()},"renderer":RenderingServer.get_video_adapter_name(),"node_changes_by_script":growth,"presentation_nodes":presentation_nodes,"simulation_steps":owner.simulation_steps,"ordinary_pause":game.ordinary_pause,"cpu_monitor_p95_ms":cpu[int(cpu.size()*.95)],"physics_monitor_p95_ms":physics[int(physics.size()*.95)],"note":"Normal painterly scene with twelve additional bosses; short run, not a full-wave stress test or controlled performance comparison"}
 FileAccess.open(OUT+"live-results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("DARK_LUMINA_SPIN_LIVE_RESULT ",result)
 game.set_physics_process(false);p.set_physics_process(false);game.queue_free();await frames(4);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
