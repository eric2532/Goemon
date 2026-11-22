extends SceneTree
const Document=preload("res://scripts/forest/forest_map_document.gd")
const MoveAudio=preload("res://scripts/move_audio.gd")
var checks=0
var failures=0
var game
var cfg="user://nearby-ally-audio-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",note)
func frames(count=3):
 for i in count:await process_frame
func quiet():
 for voice in game.voices:voice.stop()
 game.move_audio.stop()
 game.crowd.army.presentation.suspend_audio()
 game.crowd.army.presentation.next_sound=0
func run():
 create_timer(180).timeout.connect(func():printerr("NEARBY_ALLY_AUDIO_TIMEOUT");quit(1))
 for large in [false,true]:
  var document=Document.new(false)
  check((document.load_wind_meadow_large() if large else document.load_wind_meadow()).is_empty(),"Bundled map validates")
  var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{},document.data,false)
  check(document.data.buildings.is_empty() and model.buildings.size()==1 and model.shrine().kind=="shrine","Both presets start with only the statue")
  check(model.portals.size()==4 and model.workers.is_empty() and model.waves.active_cap()==240,"Enemy castles and army cap are retained with zero starting workers")
  document.data.buildings.append({"kind":"tower","x":3,"z":4,"rotation":2})
  var saved=Document.new(false)
  check(saved.decode(document.encode()).is_empty() and saved.data.buildings.size()==1,"Saved custom tower survives normalization")
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 check(game.world.structure_nodes.size()==1,"Normal game renders only the statue")
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 for node in [game,game.player,game.camera_rig,game.army_runtime]:
  node.set_process(false);node.set_physics_process(false)
 game.music.stop();game.settings.volume=.65;game.camera_focused=false;game._sync_camera_mouse()
 game.player.position=game.model.point(Vector2i(0,3))+Vector3.UP*.15
 var heroes=game.explorer_helpers.legendary_heroes
 var source=game.player.position
 check(heroes.reinforce(31,source+Vector3.RIGHT*4),"Real native ally is available")
 var body=heroes.bodies.back()
 var ticket=body.attack_chain.begin("warcraft_attack")
 check(ticket.allied,"Ally attacks retain their source ownership")
 for offset in [4.0,15.0,15.01,65.0]:
  body.global_position=source+Vector3.RIGHT*offset
  var before=game.voice_idx;game.sound("wc_attack_1",.8,false,ticket,31)
  check((game.voice_idx>before)==(offset<=15),"Hero attack cutoff at %.2f metres"%offset)
 body.global_position=source+Vector3.UP*16
 check(not MoveAudio.ticket_audible(game,ticket),"Height separation is included")
 body.global_position=source+Vector3.RIGHT*65
 var own=game.voice_idx;game.player.play_sound("swing")
 check(game.voice_idx>own,"Player attack remains audible")
 var paired=game.move_audio.cursor;ticket.move_audio={"character_id":1,"move_key":"primary_1","voiced":false}
 game.move_audio.release(game,ticket)
 check(game.move_audio.cursor==paired and not ticket.move_audio.voiced,"Distant ally cannot release a paired global voice")
 # The proxy must gate before the shared Rogue pool's throttle and cursor.
 var shared=game.get_node_or_null("RogueSharedClassAudio")
 if shared==null:
  shared=load("res://assets/rogue/scripts/audio.gd").new();shared.game=game;game.add_child(shared)
 var proxy=load("res://scripts/forest/forest_gate_audio.gd").new();proxy.hero=body;proxy.game=game;proxy.shared=shared;body.add_child(proxy)
 var cursor=shared.cursor;shared.last_events.clear();proxy.play("blade",{"style":"samurai","ticket":ticket})
 check(shared.cursor==cursor and shared.last_events.is_empty(),"Distant Rogue ally consumes no shared sound slot")
 body.global_position=source+Vector3.RIGHT*4;proxy.play("blade",{"style":"samurai","ticket":{}})
 check(shared.cursor!=cursor,"Nearby Rogue ally remains audible")
 var fx=game.crowd.army.presentation
 for kind in ["landing_pulse","status","melee"]:
  for offset in [4.0,25.0]:
   quiet();var before=fx.voices.map(func(v):return v.get_meta("started",-1))
   fx.clock+=1
   fx.present([{"kind":kind,"position":source+Vector3.RIGHT*offset,"team":1,"unit_kind":31 if kind=="melee" else 8,"action_index":18 if kind=="status" else 0}])
   var after=fx.voices.map(func(v):return v.get_meta("started",-1))
   check((before!=after)==(offset<=15),"Native %s cue respects player proximity"%kind)
 quiet();var serial=game.voice_idx
 body.global_position=source+Vector3.RIGHT*25
 fx.dark_cue(source,0,0,body.get_instance_id(),1,1,true,true,ticket)
 fx.finale_cue(source,33,Vector3.FORWARD,body.get_instance_id(),0,1,1,ticket)
 check(game.voice_idx==serial,"Borrowed Dark and Finale foreground attacks respect their ally ticket")
 body.global_position=source+Vector3.RIGHT*4;fx.finale_loop(source,"wind_loop",3,-999,ticket)
 check(fx.voices.any(func(v):return v.get_meta("finale_loop","")=="wind_loop" and v.get_meta("audio_ticket",{})==ticket),"Nearby allied sustained spell uses its existing voice pool")
 await frames();body.global_position=source+Vector3.RIGHT*25;fx.tick(.01);await frames()
 check(fx.voices.all(func(v):return not v.playing),"Allied spell loop stops when the source leaves close range")
 # Exercise Illidan's real controller, including a power with no attack ticket yet.
 check(heroes.reinforce(32,source+Vector3.RIGHT*25),"Real native Illidan is available")
 var illidan=heroes.bodies.back();var kit=illidan.active_ability
 quiet();illidan.attack_chain.reset();kit.cancel()
 var start_order=game.voice_idx;kit.toggle_immolation()
 check(game.voice_idx==start_order,"Distant Illidan immolation cannot borrow the player audio ticket")
 kit.cancel();start_order=game.voice_idx;kit.start_attack()
 check(game.voice_idx==start_order,"Distant real Illidan melee is silent")
 kit.cancel();kit.clear_cooldowns();start_order=game.voice_idx;kit.start_morph()
 check(game.voice_idx==start_order,"Distant real Illidan morph is silent")
 kit.tick(kit.duration);kit.start_attack();kit.tick(kit.contact)
 check(game.voice_idx==start_order,"Distant real Illidan demon launch is silent")
 var pool=load("res://scripts/character_projectile_pool.gd").service(game)
 for shots in pool.all.values():
  for shot in shots:
   if shot.pool_live and shot.hero==illidan:
    shot.set_physics_process(false);shot.explode(source+Vector3.RIGHT*25);shot.retire()
 check(game.voice_idx==start_order,"Distant real Illidan demon impact is silent")
 kit.cancel();illidan.global_position=source+Vector3.RIGHT*4;kit.start_attack()
 var nearby_voice=game.last_sound_voice
 game.move_audio.play_voice(game,32,"wc_ready",kit.ticket)
 var nearby_pair=game.move_audio.voices[(game.move_audio.cursor+game.move_audio.voices.size()-1)%game.move_audio.voices.size()]
 check(nearby_pair.playing,"Nearby paired ally voice is audible")
 check(game.voice_idx>start_order and nearby_voice.playing,"Nearby real Illidan melee is audible")
 illidan.global_position=source+Vector3.RIGHT*25;game.sound_library._process(0)
 check(not nearby_voice.playing and not nearby_pair.playing,"Playing ally weapon and paired voices stop when their source leaves range")
 game.sound("wc_attack_1",.8,false,game.player.attack_chain.make_ticket("pipe"),32)
 var own_voice=game.last_sound_voice;game.sound_library._process(0)
 check(own_voice.playing,"Reusing an ally voice for the player clears obsolete source ownership")
 kit.cancel();quiet()
 # Repeat bursts from five actual allied bodies without changing army ownership.
 for id in [1,13,28]:check(heroes.reinforce(id,source+Vector3(4,0,id%4)),"Native hero %d joins the simultaneous fixture"%id)
 var voice_ids=game.voices.map(func(v):return v.get_instance_id())
 for cycle in 3:
  for ally in heroes.bodies:
   ally.global_position=source+Vector3.RIGHT*(4 if cycle%2==0 else 25)
   var t=ally.attack_chain.begin("pipe")
   var before=game.voice_idx;game.sound("wc_attack_1",.5,false,t,31)
   check((game.voice_idx>before)==(cycle%2==0),"Repeated simultaneous hero cue is near-only")
 quiet();await frames(12)
 var nodes=game.get_tree().get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var times=[]
 for i in 1000:
  body.global_position=source+Vector3.RIGHT*25
  var before=Time.get_ticks_usec();game.sound("wc_attack_1",.8,false,ticket,31);times.append(Time.get_ticks_usec()-before)
 check(game.voices.map(func(v):return v.get_instance_id())==voice_ids,"Repeated attacks reuse the existing voice pool")
 await frames(12)
 check(game.get_tree().get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated distant attacks retain no nodes or resources")
 if DisplayServer.get_name()!="headless":
  var bus=AudioServer.get_bus_index("SFX");var recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS;AudioServer.add_bus_effect(bus,recorder)
  for id in [31,32]:
   for near in [true,false]:
    quiet()
    for voice in shared.voices:voice.stop()
    await create_timer(.2).timeout
    body.global_position=source+Vector3.RIGHT*(4 if near else 25)
    illidan.global_position=body.global_position;kit.cancel()
    recorder.set_recording_active(true)
    if id==32:kit.start_attack()
    else:game.sound("wc_attack_1",.8,false,ticket,31)
    await create_timer(.4).timeout;recorder.set_recording_active(false)
    var wav=recorder.get_recording();var peak=0
    for offset in range(0,wav.data.size(),2):peak=maxi(peak,absi(wav.data.decode_s16(offset)))
    check((peak>0)==near,"Actual SFX mix contains nearby %d attack and silence at distance"%id)
    wav.save_to_wav("res://build/Other Files/Asset Toolkit/Illidan Audio/%d-%s.wav"%[id,"near" if near else "far"])
    print("ALLY_AUDIO_PCM id=",id," near=",near," peak=",peak)
  AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
  game.model.phase="preparing";game.set_phase_view();await frames();await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://build/Other Files/Ally Audio/statue-only.png")
 times.sort();print("ALLY_AUDIO_ROUTER_US p95=",times[int(times.size()*.95)]," max=",times.back())
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("NEARBY_ALLY_AUDIO_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
