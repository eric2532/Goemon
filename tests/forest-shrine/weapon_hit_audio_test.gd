extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Real native victims and both shared playback routes, without changing damage.
const Audio=preload("res://assets/rogue/scripts/audio.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
func stop_audio(node:Node):
 if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop()
 for child in node.get_children():stop_audio(child)
func explorer_cuts():
 var p=game.player;var lib=game.sound_library
 var expected=preload("res://assets/audio/recovered_musashi/fusion_swing.wav")
 p.select_character(11);p.position=ORIGIN;p.smoke_mode=true
 var combat=p.active_ability
 combat.player.pos=ORIGIN;combat.aim=ORIGIN+Vector3.FORWARD*20
 for slot in ["native_blade","move_primary_1_weapon","move_primary_2_weapon","move_primary_3_weapon","move_secondary_weapon"]:
  check(game.sound_preview(11,slot)==expected,"Explorer %s previews Musashi's light cut"%slot)
 for repeat in 3:
  for stage in 3:
   stop_audio(game);combat.sound.last_events.clear()
   combat.player.attack=null;combat.player.cooldowns.cutlass=0;combat.hit_stop=0
   combat.combo=stage;combat.combo_timer=1;combat.attack();combat.primary_held=false
   var attack:Dictionary=combat.player.attack
   combat.tick(attack.contact+.001,false)
   check(combat.sound.voices.any(func(v):return v.playing and v.stream==expected and v.pitch_scale==1),"Explorer actual cut %d plays Musashi at source pitch (repeat %d)"%[stage+1,repeat+1])
   var impact:AudioStream=SoundLibrary.BLADE_IMPACTS.heavy_hit if stage==2 else SoundLibrary.BLADE_IMPACTS.hit
   check(combat.sound.voices.any(func(v):return v.playing and v.stream==impact),"Explorer confirmed cut %d also plays Knight's contact sample"%(stage+1))
 stop_audio(game);combat.player.attack=null
 var context={"move_audio":{"character_id":11,"move_key":"primary_1","voiced":false}}
 lib.select_character(11)
 var take=preload("res://assets/audio/recovered_musashi/sword_hit.wav")
 lib.custom.native_blade=take;lib.gains.native_blade=.5
 combat.sound.last_events.clear();combat.sound.play("blade",{"style":"explorer","ticket":context})
 var voice=combat.sound.voices[(combat.sound.cursor-1)%combat.sound.voices.size()]
 check(voice.stream==take and is_equal_approx(db_to_linear(voice.volume_db),.55*.5),"Explorer keeps a saved blade recording and gain")
 lib.custom.erase("native_blade");lib.gains.erase("native_blade");lib.mutes.native_blade=true
 var cursor=combat.sound.cursor
 combat.sound.last_events.clear();combat.sound.play("blade",{"style":"explorer","ticket":context})
 check(combat.sound.cursor==cursor,"Explorer blade mute still suppresses the recovered cut")
 lib.mutes.erase("native_blade")
 stop_audio(game)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 200:
  combat.sound.last_events.clear();combat.sound.play("blade",{"style":"explorer","combo":i%3,"ticket":context})
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated Explorer cuts reuse prepared samples and voices")
 if "--visual" in OS.get_cmdline_user_args():
  stop_audio(game)
  var capture=AudioEffectRecord.new();capture.format=AudioStreamWAV.FORMAT_16_BITS
  var bus=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,capture)
  await create_timer(.15).timeout;capture.set_recording_active(true)
  combat.sound.last_events.clear();combat.sound.play("blade",{"style":"explorer","ticket":context})
  await create_timer(.5).timeout;capture.set_recording_active(false)
  var recording=capture.get_recording()
  check(recording!=null and recording.data.count(0)<recording.data.size(),"Desktop mixer records Explorer's audible cutting sound")
  if recording!=null:check(recording.save_to_wav("res://build/Other Files/Asset Toolkit/ROM Combat Audio/explorer-cut.wav")==OK,"Save Explorer cut for listening")
  AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 stop_audio(game)
func run():
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_physics_process(false)
 var p=game.player;var lib=game.sound_library;var runtime=game.army_runtime
 var native=Audio.new();native.game=game;game.add_child(native)
 await explorer_cuts()
 for id in p.RogueRoster.selection_ids():
  for slot in ["hit","heavy_hit"]:
   check((game.sound_preview(id,slot)==null)==SoundLibrary.source_slot_is_silent(id,slot),"Fighter %d retains its contact audio or intentional source silence"%id)
 for slot in SoundLibrary.COMBAT_DEFAULTS:
  var expected:AudioStream=SoundLibrary.COMBAT_DEFAULTS[slot]
  check(game.sounds[slot]==expected and expected.get_length()>0,"Shared %s default uses a prepared Musashi ROM sample"%slot)
  for enemy_source in [false,true]:
   game.sound(slot,.7,enemy_source,{},2)
   check(game.last_sound_voice.stream==expected and game.last_sound_voice.pitch_scale==1,"Generic %s contact retains ROM pitch (enemy=%s)"%[slot,enemy_source])
  check(game.sound_preview(2,slot)==expected,"Preview matches the shared %s default"%slot)
 var serial=game.voice_idx
 for id in p.RogueRoster.selection_ids():game.sound("enemy_reaction",.4,false,{},id)
 check(game.voice_idx==serial,"Default reactions never layer the old generated hurt over ROM contact/death audio")
 lib.select_character(2)
 var reaction=SoundLibrary.BLADE_IMPACTS.hit
 lib.custom.enemy_reaction=reaction;lib.gains.enemy_reaction=.5
 game.sound("enemy_reaction",.4,false,{},2)
 check(game.last_sound_voice.stream==reaction and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.4*.55*.45*.5),"An explicitly saved reaction still plays with its saved gain")
 check(game.sound_preview(2,"enemy_reaction")==reaction,"A saved reaction previews even with a silent default")
 lib.mutes.enemy_reaction=true;serial=game.voice_idx;game.sound("enemy_reaction",.4,false,{},2)
 check(game.voice_idx==serial,"A saved reaction still respects mute")
 lib.custom.erase("enemy_reaction");lib.gains.erase("enemy_reaction");lib.mutes.erase("enemy_reaction")
 for id in [2,3,4,5,6,7,8,10,11,12,14,15,18,20,21,22,23,24,25,26,27,28,30]:
  for slot in ["hit","heavy_hit"]:
   var expected:AudioStream=SoundLibrary.BLADE_IMPACTS[slot]
   check(game.sound_preview(id,slot)==expected,"Fighter %d previews reused %s"%[id,slot])
   game.sound(slot,.7,false,{},id)
   check(game.last_sound_voice.stream==expected and game.last_sound_voice.pitch_scale==1,"Shared contact uses the prepared sample at source pitch")
   native.last_events.clear();native.play("heavy" if slot=="heavy_hit" else "hit",{"character_id":id})
   check(native.voices[(native.cursor-1)%native.voices.size()].stream==expected,"Native contact uses the same default")
   check(native.voices[(native.cursor-1)%native.voices.size()].pitch_scale==1,"Native recovered impact retains its pitch")
 check(game.sound_preview(9,"heavy_hit")==load("res://assets/rogue/audio/claymore-impact-heavy.wav"),"Magic Swordsman retains its dedicated impact")
 for id in [1,13,16,17]:
  var bank=load("res://scripts/recovered_%s_audio.gd"%{1:"goemon",13:"musashi",16:"sasuke",17:"yae"}[id])
  check(lib.original_for(id,"hit")==bank.stream_for("hit"),"Fighter %d retains its own recovered contact"%id)
 check(lib.original_for(8,"native_pierce")==SoundLibrary.BLADE_IMPACTS.hit,"Lance thrust contact shares the blade default")
 lib.select_character(7)
 var take=AudioStreamWAV.new();take.mix_rate=22050;take.data=PackedByteArray([0,32,0,0]);take.format=AudioStreamWAV.FORMAT_16_BITS
 lib.custom.hit=take
 check(lib.playback_for(7,"hit",null).stream==take,"Saved character recording wins over reused default")
 lib.custom.erase("hit");lib.mutes.hit=true
 var before=game.voice_idx;game.sound("hit",.7,false,{},7)
 check(game.voice_idx==before,"Character mute still suppresses contact")
 lib.mutes.erase("hit")
 lib.recording=true;before=game.voice_idx;game.sound("hit",.7,false,{},7)
 var cursor=native.cursor;native.last_events.clear();native.play("hit",{"character_id":7})
 check(game.voice_idx==before and native.cursor==cursor,"Recording suppresses both playback routes")
 lib.recording=false
 # Exercise the real damage/contact route against every ordinary enemy form.
 p.select_character(7);p.active_ability.player.pos=ORIGIN
 var combat=p.active_ability
 for kind in Roles.RIGID_TYPES:
  runtime.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
  runtime.set_navigation(3000+kind,{"width":0})
  var row=game.model.waves.spawn_enemy(kind,ORIGIN+Vector3(0,0,-2));row.hp=10000;row.max_hp=10000
  runtime.import_arrivals();runtime.sync_targets()
  var victim=game.actors[row.id]
  var target={"node":victim,"pos":victim.global_position,"hp":victim.hp,"type":"soldier"}
  if kind==0:
   for id in range(3,13):
    p.select_character(id)
    var fighter=p.active_ability;fighter.player.pos=ORIGIN
    fighter.sound.last_events.clear();var hp:float=victim.hp
    fighter.hit(target,10,"cutlass",false,Vector3.FORWARD,"","claymore" if id==9 else "sword")
    var expected:AudioStream=load("res://assets/rogue/audio/claymore-impact-light.wav") if id==9 else SoundLibrary.BLADE_IMPACTS.hit
    var voice=fighter.sound.voices[(fighter.sound.cursor-1)%fighter.sound.voices.size()]
    check(victim.hp<hp and voice.playing and voice.stream==expected,"Old fighter %d damages a native victim and plays its contact sound"%id)
   p.select_character(7);combat=p.active_ability;combat.player.pos=ORIGIN
  for repeat in 3:
   combat.sound.last_events.clear();var old_cursor:int=combat.sound.cursor;var hp:float=victim.hp
   combat.hit(target,10,"cutlass",false,Vector3.FORWARD,"","sword")
   check(victim.hp<hp and combat.sound.cursor!=old_cursor,"Repeated confirmed blade hit sounds on native kind %d"%kind)
   check(combat.sound.voices[(combat.sound.cursor-1)%combat.sound.voices.size()].stream==SoundLibrary.BLADE_IMPACTS.hit,"Real contact selects Musashi sword hit")
  if kind in [0,1,3]:
   var deaths=preload("res://scripts/forest/forest_soldier_audio.gd").ensure(game)
   deaths.reset();var started:int=deaths.plays_started
   var kills:int=game.kills
   combat.sound.last_events.clear();combat.hit(target,100000,"cutlass",false,Vector3.FORWARD,"","sword")
   check(victim.dead and game.kills==kills+1 and deaths.plays_started==started+1,"Lethal contact keeps native death accounting and one ROM soldier cry")
   check(deaths.voices.any(func(v):return v.playing and v.stream==deaths.SCREAM and v.pitch_scale==1),"Native death uses the prepared pitch-bend ROM scream")
  victim.mark_dead();cursor=combat.sound.cursor
  combat.hit(target,10)
  check(combat.sound.cursor==cursor,"Rejected dead-target contact stays silent")
 stop_audio(game)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 100:
  game.sound("hit",.7,false,{},2);game.sound("enemy_reaction",.4,false,{},2)
  native.last_events.clear();native.play("hit",{"character_id":7})
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated overlapping impacts reuse voices and resources")
 if "--visual" in OS.get_cmdline_user_args():
  var capture=AudioEffectRecord.new();capture.format=AudioStreamWAV.FORMAT_16_BITS
  var bus=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,capture)
  for slot in ["hit","heavy_hit","environment_hit","enemy_death"]:
   stop_audio(game);await create_timer(.15).timeout;capture.set_recording_active(true)
   if slot=="enemy_death":
    var deaths=preload("res://scripts/forest/forest_soldier_audio.gd").ensure(game)
    deaths.reset();check(deaths.death(p.global_position,0),"Desktop audition starts the original soldier death cry")
   else:game.sound(slot,.7,false,{},2)
   await create_timer(.7).timeout;capture.set_recording_active(false)
   var recording=capture.get_recording()
   check(recording!=null and recording.get_length()>.5 and recording.data.count(0)<recording.data.size(),"Desktop mixer produces audible %s output"%slot)
   if recording!=null:check(recording.save_to_wav("res://build/Other Files/Asset Toolkit/ROM Combat Audio/"+slot+".wav")==OK,"Save %s output for listening"%slot)
  AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
  for id in [1,2,7,8,11,13,15]:
   game.sound("hit",.7,false,{},id);await create_timer(.65).timeout
 game.queue_free();game=null;paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("WEAPON_HIT_AUDIO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
