extends "res://tests/forest-shrine/dark_lumina_3_test.gd"
const STAGE=Vector3(0,.1,110)
var frame_times=[]
var wall_times=[]
var capture_dir=OUT+"Wind And Energy/Army/"
func capture(name_:String):
 await process_frame
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png(capture_dir+name_+".png")
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_dir))
 await setup_fixture()
 root.title="Goemon · Dark Lumina 3 verification"
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
 game.player.set_process_input(false);game.player.set_process_unhandled_input(false);game.camera_rig.set_process_unhandled_input(false)
 await frames(3)
 game.paused=false;game.ordinary_pause=false;game.settings_open=false;game.rogue_roster_open=false;paused=false
 var p=game.player;p.select_character(30);fresh();p.position=STAGE;p.hp=100000;p.max_hp=100000
 verify_scale_and_media(p,game.crowd.army.presentation)
 game.training_dummy.home=STAGE+Vector3(0,0,-8);game.training_dummy.position=game.training_dummy.home
 for building in game.model.buildings.values():building.hp=10000000;building.max_hp=10000000
 game.tuning.invincible=true
 game.training_dummy.hide()
 game.ui.hide();game.camera_rig.camera.position=STAGE+Vector3(10,8,14)*Finale.SCALE;game.camera_rig.camera.look_at(STAGE+Vector3(0,1,-5)*Finale.SCALE)
 var sound_bus=AudioServer.get_bus_index("SFX");var sound_capture=AudioEffectCapture.new();var capture_slot=AudioServer.get_bus_effect_count(sound_bus)
 var sound_peak=0.0;var sound_frames=0
 AudioServer.add_bus_effect(sound_bus,sound_capture)
 for move in 6:
  fresh();p.position=STAGE;p.active_ability.start_move(move)
  var snap=[130,100,120,120,42,155][move]
  var earth_release=-1
  for tick in ceili((Finale.moves[move].size()/p.active_ability.CAST_RATE+60)*2):
   var start=Time.get_ticks_usec()
   p._physics_process(1.0/60)
   game.crowd.army.presentation.tick(1.0/60)
   game.crowd.army.presentation.draw_effects()
   frame_times.append((Time.get_ticks_usec()-start)/1000.0)
   await physics_frame
   var audio=sound_capture.get_buffer(sound_capture.get_frames_available());sound_frames+=audio.size()
   for sample in audio:sound_peak=maxf(sound_peak,maxf(absf(sample.x),absf(sample.y)))
   if move==0 and tick==roundi(180/p.active_ability.CAST_RATE):await capture("move-0-sword-rush")
   if move==4 and earth_release<0 and p.active_ability.marker>40:earth_release=tick
   if (move==4 and earth_release>=0 and tick==earth_release+12) or (move!=4 and tick==roundi(snap*2/p.active_ability.CAST_RATE)):await capture("move-%d-%s"%[move,Finale.NAMES[move].to_lower()])
  check(not p.active_ability.is_attacking(),"Rendered move %d advances to completion"%move)
  p.cancel_charge()
 check(sound_frames>0 and sound_peak>.000001,"Rendered skills produce non-silent audio on the live SFX bus")
 # Exercise the same NPC owner with simultaneous final bosses and ordinary troops.
 p.select_character(1);fresh();p.position=STAGE;p.hp=100000;p.max_hp=100000
 var count_before=game.model.enemies.size()
 game.camera_rig.camera.position=STAGE+Vector3(24,24,32);game.camera_rig.camera.look_at(STAGE+Vector3(0,2,-8))
 check(not game.army_runtime.blocked(),"Native fixture is running")
 for i in 6:game.model.waves.spawn_enemy(18,STAGE+Vector3((i-2.5)*4,0,-14))
 for i in 120:game.model.waves.spawn_enemy([0,1,3,6,9,16][i%6],STAGE+Vector3((i%20-10)*3,0,-25-(i/20)*4))
 game.army_runtime.import_arrivals();game.army_runtime.record_events=true
 var nodes=game.crowd.army.presentation.counts().nodes;var samples=[];var casts={}
 var previous=Time.get_ticks_usec()
 for tick in 3600:
  p.hp=100000;p.invuln=1
  var start=Time.get_ticks_usec();game.army_runtime.integration_tick(1.0/60);samples.append((Time.get_ticks_usec()-start)/1000.0)
  for event in game.army_runtime.event_log:
   if event.get("unit_kind",-1)==18 and event.kind=="status" and event.action_index>=300 and event.action_index<306:casts[event.action_index]=true
  game.army_runtime.event_log.clear()
  if tick%600==0:print("FINAL_ENCOUNTER_PROGRESS ",tick," steps=",game.army_runtime.simulation_steps," blocked=",game.army_runtime.blocked()," phase=",game.model.phase," paused=",game.paused)
  await physics_frame
  var now=Time.get_ticks_usec()
  var audio=sound_capture.get_buffer(sound_capture.get_frames_available());sound_frames+=audio.size()
  for sample in audio:sound_peak=maxf(sound_peak,maxf(absf(sample.x),absf(sample.y)))
  if tick>120:wall_times.append((now-previous)/1000.0)
  previous=now
  if tick in [120,900,1800,2700,3500]:await capture("native-%d"%tick)
 check(game.army_runtime.simulation_steps>=3600,"Every encounter physics step executes")
 check(game.crowd.army.presentation.counts().nodes==nodes,"Simultaneous native boss effects keep a fixed presentation node count")
 check(casts.size()==6,"Native encounter reaches all six move families")
 game.crowd.army.presentation.finale_cue(STAGE,30)
 for tick in 80:
  game.crowd.army.presentation.tick(1.0/60);await physics_frame
  if tick==45:await capture("core-defeat")
 check(sound_peak<=1.0,"Player and simultaneous native effects keep mixer headroom")
 AudioServer.remove_bus_effect(sound_bus,capture_slot)
 samples.sort();frame_times.sort();wall_times.sort()
 var report={"scale":Finale.SCALE,"audio_frames":sound_frames,"audio_peak":sound_peak,"wall_frame_ms_p95":wall_times[floori(wall_times.size()*.95)],"wall_frame_ms_median":wall_times[wall_times.size()/2],"wall_frame_ms_max":wall_times[-1],"cast_families":casts.keys(),"simulation_steps":game.army_runtime.simulation_steps,"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"troops":120,"final_bosses":6,"existing_enemies":count_before,"native_step_ms_median":samples[samples.size()/2],"native_step_ms_p95":samples[floori(samples.size()*.95)],"native_step_ms_max":samples[-1],"player_step_ms_p95":frame_times[floori(frame_times.size()*.95)],"presentation":game.crowd.army.presentation.counts(),"process_time_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000}
 FileAccess.open(capture_dir+"rendered-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("DARK_LUMINA_3_RENDERED_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
