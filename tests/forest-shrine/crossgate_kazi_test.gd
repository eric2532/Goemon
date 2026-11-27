extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Kazi Matched Reach/"
const CUT_SOUND=preload("res://assets/audio/crossgate/kazi/cgply11a.wav")
const BLAST_SOUND=preload("res://assets/audio/crossgate/kazi/cgply11b.wav")
class BusySpell extends Node:
 var spec={"id":"test/shared"}
 func busy()->bool:return true
var samples=[]
var home=Vector3(-150,.1,150)
var audio_events=[]
var seen_audio_order=0
func record_audio():
 for voice in game.voices:
  if int(voice.get_meta("order",0))>seen_audio_order:
   audio_events.append({"kind":voice.get_meta("kind",""),"stream":voice.stream,"volume_db":voice.volume_db})
 seen_audio_order=game.voice_idx
func audio_count(kind:String)->int:return audio_events.filter(func(event):return event.kind==kind).size()
func tap(action:String):
 game.player.auto_attack_enabled=true
 game.player.auto_lock_target=game.training_dummy;game.player.auto_lock_refresh=100
 super.tap(action)
 game.player.auto_attack_enabled=false
func fresh(surge:bool=false):
 super.fresh(surge)
 game.player.dodge_cooldown=0
 game.player.position=home;game.player.velocity=Vector3.DOWN;game.player.move_and_slide()
 game.model.update_vision(home)
 game.training_dummy.home=home+Vector3.FORWARD*2;game.training_dummy.position=game.training_dummy.home
 audio_events.clear();seen_audio_order=game.voice_idx
func advance(count:int):
 var presentation=game.crowd.army.presentation
 for i in count:
  var started=Time.get_ticks_usec()
  game.player._physics_process(1.0/60)
  record_audio()
  samples.append((Time.get_ticks_usec()-started)/1000.0)
  # The fixture disables the game's physics driver.
  presentation.tick(1.0/60)
  if DisplayServer.get_name()!="headless":await physics_frame
  elif i%30==0:await process_frame
func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();await process_frame;RenderingServer.force_draw();await process_frame
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Captured "+label_)
func shows_attack_frame(model)->bool:
 var frame:Array=model.appearance.clips[model.current_clip].frames[model.current_frame]
 var offset=Vector2(float(frame[5])+float(frame[3])*.5,model.FEET_OFFSET_PIXELS-float(frame[6])-float(frame[4])*.5)
 return model.sprite.texture==model.atlases[int(frame[0])] and model.sprite.region_rect==Rect2(frame[1],frame[2],frame[3],frame[4]) and model.sprite.offset==offset and model.sprite.position==Vector3.ZERO
func capture_motion(model,action:int,label_:String):
 if DisplayServer.get_name()=="headless":return
 var clip:Dictionary=model.motions.clips["%d:%d"%[action,model.direction()]]
 for frame in clip.frames.size():
  model.show_pose(action,(frame+.01)*float(clip.duration)/clip.frames.size(),true)
  RenderingServer.force_draw();await process_frame
  root.get_texture().get_image().save_png(OUT+"Motion/"+label_+"-%02d.png"%frame)
func capture_turns(model,back:Vector3,right:Vector3):
 if DisplayServer.get_name()=="headless":return
 var facing=game.player.facing
 for action in [0,1,3,5]:
  for direction in 8:
   var angle=(direction-1)*TAU/8
   game.player.facing=right*sin(angle)-back*cos(angle)
   model.rotation.y=atan2(-game.player.facing.x,-game.player.facing.z)
   model.show_pose(action,0,true)
   await capture("turn-%d-%d"%[action,direction])
 game.player.facing=facing
func capture_travel():
 if DisplayServer.get_name()=="headless":return
 fresh();await advance(6)
 var camera=game.camera_rig.camera
 var saved_camera=camera.global_transform
 var start=game.player.position
 camera.global_position=start+Vector3(0,4,12);camera.look_at(start+Vector3.UP*1.3)
 var camera_offset=camera.global_position-start
 var track=[]
 game.player.smoke_move=Vector2.RIGHT
 var started=Time.get_ticks_usec()
 var next_capture=started
 game.player.set_physics_process(true)
 while Time.get_ticks_usec()-started<2500000:
  await physics_frame;await process_frame
  camera.global_position=game.player.position+camera_offset
  record_audio()
  if Time.get_ticks_usec()>=next_capture:
   track.append({"time_ms":(Time.get_ticks_usec()-started)/1000.0,"phase":game.player.model.phase,"speed":game.player.model.locomotion.actual_speed,"grounded":game.player.is_on_floor(),"clip":game.player.model.current_clip})
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().get_region(Rect2i(420,210,440,360)).save_png(OUT+"Motion/travel-%03d.png"%(track.size()-1))
   next_capture=Time.get_ticks_usec()+33333
 game.player.set_physics_process(false)
 var file=FileAccess.open(OUT+"Motion/travel.json",FileAccess.WRITE);file.store_string(JSON.stringify(track));file.close()
 check(game.player.position.distance_to(start)>5 and track.all(func(sample):return sample.speed<12),"Captured normal-physics walking over scrolling terrain at the real movement speed")
 camera.global_transform=saved_camera
 fresh();await advance(6)
func check_jump(model):
 var p=game.player
 var camera=game.camera_rig.camera
 var saved_camera=camera.global_transform
 var original_skin=model.kaz_skin
 var child_count=model.body.get_child_count()
 for skin:int in model.Skins.CATALOG:
  model.set_kaz_skin(skin)
  fresh();await advance(6)
  camera.global_position=p.global_position+Vector3(0,4,12)
  camera.look_at(p.global_position+Vector3.UP*2.4)
  p.facing=Vector3(1,0,1).normalized()
  super.tap("jump")
  await advance(1)
  var cell:Vector2=model.GUARD_CELL
  check(p.is_on_floor() and model.current_clip.begins_with("9:") and model.sprite.texture==model.jump_guard_atlas and model.sprite.region_rect==Rect2(Vector2(model.direction(),model.GUARD_ROW[skin])*cell,cell),"Kaz skin %d guards during the existing jump windup"%skin)
  if skin==original_skin:await capture("jump-guard")
  await advance(2)
  check(not p.is_on_floor() and p.velocity.y>0 and model.current_clip.begins_with("9:"),"Kaz skin %d launches on the third tick while guarding"%skin)
  await advance(4)
  check(model.current_clip.begins_with("8:") and model.current_frame==0,"Kaz skin %d briefly flinches after the guard"%skin)
  if skin==original_skin:await capture("jump-flinch")
  var tuck=false
  var descent=false
  var landed=false
  for i in 150:
   await advance(1)
   if not tuck and p.velocity.y>0 and model.current_clip.begins_with("3:") and model.current_frame==3:
    tuck=true
    if skin==original_skin:await capture("jump-tuck")
   if not descent and p.velocity.y<0 and model.current_clip.begins_with("3:") and model.current_frame==15:
    descent=true
    if skin==original_skin:await capture("jump-descent")
   if p.is_on_floor():
    landed=model.current_clip.begins_with("10:") and model.current_frame==5
    if skin==original_skin:await capture("jump-landing")
    break
  check(tuck and descent and landed,"Kaz skin %d tucks, descends in the run pose, and crouches on floor contact"%skin)
  await advance(16)
  check(model.current_clip.begins_with("0:") and audio_count("land")==1,"Kaz skin %d recovers to idle and plays one landing cue"%skin)
 model.set_kaz_skin(original_skin)
 fresh();await advance(6);super.tap("jump");await advance(13)
 super.tap("jump");await advance(1)
 check(p.jumps_used==2 and model.current_clip.begins_with("8:") and model.current_frame==0,"The second jump restarts the flinch on its launch tick")
 await advance(120)
 check(p.is_on_floor() and model.body.get_child_count()==child_count,"Repeated jumps reuse Kaz's existing sprite and recover on the floor")
 camera.global_transform=saved_camera
func run():
 DirAccess.make_dir_recursive_absolute(OUT+"Motion")
 create_timer(180).timeout.connect(func():printerr("KAZI_TIMEOUT");quit(1))
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data);game.tuning.invincible=true
 game.set_process_input(false);game.set_process_unhandled_input(false)
 game.player.set_process_input(false);game.player.set_process_unhandled_input(false)
 root.gui_disable_input=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 home.y=game.model.surface_height(home.x,home.z)+.1
 game.camera_rig.set_process_unhandled_input(false)
 var p=game.player
 game.show_rogue_roster();await frames(2)
 var card=game.menu.find_child("RogueFighter_kazi",true,false)
 check(card!=null and card.tooltip_text=="Kaz","Kaz is selectable under the original nickname")
 card.grab_focus();await frames(3)
 await capture("gallery");game.close_rogue_roster()
 p.select_character(34);fresh();await advance(8)
 var model=p.model;var kit=p.active_ability
 check(p.RogueRoster.name_for(34)=="Kaz" and p.ROSTER[34].name=="Kaz" and p.RogueRoster.class_id(34)=="kazi","Kaz keeps his saved fighter identity")
 var portrait:Texture2D=p.RogueRoster.portrait(34)
 var portrait_frame:Array=model.motions.clips["0:4"].frames[0]
 var source_atlas=Image.load_from_file(model.atlases[int(portrait_frame[0])].resource_path)
 var front_pose=source_atlas.get_region(Rect2i(portrait_frame[1],portrait_frame[2],portrait_frame[3],portrait_frame[4]))
 check(portrait==p.RogueRoster.selection_portrait(34) and Image.load_from_file(portrait.resource_path).get_data()==front_pose.get_data(),"Gallery and HUD share the exact recovered front-diagonal pose")
 check(model.motions.id==102488 and model.motions.clips.size()==56,"Seven source actions retain all eight directions")
 var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/crossgate/kazi/motions.json"))
 var frames_kept=0
 var timing_kept=true
 for key in original.clips:
  var clip:Dictionary=model.motions.clips[key]
  frames_kept+=clip.frames.size()
  timing_kept=timing_kept and clip.frames.size()==original.clips[key].frames.size() and clip.duration==original.clips[key].duration and clip.sounds==original.clips[key].sounds
 check(not model.motions.has("illustrated") and frames_kept==872 and timing_kept,"All 872 original frame slots keep source durations and sound markers")
 check(model.ROOT=="res://assets/characters/crossgate/kazi/" and model.motions==original,"Live frame regions and offsets exactly match the original source")
 check(model.atlases.size()==6 and model.atlases.all(func(atlas):return atlas.resource_path.begins_with(model.ROOT)),"Base animations retain the six original sprite atlases")
 check(model.explosion==null,"Kaz uses his body sprite for the full-size attack effects")
 check(is_equal_approx(model.BODY_HEIGHT_PIXELS,83) and is_equal_approx(model.FEET_OFFSET_PIXELS,7),"Original body and foot references are restored")
 check(model.sprite.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR,"Original sprites use gentle display smoothing")
 check(is_equal_approx(model.sprite.pixel_size*model.BODY_HEIGHT_PIXELS,preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT),"Kazi's standing body matches Goemon's reference height")
 check(SoundLibrary.original_for(34,"swing").resource_path.ends_with("/cgply01a.wav"),"Original Cross Gate sword sample is prepared")
 check(SoundLibrary.original_for(34,"hit").resource_path.ends_with("/cgefc04.wav"),"Recovered Cross Gate impact is prepared")
 check(game.sound_preview(34,"hit")==CUT_SOUND and game.sound_preview(34,"heavy_hit")==BLAST_SOUND,"Sound Studio previews both sword impacts")
 game.camera_rig.camera.global_position=home+Vector3(6,4,9)
 game.camera_rig.camera.look_at(home+Vector3(0,1,0))
 model.animate(0,0,true,0,0,false,0,false);await capture("idle")
 var directions={}
 for i in 8:
  p.facing=Vector3(sin(i*TAU/8),0,cos(i*TAU/8))
  model.animate(0,0,true,0,0,false,0,false);directions[model.direction()]=true
 check(directions.size()==8,"Camera-relative facing reaches every source direction")
 var back=Vector3(game.camera_rig.camera.global_basis.z.x,0,game.camera_rig.camera.global_basis.z.z).normalized()
 var right=Vector3(game.camera_rig.camera.global_basis.x.x,0,game.camera_rig.camera.global_basis.x.z).normalized()
 var attack_facing=p.facing
 for direction in 8:
  var angle=(direction-1)*TAU/8
  p.facing=right*sin(angle)-back*cos(angle);model.rotation.y=atan2(-p.facing.x,-p.facing.z)
  var original_art=true
  for frame in 11:
   model.show_pose(5,(frame+.01)*kit.DURATION/11,false)
   original_art=original_art and model.current_frame==frame and shows_attack_frame(model)
  check(original_art,"Original slash and blast use their full-size art and offsets for direction %d"%direction)
  model.show_pose(0,0,true)
  check(model.current_clip.begins_with("0:"),"Returning to idle clears the explosion for direction %d"%direction)
 p.facing=right;model.rotation.y=atan2(-right.x,-right.z)
 var blast_pose=.36
 model.show_pose(5,blast_pose,false)
 var attack_duration=float(model.motions.clips[model.current_clip].duration)
 for skin_id in [109890,109891,109146,model.Skins.DEFAULT]:
  game.select_kaz_skin(skin_id)
  var attack_clip:Dictionary=model.appearance.clips[model.current_clip]
  var uses_own_art=shows_attack_frame(model)
  for frame in attack_clip.frames.size():
   model.show_pose(5,(frame+.01)*attack_duration/attack_clip.frames.size(),false)
   uses_own_art=uses_own_art and model.current_frame==frame and shows_attack_frame(model)
  check(uses_own_art,"Skin %d switches in place and uses its own attack frames"%skin_id)
  model.show_pose(5,blast_pose,false)
  if skin_id in [109146,model.Skins.DEFAULT]:
   var base_scale:Vector3=model.scale
   var base_pixel:float=model.sprite.pixel_size*model.sprite.global_basis.y.length()
   model.scale=base_scale*1.4
   check(shows_attack_frame(model) and is_equal_approx(model.sprite.pixel_size*model.sprite.global_basis.y.length(),base_pixel*1.4),"Skin %d scales its burst with the fighter"%skin_id)
   await capture("attack-skin-%d-enlarged"%skin_id)
   model.scale=base_scale
  await capture("attack-skin-%d"%skin_id)
 p.facing=attack_facing
 await capture_turns(model,back,right)
 if DisplayServer.get_name()!="headless":
  var saved_facing=p.facing;var saved_filter=model.sprite.texture_filter
  p.facing=back;model.show_pose(0,0,true)
  model.sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;await capture("filter-nearest")
  model.sprite.texture_filter=saved_filter;await capture("filter-smoothed")
  p.facing=saved_facing
 var saved_phase=model.phase
 var saved_steps=model.locomotion.step_events
 model.phase=.48;model.locomotion_velocity=right*2
 model.animate(.04,2,true,0,0,false,0,false)
 check(model.locomotion.step_events==saved_steps+1,"A grounded half-stride emits one footstep")
 var walk_phase=model.phase
 Input.action_press("sprint")
 model.locomotion_velocity=right*8
 p.facing=right;model.animate(0,8,true,0,0,false,0,false)
 check(is_equal_approx(model.phase,walk_phase) and model.current_frame==floori(walk_phase*18),"Walk/run and direction changes retain stride phase")
 saved_steps=model.locomotion.step_events
 model.animate(.3,8,false,3,0,false,0,false)
 model.locomotion_velocity=Vector3.ZERO;model.animate(.3,8,true,0,0,false,0,false)
 check(model.locomotion.step_events==saved_steps,"Airborne or obstructed movement emits no footsteps")
 var blocked_phase=model.phase
 model.animate(.3,10.2,true,0,0,false,0,false)
 check(is_equal_approx(model.phase,blocked_phase) and model.current_clip.begins_with("0:"),"A blocked character holds stride phase and returns to idle after landing recovery")
 model.phase=0;model.locomotion_velocity=right*8
 model.animate(model.RUN_STRIDE*.5/8,8,true,0,0,false,0,false)
 check(is_equal_approx(model.phase,.5),"Running advances half a stride over half its ground distance")
 Input.action_release("sprint")
 model.phase=0;model.locomotion_velocity=right*2
 model.animate(model.WALK_STRIDE*.5/2,2,true,0,0,false,0,false)
 check(is_equal_approx(model.phase,.5),"Walking advances half a stride over half its ground distance")
 model.phase=saved_phase
 model.locomotion_velocity=Vector3.ZERO
 var spell=BusySpell.new();game.add_child(spell)
 model.animate_spell(.01,spell);model.animate_spell(.12,spell)
 check(model.current_clip.begins_with("6:") and model.current_frame==4,"Shared skills advance Kazi's original cast gesture")
 model.animate(0,0,true,0,0,false,0,false);model.animate_spell(.01,spell)
 check(model.current_frame==0,"A new cast starts from its preparation frame")
 spell.queue_free()
 for pair in [[-back,1],[right,3],[back,5],[-right,7]]:
  model.locomotion_velocity=pair[0]*2
  p.facing=pair[0];model.animate(0,2,true,0,0,false,0,false)
  check(model.current_clip=="1:%d"%pair[1],"Straight walk selects source cardinal direction "+str(pair[1]))
  await capture("straight-walk-%d"%pair[1])
  Input.action_press("sprint")
  model.locomotion_velocity=pair[0]*5;model.animate(0,5,true,0,0,false,0,false)
  check(model.current_clip=="3:%d"%pair[1],"Straight run selects source cardinal direction "+str(pair[1]))
  Input.action_release("sprint")
 if DisplayServer.get_name()!="headless":
  p.facing=back
  await capture_motion(model,1,"front-walk")
  await capture_motion(model,3,"front-run")
  await capture_motion(model,5,"front-attack")
  p.facing=right;await capture_motion(model,3,"side-run")
  await capture_motion(model,5,"side-attack")
  p.facing=back
  model.show_pose(6,.4,false);await capture("cast")
  model.show_pose(8,1,false);await capture("hurt")
  model.show_pose(10,1.2,false);await capture("fall")
 p.facing=Vector3.FORWARD
 if DisplayServer.get_name()!="headless":
  var reference=p.character_models[1]
  var camera_transform=game.camera_rig.camera.global_transform
  reference.position=Vector3(-4,0,0);reference.rotation.y=atan2(-back.x,-back.z)
  reference.apply_native_pose(0,0);reference.show();reference.set_process(false)
  p.facing=back;model.show_pose(0,0,true)
  game.camera_rig.camera.global_position=home+Vector3(-2,2,14)
  game.camera_rig.camera.look_at(home+Vector3(-2,1.6,0))
  await capture("goemon-size-comparison")
  reference.hide();reference.position=Vector3.ZERO
  game.camera_rig.camera.global_transform=camera_transform
  p.facing=Vector3.FORWARD
 var start=p.position;p.smoke_move=Vector2.RIGHT
 Input.action_press("sprint")
 var ran=false
 for frame in 35:
  await advance(1)
  if not ran and model.current_clip.begins_with("3:"):
   ran=true;await capture("run")
 check(p.position.distance_to(start)>.5 and ran,"Real Hero movement plays illustrated run before slowing at obstacles (distance=%.3f clip=%s)"%[p.position.distance_to(start),model.current_clip])
 Input.action_release("sprint")
 check(audio_events.any(func(event):return event.kind=="step" and event.stream==SoundLibrary.GOEMON_FOOTSTEP),"Kazi's actual movement uses Goemon's baseline footstep")
 await capture_travel()
 await check_jump(model)
 fresh();await advance(6)
 p.position.y+=3;p.velocity=Vector3.DOWN*10;p.was_floor=false
 var landing_recorder:AudioEffectRecord
 var landing_bus=AudioServer.get_bus_index("SFX")
 var landing_effect=AudioServer.get_bus_effect_count(landing_bus)
 if DisplayServer.get_name()!="headless":
  landing_recorder=AudioEffectRecord.new();landing_recorder.format=AudioStreamWAV.FORMAT_16_BITS
  AudioServer.add_bus_effect(landing_bus,landing_recorder);landing_recorder.set_recording_active(true)
 await advance(70)
 check(p.is_on_floor() and audio_count("land")==1 and audio_events.any(func(event):return event.kind=="land" and event.stream==SoundLibrary.HUMANOID_LANDING),"Kazi's physical landing uses Goemon's prepared landing exactly once")
 if landing_recorder!=null:
  landing_recorder.set_recording_active(false)
  var landed=landing_recorder.get_recording()
  check(landed!=null and landed.data.count(0)<landed.data.size() and landed.save_to_wav(ProjectSettings.globalize_path(OUT+"kazi-landing-audio.wav"))==OK,"Saved audible Goemon landing from Kazi's actual floor transition")
  AudioServer.remove_bus_effect(landing_bus,landing_effect)
 fresh();await advance(6)
 game.camera_rig.kick_age=1.0
 var presentation=game.crowd.army.presentation
 var effects_before=presentation.effects.size()
 tap("light_attack")
 check(kit.is_attacking() and p.has_offensive_action(),"LMB enters the shared offensive lifecycle")
 var recorder:AudioEffectRecord
 var sfx=AudioServer.get_bus_index("SFX")
 var effect_index=AudioServer.get_bus_effect_count(sfx)
 if DisplayServer.get_name()!="headless":
  recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
  AudioServer.add_bus_effect(sfx,recorder);recorder.set_recording_active(true)
 kit.tick(kit.CONTACT-.001)
 record_audio()
 check(contacts.is_empty(),"Sword damage waits for contact")
 check(audio_count("swing")==1 and audio_count("hit")==0,"Original swing cue precedes the hit")
 check(presentation.effects.size()==effects_before,"The swing creates no contact burst during windup")
 kit.tick(.002);model.animate(0,0,true,0,0,false,0,false)
 check(contacts.size()==1 and model.current_frame==5,"The initial cut lands before the explosion")
 check(is_equal_approx(game.camera_rig.kick_strength,.035),"The blade uses a light camera kick")
 game.training_dummy._physics_process(1.0/60)
 check(game.training_dummy.model.rotation.x<-.05,"The dummy snaps away from the cut on the first step")
 record_audio()
 check(audio_count("hit")==1 and audio_events.any(func(event):return event.kind=="hit" and event.stream==CUT_SOUND and is_equal_approx(event.volume_db,linear_to_db(1.2*.55*.45))),"The landed cut plays Cross Gate sound 133 at Kaz's existing gain")
 var cut_spark:Dictionary=presentation.effects.back()
 check(cut_spark.kind in presentation.GOLD_SPARKS and cut_spark.position.distance_to(game.training_dummy.global_position+Vector3.UP)<1.0,"The cut draws a batched gold spark on the target")
 presentation.draw_effects()
 await capture("attack")
 kit.tick(.01);check(contacts.size()==1,"The cut cannot hit twice before the explosion")
 var second_cut=kit.SECOND_CUT_CONTACT
 kit.tick(second_cut-kit.elapsed-.001);check(contacts.size()==1,"Second cut damage waits for its authored frame")
 kit.tick(.002);model.animate(0,0,true,0,0,false,0,false)
 check(contacts.size()==2 and model.current_frame==6 and shows_attack_frame(model),"The second cut lands while the full-size visual blast plays")
 check(is_equal_approx(game.training_dummy.recoil_strength,.18) and kit.protects_player(),"The second cut uses the ordinary cut recoil and guard")
 check(is_equal_approx(game.camera_rig.kick_strength,.035) and is_equal_approx(p.impact_pause,.035),"The second cut uses ordinary camera kick and impact pause")
 check(p.attack_chain.count==1,"Both hits share one attack-chain link")
 var second_spark:Dictionary=presentation.effects.back()
 check(second_spark.kind in presentation.GOLD_SPARKS and second_spark.scale==cut_spark.scale and second_spark.life==cut_spark.life,"Both cuts draw a gold spark with the same scale and lifetime")
 presentation.draw_effects()
 await capture("attack-explosion")
 kit.tick(1);record_audio();check(not kit.is_attacking() and p.attack_left==0,"Attack recovery clears its clock")
 check(contacts.size()==2 and audio_count("swing")==kit.sound_cues.size() and audio_count("hit")==2 and audio_count("heavy_hit")==0,"Both hits play the regular cut sound alongside the original swing markers")
 if recorder!=null:
  await create_timer(.9).timeout
  recorder.set_recording_active(false)
  var recording=recorder.get_recording();var data=recording.data
  var peak=0
  for offset in range(0,data.size()-1,2):
   peak=maxi(peak,absi(data.decode_s16(offset)))
  check(peak>128 and peak<32767,"Real SFX bus contains audible sword and impact playback without clipping")
  check(recording.save_to_wav(ProjectSettings.globalize_path(OUT+"kazi-attack-audio.wav"))==OK,"Saved actual game audio")
  AudioServer.remove_bus_effect(sfx,effect_index)
 fresh();tap("light_attack");tap("dodge");await advance(30)
 check(contacts.is_empty() and not kit.is_attacking(),"Dodge cancels pending damage")
 check(audio_count("swing")==0 and audio_count("hit")==0 and audio_count("heavy_hit")==0,"Dodge cancels pending sword audio")
 fresh();tap("light_attack");kit.tick(1)
 check(contacts.size()==2,"LMB delivers both hits even when one tick crosses both frames")
 fresh();tap("light_attack");kit.tick(kit.CONTACT+.001);tap("dodge");await advance(30)
 check(contacts.size()==1 and not model.current_clip.begins_with("5:") and not kit.protects_player(),"Dodging after the first cut cancels the second cut and its protection")
 fresh();game.training_dummy.position=home+Vector3.FORWARD*100
 effects_before=presentation.effects.size()
 tap("light_attack");kit.tick(1);record_audio()
 check(audio_count("swing")==kit.sound_cues.size() and audio_count("hit")==0 and audio_count("heavy_hit")==0,"A missed sword attack has swings but no impact sound")
 check(presentation.effects.size()==effects_before,"A missed sword attack draws no contact burst")
 fresh();game.training_dummy.position=home+Vector3.FORWARD*100
 kit.start_attack();kit.tick(kit.CONTACT+.001)
 check(contacts.is_empty(),"The cut misses a target outside reach")
 game.training_dummy.position=game.training_dummy.home;kit.tick(1)
 check(contacts.size()==1,"The second cut can hit a target that enters reach after the first")
 fresh();game.training_dummy.position=home+Vector3.FORWARD*100
 game.tuning.invincible=false
 var player_hp:float=p.hp
 kit.start_attack()
 check(not kit.protects_player(),"Sword windup starts vulnerable")
 kit.tick(kit.CONTACT-.001)
 p.take_hit(10,Vector3.BACK)
 check(p.hp==player_hp and kit.is_attacking(),"An incoming hit on the cut's physics step cannot interrupt Kaz")
 kit.tick(.002)
 p.take_hit(10,Vector3.BACK,true)
 check(p.hp==player_hp and contacts.is_empty(),"The brief cut protection also blocks projectiles on a whiff")
 kit.tick_timers(1.0/60);kit.tick_timers(1.0/60)
 p.take_hit(10,Vector3.BACK)
 check(p.hp<player_hp and not kit.is_attacking(),"Kaz can be hit again after the short cut window")
 p.hp=player_hp;game.tuning.invincible=true
 fresh();await advance(90);await create_timer(1.2).timeout
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var contacts_per_attack=[]
 for i in 12:
  var before=contacts.size()
  tap("light_attack");await advance(60)
  contacts_per_attack.append(contacts.size()-before)
 await advance(120);await create_timer(1.2).timeout
 check(contacts_per_attack.all(func(count):return count==2),"Twelve repeated attacks each land both hits: "+str(contacts_per_attack))
 check(presentation.effects.all(func(effect):return not effect.get("contact",false)),"Repeated attacks let all contact bursts expire")
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes,"Repeated attacks retain no extra nodes (%d → %d)"%[nodes,Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
 var resources_after=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 check(resources_after<=resources,"Repeated attacks retain no extra resources (%d → %d)"%[resources,resources_after])
 fresh()
 var wall=StaticBody3D.new();wall.collision_layer=1
 var collider=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(4,4,.2)
 collider.shape=box;wall.add_child(collider);game.add_child(wall);wall.position=home+Vector3(0,1,-1)
 await physics_frame
 tap("light_attack");kit.tick(1)
 check(contacts.is_empty(),"Solid cover blocks both phases")
 kit.cancel();wall.queue_free();await physics_frame;await physics_frame
 fresh()
 var owner=game.army_runtime
 var row=game.model.waves.spawn_enemy(0,home+Vector3.FORWARD*5.45)
 row.hp=10000;row.max_hp=10000;owner.import_arrivals();owner.integration_tick(1.0/60)
 var handle:int=owner.handles[row.id]
 var hp:float=owner.unit_state(handle).hp
 p.ai_controlled=true;p.ai_aim=owner.unit_state(handle).position
 kit.start_attack();p.ai_controlled=false;kit.tick(kit.CONTACT+.001)
 check(is_equal_approx(hp-owner.unit_state(handle).hp,50),"The player's cut deals 50 base damage at the far edge of sword reach")
 var cut_position:Vector3=owner.unit_state(handle).position
 owner.integration_tick(1.0/60)
 var second_cut_position:Vector3=owner.unit_state(handle).position
 check((second_cut_position-cut_position).dot(p.facing)>.025,"The native enemy recoils sharply away from the cut")
 kit.tick(1)
 check(is_equal_approx(hp-owner.unit_state(handle).hp,100),"Both hits bring total base damage to 100 at the shared reach")
 owner.integration_tick(1.0/60)
 check((owner.unit_state(handle).position-second_cut_position).dot(p.facing)>.025,"The second cut applies the same sharp native recoil")
 owner.despawn(handle);owner.integration_tick(1.0/60)
 fresh();tap("light_attack");p.select_character(1)
 check(not kit.is_attacking() and p.attack_left==0,"Switching fighter cancels the old sword")
 p.select_character(34);fresh()
 for skin_id in [109890,109891,109146]:
  game.select_kaz_skin(skin_id);fresh()
  tap("light_attack");kit.tick(1);record_audio()
  check(contacts.size()==2 and audio_count("hit")==2 and audio_count("heavy_hit")==0,"Skin %d lands two regular cuts"%skin_id)
 fresh();tap("light_attack");kit.tick(float(kit.cut_times[0])+.001)
 game.select_kaz_skin(model.Skins.DEFAULT);kit.tick(1)
 check(contacts.size()==1 and not kit.is_attacking(),"Changing skins during a cut cancels its remaining contact")
 fresh()
 check(is_equal_approx(preload("res://scripts/forest/player_attack_range.gd").new().radius(p),5.6),"Range indicator shows the reach of both sword cuts")
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 var target:Vector3=game.training_dummy.position
 for i in 5:
  var allocated=mirrors.reinforce(34,target+Vector3.BACK.rotated(Vector3.UP,i*TAU/5)*2)
  check(allocated,"Kazi ally allocated through native owner "+str(i))
  if not allocated:break
  var body=mirrors.bodies[i]
  check(body.model.atlases[0]==model.atlases[0],"Ally shares prepared atlas "+str(i))
  body.perform(0,target)
 check(mirrors.bodies.size()==5,"Native owner supplies all five bodies")
 for tick in 50:
  for body in mirrors.bodies:
   body.step(1.0/60,{"position":body.position,"hp":body.max_hp,"yaw":0.0,"pose_velocity":Vector3.ZERO})
  if DisplayServer.get_name()!="headless":await physics_frame
 check(mirrors.bodies.all(func(body):return not body.has_offensive_action()),"Five simultaneous allies finish their attacks")
 check(contacts.size()==10,"Five simultaneous native allies land both phases")
 check(mirrors.bodies.all(func(body):return not body.model.current_clip.begins_with("5:")),"All five native allies return to their regular poses")
 await capture("allies");mirrors.dispose();await frames(3)
 var metrics=preload("res://tests/forest-shrine/army_benchmark_metrics.gd")
 FileAccess.open(OUT+"focused-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"headless":DisplayServer.get_name()=="headless","manual_player_step_ms":metrics.summary(samples)},"  "))
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("KAZI_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
