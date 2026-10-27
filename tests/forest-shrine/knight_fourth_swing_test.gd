extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const FINISH=preload("res://assets/audio/recovered_musashi/lumina_rotation.wav")
func quiet(node:Node):
 if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop()
 for child in node.get_children():quiet(child)
func played(pool:Array,stream:AudioStream)->bool:
 return pool.any(func(v):return v.playing and v.stream==stream)
func run():
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_physics_process(false)
 var p=game.player;p.select_character(7);p.set_auto_attack(false)
 var c=p.active_ability;var runtime=game.army_runtime
 runtime.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
 game.training_dummy.hide();game.training_dummy.position=Vector3(0,-100,0)
 runtime.set_navigation(6000,{"width":0})
 var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3.FORWARD*2.6);row.hp=100000;row.max_hp=100000
 runtime.import_arrivals();runtime.sync_targets()
 var dummy=game.actors[row.id]
 if "--visual" in OS.get_cmdline_user_args():
  game.camera_rig.camera.global_position=ORIGIN+Vector3(7,4.5,8)
  game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1.3,-1))
 var sounds=[]
 game.impact_confirmed.connect(func(victim,_strength,_duration):
  if victim==dummy:
   var voice=c.sound.voices[(c.sound.cursor-1)%c.sound.voices.size()]
   sounds.append({"stream":voice.stream,"playing":voice.playing}))
 check(SoundLibrary.moves_for(7).has("primary_4"),"Sound Studio exposes the fourth Knight swing")
 check(game.sound_preview(7,"knight_finisher_hit")==FINISH and FINISH==game.sound_library.original_for(13,"fusion_fourth_hit"),"Knight finisher uses Musashi's actual fourth-hit sample")
 var damage=[]
 for index in 8:
  quiet(game);c.sound.last_events.clear();sounds.clear();p.attack_chain.reset();c.player.cooldowns.cutlass=0;c.player.pos=ORIGIN;p.position=ORIGIN
  c.player.vel=Vector3.ZERO;c.aim=ORIGIN+Vector3.FORWARD*30
  var hp:float=dummy.hp;c.attack()
  var a:Dictionary=c.player.attack
  check(a.index==index%4,"Repeated combo advances through four attacks")
  check(a.ticket.move_audio.move_key=="primary_%d"%(index%4+1),"Swing keeps its own audio ticket")
  c._sync_hero()
  if index%4==3:check(p.attack_heavy,"Fourth swing has heavy-hit feedback")
  for frame in ceili((a.duration+.02)*60):
   c.tick(1.0/60,false)
   if "--visual" in OS.get_cmdline_user_args():
    c._sync_hero();c._animate(1.0/60,0)
    game.crowd.army.present(runtime.render_snapshot(),runtime.presentation_events);runtime.presentation_events.clear()
    game.crowd.army.presentation.tick(1.0/60)
    await physics_frame
    if index==3 and frame==ceili(a.contact*60):
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png("res://build/Other Files/Asset Toolkit/Knight Fourth Swing/combo.png")
  var dealt=hp-dummy.hp;damage.append(dealt)
  check(dealt>0 and c.player.attack==null,"Each swing completes and damages a real target")
  check(sounds.size()==1 and sounds[0].playing and (sounds[0].stream==FINISH)==(index%4==3),"Only confirmed fourth contacts play the final sound")
 check(damage[3]>damage[2] and damage[2]>damage[1],"Fourth contact is stronger than the existing third")
 check(damage.slice(0,4)==damage.slice(4,8),"Repeated combo retains all four damage values")
 c.combo=3;c.combo_timer=1;c.player.cooldowns.cutlass=0;dummy.position=ORIGIN+Vector3.FORWARD*100
 quiet(game);c.attack();var missed=c.player.attack
 for frame in ceili((missed.duration+.02)*60):c.tick(1.0/60,false)
 check(not played(c.sound.voices,FINISH),"Fourth swing misses without a contact sound")
 c.combo=3;c.combo_timer=0;c.player.cooldowns.cutlass=0;c.attack()
 check(c.player.attack.index==0,"Expired combo returns to its first swing")
 c.cancel();c.combo=3;c.combo_timer=1;c.player.cooldowns.cutlass=0;c.attack()
 c._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(c.player.attack==null,"Focus loss cancels a pending fourth swing")
 var fx=game.crowd.army.presentation;quiet(game);fx.next_sound=0
 fx.present([{"kind":"status","action_index":18,"position":ORIGIN}])
 check(played(fx.voices,FINISH),"Allied contact uses the existing spatial voice pool")
 quiet(game);fx.next_sound=0;game.sound_library.select_character(7);game.sound_library.mutes.heavy_hit=true
 fx.present([{"kind":"status","action_index":18,"position":ORIGIN}])
 check(not played(fx.voices,FINISH),"Heavy-hit mute includes the new allied finisher")
 game.sound_library.mutes.erase("heavy_hit")
 var lib=game.sound_library;var take=SoundLibrary.BLADE_IMPACTS.hit
 lib.custom.heavy_hit=take;lib.gains.heavy_hit=.4
 var playback=lib.playback_for(7,"knight_finisher_hit",null)
 check(playback.stream==take and is_equal_approx(playback.gain,.4) and game.sound_preview(7,"knight_finisher_hit")==take,"Existing heavy recording/gain and preview apply to the fourth contact")
 lib.custom.erase("heavy_hit");lib.gains.erase("heavy_hit")
 if "--native" in OS.get_cmdline_user_args():native_combo()
 quiet(game);game.queue_free();game=null;paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("KNIGHT_FOURTH_SWING_RESULT checks=%d failures=%d damage=%s"%[checks,failures,str(damage)])
 quit(1 if failures else 0)
func native_combo():
 var r=load("res://scripts/forest/crowd/army_runtime.gd").new();r.configure(null)
 var data=preload("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model)
 for i in data.ally_kinds.size():data.ally_profiles[i*5+1]=0;data.ally_profiles[i*5+4]=0
 r.configure_kits(data);r.set_navigation(1,{"width":0})
 for i in 8:
  var point=Vector3(i*24,0,0)
  var enemy:int=r.spawn(i+1,0,0,point+Vector3(0,0,3.8),100000,.4)
  r.apply_hit(enemy,{"element":"ice","status_seconds":100.0})
  r.spawn(-i-1,1,7,point,10000,.4)
 var traces={};var hits={};var cues={}
 for frame in 420:
  r.step(1.0/60,{})
  for e in r.take_events():
   if e.kind=="melee" and e.unit_kind==7:
    if not traces.has(e.source_id):traces[e.source_id]=[]
    traces[e.source_id].append([e.action_index,e.amount])
   if e.kind=="damage" and e.source_id<0:
    if not hits.has(e.source_id):hits[e.source_id]=[]
    hits[e.source_id].append(e.heavy)
   if e.kind=="status" and e.action_index==18:cues[e.source_id]=int(cues.get(e.source_id,0))+1
 for id in range(-8,0):
  var trace:Array=traces.get(id,[])
  check(trace.size()>=8 and trace.slice(0,8)==[[0,42.0],[1,42.0],[2,61.0],[3,76.0],[0,42.0],[1,42.0],[2,61.0],[3,76.0]],"Simultaneous native Knight %d repeats the same four swings"%id)
  check(hits.get(id,[]).size()>=4 and hits[id][3],"Native fourth contact carries heavy knockback")
  check(int(cues.get(id,0))>=2,"Native Knight emits one confirmed finisher cue per completed combo")
 r.free()
