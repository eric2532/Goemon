extends "res://tests/forest-shrine/reference/skill-timelines/crossgate_qigong_test.gd"

const REPORT="res://build/Other Files/Asset Toolkit/Kazi Elements/Grounded Ice and Wind Audio/"
const SLOTS=["fire","ice","wind","meteor"]
var heard:Dictionary={}
var audio_order=0
var rows:Array=[]
var targets:Array=[]

func snapshot_audio():
 for voice in game.voices:
  if int(voice.get_meta("order",0))<=audio_order:continue
  var cue:String=voice.get_meta("kind","")
  if cue.begins_with("cg_") and voice.stream==SoundLibrary.original_for(34,cue):
   heard[cue]=heard.get(cue,0)+1
 audio_order=game.voice_idx

func health()->Array:
 return rows.map(func(row):return float(owner.unit_state(owner.handles[row.id]).hp))

func render_evidence(name_:String):
 if DisplayServer.get_name()=="headless":return
 game.world.sync(0)
 game.forest_ui.sync()
 await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(REPORT+name_+".png")==OK,"Captured "+name_)

func verify_queue():
 var loadout=player.spell_loadout
 loadout.cancel();loadout.clear_cooldowns();launched.clear()
 hotkey(true,false,2);hotkey(false,false,2);step_cast(12)
 for slot in [3,2,4]:
  hotkey(true,false,slot);hotkey(true,true,slot);hotkey(false,false,slot)
 check(loadout.current.spec.id=="kazi/fire" and loadout.magic_queue.size()==3,"Taps queue without replacing the active windup or duplicating key echoes")
 for tick in 175:
  step_cast(1);step_shots(1)
 check(launched.size()==16 and launched.slice(0,8).all(func(shot):return shot.kind=="fire") and launched.slice(8).all(func(shot):return shot.kind=="ice"),"Fire finishes, Ice follows, and the second Fire waits for cooldown")
 check(launched.all(func(shot):return not shot.pool_live),"Both overlapping casts finish and recycle")
 launched.clear()
 for tick in 210:
  step_cast(1);step_shots(1)
 check(launched.size()==16 and launched.slice(0,8).all(func(shot):return shot.kind=="fire") and launched.slice(8).all(func(shot):return shot.kind=="wind"),"The repeated Fire and following Wind release in the original tap order")
 step_shots(170);launched.clear()
 hotkey(true,false,2);hotkey(false,false,2)
 check(loadout.current==null and loadout.magic_queue.size()==1,"A tap during cooldown waits without taking over movement")
 var dodge=InputEventAction.new();dodge.action="dodge";dodge.pressed=true;player._unhandled_input(dodge)
 step_cast(360)
 check(launched.is_empty() and loadout.magic_queue.is_empty(),"Dodging clears an idle queued cast")
 check(pool.misses==0,"Queued casts reuse the existing projectile pool")
 hotkey(true,false,2);hotkey(false,false,2)
 hotkey(true,false,2);hotkey(false,false,2)
 loadout.clear_cooldowns();step_cast(36)
 check(launched.size()==8 and loadout.current==null and loadout.magic_queue.size()==1,"A buffered repeat waits for the released spell to damage an enemy")
 loadout.clear_cooldowns()
 for tick in 60:
  if loadout.current!=null:break
  step_shots(1);step_cast(1)
 check(loadout.current!=null and player.model.cast_clock<.1,"After damage, the repeated spell restarts Kazi's charge gesture")
 loadout.cancel()
 check(launched.all(func(shot):return not shot.pool_live and not shot.visible and shot.cast_hits.is_empty()),"Canceling the loadout recycles effects that are still waiting to appear")

func verify_combo():
 var loadout=player.spell_loadout
 loadout.cancel();loadout.clear_cooldowns();launched.clear()
 for cast_index in 42:
  var slot=cast_index%5+1
  hotkey(true,false,slot);hotkey(false,false,slot)
  for tick in 400:
   if loadout.current!=null:break
   step_cast(1);step_shots(1)
   launched=launched.filter(func(shot):return shot.pool_live)
  var expected=minf(5.0,1.0+.1*cast_index)
  if loadout.current==null or not is_equal_approx(loadout.current.controller.cast_speed,expected):
   check(false,"Cast %d reaches %.1f× after the previous spell damages native enemies"%[cast_index+1,expected])
   return
  while loadout.current!=null:
   step_cast(1);step_shots(1)
   launched=launched.filter(func(shot):return shot.pool_live)
 check(true,"42 damage-linked casts through keys 1–5 reach and hold 5×")
 check(pool.misses==0,"The accelerated rotation stays inside the prepared projectile pools")
 loadout.clear_cooldowns()
 hotkey(true,false,1);hotkey(false,false,1)
 for tick in 400:
  if loadout.current!=null:break
  step_cast(1);step_shots(1)
  launched=launched.filter(func(shot):return shot.pool_live)
 step_cast(7)
 var miss:Dictionary=loadout.magic_result
 check(miss.pending>0 and not miss.hit,"Released Qi Orbs are still in flight")
 for shot in launched:
  if is_same(shot.attack_ticket.get("magic_result"),miss):shot.target=null
 hotkey(true,false,3);hotkey(false,false,3)
 step_cast(1)
 check(loadout.current==null,"A queued cast waits for the missed projectiles to settle")
 for tick in 520:
  if loadout.current!=null:break
  step_shots(1);step_cast(1)
  launched=launched.filter(func(shot):return shot.pool_live)
 check(miss.pending==0 and not miss.hit and loadout.current!=null and loadout.current.controller.cast_speed==1.0,"A missed volley resets the queued follow-up to 1×")
 loadout.cancel();loadout.clear_cooldowns()

func verify_long_range():
 player.select_character(34);fresh();player.position=home
 for row in rows:owner.despawn(owner.handles[row.id])
 var terrain:Array[RID]=game.world.terrain_rids
 var origin=home+Vector3.UP*1.5
 var inside=Vector3.INF
 var outside=Vector3.INF
 for i in 72:
  var direction=Vector3.FORWARD.rotated(Vector3.UP,i*TAU/72)
  var near=home+direction*142.5
  var far=home+direction*149.0
  near.y=game.model.surface_height(near.x,near.z)+.1
  far.y=game.model.surface_height(far.x,far.z)+.1
  if not game.forest_point_visible(near) or not game.forest_point_visible(far):continue
  if home.distance_to(near)>144.0:continue
  if not AttackChain.clear_line(player,origin,near+Vector3.UP*1.4,terrain):continue
  if not AttackChain.clear_line(player,origin,far+Vector3.UP*1.4,terrain):continue
  inside=near;outside=far;break
 check(inside.is_finite(),"Found visible native target positions on either side of 144 m")
 if not inside.is_finite():return
 # A controlled ridge on the existing terrain body isolates terrain from scenery.
 var ground=game.world.find_child("ValleyTerrainCollision",true,false)
 var ridge=CollisionShape3D.new();var ridge_box=BoxShape3D.new();ridge_box.size=Vector3(6,20,6)
 ridge.shape=ridge_box;ground.add_child(ridge)
 var toward=(inside-home).slide(Vector3.UP).normalized()
 ridge.global_position=home+toward*9.0+Vector3.UP*3.0
 await physics_frame;await physics_frame
 var row=game.model.waves.spawn_enemy(0,inside);row.hp=HP;row.max_hp=HP
 var far_row=game.model.waves.spawn_enemy(0,outside);far_row.hp=HP;far_row.max_hp=HP
 owner.import_arrivals();owner.integration_tick(1.0/60)
 var enemy=game.actors[row.id]
 var handle:int=owner.handles[row.id]
 var distance=home.distance_to(enemy.global_position)
 check(distance>140.0 and distance<=144.0 and home.distance_to(game.actors[far_row.id].global_position)>144.0,
  "Native targets straddle the 144 m limit (inside %.1f m)"%distance)
 var obstruction=AttackChain.world_ray(player,origin,AttackChain.aim_point(enemy,origin))
 check(not obstruction.is_empty() and terrain.has(obstruction.rid),"The ridge blocks normal collision rays on the native terrain body")
 for index in 5:
  var kind:String=["qigong","fire","ice","wind","meteor"][index]
  var cast=player.spell_loadout.instances["34:kazi/"+kind].controller
  cast.clear_cooldowns();player.attack_chain.reset();launched.clear()
  var before:float=owner.unit_state(handle).hp
  hotkey(true,false,index+1);hotkey(false,false,index+1);step_cast(36)
  if kind in ["qigong","wind"]:
   check(launched.filter(func(shot):return shot.target!=null).map(func(shot):return shot.target)==[enemy],"%s locks beyond the ridge but inside 144 m"%kind)
  else:
   check(launched.map(func(shot):return shot.global_position)==[enemy.global_position],"%s appears behind the ridge and excludes the target beyond 144 m"%kind)
  step_shots(490)
  var expected:float=[750.0,1500.0,1200.0,1000.0,1300.0][index]
  check(is_equal_approx(before-owner.unit_state(handle).hp,expected),"%s delivers its full damage to the distant native enemy"%kind)
  check(launched.all(func(shot):return not shot.pool_live),"%s recycles the long-range volley"%kind)
 var wall=StaticBody3D.new();wall.collision_layer=1
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(7,10,.4)
 shape.shape=box;wall.add_child(shape);game.add_child(wall)
 wall.position=home+toward*3.0+Vector3.UP*3.0
 wall.rotation.y=atan2(toward.x,toward.z)
 await physics_frame;await physics_frame
 check(not AttackChain.clear_line(player,origin,AttackChain.aim_point(enemy,origin),terrain),"The wall blocks ordinary spell sight even with terrain excluded")
 for index in SLOTS.size():
  var kind:String=SLOTS[index]
  player.spell_loadout.instances["34:kazi/"+kind].controller.clear_cooldowns()
  player.attack_chain.reset();launched.clear()
  var before:float=owner.unit_state(handle).hp
  hotkey(true,false,index+2);hotkey(false,false,index+2);step_cast(36)
  if kind=="wind":
   check(launched.filter(func(shot):return shot.target!=null).map(func(shot):return shot.target)==[enemy],"Wind locks behind the wall within 144 m")
  else:
   check(launched.map(func(shot):return shot.global_position)==[enemy.global_position],"%s appears at the target behind the wall"%kind)
  step_shots(490)
  var expected:float=[1500.0,1200.0,1000.0,1300.0][index]
  check(is_equal_approx(before-owner.unit_state(handle).hp,expected),"%s lands its full damage behind the wall"%kind)
 var qi=player.spell_loadout.instances["34:kazi/qigong"].controller
 check(qi.nearest_targets(origin,terrain).is_empty(),"The wall still blocks Qi Orb lock-on")
 wall.queue_free();ridge.queue_free()
 check(pool.misses==0,"Long-range casts reuse prepared leases")
 player.select_character(1);player.position=home
 var borrowed=player.spell_loadout.instances["1:kazi/meteor"].controller
 check(borrowed.nearest_targets(origin,terrain).is_empty(),"Borrowed Meteor keeps its original shorter reach")

func run():
 DirAccess.make_dir_recursive_absolute(REPORT)
 create_timer(90).timeout.connect(func():printerr("CROSSGATE_ELEMENTS_TIMEOUT");quit(1))
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
 game.explorer_helpers.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 root.gui_disable_input=true
 player=game.player;player.set_process_input(false);player.set_process_unhandled_input(false)
 player.spell_loadout.equip(34,"equip",Qi.ID)
 player.spell_loadout.equip(34,"surge","kazi/fire")
 home.y=game.model.surface_height(home.x,home.z)+.1
 player.select_character(34);fresh();player.position=home;step_cast(5)
 game.update_character_tuning(34,"model_scale",1.2)
 var body_height=Qi.Proportions.GOEMON_HEIGHT*player.model.global_basis.y.length()
 game.model.update_vision(home)
 game.training_dummy.position=Vector3(0,-100,0);game.training_dummy.collision_layer=0
 owner=game.army_runtime;owner.set_process(false);owner.set_physics_process(false)
 for offset in [Vector2(0,-5.5),Vector2(.65,-5.5),Vector2(6,0),Vector2(-7,0),Vector2(0,8),Vector2(8,5),Vector2(-9,6),Vector2(0,-12),Vector2(.35,-12.15),Vector2(0,-32)]:
  var point=home+Vector3(offset.x,0,offset.y)
  point.y=game.model.surface_height(point.x,point.z)+.1
  var row=game.model.waves.spawn_enemy(0,point);row.hp=1000000.0;row.max_hp=row.hp;rows.append(row)
 owner.import_arrivals();owner.integration_tick(1.0/60)
 targets=rows.map(func(row):return game.actors[row.id])
 pool=game.get_node("CharacterProjectiles")
 pool.launched.connect(func(shot):
  if shot.get_script() in [Qi.Element,Qi.Shot]:
   shot.set_physics_process(false);launched.append(shot))
 game.camera_rig.camera.global_position=home+Vector3(6,7,13)
 game.camera_rig.camera.look_at(home+Vector3(0,1,-3))
 game.world.sync(0)
 var material:ShaderMaterial=game.world.attack_materials.front()
 check(is_equal_approx(material.get_shader_parameter("attack_radius"),player.melee_strike_reach()),"Kaz's shared outline marks the actual melee radius")
 await render_evidence("kazi-melee-range")
 game.camera_rig.camera.global_position=home+Vector3(26,20,31)
 game.camera_rig.camera.look_at(home+Vector3(0,6,-3))
 var created:int=pool.created
 var ice_image=Qi.Element.ICE.get_image()
 var ice_cell=ice_image.get_size()/Vector2i(8,2)
 var ice_anchors:Array[float]=[]
 for frame in 15:
  var tile=ice_image.get_region(Rect2i(Vector2i(frame%8,frame/8)*ice_cell,ice_cell))
  var bounds=tile.get_used_rect()
  ice_anchors.append(bounds.position.y+bounds.size.y*.5 if frame<4 else bounds.end.y)
 for index in SLOTS.size():
  var kind:String=SLOTS[index]
  var hotbar:Array=player.spell_loadout.numbered_slots[index+1]
  check(hotbar[0].contains(kind.capitalize()),"Slot %d selects %s"%[index+2,kind])
  player.spell_loadout.cancel()
  launched.clear();heard.clear();audio_order=game.voice_idx;player.attack_chain.reset()
  var before=health()
  hotkey(true,false,index+2);hotkey(false,false,index+2);snapshot_audio()
  var cast:Node=player.spell_loadout.current
  check(is_instance_valid(cast) and cast.controller.charge_fx.texture==Qi.Element.CAST,"%s uses the recovered level-11 cast sheet"%kind)
  if not is_instance_valid(cast):quit(1);return
  step_cast(20)
  check(launched.is_empty(),"One press winds up before %s releases"%kind)
  var charge:Sprite3D=cast.controller.charge_fx
  check(charge.frame==6 and is_equal_approx(charge.pixel_size*charge.global_basis.y.length()*127.0,body_height*2.0),"%s charge wraps the body at twice Kazi's height"%kind)
  check(is_equal_approx(charge.offset.y,17.5) and charge.position.is_zero_approx(),"%s flare starts at Kazi's feet instead of above his head"%kind)
  var tint:Color=charge.modulate
  var colors=[tint.r>tint.g and tint.g>tint.b,tint.b>tint.g and tint.g>tint.r,tint.r>.8 and tint.g>.8 and tint.b<.4,tint.g>tint.r and tint.g>tint.b]
  check(colors[index],"%s charge uses its element color"%kind)
  step_cast(16);snapshot_audio()
  check(launched.size()==8 and launched.all(func(shot):return shot.kind==kind),"%s releases exactly eight effects"%kind)
  if launched.is_empty():quit(1);return
  if kind=="wind":
   check(launched.map(func(shot):return shot.target)==targets.slice(0,8),"Eight winds lock the closest eight separately")
  else:
   check(launched.map(func(shot):return shot.global_position)==targets.slice(0,8).map(func(target):return target.global_position),"%s appears on the closest eight"%kind)
  var primary:Sprite3D=launched[0].sprite
  var visible_pixels:float={"fire":165.0,"ice":205.0,"wind":214.0,"meteor":120.0}[kind]
  check(is_equal_approx(primary.pixel_size*primary.global_basis.y.length()*visible_pixels,body_height*1.1*4.0),"%s uses the shared 4× elemental scale"%kind)
  if kind=="meteor":
   check(launched.all(func(shot):return shot.sprite.position.y>0) and launched.map(func(shot):return shot.sprite.texture).slice(0,3)==Qi.Element.METEORS,"Meteors start overhead and use all three recovered variants")
  check(launched.filter(func(shot):return shot.visible)==[launched[0]],"%s starts with one visible effect"%kind)
  var reveal_ticks={}
  var timed_cue:String=["cg_fire_hit","cg_ice_a","cg_wind_fly","cg_meteor_hit"][index]
  var sound_synced=true
  var sound_ticks=int(heard.has(timed_cue))
  var concurrent_voices=0
  var grounded_frames={}
  var ice_grounded=true
  var recorder:AudioEffectRecord
  var sfx=AudioServer.get_bus_index("SFX")
  var effect_index=AudioServer.get_bus_effect_count(sfx)
  if DisplayServer.get_name()!="headless":
   recorder=AudioEffectRecord.new()
   recorder.format=AudioStreamWAV.FORMAT_16_BITS
   AudioServer.add_bus_effect(sfx,recorder);recorder.set_recording_active(true)
  for tick in 170:
   if recorder!=null:await physics_frame
   var previous:int=heard.get(timed_cue,0)
   step_shots(1);snapshot_audio()
   var expected_starts=0
   for shot in launched:
    if shot.visible and not reveal_ticks.has(shot):reveal_ticks[shot]=tick
    match kind:
     "fire":expected_starts+=int(shot.marker==2)
     "ice":
      expected_starts+=int(shot.marker>=2)+int(shot.sound_lead and shot.marker>=4)
      if shot.visible:
       var frame:int=shot.sprite.frame
       var crack=frame<4
       var offset:float=shot.sprite.offset.y+ice_cell.y*.5-ice_anchors[frame]
       var height:float=shot.sprite.global_position.y-shot.global_position.y
       var axis=Vector3.AXIS_Y if crack else Vector3.AXIS_Z
       var billboard=BaseMaterial3D.BILLBOARD_DISABLED if crack else BaseMaterial3D.BILLBOARD_FIXED_Y
       ice_grounded=ice_grounded and is_zero_approx(offset) and absf(height-(.04 if crack else -.1))<.001 and shot.sprite.axis==axis and shot.sprite.billboard==billboard
       grounded_frames[frame]=true
     "wind":expected_starts+=int(shot.start_delay<=0)
     "meteor":expected_starts+=shot.marker
   sound_synced=sound_synced and heard.get(timed_cue,0)==expected_starts
   if heard.get(timed_cue,0)>previous:sound_ticks+=1
   concurrent_voices=maxi(concurrent_voices,game.voices.filter(func(voice):return voice.playing and voice.get_meta("kind","")==timed_cue).size())
   if tick==2:
    check(launched.slice(1).all(func(shot):return not shot.visible and shot.age==0 and shot.marker==0),"%s delayed effects wait before moving or hitting"%kind)
   if tick==12 and kind=="fire":await render_evidence("fire-first")
   if tick==31 and kind!="meteor":await render_evidence(kind+"-staggered")
   if tick in [5,19] and kind=="ice" and recorder!=null:
    var camera=game.camera_rig.camera
    var old_view=camera.global_transform
    camera.global_position=home+Vector3(16,9,18)
    camera.look_at(launched[0].global_position+Vector3.UP*(1.0 if tick==5 else 5.0))
    await render_evidence("ice-ground-crack" if tick==5 else "ice-ground-contact")
    camera.global_transform=old_view
   if kind=="meteor" and tick==13:
    check(health()==before and launched[0].sprite.position.y>0,"The falling meteors deal no damage before contact")
   if kind=="meteor" and tick==24:
    check(is_equal_approx(before[0]-health()[0],650.0),"First meteor impact applies one 650-damage hit")
  var expected:int=[8,9,8,16][index]
  check(sound_synced and heard.get(timed_cue,0)==expected and sound_ticks>=8,"%s plays %d staggered sounds on the authored reveal or hit ticks"%[kind,expected])
  check(concurrent_voices<=2,"%s reuses at most two concurrent voices for %s"%[kind,timed_cue])
  if kind=="ice":check(ice_grounded and grounded_frames.size()==15,"Ice opens flat on the ground, then pins the painted base of every crystal frame")
  if recorder!=null:
   recorder.set_recording_active(false)
   var recording=recorder.get_recording()
   check(recording!=null and recording.data.count(0)<recording.data.size() and recording.save_to_wav(ProjectSettings.globalize_path(REPORT+kind+".wav"))==OK,"Recorded audible %s from the SFX bus"%kind)
   AudioServer.remove_bus_effect(sfx,effect_index)
  check(reveal_ticks.size()==8 and reveal_ticks.values().max()<=42 and reveal_ticks.values().all(func(tick):return reveal_ticks.values().count(tick)==1),"%s reveals eight effects on distinct ticks within 0.7 seconds"%kind)
  var after=health()
  var damage=[]
  for i in before.size():damage.append(before[i]-after[i])
  var total:float={"fire":1500.0,"ice":1200.0,"wind":1000.0,"meteor":1300.0}[kind]
  check(is_zero_approx(damage[9]) and damage[8]>=total,"%s splashes the nearby unselected enemy and leaves the distant enemy alone"%kind)
  if kind!="wind":
   check(damage.slice(0,9).all(func(amount):return is_equal_approx(amount,total)),"%s overlaps do not multiply the hit count (%s)"%[kind,damage])
  else:
   check(launched.all(func(shot):return shot.marker==4) and damage[0]>=total and damage[1]>=total,"Each wind lands four pulses in an overlapping area")
  var cues:Array={"fire":["cg_fire_charge","cg_fire_rise","cg_fire_hit"],"ice":["cg_ice_charge","cg_ice_rise","cg_ice_a","cg_ice_b"],"wind":["cg_wind_charge","cg_wind_fly","cg_wind_hit"],"meteor":["cg_meteor_charge","cg_meteor_fall","cg_meteor_hit"]}[kind]
  check(cues.all(func(cue):return heard.has(cue)),"%s plays all its recovered cue samples (%s)"%[kind,heard])
  check(launched.all(func(shot):return not shot.pool_live and shot.cast_hits.is_empty()),"%s recycles its effects and per-cast hit state"%kind)
 check(pool.misses==0 and pool.created==created,"All four spells reuse their prepared projectile nodes")
 await create_timer(.85).timeout
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for index in SLOTS.size():
  var spell:Node=player.spell_loadout.instances["34:kazi/"+SLOTS[index]]
  spell.controller.clear_cooldowns();launched.clear()
  hotkey(true,false,index+2);hotkey(false,false,index+2);step_cast(36);step_shots(170)
 await create_timer(.85).timeout
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated elemental casts retain no extra nodes or resources")
 verify_queue()
 verify_combo()

 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(player,0)
 launched.clear()
 for i in 5:
  var allocated=mirrors.reinforce(34,home+Vector3((i-2)*.8,0,0))
  check(allocated,"Native ally %d is available"%i)
  if not allocated:quit(1);return
 for index in range(1,4):
  var kind:String=SLOTS[index]
  launched.clear()
  for body in mirrors.bodies:
   body.attack_chain.reset()
   body.perform(index+3,targets[0].global_position)
  for tick in 36:
   for body in mirrors.bodies:
    body.step(1.0/60,{"position":body.position,"hp":body.max_hp,"yaw":0.0,"pose_velocity":Vector3.ZERO})
  check(launched.size()==40 and pool.misses==0,"Five native allies release forty %s effects with no pool misses"%kind)
  var before=health()
  step_shots(170)
  var damage:float=before[2]-health()[2]
  var expected:float=5*[0.0,1200.0,1000.0,1300.0][index]
  check((damage>=expected if kind=="wind" else is_equal_approx(damage,expected)) and launched.all(func(shot):return not shot.pool_live),"All simultaneous %s casts deal damage and retire (%.1f / %.1f)"%[kind,damage,expected])
 mirrors.dispose()
 player.select_character(1);fresh();player.position=home;launched.clear()
 check(player.spell_loadout.equip(1,"special_5","kazi/meteor"),"Other fighters can equip the level-11 meteor spell")
 hotkey(true,false,5);hotkey(false,false,5);step_cast(36)
 check(launched.size()==8 and launched.all(func(shot):return shot.hero==player and shot.kind=="meteor"),"Goemon borrows the same eight-meteor cast")
 if DisplayServer.get_name()!="headless":
  player.select_character(34);fresh();player.position=home;player.model.scale=Vector3.ONE*1.2
  for shot_tick in [0,14,34]:
   # Keep asynchronous capture separate from the damage assertions.
   await process_frame
   player.spell_loadout.cancel()
   var slot=4 if shot_tick==0 else 5
   var id="34:kazi/wind" if slot==4 else "34:kazi/meteor"
   player.spell_loadout.instances[id].controller.clear_cooldowns()
   hotkey(true,false,slot);hotkey(false,false,slot);step_cast(20)
   if shot_tick==0:await render_evidence("wind-charge")
   else:
    launched.clear();step_cast(16);step_shots(shot_tick)
    game.camera_rig.camera.global_position=home+Vector3(26,20,31)
    game.camera_rig.camera.look_at(home+Vector3(0,6,-3))
    await render_evidence("level-11-meteor-fall" if shot_tick==14 else "level-11-meteor")
  await process_frame
  player.spell_loadout.cancel()
  player.spell_loadout.instances["34:kazi/meteor"].controller.clear_cooldowns()
  game.camera_rig.camera.global_position=home+Vector3(6,7,13)
  game.camera_rig.camera.look_at(home+Vector3(0,1,-3))
  hotkey(true,false,5);hotkey(false,false,5);step_cast(20)
  await render_evidence("meteor-charge")
 await verify_long_range()
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("CROSSGATE_ELEMENT_STEP_MS ",preload("res://tests/forest-shrine/army_benchmark_metrics.gd").summary(shot_step_ms))
 print("CROSSGATE_ELEMENTS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
