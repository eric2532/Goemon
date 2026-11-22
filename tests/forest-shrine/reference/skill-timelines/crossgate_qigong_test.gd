extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Qi=preload("res://scripts/qigong_combat.gd")
const OUT="res://build/Other Files/Asset Toolkit/Kazi Qi Orbs/Staggered Launch/"
const HP=100000.0
var launched:Array=[]
var owner:Node
var pool:Node
var player:Hero
var shot_step_ms:Array=[]
var home=Vector3(-150,.1,150)

func hotkey(down:bool,echo:bool=false,slot:int=1):
 var key=InputEventKey.new();key.physical_keycode=KEY_0+slot;key.pressed=down;key.echo=echo
 if down:player._unhandled_input(key)
 else:player._input(key)

func step_cast(ticks:int):
 for i in ticks:player._physics_process(1.0/60)

func step_shots(ticks:int):
 for i in ticks:
  var started=Time.get_ticks_usec()
  var active=0
  for shot in launched:
   if is_instance_valid(shot) and shot.pool_live:
    active+=1;shot._physics_process(1.0/60)
  if active>0:shot_step_ms.append((Time.get_ticks_usec()-started)/1000.0)

func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Captured "+name_)

func settle_feedback():
 await create_timer(.9).timeout

func check_cue(cue:String):
 check(game.voices.any(func(voice):return voice.get_meta("kind","")==cue and voice.stream==SoundLibrary.original_for(34,cue)),"Plays the recovered "+cue+" cue")

func check_skill_impacts():
 var dummy:Ninja=game.training_dummy
 dummy.global_position=home+Vector3.FORWARD*3
 game.model.update_vision(home)
 var point=AttackChain.aim_point(dummy,dummy.global_position+Vector3.UP)
 var knife_script=preload("res://scripts/recovered_enemy_projectile.gd")
 var clips={
  "qigong_hit":preload("res://assets/audio/crossgate/kazi/cgefc04.wav"),
  "cg_dagger_hit":preload("res://assets/audio/crossgate/maze/cgply15.wav")}
 var roster=player.RogueRoster
 for id in [1,13,14,16,roster.KAZI_ID,roster.RUBY_ID,roster.MAZE_ID,roster.SAIZO_ID]:
  for cue in clips:
   var shot=Qi.Shot.new() if cue=="qigong_hit" else knife_script.new()
   if cue=="qigong_hit":
    shot.target=dummy
    shot.attack_ticket.gold_palette=roster.has_crossgate_throws(id)
   else:
    shot.kind="maze_dagger"
    shot.target=weakref(dummy)
   shot.hero=player;shot.game=game;shot.damage=1.0
   shot.attack_ticket.crossgate_sound_source=id
   shot.velocity=Vector3.FORWARD*30
   game.add_child(shot)
   shot.global_position=point-Vector3.FORWARD*.2
   var order:int=game.voice_idx
   shot._physics_process(1.0/60)
   var voices=game.voices.filter(func(voice):return int(voice.get_meta("order",0))>order)
   check(voices.size()==1 and voices[0].get_meta("kind","")==cue and voices[0].stream==clips[cue],"%s uses only the %s contact sample"%[roster.name_for(id),cue])
   shot.free()

func run():
 DirAccess.make_dir_recursive_absolute(OUT)
 create_timer(90).timeout.connect(func():printerr("QIGONG_TIMEOUT");quit(1))
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
 game.explorer_helpers.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 root.gui_disable_input=true
 player=game.player
 player.set_process_input(false);player.set_process_unhandled_input(false)
 home.y=game.model.surface_height(home.x,home.z)+.1
 player.spell_loadout.equip(34,"equip",Qi.ID)
 player.select_character(34);fresh();player.position=home;step_cast(5)
 player.model.scale=Vector3.ONE*1.2
 var body_height=Qi.Proportions.GOEMON_HEIGHT*player.model.global_basis.y.length()
 game.model.update_vision(home)
 game.training_dummy.position=Vector3(0,-100,0);game.training_dummy.collision_layer=0
 owner=game.army_runtime
 owner.set_process(false);owner.set_physics_process(false)
 var rows=[]
 for i in 10:
  var point=home+Vector3(sin(i*TAU/10),0,-cos(i*TAU/10))*(5.0 if i==0 else 20.0+i*5.0)
  point.y=game.model.surface_height(point.x,point.z)+.1
  var row=game.model.waves.spawn_enemy(0,point);row.hp=HP;row.max_hp=HP;rows.append(row)
 owner.import_arrivals();owner.integration_tick(1.0/60)
 var targets=rows.map(func(row):return game.actors[row.id])
 check(targets.all(func(enemy):return enemy!=null and game.forest_enemy_visible(enemy)),"Ten visible enemies use the native army")
 pool=game.get_node("CharacterProjectiles")
 pool.launched.connect(func(shot):
  if shot.get_script()==Qi.Shot:
   shot.set_physics_process(false);launched.append(shot))
 game.camera_rig.camera.global_position=home+Vector3(6,5,10)
 game.camera_rig.camera.look_at(home+Vector3(0,1.7,0))
 check(player.spell_loadout.spell_for(34,"equip")==Qi.ID,"Kaz can equip Qi Orbs on slot 1")
 hotkey(true);hotkey(true,true);hotkey(false)
 var cast:Node=player.spell_loadout.current
 check(is_instance_valid(cast) and cast.controller.charge_fx.visible,"One press starts the recovered charge even after release")
 check_cue("qigong_charge")
 if not is_instance_valid(cast):quit(1);return
 var charge:Sprite3D=cast.controller.charge_fx
 check(is_equal_approx(charge.pixel_size*charge.global_basis.y.length()*357.0,Qi.BASE_DIAMETER),"Qi charge uses the shared base size independently of the scaled Kazi body")
 step_cast(12)
 check(launched.is_empty() and player.model.current_clip.begins_with("0:") and charge.global_position.is_equal_approx(player.model.qi_blast_chest()),"Shining stays centered on Kaz while he stands still")
 await capture("charge")
 var audio_order:int=game.voice_idx
 var recorder:AudioEffectRecord
 var sfx=AudioServer.get_bus_index("SFX")
 var effect_index=AudioServer.get_bus_effect_count(sfx)
 if DisplayServer.get_name()!="headless":
  recorder=AudioEffectRecord.new();recorder.format=AudioStreamWAV.FORMAT_16_BITS
  AudioServer.add_bus_effect(sfx,recorder);recorder.set_recording_active(true)
 step_cast(9)
 check(launched.is_empty() and not charge.visible and player.model.current_clip.begins_with("qi:5:"),"Kaz uses his recovered unarmed attack after Shining")
 step_cast(9)
 check(launched.size()==8,"Holding or repeating the key produces only one eight-shot volley")
 check(player.model.current_clip.begins_with("qi:5:") and player.model.current_frame>=7,"The punch reaches its contact and follows through after release")
 check(launched.map(func(shot):return shot.target)==targets.slice(0,8),"Eight shots lock the eight closest distinct enemies, including enemies behind Kazi")
 check(launched.all(func(shot):return shot.visual.material_override==Qi.Shot.material),"All shots share one material")
 check(is_equal_approx(launched[0].visual.scale.x*Qi.Shot.DIAMETER,Qi.BASE_DIAMETER) and is_equal_approx(launched[0].hit_radius*launched[0].collision_scale,Qi.BASE_DIAMETER*.5),"Orb art and contact radius use the shared base size")
 check_cue("qigong_launch")
 var first:Node3D=launched[0]
 var far:Node3D=launched[7]
 var origin:Vector3=first.global_position
 check(absf(first.visual.global_position.y-player.model.qi_blast_chest().y)<.1,"The orb leaves at torso height")
 check(launched.filter(func(shot):return shot.visible)==[first],"Only the first orb is visible at release")
 check(Qi.Shot.material.get_shader_parameter("atlas")==preload("res://assets/characters/crossgate/qigong/orbs.png") and first.visual.get_instance_shader_parameter("frame")==0.0,"Kaz starts on the first original glow frame")
 var sound_ticks=0
 var starts=0
 var sound_synced=true
 var voice_peak=0
 var contact=Vector3.INF
 var tested_speed=false
 for tick in 49:
  if tick>0 and recorder!=null:await physics_frame
  var far_ready:bool=far.pool_live and far.start_delay<=0.0
  var far_before:Vector3=far.global_position
  if tick>0:step_shots(1)
  var cues=0
  var voices=0
  for voice in game.voices:
   if voice.get_meta("kind","")!="qigong_launch":continue
   if voice.playing:voices+=1
   if int(voice.get_meta("order",0))>audio_order and voice.stream==SoundLibrary.original_for(34,"qigong_launch"):cues+=1
  starts+=cues;sound_ticks+=int(cues>0);voice_peak=maxi(voice_peak,voices)
  audio_order=game.voice_idx
  sound_synced=sound_synced and starts==launched.filter(func(shot):return shot.start_delay<=0.0).size()
  if tick==1:
   check(first.pool_live and origin.distance_to(first.global_position)<Qi.SPEED/60.0*.95,"First orb eases down near the target and waits for edge contact")
   check(launched.slice(1).all(func(shot):return not shot.visible and shot.global_position==origin and shot.age==0.0),"Pending orbs stay hidden and stationary")
   check(get_nodes_in_group("original_goemon_hit_pixels").is_empty(),"The original Blue Cross Gate shine replaces the Goemon burst")
   var glow_frame:float=first.visual.get_instance_shader_parameter("frame")
   first.visual.set_instance_shader_parameter("frame",0.0)
   await capture("orb-dark-glow")
   first.visual.set_instance_shader_parameter("frame",1.0)
   await capture("orb-bright-glow")
   if DisplayServer.get_name()!="headless":
    first.visual.set_instance_shader_parameter("uru_palette",1.0)
    await capture("orb-red-glow")
    first.visual.set_instance_shader_parameter("uru_palette",0.0)
    first.visual.set_instance_shader_parameter("gold_palette",1.0)
    await capture("orb-gold-glow")
    first.visual.set_instance_shader_parameter("gold_palette",0.0)
   first.visual.set_instance_shader_parameter("frame",glow_frame)
  if far_ready and far.pool_live and not tested_speed:
   check(is_equal_approx(far_before.distance_to(far.global_position),Qi.SPEED/60.0),"Distant orb flies at full speed after its delay")
   tested_speed=true
  if first.contact_done and not contact.is_finite():
   contact=AttackChain.aim_point(targets[0],first.visual.global_position)
   var gap=first.visual.global_position.distance_to(contact)
   var radius:float=first.hit_radius*first.visual.scale.x
   check(gap>0 and gap<radius+Qi.SPEED/60.0,"Orb contacts inside its resized footprint, %.2f metres from the enemy shape"%gap)
   check(first.shine.visible and first.shine_age>=first.SHINE_LEAD,"The recovered Blue Cross Gate shine leads the confirmed contact")
   check(is_equal_approx(targets[0].impact_pause,.060) and is_equal_approx(game.camera_rig.kick_strength,.065),"Confirmed contact uses the stronger recoil and camera kick")
   owner.flush_presentation()
   var view:Transform3D=game.camera_rig.camera.global_transform
   game.camera_rig.camera.global_position=contact+Vector3(4,2,-2)
   game.camera_rig.camera.look_at(contact)
   await capture("bluecg-contact")
   game.camera_rig.camera.global_transform=view
  if tick==28:await capture("original-glow-volley")
 check(tested_speed and contact.is_finite(),"Both early and delayed shots complete their flight checks")
 check(sound_synced and starts==8 and sound_ticks==8,"Eight orbs start moving and sounding on eight separate ticks")
 check(voice_peak<=2,"Orb launches reuse at most two concurrent voices")
 if recorder!=null:
  await settle_feedback()
  recorder.set_recording_active(false)
  var recording=recorder.get_recording()
  check(recording!=null and recording.data.count(0)<recording.data.size() and recording.save_to_wav(ProjectSettings.globalize_path(OUT+"orb-launches.wav"))==OK,"Recorded audible orb launches from the SFX bus")
  AudioServer.remove_bus_effect(sfx,effect_index)
 step_shots(200)
 owner.flush_presentation()
 for i in rows.size():
  var hp:float=owner.unit_state(owner.handles[rows[i].id]).hp
  check(is_equal_approx(HP-hp,750.0 if i<8 else 0.0),"Native damage matches the lock for enemy %d"%i)
 check(launched.all(func(shot):return not shot.pool_live and shot.target==null and shot.attack_ticket.is_empty()),"Recycled shots clear targets and tickets")
 check(player.attack_chain.count==1,"The eight impacts share one chain link")
 check_cue("qigong_hit")
 launched.clear();hotkey(true);hotkey(false);step_cast(30)
 check(launched.is_empty() and cast.controller.cooldown>0,"Cooldown blocks another volley")
 cast.controller.clear_cooldowns();hotkey(true);hotkey(false)
 var dodge=InputEventAction.new();dodge.action="dodge";dodge.pressed=true;player._unhandled_input(dodge)
 step_cast(36)
 check(launched.is_empty() and not cast.controller.charge_fx.visible,"Dodging before release cancels the charge")
 cast.controller.clear_cooldowns();hotkey(true);hotkey(false);step_cast(30)
 check(launched.size()==8 and launched.filter(func(shot):return not shot.visible).size()==7,"A fresh volley prepares seven hidden follow-up shots")
 audio_order=game.voice_idx
 player.spell_loadout.cancel();step_shots(50)
 check(launched.all(func(shot):return not shot.pool_live and shot.target==null) and game.voice_idx==audio_order,"Canceling a volley clears pending shots and their launch sounds")
 launched.clear()

 player.select_character(1);fresh();player.position=home;player.dodge_time=0
 check(player.spell_loadout.equip(1,"equip",Qi.ID),"The loadout API equips the borrowed spell on Goemon")
 for row in rows.slice(1):owner.despawn(owner.handles[row.id])
 owner.integration_tick(1.0/60)
 var handle:int=owner.handles[rows[0].id]
 var hp:float=owner.unit_state(handle).hp
 hotkey(true);hotkey(false);step_cast(12)
 var borrowed_cast:Node=player.spell_loadout.current.controller
 check(borrowed_cast.charge_fx.visible and borrowed_cast.charge_fx.global_position.is_equal_approx(player.model.qi_blast_chest()),"Borrowed Qi uses the same torso flash on Goemon")
 step_cast(10)
 check(not player.model.pipe.visible and borrowed_cast.punch_progress()>0,"Goemon uses the native throwing gesture for borrowed Qi")
 step_cast(14)
 check(launched.size()==8 and launched.filter(func(shot):return shot.target==targets[0]).size()==1,"Borrowed spell still fires eight when only one target is available")
 var wall=StaticBody3D.new();wall.collision_layer=1
 var collider=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(4,4,.3)
 collider.shape=box;wall.add_child(collider);game.add_child(wall);wall.position=home+Vector3(0,1,-2)
 await physics_frame;await physics_frame
 var bursts_before=get_nodes_in_group("original_goemon_hit_pixels").size()
 step_shots(200)
 check(is_equal_approx(hp,owner.unit_state(handle).hp),"New solid cover stops an in-flight orb")
 check(get_nodes_in_group("original_goemon_hit_pixels").size()==bursts_before,"A blocked shot cannot trigger the Goemon burst")
 wall.queue_free();await physics_frame;await physics_frame
 var borrowed:Node=player.spell_loadout.instances["1:"+Qi.ID].controller
 borrowed.clear_cooldowns();launched.clear();hotkey(true);hotkey(false);step_cast(36);step_shots(200)
 hp=owner.unit_state(handle).hp
 await settle_feedback()
 var created:int=pool.created
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var expected=6*750.0*player.damage_multiplier()
 for i in 6:
  borrowed.clear_cooldowns();player.attack_chain.reset();launched.clear()
  hotkey(true);hotkey(false);step_cast(36);step_shots(200)
 check(is_equal_approx(hp-owner.unit_state(handle).hp,expected),"Each borrowed cast applies the orb's damage with Goemon's multiplier")
 check(pool.misses==0 and pool.created==created,"Six repeated volleys reuse prepared nodes")
 await settle_feedback()
 var nodes_after=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var resources_after=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 check(nodes_after==nodes and resources_after==resources,"Repeated casts retain no extra nodes or resources (%d/%d → %d/%d)"%[nodes,resources,nodes_after,resources_after])

 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(player,0)
 launched.clear()
 for i in 5:
  check(mirrors.reinforce(34,home+Vector3((i-2)*1.4,0,0)),"Native Kazi ally allocated %d"%i)
  var body=mirrors.bodies[i]
  body.perform(2,targets[0].global_position)
 for i in 30:
  for body in mirrors.bodies:
   body.step(1.0/60,{"position":body.position,"hp":body.max_hp,"yaw":0.0,"pose_velocity":Vector3.ZERO})
 check(launched.size()==40 and pool.misses==0,"Five simultaneous native allies release forty prepared orbs")
 hp=owner.unit_state(handle).hp
 step_shots(24)
 check(is_equal_approx(hp-owner.unit_state(handle).hp,5*750.0),"Five simultaneous allies each land one orb on the available enemy")
 mirrors.dispose()
 check(launched.all(func(shot):return not shot.pool_live),"Retiring allies clears their outstanding shots")
 borrowed.clear_cooldowns();launched.clear();hotkey(true);hotkey(false);step_cast(30)
 owner.despawn(handle);owner.integration_tick(1.0/60);step_shots(200)
 check(launched.size()==8 and launched.all(func(shot):return not shot.pool_live and shot.target==null),"Shots recycle safely when their target disappears")
 for id in [2,3,12,13,14,15,16,17,18,19,20,27,28,29,31,32,33,35]:
  player.select_character(id)
  check(player.character_id==id,"Qi presentation loads for fighter %d"%id)
  player.model.animate_qi_blast(1.0/60,-1.0)
  player.model.animate_qi_blast(1.0/60,1.0)
  player.model.animate_qi_blast(1.0/60,1.5)
 check(player.model.current_clip.begins_with("qi:5:") and player.model.qi_punch.id==105714,"Uru uses the matching recovered orange-outfit punch")
 check_skill_impacts()
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("QIGONG_PROJECTILE_STEP_MS ",preload("res://tests/forest-shrine/army_benchmark_metrics.gd").summary(shot_step_ms))
 print("QIGONG_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
