extends SceneTree
## Paired rendered crowd load; protected health keeps the population fighting.
class Field extends "res://scripts/forest/forest_game.gd":
 func award_team_kill(_reward_tenths:int=10,_source_id:int=0,_enemy_id:int=0):pass
 func _sync_camera_mouse():
  if is_instance_valid(camera_rig):camera_rig.sync_character_view()
const Metrics=preload("res://tests/forest-shrine/army_benchmark_metrics.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const OUT="res://build/Other Files/Asset Toolkit/Timed Dodge/Plain Crowd/"
var game
var count_=600
var seconds=45.0
var label_="600"
var home=Vector3(-120,0,125)
var points=PackedVector3Array()
var cursor=0
var dodges=0
var replacements=0
var errors:Array[String]=[]
var hashes={}

func _initialize():
 create_timer(300).timeout.connect(func():printerr("PLAIN_CROWD_TIMEOUT");quit(1))
 run.call_deferred()
func expect(ok:bool,message:String):
 if not ok and not errors.has(message):errors.append(message);printerr("FAIL: ",message)
func spawn_enemy():
 var at=points[cursor%points.size()];var kind=[0,1,3][cursor%3];cursor+=1
 var row=game.model.waves.spawn_enemy(kind,at)
 var army=game.army_runtime
 var handle:int=army.spawn(row.id,0,kind,at,row.hp,Roles.footprint_radius(kind))
 expect(handle!=0,"Enemy allocation failed")
 var target=army.enemy_target(row.id);game.actors[row.id]=target;game.enemies.append(target)
func reinforce(event:Dictionary):
 if event.team==0:
  game.model.waves.kill_spawn_pending=0;spawn_enemy();replacements+=1
func key():
 var e=InputEventKey.new();e.physical_keycode=KEY_SPACE;e.pressed=true;root.push_input(e,true)
 e.pressed=false;root.push_input(e,true)
func fingerprint()->Dictionary:
 var result={}
 for path in ["scripts/forest/timed_dodge.gd","scripts/crossgate_model.gd","scripts/crossgate_combat.gd","scripts/player.gd","scripts/forest/crowd/army_coordinator.gd","scripts/forest/crowd/army_runtime.gd","scripts/forest/crowd/army_presentation.gd","native/terrain_math/bin/libgoemon_terrain_math.macos.universal.dylib"]:result[path]=FileAccess.get_sha256("res://"+path)
 return result
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--count="):count_=int(arg.trim_prefix("--count="))
  if arg.begins_with("--seconds="):seconds=float(arg.trim_prefix("--seconds="))
  if arg.begins_with("--label="):label_=arg.trim_prefix("--label=")
 assert(count_>=100 and count_<=1000 and seconds>=5 and seconds<=100 and label_.is_valid_filename())
 if DisplayServer.get_name()=="headless":printerr("Requires desktop rendering");quit(2);return
 seed(71116);Engine.max_fps=0;Engine.time_scale=1
 set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_wind_meadow_large.json")))
 set_meta("forest_fighter",34);set_meta("forest_painterly_preview",true)
 root.size=Vector2i(1280,800);root.title="Goemon · Plain Dodge Crowd · %d"%count_
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true)
 DisplayServer.window_move_to_foreground();DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 DirAccess.make_dir_recursive_absolute(OUT)
 game=Field.new();game.settings_path="user://plain-crowd-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game
 if not game.combat_warmup.complete:await game.combat_warmup.finished
 game.settings.forest_pet_loadout=[];game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=false
 game.start_wave();game.model.survival_run=true
 var waves=game.model.waves
 waves.pending=0;waves.kill_spawn_pending=0;waves.wave_clock=1000000;waves.spawn_clock=1000000;waves.random_spawn_clock=1000000
 for b in game.model.buildings.values():b.hp=100000000
 var p=game.player;p.select_character(34);p.smoke_mode=true;p.smoke_move=Vector2.ZERO
 for stat in ["dodge_chance","counter_chance"]:game.update_character_tuning(34,stat,0)
 p.max_hp=10000000;p.hp=p.max_hp;p.set_auto_attack(true)
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000
 home.y=game.model.surface_height(home.x,home.z)+.05;p.position=home;p.velocity=Vector3.ZERO
 game.set_process_input(false);game.set_process_unhandled_input(false);game.camera_rig.set_process_unhandled_input(false);game.camera_rig.set_process(false)
 var m=game.model
 for x in range(m.navigation_region.position.x,m.navigation_region.end.x):
  for z in range(m.navigation_region.position.y,m.navigation_region.end.y):m.explored[Vector2i(x,z)]=true;m.visible_cells[Vector2i(x,z)]=true
 for attempt in 100000:
  var angle=attempt*2.399963229728653;var distance=sqrt(lerpf(10*10,110*110,fposmod(attempt*.6180339887,.99999)))
  var at=home+Vector3(cos(angle),0,sin(angle))*distance
  var cell=m.cell_of(at)
  if not m.enemy_grid.region.has_point(cell) or m.enemy_grid.is_point_solid(cell) or not m.terrain.contains(at.x,at.z) or not m.terrain.disk_clear(at,3.9):continue
  at.y=m.surface_height(at.x,at.z)+.12;points.append(at)
  if points.size()==count_:break
 expect(points.size()==count_,"Insufficient legal crowd spawn points")
 if points.is_empty():quit(1);return
 var army=game.army_runtime;army.collect_stats=true;army.profile_enabled=true;army.record_events=false
 for i in count_:spawn_enemy()
 army.unit_died.connect(reinforce)
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 var focus_deadline=Time.get_ticks_msec()+20000
 while not DisplayServer.window_is_focused() and Time.get_ticks_msec()<focus_deadline:await process_frame
 expect(DisplayServer.window_is_focused(),"Desktop did not receive focus")
 for i in 240:await physics_frame
 hashes=fingerprint()
 var stages=[]
 for enabled in [false,true]:
  dodges=0
  var frames=[];var gpu=[];var cpu=[];var rows=[];var spikes=[];var focused=0;var min_live=count_;var min_hp=p.hp
  var initial_events=army.observed_counts.duplicate();var first_sim=army.simulation_seconds
  var started=Time.get_ticks_usec();var previous=started;var last_sample=-1
  while (Time.get_ticks_usec()-started)*.000001<seconds:
   await process_frame
   var now=Time.get_ticks_usec();var elapsed=(now-started)*.000001;var ms=(now-previous)*.001;previous=now
   frames.append(ms);cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()));gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
   focused+=int(DisplayServer.window_is_focused());min_hp=minf(min_hp,p.hp)
   var phase_costs=army.profile_totals
   if ms>50 and spikes.size()<40:spikes.append({"seconds":elapsed,"ms":ms,"phases":phase_costs.duplicate()})
   army.profile_totals.clear()
   var camera=game.camera_rig.camera;camera.global_position=p.position+Vector3(50,65,75);camera.look_at(p.position+Vector3.UP*2)
   if enabled and p.timed_dodge.ready_to_dodge():
    key()
    if p.timed_dodge.reacting:
     dodges+=1
     expect(not p.timed_dodge.shadow_counter_enabled and p.timed_dodge.counter_source==0,"Default crowd dodge banked a counter")
     expect(not p.model.stat_counter_shadow.visible and p.model.kagerou_shadows.all(func(s):return not s.visible),"Default crowd dodge created a shadow")
   expect(game.playing and game.model.phase=="wave" and not game.paused,"Live battle stopped")
   if int(elapsed)!=last_sample:
    last_sample=int(elapsed)
    var live:int=army.latest.get("teams",PackedInt32Array()).count(0);min_live=mini(min_live,live)
    rows.append([elapsed,live,Performance.get_monitor(Performance.OBJECT_NODE_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),OS.get_static_memory_usage(),p.hp])
    if last_sample%10==0:print("PLAIN_CROWD_PROGRESS mode=",enabled," ",rows.back()," dodges=",dodges)
  var events={}
  for key_ in army.observed_counts:events[key_]=int(army.observed_counts[key_])-int(initial_events.get(key_,0))
  var result={"dodge":enabled,"seconds":(Time.get_ticks_usec()-started)*.000001,"frames":frames.size(),"frame_times":Metrics.summary(frames),"frame_ms":frames,"render_cpu":Metrics.summary(cpu),"render_gpu":Metrics.summary(gpu),"focused_fraction":float(focused)/maxi(1,frames.size()),"minimum_enemies":min_live,"dodges":dodges,"events":events,"rows":rows,"spikes":spikes,"simulation_seconds":army.simulation_seconds-first_sim,"minimum_player_hp":min_hp}
  expect(min_live==count_,"Crowd population was not maintained")
  expect(result.focused_fraction>=.95,"Foreground coverage fell below 95%")
  expect(result.frame_times.p95_ms<=25 and result.frame_times.p99_ms<=50,"Frame pacing exceeded existing 25/50 ms limits")
  expect(absf(result.simulation_seconds-result.seconds)<.5,"Native simulation fell behind wall time")
  if enabled:expect(dodges>=5,"Insufficient real Space dodges during crowd measurement")
  stages.append(result);print("PLAIN_CROWD_STAGE ",JSON.stringify(result.duplicate().merged({"frame_ms":[],"rows":[],"spikes":[]} ,true)))
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+label_+".png")
 expect(fingerprint()==hashes,"Gameplay source changed during measurement")
 var report={"enemies":count_,"stages":stages,"errors":errors,"source_hashes":hashes,"painterly":game.painterly_preview,"resolution":[root.size.x,root.size.y],"device":RenderingServer.get_rendering_device().get_device_name(),"replacements":replacements,"event_gaps":army.event_gaps,"diagnostic":"Protected player/objective health; no XP upgrades; unchanged enemy stats, AI, exact combat, art and live population. Counter/dodge chance stats are zero to isolate baseline Space; normal auto attacks continue. This is paired crowd-load evidence, not a normal-health survival soak."}
 FileAccess.open(OUT+label_+".json",FileAccess.WRITE).store_string(JSON.stringify(report))
 print("PLAIN_CROWD_RESULT errors=",errors," dodges=",dodges)
 var cfg=game.settings_path;game.queue_free();current_scene=null
 for i in 4:await process_frame
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if not errors.is_empty() else 0)
