extends Node
## Per-skin assignments; older fighter saves seed skins until their first edit.
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const Instance=preload("res://scripts/spells/spell_instance.gd")
const SwordFire=preload("res://scripts/crossgate_element_projectile.gd")
const ProjectilePool=preload("res://scripts/character_projectile_pool.gd")
const MAGIC_COMBO_LIMIT=40
var hero:Hero
var instances:Dictionary={}
var retired_cooldowns:Dictionary={}
var flight_enabled=false
var magic_seal_left=0.0
var held_slots:Dictionary={}
var current:Node
var magic_combo_steps=0
var magic_result:Dictionary={}
var dispatching=false
var casting_id=""
var numbered_slots:Array=[]
var held_numbers:Dictionary={}
var air_attack_action=""

func assignments(character:int)->Dictionary:
 var key=Catalog.Roster.loadout_key(character,hero.game.settings)
 var saved:Variant=hero.game.settings.get("spell_loadouts",{})
 if not saved is Dictionary:saved={}
 var slots:Dictionary=Catalog.valid_loadouts({key:saved.get(key,saved.get(str(character),saved.get(character,{})))}).get(key,{})
 # Hide retired assignments without erasing saved loadouts.
 for action in slots.keys():
  if not Catalog.available(Catalog.all()[slots[action]]):slots.erase(action)
 if character==7 and not slots.has("sky_strike"):slots.sky_strike="knight/lion"
 return slots

func spell_for(character:int,action:String)->String:
 return str(assignments(character).get(action,Catalog.defaults(character).get(action,"")))

func equip(character:int,action:String,id:String)->bool:
 if character not in Catalog.Roster.PLAYABLE_IDS or not Catalog.SLOTS.has(action) or (id in [Catalog.RECOVERY,Catalog.MEDITATION] and not Catalog.Roster.is_crossgate_fighter(character)) or (not id.is_empty() and not Catalog.all().has(id)):return false
 if not id.is_empty() and not Catalog.available(Catalog.all()[id]):return false
 if id==Catalog.KAGEROU and not Catalog.Roster.is_crossgate_fighter(character):return false
 if action=="special_6" and not Catalog.Roster.is_crossgate_fighter(character):return false
 if character==hero.character_id and spell_for(character,action)==Catalog.KAGEROU and id!=Catalog.KAGEROU:hero.active_ability.disable_kagerou()
 cancel()
 if Catalog.Roster.has_crossgate_throws(character) and character==hero.character_id and action=="special_6" and not id.is_empty():
  hero.active_ability.disable_kagerou()
 if Catalog.Roster.has_crossgate_throws(character) and character==hero.character_id and action=="equip" and not id.is_empty():
  hero.active_ability.disable_assassination()
 var saved=Catalog.valid_loadouts(hero.game.settings.get("spell_loadouts",{}))
 var key=Catalog.Roster.loadout_key(character,hero.game.settings)
 var slots:Dictionary=saved.get(key,saved.get(str(character),{})).duplicate()
 if id.is_empty():slots.erase(action)
 else:slots[action]=id
 if slots.is_empty() and key==str(character):saved.erase(key)
 else:saved[key]=slots
 hero.game.settings.spell_loadouts=saved;hero.game.save_settings()
 if character==13 and hero.character_id==13 and hero.active_ability.combo_skill=="leaping-strike":hero.active_ability.cancel()
 prepare()
 return true

func prepare():
 hero.jump_style.prepare()
 refresh_numbered_slots()
 air_attack_action=""
 var slots=assignments(hero.character_id)
 if hero.timed_dodge!=null:hero.timed_dodge.bodyguard_equipped=slots.values().has(Catalog.BODYGUARD) and not hero.ai_controlled
 if Catalog.Roster.is_crossgate_fighter(hero.character_id):
  if slots.values().has(Catalog.KAGEROU) and not hero.ai_controlled:hero.model.prepare_kagerou_shadows()
  else:hero.active_ability.disable_kagerou()
  hero.active_ability.clear_shin_counter()
  hero.active_ability.shin_counter_equipped=slots.values().has(Catalog.COUNTER) and not hero.ai_controlled
  if hero.active_ability.shin_counter_equipped:hero.model.prepare_shin_counter()
  if slots.values().has(Catalog.BARRAGE_SHADOWS):hero.active_ability.prepare_shadow_mirrors()
  elif hero.active_ability.mirrors!=null:hero.active_ability.mirrors.clear()
  if Catalog.Roster.has_crossgate_throws(hero.character_id):hero.active_ability.disable_assassination()
 for action in Catalog.SLOTS:
  if slots.has(action) and Catalog.all()[slots[action]].get("air_attack",false):
   air_attack_action=action;break
 # Selection/equipment pays setup once; input only starts prepared controllers.
 var equipped=slots.values().filter(func(id):
  return id not in [Catalog.BODYGUARD,Catalog.KAGEROU,Catalog.RANDOM_SHOT,Catalog.COUNTER,Catalog.BARRAGE_SHADOWS,Catalog.MEDITATION,Catalog.GUARD_BREAK] and (id not in [Catalog.SURE_STRIKE,Catalog.DOUBLE_EDGE] or not Catalog.Roster.is_crossgate_fighter(hero.character_id)) and (not hero.mirror_copy or id!="blademaster/mirror-image") and (not hero.ai_controlled or id not in [Catalog.RECOVERY,Catalog.COMBO,Catalog.BEARS]))
 if hero.character_id==Catalog.Roster.KAZI_ID:equipped=equipped.filter(func(id):return id!=Catalog.COMBO)
 if hero.character_id==13:equipped=equipped.filter(func(id):return Catalog.all()[id].source!=13 or Catalog.all()[id].method not in ["start_combo","start_leaping_strike","start_rotation","start_counter"])
 if hero.team_progression!=null and hero.game.player==hero and not hero.ai_controlled:hero.team_progression.skills.assign(equipped)
 var fire_basic=hero.accessory_bonuses.get("primary","")=="fire"
 for key in instances.keys():
  if key.begins_with("%d:"%hero.character_id) and (fire_basic if instances[key].spec.get("basic_attack",false) else equipped.has(instances[key].spec.id)):continue
  retired_cooldowns[key]=instances[key].cooldown_state()
  instances[key].queue_free();instances.erase(key)
 for id in equipped:_instance(id)
 if fire_basic:_instance("kazi/fire",true)
 if hero.accessory_bonuses.get("sword_fire",0)>0:
  ProjectilePool.service(hero.game).warm(hero,SwordFire,"sword-fire",{"kind":"fire"},16)
 if not hero.mirror_copy:
  var kits=[hero.active_ability]
  for instance in instances.values():kits.append(instance.controller)
  for kit in kits:
   if is_instance_valid(kit) and (kit.has_method("start_mirrors") or kit.has_method("start_shadow_mirrors")) and kit.mirrors!=null:kit.mirrors.prepare_loadout()

func refresh_numbered_slots():
 numbered_slots=slots_for(hero.character_id)
 # A weapon swap can add contacts; prepare the larger volley before combat.
 for key in instances:
  if key.begins_with("%d:"%hero.character_id) and instances[key].controller is Instance.Qigong:instances[key].controller.prepare_projectiles()

func native_slots_for(character:int)->Array:
 return Catalog.hotbar(character)

func slots_for(character:int)->Array:
 var result=native_slots_for(character)
 var equipped=assignments(character)
 for i in result.size():
  var action=Catalog.SLOTS.keys()[i]
  if equipped.has(action):result[i]=[Catalog.all()[equipped[action]].name,action]
 return result

func number_input(number:int,pressed:bool):
 if number<1 or number>numbered_slots.size():return
 if not pressed:
  var slot:Array=held_numbers.get(number,[]);held_numbers.erase(number)
  if slot.is_empty():return
  if slot[1]=="select_number":
   if hero.character_id==13 and slot[2]==7:hero.active_ability.assimilation.held=false
  elif slot.size()==2:
   var release=Instance.event(slot[1],false)
   hero._input(release);hero._unhandled_input(release)
  return
 if held_numbers.has(number) or hero.cursed_afflictions[5]>0:return
 if not hero.game.playing or hero.game.transitioning or hero.hp<=0 or hero.ai_controlled or hero.combat_hold_left>0:return
 var slot:Array=numbered_slots[number-1]
 if slot.is_empty():return
 if hero.defend_held:
  if not hero.game.paused and slot.size()==2 and spell_for(hero.character_id,slot[1])==Catalog.GUARD_BREAK:
   hero.game.toast("Release X to use Guard Break")
  return
 # Weapon selection is useful on the preparation map; casting obeys normal pause gates.
 if slot[1]=="select_slot":hero.master_chief_combat.select_slot(slot[2])
 elif hero.game.paused:return
 elif slot.size()==2:hero._unhandled_input(Instance.event(slot[1],true))
 elif hero.dodge_time<=0:
  if slot[1]=="start_hair":hero.active_ability.cancel()
  elif slot[1] not in ["select_number"] and hero.active_ability.is_attacking() and hero.character_id!=13:return
  hero.active_ability.callv(slot[1],slot.slice(2))
 held_numbers[number]=slot

func action_pressed(action:String)->bool:
 return Input.is_action_pressed(action) or held_numbers.values().any(func(slot):return slot.size()==2 and slot[1]==action)

func number_event(event:InputEvent)->bool:
 if not event is InputEventKey:return false
 var number=(event.physical_keycode if event.physical_keycode else event.keycode)-KEY_1+1
 if number<1 or number>numbered_slots.size():return false
 if not event.pressed:
  number_input(number,false);return true
 if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:return true
 # Shift keeps construction shortcuts during preparation and permits sprinting casts in battle.
 if event.shift_pressed and hero.game.get("model")!=null and hero.game.model.phase=="preparing":return false
 if not event.echo:number_input(number,true)
 return true

func _instance(id:String,basic:bool=false)->Node:
 var key="%d:%s"%[hero.character_id,"basic:"+id if basic else id]
 if not instances.has(key):
  var instance=Instance.new();add_child(instance)
  var definition:Dictionary=Catalog.all()[id].duplicate()
  if basic:definition.basic_attack=true
  instance.setup(hero,definition);instance.restore_cooldowns(retired_cooldowns.get(key,{}));instances[key]=instance
 return instances[key]

func accessory_attack()->bool:
 var primary:String=hero.accessory_bonuses.get("primary","")
 if primary=="random-shot":
  if hero.model.current_weapon()!="bow":return false
  hero.active_ability.start_random_shot(true)
  return true
 if primary!="fire":return false
 var instance=instances.get("%d:basic:kazi/fire"%hero.character_id)
 if instance!=null and current==null and instance.can_cast():_begin_cast(instance,"")
 return true

func prepare_skill_count(id:String):
 for instance in instances.values():
  if preload("res://scripts/spells/skill_levels.gd").family(instance.spec.id)==preload("res://scripts/spells/skill_levels.gd").family(id) and instance.controller!=null and instance.controller.has_method("prepare_projectiles"):instance.controller.prepare_projectiles()
  if instance.controller!=null and instance.controller.get("mirrors")!=null:instance.controller.mirrors.prepare_count()
 var spec:Dictionary=preload("res://scripts/spells/skill_balance.gd").all().get(id,{})
 if spec.get("native",false) and spec.source==hero.character_id:hero.active_ability.prepare_projectiles()
 if id==Catalog.RANDOM_SHOT:hero.active_ability.prepare_projectiles()
 if id==Catalog.BARRAGE_SHADOWS and Catalog.Roster.is_crossgate_fighter(hero.character_id) and hero.active_ability.mirrors!=null:hero.active_ability.mirrors.prepare_count()

func input(event:InputEvent)->bool:
 if event.is_action_pressed("light_attack") and primary_skill_busy():return true
 var slots=assignments(hero.character_id)
 if not air_attack_action.is_empty() and not hero.is_on_floor() and (event.is_action_pressed("light_attack") or event.is_action_pressed("heavy_attack")):
  if not event.is_echo():_cast(slots[air_attack_action],air_attack_action)
  return true
 for action in slots:
  if not event.is_action(action):continue
  if event.is_echo():return true
  if event.is_action_pressed(action):
   _cast(slots[action],action)
  return true
 if current!=null and (event.is_action_pressed("light_attack") or event.is_action_pressed("heavy_attack") or event.is_action_pressed("dodge")):
  if current!=null and current.spec.get("basic_attack",false) and not event.is_action_pressed("dodge"):return true
  interrupt()
 return Catalog.Roster.is_crossgate_fighter(hero.character_id) and Catalog.SLOTS.keys().any(func(action):return event.is_action(action))

func _cast(id:String,action:String):
 if hero.defend_held or id==Catalog.BODYGUARD:return
 var spec:Dictionary=Catalog.all()[id]
 if not Catalog.weapon_compatible(spec,hero.model):
  if not hero.ai_controlled:hero.game.toast("Requires "+str(spec.required_weapon).capitalize())
  return
 if id!=Catalog.COUNTER and (id!=Catalog.KAGEROU or not hero.active_ability.kagerou_enabled) and not hero.can_pay_skill(id,true):return
 if id==Catalog.RANDOM_SHOT:
  casting_id=id;hero.active_ability.start_random_shot();casting_id="";return
 if id==Catalog.COUNTER:return
 if id==Catalog.GUARD_BREAK:
  if current==null and Catalog.Roster.is_crossgate_fighter(hero.character_id):hero.active_ability.start_guard_break()
  return
 if id==Catalog.MEDITATION:
  casting_id=id;hero.active_ability.start_shin_meditation();casting_id="";return
 if id==Catalog.BARRAGE_SHADOWS:
  casting_id=id;hero.active_ability.call(spec.method);casting_id="";return
 if id==Catalog.KAGEROU:
  hero.active_ability.toggle_kagerou();return
 if id in [Catalog.SURE_STRIKE,Catalog.DOUBLE_EDGE] and Catalog.Roster.is_crossgate_fighter(hero.character_id):
  casting_id=id;hero.active_ability.start_shin_area_cast();casting_id="";return
 if id==Catalog.COMBO and hero.character_id==Catalog.Roster.KAZI_ID:
  hero.active_ability.start_combo();return
 if magic_seal_left>0 and spec.method in ["start_cast","start_recovery","cast_fireball","request_meteors","beam"]:return
 if hero.character_id==13 and spec.source==13 and spec.method in ["start_combo","start_leaping_strike","start_rotation","start_counter"]:
  hero.active_ability.callv(spec.method,spec.args);return
 var instance=instances.get("%d:%s"%[hero.character_id,id])
 if instance==null:return
 if id==Catalog.BEARS:
  if instance.can_cast():
   instance.cast()
   link_primary_combo()
  return
 if id==Catalog.RECOVERY:
  if instance.can_cast():
   if primary_combo_enabled():hero.interrupt_attack_for_movement()
   instance.controller.start_recovery()
   link_primary_combo()
  return
 if not hero.ai_controlled and instance.controller is Instance.Qigong and id!=Catalog.MAZE_QI:
  if current!=null or not instance.can_cast():return
  if not magic_result.is_empty() and not magic_result.hit and magic_result.pending!=0:return
  _begin_cast(instance,"")
  return
 if instance==current and instance.held:
  held_slots[action]=instance;return
 if not instance.can_cast():return
 # Held casts keep their existing press/release owner.
 if hero.character_id==13 and spec.source==13 and spec.method=="select_number" and spec.args!=[7] and hero.active_ability.buffer_action("cast",[id,action]):return
 if instance==current and (instance.spec.method=="sky" or (instance.source_id==30 and instance.spec.args[0] in [1,2,3,4])):
  held_slots[action]=instance;dispatching=true;casting_id=instance.spec.id;instance.cast();casting_id="";dispatching=false;return
 if current!=null and current!=instance:interrupt()
 _begin_cast(instance,action)

func begin_magic_combo()->Dictionary:
 magic_combo_steps=mini(magic_combo_steps+1,MAGIC_COMBO_LIMIT) if magic_result.get("hit",false) else 0
 # Each volley keeps its own result so late impacts cannot credit a newer cast.
 magic_result={"hit":false,"pending":-1}
 return magic_result

func magic_cast_speed()->float:
 if not magic_result.get("hit",false) and magic_result.get("pending",0)==0:return 1.0
 return 1.0+.1*magic_combo_steps

func _begin_cast(instance:Node,action:String):
 if action.is_empty():dispatching=true
 hero.interrupt_attack_for_movement()
 if not action.is_empty():held_slots[action]=instance
 dispatching=true;casting_id=instance.spec.id;instance.cast();casting_id="";dispatching=false
 if action.is_empty():instance.held=false
 if instance.busy():
  current=instance
  if not instance.spec.get("basic_attack",false):link_primary_combo()

func link_primary_combo():
 if primary_combo_enabled():hero.active_ability.link_primary_combo()

func primary_combo_enabled()->bool:
 return Catalog.Roster.is_crossgate_fighter(hero.character_id) and is_instance_valid(hero.active_ability) and hero.active_ability.uses_primary_combo()

func primary_combo_cast_speed()->float:
 return hero.active_ability.primary_combo_speed() if primary_combo_enabled() else 1.0

func primary_skill_busy()->bool:
 if hero.ai_controlled or not Catalog.Roster.is_crossgate_fighter(hero.character_id) or not hero.game.has_method("forest_enemy_visible"):return false
 if current!=null and not current.spec.get("basic_attack",false):return true
 var recovery=instances.get("%d:%s"%[hero.character_id,Catalog.RECOVERY])
 return recovery!=null and (recovery.controller.cast_left>0 or recovery.controller.arrival_left>0)

func release_input(event:InputEvent):
 for action in held_slots.keys():
  if not event.is_action_released(action):continue
  var instance=held_slots[action];held_slots.erase(action)
  if held_slots.values().has(instance):continue
  if hero.game.playing and not hero.game.paused and not hero.game.transitioning and hero.hp>0:
   dispatching=true;casting_id=instance.spec.id;instance.release();casting_id="";dispatching=false
  else:instance.cancel()
  if instance.busy():current=instance

func clear_cooldowns():
 retired_cooldowns.clear()
 for key in instances:
  if instances[key].controller!=null:instances[key].controller.clear_cooldowns()

func tick(delta:float)->bool:
 if magic_seal_left>0:magic_seal_left=maxf(0.0,magic_seal_left-delta)
 for key in retired_cooldowns.keys():
  for slot in retired_cooldowns[key]:retired_cooldowns[key][slot]=maxf(0,retired_cooldowns[key][slot]-delta)
  if retired_cooldowns[key].values().all(func(value):return value<=0):retired_cooldowns.erase(key)
 if hero.is_rogue_character() and hero.surge_left>0:
  hero.surge_left=maxf(0,hero.surge_left-delta)
  if hero.surge_left<=0:hero.end_surge()
 var controlled=false
 for key in instances:
  if not key.begins_with("%d:"%hero.character_id):continue
  var instance=instances[key]
  dispatching=true
  casting_id=instance.spec.id
  var moved:bool=instance.step(delta)
  casting_id=""
  dispatching=false
  if instance==current:controlled=moved
 if current==null:return false
 var busy:bool=current.busy()
 if busy and not controlled:
  var motion=Input.get_vector("move_left","move_right","move_forward","move_back")
  var direction=hero.ai_move if hero.ai_controlled else Vector3(motion.x,0,motion.y).rotated(Vector3.UP,hero.game.camera_rig.yaw)
  var rooted=current.spec.id in [Catalog.COMBO,Catalog.BEE_FLURRY] or (current.source_id in [13,14,15,16,28,29] and current.spec.method not in ["surge","start_super_jump"])
  if current.controller is Instance.KnightLion:rooted=true
  if current.controller is Instance.RogueRuntime:
   rooted=current.controller.player.blocking
  if not rooted:
   var speed=hero.combat_tuning("walk_speed")*hero.movement_multiplier()
   hero.velocity.x=direction.x*speed;hero.velocity.z=direction.z*speed
  elif current.source_id not in [14,15,16,29]:hero.velocity.x=0;hero.velocity.z=0
  if not hero.is_on_floor():
   var vertical_owned=(current.source_id==15 and current.controller.bomb_controls_flight()) or (current.source_id==16 and current.controller.controls_vertical_motion())
   if not vertical_owned:
    if hero.jump_style.active():hero.jump_style.step(delta,false)
    elif current.source_id==29:current.controller.step_leap(delta,direction)
    else:hero.velocity.y=maxf(-55,hero.velocity.y-30*delta)
  elif hero.velocity.y<0:hero.velocity.y=0
  hero.move_and_slide()
 hero.constrain_forest_bounds()
 hero.invuln=maxf(0,hero.invuln-delta);hero.dodge_cooldown=maxf(0,hero.dodge_cooldown-delta)
 hero.model.rotation.y=atan2(-hero.facing.x,-hero.facing.z)
 # The receiving body presents the gesture; the donor retains authored hit timing.
 var posed=(current.source_id==1 and current.spec.method=="sky") or (current.source_id==2 and current.spec.method=="teleport")
 if current.controller is Instance.Qigong and not current.controller.kind.is_empty() and hero.model.has_method("animate_spell"):
  hero.model.animate_spell(delta,current)
 elif current.controller is Instance.Qigong and not current.controller.native_pattern.is_empty():
  var skill=current.controller
  hero.model.show_pose(0 if skill.charge_left>0 else skill.native_pattern.pose,skill.native_elapsed,false)
 elif current.controller is Instance.Qigong and current.controller.punches():
  hero.model.animate_qi_blast(delta,current.controller.punch_progress())
 elif current.spec.id==Catalog.COMBO:
  if hero.model.has_method("animate_combo"):hero.model.animate_combo(delta,current)
  elif hero.model.has_method("animate_spell"):hero.model.animate_spell(delta,current)
  else:hero.model.animate_qi_blast(delta,current.controller.combo_progress())
 elif current.spec.get("air_attack",false) and not hero.model.has_method("animate_spell"):
  var saved=current.snapshot();current.restore(current.hero_state)
  hero.model.animate(delta,0,hero.is_on_floor(),hero.velocity.y,clampf(hero.attack_left/maxf(.001,hero.attack_duration),.001,1),hero.attack_heavy,hero.combo,false)
  hero.model.sync_skeleton();current.restore(saved)
 elif hero.model.has_method("animate_spell"):hero.model.animate_spell(delta,current)
 elif not posed:hero.model.animate(delta,Vector2(hero.velocity.x,hero.velocity.z).length(),hero.is_on_floor(),hero.velocity.y,0,false,0,false)
 if current.controller is Instance.KnightLion:current.controller.animate_cast(delta)
 if current.source_id==29 and current.controller.action==current.controller.Dark.SPIN and busy and hero.character_id!=29:
  hero.model.rotation.y+=current.controller.spin_yaw()
 if not busy:
  current=null;hero.attack_left=0;hero.attack_motion_pending=false;hero.impact_pause=0
 return true

func filter_damage(amount:float,direction:Vector3,projectile:bool)->float:
 for key in instances:
  if key.begins_with("%d:"%hero.character_id):amount=instances[key].filter_damage(amount,direction,projectile)
 return amount*.5 if hero.character_id!=7 and buff(7)>0 else amount

func buff(source:int)->float:
 var time=0.0
 for key in instances:
  var instance=instances[key]
  if key.begins_with("%d:"%hero.character_id) and instance.source_id==source and instance.controller is Instance.RogueRuntime:
   time=maxf(time,float(instance.controller.player.buffTime))
 return time

func attack_multiplier()->float:
 return 5.0 if hero.character_id!=4 and buff(4)>0 else (2.5 if hero.character_id!=6 and buff(6)>0 else 1.0)

func damage_multiplier()->float:
 return 2.0 if hero.character_id!=11 and buff(11)>0 else 1.0

func interrupt():
 if dispatching or current==null:return
 if current.controller is Instance.Qigong:magic_result={}
 dispatching=true;current.cancel(true,true);dispatching=false;current=null
 held_slots.clear()
 hero.attack_left=0;hero.impact_pause=0

func seal_for(seconds:float):
 magic_seal_left=maxf(magic_seal_left,seconds)
 if current!=null and current.spec.method in ["start_cast","start_recovery","cast_fireball","request_meteors","beam"]:interrupt()

func cancel(preserve_power:bool=false):
 if dispatching:return
 magic_result={}
 dispatching=true
 for instance in instances.values():instance.cancel(preserve_power)
 dispatching=false;current=null;held_slots.clear();held_numbers.clear()
 if not preserve_power:
  flight_enabled=false
  magic_seal_left=0.0

func _notification(what:int):
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hero):cancel()

func melee_multiplier()->float:
 return 1.8 if hero.character_id!=12 and buff(12)>0 else 1.0

func wind_controller():
 if is_instance_valid(hero.active_ability) and hero.active_ability.has_method("consume_wind") and hero.active_ability.wind_left>0:return hero.active_ability
 for key in instances:
  var c=instances[key].controller
  if key.begins_with("%d:"%hero.character_id) and c!=null and c.has_method("consume_wind") and c.wind_left>0:return c
 return null

func movement_multiplier()->float:return preload("res://scripts/warcraft_kit.gd").WIND_SPEED if wind_controller()!=null else 1.0

func decorate_ticket(ticket:Dictionary,action:String):
 var wind=wind_controller()
 if wind!=null and wind.consume_wind(action):ticket.warcraft_opening=true
 ticket.spell_anbu=hero.character_id!=5 and not action.begins_with("rogue_ninja") and buff(5)>0
 ticket.spell_fire=hero.character_id!=12 and not action.begins_with("rogue_master-thief") and buff(12)>0
 var melee=action in ["enemy_primary","pipe","heavy","sasuke_primary","yae_primary","sword","energy_sword"] or action in ["kojiro_slash","kojiro_air_cut","kojiro_air_spin"] or action.begins_with("sword_") or (action.begins_with("rogue_") and action.ends_with("_primary"))
 if not melee:return
 for key in instances:
  var instance=instances[key]
  if key.begins_with("%d:"%hero.character_id) and instance.source_id==7 and instance.controller is Instance.RogueRuntime and instance.controller.player.riposte>0:
   ticket.spell_riposte=true;instance.controller.player.riposte=0;break


func untargetable()->bool:
 if wind_controller()!=null:return true
 for key in instances:
  if key.begins_with("%d:"%hero.character_id) and instances[key].controller is Instance.RogueRuntime and instances[key].controller.untargetable():return true
 return false

func cooldown_for(action:String)->float:
 var id=spell_for(hero.character_id,action)
 if Catalog.Roster.is_crossgate_fighter(hero.character_id) and id==Catalog.SURE_STRIKE:return hero.active_ability.shin_sure_cooldown
 if Catalog.Roster.is_crossgate_fighter(hero.character_id) and id==Catalog.DOUBLE_EDGE:return hero.active_ability.shin_double_edge_cooldown
 if Catalog.Roster.is_crossgate_fighter(hero.character_id) and id==Catalog.MEDITATION:return hero.active_ability.shin_meditation_cooldown
 if Catalog.Roster.is_crossgate_fighter(hero.character_id) and id==Catalog.RANDOM_SHOT:return hero.active_ability.random_shot_cooldown
 if Catalog.Roster.is_crossgate_fighter(hero.character_id) and id==Catalog.BARRAGE_SHADOWS:return hero.active_ability.mirror_cooldown
 if hero.character_id==Catalog.Roster.KAZI_ID and id==Catalog.COMBO:return hero.active_ability.combo_cooldown
 var key="%d:%s"%[hero.character_id,id]
 return instances[key].cooldown_remaining() if instances.has(key) else 0.0

static func damage_for_hit(enemy,amount:float,ticket:Dictionary)->float:
 if ticket.get("warcraft_opening",false):amount*=2.0
 if ticket.get("spell_riposte",false):amount*=1.8
 if ticket.get("spell_anbu",false) and randf()<.25:
  return amount+45 if enemy.boss else maxf(amount,enemy.hp)
 return amount

static func hit_effects(enemy,amount:float,ticket:Dictionary):
 if ticket.has("sword_fire_ticket") and not ticket.has("guard_break_target") and not ticket.get("guard_reply",false):
  var sword_owner_ref=ticket.get("source_hero")
  var sword_owner=sword_owner_ref.get_ref() if sword_owner_ref is WeakRef else null
  if is_instance_valid(sword_owner):
   var fire:Dictionary=ticket.sword_fire_ticket.duplicate()
   fire.element_target_ids={enemy.get_instance_id():true}
   ProjectilePool.service(sword_owner.game).launch(sword_owner,SwordFire,"sword-fire",{
    "kind":"fire","position":enemy.global_position,"sound_lead":true,"ignore_cover":false,
    "effect_height":float(ticket.sword_fire_height),"effect_tier":int(fire.skill_rules.effect_tier),
    "cast_hits":[{}],"damage":float(ticket.sword_fire_damage),"attack_ticket":fire})
 if ticket.get("accessory_sure_explosion",false):
  var owner_ref=ticket.get("source_hero")
  var owner=owner_ref.get_ref() if owner_ref is WeakRef else null
  if is_instance_valid(owner):
   var center=AttackChain.effect_anchor(enemy).position
   var radius=preload("res://scripts/spells/skill_balance.gd").BASE_DIAMETER*.5*float(ticket.get("skill_hit_area",1.0))
   var secondary={"source_hero":owner_ref,"allied":ticket.get("allied",false),"action":"accessory_explosion","chain_enabled":false,"critical_chance":0.0}
   owner.game.crowd.army.presentation.sure_strike_burst(center,radius*2.0,false)
   AttackChain.damage_splash(owner,enemy,center,radius,amount,secondary)
 if not ticket.get("spell_fire",false):return
 var source_ref=ticket.get("source_hero")
 var source=source_ref.get_ref() if source_ref is WeakRef else null
 if not is_instance_valid(source):return
 var secondary=ticket.duplicate();secondary.spell_fire=false;secondary.spell_anbu=false
 secondary.erase("responsive_recoil")
 var point=AttackChain.aim_point(enemy)
 source.game.burst(point,Color("ff9a5e"),6,.6)
 for other in AttackChain.enemy_candidates(source.game,point,1.8):
  if not is_instance_valid(other) or other==enemy or other.dead:continue
  if source.game.has_method("forest_enemy_visible") and not source.game.forest_enemy_visible(other):continue
  var contact=AttackChain.contact_point(other,point,other.global_position)
  if contact.distance_to(point)>1.8+other.body_radius:continue
  var ray=PhysicsRayQueryParameters3D.create(point,contact,1)
  if not source.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
  other.take_hit(amount*.25,(contact-point).normalized(),false,secondary)
