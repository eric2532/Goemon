extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const OUT="res://build/Other Files/Asset Toolkit/Shin Shadow Linger/"
const Roster=preload("res://scripts/rogue_roster.gd")
const STEP=1.0/60
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
var samples:Array[int]=[]
var victims:Array[Ninja]=[]

func press(key:int):
 var event=InputEventKey.new();event.physical_keycode=key;event.pressed=true
 game.player._unhandled_input(event)
 event.pressed=false;game.player._input(event)

func step_player(count:int):
 for i in count:
  var started=Time.get_ticks_usec()
  game.player._physics_process(STEP)
  samples.append(Time.get_ticks_usec()-started)
  game.army_runtime.flush_presentation()
  game.crowd.army.presentation.tick(STEP)

func settle(home:Vector3):
 var p=game.player
 p.global_position=home;p.velocity=Vector3.ZERO;p.impact_pause=0;p.facing=Vector3.FORWARD
 game.camera_rig.camera.global_position=home+Vector3(7,4,9)
 game.camera_rig.camera.look_at(home+Vector3(0,1.0,-2.3))
 step_player(12)

func capture(filename:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+filename)==OK,"Captured "+filename)

func run():
 create_timer(100).timeout.connect(func():quit(1))
 root.size=Vector2i(1280,800)
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 DirAccess.make_dir_recursive_absolute(OUT)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_physics_process(false);game.army_runtime.set_process(false)
 var p=game.player
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 p.select_character(Roster.SHIN_ID);fresh()
 var kit=p.active_ability
 var model=p.model
 var presentation=game.crowd.army.presentation
 var home=Vector3(-150,0,127)
 home.y=game.model.surface_height(home.x,home.z)+.05
 game.model.update_vision(home)
 var dummy=game.training_dummy
 dummy.position=home+Vector3.FORWARD*2.3
 dummy.home=dummy.position
 game.impact_confirmed.connect(func(victim,_strength,_time):victims.append(victim))
 game.settings.disable_character_cooldowns=false
 game.tuning.invincible=false
 settle(home)
 check(p.is_on_floor() and model.motions.weapon=="sword","Basic Shin starts grounded with the sword")
 game.world.sync(0)
 var melee_radius:float=game.world.attack_range.radius(p)
 check(melee_radius>3 and is_equal_approx(melee_radius,p.melee_strike_reach()) and game.world.attack_materials.all(
  func(material):return material.get_shader_parameter("attack_radius") in [null,0.0]
 ),"Shin retains his armed attack range while the ground circle stays hidden at idle")
 p.invuln=.85
 var always_visible=true
 for i in 55:
  step_player(1)
  always_visible=always_visible and model.sprite.is_visible_in_tree()
 check(always_visible,"Shin stays visible throughout post-hit invulnerability")
 var body_nodes:int=model.body.get_child_count()
 var glow:Sprite3D=model.combo_glow
 var counter_fx:Sprite3D=model.shin_counter_fx
 var shadow:Sprite3D=model.kagerou_shadows[0]
 for weapon in ["sword","polearm"]:
  var skill="乾坤" if weapon=="sword" else "諸刃"
  var burst="shin_sure_strike" if weapon=="sword" else "shin_double_edge"
  check(model.motions.weapon==weapon and p.spell_loadout.numbered_slots[0][0]==skill,"Key 1 displays "+skill+" with "+weapon)
  check(p.spell_loadout.numbered_slots[2].is_empty() if weapon=="sword" else p.spell_loadout.numbered_slots[2][0]=="一石二鳥","Key 3 is exclusive to polearm")
  victims.clear()
  p.combat_aim_left=0
  press(KEY_1)
  check(glow.visible and glow.get_parent()==model.body and kit.clip=="6","Key 1 starts a character-attached shine with "+weapon)
  var cue="cg_shin_sure_strike_charge" if weapon=="sword" else "cg_shin_double_edge_charge"
  check(game.last_sound_voice.get_meta("kind")==cue and game.last_sound_voice.stream==SoundLibrary.CROSSGATE_FLASH,"Each stance skill uses its own charge control with the original WAV")
  step_player(13)
  check(glow.frame>0 and victims.is_empty(),"Charge advances without dealing early damage")
  check(glow.texture.resource_path.ends_with("/qigong/charge.png") and is_equal_approx(glow.pixel_size*345.0,model.sprite.pixel_size*model.body_height_pixels*5.0),"Charge uses original 110100 at five times standing height")
  if weapon=="sword":await capture("Sure Strike charge.png")
  var swing_heard=false
  for i in 100:
   step_player(1)
   if not victims.is_empty():break
   if game.last_sound_voice.stream==kit.shin_sound(false):swing_heard=true
  check(swing_heard,"The original "+weapon+" swing sample plays before contact")
  check(victims==[dummy] and not glow.visible,"The weapon strikes the dummy once after charging")
  check(presentation.effects.any(func(row):return row.kind==burst),"Contact starts the recovered "+skill+" burst")
  step_player(8)
  await capture(skill+" impact.png")
  step_player(90)
  check(victims==[dummy] and not presentation.effects.any(func(row):return row.kind==burst),"Recovery retires the impact with no extra damage")
  check(p.spell_loadout.numbered_slots[3][0]=="明鏡止水","Key 4 displays 明鏡止水 with "+weapon)
  p.hp=p.max_hp*(.4 if weapon=="sword" else .8)
  var initial:float=p.hp
  press(KEY_4)
  check(kit.ticket.action=="shin_meditation" and glow.visible and glow.texture.resource_path.ends_with("/meditation.png") and p.hp==initial,"明鏡止水 begins with the level 11 cast before healing")
  check(game.last_sound_voice.stream.resource_path.ends_with("/cgefc10.wav") and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.55*.6),
        "明鏡止水 plays original event 261 at lower gain to leave room for the heal")
  step_player(22)
  check(model.current_clip.begins_with("6:") and model.current_frame==2 and model.sprite.texture.resource_path.ends_with("/cast-0.png"),
        "明鏡止水 plays Shin's original magic animation with "+weapon)
  await capture("Meditation "+weapon+" magic pose.png")
  step_player(15)
  check(p.hp==initial and not glow.visible and kit.is_attacking() and game.last_sound_voice.stream.resource_path.ends_with("/cgefc10.wav"),
        "The casting effect ends at the pose marker before HP or the recovery cue")
  step_player(22)
  check(is_equal_approx(p.hp,minf(initial*1.5,p.max_hp)) and not glow.visible and not kit.is_attacking(),"明鏡止水 heals once and caps at maximum HP with "+weapon)
  check(game.last_sound_voice.stream==SoundLibrary.original_for(Roster.SHIN_ID,"cg_shin_meditation_heal") and is_equal_approx(db_to_linear(game.last_sound_voice.volume_db),.55),
        "The distinct native event 256 plays at full skill gain when HP is restored with "+weapon)
  var heal_text=str(roundi(p.hp-initial))
  check(presentation.labels.any(func(label):
   return label.visible and label.text==heal_text and label.font==presentation.HEAL_FONT and label.font_size==52 and label.has_meta("hit_follow")
  ),"明鏡止水 shows only the actual HP gained in critical-hit-sized green digits above Shin")
  if weapon=="sword":await capture("Meditation green heal.png")
  var healed:float=p.hp
  press(KEY_4)
  check(p.hp==healed and not kit.is_attacking(),"The key 4 cooldown blocks repeat healing")
  p.hp=p.max_hp
  kit.clear_cooldowns()
  if weapon=="sword":p.swap_weapon()
 check(p.spell_loadout.numbered_slots[1][0]=="反擊","Swapping to polearm assigns 反擊 to key 2")
 var army=game.army_runtime
 var point=home+Vector3.FORWARD*2.8
 point.y=game.model.surface_height(point.x,point.z)
 var row=game.model.waves.spawn_enemy(0,point,-1,0)
 row.hp=500000.0;row.max_hp=row.hp
 army.import_arrivals()
 var enemy:Ninja=game.actors[row.id]
 army.integration_tick(STEP)
 game.crowd.present_army(army.render_snapshot(),[])
 victims.clear()
 settle(home)
 p.invuln=0
 press(KEY_2)
 check(glow.visible and kit.shin_counter_armed and victims.is_empty(),"Polearm key 2 toggles 反擊 on and begins its shine")
 var planted:Vector3=p.global_position
 dummy.position=home+Vector3.RIGHT*30;dummy.home=dummy.position
 p.smoke_move=Vector2.RIGHT
 tap("jump");tap("dodge")
 step_player(12)
 check(p.global_position.distance_to(planted)<.025 and kit.clip=="6","The counter shine blocks movement, jump and dodge")
 p.smoke_move=Vector2.ZERO
 step_player(16)
 game.forest_ui.sync()
 check(not glow.visible and game.forest_ui.loadout_cooldowns[1].text=="ON","Hotbar shows the counter toggle stays on")
 p.invuln=.5
 var health:float=p.hp
 p.take_hit_from(20,Vector3.BACK,false,int(row.id))
 check(p.hp==health and kit.shin_counter_armed and not counter_fx.visible,"An invulnerable hit leaves the counter armed")
 p.invuln=0
 p.attack_chain.reset()
 var enemy_health:float=army.unit_state(enemy.handle).hp
 for i in 250:
  army.integration_tick(STEP)
  if p.hp<health:break
 check(p.hp<health and kit.shin_counter_armed and kit.shin_counter.target==enemy and not kit.is_attacking(),"A native hit takes HP and starts an independent counter aimed at its attacker")
 check(presentation.effects.any(func(fx):return fx.kind in presentation.GOLD_SPARKS and fx.position.distance_to(p.global_position)<3) and presentation.labels.any(func(label):return label.visible and label.text==str(roundi(health-p.hp))),"Shin displays the shared gold hit spark and actual HP lost")
 check(counter_fx.visible and game.voices.any(func(voice):return voice.playing and voice.stream==SoundLibrary.original_for(Roster.SHIN_ID,"cg_shin_counter")),"Retaliation opens with green EX energy and the original standard counter WAV")
 army.flush_presentation()
 var shadow_origin=shadow.global_position
 var fx_origin=counter_fx.global_position
 var first_pose=shadow.region_rect
 p.smoke_move=Vector2.LEFT
 game.hit_stop=0
 step_player(13)
 check(p.global_position.distance_to(planted)>1.0 and shadow.visible and shadow.global_position==shadow_origin and counter_fx.global_position==fx_origin,
       "Shin can run while the afterimage and green energy stay at the hit location")
 check(shadow.region_rect!=first_pose and shadow.modulate.a<1.0,"The translucent afterimage advances Shin's polearm pose")
 step_player(8)
 await capture("Polearm counter energy.png")
 for i in 90:
  step_player(1)
  if not victims.is_empty():break
 check(victims==[enemy] and is_equal_approx(enemy_health-army.unit_state(enemy.handle).hp,1500.0),"Counter deals 1,500 base damage once and excludes the distant dummy")
 check(p.impact_pause==0 and game.hit_stop==0,"The shadow impact leaves Shin and the game clock moving")
 p.smoke_move=Vector2.ZERO
 army.flush_presentation()
 check(presentation.effects.any(func(row):return row.kind in presentation.GOLD_SPARKS),"Counter contact uses the shared native impact sparks")
 await capture("Polearm counter impact.png")
 for i in 90:
  if kit.shin_counter.is_empty():break
  step_player(1)
 check(shadow.visible and is_equal_approx(model.shin_counter_linger,.3),"The finished counter holds its final shadow pose for another 0.3 seconds")
 var last_pose=shadow.region_rect
 step_player(12)
 check(shadow.visible and shadow.region_rect==last_pose and victims==[enemy],"The shadow lingers after 0.2 seconds without another hit")
 await capture("Counter lingering pose.png")
 step_player(7)
 check(not shadow.visible and model.shin_counter_linger==0,"The lingering shadow retires after 0.3 seconds")
 step_player(100)
 check(victims==[enemy] and not shadow.visible and not counter_fx.visible,"Counter recovery clears its shadow and energy without repeating the hit")
 await verify_counter_streak(home,enemy,int(row.id))
 step_player(130)
 check(kit.shin_counter_armed and kit.shin_counter_rate()==1.0 and not counter_fx.visible,"A quiet gap resets counter speed while leaving the toggle on")
 p.take_hit_from(1,Vector3.BACK,false,int(row.id))
 p.swap_weapon()
 check(not kit.shin_counter_armed and model.motions.weapon=="unarmed" and p.spell_loadout.numbered_slots[0].is_empty() and p.spell_loadout.numbered_slots[3].is_empty(),"Swapping away disarms and clears the unarmed skill slots")
 check(kit.shin_counter.is_empty() and not shadow.visible and not counter_fx.visible,"Swapping away retires a live shadow and green effect")
 check(game.world.attack_range.radius(p)<melee_radius,"The melee ring shrinks on switching to unarmed")
 p.swap_weapon();settle(home)
 check(p.spell_loadout.numbered_slots[1][0]=="連擊","Sword restores 連擊 to key 2")
 dummy.position=home+Vector3(80,0,80)
 dummy.home=dummy.position
 victims.clear();var before_combo_sound:int=game.voice_idx;press(KEY_2)
 check(glow.visible and kit.ticket.action=="kazi_combo" and game.voice_idx==before_combo_sound+1 and game.last_sound_voice.get_meta("kind")=="cg_combo_charge","Sword key 2 starts 連擊 with its recovered charge sound")
 p.invuln=0
 health=p.hp
 p.take_hit(10,Vector3.BACK)
 check(p.hp==health and kit.clip=="6","連擊 is invulnerable from the start of its shine")
 step_player(28)
 p.take_hit(10,Vector3.BACK,true)
 check(p.hp==health and kit.clip=="5","連擊 blocks projectile damage between blinks")
 for i in 650:
  step_player(1)
  if presentation.effects.any(func(fx):return fx.kind=="shin_combo") and not captured:
   captured=true
   await capture("Sword Combo impact.png")
  if not kit.is_attacking():break
 check(victims.size()==7 and victims.count(enemy)==7 and captured,"連擊 hits a lone native target seven times with the EX burst")
 dummy.position=home+Vector3.FORWARD*2.3
 dummy.home=dummy.position
 step_player(61)
 p.take_hit(17,Vector3.BACK)
 check(p.hp<health and not p.crossgate_combo_protected(),"Damage resumes when 連擊 ends")
 step_player(5)
 await capture("Shin incoming hit.png")
 kit.cancel()
 for skin in Roster.ShinSkins.catalog(false):
  if skin==Roster.ShinSkins.DEFAULT:continue
  dummy.position=home+Vector3.FORWARD*2.3;dummy.home=dummy.position
  game.select_shin_skin(Roster.SHIN_ID,skin)
  p.attack_chain.reset()
  kit.clear_cooldowns()
  settle(home)
  for weapon in ["sword","polearm"]:
   var skill="乾坤" if weapon=="sword" else "諸刃"
   check(model.shin_skin==skin and model.motions.weapon==weapon and p.spell_loadout.numbered_slots[0][0]==skill and p.spell_loadout.numbered_slots[3][0]=="明鏡止水","Skin %d has %s and 明鏡止水 with %s"%[skin,skill,weapon])
   victims.clear()
   press(KEY_1)
   check(glow.visible and kit.ticket.action=="shin_sure_strike","Skin %d charges %s with %s"%[skin,skill,weapon])
   step_player(110)
   check(victims.count(dummy)==1,"Skin %d lands %s once on the dummy with %s"%[skin,skill,weapon])
   if weapon=="sword":
    settle(home)
    victims.clear()
    press(KEY_2)
    check(glow.visible and kit.ticket.action=="kazi_combo","Skin %d uses 連擊 on sword key 2"%skin)
    step_player(650)
    check(kit.combo_strikes==7 and victims.has(enemy),"Skin %d lands its seven-strike sword 連擊 on the native enemy"%skin)
    settle(home)
    p.swap_weapon()
    kit.clear_cooldowns()
  dummy.position=home+Vector3.RIGHT*30;dummy.home=dummy.position
  victims.clear()
  p.hp=p.max_hp;p.invuln=0
  press(KEY_2)
  check(glow.visible and kit.shin_counter_armed and game.last_sound_voice.get_meta("kind")=="cg_shin_counter_charge","Skin %d arms 反擊 with its own charge control on polearm key 2"%skin)
  step_player(28)
  var before_sound:int=game.voice_idx
  p.take_hit_from(1,Vector3.BACK,false,int(row.id))
  check(counter_fx.visible and kit.shin_counter_armed and game.voices.any(func(voice):
   return int(voice.get_meta("order",0))>before_sound and voice.stream==SoundLibrary.original_for(Roster.SHIN_ID,"cg_shin_counter")
  ),"Skin %d plays the green effect and original counter sound"%skin)
  if skin==105737:
   step_player(13)
   await capture("Dark Hair Teal counter.png")
  step_player(90)
  check(victims==[enemy] and not counter_fx.visible,"Skin %d counters its attacker once and retires the effect"%skin)
 check(model.body.get_child_count()==body_nodes and glow==model.combo_glow and counter_fx==model.shin_counter_fx and model.kagerou_shadows[0]==shadow,"All 22 skins reuse the same skill sprites and pooled afterimage")
 await verify_sure_area(home,enemy)
 await verify_combo_splash(home)
 await verify_two_birds(home)
 verify_shared_combo(home,dummy)
 samples.sort()
 print("SHIN_SKILL_PLAYER_CALLBACK p95_ms=%.3f max_ms=%.3f count=%d"%[samples[floori(samples.size()*.95)]*.001,samples.back()*.001,samples.size()])
 game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 await create_timer(.05).timeout
 game.queue_free();await frames()
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SHIN_SKILLS_RESULT checks=%d failures=%d"%[checks,failures])
 quit(1 if failures else 0)


func verify_shared_combo(home:Vector3,dummy:Ninja):
 var p=game.player
 var model=p.model
 var kit=p.active_ability
 var original:Dictionary=model.fighter
 var atlases:Array=model.atlases.duplicate()
 model.fighter=original.merged({"weapon_skills":false,"combo":true},true)
 p.swap_weapon()
 p.swap_weapon()
 kit.clear_cooldowns()
 p.attack_chain.reset()
 settle(home)
 p.combat_aim_left=0
 dummy.position=home+Vector3.RIGHT*30
 dummy.home=dummy.position
 victims.clear()
 check(model.motions.weapon=="sword" and model.atlases==atlases,"The reused combo keeps the receiving fighter's prepared sword and atlases")
 check(p.spell_loadout.numbered_slots[0].is_empty() and p.spell_loadout.numbered_slots[1][0]=="連擊",
       "The hotbar follows the profile instead of restoring the fighter's usual skills")
 press(KEY_2)
 check(kit.ticket.action=="kazi_combo" and model.combo_glow.visible,"The borrowed combo starts through normal numbered input")
 step_player(170)
 check(victims.count(dummy)==1 and kit.combo_strikes<7 and not kit.is_attacking(),
       "The classic combo lands once on a lone target using the receiving weapon's contact")
 model.fighter=original

func verify_counter_streak(home:Vector3,enemy:Ninja,source:int):
 var p=game.player
 var kit=p.active_ability
 var army=game.army_runtime
 var point=home+Vector3(3,0,-1.2)
 point.y=game.model.surface_height(point.x,point.z)
 var row=game.model.waves.spawn_enemy(0,point,-1,0)
 row.hp=8000.0;row.max_hp=row.hp
 army.import_arrivals()
 var second:Ninja=game.actors[row.id]
 settle(home)
 p.hp=p.max_hp;p.invuln=0
 press(KEY_2)
 check(not kit.shin_counter_armed,"Pressing 2 again toggles the counter off")
 press(KEY_2)
 victims.clear()
 var health:float=p.hp
 p.take_hit_from(2,Vector3.BACK,false,source)
 check(p.hp<health and kit.clip=="6" and kit.shin_counter.target==enemy,"Damage during the arming shine starts a separate counter")
 health=p.hp
 p.take_hit_from(2,Vector3.LEFT,false,int(row.id))
 p.take_hit_from(3,Vector3.LEFT,true,int(row.id))
 check(p.hp<health-2 and kit.shin_counter_rate()==1.5 and kit.shin_counter.target==enemy,"Two more hits take HP and speed up the shadow's current swing without restarting it")
 game.forest_ui.sync()
 check(game.forest_ui.loadout_cooldowns[1].text=="1.50×","Hotbar shows the current counter speed")
 step_player(28)
 check(not kit.is_attacking() and not kit.shin_counter.is_empty(),"Finishing the arming shine leaves Shin ready while the shadow is active")
 tap("dodge")
 check(p.dodge_time>0 and not kit.shin_counter.is_empty(),"Shin can evade while the shadow still has a retaliation queued")
 await capture("Counter streak.png")
 for i in 150:
  step_player(1)
  if kit.shin_counter.is_empty():break
 check(victims.size()==4 and victims.count(enemy)==2 and victims.count(second)==2 and kit.shin_counter_armed,"Each retaliation hits the attacker and nearby enemy once with the toggle still on")
 check(kit.shin_counter_rate()>1.0,"The speed boost persists between consecutive counters")
 tap("light_attack")
 check(kit.shin_counter_rate()==1.0 and kit.shin_counter_armed,"A normal attack breaks the speed streak without disabling 反擊")
 step_player(85)
 settle(home)
 p.invuln=0
 p.take_hit_from(1,Vector3.BACK,false,source)
 p.take_hit_from(1,Vector3.BACK,false,source)
 kit.clear_cooldowns()
 press(KEY_1)
 check(kit.shin_counter_rate()==1.0 and kit.shin_counter_armed and kit.ticket.action=="shin_sure_strike" and not kit.shin_counter.is_empty(),"Shin can start another skill immediately and reset the streak while the shadow finishes")
 var move_ticket:Dictionary=kit.ticket
 p.take_hit_from(1,Vector3.BACK,true,source)
 check(is_same(kit.ticket,move_ticket) and kit.clip=="6" and p.model.combo_glow.visible,"Damage while armed leaves the next skill's ticket and windup intact")
 victims.clear()
 for i in 60:
  step_player(1)
  if not victims.is_empty():break
 check(victims.size()==2 and victims.count(enemy)==1 and victims.count(second)==1 and is_same(kit.ticket,move_ticket) and p.attack_left>0 and p.impact_pause==0,"The extra hit lands once without pausing or replacing Shin's next skill")
 kit.cancel(true)
 press(KEY_2)
 step_player(90)
 check(victims.size()==2 and victims.count(enemy)==1 and victims.count(second)==1 and kit.shin_counter.is_empty() and kit.shin_counter_pending.is_empty() and not p.model.kagerou_shadows[0].visible,
       "Toggling off clears the shadow and queued contact")
 press(KEY_2)
 step_player(28)
 army.despawn(second.handle)
 game.model.enemies.erase(second.forest_id)

func verify_sure_area(home:Vector3,old_target:Ninja):
 var p=game.player
 var kit=p.active_ability
 var army=game.army_runtime
 var fx=game.crowd.army.presentation
 army.flush_presentation()
 step_player(60)
 game.model.waves.crossgate_pet_test=true
 army.refresh_kits()
 game.select_shin_skin(Roster.SHIN_ID,Roster.ShinSkins.DEFAULT)
 game.forest_ui.message_left=0
 game.training_dummy.position=home+Vector3(80,0,80)
 army.set_pose(old_target.handle,home+Vector3(80,0,80),0)
 for weapon in ["sword","polearm"]:
  kit.clear_cooldowns()
  p.attack_chain.reset();p.hp=p.max_hp;p.invuln=0
  settle(home)
  game.camera_rig.camera.global_position=home+Vector3(8,10,14)
  game.camera_rig.camera.look_at(home+Vector3(0,1,-3))
  var lane=weapon=="polearm"
  var skill="諸刃" if lane else "乾坤"
  var burst="shin_double_edge" if lane else "shin_sure_strike"
  var targets:Array[Ninja]=[]
  var excluded:Array[Ninja]=[]
  for i in 24:
   var offset:Vector3
   if i<20:
    offset=Vector3((i%5-2)*.6,0,-2.1-floori(i/5.0)*.45)
   else:
    offset=[Vector3(0,0,8),Vector3(14,0,-5.4),Vector3(0,0,-24),Vector3(18,0,-2.7)][i-20]
   var point=home+offset
   point.y=game.model.surface_height(point.x,point.z)
   var row=game.model.waves.spawn_enemy(Roles.SLIME,point,-1,i)
   row.hp=8000.0;row.max_hp=row.hp
   army.import_arrivals()
   var target:Ninja=game.actors[row.id]
   if i<20:targets.append(target)
   else:excluded.append(target)
  var wall=StaticBody3D.new()
  var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.3,8,.3)
  shape.shape=box;wall.add_child(shape);game.add_child(wall)
  wall.position=home+Vector3(1.1,3,-1.35)
  await physics_frame;await physics_frame
  army.sync_targets()
  game.crowd.present_army(army.render_snapshot(),[])
  victims.clear()
  if not lane:
   press(KEY_1)
   p.take_hit(5,Vector3.BACK)
   check(p.hp<p.max_hp and not kit.is_attacking() and not p.model.combo_glow.visible and kit.shin_sure_cooldown>0,
         "A hit interrupts 乾坤 during its shine and spends the cooldown")
   kit.cancel();kit.clear_cooldowns()
   settle(home)
   game.camera_rig.camera.global_position=home+Vector3(0,29,31)
   game.camera_rig.camera.look_at(home+Vector3(0,1,-21))
   p.hp=p.max_hp;p.invuln=0
  press(KEY_1)
  check(kit.is_attacking() and not p.crossgate_combo_protected() and p.model.combo_glow.visible,"%s begins with its interruptible torso shine"%skill)
  var planted:Vector3=p.global_position
  p.smoke_move=Vector2.RIGHT
  step_player(13)
  check(p.global_position.distance_to(planted)<.025,"%s keeps Shin planted through its windup"%skill)
  p.smoke_move=Vector2.ZERO
  if not lane:await capture("Large torso shine.png")
  for i in 100:
   step_player(1)
   if not victims.is_empty():break
  print("SHIN_SURE_STRIKE_CONTACT weapon=",weapon," hits=",victims.size()," player_step_ms=",samples.back()*.001)
  if victims.size()!=20 or targets.any(func(target):return not victims.has(target)):
   print("  missed=",targets.filter(func(target):return not victims.has(target)).map(func(target):return target.position-home),
         " excluded_hit=",excluded.filter(func(target):return victims.has(target)).map(func(target):return target.position-home))
  check(victims.size()==20 and targets.all(func(target):return victims.count(target)==1),"%s hits 20 native slimes exactly once in one contact"%skill)
  check(targets.all(func(target):return is_equal_approx(float(army.unit_state(target.handle).get("hp",0)),3000.0)),"%s delivers 5,000 base damage per slime"%skill)
  check(excluded.all(func(target):return is_equal_approx(float(army.unit_state(target.handle).get("hp",0)),8000.0)),"%s spares the rear, outside range, flank and covered slime"%skill)
  army.flush_presentation()
  check(fx.labels.filter(func(label):return label.visible and label.text=="5000").size()==20,"%s presents one Blue Cross Gate number per slime"%skill)
  check(fx.effects.filter(func(effect):return effect.kind==burst).size()==20 and targets.all(func(target):return fx.effects.any(func(effect):return effect.kind==burst and effect.position.is_equal_approx(target.combat_bounds().get_center()))),"%s draws a body-centred explosion for every confirmed weapon hit"%skill)
  step_player(7)
  await capture("Twenty slimes "+weapon+".png")
  if not lane:
   game.camera_rig.camera.global_position=home+Vector3(15,8,15)
   game.camera_rig.camera.look_at(home+Vector3(0,2,-16))
   await capture("Sure Strike slimes low angle.png")
  step_player(100)
  wall.free()
  for target in targets+excluded:
   army.despawn(target.handle)
   game.model.enemies.erase(target.forest_id)
  if not lane:p.swap_weapon()

func verify_combo_splash(home:Vector3):
 var p=game.player
 var kit=p.active_ability
 var army=game.army_runtime
 var fx=game.crowd.army.presentation
 game.update_character_tuning(Roster.SHIN_ID,"combo_splash_radius",10)
 p.swap_weapon();p.swap_weapon()
 kit.clear_cooldowns();p.attack_chain.reset()
 settle(home)
 game.camera_rig.camera.global_position=home+Vector3(3,16,20)
 game.camera_rig.camera.look_at(home+Vector3(0,2,-6))
 var targets:Array[Ninja]=[]
 for offset in [Vector3(0,0,-3.5),Vector3(8,0,-3.5),Vector3(-8,0,-3.5),Vector3(0,0,-11.5),Vector3(0,0,4.5),
                Vector3(6,0,2.5),Vector3(8,0,-11.5),Vector3(-8,0,-11.5)]:
  var point=home+offset
  point.y=game.model.surface_height(point.x,point.z)
  var row=game.model.waves.spawn_enemy(Roles.SLIME,point,-1,0)
  row.hp=10000.0;row.max_hp=row.hp
  army.import_arrivals()
  targets.append(game.actors[row.id])
 var wall=StaticBody3D.new()
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(1,8,1.5)
 shape.shape=box;wall.add_child(shape);game.add_child(wall)
 wall.position=home+Vector3(3,3,-.5)
 await physics_frame;await physics_frame
 army.sync_targets()
 game.crowd.present_army(army.render_snapshot(),[])
 victims.clear()
 press(KEY_2)
 for i in 100:
  step_player(1)
  if not victims.is_empty():break
 print("SHIN_COMBO_SPLASH first_strike_hits=",victims.size()," player_step_ms=",samples.back()*.001)
 check(victims.size()==5 and targets.slice(0,5).all(func(target):return victims.count(target)==1),
       "連擊 hits five native slimes in one strike, excluding cover and diagonals outside its radius")
 var first_hp:float=army.unit_state(targets[0].handle).hp
 check(first_hp<10000 and targets.slice(1,5).all(func(target):return is_equal_approx(army.unit_state(target.handle).hp,first_hp)),
       "The splash deals the same damage as the primary strike")
 check(fx.effects.any(func(effect):return effect.kind=="shin_combo" and is_equal_approx(effect.scale*fx.SHIN_COMBO_SIZE_PIXELS*fx.CONTACT_PIXEL_SIZE,preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER)),
       "The configured larger splash retains its independent slime-sized visual baseline")
 army.flush_presentation()
 step_player(9)
 var burst=fx.batches.shin_combo.multimesh.get_instance_transform(0).basis
 check(is_equal_approx(burst.x.length()/burst.y.length(),1.0),"連擊 preserves the prepared sprite proportions")
 await capture("Sword Combo splash.png")
 kit.cancel()
 game.reset_character_tuning(Roster.SHIN_ID)
 wall.free()
 for target in targets:
  army.despawn(target.handle)
  game.model.enemies.erase(target.forest_id)

func verify_two_birds(home:Vector3):
 var p=game.player
 var kit=p.active_ability
 var army=game.army_runtime
 var fx=game.crowd.army.presentation
 home=Vector3(-80,0,125)
 home.y=game.model.surface_height(home.x,home.z)+.05
 p.swap_weapon()
 kit.clear_cooldowns();p.attack_chain.reset()
 settle(home)
 game.forest_ui.message_left=0
 game.forest_ui.sync()
 check(game.forest_ui.loadout_buttons[2].visible and game.forest_ui.loadout_buttons[2].tooltip_text.contains("一石二鳥"),
       "The polearm hotbar shows 一石二鳥 on key 3")
 press(KEY_3)
 step_player(120)
 check(not kit.is_attacking() and not fx.effects.any(func(effect):return effect.kind.begins_with("shin_two_birds")),
       "A missed front strike never releases the rear wave")
 kit.clear_cooldowns()
 var front_pos=home+Vector3.FORWARD*14+Vector3.RIGHT*3
 var targets:Array[Ninja]=[]
 for i in 34:
  var point=front_pos
  if i in range(1,31):point+=Vector3(((i-1)%5-2)*8,0,-12-floori((i-1)/5.0)*7)
  elif i>30:point+=[Vector3(23,0,-7),Vector3(0,0,-59),Vector3(-21,0,-18)][i-31]
  point.y=game.model.surface_height(point.x,point.z)
  var row=game.model.waves.spawn_enemy(Roles.SLIME,point,-1,0)
  row.hp=12000.0;row.max_hp=row.hp
  army.import_arrivals()
  targets.append(game.actors[row.id])
 var wall=StaticBody3D.new()
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.85,8,.75)
 shape.shape=box;wall.add_child(shape);game.add_child(wall)
 wall.position=front_pos+Vector3(-10.5,3,-9)
 await physics_frame;await physics_frame
 army.sync_targets()
 game.crowd.present_army(army.render_snapshot(),[])
 game.camera_rig.camera.global_position=home+Vector3(0,38,33)
 game.camera_rig.camera.look_at(home+Vector3(0,1,-31))
 victims.clear()
 press(KEY_3)
 check(kit.ticket.action=="shin_two_birds" and kit.shin_sure_cooldown==0 and p.model.combo_glow.visible and game.last_sound_voice.get_meta("kind")=="cg_shin_two_birds_charge","一石二鳥 starts its own charge and cooldown")
 var swing_heard=false
 for i in 100:
  step_player(1)
  if not victims.is_empty():break
  if game.last_sound_voice.stream==kit.shin_sound(false):swing_heard=true
 check(swing_heard,"一石二鳥 plays the original spear swing before contact")
 check(victims==[targets[0]] and is_equal_approx(army.unit_state(targets[0].handle).hp,8250),"The first hit reaches a front slime 14 m away and 3 m off center")
 check(game.voices.any(func(voice):return voice.stream==kit.shin_sound(true) and voice.playing),"一石二鳥 plays the original spear contact sample")
 check(game.voices.any(func(voice):return voice.stream==SoundLibrary.SHIN_TWO_BIRDS_IMPACT),"The front impact plays the recovered cue 255")
 step_player(12)
 check(victims==[targets[0]],"The rear impact follows on a separate beat")
 for i in 100:
  step_player(1)
  if victims.size()>1:break
 print("SHIN_TWO_BIRDS rear_hits=",victims.size()-1," player_step_ms=",samples.back()*.001," mode=",kit.mode," elapsed=",kit.elapsed," duration=",kit.duration," state=",kit.state)
 check(victims.size()==31 and targets.slice(0,31).all(func(target):return victims.count(target)==1),
       "The rear fan hits 30 slimes once and excludes flank, cover and excess range")
 check(targets.slice(1,31).all(func(target):return is_equal_approx(army.unit_state(target.handle).hp,3000)),
       "Every rear target takes 9,000 damage")
 check(fx.effects.filter(func(effect):return effect.kind=="shin_two_birds" and effect.rear).size()==3,"The rear wave draws three large recovered bursts")
 army.flush_presentation()
 check(fx.labels.filter(func(label):return label.visible and label.text=="9000").size()==30,"The rear wave shows damage on all 30 slimes")
 step_player(9)
 await capture("Two Birds rear impact.png")
 kit.cancel()
 wall.free()
 for target in targets:
  army.despawn(target.handle)
  game.model.enemies.erase(target.forest_id)
