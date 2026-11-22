extends "res://scripts/player.gd"
## Pooled character presentation/combat; the native army owns navigation and life.
const Qigong=preload("res://scripts/qigong_combat.gd")
var native_handle=0
var leased=false
var actions:Array=[]
var assault_copy=false
var shadow_barrage=false
var shadow_source:Hero
var copied_damage=-1.0
var copied_magic_damage=-1.0
var copied_base_damage=-1.0
var spell_reach=0.0
var skill_ranges:Array[float]=[]
var skill_instances:Array[Node]=[]
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
 process_mode=Node.PROCESS_MODE_PAUSABLE;collision_layer=0;set_physics_process(false)
 active_ability=character_abilities.get(character_id)
 if active_ability!=null:
  active_ability.active=true
  if character_id==2:musashi=active_ability
 model.show();model.set_process(false)
 prepare_loadout()
 if character_id==1:game.prepare_coin_projectiles(self)
func prepare_loadout():
 if character_id==RogueRoster.KAZI_ID:model.set_kaz_skin(game.settings.kaz_skin)
 if RogueRoster.is_crossgate_fighter(character_id):preload("res://scripts/forest/equipment.gd").apply(self)
 spell_loadout.cancel();spell_loadout.prepare()
 if assault_copy or not leased:refresh_actions()
func refresh_actions():
 actions=[["Primary","light_attack"],["Secondary","heavy_attack"]]
 skill_ranges.clear();skill_instances.clear();spell_reach=0.0
 if shadow_barrage:
  actions=[[spell_loadout.Catalog.RANDOM_SHOT_NAME,"start_random_shot"]]
  return
 for slot in spell_loadout.numbered_slots:
  if slot.is_empty():continue
  if slot[0]==spell_loadout.Catalog.BARRAGE_SHADOWS_NAME:continue
  var id=spell_loadout.spell_for(character_id,slot[1]) if slot.size()==2 else ""
  if id in ["blademaster/mirror-image","blademaster/wind-walk","ben/flight",spell_loadout.Catalog.RECOVERY,spell_loadout.Catalog.BEARS,spell_loadout.Catalog.COMBO,spell_loadout.Catalog.KAGEROU,spell_loadout.Catalog.COUNTER,spell_loadout.Catalog.BODYGUARD] or slot[1]=="flight":continue
  if slot[1]=="special_6" and id.is_empty():continue
  if slot.size()==2 and slot[1] in ["light_attack","heavy_attack"]:continue
  if actions.size()>=7:break
  actions.append(slot)
  if not assault_copy:continue
  var instance:Node=spell_loadout.instances.get("%d:%s"%[character_id,id])
  var reach=0.0
  if instance!=null and instance.controller is Qigong:
   var controller:Node=instance.controller
   reach=controller.SPIRIT_RANGE if id==spell_loadout.Catalog.SPIRIT else controller.RANGE*controller.range_multiplier()
  elif id=="mountain-king/storm-bolt":reach=36.0
  elif id=="knight/lion":reach=48.0
  skill_ranges.append(reach);skill_instances.append(instance);spell_reach=maxf(spell_reach,reach)
func copy_from(source:Hero):
 retire()
 team_progression=source.team_progression
 progression.level=source.progression.level;powerups=source.powerups.duplicate();attack_speed_stacks=source.attack_speed_stacks
 weapon_slot=source.weapon_slot;scarf_equipped=source.scarf_equipped;gold_cloak=source.gold_cloak
 buildings_broken=source.buildings_broken;run_upgrades=source.run_upgrades.duplicate()
 scale=source.scale
 model.scale=source.model.scale;model.set_cloak(scarf_equipped,gold_cloak)
 if character_id==1:set_weapon_visual(weapon_slot)
 if model.has_method("set_outfit_mask"):model.set_outfit_mask(source.model.outfit_mask)
 if character_id==18:active_ability.select_slot(source.active_ability.weapon_slot)
 if character_id==32:active_ability.demon=source.active_ability.demon
 if RogueRoster.has_variant_skins(character_id):model.set_variant_skin(source.model.variant_skin)
 if RogueRoster.is_shin(character_id):
  model.set_shin_skin(source.model.shin_skin);model.set_stance(source.model.shin_weapon_index)
  spell_loadout.refresh_numbered_slots()
 if RogueRoster.has_crossgate_throws(character_id):
  model.set_maze_weapon(source.model.maze_weapon)
  spell_loadout.refresh_numbered_slots()
 max_hp=source.max_hp-source.level_health_bonus()-(500 if character_id==33 and source.active_ability.demon else 0);activate()
func activate():
 if character_id==RogueRoster.KAZI_ID:model.set_kaz_skin(game.settings.kaz_skin)
 refresh_actions();leased=true
 if active_ability!=null:active_ability.clear_cooldowns()
 spell_loadout.clear_cooldowns()
 action_history.clear();hp=max_hp;show();model.set_process(true)
 if shadow_barrage:
  model.sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
  model.sprite.modulate=Color(.45,.5,.6,.65)
func retire():
 if not leased:return
 leased=false;native_handle=0;ai_target=null;shadow_source=null;copied_damage=-1.0;copied_magic_damage=-1.0;copied_base_damage=-1.0
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
 velocity=Vector3.ZERO;held_action="";release_left=0;model.set_process(false);hide()
func perform_ready(index:int,point:Vector3,basic_in_range:bool):
 if has_offensive_action():return
 if shadow_barrage:
  perform(0,point)
  return
 var distance=Vector2(point.x-global_position.x,point.z-global_position.z).length()
 var melee_ready=basic_in_range and (not RogueRoster.has_crossgate_throws(character_id) or not model.daggers or distance<=3.0)
 for i in skill_ranges.size():
  var skill=(index+i)%skill_ranges.size()
  var reach=skill_ranges[skill]
  if (reach>0 and distance>reach) or (reach<=0 and not melee_ready):continue
  var instance=skill_instances[skill]
  if instance!=null and (not instance.can_cast() or (instance.spec.method=="toggle_immolation" and instance.controller.immolating)):continue
  if instance==null and character_id==32 and actions[skill+2][1]=="surge" and active_ability.immolating:continue
  if perform(skill+2,point):return
 if basic_in_range:perform(index%2,point)

func perform(index:int,point:Vector3)->bool:
 if has_offensive_action() or index<0 or index>=actions.size():return false
 var previous=attack_chain.active_ticket
 ai_aim=point;facing=combat_attack_direction();model.rotation.y=atan2(-facing.x,-facing.z)
 release_left=.45
 var slot:Array=actions[index]
 if shadow_barrage:active_ability.start_random_shot()
 elif slot.size()>2:
  active_ability.callv(slot[1],slot.slice(2))
  if slot[1]=="select_slot":press("light_attack")
 else:press(slot[1])
 action_history.append(index)
 if action_history.size()>64:action_history.pop_front()
 return has_offensive_action() or not is_same(previous,attack_chain.active_ticket) or spell_loadout.held_slots.has(slot[1])
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
 if global_position!=state.position:global_position=state.position
 hp=state.hp
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

func damage_multiplier()->float:
 if copied_damage>=0:return copied_damage
 return shadow_source.damage_multiplier() if is_instance_valid(shadow_source) else super.damage_multiplier()

func magic_damage_multiplier()->float:
 if copied_magic_damage>=0:return copied_magic_damage
 return shadow_source.magic_damage_multiplier() if is_instance_valid(shadow_source) else super.magic_damage_multiplier()

func base_damage_multiplier()->float:
 if copied_base_damage>=0:return copied_base_damage
 return shadow_source.base_damage_multiplier() if is_instance_valid(shadow_source) else super.base_damage_multiplier()
