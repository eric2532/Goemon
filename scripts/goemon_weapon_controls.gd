extends RefCounted
## Goemon owns his original numbered weapons; unassigned fighter slots stay empty.
## Native charge helper801DC27C: B hold15ticks ->24C/effect11;60ticks full;
## release full ->state3 ->7F/80/81. There is no dedicated charging body clip:
## native locomotion continues while the charge effect follows the actor.
const CHARGE_CUE_TIME=15.0/30.0
const FULL_CHARGE_TIME=60.0/30.0
const WEAPON_NAMES=["Gold pipe","Coins","Chain pipe"]
var hero:Hero
var charging=false
var elapsed=0.0
var cue_played=false
var held_action=""
var charge_ticket:Dictionary={}
var charge_visual:Node3D
var sustain_index=0
var temporary_return=-1
func _init(player:Hero):hero=player
func select_number(number:int,hold_action:String="")->bool:
 if hero.character_id!=1 or number<1 or number>5:return false
 if number>3:return true
 if charging:
  if number==2:return true
  cancel()
 if number<=3:
  if not available():return true
  hero.quick_attacks.stop_coins()
  if number==2 and hero.surge_left>0 and not hold_action.is_empty():
   temporary_return=hero.weapon_slot;hero.weapon_slot=2;hero.set_weapon_visual(2)
   begin_charge(hold_action)
  else:hero.quick_attacks.request(number)
 return true
func input(event:InputEvent)->bool:
 if hero.character_id!=1:return false
 if event is InputEventKey and (event.shift_pressed or event.ctrl_pressed or event.alt_pressed or event.meta_pressed):return false
 for pair in [["weapon_pipe",1],["weapon_coin",2],["weapon_chain",3],["scarf_toggle",4],["gold_cloak",5]]:
  if event.is_action(pair[0]):
   if event.is_pressed() and not event.is_echo():select_number(pair[1],pair[0])
   return true
 if hero.weapon_slot!=2:return false
 for action in ["light_attack","heavy_attack"]:
  if not event.is_action_pressed(action):continue
  if event.is_echo():return true
  if charging:return true
  if not available():return true
  if hero.surge_left>0:begin_charge(action)
  else:hero.quick_attacks.request_mouse(action=="heavy_attack")
  return true
 return false
func available()->bool:
 return hero.character_id==1 and hero.game.playing and not hero.game.paused and not hero.game.transitioning and hero.hp>0 and hero.attack_left<=0 and hero.dodge_time<=0 and not hero.forward_dash.active and not hero.sky_strike.active and not hero.chain_pipe_combat.active and not hero.quick_attacks.active and hero.quick_attacks.pending.is_empty()
func begin_charge(action:String):
 charging=true;elapsed=0;cue_played=false;held_action=action;sustain_index=0
 hero.primary_down=true;hero.charge_elapsed=0
 hero.quick_attacks.stop_coins();hero.rogue_controls.reset()
 charge_ticket=hero.attack_chain.make_ticket("coin_charge")
 charge_visual=preload("res://scripts/recovered_goemon_charge_vfx.gd").create(hero.model.rig_visual,hero.model.source_scale,hero.model.source_offset)
 hero.hold_combat_aim()
func tick(delta:float):
 if not charging:return
 if hero.character_id!=1 or hero.weapon_slot!=2 or hero.surge_left<=0 or hero.hp<=0 or not hero.game.playing or hero.game.transitioning or hero.dodge_time>0 or hero.forward_dash.active or hero.sky_strike.active:
  cancel();return
 if hero.game.paused:return
 elapsed+=maxf(0,delta)
 if is_instance_valid(charge_visual):charge_visual.set_charge_time(elapsed)
 hero.charge_elapsed=elapsed;hero.hold_combat_aim()
 if not cue_played and elapsed+.000001>=CHARGE_CUE_TIME:
  cue_played=true;hero.play_sound("goemon_coin_charge",1.0,charge_ticket)
 while elapsed+.000001>=1.5+float(sustain_index):
  hero.play_sound("goemon_coin_charge_a" if sustain_index%2==0 else "goemon_coin_charge_b",1.0,charge_ticket)
  sustain_index+=1
func fraction()->float:return clampf(elapsed/FULL_CHARGE_TIME,0,1)
func release(event:InputEvent):
 if not charging or not event.is_action_released(held_action):return
 var full=elapsed+.000001>=FULL_CHARGE_TIME
 var can_release=hero.character_id==1 and hero.weapon_slot==2 and hero.surge_left>0 and available()
 var previous_slot=temporary_return
 cancel()
 if can_release:
  # Native full release chooses the single charged coin costing three at60ticks.
  if previous_slot>=0:hero.quick_attacks.charged_coin(previous_slot,full)
  else:hero.start_attack(full,1,full,1.0)
func cancel():
 if is_instance_valid(charge_visual):charge_visual.queue_free()
 charge_visual=null
 if temporary_return>=0 and hero.character_id==1:
  hero.weapon_slot=temporary_return;hero.set_weapon_visual(temporary_return)
 temporary_return=-1
 charging=false;elapsed=0;cue_played=false;held_action="";charge_ticket={};sustain_index=0
 hero.primary_down=false;hero.charge_elapsed=0
