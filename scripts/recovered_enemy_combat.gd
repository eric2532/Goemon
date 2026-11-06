extends "res://scripts/character_combat.gd"
## Player input adapter; NPCs remain exclusively owned by the native army.
const Dark=preload("res://scripts/forest/dark_lumina_kit.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Visual=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const Soldier=preload("res://scripts/forest/forest_thirstquencher_combat.gd")
const Shot=preload("res://scripts/recovered_enemy_projectile.gd")
const Presentation=preload("res://scripts/forest/crowd/army_presentation.gd")
const Sand=preload("res://scripts/forest/skullpion_effects.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const LEAP_SPEED=Dark.LEAP_SPEED
const LEAP_TRAVEL_SPEED=260.0
const LEAP_RISE_GRAVITY=Dark.LEAP_RISE_GRAVITY
const LEAP_FALL_GRAVITY=Dark.LEAP_FALL_GRAVITY
const DRILL_TEMPO=10.0
const DRILL_RANGE=25.0*Roles.BOSS_SCALE
var role=0
var clip=""
var pose_tick=0.0
var elapsed=0.0
var duration=0.0
var mode=""
var state={}
var hits={}
var ticket={}
var action=0
var marker=0
var reaction=0.0
var captured:WeakRef
var fire_target:WeakRef
var aim=Vector3.ZERO
var jump_started=false

func prepare_projectiles():
 if role==Dark.ROLE:
  Dark.prepare();Pool.service(game).warm(hero,Shot,"dark_lumina",{"kind":"dark_lumina"},36)
 if role==1:Pool.service(game).warm(hero,Shot,"soldier",{},12)

func release_input(event:InputEvent):
 if event.is_action_released("light_attack") and role==Roles.BOSS and is_attacking() and action==103:cancel()

func input(event:InputEvent):
 release_input(event)
 if not active or event.is_echo() or hero.dodge_time>0:return
 if role==Dark.ROLE:
  for key in {"equip":Dark.FIRE,"surge":Dark.SLAM,"sky_strike":Dark.SPIN}:
   if event.is_action_pressed(key):start_dark_attack({"equip":Dark.FIRE,"surge":Dark.SLAM,"sky_strike":Dark.SPIN}[key]);return
 if role==Roles.BOSS and event.is_action_pressed("equip"):start_skull_attack(102);return
 if role==Roles.BOSS and event.is_action_pressed("surge"):start_skull_attack(105);return
 if event.is_action_pressed("light_attack") or event.is_action_pressed("heavy_attack"):
  start_attack(event.is_action_pressed("heavy_attack"))
  if role==Roles.BOSS and is_attacking() and action==103:state.sand_held=true

func start_attack(heavy:bool=false):
 if role==Dark.ROLE:start_dark_attack(Dark.SLAM if heavy else Dark.CLAW);return
 if role==Roles.BOSS:start_skull_attack(104 if heavy else 103);return
 if is_attacking() or hero.hp<=0:return
 hero.facing=hero.combat_attack_direction()
 hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)
 elapsed=0;pose_tick=0;hits.clear();marker=0;mode="attack";reaction=0
 ticket=hero.attack_chain.begin("enemy_primary")
 if role in [0,1,3]:
  state={"variant":role};Soldier.begin(state);clip=state.soldier_clip;duration=4.0
 else:
  var semantic:Dictionary=Visual.data(role).get_meta("semantics")
  var value=semantic[Roles.ATTACKS[role].clip];clip=value[0] if value is Array else value
  duration=float(Visual.data(role).get_meta("clips")[clip].ticks)/30.0
 hero.attack_duration=duration;hero.attack_left=duration

func start_skull_attack(which:int):
 if role!=Roles.BOSS or is_attacking() or hero.hp<=0:return
 if which in [104,105] and not hero.is_on_floor():return
 hero.facing=hero.combat_attack_direction();cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
 elapsed=0;pose_tick=0;hits.clear();state.clear();marker=0;reaction=0;jump_started=false
 mode="attack";action=which;clip=cast_model().skull.CLIPS[action]
 duration={102:3.3,103:4.67,104:2.6,105:4.67}[action]
 ticket=hero.attack_chain.begin("skullpion_drill" if action==105 else "skullpion_sand" if action==103 else "enemy_primary")
 hero.attack_duration=(duration-Sand.SAND_START+Sand.SAND_START/Sand.SAND_TEMPO) if action==103 else duration/(DRILL_TEMPO if action==105 else 3.0 if action==102 else 1.0);hero.attack_left=hero.attack_duration
 if action==105:aim=Vector3.INF
 if action==104:hero.velocity.y=LEAP_SPEED*sqrt(hero.combat_tuning("jump_height"))*hero.progression.jump_velocity_multiplier();hero.jumps_used=1;hero.coyote=0

func step_leap(delta:float,direction:Vector3):
 if hero.is_on_floor() and hero.velocity.y<=0:return
 if role==Dark.ROLE and is_attacking() and action==Dark.SLAM and jump_started and marker==0 and pose_tick>=38:
  hero.velocity=Vector3(0,minf(hero.velocity.y,-LEAP_SPEED),0)
 # Keep the full-size body fast in the air; CharacterBody still sweeps castle collisions.
 if hero.wall_jump_recovery<=0 and not (role==Dark.ROLE and is_attacking() and action==Dark.SLAM and jump_started and pose_tick>=38):
  var motion=Vector2(hero.velocity.x,hero.velocity.z).move_toward(Vector2(direction.x,direction.z)*LEAP_TRAVEL_SPEED,1200.0*delta)
  hero.velocity.x=motion.x;hero.velocity.z=motion.y
 if not hero.is_on_floor():hero.velocity.y-=(LEAP_RISE_GRAVITY if hero.velocity.y>0 else LEAP_FALL_GRAVITY)*delta

func tick_timers(delta:float):
 reaction=maxf(0,reaction-delta)
 if mode=="hurt":
  pose_tick+=delta*30
  if reaction<=0:cancel()

func tick(delta:float,after_pose:bool=false):
 if after_pose:return
 if spell_owner==null and not is_attacking() and hero.auto_attack_running():start_attack()
 if not is_attacking():return
 var tempo=(DRILL_TEMPO if action==105 else 3.0 if action==102 else 1.0) if role==Roles.BOSS else Dark.CLAW_TEMPO if role==Dark.ROLE and action in [Dark.CLAW,Dark.GRAB] else Dark.FIRE_TEMPO if role==Dark.ROLE and action==Dark.FIRE else 1.0
 var before=elapsed;var step=delta*hero.attack_speed_multiplier()*tempo
 elapsed=Sand.advance_sand(elapsed,step) if role==Roles.BOSS and action==103 else elapsed+step
 pose_tick=elapsed*30
 hero.attack_left=maxf(0,duration-elapsed)/tempo
 if role==Roles.BOSS and action==103:
  hero.attack_left=maxf(0,Sand.SAND_START-elapsed)/Sand.SAND_TEMPO+maxf(0,duration-maxf(Sand.SAND_START,elapsed))
  if state.get("sand_held",false):hero.attack_left=maxf(.05,hero.attack_left)
 if role==Dark.ROLE:
  dark_step(before)
 elif role in [0,1,3]:
  for event in Soldier.advance(state,elapsed-before):
   if event.kind=="melee":hits.clear();strike(Visual.source_point(event.local_from),Visual.source_point(event.local_to),.576)
   elif event.kind=="bullet":shoot()
  clip=state.soldier_clip;pose_tick=state.soldier_tick
  if not Soldier.active(state):cancel(true)
 elif role==Roles.BOSS:
  if action==104:
   if not hero.is_on_floor():jump_started=true
   if marker==0:
    if jump_started and hero.is_on_floor():
     strike(Vector3(0,.8,0),Vector3(0,.8,0),8.0*Roles.BOSS_SCALE);marker=1;elapsed=1.65;duration=1.85
    else:elapsed=minf(elapsed,1.64)
    pose_tick=elapsed*30
  elif action==105:
   while marker<3 and elapsed>=1.9+marker*.9:
    aim=skull_drill_point();hits.clear()
    if aim.is_finite():strike(Vector3(0,.8,0),Vector3(0,.8,0),3.8*Roles.BOSS_SCALE,.65,-1,aim)
    marker+=1
  elif action==103:
   skull_sand_step()
  else:
   var markers=[.5,1.17,1.7,2.0,2.3,2.6]
   while marker<markers.size() and elapsed>=markers[marker]:
    hits.clear()
    strike(Vector3(0,.8,0),Vector3(0,.8,0),(6.5 if marker<2 else 13.5)*Roles.BOSS_SCALE)
    marker+=1
  var skull=cast_model().skull
  var drill_ready=action!=105 or aim.is_finite()
  skull.cue_point=aim if action==105 and drill_ready else hero.global_position
  var shown=Sand.SAND_START+fposmod(elapsed-Sand.SAND_START,Sand.SAND_END-Sand.SAND_START) if action==103 and state.get("sand_held",false) and elapsed>=Sand.SAND_START else elapsed
  if action==103:pose_tick=shown*30
  skull.effects.sync(action if drill_ready else 100,shown,skull.cue_point,action!=103)
  if action==103 and skull.sand.visible:skull_sand_path()
  # Hero's physical landing owns stomp audio; keep the timed dust burst only.
  if drill_ready or elapsed<1.9:skull.presentation_events(action,elapsed,action!=104,state.get("sand_held",false))
  skull.last_action=action;skull.last_time=elapsed
 else:
  var pattern:Dictionary=Roles.ATTACKS[role]
  if elapsed*30>=pattern.contact and before*30<float(pattern.get("contact_end",pattern.contact+1)):
   strike(Visual.source_point(pattern.from),Visual.source_point(pattern.to),.42)
 if elapsed>=duration and not (role==Roles.BOSS and action==103 and state.get("sand_held",false)):cancel(true)

func skull_sand_path()->Vector3:
 hero.facing=hero.combat_attack_direction();cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
 var skull=cast_model().skull
 var origin=skull.global_transform*Sand.SAND_ORIGIN
 var direction=(hero.ai_aim-origin).normalized() if hero.ai_controlled else game.projectile_direction(origin) if game.has_method("projectile_direction") else hero.facing
 if direction.length_squared()<.0001:direction=hero.facing
 direction=direction.normalized()
 var reach=Sand.SAND_LENGTH*hero.growth_multiplier()*hero.pickup_multiplier("range")
 var wall=AttackChain.world_ray(hero,origin,origin+direction*reach,1,[hero.get_rid()])
 if not wall.is_empty():reach=minf(reach,origin.distance_to(wall.position))
 skull.effects.sand_path(origin,direction,reach,Sand.SAND_RADIUS*hero.growth_multiplier())
 return origin+direction*reach

func skull_sand_step():
 var until=elapsed if state.get("sand_held",false) else minf(elapsed,Sand.SAND_END-.000001)
 while until+.000001>=Sand.SAND_START+marker*Sand.SAND_INTERVAL:
  marker+=1
  var end=skull_sand_path()
  var origin=cast_model().skull.sand.global_position
  var radius=Sand.SAND_RADIUS*hero.growth_multiplier()*skill_factor("hit_area",ticket)
  AttackChain.beam_pulse(hero,hero,origin,end,radius,radius*hero.pickup_multiplier("range"),Roles.stats(role).damage*.35*hero.damage_multiplier(),ticket,source_id())

func skull_drill_point()->Vector3:
 var origin=hero.global_position+Vector3.UP*.8
 var nearest=DRILL_RANGE*DRILL_RANGE*hero.melee_range_multiplier()*hero.melee_range_multiplier()
 var result=Vector3.INF
 # Query the existing local snapshot only at each of the three emergence markers.
 for enemy in AttackChain.enemy_candidates(game,origin,DRILL_RANGE*hero.melee_range_multiplier()):
  if not is_instance_valid(enemy) or enemy.dead:continue
  if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
  var point=AttackChain.aim_point(enemy,origin);var distance=origin.distance_squared_to(point)
  if distance>=nearest or not AttackChain.clear_line(hero,origin,point):continue
  var ground=AttackChain.world_ray(hero,point+Vector3.UP*2,point-Vector3.UP*5)
  if ground.is_empty() or ground.normal.y<.5:continue
  nearest=distance;result=ground.position
 return result

func strike(from:Vector3,to:Vector3,radius:float,damage_scale:float=1.0,min_dot:float=-1.0,origin:Vector3=Vector3.INF):
 if role!=Dark.ROLE and hits.is_empty() and game.get("crowd")!=null and Presentation.MONSTER_SOUNDS.has(role):
  var sound=Presentation.MONSTER_SOUNDS[role].get("melee")
  if sound!=null:game.crowd.army.presentation.play_sound(hero.global_position,sound)
 var reach=hero.melee_range_multiplier()*skill_factor("hit_area",ticket)
 if role==Dark.ROLE:
  from*=Vector3(Dark.SCALE*Dark.ATTACK_RANGE,1,Dark.SCALE*Dark.ATTACK_RANGE);to*=Vector3(Dark.SCALE*Dark.ATTACK_RANGE,1,Dark.SCALE*Dark.ATTACK_RANGE);radius*=Dark.SCALE*Dark.ATTACK_RANGE
 var center=hero.global_position if not origin.is_finite() else origin
 var a=center+cast_model().basis*(from*reach);var b=center+cast_model().basis*(to*reach)
 if role==Dark.ROLE and action==Dark.CLAW:cast_model().pressure_trail.paint_arc(a,b,Vector3.UP,.55)
 for enemy in AttackChain.segment_enemy_candidates(game,a,b,radius*reach):
  if not is_instance_valid(enemy) or enemy.dead or hits.has(enemy.get_instance_id()):continue
  if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
  var contact=AttackChain.segment_contact(enemy,a,b,radius*reach)
  if role==Roles.BOSS and action==105 and absf(AttackChain.aim_point(enemy,a).y-a.y)>5:continue
  if min_dot> -1.0 and not contact.is_empty():
   var offset:Vector3=AttackChain.aim_point(enemy,a)-a
   if absf(offset.y)>5 or hero.facing.dot(Vector3(offset.x,0,offset.z).normalized())<min_dot:continue
  if contact.is_empty() or not AttackChain.clear_line(hero,a,AttackChain.aim_point(enemy,a)):continue
  hits[enemy.get_instance_id()]=true
  enemy.take_hit(Roles.stats(role).damage*hero.damage_multiplier()*damage_scale*(.25 if role==Dark.ROLE and action==Dark.CLAW else 1.0),hero.facing,role in [Roles.BOSS,Dark.ROLE],ticket)
  if role==Roles.BOSS and action==105 and enemy.has_method("apply_defense_slow"):enemy.apply_defense_slow(.55,4.0)
  if hero.ai_controlled:game.confirm_ally_impact(enemy,contact.point,hero.facing,1,false,source_id())
  else:game.confirm_impact(enemy,contact.point,hero.facing,1,false,source_id())
  if role==Dark.ROLE and action==Dark.CLAW:captured=weakref(enemy);break

func shoot():
 if game.get("crowd")!=null:game.crowd.army.presentation.gunshot(hero.global_position)
 Pool.service(game).launch(hero,Shot,"soldier",{"position":hero.global_position+cast_model().basis*Visual.source_point(Soldier.MUZZLE),"velocity":hero.facing*8.64,"damage":Roles.stats(role).damage*hero.damage_multiplier(),"attack_ticket":ticket.duplicate()})

func ground_attack_velocity()->Vector3:
 if not is_attacking():return Vector3.INF
 if role in [Roles.BOSS,Dark.ROLE] and (not hero.is_on_floor() or hero.velocity.y>0):return Vector3.INF
 if role==Dark.ROLE and action==Dark.CLAW and pose_tick<Dark.CLAW_TICK:
  var target=fire_target.get_ref() if fire_target!=null else null
  if is_instance_valid(target) and hero.global_position.distance_to(target.global_position)<=3.8*Dark.SCALE*Dark.ATTACK_RANGE*hero.melee_range_multiplier():return Vector3.ZERO
  return hero.facing*Roles.stats(role).speed*2*Dark.SCALE*Dark.CLAW_TEMPO
 if role==Roles.HAYA_WOLF and pose_tick>=Roles.ATTACKS[role].contact:return hero.facing*Roles.stats(role).speed*Roles.ATTACKS[role].travel
 return Vector3.ZERO
func blocks_movement()->bool:return false
func is_attacking()->bool:return mode=="attack"
func protects_player()->bool:return false
func interrupt_for_dodge():cancel(true)
func hit():
 cancel(true);mode="hurt";reaction=.3
 clip="801ae2c4" if role==Roles.BOSS else Dark.HURT_CLIP if role==Dark.ROLE else str(Visual.data(role).get_meta("semantics").hurt[0])
func cancel(_preserve_power:bool=false):
 if is_instance_valid(cast_model()) and cast_model().pressure_trail!=null:cast_model().pressure_trail.clear()
 if role==Dark.ROLE and is_inside_tree():
  if is_instance_valid(cast_model()):cast_model().body.rotation.y=0
  if spell_owner!=null and is_attacking() and action==Dark.SPIN:hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)
  if is_instance_valid(game) and game.get("crowd")!=null:game.crowd.army.presentation.cancel_dark_spin(get_instance_id())
 if role==Dark.ROLE and spell_owner!=null and jump_started and hero.character_id not in [27,29]:
  # A cancelled borrowed leap must not carry boss launch speed into ordinary gravity.
  hero.velocity=Vector3(0,minf(0,hero.velocity.y),0)
 if role==Roles.BOSS and is_instance_valid(cast_model()):
  var skull=cast_model().skull
  skull.effects.stop();skull.last_action=-1;skull.last_time=-1
  for voice in skull.voices:voice.stop()
 mode="";clip="";elapsed=0;pose_tick=0;aim=Vector3.ZERO;hits.clear();state.clear();captured=null;fire_target=null;jump_started=false;hero.attack_left=0

func dark_cue(cue:int):
 if game.get("crowd")!=null:game.crowd.army.presentation.dark_cue(hero.global_position,cue,cast_model().rotation.y,get_instance_id(),hero.attack_speed_multiplier(),state.get("spin_sign",1),not (cue==8 and spell_owner==null and state.get("landing_sound",false)),true,ticket)
func dark_sound(cue:String):
 if cue=="step":hero.play_sound("dark_lumina_2_step");return
 if game.get("crowd")!=null:game.crowd.army.presentation.dark_sound(hero.global_position,cue,true,ticket)
func start_dark_attack(which:int):
 if role!=Dark.ROLE or which not in [Dark.CLAW,Dark.FIRE,Dark.SLAM,Dark.SPIN] or is_attacking() or hero.hp<=0:return
 var previous_yaw=cast_model().rotation.y
 hero.facing=hero.combat_attack_direction();cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
 elapsed=0;pose_tick=0;hits.clear();marker=0;reaction=0;captured=null;fire_target=null;jump_started=false
 mode="attack";action=which;clip=Dark.CLIPS[action]
 state.clear()
 if which==Dark.SPIN:
  state.spin_sign=1 if wrapf(cast_model().rotation.y-previous_yaw,-PI,PI)<0 else -1
  clip=Dark.SPIN_CLIPS[0 if state.spin_sign==1 else 1]
 duration=float(Visual.data(role).get_meta("clips")[clip].ticks)/30
 ticket=hero.attack_chain.begin("dark_lumina");hero.attack_duration=duration/(Dark.CLAW_TEMPO if which==Dark.CLAW else Dark.FIRE_TEMPO if which==Dark.FIRE else 1.0);hero.attack_left=hero.attack_duration
 aim=hero.global_position+hero.facing*54*Dark.ATTACK_RANGE+Vector3.UP
 if which==Dark.CLAW:
  var target=AttackChain.nearest_contact(game,hero,hero.global_position+Vector3.UP*2,hero.global_position+hero.facing*7*Dark.SCALE*Dark.ATTACK_RANGE+Vector3.UP*2,.8*Dark.SCALE*Dark.ATTACK_RANGE)
  if not target.is_empty():fire_target=weakref(target.enemy)
 if which==Dark.SLAM:
  hero.jump_windup=0
  if not hero.is_on_floor() or hero.velocity.y>0:
   jump_started=true;elapsed=38.0/30;pose_tick=38
   hero.velocity=Vector3(0,minf(hero.velocity.y,-LEAP_SPEED),0);hero.attack_left=duration-elapsed
 if which!=Dark.SLAM or not jump_started:dark_cue(11 if which==Dark.SPIN else which)
func spin_yaw()->float:
 return Dark.spin_turn(pose_tick)*state.get("spin_sign",1) if is_attacking() and action==Dark.SPIN else 0.0
func dark_step(before:float):
 var tick=elapsed*30
 if action==Dark.SPIN and before*30<Dark.SPIN_START and tick>=Dark.SPIN_START:
  strike(Vector3(0,.8,0),Vector3(0,.8,0),Dark.SPIN_RADIUS/(Dark.SCALE*Dark.ATTACK_RANGE))
 if action==Dark.CLAW and not state.has("miss") and before*30<Dark.CLAW_TICK and tick>=Dark.CLAW_TICK:
  strike(Visual.source_point(Roles.ATTACKS[role].from),Visual.source_point(Roles.ATTACKS[role].to),.8)
  if captured!=null:
   action=Dark.GRAB;clip=Dark.CLIPS[action];elapsed=0;pose_tick=0;marker=0
   duration=float(Visual.data(role).get_meta("clips")[clip].ticks)/30;hero.attack_duration=duration/Dark.CLAW_TEMPO;hero.attack_left=hero.attack_duration;return
 if action==Dark.GRAB:
  var victim=captured.get_ref() if captured!=null else null
  if is_instance_valid(victim) and not victim.dead and victim.global_position.distance_to(hero.global_position)<12*Dark.SCALE*Dark.ATTACK_RANGE:
   if tick<Dark.GRAB_TICKS[1] and victim.has_method("combat_knockback"):victim.combat_knockback(Vector3.ZERO,0,.15)
   while marker<2 and tick>=Dark.GRAB_TICKS[marker]:
    if AttackChain.clear_line(hero,hero.global_position+Vector3.UP,AttackChain.aim_point(victim,hero.global_position)):
     victim.take_hit(Roles.stats(role).damage*hero.damage_multiplier()*(.25 if marker==0 else .75),hero.facing,true,ticket)
     if marker==1 and victim.has_method("combat_knockback"):victim.combat_knockback(hero.facing,12,.35)
    dark_cue(4+marker);marker+=1
  elif marker<2:marker=2;captured=null
 elif action==Dark.FIRE:
  if before*30<35 and tick>=35:
   var target=AttackChain.nearest_contact(game,hero,hero.global_position+Vector3.UP*2,hero.global_position+hero.facing*72*Dark.ATTACK_RANGE+Vector3.UP*2,4*Dark.FIRE_SCALE)
   if not target.is_empty():aim=target.point;fire_target=weakref(target.enemy)
  while marker<Dark.FIRE_TICKS.size() and tick>=Dark.FIRE_TICKS[marker]:
   var offset=Dark.MOUTH
   if spell_owner!=null:
    var height:float=hero.body_shape.shape.size.y if hero.body_shape.shape is BoxShape3D else hero.body_shape.shape.height
    offset*=height/(5.184*Dark.SCALE)
   var mouth=hero.global_position+cast_model().basis*offset*hero.growth_multiplier()
   var shot_ticket=ticket.duplicate();shot_ticket.projectile=true
   for side in [-1,1]:
    var direction=(aim-mouth).normalized().rotated(Vector3.UP,side*Dark.FIRE_SPREAD)
    Pool.service(game).launch(hero,Shot,"dark_lumina",{"kind":"dark_lumina","position":mouth,"velocity":direction*Dark.FIRE_SPEED,"aim":aim,"target":fire_target,"lifetime":Dark.FIRE_LIFE,"damage":Roles.stats(role).damage*.5*hero.damage_multiplier(),"attack_ticket":shot_ticket.duplicate()})
   dark_cue(7);marker+=1
 elif action==Dark.SLAM:
  if not jump_started and tick>=22:jump_started=true;hero.velocity.y=LEAP_SPEED*sqrt(hero.combat_tuning("jump_height"))*hero.progression.jump_velocity_multiplier()
  if marker==0 and tick>=38:
   if not hero.is_on_floor() or hero.velocity.y>0:elapsed=38.0/30;pose_tick=38;return
   if tick<Dark.SLAM_TICK:elapsed=Dark.SLAM_TICK/30.0;pose_tick=Dark.SLAM_TICK;tick=Dark.SLAM_TICK
  while marker<2 and tick>=Dark.SLAM_TICK+marker*Dark.SHOCK_DELAY*30:
   var radius=Dark.SHOCK_RADIUS*(.7 if marker==0 else 1.0)*hero.melee_range_multiplier()
   var center=hero.global_position+Vector3.UP*.2
   for enemy in AttackChain.segment_enemy_candidates(game,center,center,radius):
    if not is_instance_valid(enemy) or enemy.dead:continue
    var contact=AttackChain.segment_contact(enemy,center,center,radius)
    if contact.is_empty() or contact.point.y>center.y+1.2 or not AttackChain.clear_line(hero,center+Vector3.UP,contact.point+Vector3.UP):continue
    enemy.take_hit(Roles.stats(role).damage*hero.damage_multiplier(),hero.facing,true,ticket)
   dark_cue(8+marker);marker+=1
 if action==Dark.CLAW and elapsed>=duration and not state.has("miss"):
  state.miss=true;clip="Source__801f1238";elapsed=0;pose_tick=0;duration=32.0/30;hero.attack_duration=duration/Dark.CLAW_TEMPO;hero.attack_left=hero.attack_duration
func die():
 cancel();mode="dead";clip="Source__801f1a58" if role==Dark.ROLE else str(Visual.data(role).get_meta("semantics").death)
 if role==Dark.ROLE:dark_cue(15)
