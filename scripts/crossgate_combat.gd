extends "res://scripts/recovered_enemy_combat.gd"
## Reuse exact local melee, cover checks, attack tickets and cancellation.
const ShineTiers=preload("res://scripts/spells/skill_effects.gd")
const DURATION=.6
const CUT_RADIUS=.42
const CUT_SWEEP=[-45.0,-30.0,-15.0,15.0,30.0,45.0]
const OUTER_REACH=5.6
const CUT_REACH=OUTER_REACH-CUT_RADIUS
const SHIN_PUNCH_REACH=2.0
const SHIN_DEFAULT_WEAPON_REACH=3.2
const SHIN_SWORD_REACH=5.2
const PRIMARY_RUSH_DISTANCE=5.0
const PRIMARY_RUSH_SPEED=32.0
const PRIMARY_SELECTION_DISTANCE=120.0
const PRIMARY_COMBO_WINDOW=5.0
const GUARD_REPLY_SPEED=1.5
const SKILL_LINK_SPEED=1.5
const GUARD_BREAK=preload("res://scripts/spells/spell_catalog.gd").GUARD_BREAK
const GUARD_BREAK_CHARGE=.20
const SHIN_POLEARM_REACH=6.6
const SHIN_COUNTER_GAP=2.0
const SHIN_COUNTER_MAX_CHAIN=9
const SHIN_COUNTER_DAMAGE=1500.0
const SHIN_SURE_DAMAGE=5000.0
const SURE_STRIKE_RADIUS=preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER*.5
const SHIN_SURE_SWORD_SPREAD=1.732051
const SHIN_SURE_HEIGHT=6.0
const SHIN_TWO_BIRDS_FRONT_REACH=15.0
const SHIN_TWO_BIRDS_FRONT_RADIUS=3.0
const SHIN_TWO_BIRDS_REAR_REACH=52.0
const SHIN_TWO_BIRDS_FRONT_DAMAGE=.75*SHIN_SURE_DAMAGE
const SHIN_TWO_BIRDS_REAR_DAMAGE=1.8*SHIN_SURE_DAMAGE
const SHIN_SKILL_COOLDOWN=5.0
const SHIN_MEDITATION_COOLDOWN=10.0
const Skills=preload("res://scripts/spells/skill_balance.gd")
const DAMAGE_SCALE=250.0/Roles.DATA[0].damage
# Original Kaz's two contacts follow the cut and the start of his authored flash.
const CONTACT=DURATION*5.0/11.0
const SECOND_CUT_CONTACT=DURATION*6.0/11.0
const DEFAULT_CUT_TIMES=[CONTACT,SECOND_CUT_CONTACT]
const CUT_GUARD_TAIL=.025
const COMBO_START_RANGE=32.0
const COMBO_RANGE=COMBO_START_RANGE
const COMBO_LIMIT=8
const SHIN_COMBO_LIMIT=7
const COMBO_TEMPO=1.8
const COMBO_SWING=DURATION*3.0/11.0
const COMBO_COOLDOWN=5.0
const BEE_FLURRY="bee/blink-flurry"
const BEE_FLURRY_RATE=1.5
const COMBO_CHARGE_FRAME_TIME=3.0/60
const COMBO_CHARGE_FRAMES=9
const SHIN_MEDITATION_FRAME_TIME=2.0/60
const SHIN_MEDITATION_FRAMES=7
const SHIN_SWING_LEAD=.18
const RANDOM_SHOT_COUNT=12
# Client state 18 selects a 33% bow animation clock for protocol 95 (亂射).
const RANDOM_SHOT_RATE=100.0/33.0
const RANDOM_SHOT_COOLDOWN=5.0
var sound_cues:Array=[]
var cut_times:Array=[]
var contact_cues:Array=[]
var cut_index=0
var shin_contact=0.0
var shin_swing=0.0
var shin_sure_cooldown=0.0
var shin_double_edge_cooldown=0.0
var shin_two_birds_cooldown=0.0
var shin_meditation_cooldown=0.0
var shin_counter_equipped=false
var shin_counter_armed:bool:
 get:return shin_counter_equipped and not hero.ai_controlled and hero.hp>0 and cast_model().current_weapon()=="polearm"
var shin_counter_chain=0
var shin_counter_gap=0.0
var shin_counter:Dictionary={}
var shin_counter_pending:Dictionary={}
var cut_guard_left=0.0
var kagerou_enabled=false
var combo_cooldown=0.0
var combo_target:Ninja
var combo_strikes=0
var combo_contacts=0
var random_shot_cooldown=0.0
var bow_primary_ticket:Dictionary={}
var bow_primary_cooldown=0.0
var mirrors:RefCounted
var mirror_cooldown=0.0
var primary_combo_hits=0
var primary_combo_left=0.0
var primary_combo_epoch=0
var primary_tab_target:WeakRef
var primary_hold_target:WeakRef

func ranged_projectile()->String:
 var weapon=cast_model().current_weapon()
 return "crossgate_boomerang" if weapon=="boomerang" else "water_dragon_dagger" if weapon=="kunai" else "crossgate_arrow"

func prepare_projectiles():
 if cast_model().fighter.strike=="throw":
  var cadence:float=cast_model().motions.clips["5:0"].duration
  var kind=ranged_projectile()
  Pool.service(game).warm(hero,Shot,kind,{"kind":kind},ceili(PI*projectile_range()/Shot.THROWN_SPEED/cadence)+2)
  return
 if cast_model().fighter.strike!="bow":
  super.prepare_projectiles()
  return
 if hero.RogueRoster.is_crossgate_archer(source_id()):prepare_shadow_mirrors()
 var cadence:float=cast_model().motions.clips["5:0"].duration
 var id:String=preload("res://scripts/spells/spell_catalog.gd").RANDOM_SHOT
 var count_=int(Skills.effective(hero,id,"count")) if Skills.all().has(id) else 1
 if mirrors!=null:mirrors.prepare_count()
 Pool.service(game).warm(hero,Shot,"crossgate_arrow",{"kind":"crossgate_arrow"},count_+ceili(count_/RANDOM_SHOT_RATE)+ceili(projectile_range()/Shot.THROWN_SPEED/cadence)+1)

func projectile_range()->float:return Shot.THROWN_RANGE*hero.pickup_multiplier("range")*float(hero.accessory_bonuses.get("range",1.0))

func bow_target(randomize:bool=false)->Ninja:
 var origin=hero.auto_aim_origin()
 if not randomize:return AttackChain.nearest_visible_target(hero,origin,projectile_range())
 var target:Ninja
 var count=0
 for enemy in AttackChain.enemy_candidates(game,origin,projectile_range()):
  if not is_instance_valid(enemy) or enemy.dead:continue
  if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
  var point=AttackChain.aim_point(enemy,origin)
  if origin.distance_to(point)>projectile_range() or not AttackChain.clear_line(hero,origin,point):continue
  count+=1
  if randi_range(1,count)==1:target=enemy
 return target

func start_random_shot(basic:bool=false):
 if hero.model.current_weapon()!="bow":return
 if cast_model().fighter.strike!="bow" or hero.hp<=0 or hero.dodge_time>0 or not hero.is_on_floor() or (is_attacking() and not primary_hit_can_link_skill()) or (not basic and random_shot_cooldown>0):return
 if bow_target()==null:return
 if not basic:
  if not hero.spend_skill_mana(Skills.Catalog.RANDOM_SHOT):return
  random_shot_cooldown=RANDOM_SHOT_COOLDOWN
 start_charge("lancelot_random_shot",1 if basic else 0)
 if basic:
  state.accessory_barrage=true
  if uses_primary_combo():
   prepare_primary_combo(ticket)
   state.barrage_combo_credit=ticket.primary_combo_credit
 if hero.mirror_copy and hero.get("shadow_barrage") and is_instance_valid(hero.shadow_source):
  var source:Hero=hero.shadow_source
  preload("res://scripts/spells/skill_balance.gd").decorate(source,ticket,"lancelot_random_shot")
  ticket.damage_multiplier=source.attack_chain.damage_multiplier()
  ticket.critical_chance=source.combat_tuning("critical_chance")
 state.barrage_left=skill_count(RANDOM_SHOT_COUNT,ticket)
 state.barrage_skill={}
 for key in ticket:
  if str(key).begins_with("skill_"):state.barrage_skill[key]=ticket[key]
 if hero.mirror_copy and hero.get("shadow_barrage"):
  state.barrage_skill.damage_multiplier=ticket.damage_multiplier
  state.barrage_skill.critical_chance=ticket.critical_chance

func prepare_shadow_mirrors():
 if not hero.mirror_copy and not hero.ai_controlled:
  if mirrors==null:mirrors=load("res://scripts/warcraft_mirrors.gd").new(hero,5,true)
  mirrors.prepare_count()

func start_shadow_mirrors():
 if hero.model.current_weapon()!="bow":return
 if mirrors==null or hero.hp<=0 or hero.dodge_time>0 or not hero.is_on_floor() or is_attacking() or mirror_cooldown>0:return
 if not hero.spend_skill_mana(Skills.Catalog.BARRAGE_SHADOWS):return
 if mirrors.cast():
  mirror_cooldown=preload("res://scripts/warcraft_kit.gd").MIRROR_COOLDOWN
  link_primary_combo()
  hero.play_sound("cg_mirror_charge",.8)
 else:
  hero.refund_skill_mana(Skills.Catalog.BARRAGE_SHADOWS)
  game.toast("Shadows need clear ground")

func _exit_tree():
 release_combo_target()
 if mirrors!=null:mirrors.dispose()

func ground_attack_velocity()->Vector3:
 if state.has("approach_velocity"):return state.approach_velocity
 return Vector3.INF if cast_model().fighter.strike=="bow" else super.ground_attack_velocity()

func is_attacking()->bool:
 return mode=="primary_approach" or super.is_attacking()

func uses_primary_combo()->bool:
 return spell_owner==null and not hero.ai_controlled and game.has_method("forest_enemy_visible")

func uses_primary_targeting()->bool:
 return spell_owner==null and not hero.ai_controlled and game.has_method("forest_enemy_visible") and hero.accessory_bonuses.get("primary","")!="fire"

func primary_is_ranged()->bool:
 return cast_model().current_weapon() in ["bow","kunai","boomerang"]

func primary_melee_length()->float:
 return shin_reach() if cast_model().fighter.strike=="timed" else CUT_REACH

func primary_reach()->float:
 return projectile_range() if primary_is_ranged() else (primary_melee_length()+CUT_RADIUS)*cast_model().basis.get_scale().x*hero.melee_range_multiplier()

func primary_combo_speed()->float:
 return minf(hero.ATTACK_SPEED_CAP,1.0+.1*primary_combo_hits)

func prepare_primary_combo(attack:Dictionary):
 if not uses_primary_combo():return
 attack.primary_combo_speed=primary_combo_speed()
 # Each projectile in a volley shares the same one-hit credit.
 attack.primary_combo_credit={"owner":get_instance_id(),"epoch":primary_combo_epoch,"spent":false}

func confirm_primary_combo(credit:Dictionary):
 if credit.spent or credit.owner!=get_instance_id() or credit.epoch!=primary_combo_epoch:return
 credit.spent=true
 primary_combo_hits+=1
 primary_combo_left=PRIMARY_COMBO_WINDOW

func link_primary_combo():
 if primary_combo_left<=0 or not uses_primary_combo():return
 primary_combo_left=PRIMARY_COMBO_WINDOW

func tick_primary_combo(delta:float):
 if primary_combo_left<=0:return
 primary_combo_left=maxf(0,primary_combo_left-delta)
 if primary_combo_left==0.0:reset_primary_combo()

func reset_primary_combo():
 primary_combo_hits=0
 primary_combo_left=0.0

func release_input(event:InputEvent):
 if event.is_action_released("light_attack"):primary_hold_target=null
 super.release_input(event)

func input(event:InputEvent):
 if active and not event.is_echo():
  var left_click=event.is_action_pressed("light_attack")
  if left_click and hero.timed_dodge.counter_attack():
   if uses_primary_targeting():hero.play_sound("shin_target_select",.65)
   return
  var slots:Dictionary=cast_model().native_skills
  for action_ in slots:
   if not event.is_action_pressed(action_):continue
   var skill:Array=slots[action_]
   if not skill[1].is_empty():callv(skill[1],skill.slice(2))
   return
  if uses_primary_targeting() and left_click:
   if hero.dodge_time<=0:
    var target=start_targeted_primary(true)
    if target!=null:primary_hold_target=weakref(target)
   return
  if left_click and can_guard_reply() and not is_attacking() and hero.dodge_time<=0:
   start_attack(false,false)
   if is_attacking():apply_guard_reply()
   return
 super.input(event)

func can_guard_reply()->bool:
 return spell_owner==null and hero.guard_reply_left>0 and not hero.defend_held and hero.is_on_floor()

func apply_guard_reply():
 ticket.guard_reply=true
 hero.guard_reply_left=0.0

func primary_target_offset(enemy:Ninja)->Vector3:
 if not is_instance_valid(enemy) or enemy.dead or enemy.hp<=0 or not game.forest_enemy_visible(enemy):return Vector3.INF
 var ranged=primary_is_ranged()
 var origin:Vector3=hero.auto_aim_origin() if ranged else hero.global_position+Vector3.UP*cast_model().basis.get_scale().y*hero.growth_multiplier()
 var point=AttackChain.aim_point(enemy,origin)
 if not AttackChain.clear_line(hero,origin,point):return Vector3.INF
 var offset=point-origin
 offset.y=0
 return offset

func primary_in_range(enemy:Ninja,direction:Vector3)->bool:
 if primary_is_ranged():
  var muzzle=hero.auto_aim_origin()
  return muzzle.distance_to(AttackChain.aim_point(enemy,muzzle))<=projectile_range()
 var scale_:Vector3=cast_model().basis.get_scale()
 var reach:float=hero.melee_range_multiplier()*scale_.x
 var origin:Vector3=hero.global_position+Vector3.UP*scale_.y*hero.growth_multiplier()
 return not AttackChain.segment_contact(enemy,origin,origin+direction*primary_melee_length()*reach,CUT_RADIUS*reach).is_empty()

func primary_click_target()->Dictionary:
 var enemy=locked_primary_enemy()
 var offset=primary_target_offset(enemy)
 if not offset.is_finite():
  primary_tab_target=null
  enemy=null if game.enemies.is_empty() else game.enemy_near_crosshair(PRIMARY_SELECTION_DISTANCE)
  offset=primary_target_offset(enemy)
 if not offset.is_finite() or offset.length()>PRIMARY_SELECTION_DISTANCE:return {}
 return {"enemy":enemy,"offset":offset}

func start_targeted_primary(allow_approach:bool,manual:bool=true,held:WeakRef=null)->Ninja:
 if hero.hp<=0 or mode=="dead" or game.model.phase!="wave" or hero.timed_dodge.reacting or hero.dodge_time>0 or hero.defend_held:return null
 if state.has("approach_skill") or state.has("next_area_skill"):return null
 var finishing=is_attacking() and mode!="primary_approach"
 if finishing and (not manual or not normal_swing()):return null
 if cast_model().fighter.strike=="bow" and bow_primary_cooldown>0:return null
 var enemy:Ninja
 var offset:Vector3
 if manual:
  var selection=primary_click_target()
  if selection.is_empty():return null
  enemy=selection.enemy
  offset=selection.offset
 else:
  enemy=held.get_ref() as Ninja if held!=null else locked_primary_enemy()
  offset=primary_target_offset(enemy)
 if held!=null and (not offset.is_finite() or offset.length()>PRIMARY_SELECTION_DISTANCE):primary_hold_target=null
 if not offset.is_finite() or (mode=="primary_approach" and enemy==selected_primary_enemy()) or offset.length()>PRIMARY_SELECTION_DISTANCE:return null
 var toward=hero.facing if offset.is_zero_approx() else offset.normalized()
 var in_range=primary_in_range(enemy,toward)
 if not in_range and (not allow_approach or not can_approach_primary()):return null
 if manual:hero.play_sound("shin_target_select",.65)
 if finishing:state.next_primary_target=weakref(enemy)
 elif in_range:start_selected_primary(toward,enemy,PRIMARY_RUSH_DISTANCE,allow_approach,manual)
 else:
  begin_primary_approach(enemy,toward)
  state.guard_reply_click=manual and can_guard_reply()
 return enemy

func normal_swing()->bool:
 return mode=="attack" and clip=="5" and ticket.has("primary_combo_credit") and not ticket.has("guard_break_target") and ticket.get("action","")!="lancelot_random_shot"

func start_guard_break():
 if not active or hero.ai_controlled or hero.hp<=0 or mode=="dead" or game.get("army_runtime")==null or game.model.phase!="wave" or not hero.is_on_floor() or hero.defend_held or hero.timed_dodge.reacting or hero.dodge_time>0 or primary_is_ranged():return
 if state.has("approach_skill"):return
 if is_attacking() and mode!="primary_approach":
  if not normal_swing() or ticket.get("guard_reply",false):return
 var selection=primary_click_target()
 if selection.is_empty():
  charge_guard_break(null,hero.combat_attack_direction(),0.0)
  return
 var toward:Vector3=hero.facing if selection.offset.is_zero_approx() else selection.offset.normalized()
 if primary_in_range(selection.enemy,toward):charge_guard_break(selection.enemy,toward,PRIMARY_RUSH_DISTANCE)
 elif can_approach_primary():begin_skill_approach(selection.enemy,toward,GUARD_BREAK)

func charge_guard_break(enemy:Ninja,toward:Vector3,rush_left:float):
 if not hero.spend_skill_mana(GUARD_BREAK):return
 primary_hold_target=null
 hero.facing=toward
 cast_model().rotation.y=atan2(-toward.x,-toward.z)
 start_charge(GUARD_BREAK)
 ticket.guard_break_target=weakref(enemy) if is_instance_valid(enemy) else null
 if is_instance_valid(enemy):track_selected_primary(enemy,rush_left)

func finish_guard_break():
 var charge_ticket=ticket
 start_selected_primary(hero.facing,selected_primary_enemy(),state.get("rush_left",0.0),false,false,true)
 if charge_ticket.has("guard_break_notice_target"):ticket.guard_break_notice_target=charge_ticket.guard_break_notice_target
 ticket.normal_attack_damage*=float(charge_ticket.skill_rules.damage)
 ticket.skill_damage=Skills.factor(charge_ticket,"damage")
 ticket.guard_break_scale=Skills.factor(charge_ticket,"size")
 if Skills.Levels.is_ex(charge_ticket):ticket.guard_break_ex=true

func start_selected_primary(direction:Vector3,enemy:Ninja,rush_left:float=PRIMARY_RUSH_DISTANCE,cycle_motion:bool=true,manual_reply:bool=false,guard_break:bool=false):
 if mode=="primary_approach":cancel(true)
 var reply=manual_reply and can_guard_reply()
 if not reply and not guard_break and hero.spell_loadout.accessory_attack():return
 start_basic_attack(direction,enemy)
 if reply:apply_guard_reply()
 if guard_break:
  ticket.guard_break_target=weakref(enemy) if is_instance_valid(enemy) else null
  primary_hold_target=null
 if cycle_motion:cast_model().advance_weapon_combo()
 if is_instance_valid(enemy):track_selected_primary(enemy,rush_left)

func track_selected_primary(enemy:Ninja,rush_left:float):
 state.primary_target=weakref(enemy)
 state.rush_left=rush_left

func selected_primary_enemy()->Ninja:
 var reference=state.get("primary_target")
 if reference==null:return null
 return reference.get_ref() as Ninja

func locked_primary_enemy()->Ninja:
 if primary_tab_target==null:return null
 var enemy=primary_tab_target.get_ref() as Ninja
 if not uses_primary_targeting() or not is_instance_valid(enemy) or enemy.dead or enemy.hp<=0 or hero.global_position.distance_squared_to(enemy.global_position)>PRIMARY_SELECTION_DISTANCE*PRIMARY_SELECTION_DISTANCE:
  primary_tab_target=null
  return null
 return enemy

func cycle_primary_lock():
 var camera:Camera3D=game.camera_rig.camera
 var origin:Vector3=hero.global_position
 var candidates:Array[Ninja]=[]
 for enemy in AttackChain.enemy_candidates(game,origin,PRIMARY_SELECTION_DISTANCE):
  if not is_instance_valid(enemy) or not enemy is Ninja:continue
  var offset=primary_target_offset(enemy)
  if not offset.is_finite() or offset.length_squared()>PRIMARY_SELECTION_DISTANCE*PRIMARY_SELECTION_DISTANCE:continue
  var point:Vector3=AttackChain.effect_anchor(enemy).position
  if camera.is_position_in_frustum(point) and AttackChain.clear_line(hero,camera.global_position,point):candidates.append(enemy)
 candidates.sort_custom(func(a:Ninja,b:Ninja):
  var distance_a=origin.distance_squared_to(a.global_position)
  var distance_b=origin.distance_squared_to(b.global_position)
  return a.get_instance_id()<b.get_instance_id() if distance_a==distance_b else distance_a<distance_b)
 var next=candidates.find(locked_primary_enemy())+1
 var selected:Ninja=candidates[next] if next<candidates.size() else null
 primary_tab_target=weakref(selected) if selected!=null else null
 if selected!=null:hero.play_sound("shin_target_select",.65)

func can_approach_primary()->bool:
 return game.model.phase=="wave" and hero.is_on_floor() and hero.velocity.y<=0 and hero.jump_buffer<=0 and hero.jump_windup<=0 and hero.dodge_time<=0 and not hero.defend_held and not hero.timed_dodge.reacting

func primary_manual_move()->bool:
 var move:Vector2=hero.smoke_move if hero.smoke_mode else Input.get_vector("move_left","move_right","move_forward","move_back")
 return move.length_squared()>.01

func begin_primary_approach(enemy:Ninja,direction:Vector3):
 hero.facing=direction
 mode="primary_approach"
 clip=""
 ticket={}
 track_selected_primary(enemy,PRIMARY_RUSH_DISTANCE)
 state.approach_velocity=Vector3.ZERO
 state.approach_rushing=false

func begin_skill_approach(enemy:Ninja,direction:Vector3,skill:String):
 # Replace the normal attack intent before moving so a held click cannot fire on arrival.
 hero.interrupt_attack_for_movement()
 begin_primary_approach(enemy,direction)
 primary_hold_target=null
 state.approach_skill=skill

func stop_primary_approach(complete_guard_break:bool=false):
 if mode!="primary_approach":return
 var finish_attempt=complete_guard_break and state.get("approach_skill","")==GUARD_BREAK
 primary_hold_target=null
 var enemy=selected_primary_enemy()
 cancel(true)
 if finish_attempt:
  charge_guard_break(null,hero.facing,0.0)
  if ticket.has("guard_break_target") and is_instance_valid(enemy):ticket.guard_break_notice_target=weakref(enemy)

func tick_primary_approach(delta:float):
 if not can_approach_primary() or primary_manual_move():
  stop_primary_approach()
  return
 var enemy=selected_primary_enemy()
 var offset=primary_target_offset(enemy)
 if not offset.is_finite() or offset.length()>PRIMARY_SELECTION_DISTANCE:
  stop_primary_approach(true)
  return
 var direction=offset.normalized() if not offset.is_zero_approx() else hero.facing
 var skill:String=state.get("approach_skill","")
 if primary_in_range(enemy,direction):
  if not skill.is_empty():
   var rush_left:float=state.rush_left
   cancel(true)
   if skill==GUARD_BREAK:charge_guard_break(enemy,direction,rush_left)
   else:charge_shin_area_skill(skill,direction,enemy,rush_left)
  else:start_selected_primary(direction,enemy,state.rush_left,true,state.get("guard_reply_click",false))
  return
 if not move_toward_primary_target(offset,direction,delta):stop_primary_approach(true)

func move_toward_primary_target(offset:Vector3,direction:Vector3,delta:float)->bool:
 var dashing=not primary_is_ranged() and float(hero.accessory_bonuses.get("attack_dash",0))>0
 var rushing=dashing or (state.rush_left>0.0 and offset.length()<=primary_reach()+PRIMARY_RUSH_DISTANCE)
 var speed=PRIMARY_RUSH_SPEED if rushing else hero.combat_tuning("sprint_speed")*hero.movement_multiplier()
 if dashing:speed*=hero.movement_multiplier()
 var distance=minf(speed*delta,offset.length())
 if rushing and not dashing:distance=minf(distance,state.rush_left)
 var from:Vector3=hero.global_position
 var next=combo_landing(from,from+direction*distance) if distance>0.0 else Vector3.INF
 if not next.is_finite() or absf(next.y-from.y)>.32:return false
 hero.facing=direction
 state.approach_velocity=direction*distance/delta
 state.approach_rushing=rushing
 state.approach_dashing=dashing
 if rushing and not dashing:state.rush_left-=distance
 return true

func controls_primary_facing()->bool:
 return mode=="primary_approach" or (mode=="attack" and state.has("primary_target") and not state.get("primary_committed",false))

func track_primary_windup(delta:float)->bool:
 var enemy=selected_primary_enemy()
 var offset=primary_target_offset(enemy)
 var guard_break=ticket.has("guard_break_target")
 if not offset.is_finite() or offset.length()>PRIMARY_SELECTION_DISTANCE:
  if guard_break:
   state.erase("approach_velocity")
   return true
  cancel(true)
  return false
 var direction=offset.normalized() if not offset.is_zero_approx() else hero.facing
 hero.facing=direction
 cast_model().rotation.y=atan2(-direction.x,-direction.z)
 if guard_break or primary_in_range(enemy,direction):
  state.erase("approach_velocity")
  return true
 # Hold the current swing until its target is back within actual contact reach.
 if primary_manual_move() or not can_approach_primary() or not move_toward_primary_target(offset,direction,delta):
  cancel(true)
 return false

func summon_cave_bears():
 if hero.character_id!=hero.RogueRoster.BOG_ID or hero.hp<=0 or not game.has_method("forest_enemy_visible") or not is_instance_valid(game.army_runtime) or game.army_runtime.blocked():return
 if not hero.spend_skill_mana(Skills.Catalog.BEARS):return
 game.army_runtime.queue_cave_bears()

func toggle_kagerou():
 if not kagerou_enabled and not hero.spend_skill_mana(Skills.Catalog.KAGEROU):return
 hero.attack_chain.kazi_combo_streak=0
 kagerou_enabled=not kagerou_enabled
 hero.play_sound("cg_kagerou_dodge")

func swap_weapon():
 if not active or hero.hp<=0 or not mode.is_empty() or not cast_model().can_swap_stance():return
 primary_hold_target=null
 clear_shin_counter()
 cast_model().swap_stance()
 if not hero.ai_controlled and spell_owner==null:game.save_skin_equipment(hero.character_id,{"weapon":cast_model().shin_weapon_index})
 if not hero.ai_controlled:hero.spell_loadout.refresh_numbered_slots()
 if not hero.ai_controlled:game.toast(hero.RogueRoster.name_for(hero.character_id)+" · "+str(cast_model().motions.weapon).capitalize())

func cancel(preserve_power:bool=false):
 if is_instance_valid(cast_model()) and cast_model().get("weapon_combo_step")!=null:
  cast_model().weapon_combo_step=-1
  if not preserve_power:cast_model().weapon_combo_next=0
 if state.has("approach_velocity"):
  hero.velocity.x=0
  hero.velocity.z=0
 release_combo_target()
 if state.has("bee_origin"):
  var origin:Vector3=state.bee_origin;state.erase("bee_origin")
  if not hero.test_move(Transform3D(hero.global_basis,origin),Vector3.ZERO):bee_blink(origin)
 bow_primary_ticket={}
 if not preserve_power:bow_primary_cooldown=0.0
 if is_attacking() and clip=="6" and cast_model().combo_glow!=null:cast_model().combo_glow.hide()
 if is_attacking() and ticket.get("action","")=="kazi_combo" and cast_model().kagerou_dash_left>0:cast_model().clear_kagerou_dodge()
 if spell_owner!=null and hero.model.has_method("clear_kagerou_dodge"):hero.model.clear_kagerou_dodge()
 if spell_owner!=null and hero.model.locomotion.get("dirty")!=null:hero.model.locomotion.dirty=true
 combo_target=null
 super.cancel(preserve_power)
 if not preserve_power:
  primary_tab_target=null
  primary_hold_target=null
  primary_combo_epoch+=1
  reset_primary_combo()
  if mirrors!=null:mirrors.clear()
  disable_kagerou()
  clear_shin_counter()

func release_combo_target():
 if is_instance_valid(combo_target) and combo_target.has_method("release_sequence"):combo_target.release_sequence()

func hold_combo_target(enemy:Ninja):
 release_combo_target()
 combo_target=enemy
 if combo_target.has_method("retain_sequence"):combo_target.retain_sequence()

func combo_target_valid()->bool:
 return is_instance_valid(combo_target) and (not combo_target.dead or (combo_target.get("sequence_defeated")==true and combo_target.sequence_users>0))

func sequence_contact(from:Vector3,to:Vector3,radius:float)->Dictionary:
 return combo_target.sequence_contact(from,to,radius) if combo_target.has_method("sequence_contact") else AttackChain.segment_contact(combo_target,from,to,radius)

func disable_kagerou():
 kagerou_enabled=false
 cast_model().clear_kagerou_dodge()

func clear_cooldowns():
 mirror_cooldown=0.0
 random_shot_cooldown=0.0
 combo_cooldown=0.0;shin_sure_cooldown=0.0
 shin_double_edge_cooldown=0.0
 shin_two_birds_cooldown=0.0
 shin_meditation_cooldown=0.0

func reset_shin_counter_chain():
 shin_counter_chain=0
 shin_counter_gap=0.0

func clear_shin_counter():
 reset_shin_counter_chain()
 if cast_model().stat_counter_shadow!=null:cast_model().stat_counter_shadow.hide()
 if (not shin_counter.is_empty() or cast_model().shin_counter_linger>0) and not cast_model().kagerou_shadows.is_empty():cast_model().kagerou_shadows[0].hide()
 cast_model().shin_counter_linger=0.0
 shin_counter.clear()
 shin_counter_pending.clear()
 if cast_model().shin_counter_fx!=null:cast_model().shin_counter_fx.hide()

func shin_cast_planted()->bool:
 return is_attacking() and not state.has("approach_velocity") and ticket.get("action","") in ["shin_sure_strike","shin_two_birds","shin_meditation"]

func shin_counter_rate()->float:
 return 1.0+.25*maxi(0,shin_counter_chain-1)

func primary_hit_can_link_skill()->bool:
 return mode=="attack" and ticket.has("primary_combo_credit") and ticket.primary_combo_credit.spent

func start_shin_area_cast(two_birds:bool=false):
 if two_birds and hero.model.current_weapon()!="polearm":return
 if hero.ai_controlled or hero.hp<=0 or hero.dodge_time>0 or hero.defend_held or hero.timed_dodge.reacting or not hero.is_on_floor() or state.has("approach_skill"):return
 var must_finish=is_attacking() and mode!="primary_approach" and not primary_hit_can_link_skill()
 if must_finish and (two_birds or not normal_swing()):return
 var skill="shin/two-birds" if two_birds else Skills.Catalog.DOUBLE_EDGE if Skills.Levels.family(Skills.identify(hero,"shin_sure_strike"))=="double-edge" else Skills.Catalog.SURE_STRIKE
 if not area_skill_ready(skill) or not hero.can_pay_skill(skill,true):return
 var selection=primary_click_target() if not two_birds and game.has_method("forest_enemy_visible") and game.model.phase=="wave" else {}
 var target:WeakRef=weakref(selection.enemy) if not selection.is_empty() else null
 var toward:Vector3=hero.combat_attack_direction() if selection.is_empty() else hero.facing if selection.offset.is_zero_approx() else selection.offset.normalized()
 if must_finish:
  state.next_area_skill={"id":skill,"target":target,"direction":toward}
  state.erase("next_primary_target")
  primary_hold_target=null
  return
 dispatch_shin_area_skill(skill,toward,target)

func dispatch_shin_area_skill(skill:String,direction:Vector3,target:WeakRef):
 if target==null:
  charge_shin_area_skill(skill,direction)
  return
 var enemy=target.get_ref() as Ninja
 var offset=primary_target_offset(enemy)
 if not offset.is_finite() or offset.length()>PRIMARY_SELECTION_DISTANCE:return
 var toward=direction if offset.is_zero_approx() else offset.normalized()
 if primary_in_range(enemy,toward):charge_shin_area_skill(skill,toward,enemy)
 elif can_approach_primary():begin_skill_approach(enemy,toward,skill)

func area_skill_ready(skill:String)->bool:
 if skill==Skills.Catalog.DOUBLE_EDGE:return shin_double_edge_cooldown<=0
 if skill==Skills.Catalog.SURE_STRIKE:return shin_sure_cooldown<=0
 return shin_two_birds_cooldown<=0

func charge_shin_area_skill(skill:String,direction:Vector3,enemy:Ninja=null,rush_left:float=PRIMARY_RUSH_DISTANCE):
 if not area_skill_ready(skill) or not hero.spend_skill_mana(skill):return
 primary_hold_target=null
 var two_birds=skill=="shin/two-birds"
 if two_birds:
  shin_two_birds_cooldown=SHIN_SKILL_COOLDOWN
 elif skill==Skills.Catalog.DOUBLE_EDGE:
  shin_double_edge_cooldown=SHIN_SKILL_COOLDOWN
 else:
  shin_sure_cooldown=SHIN_SKILL_COOLDOWN
 reset_shin_counter_chain()
 hero.facing=direction
 cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
 hero.attack_chain.kazi_combo_streak=0
 var previous_skill:String=hero.spell_loadout.casting_id
 if not two_birds:hero.spell_loadout.casting_id=skill
 start_charge("shin_two_birds" if two_birds else "shin_sure_strike")
 hero.spell_loadout.casting_id=previous_skill
 if not two_birds and ticket.get("skill_rules",{}).has("defense_penalty"):
  hero.double_edge_left=10.0;hero.double_edge_penalty=float(ticket.skill_rules.defense_penalty)
 if not two_birds:ticket.shin_blast_forward=hero.facing
 if enemy!=null:track_selected_primary(enemy,rush_left)

func start_shin_meditation():
 if hero.ai_controlled or hero.hp<=0 or hero.dodge_time>0 or not hero.is_on_floor() or (is_attacking() and not primary_hit_can_link_skill()) or shin_meditation_cooldown>0:return
 if not hero.spend_skill_mana(Skills.Catalog.MEDITATION):return
 shin_meditation_cooldown=SHIN_MEDITATION_COOLDOWN
 reset_shin_counter_chain()
 hero.attack_chain.kazi_combo_streak=0
 start_charge("shin_meditation")

func finish_shin_meditation():
 var amount=maxf(0.0,hero.max_hp-hero.hp)*clampf(float(ticket.get("skill_healing",.05)),0.0,1.0)
 hero.hp+=amount
 if game.get("crowd")!=null:
  var at=hero.global_position+Vector3.UP*(cast_model().standing_height()-.6)
  game.crowd.army.presentation.label_damage(at,amount,false,false,true,hero)
 hero.play_sound("cg_shin_meditation_heal",1.0,ticket)
 cancel(true)

func counter_after_hit(direction:Vector3,source:int,basic:bool=false,after_dodge:bool=false,counter_origin:Vector3=Vector3.INF)->bool:
 if basic:
  if hero.ai_controlled or hero.hp<=0 or (not after_dodge and randf()*100>=hero.combat_tuning("counter_chance")):return false
 elif not shin_counter_armed or not hero.can_pay_skill(Skills.Catalog.COUNTER):return false
 if not basic:
  shin_counter_chain=mini(SHIN_COUNTER_MAX_CHAIN,shin_counter_chain+1)
  shin_counter_gap=SHIN_COUNTER_GAP
 var origin:Vector3=counter_origin if after_dodge and counter_origin.is_finite() else hero.global_position
 var target:Ninja=game.army_runtime.enemy_target(source) if source>0 and game.get("army_runtime")!=null else null
 if basic and source<=0 and not after_dodge:
  target=AttackChain.nearest_visible_target(hero,origin,melee_visual_reach() if cast_model().fighter.strike not in ["bow","throw"] and not cast_model().daggers else projectile_range())
 if basic and (not is_instance_valid(target) or target.dead):return false
 var toward=target.global_position-origin if is_instance_valid(target) else -direction
 toward.y=0
 var facing:Vector3=hero.facing if toward.is_zero_approx() else toward.normalized()
 var basis=Basis(Vector3.UP,atan2(-facing.x,-facing.z))
 var counter={"origin":origin,"basis":basis,"facing":facing,"source":source,"target":target,"hits_done":0,"basic":basic,"after_dodge":after_dodge}
 if after_dodge and not shin_counter.is_empty():return false
 if shin_counter.is_empty():begin_shin_counter(counter)
 # Keep the newest attacker ready without restarting the shadow's swing.
 else:shin_counter_pending=counter
 return true

func begin_shin_counter(counter:Dictionary):
 var basic:bool=counter.basic
 if not basic and not hero.spend_skill_mana(Skills.Catalog.COUNTER,false):return
 var pattern=cast_model().normal_attack_pattern(counter.facing) if basic else {}
 var attack:Dictionary=pattern.attack if basic else cast_model().motions.clips["5:%d"%cast_model().direction_for(counter.facing)]
 counter.attack=attack
 counter.elapsed=0.0
 counter.marker=0
 counter.ticket=hero.attack_chain.make_ticket("stat_counter" if basic else "shin_counter")
 if basic:
  counter.contact=float(pattern.contacts[0])
  counter.swing=float(pattern.sounds[0]) if not pattern.sounds.is_empty() else counter.contact*.5
  counter.reach=shin_reach() if cast_model().fighter.strike=="timed" else CUT_REACH
  if counter.get("after_dodge",false):counter.reach*=1.5
  counter.damage=Skills.basic_damage(pattern,hero)
  counter.projectile=""
  if int(pattern.pose)==7:counter.projectile="maze_dagger"
  elif cast_model().fighter.strike in ["bow","throw"]:counter.projectile=ranged_projectile()
  counter.swing_sound=shin_sound(false,0,attack) if hero.RogueRoster.is_crossgate_fighter(hero.character_id) else null
  counter.hit_sound=shin_sound(true,0,attack,true) if hero.RogueRoster.is_crossgate_fighter(hero.character_id) else null
  counter.ticket.crossgate_sound_source=hero.character_id
 else:
  counter.contact=float(attack.duration)*float(attack.contact)
  counter.swing=minf(float(attack.duration)*float(attack.swing),maxf(.001,counter.contact-SHIN_SWING_LEAD))
  counter.ticket.impact_scale*=1.5
 shin_counter=counter
 cast_model().show_shin_counter(counter.origin,attack,basic)
 if basic:return
 var glow:Sprite3D=cast_model().shin_counter_fx
 var cell=glow.texture.get_size()/Vector2(glow.hframes,glow.vframes)
 glow.scale*=preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER/(maxf(cell.x,cell.y)*glow.pixel_size*glow.global_basis.get_scale().x)*Skills.shine_factor(counter.ticket)
 hero.play_sound("cg_shin_counter",1.0,counter.ticket)

func tick_shin_counter(delta:float):
 shin_counter_gap=maxf(0,shin_counter_gap-delta)
 if shin_counter_gap==0:shin_counter_chain=0
 var rate=1.0 if shin_counter.get("basic",false) else shin_counter_rate()
 cast_model().tick_shin_counter(delta,rate)
 if shin_counter.is_empty():return
 var counter=shin_counter
 counter.elapsed+=delta*hero.attack_speed_multiplier()*rate
 if counter.marker==0 and counter.elapsed>=counter.swing:
  counter.marker=1
  hero.play_sound("swing",.8,counter.ticket,counter.swing_sound if counter.basic else shin_sound(false))
 if counter.marker==1 and counter.elapsed>=counter.contact:
  counter.marker=2
  var target=counter.target
  if (not counter.basic and counter.source<=0) or (is_instance_valid(target) and not target.dead):
   if counter.basic:
    if not counter.projectile.is_empty():
     var origin:Vector3=counter.origin+Vector3.UP*hero.model.standing_height()*.55
     var toward=AttackChain.aim_point(target,origin)-origin
     var direction:Vector3=counter.facing if toward.is_zero_approx() else toward.normalized()
     var config={"kind":counter.projectile,"position":origin,"velocity":direction*Shot.THROWN_SPEED,"lifetime":projectile_range()/Shot.THROWN_SPEED,"damage":counter.damage*hero.damage_multiplier(),"attack_ticket":counter.ticket}
     if cast_model().motions.get("water_dragon",false):config.impact_sound=counter.hit_sound
     if counter.projectile=="crossgate_boomerang":config.boomerang_reach=clampf(toward.length(),2,projectile_range())
     Pool.service(game).launch(hero,Shot,counter.projectile,config)
    else:
     strike(Vector3.UP,Vector3(0,1,-counter.reach),CUT_RADIUS*cast_model().basis.get_scale().x,counter.damage/Roles.DATA[0].damage,-1.0,counter.origin,0,[],counter.hit_sound,counter)
   else:
    var area=counter.duplicate();area.erase("target")
    strike(Vector3.UP,Vector3.UP,SURE_STRIKE_RADIUS,
           Skills.damage(hero,counter.ticket,SHIN_COUNTER_DAMAGE)/Roles.DATA[0].damage,-1.0,counter.origin,1,[],shin_sound(true),area)
 if counter.elapsed<float(counter.attack.duration):
  cast_model().pose_shin_counter(counter.attack,counter.elapsed)
  return
 counter.hits_done+=1
 if not counter.basic and counter.hits_done<skill_count(1,counter.ticket) and (counter.source<=0 or (is_instance_valid(counter.target) and not counter.target.dead)):
  counter.elapsed=0.0;counter.marker=0
  return
 cast_model().pose_shin_counter(counter.attack,float(counter.attack.duration))
 cast_model().shin_counter_linger=.3
 shin_counter={}
 if not shin_counter_pending.is_empty():
  var pending=shin_counter_pending
  shin_counter_pending={}
  begin_shin_counter(pending)

func start_combo():
 if hero.ai_controlled or hero.hp<=0 or hero.dodge_time>0 or combo_cooldown>0 or not hero.is_on_floor():return
 if is_attacking() and ticket.get("action","")=="kazi_combo":return
 var hop=next_combo_hop({},COMBO_START_RANGE)
 if hop.is_empty():return
 if not hero.spend_skill_mana(Skills.Catalog.COMBO):return
 combo_strikes=0
 combo_contacts=0
 start_charge("kazi_combo")
 hold_combo_target(hop.enemy)

func bee_start_range()->float:
 var ability=hero.active_ability
 var ranged=hero.model.current_weapon() in ["bow","kunai","boomerang"]
 return 2.0*(ability.dagger_range() if hero.model.daggers and ability.has_method("dagger_range") else ability.projectile_range() if ranged else ability.melee_visual_reach())

func start_bee_flurry():
 if hero.hp<=0 or hero.dodge_time>0 or combo_cooldown>0 or not hero.is_on_floor():return
 var hop=next_combo_hop({},bee_start_range())
 if hop.is_empty():return
 if not hero.spend_skill_mana(Skills.Catalog.BEE_FLURRY):return
 start_charge(BEE_FLURRY)
 hold_combo_target(hop.enemy);combo_strikes=0
 state.bee_origin=hero.global_position;state.bee_side=Vector3.ZERO
 combo_cooldown=COMBO_COOLDOWN

func bee_blink(point:Vector3):
 for at in [hero.global_position,point]:game.crowd.army.presentation.add_effect("smoke",at+Vector3.UP*.6,.28,1.35)
 hero.global_position=point;hero.reset_physics_interpolation();hero.velocity=Vector3.ZERO
 hero.play_sound("maze_assassination_vanish",.8,ticket)

func bee_next_hop()->bool:
 if not combo_target_valid():return false
 var feet:Vector3=combo_target.global_position
 var previous:Vector3=state.bee_side
 for attempt in 8:
  var angle=randf()*TAU if previous.is_zero_approx() else atan2(previous.x,previous.z)+PI+randf_range(-PI/3,PI/3)
  var side=Vector3(sin(angle),0,cos(angle))
  var contact=AttackChain.contact_point(combo_target,feet+side*100+Vector3.UP,feet+Vector3.UP)
  var landing=combo_landing(hero.global_position,Vector3(contact.x,feet.y,contact.z)+side*1.15)
  if not landing.is_finite() or not AttackChain.clear_line(hero,landing+Vector3.UP,AttackChain.aim_point(combo_target,landing+Vector3.UP)):continue
  var actual=Vector3(landing.x-feet.x,0,landing.z-feet.z).normalized()
  if not previous.is_zero_approx() and actual.dot(previous)>-.5:continue
  state.bee_side=actual;bee_blink(landing);hero.facing=-actual
  cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
  state.combo_pattern=hero.model.normal_attack_pattern()
  state.combo_sound=0
  clip=str(state.combo_pattern.pose);elapsed=0;pose_tick=0;marker=0
  duration=float(state.combo_pattern.contacts[0])+.1
  hero.attack_duration=duration;hero.attack_left=duration
  combo_strikes+=1
  return true
 return false

func tick_bee_flurry(delta:float):
 if clip=="6":
  if tick_charge(delta*BEE_FLURRY_RATE) and not bee_next_hop():cancel(true)
  return
 if not combo_target_valid():cancel(true);return
 elapsed+=delta*BEE_FLURRY_RATE*float(ticket.get("shin_cast_speed",1.0));pose_tick=elapsed*30;hero.attack_left=maxf(0,duration-elapsed)
 if state.combo_sound==0 and not state.combo_pattern.sounds.is_empty() and elapsed>=float(state.combo_pattern.sounds[0]):
  state.combo_sound=1
  hero.play_sound("swing",.8,ticket,shin_sound(false))
 if marker==0 and elapsed>=float(state.combo_pattern.contacts[0]):
  marker=1
  var from:Vector3=hero.global_position+Vector3.UP
  var aim=AttackChain.aim_point(combo_target,from)
  var reach=maxf(hero.melee_strike_reach(),SHIN_DEFAULT_WEAPON_REACH)*skill_factor("hit_area",ticket)
  var hit=sequence_contact(from,from+hero.facing*reach,CUT_RADIUS*skill_factor("hit_area",ticket))
  if not hit.is_empty() and AttackChain.clear_line(hero,from,aim):
   if combo_target.dead:combo_target.overkill_feedback(ticket)
   else:combo_target.take_hit(Skills.damage(hero,ticket,250.0)*hero.damage_multiplier(),hero.facing,false,ticket)
   game.confirm_impact(combo_target,hit.point,hero.facing,0,false,hero.character_id,false,shin_sound(true,0,state.combo_pattern.attack,true))
 if elapsed>=duration:
  if combo_strikes>=5 or not bee_next_hop():cancel(true)

func start_charge(action_:String,level_override:int=0):
 hero.interrupt_attack_for_movement()
 ticket=hero.attack_chain.begin(action_)
 if level_override>0:Skills.decorate(hero,ticket,action_,level_override)
 mode="attack";clip="6";elapsed=0.0;pose_tick=0.0
 cut_times=[];contact_cues=[]
 var meditation=action_=="shin_meditation"
 var guard_break=action_==GUARD_BREAK
 cast_model().set_shin_charge_art(meditation)
 duration=GUARD_BREAK_CHARGE if guard_break else COMBO_CHARGE_FRAMES*COMBO_CHARGE_FRAME_TIME
 if meditation:
  var cast:Dictionary=cast_model().motions.clips.get("6:0",{})
  duration=float(cast.get("duration",duration))
  state.meditation_release=float(cast.get("release",duration))
 hero.attack_duration=duration;hero.attack_left=duration
 var speed=hero.spell_loadout.primary_combo_cast_speed()
 if speed>1.0:ticket.shin_cast_speed=speed
 link_primary_combo()
 var glow:Sprite3D=cast_model().combo_glow
 if meditation:ShineTiers.meditation_shine(glow,ticket)
 else:ShineTiers.physical_shine(glow,ticket)
 var prepared_size=(342.0 if meditation else 357.0)*glow.pixel_size*glow.get_parent().global_basis.get_scale().x
 var shine_scale=1.25*Skills.factor(ticket,"size") if guard_break else Skills.shine_factor(ticket)
 glow.scale=Vector3.ONE*(Skills.BASE_DIAMETER/prepared_size)*shine_scale
 glow.global_position=hero.model.qi_blast_chest()
 if action_=="kazi_combo":
  for key in ["combo_charge_size","combo_effect_height","combo_splash_radius"]:ticket[key]=game.balance_value(source_id(),key) if spell_owner!=null else hero.combat_tuning(key)
  glow.scale*=ticket.combo_charge_size
 glow.frame=0
 glow.modulate.a=.35 if game.settings.get("reduced_flashes",false) else 1.0
 glow.show()
 var cue:String={
  BEE_FLURRY:"cg_combo_charge",
  "kazi_combo":"cg_combo_charge",
  "lancelot_random_shot":"cg_random_shot_charge",
  GUARD_BREAK:"cg_guard_break_charge",
  "shin_two_birds":"cg_shin_two_birds_charge", "shin_meditation":"cg_shin_meditation",
  "shin_sure_strike":"cg_shin_double_edge_charge" if ticket.get("skill_rules",{}).has("defense_penalty") else "cg_shin_sure_strike_charge"
 }[action_]
 hero.play_sound(cue,.6 if meditation else .8,ticket)

func tick_charge(delta:float)->bool:
 cast_model().combo_glow.global_position=hero.model.qi_blast_chest()
 elapsed+=delta*float(ticket.get("shin_cast_speed",1.0))
 hero.attack_left=maxf(0,duration-elapsed)
 if hero.attack_left>.00001:
  if ticket.action=="shin_meditation":
   if elapsed<state.meditation_release:cast_model().combo_glow.frame=floori(elapsed/SHIN_MEDITATION_FRAME_TIME)%SHIN_MEDITATION_FRAMES
   elif cast_model().combo_glow.visible:cast_model().combo_glow.hide()
  else:cast_model().combo_glow.frame=ShineTiers.charge_frame(ticket,elapsed/(GUARD_BREAK_CHARGE/COMBO_CHARGE_FRAMES if ticket.action==GUARD_BREAK else COMBO_CHARGE_FRAME_TIME),9,12)
  return false
 cast_model().combo_glow.hide()
 return true

func next_combo_hop(visited:Dictionary,range_:float=COMBO_RANGE,locked_target:Ninja=null,behind:bool=false)->Dictionary:
 var from:Vector3=hero.global_position
 var best={}
 var nearest=range_*range_
 var candidates=[locked_target] if locked_target!=null else AttackChain.enemy_candidates(game,from,range_)
 for enemy in candidates:
  var overkill=enemy==locked_target and enemy==combo_target and combo_target_valid()
  if not is_instance_valid(enemy) or (enemy.dead and not overkill) or visited.has(enemy.get_instance_id()):continue
  if not overkill and game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
  var feet:Vector3=enemy.global_position
  var distance=from.distance_squared_to(feet)
  if distance>nearest:continue
  var direction=Vector3(feet.x-from.x,0,feet.z-from.z).normalized()
  if direction.is_zero_approx():direction=hero.facing
  var side=from+Vector3.UP
  if behind:
   var yaw=enemy.get("_yaw")
   # Baked army meshes and billboard sprites face local -Z. Skullpion uses +Z.
   var forward=Vector3.BACK if enemy.variant==Roles.BOSS else Vector3.FORWARD
   direction=forward.rotated(Vector3.UP,enemy.global_rotation.y if yaw==null else float(yaw))
   side=feet+Vector3.UP-direction*(range_+1.0)
  var contact=AttackChain.contact_point(enemy,side,feet+Vector3.UP)
  var beside=combo_landing(from,Vector3(contact.x,feet.y,contact.z)-direction*1.15)
  if not beside.is_finite() or not AttackChain.clear_line(hero,from+Vector3.UP,Vector3(feet.x,contact.y,feet.z)):continue
  var exit=Vector3.INF
  if behind:
   exit=combo_pass_exit(beside,enemy,direction)
   if not exit.is_finite():continue
  nearest=distance
  best={"enemy":enemy,"position":beside,"direction":direction,"exit":exit}
 return best

func combo_pass_exit(from:Vector3,enemy:Ninja,direction:Vector3)->Vector3:
 var feet:Vector3=enemy.global_position
 var front=AttackChain.contact_point(enemy,feet+Vector3.UP+direction*(COMBO_START_RANGE+1.0),feet+Vector3.UP)
 return combo_landing(from,Vector3(front.x,feet.y,front.z)+direction*1.15)

func combo_landing(from:Vector3,point:Vector3)->Vector3:
 if not game.world.playable_bounds.grow(-2.0*hero.growth_multiplier()).has_point(Vector2(point.x,point.z)):return Vector3.INF
 var ground=AttackChain.world_ray(hero,point+Vector3.UP*1.5,point-Vector3.UP*1.5)
 if ground.is_empty() or ground.normal.y<.65:return Vector3.INF
 point=ground.position+Vector3.UP*.05
 if absf(point.y-from.y)>2.0:return Vector3.INF
 if game.has_method("forest_enemy_visible") and game.world.submerged(point):return Vector3.INF
 var raised=Transform3D(hero.global_basis,from+Vector3.UP*.3)
 if hero.test_move(raised,point-from) or hero.test_move(Transform3D(raised.basis,point),Vector3.ZERO):return Vector3.INF
 return point

func dash_to_combo_target(hop:Dictionary):
 combo_strikes+=1
 hold_combo_target(hop.enemy)
 hits[combo_target.get_instance_id()]=true
 if spell_owner!=null:
  if hero.model.has_method("show_kagerou_dash") and hero.model.kagerou_shadows.size()>=3:hero.model.show_kagerou_dash(hop.position-hero.global_position)
  else:
   for point in [hero.global_position,hop.position]:game.crowd.army.presentation.add_effect("smoke",point+Vector3.UP*.6,.28,1.35)
 else:cast_model().show_kagerou_dash(hop.position-hero.global_position)
 hero.global_position=hop.position
 hero.reset_physics_interpolation()
 hero.velocity=Vector3.ZERO
 hero.facing=hop.direction
 cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
 mode="attack";clip="5";elapsed=0.0;pose_tick=0.0
 if hero.RogueRoster.is_crossgate_fighter(hero.character_id):
  state.combo_pattern=hero.model.normal_attack_pattern()
  clip=str(state.combo_pattern.pose);duration=state.combo_pattern.duration
 else:
  state.combo_pattern={"contacts":[CONTACT],"sounds":[COMBO_SWING],"duration":SECOND_CUT_CONTACT}
  duration=SECOND_CUT_CONTACT
 state.combo_contact=0;state.combo_sound=0
 hero.attack_duration=duration;hero.attack_left=duration

func tick_combo(delta:float):
 if clip=="6":
  if not tick_charge(delta):return
  var first=next_combo_hop({},COMBO_START_RANGE,combo_target if combo_target_valid() and combo_target.dead else null) if hero.is_on_floor() else {}
  if first.is_empty():cancel(true)
  else:
   ticket.kazi_combo_multiplier=1.0+.5*hero.attack_chain.kazi_combo_streak
   hero.attack_chain.kazi_combo_streak+=1
   combo_cooldown=COMBO_COOLDOWN
   dash_to_combo_target(first)
  return
 elapsed+=delta*COMBO_TEMPO*float(ticket.get("shin_cast_speed",1.0))
 pose_tick=elapsed*30
 hero.attack_left=maxf(0,duration-elapsed)
 var splash:bool=cast_model().fighter.get("weapon_skills",false)
 var timed:bool=cast_model().fighter.strike=="timed"
 var weapon_timed:bool=timed or hero.RogueRoster.is_crossgate_fighter(hero.character_id)
 var swing_cue="kojiro_sword_cut" if spell_owner!=null and hero.character_id==28 else Dark.slot_for("claw") if spell_owner!=null and hero.character_id==29 else "swing"
 var impact_cue=Dark.slot_for("contact_a") if spell_owner!=null and hero.character_id==29 else "coin_hit" if spell_owner!=null and hero.RogueRoster.is_crossgate_archer(hero.character_id) else "hit"
 while state.combo_sound<state.combo_pattern.sounds.size() and elapsed>=float(state.combo_pattern.sounds[state.combo_sound]):
  state.combo_sound+=1
  hero.play_sound(swing_cue,.8 if timed else .5,ticket,shin_sound(false,state.combo_sound-1) if weapon_timed else null)
 while state.combo_contact<state.combo_pattern.contacts.size() and elapsed>=float(state.combo_pattern.contacts[state.combo_contact]):
  state.combo_contact+=1
  if ticket.has("skill_rules") and combo_contacts>=skill_count(COMBO_LIMIT,ticket):break
  combo_contacts+=1
  if not combo_target_valid():continue
  var from:Vector3=hero.global_position+Vector3.UP
  var aim_point=AttackChain.aim_point(combo_target,from)
  var reach=(SHIN_DEFAULT_WEAPON_REACH+CUT_RADIUS)*cast_model().basis.get_scale().x*hero.melee_range_multiplier() if splash else maxf(melee_visual_reach(),(SHIN_DEFAULT_WEAPON_REACH+CUT_RADIUS)*cast_model().basis.get_scale().x)
  var area=skill_factor("hit_area",ticket)
  var contact=sequence_contact(from,from+hero.facing*reach*area,CUT_RADIUS*area)
  if not contact.is_empty() and AttackChain.clear_line(hero,from,aim_point):
   ticket.combo_hit_size=ticket.combo_effect_height*skill_factor("size",ticket)
   ticket.combo_hit_shin=splash or Skills.Levels.is_ex(ticket)
   ticket.responsive_recoil=true
   var damage=Skills.damage(hero,ticket,Roles.stats(role).damage*DAMAGE_SCALE*1.5*ticket.kazi_combo_multiplier/state.combo_pattern.contacts.size())*hero.damage_multiplier()*(float(ticket.kazi_combo_multiplier) if ticket.has("skill_rules") else 1.0)
   var center:Vector3=combo_target.global_position
   center.y=aim_point.y
   if splash:ticket.shin_area_impact=true
   var overkill=combo_target.dead
   if combo_target.dead:combo_target.overkill_feedback(ticket)
   else:combo_target.take_hit(damage,hero.facing,false,ticket)
   game.confirm_impact(combo_target,contact.point,hero.facing,0,false,hero.character_id,false,shin_sound(true,state.combo_contact-1) if weapon_timed else null,true,impact_cue)
   if not overkill and ticket.combo_splash_radius>0:shin_combo_splash(center,damage)
 if elapsed<duration and combo_target_valid():return
 var hop={}
 if (combo_contacts if ticket.has("skill_rules") else combo_strikes)<skill_count(SHIN_COMBO_LIMIT if splash else COMBO_LIMIT,ticket) and hero.velocity.y<=0:
  hop=next_combo_hop({},COMBO_RANGE,combo_target) if combo_target_valid() and combo_target.dead else next_combo_hop(hits)
  if (splash or ticket.has("skill_rules")) and hop.is_empty():hop=next_combo_hop({})
 if hop.is_empty():cancel(true)
 else:dash_to_combo_target(hop)

func combo_progress()->float:
 if clip=="6":return -1.0
 return elapsed/CONTACT if elapsed<CONTACT else 1.0+(elapsed-CONTACT)/maxf(.001,duration-CONTACT)

func shin_combo_splash(center:Vector3,damage:float):
 var radius:float=ticket.combo_splash_radius*hero.melee_range_multiplier()*skill_factor("hit_area",ticket)
 AttackChain.damage_splash(hero,combo_target,center,radius,damage,ticket)

func start_attack(_heavy:bool=false,allow_accessories:bool=true):
 if mode=="dead" or hero.hp<=0:return
 var style:String=cast_model().fighter.strike
 if is_attacking():
  if state.get("accessory_barrage",false):return
  if style=="bow" and ticket.get("action","")=="lancelot_random_shot" and bow_primary_ticket.is_empty() and bow_primary_cooldown<=0:
   bow_primary_ticket=hero.attack_chain.begin("crossgate_bow")
   bow_primary_ticket.normal_attack_damage=Skills.basic_damage(cast_model().normal_attack_pattern(),hero)
   bow_primary_ticket.crossgate_sound_source=hero.character_id
   prepare_primary_combo(bow_primary_ticket)
  return
 if allow_accessories and spell_owner==null and not state.has("barrage_left") and hero.spell_loadout.accessory_attack():return
 if style=="bow" and not state.has("barrage_left") and bow_primary_cooldown>0:return
 start_basic_attack(hero.combat_attack_direction())

func start_basic_attack(direction:Vector3,selected:Ninja=null):
 if mode=="primary_approach":cancel(true)
 var style:String=cast_model().fighter.strike
 if style in ["bow","throw"]:
  var origin=hero.auto_aim_origin()
  var target=selected if selected!=null else bow_target(state.has("barrage_left"))
  fire_target=weakref(target) if target!=null else null
  if target!=null:
   direction=AttackChain.aim_point(target,origin)-origin;direction.y=0
   direction=direction.normalized() if not direction.is_zero_approx() else hero.facing
 prepare_attack_pose(direction)
 var key="5:%d"%cast_model().direction()
 var attack:Dictionary=cast_model().body_clip(5,key)
 duration=float(attack.duration)
 clip="5";sound_cues=attack.get("sounds",[])
 cut_times=attack.get("contacts",DEFAULT_CUT_TIMES if style=="cuts" else [])
 contact_cues=attack.get("contact_cues",[])
 cut_index=0
 if style=="timed":
  reset_shin_counter_chain()
  prepare_shin_strike(false)
 ticket=hero.attack_chain.begin("crossgate_throw" if style=="throw" else "crossgate_bow" if style=="bow" else "shin_basic" if style=="timed" else "uru_staff" if style=="staff" else "kazi_sword")
 ticket.normal_attack_damage=Skills.basic_damage(cast_model().normal_attack_pattern(),hero)
 if style in ["bow","throw"]:ticket.crossgate_sound_source=hero.character_id
 if style=="bow" and state.has("barrage_left"):
  ticket.action="lancelot_random_shot"
  ticket.merge(state.barrage_skill,true)
  if state.has("barrage_combo_credit"):ticket.primary_combo_credit=state.barrage_combo_credit
 else:prepare_primary_combo(ticket)
 if spell_owner==null and not state.has("barrage_left"):
  ticket.sword_repeat=int(hero.accessory_bonuses.get("sword_repeat",0))
  var fire_level=int(hero.accessory_bonuses.get("sword_fire",0))
  if fire_level>0:
   var fire=ticket.duplicate()
   fire.action="sword_fire";fire.magical=true
   Skills.decorate(hero,fire,"kazi/fire",fire_level)
   fire.erase("primary_combo_credit")
   ticket.sword_fire_ticket=fire
   ticket.sword_fire_damage=hero.magic_spell_damage(float(fire.skill_rules.base_damage))
   ticket.sword_fire_height=hero.model.standing_height()*1.1*4.0
 hero.attack_duration=duration;hero.attack_left=duration

func release_bow(shot_ticket:Dictionary,target_ref:WeakRef):
 var origin=hero.auto_aim_origin()
 var direction=hero.facing
 var target=target_ref.get_ref() if target_ref!=null else null
 if is_instance_valid(target) and not target.dead:
  var offset=AttackChain.aim_point(target,origin)-origin
  if not offset.is_zero_approx():direction=offset.normalized()
 var kind=ranged_projectile()
 var config={"kind":kind,"position":origin,"velocity":direction*Shot.THROWN_SPEED,"lifetime":projectile_range()/Shot.THROWN_SPEED,"damage":float(shot_ticket.get("normal_attack_damage",250.0))*hero.damage_multiplier(),"attack_ticket":shot_ticket.duplicate()}
 if shot_ticket.get("action","")=="shin_sure_strike":
  config.damage=Skills.damage(hero,shot_ticket,SHIN_SURE_DAMAGE)*hero.damage_multiplier()
  config.attack_ticket.sure_strike_size=preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER*skill_factor("size",shot_ticket)
  config.attack_ticket.sure_strike_polearm=shot_ticket.get("skill_rules",{}).has("defense_penalty")
  if config.attack_ticket.sure_strike_polearm:config.attack_ticket.sure_strike_size/=float(shot_ticket.skill_rules.get("size",1.0))
  config.attack_ticket.crossgate_sound_source=hero.character_id
 elif shot_ticket.get("action","")=="lancelot_random_shot":config.damage=Skills.damage(hero,shot_ticket,250.0)*hero.damage_multiplier()
 if cast_model().motions.get("water_dragon",false):config.impact_sound=shin_sound(true)
 if kind=="crossgate_boomerang":
  var reach=origin.distance_to(AttackChain.aim_point(target,origin)) if is_instance_valid(target) and not target.dead else projectile_range()
  config.boomerang_reach=clampf(reach,2,projectile_range())
 Pool.service(game).launch(hero,Shot,kind,config)

func start_sure_strike_attack():
 var charged=ticket
 var enemy=selected_primary_enemy()
 var direction:Vector3=hero.facing if enemy!=null else charged.get("shin_blast_forward",hero.facing)
 mode=""
 # The receiving controller owns its animation, contacts, sounds and projectiles.
 if enemy!=null:start_basic_attack(direction,enemy)
 else:start_attack(false,false)
 ticket=charged;hero.attack_chain.active_ticket=ticket
 hero.facing=direction;cast_model().rotation.y=atan2(-direction.x,-direction.z)
 var contacts=maxi(1,cut_times.size())
 if cast_model().fighter.strike=="staff":contacts=maxi(1,sound_cues.filter(func(cue):return int(cue.id)==139).size())
 ticket.sure_strike_damage=Skills.damage(hero,ticket,SHIN_SURE_DAMAGE/contacts)
 ticket.sure_strike_size=preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER*skill_factor("size",ticket)
 if ticket.get("skill_rules",{}).has("defense_penalty"):ticket.sure_strike_size/=float(ticket.skill_rules.get("size",1.0))
 ticket.sure_strike_polearm=ticket.get("skill_rules",{}).has("defense_penalty")
 ticket.impact_scale*=1.5
 if source_id()==hero.RogueRoster.SHIN_ID and int(cast_model().motions.get("source_id",0))==100053:
  # Default sword contact frame: midpoint is low, ahead of the crouched body.
  ticket.sure_strike_contact=hero.global_position+(Vector3.UP*.5+direction*2.6)*hero.model.global_basis.x.length()

func prepare_shin_strike(lead_swing:bool=true):
 if cast_model().fighter.strike=="bow":
  var target=bow_target()
  fire_target=weakref(target) if target!=null else null
  if target!=null:
   var direction=AttackChain.aim_point(target,hero.auto_aim_origin())-hero.auto_aim_origin();direction.y=0
   if not direction.is_zero_approx():prepare_attack_pose(direction.normalized())
 var attack:Dictionary=cast_model().motions.clips["5:%d"%cast_model().direction()]
 duration=float(attack.duration)
 var bow=cast_model().fighter.strike=="bow"
 shin_contact=float(attack.release) if bow else duration*float(attack.contact)
 shin_swing=float(attack.draw) if bow else duration*float(attack.swing)
 if lead_swing and cast_model().motions.weapon!="unarmed":shin_swing=minf(shin_swing,maxf(.001,shin_contact-SHIN_SWING_LEAD))
 clip="5"
 hero.attack_duration=duration;hero.attack_left=duration

func shin_sound(contact:bool,index:int=0,attack:Dictionary={},single_contact:bool=false)->AudioStream:
 var visual=hero.model if spell_owner!=null and hero.RogueRoster.is_crossgate_fighter(hero.character_id) else cast_model()
 var prepared:AudioStream=visual.single_strike_sound(attack) if contact and single_contact else visual.attack_sound(contact,index,attack)
 if prepared!=null:return prepared
 if not visual.gear_sounds.is_empty() and visual.motions.has("weapon"):
  var motion:Dictionary=visual.motions.clips["5:%d"%visual.direction()]
  var cues:Array=motion.get("contact_cues",[]) if contact else motion.get("sounds",[])
  if not cues.is_empty():return visual.gear_sounds.get(int(cues[0]) if contact else int(cues[0].id))
 if visual.current_weapon()=="bow":return SoundLibrary.CROSSGATE_BOW_SOUNDS.coin_hit if contact else SoundLibrary.CROSSGATE_BOW_SOUNDS.swing
 return SoundLibrary.shin_weapon_sound(visual.current_weapon(),int(visual.motions.get("source_id",0)),contact)

func prepare_attack_pose(direction:Vector3):
 if spell_owner==null:hero.crossgate_attack_serial+=1
 hero.facing=direction
 cast_model().rotation.y=atan2(-hero.facing.x,-hero.facing.z)
 elapsed=0;pose_tick=0;hits.clear();marker=0;mode="attack";reaction=0;cut_guard_left=0;wind_contact=0

func tick(delta:float,after_pose:bool=false):
 if after_pose:return
 if mode=="primary_approach":
  tick_primary_approach(delta)
  return
 if mode.is_empty() and uses_primary_targeting():
  if hero.spell_loadout.primary_skill_busy():return
  if primary_hold_target!=null:start_targeted_primary(true,false,primary_hold_target)
  if mode=="primary_approach":return
 if not uses_primary_targeting() and hero.auto_attack_running() and ticket.get("action","")=="lancelot_random_shot":start_attack()
 if is_attacking():
  var action_:String=ticket.get("action","")
  if action_==BEE_FLURRY:
   tick_bee_flurry(delta)
   return
  if action_==GUARD_BREAK and clip=="6":
   if state.has("primary_target"):track_primary_windup(delta)
   if tick_charge(delta):finish_guard_break()
   return
  if action_=="lancelot_random_shot" and clip=="6":
   if tick_charge(delta):mode="";start_attack()
   return
  if action_=="kazi_combo":
   tick_combo(delta)
   return
  if clip=="6" and action_ in ["shin_sure_strike","shin_two_birds","shin_meditation"]:
   if state.has("primary_target") and not track_primary_windup(delta):return
   if tick_charge(delta):
    if action_=="shin_sure_strike":start_sure_strike_attack()
    elif action_=="shin_two_birds":
     prepare_attack_pose(hero.facing)
     prepare_shin_strike()
     ticket.impact_scale*=1.5
    elif action_=="shin_meditation":finish_shin_meditation()
    else:cancel(true)
   return
 if not is_attacking() and mode!="dead" and hero.auto_attack_running():
  if uses_primary_targeting():start_targeted_primary(false,false)
  else:start_attack()
 if not is_attacking():return
 advance_attack(delta)

func primary_attack_tempo()->float:
 var rate=RANDOM_SHOT_RATE if ticket.get("action","")=="lancelot_random_shot" else float(ticket.get("primary_combo_speed",ticket.get("shin_cast_speed",1.0)))
 var speed=hero.attack_speed_multiplier()*rate
 if ticket.get("guard_reply",false) or ticket.has("guard_break_target"):return minf(hero.ATTACK_SPEED_CAP,speed*GUARD_REPLY_SPEED)
 if state.has("next_area_skill"):return minf(hero.ATTACK_SPEED_CAP,speed*SKILL_LINK_SPEED)
 return minf(speed,hero.ATTACK_SPEED_CAP) if ticket.has("primary_combo_speed") or ticket.has("shin_cast_speed") else speed

func finish_primary_swing():
 var next:WeakRef=state.get("next_primary_target")
 var skill:Dictionary=state.get("next_area_skill",{})
 var repeat=0 if ticket.has("guard_break_target") or ticket.get("guard_reply",false) else int(ticket.get("sword_repeat",0))
 var direction=hero.facing
 var target=selected_primary_enemy()
 if ticket.has("guard_break_target") and not ticket.get("guard_break_connected",false):
  var target_ref:WeakRef=ticket.get("guard_break_notice_target",ticket.guard_break_target)
  var missed_target=target_ref.get_ref() if target_ref!=null else null
  if is_instance_valid(missed_target) and not missed_target.dead:
   game.crowd.army.presentation.guard_break_notice("Miss",missed_target.combat_head(),target_ref)
 cancel(true)
 if not skill.is_empty():
  if hero.is_on_floor() and not hero.defend_held:dispatch_shin_area_skill(skill.id,skill.direction,skill.target)
 elif repeat>0 and hero.hp>0 and not hero.defend_held:
  start_basic_attack(direction,target if is_instance_valid(target) and not target.dead else null)
  ticket.sword_repeat=repeat-1
 elif next!=null:start_targeted_primary(true,false,next)

func advance_attack(delta:float):
 if controls_primary_facing() and not track_primary_windup(delta):return
 elapsed+=delta*primary_attack_tempo();pose_tick=elapsed*30
 hero.attack_left=maxf(0,duration-elapsed)
 var style:String=cast_model().fighter.strike
 if style in ["bow","throw"]:
  var shot:Dictionary=cast_model().motions.clips["5:%d"%cast_model().direction()]
  if marker==0 and elapsed>=float(shot.draw):
   marker=1;hero.play_sound("swing",.8,ticket,shin_sound(false))
  if marker==1 and elapsed>=float(shot.release):
   marker=2
   state.primary_committed=true
   if style=="bow":hero.play_sound("throw",.8,ticket,shin_sound(true))
   release_bow(ticket,fire_target)
   if not bow_primary_ticket.is_empty():
    var target=bow_target()
    release_bow(bow_primary_ticket,weakref(target) if target!=null else null)
    bow_primary_ticket={};bow_primary_cooldown=duration
  if elapsed>=duration:
   if state.get("barrage_left",0)>1:
    state.barrage_left-=1;mode="";start_attack()
   else:
    var primary=bow_primary_ticket
    if primary.is_empty():finish_primary_swing()
    else:
     cancel(true)
     start_attack();ticket=primary;hero.attack_chain.active_ticket=primary
  return
 if style=="timed" and cut_times.is_empty():
  if marker==0 and elapsed>=shin_swing:
   marker=1
   hero.play_sound("swing",.8 if cast_model().motions.weapon!="unarmed" else .5,ticket,shin_sound(false))
  if marker==1 and elapsed>=shin_contact:
   marker=2
   state.primary_committed=true
   shin_strike_contact()
  if marker==2 and state.has("rear_at") and elapsed>=state.rear_at:
   marker=3
   shin_two_birds_rear(state.rear_origin)
  if elapsed>=duration:finish_primary_swing()
  return
 while marker<sound_cues.size() and elapsed>=float(sound_cues[marker].atMs)/1000:
  var cue:Dictionary=sound_cues[marker]
  marker+=1
  if style=="staff" and int(cue.id)==139:
   state.primary_committed=true
   hits.clear()
   strike(Vector3(0,1,0),Vector3(0,1,-CUT_REACH),CUT_RADIUS*cast_model().basis.get_scale().x,DAMAGE_SCALE*.4,-1.0,Vector3.INF,0,CUT_SWEEP,shin_sound(true))
  else:hero.play_sound("swing",.8 if style=="timed" else .5,ticket,shin_sound(false,marker-1))
 while style in ["cuts","timed"] and cut_index<cut_times.size() and elapsed>=float(cut_times[cut_index]):
  state.primary_committed=true
  cut_index+=1
  hits.clear()
  if style=="timed":
   var sound=shin_sound(true,cut_index-1)
   strike(Vector3.UP,Vector3(0,1,-shin_reach()),CUT_RADIUS*cast_model().basis.get_scale().x,Skills.normal_damage(hero)/Roles.DATA[0].damage,-1.0,Vector3.INF,0,[],sound)
  else:strike_cut()
 if elapsed>=duration:finish_primary_swing()

func shin_strike_contact():
 if ticket.action=="shin_two_birds":
  shin_two_birds_front()
  return
 strike(Vector3.UP,Vector3(0,1,-shin_reach()),CUT_RADIUS*cast_model().basis.get_scale().x,DAMAGE_SCALE,-1.0,Vector3.INF,0,[],shin_sound(true))

func shin_two_birds_front():
 var origin:Vector3=hero.global_position
 var from=origin+Vector3.UP*hero.growth_multiplier()
 var scale_:float=cast_model().basis.get_scale().x*hero.melee_range_multiplier()*skill_factor("hit_area",ticket)/float(ticket.get("skill_rules",{}).get("hit_area",1.0))
 var reach=SHIN_TWO_BIRDS_FRONT_REACH*scale_
 var radius=SHIN_TWO_BIRDS_FRONT_RADIUS*scale_
 var to=from+hero.facing*reach
 var front:Ninja=null
 var nearest=INF
 var at=Vector3.ZERO
 for enemy in AttackChain.segment_enemy_candidates(game,from,to,radius):
  if not is_instance_valid(enemy) or enemy.dead or hero.facing.dot(enemy.global_position-origin)<=0:continue
  if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
  var contact=AttackChain.segment_contact(enemy,from,to,radius)
  if contact.is_empty() or contact.t>=nearest or not AttackChain.clear_line(hero,from,AttackChain.aim_point(enemy,from)):continue
  nearest=contact.t;front=enemy;at=contact.point
 if front==null:return
 hits[front.get_instance_id()]=true
 state.rear_origin=front.global_position
 ticket.shin_area_impact=true
 front.take_hit(Skills.damage(hero,ticket,SHIN_TWO_BIRDS_FRONT_DAMAGE)*hero.damage_multiplier(),hero.facing,true,ticket)
 hero.play_sound("hit",.65,ticket,shin_sound(true))
 game.confirm_impact(front,at,hero.facing,2,false,hero.character_id,false,SoundLibrary.SHIN_TWO_BIRDS_IMPACT)
 state.rear_at=shin_contact+(38.0 if front.dead else 24.0)/60.0
 duration=maxf(duration,state.rear_at+.12)
 hero.attack_duration=duration
 if game.get("crowd")!=null:
  var height:float=cast_model().standing_height()*skill_factor("size",ticket)/float(ticket.get("skill_rules",{}).get("size",1.0))
  game.crowd.army.presentation.two_birds_burst(at+Vector3.UP*height*.5,height,false,Skills.Levels.is_ex(ticket))

func shin_two_birds_rear(origin:Vector3):
 var depth=SHIN_TWO_BIRDS_REAR_REACH*skill_factor("hit_area",ticket)*cast_model().basis.get_scale().x*hero.melee_range_multiplier()
 var forward:Vector3=hero.facing
 var side=forward.cross(Vector3.UP)
 var from=origin+Vector3.UP*hero.growth_multiplier()
 ticket.shin_area_impact=true
 for enemy in AttackChain.enemy_candidates(game,from,depth):
  if not is_instance_valid(enemy) or enemy.dead or hits.has(enemy.get_instance_id()):continue
  var offset:Vector3=enemy.global_position-origin
  if absf(offset.y)>SHIN_SURE_HEIGHT*hero.growth_multiplier():continue
  offset.y=0
  var along=forward.dot(offset)
  if along<=0 or along>depth or offset.length_squared()>depth*depth or absf(side.dot(offset))>along*SHIN_SURE_SWORD_SPREAD:continue
  if game.has_method("forest_enemy_visible") and not game.forest_enemy_visible(enemy):continue
  var contact=AttackChain.aim_point(enemy,from)
  var feet:Vector3=enemy.global_position
  if not AttackChain.clear_line(hero,from,Vector3(feet.x,contact.y,feet.z)):continue
  var secondary=Skills.normal_damage(hero)*float(ticket.skill_rules.secondary_damage) if ticket.get("skill_rules",{}).has("secondary_damage") else SHIN_TWO_BIRDS_REAR_DAMAGE
  enemy.take_hit(secondary*hero.damage_multiplier(),offset.normalized(),true,ticket)
  game.confirm_impact(enemy,contact,forward,2,false,hero.character_id,true,null,false)
 if game.get("crowd")==null:return
 var height:float=cast_model().standing_height()*skill_factor("size",ticket)
 for anchor in [Vector2(0,.22),Vector2(-.30,.57),Vector2(.30,.57)]:
  var at=from+(forward*anchor.y+side*anchor.x)*depth
  if AttackChain.clear_line(hero,from,at):game.crowd.army.presentation.two_birds_burst(at+Vector3.UP*height,height,true,Skills.Levels.is_ex(ticket))

func strike_cut():
 cut_guard_left=CUT_GUARD_TAIL
 ticket.responsive_recoil=true
 strike(Vector3(0,1,0),Vector3(0,1,-CUT_REACH),CUT_RADIUS*cast_model().basis.get_scale().x,DAMAGE_SCALE,-1.0,Vector3.INF,0,CUT_SWEEP,shin_sound(true,maxi(0,cut_index-1)))
 ticket.erase("responsive_recoil")

func shin_reach()->float:
 var weapon:String=cast_model().motions.weapon
 var source=int(cast_model().motions.source_id)
 if weapon=="polearm" or source==100055 or source==108313:return SHIN_POLEARM_REACH
 if weapon=="sword" or source==100053 or source==106707:return SHIN_SWORD_REACH
 if weapon=="staff":return CUT_REACH
 return SHIN_PUNCH_REACH if weapon=="unarmed" else SHIN_DEFAULT_WEAPON_REACH

func melee_visual_reach()->float:
 if cast_model().fighter.strike in ["bow","throw"]:return 0.0
 var reach=shin_reach()+CUT_RADIUS if cast_model().fighter.strike=="timed" else OUTER_REACH
 return reach*cast_model().basis.get_scale().x*hero.melee_range_multiplier()

func tick_timers(delta:float):
 mirror_cooldown=maxf(0,mirror_cooldown-delta)
 bow_primary_cooldown=maxf(0,bow_primary_cooldown-delta*hero.attack_speed_multiplier())
 random_shot_cooldown=maxf(0,random_shot_cooldown-delta)
 combo_cooldown=maxf(0,combo_cooldown-delta)
 shin_sure_cooldown=maxf(0,shin_sure_cooldown-delta)
 shin_double_edge_cooldown=maxf(0,shin_double_edge_cooldown-delta)
 shin_two_birds_cooldown=maxf(0,shin_two_birds_cooldown-delta)
 shin_meditation_cooldown=maxf(0,shin_meditation_cooldown-delta)
 cut_guard_left=maxf(0,cut_guard_left-delta)
 if mode=="hurt":
  elapsed+=delta
  if elapsed>=(duration if cast_model().fighter.strike!="cuts" else .3):cancel(true)

func guard_threat()->int:
 if not is_attacking() or clip!="5" or ticket.has("guard_break_target"):return 0
 var contact=shin_contact if cast_model().fighter.strike=="timed" else float(cut_times[0]) if not cut_times.is_empty() else duration*.5
 if elapsed>=contact:return 0
 return hero.crossgate_attack_serial

func combo_protected()->bool:
 return not hero.ai_controlled and is_attacking() and ticket.get("action","")=="kazi_combo"

func protects_player()->bool:
 if is_attacking() and ticket.get("action","")==BEE_FLURRY:return true
 if combo_protected():return true
 if cast_model().fighter.strike!="cuts" or hero.ai_controlled or not is_attacking() or clip!="5":return false
 # Native contacts can arrive before the player's step advances the cut.
 if cut_guard_left>0:return true
 if cut_index>=cut_times.size():return false
 var speed=primary_attack_tempo() if ticket.get("guard_reply",false) or ticket.has("guard_break_target") or state.has("next_area_skill") else hero.attack_speed_multiplier()
 return elapsed+speed/Engine.physics_ticks_per_second>=float(cut_times[cut_index])
func hit():
 cancel(true);mode="hurt";clip="8"
 if cast_model().fighter.strike!="cuts":duration=float(cast_model().motions.clips["8:0"].duration)
func die():
 if spell_owner==null:hero.timed_dodge.reset()
 cancel();mode="dead";clip="10"
