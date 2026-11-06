extends "res://scripts/recovered_enemy_combat.gd"
## Player adapter only. Enemies consume the same Finale timeline in native Combat.
const Finale=preload("res://scripts/forest/dark_lumina_3_kit.gd")
const FinaleShot=preload("res://scripts/dark_lumina_3_projectile.gd")
const WaveShot=preload("res://scripts/kojiro_projectile.gd")
const CAST_RATE=3.0
const EARTH_WAVE_TICKS=28
const SWORD_SECTIONS=[
 {"clip":"Source__801ef270","start":0,"ticks":40,"contact":28},
 {"clip":"Source__801ef3b8","start":0,"ticks":16,"contact":11},
 {"clip":"Source__801ef3b8","start":16,"ticks":16,"contact":7}]
var move=0
var origin=Vector3.ZERO
var combo=-1
var combo_timer=0.0
var queued_cut=false
var earth_waves=0
var spell_casts=0
func prepare_projectiles():
 Finale.prepare()
 Pool.service(game).warm(hero,WaveShot,"wind",{"kind":"wind"},12)
 Pool.service(game).warm(hero,WaveShot,"dust",{"kind":"dust"},128)
 game.sound_library.gain_for(30,"finale_cast")
 # Consecutive airborne queues at maximum pickup speed overlap eight Fire volleys.
 # Water reserves prepared leases for overlapping five-way contact splits.
 for i in [0,1,2,3,5]:Pool.service(game).warm(hero,FinaleShot,"finale%d"%i,{"kind":i},256 if i==3 else 128 if i==2 else Finale.WIND_POOL if i==1 else 8)
func input(event:InputEvent):
 if not active or event.is_echo() or hero.dodge_time>0:return
 if event is InputEventKey and event.pressed:
  var number=(event.physical_keycode if event.physical_keycode else event.keycode)-KEY_1
  if number>=0 and number<5:select_number(number+1);return
 if event.is_action_pressed("light_attack"):start_attack()
func select_number(number:int):
 if number<1 or number>5 or not active or hero.hp<=0 or hero.dodge_time>0:return
 if not (number in [1,2,3,4] and mode=="attack" and move==number):cancel(true)
 start_move(number)
func start_attack(_heavy:bool=false):
 if hero.hp<=0:return
 if mode=="combo":queued_cut=true;return
 if is_attacking():cancel(true)
 combo=0 if combo_timer<=0 else (combo+1)%SWORD_SECTIONS.size()
 combo_timer=0;queued_cut=false;move=0;mode="combo";elapsed=0;marker=0;reaction=0;hits.clear()
 hero.facing=hero.combat_attack_direction();cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
 duration=SWORD_SECTIONS[combo].ticks/30.0
 ticket=hero.attack_chain.begin("sword","energy_%d"%(combo+1));hero.attack_ticket=ticket;hero.combo=combo+1
 hero.attack_duration=duration/CAST_RATE;hero.attack_left=hero.attack_duration
 cue(33,hero.global_position);update_pose()
func start_move(index:int):
 if index<0 or index>=6 or hero.hp<=0:return
 if index in [1,2,3] and mode=="attack" and move==index:
  if spell_casts<3:
   spell_casts+=1
   if marker<=60:
    elapsed=0;marker=0
    cue(31,hero.global_position);cue(move,hero.global_position);update_pose()
   duration=Finale.moves[move].size()*spell_casts/30.0
   hero.attack_duration=duration/CAST_RATE;hero.attack_left=(duration-elapsed)/CAST_RATE
  return
 if index==4 and mode=="attack" and move==4:
  if marker<=40 and earth_waves<5:
   earth_waves+=1
   elapsed=0;marker=0;hero.velocity.y=13
   duration=maxf(duration,(40+(earth_waves-1)*EARTH_WAVE_TICKS+20)/30.0)
   hero.attack_duration=duration/CAST_RATE;hero.attack_left=hero.attack_duration
   update_pose();cue(move,hero.global_position)
  return
 if is_attacking():return
 origin=hero.global_position
 move=index;mode="attack";elapsed=0;marker=0;reaction=0;hits.clear()
 earth_waves=1 if move==4 else 0
 spell_casts=1 if move in [1,2,3] else 0
 hero.facing=hero.combat_attack_direction();cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
 aim=hero.global_position+hero.facing*8*Finale.SCALE
 var target=AttackChain.nearest_contact(game,hero,hero.global_position+Vector3.UP,hero.global_position+Vector3.UP+hero.facing*24*Finale.SCALE,3*Finale.SCALE)
 if not target.is_empty():aim=target.enemy.global_position
 ticket=hero.attack_chain.begin("dark_lumina_3_"+str(move));duration=Finale.moves[move].size()/30.0
 hero.attack_duration=duration/CAST_RATE;hero.attack_left=hero.attack_duration
 if move==4:hero.velocity.y=13;hero.jumps_used=maxi(1,hero.jumps_used);hero.coyote=0
 update_pose();cue(move,hero.global_position)
func tick_timers(delta:float):
 super.tick_timers(delta);combo_timer=maxf(0,combo_timer-delta)
func tick(delta:float,after_pose:bool=false):
 if after_pose:return
 if spell_owner==null and not is_attacking() and hero.auto_attack_running():start_attack()
 if not is_attacking():return
 if mode=="attack" and move==1:
  hero.facing=hero.combat_attack_direction();cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
 elapsed+=delta*hero.attack_speed_multiplier()*CAST_RATE
 if mode=="combo":
  if marker==0 and elapsed*30>=SWORD_SECTIONS[combo].contact:
   strike(Visual.source_point(Roles.ATTACKS[role].from)*Finale.SCALE,Visual.source_point(Roles.ATTACKS[role].to)*Finale.SCALE,.7*Finale.SCALE,Finale.DAMAGE[0]);marker=1
   release_event(1,[88,127,139][combo])
  hero.attack_left=maxf(0,(duration-elapsed)/CAST_RATE);update_pose()
  if elapsed>=duration:
   var next=queued_cut;var section=combo;cancel(true);combo=section;combo_timer=.7
   if next:start_attack()
  return
 if move==4 and marker<=40 and elapsed*30>=40 and not hero.is_on_floor():elapsed=39.0/30
 hero.attack_left=maxf(0,(duration-elapsed)/CAST_RATE)
 while marker<mini(floori(elapsed*30)+1,roundi(duration*30)):
  var source_tick=marker%Finale.moves[move].size() if move in [1,2,3] else marker
  if source_tick==0 and marker>0:
   hits.clear()
   cue(31,hero.global_position);cue(move,hero.global_position)
  var frame=Finale.frame(move,source_tick)
  var event:int=frame.event
  if move==4:event=5 if marker>=40 and (marker-40)%EARTH_WAVE_TICKS==0 and (marker-40)/EARTH_WAVE_TICKS<earth_waves else 0
  if frame.cue:cue(frame.cue,hero.global_position,Vector3.INF,source_tick)
  if move==5 and marker in [51,251]:sky_warp(aim+Vector3(0,0,7)*Finale.SCALE if marker==51 else origin)
  if event:release_event(event,source_tick)
  marker+=1
 if move==0 and Finale.frame(move,floori(elapsed*30)).speed>0:
  strike(Visual.source_point(Roles.ATTACKS[role].from)*Finale.SCALE,Visual.source_point(Roles.ATTACKS[role].to)*Finale.SCALE,.7*Finale.SCALE,Finale.DAMAGE[0])
 update_pose()
 if elapsed>=duration:cancel(true)
func update_pose():
 if mode=="combo":clip=SWORD_SECTIONS[combo].clip;pose_tick=SWORD_SECTIONS[combo].start+minf(elapsed*30,SWORD_SECTIONS[combo].ticks-1);return
 var source_tick=floori(elapsed*30)
 if move in [1,2,3]:source_tick%=Finale.moves[move].size()
 var frame=Finale.frame(move,source_tick);clip=frame.clip;pose_tick=frame.tick
 cast_model().body.visible=not frame.hidden
func release_event(event:int,tick_:int):
 var point=hero.global_position+(Vector3.UP*1.3+hero.facing*1.5)*Finale.SCALE
 var direction=hero.facing
 if event in [2,5]:
  if event==5 and tick_==40:origin=hero.global_position
  point=hero.global_position+hero.facing*5*Finale.SCALE if event==2 else origin
  var victims=area(point,Finale.WIND_AREA if event==2 else Finale.SHOT_RADIUS[move],0.0 if event==2 else Finale.DAMAGE[move],event==2)
  if event==2:
   var side=hero.facing.cross(Vector3.UP)
   for lane in Finale.WIND_FAN:
    var from=hero.global_position+(hero.facing+side*(-2 if lane%2==0 else 2)+Vector3.UP)*Finale.SCALE
    wind_shot(from,hero.facing.rotated(Vector3.UP,(lane-1.5)*PI/24))
   for target in victims:
    var from=hero.global_position+(hero.facing+Vector3.UP)*Finale.SCALE
    var away=Vector3(target.x-hero.position.x,0,target.z-hero.position.z).normalized()
    var lead=minf(18.0,from.distance_to(target)*24.0/(Finale.SHOT_SPEED[1]-24.0))
    wind_shot(from,(target+away*lead-from).normalized())
 elif event in [6,7]:
  var index=(tick_-60)/6 if event==6 else (tick_-139)/12
  var angle=index*TAU/5+(tick_-60)*TAU/31 if event==6 else index*TAU/5
  point=aim+Vector3(sin(angle)*7,1,cos(angle)*7)*Finale.SCALE
  direction=(aim+Vector3.UP*Finale.SCALE-point).normalized()
 elif event in [3,4]:
  var angle=randf()*TAU;var radius=randf()*Finale.FALL_SPREAD[move-2]
  point=aim+Vector3(sin(angle)*radius,Finale.FALL_HEIGHT,cos(angle)*radius)
  direction=Vector3(-.18 if event==4 else 0,-1,0).normalized()
 if event==1 and tick_==88 and mode=="combo":
  point=hero.global_position+direction*24*WaveShot.SOURCE_UNIT+Vector3.UP*.08
  Pool.service(game).launch(hero,WaveShot,"wind",{"kind":"wind","position":point,"unit":WaveShot.SOURCE_UNIT,"velocity":direction*16*30*WaveShot.SOURCE_UNIT,"damage":Roles.stats(role).damage*Finale.DAMAGE[0]*hero.damage_multiplier(),"attack_ticket":ticket.duplicate()})
  cue(11,point,direction,tick_);return
 if event==1 and tick_==88:point.y=hero.global_position.y+.025*Finale.SCALE
 if event in [1,3,4,7]:
  Pool.service(game).launch(hero,FinaleShot,"finale%d"%move,{"kind":move,"piercing":mode=="combo","cross_slash":move==0 and tick_>88,"slash_yaw":Finale.SWORD_CROSS_ANGLE*(1 if tick_==127 else -1) if move==0 and tick_>88 else 0.0,"position":point,"velocity":direction*Finale.SHOT_SPEED[move],"lifetime":Finale.SHOT_LIFE[move],"damage":Roles.stats(role).damage*Finale.DAMAGE[move]*hero.damage_multiplier(),"attack_ticket":ticket.duplicate()})
 if event!=4:cue(event+10,point,direction,tick_)
func wind_shot(from:Vector3,direction:Vector3):
 Pool.service(game).launch(hero,FinaleShot,"finale1",{"kind":1,"position":from,"velocity":direction*Finale.SHOT_SPEED[1],"lifetime":Finale.SHOT_LIFE[1],"damage":Roles.stats(role).damage*Finale.DAMAGE[1]*.5*hero.damage_multiplier(),"attack_ticket":ticket.duplicate()})
func area(center:Vector3,radius:float,factor:float,wind:bool)->Array:
 radius*=skill_factor("hit_area",ticket)
 var victims=[]
 for enemy in AttackChain.segment_enemy_candidates(game,center,center,radius):
  if not is_instance_valid(enemy) or enemy.dead:continue
  var point=AttackChain.aim_point(enemy,center)
  if point.distance_to(center)>radius:continue
  if wind and hero.facing.dot((point-hero.global_position).normalized())<.45:continue
  if not AttackChain.clear_line(hero,center+Vector3.UP,point):continue
  var direction=(point-hero.global_position).normalized() if wind else hero.facing
  if factor>0:enemy.take_hit(Roles.stats(role).damage*factor*hero.damage_multiplier(),direction,not wind,ticket)
  if wind and enemy.has_method("combat_knockback"):enemy.combat_knockback(direction,24,.3)
  if wind and not hits.has(enemy.get_instance_id()):
   hits[enemy.get_instance_id()]=true;victims.append(point+Vector3.UP*1.2)
  if factor>0:
   if hero.ai_controlled:game.confirm_ally_impact(enemy,point,hero.facing,1,false,30)
   else:game.confirm_impact(enemy,point,hero.facing,1,false,30)
 return victims
func cue(code:int,point:Vector3,direction:Vector3=Vector3.INF,source_tick:int=-1):
 if game.get("crowd")!=null:game.crowd.army.presentation.finale_cue(point,code,direction if direction.is_finite() else hero.facing,get_instance_id(),source_tick if source_tick>=0 else floori(elapsed*30),CAST_RATE*hero.attack_speed_multiplier() if is_attacking() else 1.0,skill_factor("size",ticket),ticket)
func ground_attack_velocity()->Vector3:
 return hero.facing*Finale.frame(move,floori(elapsed*30)).speed if mode=="attack" else Vector3.INF
func is_attacking()->bool:return mode in ["attack","combo"]
func presentation_mode()->float:
 if mode=="combo":return 7.1
 if not is_attacking():return 0
 if move==0 and elapsed*30>=40 and elapsed*30<180:return 7+.1*clampf(minf((elapsed*30-40)/16,(180-elapsed*30)/16),0,1)
 return move+1
func protects_player()->bool:return mode=="attack" and Finale.frame(move,floori(elapsed*30)).hidden
func cancel(preserve_power:bool=false):
 if game.get("crowd")!=null:game.crowd.army.presentation.cancel_finale(get_instance_id())
 super.cancel(preserve_power)
 combo=-1;combo_timer=0;queued_cut=false;earth_waves=0;spell_casts=0
 if is_instance_valid(cast_model()):cast_model().body.show()

func hit():
 super.hit()
func die():
 cancel();mode="dead";clip="Source__801ef940";pose_tick=0;cue(30,hero.global_position)

func sky_warp(point:Vector3):
 var floor_hit=hero.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*5,point-Vector3.UP*8,1,[hero.get_rid()]))
 if floor_hit.is_empty() or floor_hit.normal.y<.6:return
 point.y=floor_hit.position.y+.08
 var query=PhysicsShapeQueryParameters3D.new();query.shape=hero.body_shape.shape;query.collision_mask=1;query.exclude=[hero.get_rid()]
 query.transform=hero.global_transform*hero.body_shape.transform;query.transform.origin+=point-hero.global_position
 if not hero.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return
 hero.global_position=point;hero.velocity=Vector3.ZERO
