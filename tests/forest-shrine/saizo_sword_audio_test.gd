extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Roster=preload("res://scripts/rogue_roster.gd")
const SWING=preload("res://assets/audio/crossgate/special_skins/cgply02a.wav")
const HIT=preload("res://assets/audio/crossgate/kazi/cgply11a.wav")
const OUT="res://build/Other Files/Asset Toolkit/Saizo Sword Motion/"

func run():
 create_timer(90).timeout.connect(func():printerr("SAIZO_AUDIO_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false)
 for node in [game,game.player,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 var p=game.player
 p.select_character(Roster.SAIZO_ID);p.position=ORIGIN;p.smoke_mode=true
 var kit=p.active_ability
 var dummy=game.training_dummy
 var lib=game.sound_library
 check(game.sound_preview(Roster.SAIZO_ID,"swing")==SWING,"Saizo previews original swing 105 instead of Maze's 103")
 check(game.sound_preview(Roster.MAZE_ID,"swing")!=SWING,"Maze retains his own sword sound")
 for skin in Roster.SaizoSkins.CATALOG:
  game.select_saizo_skin(skin);kit.set_weapon(Roster.MazeWeapon.KATANA)
  for landed in [false,true]:
   kit.cancel();p.attack_chain.reset();contacts.clear();p.facing=Vector3.FORWARD
   dummy.position=ORIGIN+Vector3.FORWARD*(2 if landed else 20);dummy.home=dummy.position
   tap("light_attack")
   check(kit.is_attacking() and kit.cut_times.size()==1 and kit.duration==1.0,"Skin %d uses one original sword cut over its native clock"%skin)
   var cues=kit.sound_cues.duplicate(true);var cuts=kit.cut_times.duplicate()
   var rate=p.attack_speed_multiplier()
   for i in cuts.size():
    var before=game.voice_idx
    kit.tick((float(cues[i].atMs)/1000-kit.elapsed-.0001)/rate)
    check(game.voice_idx==before,"Skin %d cut %d waits for its swing marker"%[skin,i])
    kit.tick(.0002/rate)
    check(game.voice_idx==before+1 and game.last_sound_voice.stream==SWING and game.last_sound_voice.pitch_scale==1,"Skin %d cut %d plays original swing 105 once"%[skin,i])
    before=game.voice_idx
    kit.tick((float(cuts[i])-kit.elapsed+.0001)/rate)
    p.model.show_pose(5,kit.elapsed,false)
    check(p.model.current_frame==6,"Original contact drawing is source frame six")
    check(contacts.size()==(i+1 if landed else 0),"Skin %d cut %d preserves exact contact/miss"%[skin,i])
    check((game.voice_idx==before+1 and game.last_sound_voice.stream==HIT) if landed else game.voice_idx==before,"Skin %d cut %d sounds an impact only on contact"%[skin,i])
   var before=game.voice_idx
   kit.tick((kit.duration-kit.elapsed-.0001)/rate)
   p.model.show_pose(5,kit.elapsed,false)
   check(p.model.current_frame==13 and contacts.size()==(1 if landed else 0),"Full recovery reaches frame thirteen without a second cut")
   kit.tick(.0002/rate)
   check(game.voice_idx==before and not kit.is_attacking(),"Recovery adds no sword sound or queued attack")
 lib.select_character(Roster.SAIZO_ID);lib.custom.swing=HIT;lib.gains.swing=.4
 p.play_sound("swing",.5)
 check(game.last_sound_voice.stream==HIT and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.5*.55*.4),"Saved Saizo recording and gain still override the default")
 lib.mutes.swing=true;var before=game.voice_idx;p.play_sound("swing",.5)
 check(game.voice_idx==before,"Saved swing mute still works")
 lib.custom.erase("swing");lib.gains.erase("swing");lib.mutes.erase("swing")
 await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var times=[]
 for repeat in 40:
  contacts.clear();kit.cancel();p.attack_chain.reset();tap("light_attack")
  var rate=p.attack_speed_multiplier()
  for tick in 61:
   var start=Time.get_ticks_usec()
   kit.tick(1.0/60/rate);p.model.animate(1.0/60,0,true,0,0,false,0,false)
   times.append(Time.get_ticks_usec()-start)
  check(contacts.size()==1,"Repeated sword use keeps exactly one hit")
 await frames(3);times.sort()
 print("SAIZO_CONTROLLER_POSE_US p95=",times[floori(times.size()*.95)]," max=",times.back()," nodes=",nodes,"/",get_node_count()," resources=",resources,"/",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Forty warmed sword cycles retain no extra nodes or resources")
 if "--visual" in OS.get_cmdline_user_args():await audition()
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SAIZO_SWORD_AUDIO_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func audition():
 var p=game.player;var kit=p.active_ability
 game.select_saizo_skin(Roster.SaizoSkins.DEFAULT);kit.set_weapon(Roster.MazeWeapon.KATANA)
 var home=Vector3(-150,0,150);home.y=game.model.surface_height(home.x,home.z)+.1
 p.position=home
 game.training_dummy.position=home+Vector3.RIGHT*2;game.training_dummy.home=game.training_dummy.position
 game.camera_rig.camera.global_position=home+Vector3(0,3.8,9)
 game.camera_rig.camera.look_at(home+Vector3.UP*1.5)
 game.model.update_vision(home);game.forest_ui.sync()
 game.camera_rig.yaw=-PI/2
 p.model.show_pose(5,0,false);await frames(3)
 var effect=AudioEffectRecord.new();effect.format=AudioStreamWAV.FORMAT_16_BITS
 var bus=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,effect)
 await create_timer(.2).timeout;effect.set_recording_active(true)
 for repeat in 3:
  kit.cancel();p.attack_chain.reset();p.facing=Vector3.RIGHT;tap("light_attack")
  var elapsed=0.0
  for frame in 70:
   kit.tick(1.0/60);elapsed+=1.0/60*p.attack_speed_multiplier();p.model.show_pose(5,minf(elapsed,1.0),false)
   if repeat==0 and frame in [0,10,17,22,30,37,45,49]:
    RenderingServer.force_draw()
    check(root.get_texture().get_image().save_png(OUT+"sword-%02d.png"%frame)==OK,"Captured sword frame %d"%frame)
   await create_timer(1.0/60).timeout
 effect.set_recording_active(false)
 var wav=effect.get_recording()
 check(wav!=null and wav.data.count(0)<wav.data.size(),"Desktop SFX mixer produces audible sword output")
 if wav!=null:check(wav.save_to_wav(OUT+"saizo-sword.wav")==OK,"Saved live mixer output")
 AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
