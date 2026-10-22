extends Node
## Recovered Yae katana, Sword Shield and bazooka action clocks and contact curves.
const Profile=preload("res://scripts/recovered_yae_combat_profile.gd")
const Projectile=preload("res://scripts/recovered_yae_projectile.gd")
var hero: Hero
var game: Node
var active=false:
 set(value):
  active=value
  if not value:cancel()
var primary_held=false
var secondary_held=false
var shield_held=false
var queued_primary=false
var elapsed=0.0
var action_id=0
var mode=""
var combo=0
var combo_timer=0.0
var contact_done=false
var cue_done={}
var pending_from=-1.0
var pending_until=-1.0
var pending_end=false
var previous_root=Transform3D.IDENTITY
var have_previous_root=false
var cached_reach_scale=-1.0
var cached_melee_reach=3.3
var shield_sound_clock=0.0
var next_charge_sound=1.5
var charge_sustain_count=0
var lock_targets: Array=[]

func _notification(what: int):
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:cancel()
func input(event: InputEvent):
 release_input(event)
 if not active or event.is_echo() or hero.dodge_time>0:return
 if event.is_action_pressed("light_attack"):
  primary_held=true
  if is_attacking():queued_primary=true
  else:primary_attack()
 elif event.is_action_pressed("heavy_attack"):
  cancel();secondary_held=true;_begin("bazooka_charge",0)
 elif event.is_action_pressed("equip"):
  cancel();shield_held=true;_begin("shield_enter",0x9c if hero.is_on_floor() else 0x9f)
func release_input(event: InputEvent):
 if event.is_action_released("light_attack"):primary_held=false
 if event.is_action_released("heavy_attack"):
  secondary_held=false
  if mode=="bazooka_charge":
   var charged=elapsed>=Profile.CHARGE_SECONDS
   finish_attack();start_bazooka(charged)
 if event.is_action_released("equip"):
  shield_held=false
  if mode in ["shield_enter","shield"]:_begin("shield_exit",0x9e if hero.is_on_floor() else 0xa1)
func primary_attack():
 if not active or is_attacking() or hero.dodge_time>0:return
 combo=0 if combo_timer<=0 or not hero.is_on_floor() else (combo+1)%3;combo_timer=1.0
 _begin("primary",Profile.combo_actions()[combo] if hero.is_on_floor() else 0x6e)
 if combo!=1:_release_voice("move_primary_%d_voice"%(combo+1))
func start_bazooka(charged: bool=false):
 _begin("lock_on" if charged else "bazooka",(0xa7 if charged else 0xa4) if hero.is_on_floor() else (0xa8 if charged else 0xa5))
func _begin(kind: String,action: int):
 mode=kind;action_id=action;elapsed=0;contact_done=false;cue_done.clear();pending_from=-1;pending_until=-1;pending_end=false;have_previous_root=false
 shield_sound_clock=0;next_charge_sound=1.5;charge_sustain_count=0
 hero.weapon_slot=1;hero.attack_heavy=kind in ["bazooka","lock_on"];hero.attack_charged=kind=="lock_on"
 hero.combo=combo+1;hero.hit_done=false;hero.struck_targets.clear()
 hero.attack_duration=Profile.duration(action_id);hero.attack_left=maxf(.05,hero.attack_duration)
 hero.facing=hero.combat_attack_direction()
 if is_instance_valid(hero.model):
  hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)
  previous_root=hero.model.global_transform;have_previous_root=true
 var move_key="primary_%d"%(combo+1) if kind=="primary" else {"bazooka_charge":"secondary","bazooka":"secondary","lock_on":"charged","shield_enter":"utility","shield":"utility","shield_exit":"utility"}.get(kind,kind)
 if hero.attack_chain!=null:hero.attack_ticket=hero.attack_chain.begin("yae_"+kind,move_key)
 else:hero.attack_ticket={"source_hero":weakref(hero),"source_character_id":17,"action":"yae_"+kind,"allied":hero.ai_controlled,"chain_enabled":false}
func tick_timers(delta: float):combo_timer=maxf(0,combo_timer-delta)
func tick(delta: float,after_pose: bool=false):
 if not active:return
 if game.paused or game.transitioning or not game.playing:
  if pose_active() or primary_held or secondary_held or shield_held:cancel()
  return
 if after_pose:
  if pending_from>=0 and mode=="primary":
   _sweep(pending_from,pending_until);pending_from=-1;pending_until=-1
  if pending_end:pending_end=false;_complete_action()
  return
 if mode=="hurt":
  elapsed+=delta
  if elapsed>=Profile.duration(action_id):finish_attack()
  return
 if mode=="dead":return
 if not is_attacking():
  if primary_held or hero.auto_attack_running():primary_attack()
  return
 var previous=elapsed;elapsed+=delta*hero.attack_speed_multiplier()
 hero.attack_left=maxf(.05,Profile.duration(action_id)-elapsed)
 if mode=="bazooka_charge":
  hero.attack_left=.05;lock_targets=_find_lock_targets()
  if elapsed+.000001>=.5 and not cue_done.has("charge"):
   cue_done["charge"]=true;_sound("yae_bazooka_charge")
  while elapsed+.000001>=next_charge_sound:
   _sound("yae_bazooka_charge_a" if charge_sustain_count%2==0 else "yae_bazooka_charge_b")
   charge_sustain_count+=1;next_charge_sound+=1.0
  return
 if mode=="shield":
  hero.attack_left=.05;shield_sound_clock+=delta
  while shield_sound_clock+.000001>=3.0/30.0:
   shield_sound_clock-=3.0/30.0;_sound("yae_shield")
  elapsed=fmod(elapsed,Profile.duration(action_id));return
 if mode=="primary":
  # Source event frames5/7/6+7; quantize with native30Hz action rate.
  var frames=([2] if action_id==0x6e else [5]) if combo==0 else ([7] if combo==1 else [6,7])
  for frame in frames:
   var cue_at=float(5 if frame==6 else 6)/30.0 if combo==2 else Profile.source_time(action_id,frame)
   if elapsed+.000001>=cue_at and not cue_done.has(frame):
    cue_done[frame]=true;_sound("yae_katana_%d"%(combo+1) if frame!=7 or combo!=2 else "yae_katana_3_follow")
  pending_from=previous;pending_until=minf(elapsed,Profile.duration(action_id))
 if mode in ["bazooka","lock_on"] and not contact_done and elapsed+.000001>=Profile.release_time(action_id):
  contact_done=true;_release_projectiles();_sound("yae_lock_on" if mode=="lock_on" else "yae_bazooka");_release_voice("move_charged_voice" if mode=="lock_on" else "move_secondary_voice")
 if elapsed+.000001>=Profile.duration(action_id):
  if mode=="primary":pending_end=true
  else:_complete_action()
func _complete_action():
 if mode=="primary" and action_id in Profile.combo_actions():
  if (primary_held or queued_primary or hero.auto_attack_running()) and combo<2:
   queued_primary=false;finish_attack();primary_attack();return
  action_id=0x6b+combo;mode="recovery";elapsed=0;hero.attack_duration=Profile.duration(action_id);return
 if mode=="shield_enter":
  if shield_held:_begin("shield",0x9d if action_id==0x9c else 0xa0)
  else:_begin("shield_exit",0x9e if action_id==0x9c else 0xa1)
  return
 finish_attack()
 if queued_primary or primary_held or hero.auto_attack_running():queued_primary=false;primary_attack()
func _find_lock_targets()->Array:
 var candidates=[];var origin=hero.global_position+Vector3.UP*1.3*hero.growth_multiplier()
 for enemy in game.enemies:
  if not is_instance_valid(enemy) or enemy.dead:continue
  var point=AttackChain.aim_point(enemy,origin);var offset=point-origin
  if offset.length()>6.5 or offset.normalized().dot(hero.facing)<.5 or not _clear_line(point):continue
  candidates.append(enemy)
 candidates.sort_custom(func(a,b):return hero.global_position.distance_squared_to(a.global_position)<hero.global_position.distance_squared_to(b.global_position))
 var result=[]
 for index in mini(3,candidates.size()):result.append(weakref(candidates[index]))
 return result
func _release_projectiles():
 var count=3 if mode=="lock_on" else 1
 var native_scale=.01515809
 if is_instance_valid(hero.model):native_scale=hero.model.source_scale
 lock_targets=_find_lock_targets()
 for index in count:
  var p=Projectile.new();p.hero=hero;p.game=game;p.kind=mode;p.attack_ticket=hero.attack_ticket.duplicate(true);p.damage_scale=hero.damage_multiplier();p.source_scale=native_scale
  p.speed=6.0*30.0*native_scale
  var direction=hero.facing
  if mode=="lock_on":
   if index<lock_targets.size():p.target=lock_targets[index]
   # Native80033898 pitch0/64/960, yaw976; source+X is actor-left.
   var source_direction=[Vector3(-.290284693,0,.956940293),Vector3(-.268188089,-.382683396,.884097517),Vector3(-.268188089,.382683396,.884097517)][index]
   var right=hero.facing.cross(Vector3.UP).normalized()
   direction=hero.facing*source_direction.z-right*source_direction.x+Vector3.UP*source_direction.y
  var muzzle=Vector3(-19.15,112.75,116.8300018)*native_scale
  if is_instance_valid(hero.model):p.position=hero.model.global_transform*(hero.model.rig_visual.transform*(muzzle+hero.model.source_offset))
  else:p.position=hero.global_position+Vector3.UP*1.3+hero.facing*.5
  p.velocity=Vector3.ZERO;p.native_acceleration=direction*(30.0*30.0*native_scale)
  p.hit_radius=30.0*native_scale;game.add_child(p)
func _sweep(from: float,until: float):
 if not is_instance_valid(hero.model) or until<from:return
 var source: Dictionary=Profile.data().get("collision_spheres",{}).get(str(action_id),{})
 if source.is_empty():return
 var root_now=hero.model.global_transform
 if not have_previous_root:previous_root=root_now;have_previous_root=true
 var count=clampi(ceili((until-from)*120.0),1,128)
 var previous_spheres=_source_spheres(source,from,previous_root);var scored=false
 for step in range(count+1):
  var fraction=float(step)/count;var at=lerpf(from,until,fraction)
  var spheres=_source_spheres(source,at,previous_root.interpolate_with(root_now,fraction))
  for index in spheres.size():
   var old: Dictionary=previous_spheres[index];var sphere: Dictionary=spheres[index]
   var radius=maxf(float(old.radius),float(sphere.radius))
   if radius>.00001 and _contact_segment(old.center,sphere.center,radius):scored=true
  previous_spheres=spheres
 previous_root=root_now
 if scored and not hero.ai_controlled:game.chain+=1;game.chain_timer=3.0
func _source_spheres(source: Dictionary,at: float,root_at: Transform3D)->Array:
 var frame=clampf(at*30.0*Profile.rate(action_id),0,float(source.frame_count)-1.0)
 var first=floori(frame);var second=mini(first+1,int(source.frame_count)-1);var weight=frame-first
 var result=[];var model=hero.model;var reach=reach_scale()
 var pose: Dictionary=model.sampler.sample_source(action_id,at) if not is_equal_approx(reach,1.0) else {}
 for index in int(source.count):
  var a: Dictionary=source.frames[first][index];var b: Dictionary=source.frames[second][index]
  var center=Vector3(a.center[0],a.center[1],a.center[2]).lerp(Vector3(b.center[0],b.center[1],b.center[2]),weight)
  if pose.has("0x9007478"):
   var anchor: Vector3=pose["0x9007478"]*Vector3(0,15,0);center=anchor+(center-anchor)*reach
  center=root_at*(model.rig_visual.transform*(center*model.source_scale+model.source_offset))
  var radius=lerpf(float(a.radius),float(b.radius),weight)*model.source_scale*root_at.basis.get_scale().abs().length()/sqrt(3.0)*reach
  result.append({"center":center,"radius":maxf(0,radius)})
 return result
func _contact_segment(from: Vector3,to: Vector3,radius: float)->bool:
 var scored=false
 for enemy in game.enemies:
  if not is_instance_valid(enemy) or enemy.dead or hero.struck_targets.has(enemy.get_instance_id()):continue
  var contact=AttackChain.segment_contact(enemy,from,to,radius)
  if contact.is_empty() or not _clear_line(contact.point):continue
  var point: Vector3=contact.point;hero.struck_targets[enemy.get_instance_id()]=true;hero.hit_done=true
  var direction=(point-hero.global_position).normalized()
  enemy.take_hit((30.0 if combo==2 else 22.0)*hero.damage_multiplier(),direction,combo==2,hero.attack_ticket)
  if hero.ai_controlled:game.confirm_ally_impact(enemy,point,direction,2 if combo==2 else 0,false,17)
  else:game.confirm_impact(enemy,point,direction,2 if combo==2 else 0,false,17)
  _sound("yae_katana_impact");scored=true
 return scored
func _clear_line(point: Vector3)->bool:
 var ray=PhysicsRayQueryParameters3D.create(hero.global_position+Vector3.UP*1.1*hero.growth_multiplier(),point,1);ray.exclude=[hero.get_rid()]
 return hero.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func _release_voice(fallback: String):
 if game.get("move_audio")!=null:game.move_audio.release(game,hero.attack_ticket)
 else:_sound(fallback)
func _sound(slot: String):game.sound(slot,.7,false,hero.attack_ticket,17)
func is_attacking()->bool:return not mode.is_empty() and mode not in ["hurt","dead"]
func pose_active()->bool:return not mode.is_empty() and mode!="bazooka_charge"
func blocks_movement()->bool:return false
func protects_player()->bool:return false
func blocks_projectile(_direction: Vector3)->bool:
 if not active or mode!="shield":return false
 _sound("yae_shield_block");return true
func can_hit_target(_enemy: Ninja)->bool:return false
func ground_attack_velocity()->Vector3:
 return Vector3.ZERO if mode in ["shield_enter","shield","shield_exit"] or (is_attacking() and mode!="bazooka_charge" and hero.is_on_floor()) else Vector3.INF
func reach_scale()->float:
 if not is_instance_valid(hero) or not is_instance_valid(game) or game.get("tuning")==null:return 1.0
 return hero.pickup_multiplier("range")*hero.melee_reach_setting()
func melee_reach()->float:
 var reach=reach_scale()
 if not is_equal_approx(reach,cached_reach_scale) and is_instance_valid(hero.model):
  var maximum=0.0
  for attack in Profile.combo_actions():
   var source: Dictionary=Profile.data().collision_spheres[str(attack)]
   for frame in int(source.frame_count):
    var pose: Dictionary=hero.model.sampler.sample_source(attack,float(frame)/(30.0*Profile.rate(attack)))
    var anchor: Vector3=pose["0x9007478"]*Vector3(0,15,0)
    for sphere in source.frames[frame]:
     var center=Vector3(sphere.center[0],sphere.center[1],sphere.center[2]);center=anchor+(center-anchor)*reach
     maximum=maxf(maximum,(center.z+float(sphere.radius)*reach)*hero.model.source_scale)
  cached_reach_scale=reach;cached_melee_reach=maximum*.9
 return cached_melee_reach*hero.growth_multiplier()
func finish_attack():
 mode="";elapsed=0;action_id=0;pending_from=-1;pending_until=-1;pending_end=false
 if is_instance_valid(hero):hero.attack_left=0
func cancel(_preserve_power: bool=false):
 primary_held=false;secondary_held=false;shield_held=false;queued_primary=false;combo_timer=0;combo=0;lock_targets.clear();finish_attack()
func hit():cancel();mode="hurt";action_id=0x1d;elapsed=0
func die():
 cancel();mode="dead";action_id=0x2d;elapsed=Profile.duration(action_id)
 if is_instance_valid(hero.model):hero.model.apply_native_pose(action_id,elapsed)
func interrupt_for_dodge():cancel()
