extends Node
## Per-fighter assignments; native controls remain the default until a slot is edited.
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const Instance=preload("res://scripts/spells/spell_instance.gd")
var hero:Hero
var instances:Dictionary={}
var retired_cooldowns:Dictionary={}
var flight_enabled=false
var held_slots:Dictionary={}
var current:Node
var dispatching=false
var casting_id=""
var numbered_slots:Array=[]
var held_numbers:Dictionary={}

func assignments(character:int)->Dictionary:
 var saved=Catalog.valid_loadouts(hero.game.settings.get("spell_loadouts",{}))
 var slots:Dictionary=saved.get(str(character),{}).duplicate()
 if character==7 and not slots.has("sky_strike"):slots.sky_strike="knight/lion"
 return slots

func spell_for(character:int,action:String)->String:
 return str(assignments(character).get(action,Catalog.defaults(character).get(action,"")))

func equip(character:int,action:String,id:String)->bool:
 if character not in Catalog.Roster.PLAYABLE_IDS or not Catalog.SLOTS.has(action) or (not id.is_empty() and not Catalog.all().has(id)):return false
 cancel()
 var saved=Catalog.valid_loadouts(hero.game.settings.get("spell_loadouts",{}))
 var slots:Dictionary=saved.get(str(character),{})
 if id.is_empty():slots.erase(action)
 else:slots[action]=id
 if slots.is_empty():saved.erase(str(character))
 else:saved[str(character)]=slots
 hero.game.settings.spell_loadouts=saved;hero.game.save_settings()
 prepare()
 return true

func prepare():
 hero.jump_style.prepare()
 numbered_slots=slots_for(hero.character_id)
 # Selection/equipment pays setup once; input only starts prepared controllers.
 var equipped=assignments(hero.character_id).values().filter(func(id):return not hero.mirror_copy or id!="blademaster/mirror-image")
 for key in instances.keys():
  if key.begins_with("%d:"%hero.character_id) and equipped.has(instances[key].spec.id):continue
  retired_cooldowns[key]=instances[key].cooldown_state()
  instances[key].queue_free();instances.erase(key)
 for id in equipped:_instance(id)
 if not hero.mirror_copy:
  var kits=[hero.active_ability]
  for instance in instances.values():kits.append(instance.controller)
  for kit in kits:
   if is_instance_valid(kit) and kit.has_method("start_mirrors") and kit.mirrors!=null:kit.mirrors.prepare_loadout()

func slots_for(character:int)->Array:
 var result=Catalog.hotbar(character)
 var equipped=assignments(character)
 for i in 5:
  var action=Catalog.SLOTS.keys()[i]
  if equipped.has(action):result[i]=[Catalog.all()[equipped[action]].name,action]
 return result

func number_input(number:int,pressed:bool):
 if number<1 or number>5:return
 if not pressed:
  var slot:Array=held_numbers.get(number,[]);held_numbers.erase(number)
  if slot.is_empty():return
  if slot[1]=="select_number":
   if hero.character_id==13 and slot[2]==7:hero.active_ability.assimilation.held=false
  elif slot.size()==2:
   var release=Instance.event(slot[1],false)
   hero._input(release);hero._unhandled_input(release)
  return
 if held_numbers.has(number) or numbered_slots.size()!=5:return
 if not hero.game.playing or hero.game.transitioning or hero.hp<=0 or hero.ai_controlled or hero.combat_hold_left>0:return
 var slot:Array=numbered_slots[number-1]
 if slot.is_empty():return
 # Weapon selection is useful on the preparation map; casting obeys normal pause gates.
 if slot[1]=="select_slot":hero.master_chief_combat.select_slot(slot[2])
 elif hero.game.paused:return
 elif slot.size()==2:hero._unhandled_input(Instance.event(slot[1],true))
 elif hero.dodge_time<=0:
  if slot[1]=="start_hair":hero.active_ability.cancel()
  elif slot[1] not in ["select_number"] and hero.active_ability.is_attacking():return
  hero.active_ability.callv(slot[1],slot.slice(2))
 held_numbers[number]=slot

func action_pressed(action:String)->bool:
 return Input.is_action_pressed(action) or held_numbers.values().any(func(slot):return slot.size()==2 and slot[1]==action)

func number_event(event:InputEvent)->bool:
 if not event is InputEventKey:return false
 var number=(event.physical_keycode if event.physical_keycode else event.keycode)-KEY_1+1
 if number<1 or number>5:return false
 if not event.pressed:
  number_input(number,false);return true
 if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:return true
 # Shift keeps construction shortcuts during preparation and permits sprinting casts in battle.
 if event.shift_pressed and hero.game.get("model")!=null and hero.game.model.phase=="preparing":return false
 if not event.echo:number_input(number,true)
 return true

func _instance(id:String)->Node:
 var key="%d:%s"%[hero.character_id,id]
 if not instances.has(key):
  var instance=Instance.new();add_child(instance);instance.setup(hero,Catalog.all()[id]);instance.restore_cooldowns(retired_cooldowns.get(key,{}));instances[key]=instance
 return instances[key]

func input(event:InputEvent)->bool:
 var slots=assignments(hero.character_id)
 for action in slots:
  if not event.is_action(action):continue
  if event.is_echo():return true
  if event.is_action_pressed(action):
   var instance=instances.get("%d:%s"%[hero.character_id,slots[action]])
   if instance==null:return true
   if instance==current and instance.held:
    held_slots[action]=instance;return true
   if not instance.can_cast():return true
   if instance==current and (instance.spec.method=="sky" or (instance.source_id==30 and instance.spec.args[0] in [1,2,3,4])):
    held_slots[action]=instance;dispatching=true;casting_id=instance.spec.id;instance.cast();casting_id="";dispatching=false;return true
   if current!=null and current!=instance:interrupt()
   hero.interrupt_attack_for_movement()
   held_slots[action]=instance
   dispatching=true;casting_id=instance.spec.id;instance.cast();casting_id="";dispatching=false
   if instance.busy():current=instance
  return true
 if current!=null and (event.is_action_pressed("light_attack") or event.is_action_pressed("heavy_attack") or event.is_action_pressed("dodge")):
  interrupt()
 return false

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
  var rooted=current.source_id in [13,14,15,16,28,29] and current.spec.method not in ["surge","start_super_jump"]
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
 if hero.model.has_method("animate_spell"):hero.model.animate_spell(delta,current)
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
 if current!=null:
  dispatching=true;current.cancel(true,true);dispatching=false;current=null
 held_slots.clear()
 hero.attack_left=0;hero.impact_pause=0

func cancel(preserve_power:bool=false):
 if dispatching:return
 dispatching=true
 for instance in instances.values():instance.cancel(preserve_power)
 dispatching=false;current=null;held_slots.clear();held_numbers.clear()
 if not preserve_power:flight_enabled=false

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
 var key="%d:%s"%[hero.character_id,spell_for(hero.character_id,action)]
 return instances[key].cooldown_remaining() if instances.has(key) else 0.0

static func damage_for_hit(enemy,amount:float,ticket:Dictionary)->float:
 if ticket.get("warcraft_opening",false):amount*=2.0
 if ticket.get("spell_riposte",false):amount*=1.8
 if ticket.get("spell_anbu",false) and randf()<.25:
  return amount+45 if enemy.boss else maxf(amount,enemy.hp)
 return amount

static func hit_effects(enemy,amount:float,ticket:Dictionary):
 if not ticket.get("spell_fire",false):return
 var source_ref=ticket.get("source_hero")
 var source=source_ref.get_ref() if source_ref is WeakRef else null
 if not is_instance_valid(source):return
 var secondary=ticket.duplicate();secondary.spell_fire=false;secondary.spell_anbu=false
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
