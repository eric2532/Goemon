extends "res://tests/forest-shrine/dark_lumina_3_controls_test.gd"
const COMPLETE_OUT=OUT+"Completeness/"
const Shot=preload("res://scripts/dark_lumina_3_projectile.gd")
const STAGE=Vector3(0,.1,110)
var heard=[]
var released=[]
var voice_order=0
var recorder:AudioEffectRecord
var recording_slot=-1
var mixed=[]
var victim:Node
var blade_only=false
func advance(count:int):
 var previous=Time.get_ticks_usec()
 for i in count:
  var begin=Time.get_ticks_usec()
  game.player._physics_process(1.0/60)
  for nodes in Pool.service(game).all.values():
   for shot in nodes:
    if shot.pool_live and shot.get_script() in [Shot,WaveShot]:shot._physics_process(1.0/60)
  game.crowd.army.presentation.tick(1.0/60)
  for voice in game.voices:
   if int(voice.get_meta("order",0))>voice_order:heard.append(str(voice.get_meta("kind","")))
  voice_order=game.voice_idx;step_times.append((Time.get_ticks_usec()-begin)/1000.0)
  if visual:
   await physics_frame
   var now=Time.get_ticks_usec();frame_times.append((now-previous)/1000.0);previous=now
  elif i%30==0:await process_frame
func fresh(surge:bool=false):
 super.fresh(surge);game.player.position=STAGE
func save_view(label_:String):
 if not visual:return
 game.crowd.army.presentation.draw_effects();RenderingServer.force_draw()
 root.get_texture().get_image().save_png(COMPLETE_OUT+label_+".png")
func begin_audio():
 heard.clear();voice_order=game.voice_idx
 if recorder:recorder.set_recording_active(true)
func save_audio(label_:String):
 if not recorder:return
 await create_timer(.25).timeout
 recorder.set_recording_active(false)
 var result=recorder.get_recording()
 check(result!=null and result.data.count(0)<result.data.size(),"Recorded live audio for "+label_)
 if result:check(result.save_to_wav(COMPLETE_OUT+label_+".wav")==OK,"Saved listening capture for "+label_)
func run():
 create_timer(220).timeout.connect(func():printerr("FINALE_COMPLETENESS_TIMEOUT");quit(1))
 visual=DisplayServer.get_name()!="headless"
 blade_only="--blade-only" in OS.get_cmdline_user_args()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(COMPLETE_OUT))
 await setup_fixture()
 root.title="Goemon · Dark Lumina 3 complete effects and sound"
 root.set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
 game.player.set_process_input(false);game.player.set_process_unhandled_input(false)
 game.camera_rig.set_process_unhandled_input(false);game.model.phase="wave";game.tuning.invincible=true
 game.settings.volume=.65;game.settings.music_enabled=false;game.apply_music_setting()
 var p=game.player;p.select_character(30);fresh();var c=p.active_ability;var presentation=game.crowd.army.presentation
 var pool=Pool.service(game);var prepared=pool.created;var misses=pool.misses
 game.ui.hide();game.training_dummy.hide();game.training_dummy.position=STAGE+Vector3(0,0,-12);game.training_dummy.home=game.training_dummy.position
 pool.launched.connect(func(shot):
  if shot.get_script()==Shot:
   shot.set_physics_process(false);released.append({"kind":shot.kind,"secondary":shot.secondary,"point":shot.position,"damage":shot.damage})
  elif shot.get_script()==WaveShot:
   shot.set_physics_process(false)
   if shot.kind=="wind":released.append({"kind":0,"secondary":false,"point":shot.position,"damage":shot.damage}))
 if visual:
  recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
  recording_slot=AudioServer.get_bus_effect_count(AudioServer.get_bus_index("SFX"));AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"),recorder)
 game.camera_rig.camera.position=STAGE+Vector3(11,8,17);game.camera_rig.camera.look_at(STAGE+Vector3(0,4,0))
 p.model.animate(0,0,true,0,0,false,0,false);await save_view("body-color")
 game.camera_rig.camera.position=STAGE+Vector3(9,7,-15);game.camera_rig.camera.look_at(STAGE+Vector3(0,4,0));await save_view("body-color-front")
 var lib=game.sound_library
 lib.select_character(30)
 for cue in Finale.SOUND_NAMES:
  var slot="finale_"+cue
  check(SoundLibrary.slots_for(30).has(slot),"Studio includes "+cue)
  check(game.sound_preview(30,slot)==Finale.sounds[cue],"Studio previews the installed ROM "+cue)
  var before=game.voice_idx;presentation.finale_sound(p.position,cue,true)
  check(game.voice_idx==before+1 and game.last_sound_voice.stream==Finale.sounds[cue],"Foreground voice plays "+cue)
  check(game.voices.find(game.last_sound_voice)<16,"Recovered cue uses the existing reserved attack voices")
 for voice in game.voices:voice.stop()
 lib.custom.finale_cast=Finale.sounds.core_hit;lib.gains.finale_cast=.5
 presentation.finale_sound(p.position,"cast",true)
 check(game.last_sound_voice.stream==Finale.sounds.core_hit and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.55*.5),"Recorded cast and saved gain own actual playback")
 lib.mutes.finale_cast=true;var old_order=game.voice_idx;presentation.finale_sound(p.position,"cast",true)
 check(game.voice_idx==old_order,"Cast mute suppresses actual playback")
 lib.custom.erase("finale_cast");lib.gains.erase("finale_cast");lib.mutes.erase("finale_cast")
 for voice in game.voices:voice.stop()
 check(Finale.meshes.sword_wave.surface_get_material(0).blend_mode==BaseMaterial3D.BLEND_MODE_ADD,"Ground wave uses source additive blending instead of dark triangles")
 for move in ([0] if blade_only else [1,2,3,4,5,0]):
  fresh();released.clear();begin_audio();c.start_move(move);var target=c.aim
  game.camera_rig.camera.position=STAGE+Vector3(24,18,36);game.camera_rig.camera.look_at(STAGE+Vector3(0,4,-10))
  if move in [2,3,4]:
   game.camera_rig.camera.position=STAGE+Vector3(50,65,85);game.camera_rig.camera.look_at(STAGE+Vector3(0,0,-20))
  var earth_snap=false
  for tick in 360:
   await advance(1)
   if tick in [55,80,110]:await save_view("%s-%d"%[Finale.NAMES[move].to_lower(),tick])
   if move==4 and c.marker>40 and not earth_snap:
    await advance(16);await save_view("earth-wave");earth_snap=true
  if move==1:
   check(released.filter(func(s):return s.kind==1).size()==22*Finale.WIND_FAN+1,"Wind emits its wider barrage and targets the pushed victim once")
   check(contacts.size()>0,"Wind's travelling gusts make real combat contact")
   check(released.filter(func(s):return s.kind==1).all(func(s):return s.damage>0),"Visible gusts carry damage")
  elif move in [2,3]:
   var primary=released.filter(func(s):return s.kind==move and not s.secondary)
   check(primary.size()==(6 if move==2 else 32),"All falling hazards remain")
   var spread=0.0
   for shot in primary:spread=maxf(spread,Vector2(shot.point.x-target.x,shot.point.z-target.z).length())
   check(spread>Finale.FALL_SPREAD[move-2]*.5 and spread<=Finale.FALL_SPREAD[move-2]+.01,"The falling hazard has its 1.5x farther spread")
   check(primary.all(func(s):return is_equal_approx(s.point.y,STAGE.y+Finale.FALL_HEIGHT)),"Fall travel starts 1.5x farther away")
   check(heard.count("finale_water_burst" if move==2 else "finale_fire_fall")== (6 if move==2 else 32),"Every primary hazard reaches its correct audible phase: "+Finale.NAMES[move])
   if move==3:check(not heard.has("finale_impact"),"Ground fire does not add 32 unrelated impact sounds")
  elif move==4:
   check(earth_snap,"Earth wave follows the actual physical landing")
   check(heard.has("finale_cast") and heard.has("finale_earth_impact"),"Earth has its cast and landing cues")
  elif move==5:check(heard.count("finale_sky_copy")==5 and heard.count("finale_sky_launch")==5,"All five copies have birth and launch cues")
  elif move==0:check(heard.has("finale_sword_wave") and heard.count("finale_sword_cross")==2,"Sword wave and opposing crosses have separate cues")
  await save_audio(Finale.NAMES[move].to_lower())
  c.cancel();await advance(240)
 fresh();released.clear();begin_audio()
 game.camera_rig.camera.position=STAGE+Vector3(15,10,22);game.camera_rig.camera.look_at(STAGE+Vector3(0,2,-10))
 for section in 3:
  c.start_attack()
  await advance(ceili(c.SWORD_SECTIONS[section].contact*2/c.CAST_RATE)+2)
  await save_view("blade-click-%d"%(section+1))
  await advance(ceili((c.SWORD_SECTIONS[section].ticks-c.SWORD_SECTIONS[section].contact)*2/c.CAST_RATE)+8)
 check(released.size()==3,"Three requested energy cuts release Kojiro’s wave and two flying energy blades")
 check(heard.count("finale_sword_wave")==1 and heard.count("finale_sword_cross")==2,"Clicked energy sequence keeps all three distinct ROM release sounds")
 await save_audio("blade-clicks");await advance(180)
 var point=p.position
 check(is_equal_approx(Finale.meshes.fire.center_offset.y,Finale.meshes.fire.size.y*.5),"The full flame stands above its base")
 check(is_equal_approx(Finale.meshes.water.center_offset.y,Finale.meshes.water.size.y*.5),"The full water splash stays above the ground")
 for cue in [22,42,16,17,35]:
  presentation.effects.clear();presentation.finale_cue(point,cue,Vector3.FORWARD,c.get_instance_id(),60)
  var effect=presentation.effects.filter(func(e):return e.kind.begins_with("finale-") and e.kind!="finale-sky_copy")[0]
  var mesh=Finale.meshes[effect.kind.trim_prefix("finale-")];var mat=mesh.surface_get_material(0)
  var full_length=float(mat.get_shader_parameter("frames"))/float(mat.get_shader_parameter("playback_fps"))
  check(effect.life+0.0001>=full_length,"Effect %d displays every recovered animation frame"%cue)
 presentation.effects.clear();c.cancel()
 var fire=pool.launch(p,Shot,"finale3",{"kind":3,"position":ORIGIN+Vector3.UP*5,"velocity":Vector3.DOWN*Finale.SHOT_SPEED[3],"damage":1.0})
 check(fire.visual.multimesh.visible_instance_count==3,"A falling flame has its full body and two trails")
 fire.impact(ORIGIN+Vector3.UP*3)
 check(fire.grounded and absf(fire.position.y-.25*Finale.SCALE)<.03,"A flame hitting a body settles on the ground below")
 check(fire.visual.multimesh.visible_instance_count==1,"A landed flame removes its falling trail")
 fire.retire();fire=pool.launch(p,Shot,"finale3",{"kind":3})
 check(not fire.grounded and fire.visual.multimesh.visible_instance_count==3,"A reused flame restores its complete falling effect")
 fire.retire()
 presentation.finale_loop(point,"fire_loop",2.7,123);presentation.finale_loop(point,"fire_loop",2.7,456)
 check(presentation.voices.filter(func(v):return v.playing and v.get_meta("finale_loop","")=="fire_loop").size()==1,"Ground flames share one sustained fire sound")
 presentation.tick(2.8)
 check(not presentation.voices.any(func(v):return v.playing and v.get_meta("finale_loop","")=="fire_loop"),"The shared fire sustain ends after its last flame")
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var bank=preload("res://scripts/character_audio_bank.gd").streams.size()
 for repeat in 100:
  presentation.finale_sound(point,"cast",true);presentation.finale_sound(point,"sword_wave",true)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated sounds reuse existing nodes and resources")
 check(preload("res://scripts/character_audio_bank.gd").streams.size()==bank,"Repeated sounds do not load more assets")
 check(pool.created==prepared and pool.misses==misses,"Full effects reuse prepared projectile leases")
 for voice in game.voices:voice.stop()
 for voice in presentation.voices:voice.stop()
 begin_audio();game.tuning.invincible=false;p.hp=1;p.invuln=0;p.take_hit(100,Vector3.FORWARD)
 check(c.mode=="dead" and game.respawn_left>0,"Playable defeat retains the recovered death state after respawn cancellation")
 check(presentation.effects.any(func(e):return e.kind=="finale-core"),"Playable defeat retains the core effect")
 await advance(45);await save_view("defeat-core");await advance(510);await save_audio("defeat")
 if recorder:AudioServer.remove_bus_effect(AudioServer.get_bus_index("SFX"),recording_slot)
 step_times.sort();frame_times.sort()
 var report={"checks":checks,"failures":failures,"pool_before":prepared,"pool_after":pool.created,"misses":pool.misses-misses,"manual_step_p95_ms":step_times[floori(step_times.size()*.95)]}
 if visual:report.frame_median_ms=frame_times[frame_times.size()/2];report.frame_p95_ms=frame_times[floori(frame_times.size()*.95)];report.frame_max_ms=frame_times[-1]
 FileAccess.open(COMPLETE_OUT+(("rendered-blade-results.json" if visual else "headless-blade-results.json") if blade_only else ("rendered-results.json" if visual else "headless-results.json")),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FINALE_COMPLETENESS_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
