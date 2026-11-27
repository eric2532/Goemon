extends Node3D
## One player cue reads the native attack clock; it never chooses enemy targets.
const WINDOW=.55
const RECOVERY=.75
var hero
var mark:Sprite3D
var cooldown=0.0
var reacting=false
var shadow_counter_enabled=false
var counter_source=0
var counter_origin=Vector3.INF
var step_time=0.0
var step_ticks=0
var threat:Dictionary={}
var bodyguard_equipped=false
var rescue_left=0.0
var rescue_from=Vector3.ZERO
var rescue_to=Vector3.ZERO
var rescue_mark_left=0.0

func begin_rescue(event:Dictionary):
 hero.interrupt_attack_for_movement()
 hero.active_ability.cancel(true)
 hero.active_ability.clear_shin_counter();hero.active_ability.primary_hold_target=null
 hero.model.clear_kagerou_dodge()
 reset()
 hero.defend_held=false;hero.dodge_time=0;hero.invuln=0
 hero.combat_hold_left=0;hero.combat_hold_source=-1
 hero.jump_buffer=0;hero.jump_windup=0;hero.velocity=Vector3.ZERO
 rescue_from=hero.global_position;rescue_to=event.direction;rescue_left=event.amount;rescue_mark_left=.55
 var toward:Vector3=rescue_to-rescue_from;toward.y=0
 if not toward.is_zero_approx():hero.facing=toward.normalized()
 hero.play_sound("cg_dodge_warning")

func tick_rescue(delta:float):
 rescue_left=maxf(0,rescue_left-delta)
 var to=rescue_from.lerp(rescue_to,1-rescue_left/.18)
 hero.move_and_collide(to-hero.global_position)
 hero.model.locomotion_velocity=(rescue_to-rescue_from)/.18
 hero.model.animate(delta,32,true,0,0,false,0,false)
 hero.model.show_pose(3,.18-rescue_left,true)

func _ready():
 mark=Sprite3D.new();mark.texture=preload("res://assets/characters/crossgate/hit_feedback/exclamation.png")
 mark.billboard=BaseMaterial3D.BILLBOARD_ENABLED;mark.no_depth_test=true;mark.fixed_size=true;mark.pixel_size=.0016
 mark.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(mark)
 hide()

func available()->bool:
 return not hero.ai_controlled and hero.RogueRoster.is_crossgate_fighter(hero.character_id) and hero.game.playing and not hero.game.paused and not hero.game.transitioning and hero.hp>0

func refresh():
 threat={}
 if available() and is_instance_valid(hero.game.get("army_runtime")):
  threat=hero.game.army_runtime.native.hero_dodge_threat()

func can_dodge()->bool:
 return available() and cooldown<=0 and hero.is_on_floor() and hero.dodge_time<=0 and hero.combat_hold_left<=0 and not hero.shin_cast_planted()

func ready_to_dodge()->bool:
 var seconds=float(threat.get("seconds",-1))
 return can_dodge() and seconds>0 and seconds<=WINDOW

func evading_charge()->bool:
 return cooldown>RECOVERY-WINDOW-.05 and hero.invuln>0

func press()->bool:
 refresh()
 var timed=ready_to_dodge()
 if not timed and not (can_dodge() and hero.accessory_bonuses.get("backstep",0)>0):return false
 cooldown=RECOVERY
 hero.defend_held=false
 hero.interrupt_attack_for_movement()
 var away:Vector3=hero.global_position-threat.origin if timed else -hero.facing
 var step=away
 if timed and threat.get("charge",false):
  var side=away.cross(Vector3.UP).normalized()
  var move:Vector2=hero.smoke_move if hero.smoke_mode else Input.get_vector("move_left","move_right","move_forward","move_back")
  var wish=Vector3(move.x,0,move.y).rotated(Vector3.UP,hero.game.camera_rig.yaw)
  step= -side if side.dot(wish)<0 else side
 hero.model.clear_kagerou_dodge();hero.model.show_kagerou_dodge(step,false,false)
 step_time=0;step_ticks=0
 counter_source=0;counter_origin=Vector3.INF
 if hero.accessory_bonuses.get("manual_dodge_shadow",0)>0:
  hero.active_ability.counter_after_hit(away,int(threat.source_id) if timed else 0,true,false,Vector3.INF,true)
 elif timed and shadow_counter_enabled:
  counter_source=int(threat.source_id) if timed else 0;counter_origin=hero.global_position
  if hero.active_ability.shin_counter.is_empty():
   hero.model.shin_counter_linger=0;hero.model.counter_is_basic=true
   hero.model.stamp_kagerou(hero.model.stat_counter_shadow)
 elif timed:
  hero.active_ability.counter_after_hit(away,int(threat.source_id),true)
 reacting=true;hero.invuln=maxf(hero.invuln,WINDOW+.05)
 hero.play_sound("cg_kagerou_dodge")
 return true

func counter_attack()->bool:
 if not shadow_counter_enabled or counter_source<=0 or not available() or hero.dodge_time>0 or hero.active_ability.is_attacking() or not hero.active_ability.shin_counter.is_empty():return false
 var source=counter_source
 var origin=counter_origin
 counter_source=0;counter_origin=Vector3.INF
 if not hero.active_ability.counter_after_hit(Vector3.ZERO,source,true,true,origin):
  hero.model.stat_counter_shadow.hide()
  return false
 return true

func tick(delta:float):
 rescue_mark_left=maxf(0,rescue_mark_left-delta)
 cooldown=maxf(0,cooldown-delta)
 if not reacting:return
 if hero.model.kagerou_tick<0:
  reacting=false;return
 step_time+=delta
 var ticks=mini(floori(step_time*hero.model.KAGEROU_HZ+.00001),hero.model.KAGEROU_BACK_TICKS)
 if ticks>step_ticks:
  var from:Vector3=hero.global_position
  var to:Vector3=hero.active_ability.combo_landing(from,from+hero.model.kagerou_step*(ticks-step_ticks))
  if to.is_finite():hero.move_and_collide(to-from)
  step_ticks=ticks
 if step_ticks==hero.model.KAGEROU_BACK_TICKS:
  hero.model.clear_kagerou_dodge();reacting=false

func reset():
 rescue_left=0;rescue_mark_left=0
 if reacting and is_instance_valid(hero.model):hero.model.clear_kagerou_dodge()
 if counter_source>0 and is_instance_valid(hero.model) and hero.active_ability.shin_counter.is_empty() and hero.model.stat_counter_shadow!=null:hero.model.stat_counter_shadow.hide()
 cooldown=0;reacting=false;shadow_counter_enabled=false;counter_source=0;counter_origin=Vector3.INF;step_time=0;step_ticks=0;threat={};hide()

func _process(_delta:float):
 if not available():hide();return
 if rescue_mark_left>0:
  show();global_position=hero.global_position+Vector3.UP*(hero.model.standing_height()+.9);mark.scale=Vector3.ONE*1.18;return
 refresh()
 if not ready_to_dodge():hide();return
 if not visible and not threat.get("charge",false):hero.play_sound("cg_dodge_warning")
 show()
 global_position=hero.global_position+Vector3.UP*(hero.model.standing_height()+.9)
 mark.scale=Vector3.ONE*1.18
