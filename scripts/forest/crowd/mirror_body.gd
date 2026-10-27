extends "res://scripts/player.gd"
## Pooled character presentation/combat; the native army owns navigation and life.
var leased=false
var actions:Array=[]
var held_action=""
var release_left=0.0
var action_history:Array=[]
func _setup_initial_model():
 ensure_character(character_id);model=character_models[character_id]
func ensure_character(id:int):
 if id==character_id:super.ensure_character(id)
func _ready():
 ai_controlled=true;mirror_copy=true
 super._ready()
 collision_layer=0;set_physics_process(false)
 active_ability=character_abilities.get(character_id)
 if active_ability!=null:
  active_ability.active=true
  if character_id==2:musashi=active_ability
 model.show();model.set_process(false)
 prepare_loadout()
 if character_id==1:game.prepare_coin_projectiles(self)
func prepare_loadout():
 spell_loadout.cancel();spell_loadout.prepare()
 if not leased:refresh_actions()
func refresh_actions():
 actions=[["Primary","light_attack"],["Secondary","heavy_attack"]]
 for slot in spell_loadout.numbered_slots:
  if slot.is_empty():continue
  var id=spell_loadout.spell_for(character_id,slot[1]) if slot.size()==2 else ""
  if id in ["blademaster/mirror-image","blademaster/wind-walk"] or slot[1]=="flight":continue
  if slot.size()==2 and slot[1] in ["light_attack","heavy_attack"]:continue
  actions.append(slot)
func copy_from(source:Hero):
 retire()
 team_progression=source.team_progression
 progression.level=source.progression.level;powerups=source.powerups.duplicate();attack_speed_stacks=source.attack_speed_stacks
 weapon_slot=source.weapon_slot;scarf_equipped=source.scarf_equipped;gold_cloak=source.gold_cloak
 buildings_broken=source.buildings_broken;run_upgrades=source.run_upgrades.duplicate()
 model.scale=source.model.scale;model.set_cloak(scarf_equipped,gold_cloak)
 if character_id==1:set_weapon_visual(weapon_slot)
 if model.has_method("set_outfit_mask"):model.set_outfit_mask(source.model.outfit_mask)
 if character_id==18:active_ability.select_slot(source.active_ability.weapon_slot)
 if character_id==32:active_ability.demon=source.active_ability.demon
 max_hp=source.max_hp;activate()
func activate():
 refresh_actions();leased=true
 if active_ability!=null:active_ability.clear_cooldowns()
 spell_loadout.clear_cooldowns()
 action_history.clear();hp=max_hp;show()
func retire():
 if not leased:return
 leased=false
 if spell_loadout!=null:spell_loadout.cancel()
 if active_ability!=null:active_ability.cancel()
 if quick_attacks!=null:quick_attacks.stop_coins();quick_attacks.cancel()
 if forward_dash!=null:forward_dash.cancel()
 if sky_strike!=null:sky_strike.cancel()
 if chain_pipe_combat!=null:chain_pipe_combat.cancel()
 var pool=game.get_node_or_null("CharacterProjectiles")
 if pool!=null:pool.release_owner(self)
 if character_id==13 and active_ability!=null:
  for shot in active_ability.assimilation.shots:active_ability.assimilation._retire(shot)
 attack_chain.reset();melee_assist.reset()
 attack_left=0;attack_motion_pending=false;impact_pause=0;heavy_buffer=0;queued=false
 velocity=Vector3.ZERO;held_action="";release_left=0;hide()
func perform(index:int,point:Vector3):
 if has_offensive_action() or index<0 or index>=actions.size():return
 ai_aim=point;facing=combat_attack_direction();model.rotation.y=atan2(-facing.x,-facing.z)
 release_left=.45
 var slot:Array=actions[index]
 if slot.size()>2:
  active_ability.callv(slot[1],slot.slice(2))
  if slot[1]=="select_slot":press("light_attack")
 else:press(slot[1])
 action_history.append(index)
 if action_history.size()>64:action_history.pop_front()
func press(action:String):
 held_action=action;release_left=.45
 var event=preload("res://scripts/spells/spell_instance.gd").event(action,true)
 if spell_loadout.input(event):return
 if active_ability!=null:active_ability.input(event)
 elif action in ["light_attack","heavy_attack"]:quick_attacks.request_mouse(action=="heavy_attack")
 elif action=="weapon_coin":quick_attacks.request(2)
 elif action=="weapon_chain":quick_attacks.request(3)
 elif action=="equip":forward_dash.start()
 elif action=="sky_strike":sky_strike.request()
 elif action=="surge":activate_surge()
func release():
 if character_id==13:active_ability.assimilation.held=false
 if held_action.is_empty():return
 var event=preload("res://scripts/spells/spell_instance.gd").event(held_action,false)
 spell_loadout.release_input(event)
 if active_ability!=null:
  if active_ability.has_method("release_input"):active_ability.release_input(event)
  else:active_ability.input(event)
 held_action=""
func step(delta:float,state:Dictionary):
 global_position=state.position;hp=state.hp
 if release_left>0:
  release_left=maxf(0,release_left-delta)
  if release_left<=0:release()
 if has_offensive_action() or not is_on_floor():
  # Only authored attacks use character physics; pursuit stays native.
  super._physics_process(delta)
 else:
  facing=Vector3(sin(state.yaw),0,cos(state.yaw));model.rotation.y=atan2(-facing.x,-facing.z)
  spell_loadout.tick(delta)
  dodge_cooldown=maxf(0,dodge_cooldown-delta);invuln=maxf(0,invuln-delta)
  for key in powerups:powerups[key]=maxf(0,powerups[key]-delta)
  if powerups.attack_speed<=0:attack_speed_stacks=0
  if surge_left>0:
   surge_left=maxf(0,surge_left-delta)
   if surge_left<=0:end_surge()
  quick_attacks.tick_coins(delta)
  if active_ability!=null:
   if is_rogue_character():
    active_ability.player.pos=global_position;active_ability.player.angle=state.yaw;active_ability.aim=ai_aim
    active_ability.animation_velocity=state.pose_velocity;active_ability.locomotion_velocity=state.pose_velocity
    active_ability.tick(delta);active_ability._animate(delta,state.pose_velocity.length())
   else:active_ability.tick_timers(delta);active_ability.tick(delta,false)
  if not is_rogue_character():
   model.locomotion_velocity=state.pose_velocity
   model.animate(delta,state.pose_velocity.length(),true,0,0,false,0,false)
  attack_chain.tick(delta,false)
func take_hit(_amount:float,_direction:Vector3,_projectile:bool=false):pass
func _finish_movement_bounds():pass
func _physics_process(_delta):pass

func is_master_chief()->bool:return character_id==18
