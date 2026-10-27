extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
const OUT="res://build/Other Files/Asset Toolkit/Dark Lumina 2/Spin and Walking/"
var focused=0
var stepped=0
var recorder:AudioEffectRecord
var timings=[]
func advance(count:int):
 for i in count:
  var start=Time.get_ticks_usec()
  game.player._physics_process(1.0/60)
  game.crowd.army.presentation.tick(1.0/60)
  timings.append((Time.get_ticks_usec()-start)/1000.0)
  stepped+=1
  if DisplayServer.get_name()!="headless" and root.has_focus():focused+=1
  await physics_frame
func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.player.model.show();await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Render "+label_)
func begin_audio():
 for voice in game.crowd.army.presentation.voices:voice.stop()
 game.crowd.army.presentation.next_sound=0
 if recorder:recorder.set_recording_active(true)
func end_audio(label_:String):
 if recorder==null:return
 await create_timer(.7).timeout;recorder.set_recording_active(false)
 var recording=recorder.get_recording()
 check(recording!=null and recording.data.count(0)<recording.data.size(),"Desktop mixer emits "+label_)
 if recording:recording.save_to_wav(OUT+label_+".wav")
func run():
 create_timer(180).timeout.connect(func():printerr("DL2_SPIN_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_physics_process(false)
 game.settings.volume=1;game.settings.music_enabled=false;game.apply_music_setting()
 game.tuning.invincible=true
 var p=game.player;p.select_character(Dark.PLAYER);fresh();await advance(3)
 var presentation=game.crowd.army.presentation
 game.camera_rig.camera.global_position=ORIGIN+Vector3(40,25,46);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,6,0))
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_title("Goemon · DL2 spin and walking (DEBUG)")
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground()
  recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
  AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"),recorder)
 check(p.spell_loadout.spell_for(29,"sky_strike")=="dark-lumina-2/spin","T defaults to recovered spin")
 check(Dark.sounds.spin==Dark.sounds.hurt,"B56 spin reuses the prepared original layered voice")
 check(game.sound_preview(29,"dark_lumina_2_spin")==Dark.sounds.spin,"Recording studio previews original spin")
 check(game.sound_preview(29,"dark_lumina_2_step")==Dark.sounds.step,"Recording studio previews original walk stomp")
 check(Dark.steps_between(0,14)==0 and Dark.steps_between(14,15)==1 and Dark.steps_between(15,53)==1 and Dark.steps_between(53,95)==1,"Original 15/53 foot markers survive wraparound")
 check(Dark.steps_between(0,240)==6,"Skipped animation intervals retain every crossed foot marker")
 begin_audio();p.model.walk_tick=0
 var stride=preload("res://scripts/forest/forest_enemy_roles.gd").stats(Dark.ROLE).stride
 var walked=0
 for frame in 240:
  var speed=stride*(1.0 if frame<120 else .5)
  p.model.animate(1.0/60,speed,true,0,0,false,0,false)
  presentation.tick(1.0/60)
  await physics_frame
  if frame in [11,39,143,199]:walked+=int(game.voices.any(func(voice):return voice.playing and voice.stream==Dark.sounds.step))
 check(is_equal_approx(p.model.walk_tick,240),"Changing walking speed keeps continuous pose phase")
 check(walked>0,"Walking animation dispatches the original stomp stream")
 var before=p.model.walk_tick;p.model.animate(1,0,true,0,0,false,0,false);p.model.animate(1,stride,false,30,0,false,0,false)
 check(p.model.walk_tick==before,"Idle and airborne movement emit no walking markers")
 await capture("walking");await end_audio("walking")
 for sign_ in [-1,1]:
  fresh();await advance(3);game.training_dummy.position=ORIGIN+Vector3(0,0,-10)
  begin_audio();tap("sky_strike")
  var combat=p.active_ability
  combat.state.spin_sign=sign_;combat.clip=Dark.SPIN_CLIPS[0 if sign_==1 else 1]
  await advance(12)
  check(contacts.is_empty(),"Spin windup does no early damage")
  await capture("spin-%d-windup"%sign_)
  await advance(4)
  check(contacts.size()==1,"Spin contacts nearby target once at source frame seven")
  check(p.model.current_clip==combat.clip and absf(p.model.body.rotation.y)>0,"Original directional pose includes code-owned body turn")
  await advance(19);await capture("spin-%d-active"%sign_)
  check(presentation.batches["dark-spin_debris"].multimesh.visible_instance_count>0,"Spin presents recovered flying floor tiles")
  await advance(50)
  check(contacts.size()==1 and not combat.is_attacking(),"Spin completes without duplicate damage")
  check(is_zero_approx(p.model.body.rotation.y),"Spin restores body orientation")
  await end_audio("spin-%d"%sign_)
 fresh();await advance(3);tap("sky_strike");await advance(3);p.active_ability.cancel();await advance(70)
 check(contacts.is_empty() and is_zero_approx(p.model.body.rotation.y),"Cancelled spin leaves no delayed damage or rotation")
 fresh();await advance(3);game.training_dummy.position=ORIGIN+Vector3(0,0,-60);tap("sky_strike");await advance(70)
 check(contacts.is_empty(),"Spin misses a target beyond its shared reach")
 p.select_character(1);fresh();game.training_dummy.position=ORIGIN+Vector3(0,0,-10);await advance(3)
 check(p.spell_loadout.equip(1,"equip","dark-lumina-2/spin"),"Another fighter equips spin through shared skills")
 tap("equip");await advance(20)
 check(p.spell_loadout.current!=null and absf(wrapf(p.model.rotation.y-atan2(-p.facing.x,-p.facing.z),-PI,PI))>.1,"Borrowed spin turns the receiving body")
 await capture("borrowed-spin");await advance(65)
 check(p.spell_loadout.current==null and contacts.size()==1 and p.character_id==1,"Borrowed spin hits once, completes and keeps the selected fighter")
 tap("equip");await advance(3);p.spell_loadout.cancel();await advance(70)
 check(is_zero_approx(wrapf(p.model.rotation.y-atan2(-p.facing.x,-p.facing.z),-PI,PI)),"Cancelling borrowed spin restores facing")
 p.spell_loadout.equip(1,"equip","");p.select_character(29);fresh();await advance(3)
 var lib=game.sound_library;lib.select_character(29)
 for slot in ["dark_lumina_2_step","dark_lumina_2_spin"]:
  begin_audio();lib.custom[slot]=Dark.sounds.claw;lib.gains[slot]=.5
  presentation.dark_sound(p.position,slot.trim_prefix("dark_lumina_2_"))
  var voice=presentation.voices.filter(func(v):return v.playing and v.stream==Dark.sounds.claw)
  check(voice.size()==1 and is_equal_approx(voice[0].max_distance,195) and is_equal_approx(db_to_linear(voice[0].volume_db),.55*.5),"Saved recording, gain and enlarged sound range apply to "+slot)
  begin_audio();lib.mutes[slot]=true;presentation.dark_sound(p.position,slot.trim_prefix("dark_lumina_2_"))
  check(presentation.voices.all(func(v):return not v.playing),"Saved mute applies to "+slot)
  lib.custom.erase(slot);lib.gains.erase(slot);lib.mutes.erase(slot)
 begin_audio();presentation.dark_cue(p.position,10)
 check(presentation.voices.all(func(v):return not v.playing),"Held-victim status does not falsely emit a footstep")
 await advance(180)
 # Exercise overlapping army/player effect ownership without adding per-unit nodes.
 var nodes=presentation.get_child_count()
 for repeat in 3:
  for i in 12:presentation.dark_cue(ORIGIN+Vector3((i%4-1.5)*16,0,-floori(i/4.0)*16),11,0,-i-1,1,1 if i%2 else -1)
  presentation.tick(.5)
  check(presentation.batches["dark-spin_dust"].multimesh.visible_instance_count==12*9*8,"Twelve simultaneous spins preserve all active dust emitters")
  check(presentation.batches["dark-spin_debris"].multimesh.visible_instance_count==12*9,"Twelve simultaneous spins preserve original floor-fragment emission count")
  if repeat==0:await capture("simultaneous-spin-effects")
  presentation.tick(3)
 check(presentation.get_child_count()==nodes and presentation.effects.is_empty(),"Repeated simultaneous spins retire with stable pooled nodes")
 timings.sort()
 var result={"checks":checks,"failures":failures,"focused_frames":focused,"stepped_frames":stepped,"manual_step_cpu_p95_ms":timings[int(timings.size()*.95)],"presentation_nodes":nodes,"note":"Isolated gameplay and simultaneous effect checks; manual step CPU is not FPS"}
 FileAccess.open(OUT+"gameplay-results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("DARK_LUMINA_SPIN_RESULT ",result)
 if recorder:recorder.set_recording_active(false)
 game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
