extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const REPORT="res://build/Other Files/Asset Toolkit/Uru/Regrowth/"
const Roster=preload("res://scripts/rogue_roster.gd")
const Mirrors=preload("res://scripts/warcraft_mirrors.gd")
var samples=[]

func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(REPORT+name_+".png")==OK,"Captured "+name_)

func run():
 DirAccess.make_dir_recursive_absolute(REPORT)
 create_timer(120).timeout.connect(func():printerr("URU_TIMEOUT");quit(1))
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player
 game.show_rogue_roster();await frames()
 var picker=game.menu.find_child("RosterGrid",true,false).get_parent().get_parent().get_parent().get_parent()
 var uru=picker.find_child("RogueFighter_uru",true,false)
 var kaz=picker.find_child("RogueFighter_kazi",true,false)
 var maze=picker.find_child("RogueFighter_maze",true,false)
 check(uru.is_visible_in_tree() and kaz.is_visible_in_tree() and maze==null and picker.cards.size()==Roster.selection_ids().size(),"The gallery keeps Uru alongside Kaz, with Maze in Kaz's skins")
 await capture("Gallery")
 uru.pressed.emit()
 check(p.character_id==Roster.RUBY_ID and p.model.motions.id==105716,"The Uru card selects the original fighter from #20")
 check(p.model.motions.clips.size()==152,"Uru keeps 19 original actions across eight directions")
 check(p.model.body.find_children("*","Sprite3D",false,false)==[p.model.sprite],"Uru's model draws the body without the rune or spark sprites")
 var uru_slots:Array=p.spell_loadout.slots_for(Roster.RUBY_ID)
 var kaz_slots:Array=p.spell_loadout.slots_for(Roster.KAZI_ID)
 check(uru_slots[0][0]=="※高感應電流" and kaz_slots[0][0].contains("追月") and uru_slots.slice(2,5)==kaz_slots.slice(2,5) and uru_slots[1]==[p.spell_loadout.Catalog.all()["kazi/fire"].name,"surge"],"Uru starts with Spirit Shockwave and Fire, and shares Ice, Wind and Meteor with Kaz")
 check(game.sound_library.original_for(p.character_id,"step")==SoundLibrary.GOEMON_FOOTSTEP and game.sound_library.original_for(p.character_id,"land")==SoundLibrary.HUMANOID_LANDING,"Uru uses the shared footstep and landing originals")

 fresh();p.position=ORIGIN;p.velocity=Vector3.DOWN;p.move_and_slide()
 game.training_dummy.position=Vector3(0,-100,0);game.training_dummy.collision_layer=0
 var owner=game.army_runtime
 owner.set_physics_process(false);owner.set_process(false)
 var row=game.model.waves.spawn_enemy(0,p.global_position+Vector3.FORWARD*2)
 row.hp=100000;row.max_hp=100000
 owner.import_arrivals();owner.integration_tick(1.0/60)
 var handle:int=owner.handles[row.id]
 p.auto_attack_enabled=true;p.auto_lock_target=game.actors[row.id];p.auto_lock_refresh=100
 p.model.show_pose(0,0,true)
 await capture("Uru in Wind Meadow")
 p.active_ability.start_attack()
 p.auto_attack_enabled=false
 check(is_equal_approx(p.attack_duration,2.0),"The original staff clip lasts two seconds")
 for i in 121:
  var started=Time.get_ticks_usec()
  p.active_ability.tick(1.0/60.0)
  p.model.animate(1.0/60.0,0,true,0,0,false,0,false)
  samples.append((Time.get_ticks_usec()-started)/1000.0)
  if i==60:await capture("Staff combo")
 check(is_equal_approx(owner.unit_state(handle).hp,99500),"Five original staff markers deal 500 base damage to the native target, remaining HP %s"%str(owner.unit_state(handle).hp))
 check(not p.active_ability.is_attacking(),"The staff combo ends cleanly")
 check(game.sound_library.original_for(35,"swing").resource_path.ends_with("cgply04a.wav") and game.sound_library.original_for(35,"hit").resource_path.ends_with("cgply14a.wav"),"Staff swing and contact use original PCM")

 p.spell_loadout.equip(Roster.KAZI_ID,"equip","kazi/qigong")
 p.spell_loadout.equip(Roster.RUBY_ID,"equip","kazi/qigong")
 for id in [Roster.RUBY_ID,Roster.KAZI_ID]:
  p.select_character(id);p.attack_chain.reset()
  var instance=p.spell_loadout.instances["%d:kazi/qigong"%id]
  var controller=instance.controller
  check(controller.range_multiplier()==3.0,"Fighter %d receives the same native Cross Gate targeting range"%id)
  p.spell_loadout.number_input(1,true);p.spell_loadout.number_input(1,false)
  check(controller.is_attacking() and is_equal_approx(controller.cooldown,5.0),"Hotbar key 1 starts the shared Qi cast")
  check(controller.charge_fx.pixel_size*165.0>6.0,"The original level-11 charge is over six metres tall")
  var charge:Sprite3D=controller.charge_fx
  var torso:Vector3=p.model.to_global(Vector3.UP*controller.Proportions.GOEMON_HEIGHT*.55)
  check(charge.frame==0 and charge.is_visible_in_tree() and charge.global_position.is_equal_approx(torso) and charge.offset==controller.ORB_CHARGE_ORIGIN_OFFSET,"The opening Qi blink starts at the fighter's torso")
  await capture("Uru opening Qi blink" if id==Roster.RUBY_ID else "Kaz opening Qi blink")
  if id==Roster.RUBY_ID:
   for i in 14:p.spell_loadout.tick(1.0/60.0)
   await capture("Level 11 charge")
  for i in (14 if id==Roster.RUBY_ID else 28):
   p.spell_loadout.tick(1.0/60.0)
  var orbs=controller.pool.all[controller.pool_key].filter(func(orb):return orb.pool_live)
  check(orbs.size()==8 and orbs.all(func(orb):return orb.visual.get_instance_shader_parameter("uru_palette")==0.0),"All eight pooled orbs default to regular blue for both fighters")
  for orb in orbs:orb.set_physics_process(false)
  var shot=orbs.filter(func(orb):return is_instance_valid(orb.target))[0]
  if id==Roster.RUBY_ID:
   var launch_position:Vector3=shot.global_position
   shot.global_position=p.global_position+Vector3(2.7,-1.4,-2.0)
   shot.show()
   for orb in orbs:
    if orb!=shot:orb.hide()
   await capture("White and red Qi Orbs")
   shot.global_position=launch_position
  shot.global_position=AttackChain.aim_point(shot.target,p.global_position)+Vector3(0,.25,2.1)-shot.visual.position
  var hp:float=owner.unit_state(handle).hp
  for i in 14:
   shot._physics_process(1.0/60.0)
   if shot.shine.visible:break
  check(shot.shine.visible and is_equal_approx(owner.unit_state(handle).hp,hp),"Original energy shine appears before any native damage")
  for i in 5:shot._physics_process(1.0/60.0)
  check(shot.shine.frame>=2 and shot.shine.pixel_size*131>8.0 and is_equal_approx(owner.unit_state(handle).hp,hp),"The full-size burst opens before point-blank contact")
  if DisplayServer.get_name()!="headless":
   var camera=game.camera_rig.camera
   var previous:Transform3D=camera.global_transform
   camera.global_position=p.global_position+Vector3(6,4,9)
   camera.look_at(p.global_position+Vector3.UP*1.5)
   RenderingServer.force_draw()
   var name_="Uru pre-hit energy shine" if id==Roster.RUBY_ID else "Kaz pre-hit energy shine"
   check(root.get_texture().get_image().save_png(REPORT+name_+".png")==OK,"Captured "+name_)
   camera.global_transform=previous
  for i in 30:
   if shot.pool_live:shot._physics_process(1.0/60.0)
  check(not shot.pool_live and is_equal_approx(owner.unit_state(handle).hp,hp-750.0),"The shine leads one normal 750-damage hit and then returns to the pool (HP %s to %s, active %s, contact %s)"%[hp,owner.unit_state(handle).hp,shot.pool_live,shot.contact_done])
  for orb in orbs:orb.set_physics_process(true)
  p.spell_loadout.cancel()
 p.select_character(Roster.RUBY_ID)
 p.spell_loadout.equip(Roster.RUBY_ID,"equip","")
 var mirrors=Mirrors.new(p,0)
 for i in 5:
  check(mirrors.reinforce(Roster.RUBY_ID,ORIGIN+Vector3(3+i,0,0)),"Uru can occupy native ally slot %d"%i)
 check(mirrors.bodies.all(func(body):return body.model.atlases[0]==p.model.atlases[0]),"Five allies and the player share the prepared sprite pages")
 check(mirrors.bodies.all(func(body):return body.model.body.find_children("*","Sprite3D",false,false)==[body.model.sprite]),"Native Uru allies also draw without the aura")
 check(mirrors.bodies.all(func(body):return body.actions.size()==7 and not body.spell_loadout.instances.has("35:uru/recovery")),"Allies keep seven offensive actions and skip the player-only heal")
 for body in mirrors.bodies:
  body.ai_aim=game.actors[row.id].global_position
  body.active_ability.start_attack()
 for i in 121:
  for body in mirrors.bodies:body.active_ability.tick(1.0/60.0)
 check(mirrors.bodies.all(func(body):return not body.active_ability.is_attacking()),"Simultaneous native ally combos finish cleanly")
 mirrors.clear()
 await check_recovery()
 print("URU_STAFF_STEP_MS ",preload("res://tests/forest-shrine/army_benchmark_metrics.gd").summary(samples))
 print("URU_RESULT checks=",checks," failures=",failures)
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)

func press_six():
 var p=game.player
 var key=InputEventKey.new();key.physical_keycode=KEY_6;key.pressed=true
 p._unhandled_input(key)
 key.pressed=false;p._input(key)

func check_recovery():
 var p=game.player
 var loadout=p.spell_loadout
 var recovery=loadout.instances["35:uru/recovery"].controller
 p.hp=0;loadout.cancel()
 p.max_hp=1000;p.hp=p.max_hp
 game.forest_ui.sync()
 check(game.forest_ui.loadout_buttons[5].visible and not game.forest_ui.loadout_buttons[5].disabled and game.forest_ui.loadout_cooldowns[5].text.is_empty() and loadout.numbered_slots[5]==["Regrowth · ※再生術","special_6"],"Uru's sixth slot is ready for a manual cast")
 for cue in [
  ["cg_recovery_cast","cgefc10.wav","d0c6c6a53d2bfde7f74c556abaf9721910462cbc449a52aca71d2cd04ef261cf"],
  ["cg_recovery_body","cgefc38.wav","f1fc6b24185ce126a73f38eaacba1cbedc19e85f84eafd213523416eb6cc2644"],
  ["cg_recovery_pulse","cgefc28.wav","da92cc361dc34ecf1a2f3a217ffd831737602962f4138ce559934c67ea86edb6"],
 ]:
  var sample:AudioStreamWAV=SoundLibrary.original_for(35,cue[0])
  var digest=HashingContext.new()
  digest.start(HashingContext.HASH_SHA256)
  digest.update(sample.data)
  check(sample.resource_path.ends_with(cue[1]) and sample.mix_rate==22050 and sample.format==AudioStreamWAV.FORMAT_16_BITS and digest.finish().hex_encode()==cue[2],"The prepared %s PCM matches the archived cue byte for byte"%cue[0])
 check(p.combat_tuning("recovery")==100.0,"Uru starts with the Cross Gate baseline of 100 Recovery")
 game.character_tuning.uru={"recovery":11.0}
 var effect:Sprite3D=recovery.effect
 var number:Label3D=recovery.heal_number
 var sound_order:int=game.voice_idx
 for i in 601:recovery.tick(1.0/60.0)
 check(not effect.visible and recovery.cooldown==0 and game.voice_idx==sound_order,"Full HP stays idle until key 6")
 var hud_message=game.forest_ui.message
 p.active_ability.start_attack()
 press_six()
 check(p.hp==p.max_hp and p.active_ability.is_attacking() and loadout.current==null and recovery.cast_left>0 and effect.texture==recovery.CAST,"Key 6 begins Regrowth at full HP without interrupting the staff attack")
 check(game.last_sound_voice.get_meta("kind")=="cg_recovery_cast" and game.last_sound_voice.stream==SoundLibrary.original_for(35,"cg_recovery_cast"),"The opening glow uses the archived cast cue")
 p.active_ability.cancel()
 p.model.locomotion_velocity=Vector3.ZERO
 p.model.animate(1.0/60.0,0,true,0,0,false,0,false)
 check(p.model.current_clip.begins_with("6:"),"An idle Uru uses the original casting pose")
 await capture("Regrowth 1 - Cast")
 for i in 20:loadout.tick(1.0/60.0)
 check(effect.texture==recovery.CAST and effect.frame==6,"The cast holds seven frames for three ticks each")
 loadout.tick(1.0/60.0)
 var travel_start=effect.position.y
 check(effect.texture==recovery.ARRIVAL and effect.frame==0 and recovery.moves_left==0 and game.voice_idx==sound_order+1,"The original target effect launches after the 21-tick cast")
 for i in 8:loadout.tick(1.0/60.0)
 check(effect.position.y<travel_start and effect.position.y>recovery.arrival_height and game.voice_idx==sound_order+1,"The target effect descends before the arrival sound")
 await capture("Regrowth 2 - Incoming effect")
 for i in 2:loadout.tick(1.0/60.0)
 check(is_equal_approx(effect.position.y,recovery.arrival_height) and game.voice_idx==sound_order+2 and game.last_sound_voice.stream==SoundLibrary.original_for(35,"cg_recovery_body"),"The effect reaches Uru's torso and plays the body cue once")
 for i in 90:loadout.tick(1.0/60.0)
 check(recovery.moves_left==6 and p.hp==p.max_hp and not effect.visible and not number.visible and game.voice_idx==sound_order+2,"Finishing the cast arms six heals at full HP")
 for i in 7:
  p.active_ability.start_attack()
  loadout.tick(1.0/60.0)
  p.active_ability.cancel()
 check(recovery.moves_left==6 and p.hp==p.max_hp and effect.texture==recovery.RING and effect.visible and not number.visible and game.voice_idx==sound_order+9,"Seven full-HP actions play the green effect and cue without spending a heal")
 for i in 16:loadout.tick(1.0/60.0)
 await capture("Regrowth - Full HP")
 p.hp=10
 for i in 100:loadout.tick(1.0/60.0)
 check(recovery.moves_left==6 and p.hp==10 and not effect.visible,"After damage, the reserved heals wait for an attack or spell")
 press_six()
 check(recovery.cast_left==0 and recovery.moves_left==6,"Key 6 respects the ten-second recast cooldown")
 p.active_ability.hit()
 p.move_and_collide(Vector3.RIGHT*.1)
 loadout.tick(1.0/60.0)
 check(recovery.moves_left==6 and p.hp==10,"Forced movement during a hit reaction does not spend Regrowth")
 p.active_ability.cancel()

 var origin:Vector3=p.global_position
 p.smoke_mode=true
 p.smoke_move=Vector2.RIGHT
 for i in 4:p._physics_process(1.0/60.0)
 check(p.global_position.distance_to(origin)>.01 and recovery.moves_left==6 and p.hp==10 and not effect.visible,"Walking keeps all six heals armed")
 p.smoke_move=Vector2.ZERO
 p.velocity=Vector3.ZERO
 var jump_origin:float=p.global_position.y
 tap("jump")
 for i in 8:p._physics_process(1.0/60.0)
 check(p.global_position.y>jump_origin+.1 and recovery.moves_left==6 and p.hp==10 and not effect.visible,"Jumping keeps all six heals armed")
 p.attack_chain.reset()
 tap("dodge")
 var dodged:bool=p.dodge_time>0
 for i in 20:p._physics_process(1.0/60.0)
 check(dodged and recovery.moves_left==6 and p.hp==10 and not effect.visible,"Dodging with an audio-only ticket keeps all six heals armed")
 p.global_position=ORIGIN
 p.velocity=Vector3.DOWN
 p.move_and_slide()
 p.model.show()
 tap("light_attack")
 loadout.tick(1.0/60.0)
 check(p.hp==36 and recovery.moves_left==5 and p.active_ability.is_attacking() and effect.texture==recovery.RING and effect.visible,"A staff attack triggers one green heal for 26 HP")
 check(game.last_sound_voice.stream==SoundLibrary.original_for(35,"cg_recovery_pulse") and number.visible and number.text=="26" and game.forest_ui.message==hud_message,"The attack plays the green cue and shows the actual HP restored")
 for i in 16:loadout.tick(1.0/60.0)
 await capture("Regrowth 3 - Green healing on attack")
 for i in 100:loadout.tick(1.0/60.0)
 check(p.hp==36 and recovery.moves_left==5 and not effect.visible and not number.visible,"Holding the same attack ticket never triggers a second heal")
 p.active_ability.cancel()
 loadout.number_input(2,true);loadout.number_input(2,false)
 var fire=loadout.instances["35:kazi/fire"]
 loadout.tick(1.0/60.0)
 check(p.hp==62 and recovery.moves_left==4 and loadout.current==fire and fire.busy(),"Starting Fire on key 2 triggers one heal without interrupting the spell")
 loadout.interrupt()
 loadout.number_input(2,true);loadout.number_input(2,false)
 loadout.tick(1.0/60.0)
 check(p.hp==62 and recovery.moves_left==4 and loadout.current==null,"A spell on cooldown does not spend a heal")
 loadout.interrupt()
 p.hp=988
 p.active_ability.start_attack()
 loadout.tick(1.0/60.0)
 check(p.hp==p.max_hp and number.text=="12" and recovery.moves_left==3,"The next action heals only missing HP and shows the capped amount")
 p.active_ability.cancel()
 p.active_ability.start_attack()
 loadout.tick(1.0/60.0)
 check(recovery.moves_left==3 and effect.visible and not number.visible and game.last_sound_voice.stream==SoundLibrary.original_for(35,"cg_recovery_pulse"),"A full-HP action still shows the hoops without spending another heal")
 p.active_ability.cancel()

 var node_count=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var resource_count=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 var recovery_samples=[]
 sound_order=game.voice_idx
 p.hp=100
 for i in 100:
  if i in [0,33,66]:
   p.active_ability.cancel()
   p.active_ability.start_attack()
  var started=Time.get_ticks_usec()
  recovery.tick(1.0/60.0)
  recovery_samples.append((Time.get_ticks_usec()-started)/1000.0)
 p.active_ability.cancel()
 check(recovery.moves_left==0 and p.hp==178 and game.voice_idx==sound_order+3 and recovery.effect==effect and recovery.heal_number==number,"Six actual heals spend Regrowth and reuse the same sprite and label")
 for i in 601:
  recovery.tick(1.0/60.0)
 check(recovery.cooldown<.000001 and not effect.visible,"After the cooldown Regrowth waits for another keypress")
 sound_order=game.voice_idx
 game.settings.reduced_flashes=true
 for cycle in 5:
  press_six()
  for i in 61:loadout.tick(1.0/60.0)
  p.hp=10
  p.active_ability.start_attack()
  loadout.tick(1.0/60.0)
  p.active_ability.cancel()
  check(recovery.moves_left==5 and p.hp==36 and is_equal_approx(effect.modulate.a,recovery.RING_ALPHA*.55),"Cast %d refreshes the six moves and respects Reduced Flashes"%(cycle+1))
  for i in 540:recovery.tick(1.0/60.0)
 check(game.voice_idx==sound_order+15 and Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==node_count and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resource_count,"Five repeated casts reuse all resources and play three ordered cues each")
 print("URU_RECOVERY_STEP_MS ",preload("res://tests/forest-shrine/army_benchmark_metrics.gd").summary(recovery_samples))
 game.settings.reduced_flashes=false
 game.character_tuning.erase("uru")
 p.hp=25
 p.active_ability.start_attack()
 loadout.tick(1.0/60.0)
 p.active_ability.cancel()
 check(p.hp==265 and number.text=="240","The default Recovery stat still gives 240 HP per move")
 p.hp=0;loadout.cancel();recovery.tick(10.0)
 check(p.hp==0 and recovery.moves_left==0 and recovery.cast_left==0 and recovery.cooldown==0 and not effect.visible and not number.visible,"Defeat clears Regrowth charges, cooldown and visuals")
 p.hp=p.max_hp
 press_six()
 p.select_character(Roster.KAZI_ID)
 await process_frame
 game.forest_ui.sync()
 press_six()
 check(not is_instance_valid(effect) and not is_instance_valid(number),"Switching fighters retires Uru's active Regrowth visuals")
 check(game.forest_ui.loadout_buttons[5].visible and loadout.numbered_slots[5][0]==loadout.Catalog.KAGEROU_NAME and p.active_ability.kagerou_enabled and not loadout.instances.has("34:uru/recovery"),"Kaz's sixth slot still activates his own Kagerou")
