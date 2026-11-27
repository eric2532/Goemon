extends "res://scripts/crossgate_combat.gd"
## Maze uses the shared sword contact and the recovered Blue Cross Gate throw.
const DAGGER_RANGE=preload("res://scripts/recovered_enemy_projectile.gd").THROWN_RANGE
const DAGGER_SPEED=preload("res://scripts/recovered_enemy_projectile.gd").THROWN_SPEED
const FIST_SWING=preload("res://assets/audio/crossgate/hounds/cgply00a.wav")
const FIST_CONTACT=preload("res://assets/audio/crossgate/kazi/cgply10a.wav")
const BLADE_DANCE_SHOTS=6
const BladeDance=preload("res://scripts/spells/spell_catalog.gd")
const Weapon=preload("res://scripts/rogue_roster.gd").MazeWeapon
const ASSASSINATION="maze_assassination"
const ASSASSINATION_RANGE=COMBO_START_RANGE*3.0
const ASSASSINATION_SPEED=2.0
const ASSASSINATION_MAX_SPEED=20.0
const ASSASSINATION_FRAME_TIME=COMBO_CHARGE_FRAME_TIME/ASSASSINATION_SPEED
const ASSASSINATION_CHARGE=COMBO_CHARGE_FRAMES*ASSASSINATION_FRAME_TIME
const ASSASSINATION_BEAT=30.0/60/ASSASSINATION_SPEED
const ASSASSINATION_APPEAR=ASSASSINATION_CHARGE+2*ASSASSINATION_BEAT
const ASSASSINATION_PASS_START=ASSASSINATION_APPEAR+2*ASSASSINATION_BEAT
const ASSASSINATION_PASS_TIME=16.0/60/ASSASSINATION_SPEED
const ASSASSINATION_FINISH=ASSASSINATION_PASS_START+ASSASSINATION_PASS_TIME
const ASSASSINATION_LABEL_TIME=1.15/ASSASSINATION_SPEED
const ASSASSINATION_MIN_LABEL_TIME=.12
var throw_release=0.0
var assassination_enabled=false
var assassination_rate=1.0
var assassination_origin=Vector3.ZERO
var assassination_facing=Vector3.FORWARD
var assassination_rear=Vector3.ZERO
var assassination_exit=Vector3.ZERO

func guard_threat()->int:
 if is_attacking() and clip=="7" and elapsed<throw_release:return hero.crossgate_attack_serial
 return super.guard_threat()

func prepare_projectiles():
 if hero.model.gear_external:
  super.prepare_projectiles();return
 var throw_duration:float=hero.model.appearance.clips["7:0"].duration
 var in_flight=ceili(dagger_range()/DAGGER_SPEED/throw_duration)*int(hero.model.fighter.get("kunai_count",1))
 if hero.model.combo_glow!=null:
  in_flight+=int(Skills.effective(hero,hero.RogueRoster.crossgate_profile(hero.character_id).id+"/blade-dance","count"))
 Pool.service(game).warm(hero,Shot,"maze_dagger",{"kind":"maze_dagger"},in_flight)

func input(event:InputEvent):
 if not hero.model.beast_master and not hero.model.gear_external and event.is_action_pressed("equip") and not event.is_echo():
  if hero.model.daggers:start_blade_dance()
  elif hero.model.maze_weapon==Weapon.KATANA and active and not hero.ai_controlled and not is_attacking() and hero.dodge_time<=0:
   start_assassination()
  return
 super.input(event)

func use_stance_skill()->bool:
 if not is_instance_valid(hero.ai_target) or hero.ai_target.dead or combo_cooldown>0:return false
 if hero.model.daggers:start_blade_dance()
 else:start_assassination(hero.ai_target)
 if not is_attacking():return false
 combo_cooldown=COMBO_COOLDOWN
 return true

func start_blade_dance():
 if not active or hero.model.combo_glow==null or not hero.model.daggers or hero.dodge_time>0 or (is_attacking() and not primary_hit_can_link_skill()) or mode=="dead" or hero.hp<=0 or combo_cooldown>0:return
 if not hero.spend_skill_mana("maze/blade-dance"):return
 prepare_attack_pose(hero.facing)
 ticket=hero.attack_chain.begin(BladeDance.BLADE_DANCE)
 var speed=hero.spell_loadout.primary_combo_cast_speed()
 if speed>1.0:ticket.shin_cast_speed=speed
 link_primary_combo()
 clip="6"
 duration=COMBO_CHARGE_FRAMES*COMBO_CHARGE_FRAME_TIME
 hero.attack_duration=duration;hero.attack_left=duration
 var glow:Sprite3D=hero.model.combo_glow
 ShineTiers.physical_shine(glow,ticket)
 glow.scale=Vector3.ONE*Skills.shine_factor(ticket)
 glow.frame=0
 glow.modulate.a=.35 if game.settings.get("reduced_flashes",false) else 1.0
 glow.show()
 hero.play_sound("cg_blade_dance_charge",.8,ticket)

func assassinating()->bool:
 return is_attacking() and ticket.get("action","")==ASSASSINATION

func protects_player()->bool:
 return assassinating() or super.protects_player()

func blocks_movement()->bool:
 return assassinating()

func cancel(preserve_power:bool=false):
 if clip=="6":hero.model.combo_glow.hide()
 if assassinating():
  hero.model.combo_glow.hide()
  hero.model.clear_kagerou_dodge()
  var sprite:Sprite3D=hero.model.sprite
  sprite.show()
  sprite.modulate.a=1.0
  sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
  if marker>=2:
   var home=Transform3D(hero.global_basis,assassination_origin)
   if not hero.test_move(home,Vector3.ZERO):
    hero.global_position=assassination_origin
  face_dagger(assassination_facing)
  hero.model.show_pose(0,0.0,false)
  hero.reset_physics_interpolation()
 if not preserve_power:assassination_enabled=false
 super.cancel(preserve_power)

func disable_assassination():
 assassination_enabled=false
 if assassinating():cancel(true)

func swap_weapon():
 if not active or hero.hp<=0 or assassinating() or (is_attacking() and clip=="5"):return
 var primary:int=hero.model.primary_throwing_weapon
 var order=[primary,1-primary,Weapon.FIST]
 set_weapon(order[(order.find(hero.model.maze_weapon)+1)%order.size()])
 if not hero.ai_controlled:game.save_skin_equipment(hero.character_id,{"weapon":hero.model.maze_weapon})

func set_weapon(weapon:int):
 if weapon==hero.model.maze_weapon:return
 primary_hold_target=null
 stop_primary_approach()
 if clip=="7" and state.has("primary_target"):cancel(true)
 if is_attacking() and clip=="5":cancel(true)
 disable_assassination()
 hero.model.set_maze_weapon(weapon)
 hero.spell_loadout.refresh_numbered_slots()

func start_assassination(target:Ninja=null):
 if hero.model.current_weapon()!="sword":return
 if is_attacking() or mode=="dead" or hero.hp<=0:return
 var hop=next_combo_hop({},ASSASSINATION_RANGE,target,true)
 if hop.is_empty():return
 if not hero.spend_skill_mana("maze/assassination"):return
 prepare_attack_pose(hero.facing)
 ticket=hero.attack_chain.begin(ASSASSINATION)
 ticket.responsive_recoil=true
 ticket.quiet_contact=true
 fire_target=weakref(hop.enemy)
 assassination_origin=hero.global_position
 assassination_facing=hero.facing
 hero.velocity=Vector3.ZERO
 hero.jump_buffer=0.0
 hero.model.clear_kagerou_dodge()
 hero.model.show()
 clip="0"
 hero.model.show_pose(0,0.0,false)
 assassination_rate=hero.attack_chain.maze_assassination_rate
 duration=ASSASSINATION_FINISH/assassination_rate+maxf(ASSASSINATION_MIN_LABEL_TIME,ASSASSINATION_LABEL_TIME/assassination_rate)
 hero.attack_duration=duration;hero.attack_left=duration
 var glow:Sprite3D=hero.model.combo_glow
 ShineTiers.physical_shine(glow,ticket)
 glow.scale=Vector3.ONE*Skills.shine_factor(ticket)
 glow.frame=0
 glow.modulate.a=.35 if game.settings.get("reduced_flashes",false) else 1.0
 glow.show()
 hero.play_sound("cg_assassination_charge",.8,ticket)

func advance_assassination(delta:float):
 elapsed+=delta
 hero.attack_left=maxf(0,duration-elapsed)
 var animation_time=elapsed*assassination_rate
 var sprite:Sprite3D=hero.model.sprite
 var target:Ninja=fire_target.get_ref()
 if marker==0 and animation_time>=ASSASSINATION_CHARGE:
  marker=1
  hero.model.combo_glow.hide()
  sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
  hero.play_sound("maze_assassination_vanish",.8,ticket)
 if animation_time<ASSASSINATION_APPEAR:
  if marker==0:hero.model.combo_glow.frame=ShineTiers.charge_frame(ticket,animation_time/ASSASSINATION_FRAME_TIME,9,12)
  else:
   sprite.modulate.a=.5
   sprite.visible=animation_time<ASSASSINATION_CHARGE+ASSASSINATION_BEAT
  return
 if marker==1:
  if not is_instance_valid(target) or target.dead:
   cancel(true)
   return
  var hop=next_combo_hop({},ASSASSINATION_RANGE,target,true)
  if hop.is_empty():
   cancel(true)
   return
  marker=2
  assassination_rear=hop.position
  assassination_exit=hop.exit
  hero.global_position=assassination_rear
  hero.reset_physics_interpolation()
  face_dagger(assassination_exit-assassination_rear)
  hero.model.show_pose(0,0.0,false)
  sprite.modulate.a=.5
  sprite.show()
 if marker==2 and animation_time>=ASSASSINATION_APPEAR+ASSASSINATION_BEAT:
  sprite.modulate.a=1.0
  sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
 if animation_time<ASSASSINATION_PASS_START:return
 if marker==2:
  if not is_instance_valid(target) or target.dead:cancel(true);return
  assassination_exit=combo_pass_exit(assassination_rear,target,(target.global_position-assassination_rear).normalized())
  if not assassination_exit.is_finite():cancel(true);return
  marker=3;clip="5"
  face_dagger(target.global_position-assassination_rear)
  state.assassination_pattern=hero.model.normal_attack_pattern()
  state.assassination_contact=0;state.assassination_sound=0;state.assassination_killed=false
  state.assassination_label=target.global_position+Vector3.UP*2.8
  sprite.modulate.a=1.0;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
  duration=(ASSASSINATION_PASS_START+state.assassination_pattern.duration+ASSASSINATION_PASS_TIME)/assassination_rate+maxf(ASSASSINATION_MIN_LABEL_TIME,ASSASSINATION_LABEL_TIME/assassination_rate)
  hero.attack_duration=duration
 var attack_time=animation_time-ASSASSINATION_PASS_START
 var pattern:Dictionary=state.assassination_pattern
 if marker==3:
  hero.model.show_pose(pattern.pose,minf(attack_time,pattern.duration),false)
  while state.assassination_sound<pattern.sounds.size() and attack_time>=float(pattern.sounds[state.assassination_sound]):
   state.assassination_sound+=1;hero.play_sound("swing",.8,ticket,shin_sound(false,state.assassination_sound-1))
  while state.assassination_contact<pattern.contacts.size() and attack_time>=float(pattern.contacts[state.assassination_contact]):
   state.assassination_contact+=1
   if not is_instance_valid(target) or target.dead:continue
   hero.play_sound("maze_assassination_strike",.8,ticket)
   strike(Vector3.UP,Vector3(0,1,-CUT_REACH),CUT_RADIUS*hero.model.basis.get_scale().x,DAMAGE_SCALE/pattern.contacts.size(),-1.0,Vector3.INF,0,CUT_SWEEP,null,{"target":target,"ticket":ticket})
   if target.dead and target!=game.get("training_dummy"):
    state.assassination_killed=true
    hero.attack_chain.maze_assassination_rate=minf(ASSASSINATION_MAX_SPEED/ASSASSINATION_SPEED,assassination_rate*2.0)
  if attack_time<pattern.duration:return
  marker=4;clip="3"
  face_dagger(assassination_exit-assassination_rear)
  hero.model.show_kagerou_dash(assassination_exit-assassination_rear)
  hero.play_sound("maze_assassination_arrive",.8,ticket)
 if marker==4:
  var travel=attack_time-pattern.duration
  hero.global_position=assassination_rear.lerp(assassination_exit,clampf(travel/ASSASSINATION_PASS_TIME,0.0,1.0))
  if travel<ASSASSINATION_PASS_TIME:
   hero.model.show_pose(3,travel*ASSASSINATION_SPEED,true)
   return
  marker=5;clip="0";hero.model.clear_kagerou_dodge();hero.model.show_pose(0,0.0,false)
  if not state.assassination_killed or game.get("crowd")==null:cancel(true);return
  var label_time=maxf(ASSASSINATION_MIN_LABEL_TIME,ASSASSINATION_LABEL_TIME/assassination_rate)
  duration=elapsed+label_time;hero.attack_duration=duration;hero.attack_left=label_time
  game.crowd.army.presentation.add_effect(ASSASSINATION,state.assassination_label,label_time,2.1*skill_factor("size",ticket))
 if elapsed>=duration:cancel(true)

func is_throwing_kunai()->bool:
 return not hero.model.gear_external and ((clip=="6" and not assassinating()) or clip=="7")

func ground_attack_velocity()->Vector3:
 return Vector3.INF if is_throwing_kunai() and not state.has("approach_velocity") else super.ground_attack_velocity()

func start_attack(heavy:bool=false,allow_accessories:bool=true):
 if is_attacking() or mode=="dead" or hero.hp<=0:return
 if not hero.model.daggers:
  super.start_attack(heavy,allow_accessories)
  return
 if allow_accessories and spell_owner==null and hero.spell_loadout.accessory_attack():return
 start_basic_attack(hero.facing)
 begin_combined_power(locked_primary_enemy())

func start_basic_attack(direction:Vector3,selected:Ninja=null):
 if not hero.model.daggers:
  super.start_basic_attack(direction,selected)
  return
 if mode=="primary_approach":cancel(true)
 face_dagger(direction)
 ticket=hero.attack_chain.begin("maze_dagger","",hero.model.beast_master)
 prepare_primary_combo(ticket)
 start_dagger_throw(selected)

func start_dagger_throw(selected:Ninja=null):
 prepare_attack_pose(hero.facing)
 ticket.crossgate_sound_source=hero.character_id
 if ticket.action!=BladeDance.BLADE_DANCE:lock_dagger_target(selected)
 clip="7"
 var throw_pose:Dictionary=hero.model.appearance.clips["7:%d"%hero.model.direction()]
 duration=float(throw_pose.duration)
 if ticket.action=="maze_dagger":ticket.normal_attack_damage=Skills.basic_damage(hero.model.normal_attack_pattern(),hero)
 throw_release=duration*int(hero.model.appearance.release_frame)/throw_pose.frames.size()
 hero.attack_duration=duration;hero.attack_left=duration

func lock_dagger_target(selected:Ninja=null):
 fire_target=null
 var origin=hero.auto_aim_origin()
 var target=selected if selected!=null else AttackChain.nearest_visible_target(hero,origin,dagger_range())
 if target!=null:
  fire_target=weakref(target)
  face_dagger(AttackChain.aim_point(target,origin)-origin)

func advance_attack(delta:float):
 if hero.model.gear_external:
  super.advance_attack(delta);return
 if assassinating():
  advance_assassination(delta)
  return
 if clip=="6":
  elapsed+=delta*float(ticket.get("shin_cast_speed",1.0))
  hero.attack_left=maxf(0,duration-elapsed)
  if elapsed+.00001<duration:
   hero.model.combo_glow.frame=ShineTiers.charge_frame(ticket,elapsed/COMBO_CHARGE_FRAME_TIME,9,12)
  else:
   hero.model.combo_glow.hide()
   start_dagger_throw()
  return
 if clip!="7":
  super.advance_attack(delta)
  return
 if controls_primary_facing() and not track_primary_windup(delta):return
 elapsed+=delta*primary_attack_tempo()
 hero.attack_left=maxf(0,duration-elapsed)
 if marker==0 and elapsed>=throw_release:
  marker=1
  state.primary_committed=true
  if ticket.action==BladeDance.BLADE_DANCE:throw_blade_dance()
  else:throw_dagger()
  combined_contact()
 if elapsed>=duration:
  if hero.combined_power_busy():finish_primary_swing()
  else:cancel(true)

func face_dagger(direction:Vector3):
 var flat=Vector3(direction.x,0,direction.z)
 if flat.length_squared()<=.0001:return
 hero.facing=flat.normalized()
 hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)

func dagger_range()->float:return DAGGER_RANGE*hero.pickup_multiplier("range")*float(hero.accessory_bonuses.get("range",1.0))

func throw_dagger():
 var origin=hero.auto_aim_origin()
 var direction=hero.facing
 var target=fire_target.get_ref() if fire_target!=null else null
 if is_instance_valid(target) and not target.dead:
  var offset=AttackChain.aim_point(target,origin)-origin
  if offset.length_squared()>.0001:direction=offset.normalized()
 face_dagger(direction)
 hero.play_sound("cg_dagger_throw",.8,ticket)
 var count:int=1 if hero.model.beast_master else hero.model.fighter.get("kunai_count",1)
 var second_target=target
 if count>1:
  var closest=dagger_range()*dagger_range()
  for enemy in AttackChain.enemy_candidates(game,origin,dagger_range()):
   if not is_instance_valid(enemy) or enemy.dead or enemy==target:continue
   if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
   var point=AttackChain.aim_point(enemy,origin)
   var distance=origin.distance_squared_to(point)
   if distance>closest or not AttackChain.clear_line(hero,origin,point):continue
   closest=distance;second_target=enemy
  if not is_instance_valid(target) or target.dead:target=second_target
 var side=direction.cross(Vector3.UP).normalized()
 var volley_ticket=ticket.duplicate()
 if volley_ticket.has("sure_strike_damage"):volley_ticket.sure_strike_damage/=count
 for i in count:
  var start=origin+side*(i-(count-1)*.5)*.6
  var aim_target=target if i==0 else second_target
  var shot_direction=direction
  if is_instance_valid(aim_target) and not aim_target.dead:
   var offset=AttackChain.aim_point(aim_target,start)-start
   if offset.length_squared()>.0001:shot_direction=offset.normalized()
  launch_dagger(start,shot_direction,volley_ticket,weakref(aim_target) if count>1 and is_instance_valid(aim_target) and not aim_target.dead else null)

func throw_blade_dance():
 var origin:Vector3=hero.auto_aim_origin()
 var reach=dagger_range()
 var candidates=[]
 for enemy in AttackChain.enemy_candidates(game,origin,reach):
  if not is_instance_valid(enemy) or enemy.dead:continue
  var offset=AttackChain.aim_point(enemy,origin)-origin
  var distance=offset.length_squared()
  if distance>reach*reach:continue
  candidates.append([distance,enemy.get_instance_id(),enemy,offset])
 candidates.sort_custom(func(a,b):return a[1]<b[1] if a[0]==b[0] else a[0]<b[0])
 var volley_ticket=ticket.duplicate()
 var count=0
 for row in candidates:
  var enemy:Ninja=row[2]
  if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
  var offset:Vector3=row[3]
  if not AttackChain.clear_line(hero,origin,origin+offset):continue
  var direction=hero.facing if offset.is_zero_approx() else offset.normalized()
  if count==0:
   face_dagger(direction)
   combo_cooldown=COMBO_COOLDOWN
   hero.play_sound("cg_dagger_throw",.8,ticket)
  launch_dagger(origin,direction,volley_ticket,weakref(enemy))
  count+=1
  if count==skill_count(BLADE_DANCE_SHOTS,ticket):break

func launch_dagger(origin:Vector3,direction:Vector3,attack_ticket:Dictionary,target:WeakRef=null):
 var damage_scale=hero.base_character_attack_multiplier() if attack_ticket.get("base_damage_only",false) else hero.damage_multiplier()
 Pool.service(game).launch(hero,Shot,"maze_dagger",{"position":origin,"velocity":direction*DAGGER_SPEED,"lifetime":dagger_range()/DAGGER_SPEED,"damage":float(attack_ticket.get("sure_strike_damage",attack_ticket.get("normal_attack_damage",250.0)))*damage_scale,"attack_ticket":attack_ticket,"target":target})

func strike_cut():
 if hero.model.maze_weapon!=Weapon.FIST:
  super.strike_cut()
  return
 strike(Vector3(0,1,0),Vector3(0,1,-SHIN_PUNCH_REACH),CUT_RADIUS*cast_model().basis.get_scale().x,DAMAGE_SCALE,-1.0,Vector3.INF,1,[],shin_sound(true))

func primary_melee_length()->float:
 if not hero.model.gear_external and hero.model.maze_weapon==Weapon.FIST:return SHIN_PUNCH_REACH
 return super.primary_melee_length()

func melee_visual_reach()->float:
 if hero.model.daggers:return 0.0
 if hero.model.maze_weapon==Weapon.FIST:return (SHIN_PUNCH_REACH+CUT_RADIUS)*cast_model().basis.get_scale().x*hero.melee_range_multiplier()
 return super.melee_visual_reach()
