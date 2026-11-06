extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Cross Gate 102488/HD Preview/Game/"
var samples=[]
var home=Vector3(-150,.1,150)
var audio_events=[]
var seen_audio_order=0
func record_audio():
 for voice in game.voices:
  if int(voice.get_meta("order",0))>seen_audio_order:
   audio_events.append({"kind":voice.get_meta("kind",""),"stream":voice.stream})
 seen_audio_order=game.voice_idx
func audio_count(kind:String)->int:return audio_events.filter(func(event):return event.kind==kind).size()
func tap(action:String):
 game.player.auto_attack_enabled=true
 game.player.auto_lock_target=game.training_dummy;game.player.auto_lock_refresh=100
 super.tap(action)
 game.player.auto_attack_enabled=false
func fresh(surge:bool=false):
 super.fresh(surge)
 game.player.position=home;game.player.velocity=Vector3.DOWN;game.player.move_and_slide()
 game.model.update_vision(home)
 game.training_dummy.home=home+Vector3.FORWARD*2;game.training_dummy.position=game.training_dummy.home
 audio_events.clear();seen_audio_order=game.voice_idx
func advance(count:int):
 for i in count:
  var started=Time.get_ticks_usec()
  game.player._physics_process(1.0/60)
  record_audio()
  samples.append((Time.get_ticks_usec()-started)/1000.0)
  if DisplayServer.get_name()!="headless":await physics_frame
  elif i%30==0:await process_frame
func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();await process_frame;RenderingServer.force_draw();await process_frame
 check(root.get_texture().get_image().save_png(OUT+label_+".png")==OK,"Captured "+label_)
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
 for action in [0,1,3]:
  for direction in 8:
   var angle=(direction-1)*TAU/8
   game.player.facing=right*sin(angle)-back*cos(angle)
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
 check(game.player.position.distance_to(start)>5 and track.all(func(sample):return sample.speed<12),"Captured normal-physics running over scrolling terrain at the real movement speed")
 camera.global_transform=saved_camera
 fresh();await advance(6)
func run():
 DirAccess.make_dir_recursive_absolute(OUT+"Motion")
 create_timer(180).timeout.connect(func():printerr("KAZI_TIMEOUT");quit(1))
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data);game.tuning.invincible=true
 home.y=game.model.surface_height(home.x,home.z)+.1
 game.camera_rig.set_process_unhandled_input(false)
 var p=game.player
 game.show_rogue_roster();await frames(2)
 var card=game.menu.find_child("RogueFighter_kazi",true,false)
 check(card!=null,"Kazi is selectable in the gallery")
 card.grab_focus();await frames(3)
 await capture("gallery");game.close_rogue_roster()
 p.select_character(34);fresh();await advance(8)
 var model=p.model;var kit=p.active_ability
 check(p.RogueRoster.name_for(34)=="Kazi" and p.RogueRoster.class_id(34)=="kazi","Stable Kazi identity")
 check(p.RogueRoster.portrait(34).resource_path.ends_with("/kazi_hd/hud_portrait.png") and p.RogueRoster.selection_portrait_path(34).ends_with("/kazi_hd/portrait.png"),"Gallery and HUD use the illustrated identity with separate framing")
 check(model.motions.id==102488 and model.motions.clips.size()==56,"Seven source actions retain all eight directions")
 var original:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/crossgate/kazi/motions.json"))
 var frames_kept=0
 var timing_kept=true
 for key in original.clips:
  var clip:Dictionary=model.motions.clips[key]
  frames_kept+=clip.frames.size()
  timing_kept=timing_kept and clip.frames.size()==original.clips[key].frames.size() and clip.duration==original.clips[key].duration and clip.sounds==original.clips[key].sounds
 check(model.motions.illustrated and frames_kept==872 and timing_kept,"All 872 illustrated frames keep source durations and sound markers")
 check(model.motions.original_motion_sha256==FileAccess.get_sha256("res://assets/characters/crossgate/kazi/motions.json"),"Original recovered reference is unchanged")
 var masters_current=model.motions.master_hashes.size()==58
 for path in model.motions.master_hashes:masters_current=masters_current and FileAccess.get_sha256("res://"+path)==model.motions.master_hashes[path]
 check(masters_current,"Every illustrated atlas matches the saved editable masters")
 var textures_current=true
 for path in model.motions.texture_hashes:textures_current=textures_current and FileAccess.get_sha256(model.ROOT+path)==model.motions.texture_hashes[path]
 check(textures_current,"Prepared atlases and portraits retain their baked hashes")
 var planted=true
 for direction in 8:
  for frame in model.motions.clips["0:%d"%direction].frames:
   planted=planted and frame[6]+frame[4]>=8 and frame[6]+frame[4]<=22
 check(planted,"Every idle frame keeps its shoes at the ground across sheet-row boundaries")
 for stance in [[0,166.0],[1,166.0],[3,148.0]]:
  var consistent=true
  for direction in 8:
   var clip:Dictionary=model.motions.clips["%d:%d"%[stance[0],direction]]
   consistent=consistent and absf(float(clip.authoring_body_height)*2/float(clip.authoring_units)-stance[1])<.01
  check(consistent,"All eight views share the %.0f-pixel body ruler for action %d"%[stance[1],stance[0]])
 check(model.sprite.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR,"Illustrated details use smooth texture filtering")
 check(is_equal_approx(model.sprite.pixel_size*model.BODY_HEIGHT_PIXELS,preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT),"Kazi's standing body matches Goemon's reference height")
 check(SoundLibrary.original_for(34,"swing").resource_path.ends_with("/cgply01a.wav"),"Original Cross Gate sword sample is prepared")
 check(SoundLibrary.original_for(34,"hit").resource_path.ends_with("/cgefc04.wav"),"Recovered Cross Gate impact is prepared")
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
 await capture_turns(model,back,right)
 var saved_phase=model.phase
 var saved_steps=model.locomotion.step_events
 model.phase=.48;model.locomotion_velocity=right*2
 model.animate(.04,2,true,0,0,false,0,false)
 check(model.locomotion.step_events==saved_steps+1,"A grounded half-stride emits one footstep")
 var walk_phase=model.phase
 model.locomotion_velocity=right*8
 p.facing=right;model.animate(0,8,true,0,0,false,0,false)
 check(is_equal_approx(model.phase,walk_phase) and model.current_frame==floori(walk_phase*18),"Walk/run and direction changes retain stride phase")
 saved_steps=model.locomotion.step_events
 model.animate(.3,8,false,3,0,false,0,false)
 model.locomotion_velocity=Vector3.ZERO;model.animate(.3,8,true,0,0,false,0,false)
 check(model.locomotion.step_events==saved_steps,"Airborne or obstructed movement emits no footsteps")
 var blocked_phase=model.phase
 model.animate(.2,10.2,true,0,0,false,0,false)
 check(is_equal_approx(model.phase,blocked_phase) and model.current_clip.begins_with("0:"),"A blocked character holds stride phase and returns to idle")
 model.phase=0;model.locomotion_velocity=right*8;model.animate(.1,10.2,true,0,0,false,0,false)
 var fast_phase=model.phase
 model.phase=0;model.locomotion_velocity=right*4;model.animate(.2,10.2,true,0,0,false,0,false)
 check(is_equal_approx(model.phase,fast_phase),"Equal travelled distance produces equal run phase despite different commanded speeds")
 model.phase=0;model.locomotion_velocity=right*model.RUN_STRIDE_METERS
 model.animate(.5,10.2,true,0,0,false,0,false)
 check(is_equal_approx(model.phase,.5),"One physical half-stride advances exactly to the opposite foot contact")
 model.phase=saved_phase
 model.locomotion_velocity=Vector3.ZERO
 var spell=Node.new();game.add_child(spell)
 model.animate_spell(.01,spell);model.animate_spell(.12,spell)
 check(model.current_clip.begins_with("6:") and model.current_frame==4,"Shared skills advance Kazi's illustrated cast gesture")
 model.animate(0,0,true,0,0,false,0,false);model.animate_spell(.01,spell)
 check(model.current_frame==0,"A new cast starts from its preparation frame")
 spell.queue_free()
 for pair in [[-back,1],[right,3],[back,5],[-right,7]]:
  model.locomotion_velocity=pair[0]*2
  p.facing=pair[0];model.animate(0,2,true,0,0,false,0,false)
  check(model.current_clip=="1:%d"%pair[1],"Straight walk selects source cardinal direction "+str(pair[1]))
  await capture("straight-walk-%d"%pair[1])
  model.locomotion_velocity=pair[0]*5;model.animate(0,5,true,0,0,false,0,false)
  check(model.current_clip=="3:%d"%pair[1],"Straight run selects source cardinal direction "+str(pair[1]))
 if DisplayServer.get_name()!="headless":
  p.facing=back
  await capture_motion(model,1,"front-walk")
  await capture_motion(model,3,"front-run")
  p.facing=right;await capture_motion(model,3,"side-run")
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
 var ran=false
 for frame in 35:
  await advance(1)
  if not ran and model.current_clip.begins_with("3:"):
   ran=true;await capture("run")
 check(p.position.distance_to(start)>.5 and ran,"Real Hero movement plays illustrated run before slowing at obstacles (distance=%.3f clip=%s)"%[p.position.distance_to(start),model.current_clip])
 check(audio_events.any(func(event):return event.kind=="step" and event.stream==SoundLibrary.GOEMON_FOOTSTEP),"Kazi's actual movement uses Goemon's baseline footstep")
 await capture_travel()
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
 kit.tick(.002);model.animate(0,0,true,0,0,false,0,false)
 check(contacts.size()==1,"One exact contact damages the target")
 record_audio()
 check(audio_count("hit")==1 and audio_events.any(func(event):return event.kind=="hit" and event.stream==SoundLibrary.original_for(34,"hit")),"Landed contact plays the Cross Gate impact once")
 await capture("attack")
 model.show_pose(5,.42,false);await capture("attack-swing")
 kit.tick(.01);check(contacts.size()==1,"Contact cannot hit twice")
 kit.tick(1);record_audio();check(not kit.is_attacking() and p.attack_left==0,"Attack recovery clears its clock")
 check(audio_count("swing")==kit.sound_cues.size() and audio_count("hit")==1,"Source swing markers play once without repeating the hit")
 if recorder!=null:
  await create_timer(.9).timeout
  recorder.set_recording_active(false)
  var recording=recorder.get_recording();var data=recording.data
  var audible=false
  for offset in range(0,data.size()-1,2):
   if absi(data.decode_s16(offset))>128:audible=true;break
  check(audible,"Real SFX bus contains audible sword and impact playback")
  check(recording.save_to_wav(ProjectSettings.globalize_path(OUT+"kazi-attack-audio.wav"))==OK,"Saved actual game audio")
  AudioServer.remove_bus_effect(sfx,effect_index)
 fresh();tap("light_attack");tap("dodge");await advance(30)
 check(contacts.is_empty() and not kit.is_attacking(),"Dodge cancels pending damage")
 check(audio_count("swing")==0 and audio_count("hit")==0,"Dodge cancels pending sword audio")
 fresh();tap("heavy_attack");check(kit.is_attacking(),"RMB uses the same original sword gesture");kit.cancel()
 fresh();game.training_dummy.position=home+Vector3.FORWARD*100
 tap("light_attack");kit.tick(1);record_audio()
 check(audio_count("swing")==kit.sound_cues.size() and audio_count("hit")==0,"A missed sword attack has swings but no impact sound")
 fresh();await advance(90);await create_timer(1.2).timeout
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 12:
  tap("light_attack");await advance(45)
 await advance(120);await create_timer(1.2).timeout
 check(contacts.size()==12,"Twelve repeated attacks deliver twelve contacts")
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes,"Repeated attacks retain no extra nodes (%d → %d)"%[nodes,Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
 check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated attacks retain no extra resources")
 fresh()
 var wall=StaticBody3D.new();wall.collision_layer=1
 var collider=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(4,4,.2)
 collider.shape=box;wall.add_child(collider);game.add_child(wall);wall.position=home+Vector3(0,1,-1)
 await physics_frame
 tap("light_attack");kit.tick(kit.CONTACT+.001)
 check(contacts.is_empty(),"Solid cover blocks the sword's exact contact")
 kit.cancel();wall.queue_free();await physics_frame;await physics_frame
 fresh()
 var owner=game.army_runtime
 var row=game.model.waves.spawn_enemy(0,home+Vector3.FORWARD*2)
 row.hp=10000;row.max_hp=10000;owner.import_arrivals();owner.integration_tick(1.0/60)
 var handle:int=owner.handles[row.id]
 var hp:float=owner.unit_state(handle).hp
 p.ai_controlled=true;p.ai_aim=owner.unit_state(handle).position
 kit.start_attack();p.ai_controlled=false;kit.tick(kit.CONTACT+.001)
 check(owner.unit_state(handle).hp<hp,"Sword damage reaches the actual native enemy lifecycle")
 kit.cancel();owner.despawn(handle);owner.integration_tick(1.0/60)
 fresh();tap("light_attack");p.select_character(1)
 check(not kit.is_attacking() and p.attack_left==0,"Switching fighter cancels the old sword")
 p.select_character(34);fresh()
 check(is_equal_approx(preload("res://scripts/forest/player_attack_range.gd").new().radius(p),3.42),"Range indicator uses Kazi's actual melee envelope")
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 for i in 5:
  var allocated=mirrors.reinforce(34,home+Vector3(i*2,0,5))
  check(allocated,"Kazi ally allocated through native owner "+str(i))
  if not allocated:break
  var body=mirrors.bodies[i]
  check(body.model.atlases[0]==model.atlases[0],"Ally shares prepared atlas "+str(i))
  body.perform(0,body.position+Vector3.FORWARD*5)
 check(mirrors.bodies.size()==5,"Native owner supplies all five bodies")
 for tick in 50:
  for body in mirrors.bodies:
   body.step(1.0/60,{"position":body.position,"hp":body.max_hp,"yaw":0.0,"pose_velocity":Vector3.ZERO})
  if DisplayServer.get_name()!="headless":await physics_frame
 check(mirrors.bodies.all(func(body):return not body.has_offensive_action()),"Five simultaneous allies finish their attacks")
 await capture("allies");mirrors.dispose();await frames(3)
 var metrics=preload("res://tests/forest-shrine/army_benchmark_metrics.gd")
 FileAccess.open(OUT+"focused-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"headless":DisplayServer.get_name()=="headless","manual_player_step_ms":metrics.summary(samples)},"  "))
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("KAZI_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
