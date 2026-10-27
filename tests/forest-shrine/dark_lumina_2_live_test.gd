extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Dark Lumina 2/Tuning/After/"
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
var samples=[]
func run():
 var map=preload("res://scripts/forest/forest_map_document.gd").new();map.load_wind_meadow()
 await setup_fixture(map.data)
 DisplayServer.window_set_title("Goemon · Dark Lumina 2 live tuning (DEBUG)");DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground()
 game.tuning.invincible=true
 var p=game.player;p.select_character(Dark.PLAYER);fresh()
 var origin=Vector3(0,game.model.surface_height(0,140)+.1,140);p.position=origin
 game.camera_rig.camera.global_position=origin+Vector3(36,31,44)
 game.camera_rig.camera.look_at(origin+Vector3(0,2,-12))
 var owner=game.army_runtime
 for i in 12:game.model.waves.spawn_enemy(Dark.ROLE,origin+Vector3((i%4-1.5)*15,0,-14-floori(i/4.0)*15))
 owner.import_arrivals();owner.sync_targets()
 game.set_physics_process(true);p.set_physics_process(true)
 p.model.show()
 var start=Time.get_ticks_msec();var shot_peak=0;var effects_peak=0;var nodes_before=0;var samples_live=[]
 var focused=0;var warm_resources=0.0;var warm_nodes=0
 var resource_samples=[]
 var frame_times=[];var previous=Time.get_ticks_usec()
 for frame in 1560:
  await process_frame
  var now=Time.get_ticks_usec()
  if frame>780 and frame not in [181,421,701]:frame_times.append((now-previous)/1000.0)
  previous=now
  if root.has_focus():focused+=1
  if frame in [120,360,600,840,1080,1320]:p.active_ability.start_dark_attack(Dark.FIRE)
  var counts=game.crowd.army.presentation.counts();shot_peak=maxi(shot_peak,counts.projectiles);effects_peak=maxi(effects_peak,counts.effects)
  if frame==120:nodes_before=counts.nodes
  if frame==780:warm_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);warm_nodes=get_node_count()
  if frame in [300,540,780,1020,1260,1559]:resource_samples.append({"frame":frame,"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"nodes":get_node_count()})
  if frame>=780:samples_live.append({"frame_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000})
  if frame in [180,420,700]:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+"live-%d.png"%frame)
 var current=game.crowd.army.presentation.counts()
 check(current.nodes==nodes_before,"Simultaneous native boss skills keep the prepared presentation node count stable")
 check(shot_peak>=12,"Many enemy fireballs are active together")
 var cpu=[];var physics=[]
 for row in samples_live:cpu.append(row.frame_ms);physics.append(row.physics_ms)
 cpu.sort();physics.sort()
 frame_times.sort()
 var result={"checks":checks,"failures":failures,"native_bosses":12,"player":29,"rendered_frames":1560,"focused_frames":focused,"wall_ms":Time.get_ticks_msec()-start,"cpu_frame_ms_p50":cpu[cpu.size()/2],"cpu_frame_ms_p95":cpu[int(cpu.size()*.95)],"physics_ms_p95":physics[int(physics.size()*.95)],"projectiles_peak":shot_peak,"effects_peak":effects_peak,"presentation_nodes":current.nodes,"resource_growth_after_warmup":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-warm_resources,"node_growth_after_warmup":get_node_count()-warm_nodes,"renderer":RenderingServer.get_video_adapter_name(),"note":"Rendered painterly desktop scene, twelve additional DL2 bosses; focus recorded separately; not a full default-wave stress benchmark"}
 result.resource_samples=resource_samples
 result.rendered_frame_ms={"p50":frame_times[frame_times.size()/2],"p95":frame_times[int(frame_times.size()*.95)],"p99":frame_times[int(frame_times.size()*.99)],"max":frame_times.back()}
 var file=FileAccess.open(OUT+"live-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
 print("DARK_LUMINA_LIVE_RESULT ",result)
 game.set_physics_process(false);p.set_physics_process(false);game.queue_free();await frames(4);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
