extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const OUT="res://build/Other Files/Asset Toolkit/Dark Lumina 2/Fire and Audio Buffs/"
const INPUTS=["scripts/player.gd","scripts/recovered_enemy_combat.gd","scripts/recovered_enemy_projectile.gd","scripts/recovered_enemy_model.gd","scripts/forest/dark_lumina_kit.gd","scripts/spells/spell_instance.gd","scripts/spells/spell_loadout.gd","scripts/forest/crowd/army_presentation.gd","scripts/forest/crowd/army_runtime.gd","assets/characters/recovered_monsters/dark_lumina_2_runtime.res","native/terrain_math/bin/libgoemon_terrain_math.macos.universal.dylib"]
var recorder:AudioEffectRecord
var released=0
var damage_frames=[]
var frame_samples=[]
var focused=0
var stepped=0
var home_point=Vector3(0,.1,140)
func fresh(surge:bool=false):
 super.fresh(surge)
 damage_frames.clear()
 game.player.position=home_point
 game.training_dummy.home=home_point+Vector3(0,0,-12)
 game.training_dummy.position=game.training_dummy.home
 game.model.update_vision(home_point)
func trace(label_:String):
 var p=game.player;var c=p.active_ability
 print("DARK_STATE ",label_," position=",p.position," action=",c.action if c!=null else -1," mode=",c.mode if c!=null else ""," elapsed=",c.elapsed if c!=null else 0," floor=",p.is_on_floor()," shots=",released," focused=",root.has_focus()," paused=",game.paused)
func advance(count:int,visual:bool=false):
 for i in count:
  var start=Time.get_ticks_usec()
  game.training_dummy.recoil_age=1
  game.player._physics_process(1.0/60)
  for nodes in Pool.service(game).all.values():
   for shot in nodes:
    if shot.pool_live and shot.get_script()==preload("res://scripts/recovered_enemy_projectile.gd"):shot._physics_process(1.0/60)
  if game.training_dummy.recoil_age==0:damage_frames.append(stepped)
  game.crowd.army.presentation.tick(1.0/60)
  frame_samples.append((Time.get_ticks_usec()-start)/1000.0)
  stepped+=1
  if root.has_focus():focused+=1
  await physics_frame
func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 var p=game.player;var camera=game.camera_rig.camera
 camera.global_position=p.global_position+Vector3(45,28,-54);camera.look_at(p.global_position+Vector3(0,7,-6))
 p.model.show();await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Rendered "+name_)
func run():
 var hashes={}
 for path in INPUTS:hashes[path]=FileAccess.get_sha256("res://"+path)
 var map=preload("res://scripts/forest/forest_map_document.gd").new();map.load_wind_meadow()
 await setup_fixture(map.data)
 home_point.y=game.model.surface_height(home_point.x,home_point.z)+.1
 game.tuning.invincible=true
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_title("Goemon · Dark Lumina 2 gameplay tuning (DEBUG)");DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground();await frames(3)
 var p=game.player;var pool=Pool.service(game)
 if DisplayServer.get_name()!="headless":
  recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
  AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"),recorder)
 game.settings.volume=1;game.settings.music_enabled=false;game.apply_music_setting()
 pool.launched.connect(func(shot):
  if shot.get("kind")=="dark_lumina":
   released+=1;shot.set_physics_process(false)
   check(is_equal_approx(shot.velocity.length(),51.84) and is_equal_approx(shot.visual.mesh.size.x,20.7),"Fire launches three times larger again and twice as fast"))
 p.select_character(Dark.PLAYER);fresh();await advance(3)
 check(p.max_hp==5000 and preload("res://scripts/forest/forest_enemy_roles.gd").stats(Dark.ROLE).hp==5000,"Player and native enemy share 5000 base health")
 check(preload("res://scripts/forest/forest_enemy_roles.gd").stats(Dark.ROLE).damage==400,"Shared attack power increases from 80 to 400")
 var presentation=game.crowd.army.presentation
 # Foreground cues must survive both a saturated army pool and its cooldown.
 for voice in presentation.voices:voice.stream=Dark.sounds.breath;voice.play()
 presentation.next_sound=presentation.clock+1000
 for cue in ["step","fire_charge","fire_release"]:
  var order=game.voice_idx;p.active_ability.dark_sound(cue)
  check(game.voice_idx==order+1 and game.last_sound_voice.stream==Dark.sounds[cue] and game.last_sound_voice.playing,"Foreground "+cue+" survives army sound saturation")
 var lib=game.sound_library;lib.select_character(29)
 lib.custom["dark_lumina_2_fire_release"]=Dark.sounds.claw;lib.gains["dark_lumina_2_fire_release"]=.5
 p.active_ability.dark_sound("fire_release")
 check(game.last_sound_voice.stream==Dark.sounds.claw and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.55*.5),"Foreground fire respects saved recording and gain")
 lib.mutes["dark_lumina_2_fire_release"]=true;var order=game.voice_idx;p.active_ability.dark_sound("fire_release")
 check(game.voice_idx==order,"Foreground fire respects saved mute")
 lib.custom.clear();lib.gains.clear();lib.mutes.clear()
 for voice in presentation.voices:voice.stop()
 presentation.next_sound=0
 if recorder:recorder.set_recording_active(true)
 p.model.walk_tick=0;order=game.voice_idx
 for frame in 120:
  p.model.animate(1.0/60,17.28,true,0,0,false,0,false);await physics_frame
 check(game.voice_idx>=order+4,"Real walking markers dispatch all four foreground footsteps")
 if recorder:
  recorder.set_recording_active(false);var recording=recorder.get_recording()
  check(recording!=null and recording.data.count(0)<recording.data.size(),"Desktop mixer records audible walking")
  recording.save_to_wav(OUT+"walking.wav")
 check(p.active_ability.role==Dark.ROLE and p.model.role==Dark.ROLE,"Selected boss shares the rigid model and player combat adapter")
 check(p.body_shape.shape is BoxShape3D and is_equal_approx(p.body_shape.shape.size.y,15.552),"Boss keeps triple-size collision matching the rendered body")
 check(["shock_ring","shock_dome"].all(func(key):return Dark.meshes[key].surface_get_material(0).shader==preload("res://assets/characters/recovered_monsters/dark_lumina_2_effects/energy_mesh.gdshader")),"Original defeat meshes retain the source actor's additive blend and pooled fade")
 for slot in ["equip","surge","sky_strike"]:
  check(p.spell_loadout.spell_for(Dark.PLAYER,slot).begins_with("dark-lumina-2/"),"Default shared spell slot "+slot)
 await capture("idle")
 check(is_equal_approx(p.movement_multiplier(),p.progression.movement_multiplier()*Dark.MOVE_SPEED*(3 if p.scarf_equipped else 1)),"Playable ground movement preserves the current shared speed")
 var clips:Dictionary=p.model.resource.get_meta("clips")
 for key in clips:
  p.model.pose(key,float(clips[key].ticks)*.5,false)
  await frames(2);await RenderingServer.frame_post_draw
  check(p.model.current_clip==key and root.get_texture().get_image().save_png(OUT+"motion-"+key+".png")==OK,"Rendered preserved motion "+key)
 fresh();await advance(3)
 tap("jump");var jump_high=p.position.y;var jump_air=false;var jump_landed=0
 for frame in 100:
  await advance(1);jump_high=maxf(jump_high,p.position.y)
  if not p.is_on_floor():jump_air=true
  if jump_air and p.is_on_floor():jump_landed=frame;break
 check(jump_high>home_point.y+30 and jump_landed>0 and jump_landed<70,"Space jump uses Skullpion ascent and fast landing")
 fresh();await advance(3)
 game.training_dummy.position=home_point+Vector3(0,0,-54);game.training_dummy.home=game.training_dummy.position
 if recorder:recorder.set_recording_active(true)
 var fire_order=game.voice_idx
 tap("equip");await advance(50);await capture("paired-fireballs");await advance(192)
 check(game.voice_idx>=fire_order+7,"Actual fire cast dispatches charge and six release sounds")
 if recorder:
  recorder.set_recording_active(false);var recording=recorder.get_recording()
  check(recording!=null and recording.data.count(0)<recording.data.size(),"Desktop mixer records audible fire attack")
  recording.save_to_wav(OUT+"fire.wav")
 check(released==12,"Playable fireballs release six pairs")
 check(not p.active_ability.is_attacking(),"Fireball action recovers")
 var created=pool.created;var misses=pool.misses
 for use in 3:
  var before=released
  p.active_ability.start_dark_attack(Dark.FIRE);await advance(250)
  trace("repeat-%d"%use)
  check(released-before==12,"Repeated fire cast %d completes all twelve releases"%use)
 check(pool.created==created and pool.misses==misses,"Repeated twelve-shot volleys reuse prepared projectiles without growth")
 fresh();game.training_dummy.position=home_point+Vector3(0,0,-20);await advance(3);p.auto_attack_enabled=true;p.auto_lock_target=game.training_dummy;p.auto_lock_refresh=100
 p.active_ability.start_attack();p.auto_attack_enabled=false;await advance(8)
 check(p.active_ability.action==Dark.CLAW,"Claw has not contacted before its retimed source marker")
 await advance(2)
 check(contacts.size()==1,"Claw contacts once at the three-times-faster marker")
 trace("grab")
 check(p.active_ability.action==Dark.GRAB,"Claw contact enters original successful grab motion")
 await capture("grab");await advance(120)
 check(not p.active_ability.is_attacking() and damage_frames.size()==3,"Retimed grab preserves all three contacts and recovers within 2.2 seconds")
 fresh();await advance(3);game.training_dummy.position=home_point+Vector3(0,0,-120)
 p.active_ability.start_attack();await advance(35)
 check(not p.active_ability.is_attacking() and contacts.is_empty(),"A missed claw also recovers three times faster without stray hits")
 fresh();await advance(3);p.active_ability.start_dark_attack(Dark.SLAM)
 var high=p.position.y;var shock_captured=false
 for i in 250:
  await advance(1);high=maxf(high,p.position.y)
  if not shock_captured and p.active_ability.marker==2 and p.active_ability.pose_tick>=67:
   shock_captured=true;await capture("shockwave")
 trace("slam")
 check(high>home_point.y+30 and not p.active_ability.is_attacking(),"Jump slam leaves the ground, lands and completes both pulses")
 check(shock_captured,"Both ROM ground waves appear after landing")
 # Borrowing prepares the same role before _ready, and never changes the wearer.
 p.select_character(1);fresh();await advance(3)
 check(p.spell_loadout.equip(1,"equip","dark-lumina-2/fireballs"),"Another fighter can equip the shared fireball skill")
 var before=released;tap("equip");await advance(250)
 check(released-before==12 and p.character_id==1,"Borrowed skill uses the DL2 attack and keeps Goemon selected")
 fresh();await advance(3)
 p.spell_loadout.equip(1,"equip","dark-lumina-2/grab")
 p.auto_attack_enabled=true;p.auto_lock_target=game.training_dummy;p.auto_lock_refresh=100
 tap("equip");p.auto_attack_enabled=false;await advance(32)
 check(p.spell_loadout.current!=null and p.spell_loadout.current.controller.action==Dark.GRAB,"Borrowed claw preserves approach and successful grab")
 await advance(130)
 check(p.spell_loadout.current==null,"Borrowed grab releases its shared skill owner")
 fresh();await advance(3);p.spell_loadout.equip(1,"equip","dark-lumina-2/shockwave");tap("equip")
 high=p.position.y
 for i in 250:await advance(1);high=maxf(high,p.position.y)
 check(high>home_point.y+30 and p.spell_loadout.current==null and p.character_id==1,"Borrowed slam uses physical jump and landing without changing fighters")
 fresh();await advance(3);tap("equip");await advance(50)
 check(p.velocity.y>0 and p.spell_loadout.current!=null,"Borrowed slam reaches its rising phase")
 p.spell_loadout.cancel()
 check(p.velocity.y<=0 and p.spell_loadout.current==null,"Cancelling a borrowed leap releases its boss launch momentum")
 await advance(150)
 check(p.is_on_floor() and damage_frames.is_empty(),"Interrupted borrowed slam lands without delayed damage")
 p.spell_loadout.equip(1,"equip","");p.select_character(Dark.PLAYER);fresh();await advance(3)
 p.active_ability.start_dark_attack(Dark.FIRE);await advance(20);before=released
 p.active_ability._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);await advance(190)
 check(released==before and not p.active_ability.is_attacking(),"Focus loss cancels future releases")
 p.active_ability.die();p.model._process(1);await capture("death")
 check(p.model.current_clip=="Source__801f1a58","Death uses the recovered original motion")
 p.active_ability.cancel();await advance(240)
 check(pool.all.values().all(func(nodes):return nodes.all(func(shot):return not shot.pool_live)),"All pooled shots retire and clear their owner references")
 check(INPUTS.all(func(path):return hashes[path]==FileAccess.get_sha256("res://"+path)),"Verified runtime inputs remain unchanged during the rendered run")
 frame_samples.sort();var summary={"checks":checks,"failures":failures,"shots":released,"pool_created":pool.created,"pool_misses":pool.misses,"focused_frames":focused,"stepped_frames":stepped,"cpu_step_ms_p50":frame_samples[frame_samples.size()/2],"cpu_step_ms_p95":frame_samples[int(frame_samples.size()*.95)],"note":"Manual isolated gameplay steps, not a live frame-rate measurement"}
 var file=FileAccess.open(OUT+"gameplay-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(summary,"  "));file.close()
 FileAccess.open(OUT+"verified-source-hashes.json",FileAccess.WRITE).store_string(JSON.stringify(hashes,"  "))
 print("DARK_LUMINA_GAMEPLAY_RESULT ",summary)
 game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
