extends Node
## Original source motions drive three distinct Ben moves and Ed's held beam.
const Projectile=preload("res://scripts/recovered_leader_projectile.gd")
const EdBeam=preload("res://scripts/recovered_ed_beam.gd")
const BombPattern=preload("res://scripts/recovered_ben_bomb_pattern.gd")
const BEN_ATTACK_RATE=2.0
const BEN_MAX_LUNGE=3.0
var assault: RefCounted
var hero: Hero
var game: Node
var active=false:
 set(value):
  active=value
  if not value:cancel()
var primary_held=false
var secondary_held=false
var utility_held=false
var queued_heavy=false
var queued_utility=false
var elapsed=0.0
var clip=""
var mode=""
var combo=0
var combo_timer=0.0
var contact_time=0.0
var contact_done=false
var secondary_contact_done=false
var playback_rate=1.0
var ground_last_key=0
var polearm_dash_distance=0.0
var original_audio: Node
var beam: Node3D
var releasing_beam: Node3D
var barrage_fired=0
var barrage_next=0.0
var last_bomb_release=-100.0
var barrage_targets: Array[Vector3]=[]
var recovery_time=-1.0
# SC06/030: deploy14 ticks, cosine ascent32, source19 barrage, descent64.
const BOMB_TAKEOFF=46.0/30.0
var bomb_phase=""
var bomb_clock=0.0
var bomb_floor_y=0.0
var bomb_start_y=0.0
var bomb_hover_y=0.0
var bomb_land_y=0.0
var bomb_was_airborne=false

func _ready():
 original_audio=preload("res://scripts/recovered_leader_audio.gd").new()
 original_audio.combat=self;add_child(original_audio)
func _notification(what: int):
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:cancel()
func input(event: InputEvent):
 release_input(event)
 if not active or event.is_echo() or hero.dodge_time>0:return
 if event.is_action_pressed("light_attack"):
  queued_heavy=false;queued_utility=false
  if mode in ["bombs","fan","axes","smoke_assault"]:finish_attack()
  secondary_held=false;utility_held=false;primary_held=true
  if not is_attacking():primary_attack()
 elif event.is_action_pressed("heavy_attack"):
  queued_utility=false
  secondary_held=true;primary_held=false;utility_held=false
  if mode in ["beam","fan","axes","smoke_assault"] or (mode=="bombs" and bomb_phase=="land"):finish_attack()
  if is_attacking():queued_heavy=true
  else:start_attack(true)
 elif hero.character_id==14 and event.is_action_pressed("equip"):
  cancel();start_utility()
 elif hero.character_id==15 and event.is_action_pressed("equip"):
  queued_heavy=false
  utility_held=true;primary_held=false;secondary_held=false
  if mode=="bombs":finish_attack()
  if is_attacking():queued_utility=true
  else:start_utility()
func release_input(event: InputEvent):
 if event.is_action_released("light_attack"):
  primary_held=false
  if mode=="beam":finish_attack(true)
 if event.is_action_released("heavy_attack"):
  secondary_held=false;queued_heavy=false
  if mode=="bombs" and contact_done:_land_bombs()
 if event.is_action_released("equip"):utility_held=false;queued_utility=false
func primary_attack():
 if active and not is_attacking() and hero.dodge_time<=0:start_attack(false)
func start_attack(heavy: bool,fan: bool=false,axes: bool=false):
 if not active:return
 if is_instance_valid(releasing_beam):releasing_beam.stop()
 releasing_beam=null
 if is_instance_valid(beam):beam.stop();beam=null
 recovery_time=-1
 combo=0 if heavy or combo_timer<=0 else (combo+1)%3;combo_timer=1.1
 if hero.character_id in [14,15]:combo=0
 elapsed=0;contact_done=false;secondary_contact_done=false;playback_rate=1.0
 hero.weapon_slot=1;hero.attack_heavy=heavy;hero.attack_charged=false;hero.combo=combo+1
 hero.hit_done=false;hero.struck_targets.clear()
 var key="Fireball" if heavy else "source_06"
 mode="fireballs" if heavy else "beam"
 if hero.character_id==15:
  mode="axes" if axes else ("fan" if fan else ("bombs" if heavy else "polearm"))
  key="source_15" if axes else ("source_14" if fan else (("source_19" if hero.flying else "source_18") if heavy else "source_16"))
  playback_rate=BEN_ATTACK_RATE
 clip=hero.model.motion(key)
 hero.attack_duration=hero.model.animation_player.get_animation(clip).length/playback_rate
 if mode in ["polearm","fan","axes"]:hero.attack_duration=(25.0 if mode=="fan" else 87.0)/30.0/playback_rate
 hero.attack_left=hero.attack_duration
 ground_last_key=0;polearm_dash_distance=0
 contact_time=14.0/30.0 if mode=="fireballs" else (4.0/30.0 if mode=="beam" else (16.0/30.0 if heavy else (10.0/30.0 if combo==0 else 9.0/30.0)))
 if fan:contact_time=(20.0 if axes else 10.0)/30.0
 elif mode=="polearm":contact_time=1.0/30.0
 hero.facing=hero.combat_attack_direction();hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)
 hero.attack_ticket=hero.attack_chain.begin("beam" if mode=="beam" else ("leader_secondary" if heavy else "leader_primary"),"utility" if fan else ("secondary" if heavy else "primary_%d"%(combo+1)))
 hero.model.animate(0,0,hero.is_on_floor(),hero.velocity.y,1,heavy,combo+1,false)
 if mode=="beam":
  beam=EdBeam.new();beam.hero=hero;beam.game=game;beam.attack_ticket=hero.attack_ticket;game.add_child(beam)
  game.move_audio.release(game,hero.attack_ticket)
 elif mode=="bombs":
  barrage_fired=0;barrage_next=6.0/30.0;last_bomb_release=-100;_prepare_bomb_targets()
  bomb_was_airborne=hero.flying;bomb_phase="barrage" if bomb_was_airborne else "deploy";bomb_clock=0
  bomb_start_y=hero.global_position.y;bomb_floor_y=bomb_start_y
  var ground_query=PhysicsRayQueryParameters3D.create(hero.global_position+Vector3.UP*.1,hero.global_position-Vector3.UP*80,1)
  ground_query.exclude=[hero.get_rid()]
  var ground_hit=hero.get_world_3d().direct_space_state.intersect_ray(ground_query)
  if not ground_hit.is_empty():bomb_floor_y=ground_hit.position.y
  bomb_hover_y=maxf(hero.global_position.y,bomb_floor_y+1.26*hero.growth_multiplier())
 elif mode=="axes":game.sound("ben_axe_voice",.6,false,hero.attack_ticket,15)
 elif mode=="fan":game.move_audio.release(game,hero.attack_ticket)
 elif mode=="polearm":game.sound("heavy_swing",.6,false,hero.attack_ticket,15)
func start_utility(axes: bool=false):
 if hero.character_id!=14:start_attack(true,true,axes);return
 if not active:return
 finish_attack();primary_held=false;secondary_held=false;utility_held=false
 elapsed=0;mode="smoke_assault";clip=hero.model.motion("source_04")
 hero.attack_heavy=true;hero.attack_duration=139.0/30.0;hero.attack_left=hero.attack_duration
 hero.attack_ticket=hero.attack_chain.begin("ed_smoke_assault","utility")
 if assault==null:assault=preload("res://scripts/recovered_ed_smoke_assault.gd").new();assault.combat=self
 assault.begin()
func tick_timers(delta: float):combo_timer=maxf(0,combo_timer-delta)
func tick(delta: float,_after_pose: bool=false):
 if not active or game.paused or game.transitioning or not game.playing:return
 if releasing_beam!=null and (not is_instance_valid(releasing_beam) or not releasing_beam.releasing):
  releasing_beam=null;recovery_time=0
 if recovery_time>=0:
  recovery_time+=delta
  if recovery_time>=hero.model.duration("source_05"):recovery_time=-1
 if not is_attacking():
  if hero.character_id==15 and secondary_held:start_attack(true)
  elif hero.character_id==15 and utility_held:start_utility()
  elif primary_held or hero.auto_attack_running():primary_attack()
  return
 var step=delta*hero.attack_speed_multiplier()*playback_rate
 elapsed+=step
 if mode=="smoke_assault":
  hero.attack_left=maxf(.05,hero.attack_duration-elapsed);assault.advance(step);return
 var source_duration=hero.model.animation_player.get_animation(clip).length
 if mode in ["polearm","fan","axes"]:source_duration=(25.0 if mode=="fan" else 87.0)/30.0
 hero.attack_left=maxf(.05,(source_duration-elapsed)/playback_rate)
 if mode=="beam":
  hero.facing=hero.combat_attack_direction();hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)
  if not is_instance_valid(beam) or not beam.active:finish_attack();primary_held=false;return
  beam.advance(step);contact_done=elapsed>=contact_time
  if not primary_held and not hero.auto_attack_running() and elapsed>=source_duration:finish_attack(true)
  return
 if mode=="bombs":
  bomb_clock+=step
  if bomb_phase=="deploy":
   if bomb_clock<BOMB_TAKEOFF:return
   bomb_clock-=BOMB_TAKEOFF;bomb_phase="barrage";clip=hero.model.motion("source_19")
  elif bomb_phase=="land":
   if bomb_clock>=81.0/30.0 and (hero.is_on_floor() or bomb_clock>5.0):finish_attack()
   return
  hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)+float(bomb_motion_frame().heading_units)/4096.0*TAU
  while bomb_clock+.000001>=barrage_next and (barrage_fired==0 or secondary_held) and barrage_fired<20:
   # Original body retains its follow-through when the counter resets;
   # the four propeller parts use the separately dispatched accessory pose.
   hero.model.sample_ben_bomb_rom(roundi(barrage_next*30),.08)
   release_bomb(barrage_targets[barrage_fired]);last_bomb_release=barrage_next;barrage_fired+=1
   barrage_next=(floorf(barrage_fired*215.0/32.0)+6.0)/30.0
  contact_done=barrage_fired>0
  if barrage_fired>=20:
   if secondary_held:
    barrage_fired=0;barrage_next=6.0/30.0;bomb_clock=0;_prepare_bomb_targets()
   else:_land_bombs()
  elif not secondary_held and contact_done and bomb_clock>=last_bomb_release+.1:_land_bombs()
  return
 if mode in ["polearm","fan","axes"]:_tick_ben_ground()
 elif not contact_done and elapsed>=contact_time:
  contact_done=true;hero.model._sample(clip,motion_time(),.08)
  if mode=="fireballs":release_projectiles()
  elif mode=="fan":release_fan()
  else:game.sound("heavy_swing",.6,false,hero.attack_ticket,hero.character_id);hero.strike()
 if elapsed>=source_duration:
  finish_attack()
  if queued_utility:queued_utility=false;start_utility()
  elif queued_heavy:queued_heavy=false;start_attack(true)
  elif hero.character_id==15 and utility_held:start_utility(true)
  elif primary_held or hero.auto_attack_running():primary_attack()
static func ben_ground_motion_frame(kind: String,tick: int)->Dictionary:
 if kind=="axes":
  var key=posmod(tick,29) if tick<87 else 29
  return {"body_key":key,"accessory_visible":false,"release":tick in [20,49,78],"contact":false,"dash":false,"aim_divisor":4 if key>=1 and key<5 else 0,"complete":tick>=87}
 var polearm=kind=="polearm"
 var key=clampi(tick,0,87 if polearm else 25)
 return {"body_key":key,"accessory_visible":false,"release":not polearm and key==10 and tick==10,
  "contact":polearm and ((key>=1 and key<44) or (key>=50 and key<=65)),
  "dash":polearm and key>=50 and key<=65,"aim_divisor":(2 if key>=45 and key<=48 else 0) if polearm else (4 if key>=1 and key<5 else 0),
  "complete":tick>=(87 if polearm else 25)}

func _tick_ben_ground():
 var sampled_elapsed=elapsed
 var key=floori(elapsed*30.0+.00001)
 for tick_ in range(ground_last_key+1,mini(key,25 if mode=="fan" else 87)+1):
  var frame=ben_ground_motion_frame(mode,tick_)
  elapsed=float(tick_)/30.0
  if int(frame.aim_divisor)>0:
   var desired=hero.combat_attack_direction()
   var heading=lerp_angle(atan2(hero.facing.x,hero.facing.z),atan2(desired.x,desired.z),1.0/float(frame.aim_divisor))
   hero.facing=Vector3(sin(heading),0,cos(heading))
   hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)
  if mode=="polearm":
   if tick_==44:game.sound("ben_polearm_strike_voice",.6,false,hero.attack_ticket,15)
   if tick_==49:
    var target=hero.global_position+hero.facing*6.0
    if hero.ai_controlled:target=hero.ai_aim
    elif game.has_method("attack_aim_point"):target=game.attack_aim_point()
    var distance=Vector2(target.x-hero.global_position.x,target.z-hero.global_position.z).length()
    # The native16-step deceleration travels2.125 times this coefficient.
    # Cap the complete lunge independently of distant cursor/AI targets.
    polearm_dash_distance=minf(maxf(0,floorf(distance*100.0)-256.0)*.01,BEN_MAX_LUNGE/2.125)
    if polearm_dash_distance>0:game.sound("ben_polearm_dash",.6,false,hero.attack_ticket,15)
   if tick_==50 and polearm_dash_distance>0:
    # Native state3 is a distinct damage stage, after aiming/setup. Keep
    # one hit per target in each stage instead of applying damage each tick.
    hero.struck_targets.clear();hero.hit_done=false
   if tick_==65 and polearm_dash_distance>0:game.sound("ben_polearm_finish",.6,false,hero.attack_ticket,15)
   if frame.contact and (tick_<44 or polearm_dash_distance>0):
    contact_done=true;hero.model._sample(clip,motion_time(),.08);hero.strike()
  elif frame.release:
   contact_done=true;hero.model._sample(clip,motion_time(),.08)
   if mode=="axes":release_axe()
   else:release_fan()
 ground_last_key=key;elapsed=sampled_elapsed

func ground_attack_velocity()->Vector3:
 if mode=="smoke_assault" and is_attacking():return assault.velocity()
 if mode in ["fan","axes"] and is_attacking():return Vector3.ZERO
 if mode!="polearm" or not is_attacking():return Vector3(INF,INF,INF)
 # Original setup is key49; next16 actor updates50..65 subtract velocity,
 # then reduce it by1/16 of its initial value. Positions use16.16 fixed point.
 var key=floori(elapsed*30.0+.00001)
 if key<50 or key>65:return Vector3.ZERO
 return hero.facing*polearm_dash_distance*7.5*float(66-key)/16.0*hero.attack_speed_multiplier()*playback_rate

func motion_time()->float:
 if mode=="smoke_assault":return assault.motion_time()
 if mode in ["polearm","fan","axes"]:return float(ben_ground_motion_frame(mode,floori(elapsed*30.0+.00001)).body_key)/30.0
 if mode=="beam":return fposmod(elapsed,hero.model.duration("source_06"))
 if mode=="bombs":
  if bomb_phase=="deploy":return bomb_clock
  if bomb_phase=="land":return maxf(0,bomb_clock-46.0/30.0) if bomb_clock>=46.0/30.0 else fposmod(bomb_clock,hero.model.duration("source_17"))
  return float(bomb_motion_frame().body_key)/30.0
 return elapsed
func bomb_motion_frame()->Dictionary:
 return hero.model.ben_bomb_rom_frame(floori(bomb_clock*30.0+.00001))
func _land_bombs():
 if bomb_phase=="land":return
 bomb_phase="land";bomb_clock=0;bomb_land_y=hero.global_position.y
 clip=hero.model.motion("source_17")
func bomb_controls_flight()->bool:return hero.character_id==15 and is_bombing()
func bomb_vertical_velocity(delta: float,lifting: bool,_boosting: bool)->float:
 if lifting:
  # Space retains direct flight control; releasing RMB must not drag a pilot down.
  if bomb_phase=="land":finish_attack();return 5.0
  var lift_speed=8.0 if _boosting else 5.0
  if bomb_phase=="barrage":
   # Remove the current bob before anchoring manual lift; never integrate
   # the oscillation back into the hover baseline on every controller tick.
   bomb_hover_y=hero.global_position.y-float(bomb_motion_frame().bob_offset_metres)*hero.growth_multiplier()+lift_speed*delta
   return lift_speed
  bomb_hover_y+=lift_speed*delta
 var target=hero.global_position.y
 if bomb_phase=="deploy":
  var ascent=clampf((bomb_clock-14.0/30.0)/(32.0/30.0),0,1)
  target=lerpf(bomb_start_y,bomb_hover_y,(1.0-cos(ascent*PI))*.5)
 elif bomb_phase=="barrage":
  target=bomb_hover_y+float(bomb_motion_frame().bob_offset_metres)*hero.growth_multiplier()
 elif bomb_phase=="land":
  var query=PhysicsRayQueryParameters3D.create(hero.global_position+Vector3.UP*.1,hero.global_position-Vector3.UP*80,1)
  query.exclude=[hero.get_rid()]
  var floor_=hero.get_world_3d().direct_space_state.intersect_ray(query)
  var floor_y=floor_.position.y if not floor_.is_empty() else bomb_floor_y
  var progress=clampf(bomb_clock/(64.0/30.0),0,1)
  target=lerpf(bomb_land_y,floor_y,(1.0-cos(progress*PI))*.5)
  if bomb_clock>=46.0/30.0 and clip!=hero.model.motion("source_20"):clip=hero.model.motion("source_20")
  # A zero-velocity target exactly on the mesh never establishes CharacterBody
  # floor contact. Keep downward pressure through retraction to avoid a second
  # automatic flight/landing animation when the move finishes.
  if progress>=1:return -.5
 return clampf((target-hero.global_position.y)/maxf(delta,.00001),-12,12)
func _release_origin(side: String)->Vector3:
 var point=hero.model.hand_position(side)+hero.facing*.15*hero.growth_multiplier()
 point.y=maxf(point.y,hero.global_position.y+.3)
 return point
func release_projectiles():
 var origin=_release_origin("R")
 for i in 3:
  var shot=Projectile.new();shot.game=game;shot.hero=hero;shot.source_character=14
  shot.attack_ticket=hero.attack_ticket;shot.damage=22.0*hero.damage_multiplier()
  shot.velocity=hero.facing.rotated(Vector3.UP,(i-1)*.15)*16.0+Vector3.UP
  game.add_child(shot);shot.global_position=origin
 game.sound("throw",.6,false,hero.attack_ticket,14)
func release_fan():
 var origin=_release_origin("L")
 for i in 3:
  var shot=Projectile.new();shot.game=game;shot.hero=hero;shot.source_character=15;shot.shuriken=true
  shot.attack_ticket=hero.attack_ticket;shot.damage=28.0*hero.damage_multiplier();shot.lifetime=4.0
  shot.velocity=hero.facing.rotated(Vector3.UP,(i-1)*PI/8.0)*7.2
  game.add_child(shot);shot.global_position=origin
 game.sound("ben_projectile_throw",.6,false,hero.attack_ticket,15)
func release_axe():
 var shot=Projectile.new();shot.game=game;shot.hero=hero;shot.source_character=15;shot.axe=true
 shot.attack_ticket=hero.attack_ticket;shot.damage=28.0*hero.damage_multiplier();shot.lifetime=4.0;shot.hit_radius=1.84
 shot.velocity=hero.facing*7.2
 game.add_child(shot);shot.global_position=_release_origin("L")
func _prepare_bomb_targets():
 barrage_targets.clear()
 var forward=hero.facing;var right=forward.cross(Vector3.UP)
 var anchor=hero.global_position+forward*8.0
 if game.has_method("attack_aim_point") and not hero.ai_controlled:
  var aim=game.attack_aim_point();var distance=Vector2(aim.x-hero.global_position.x,aim.z-hero.global_position.z).length()
  anchor=hero.global_position+forward*clampf(distance,4,12)
 var order=BombPattern.ORDERS[randi()%4]
 for index in order:
  var point=BombPattern.POINTS[index]
  var target=anchor+right*float(point[0])*.01+forward*float(point[1])*.01
  var query=PhysicsRayQueryParameters3D.create(target+Vector3.UP*40,target-Vector3.UP*80,1)
  query.exclude=[hero.get_rid()]
  var floor_=hero.get_world_3d().direct_space_state.intersect_ray(query)
  target.y=(floor_.position.y if not floor_.is_empty() else hero.global_position.y)+.4
  barrage_targets.append(target)
func release_bomb(target: Vector3):
 var shot=Projectile.new();shot.game=game;shot.hero=hero;shot.source_character=15;shot.bomb=true
 shot.attack_ticket=hero.attack_ticket;shot.damage=46.0*hero.damage_multiplier()
 shot.blast_radius=2.6*preload("res://scripts/character_proportions.gd").BEN_MODEL_SCALE*hero.pickup_multiplier("range")*hero.growth_multiplier()
 shot.bomb_target=target;shot.lifetime=1.0
 game.add_child(shot);shot.global_position=_release_origin("L")
 # ROM8017E8C8 calls943 on release; the separate940warning stays disabled.
 game.sound("throw",.35,false,hero.attack_ticket,15)
func is_attacking()->bool:return not clip.is_empty()
func is_bombing()->bool:return mode=="bombs" and is_attacking()
func blade_active()->bool:
 return mode=="polearm" and is_attacking() and bool(ben_ground_motion_frame(mode,floori(elapsed*30.0+.00001)).contact)
func blocks_movement()->bool:return false
func protects_player()->bool:
 if not active or hero.character_id!=14 or not is_attacking() or not game.playing or game.transitioning:return false
 return mode=="smoke_assault" or (mode=="beam" and is_instance_valid(beam) and beam.active)
func beam_release_pose_time()->float:
 # State6 reselects source06 and clears its animation cursor at8017E4AC.
 return releasing_beam.release_elapsed if is_instance_valid(releasing_beam) and releasing_beam.releasing else -1.0
func finish_attack(release_beam: bool=false):
 if not release_beam and is_instance_valid(releasing_beam):
  releasing_beam.stop();releasing_beam=null
 if mode=="smoke_assault" and assault!=null:assault.cancel()
 if is_instance_valid(beam):
  if release_beam:
   beam.release();releasing_beam=beam
  else:beam.stop()
 beam=null
 if mode=="beam":recovery_time=-1 if release_beam else 0
 if mode in ["polearm","smoke_assault"]:hero.velocity.x=0;hero.velocity.z=0
 if mode=="bombs" and bomb_phase=="land" and hero.is_on_floor():
  hero.model.was_flying=false;hero.model.flight_landing=false;hero.model.landing_clock=-1
 clip="";mode="";bomb_phase="";hero.attack_left=0
func cancel(_preserve_power: bool=false):
 if is_instance_valid(original_audio):original_audio.release_charge()
 primary_held=false;secondary_held=false;utility_held=false;queued_heavy=false;queued_utility=false
 if is_instance_valid(hero):finish_attack()
 releasing_beam=null
 if is_inside_tree():
  for effect in get_tree().get_nodes_in_group("ed_beams"):
   if effect.hero==hero:effect.stop()
 clip="";mode="";elapsed=0;combo_timer=0;recovery_time=-1
 if is_instance_valid(hero):
  var model=hero.character_models.get(15)
  if is_instance_valid(model) and is_instance_valid(model.sword_trail):model.sword_trail.clear()
func hit():cancel()
func interrupt_for_dodge():cancel()
