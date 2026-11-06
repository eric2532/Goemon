extends Node
## One caster owns one spell's controller, clocks and authored collision rig.
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const RogueRuntime=preload("res://scripts/spells/rogue_spell_runtime.gd")
const KnightLion=preload("res://scripts/knight_lion.gd")
const STATE_FIELDS=["attack_left","attack_duration","attack_heavy","attack_charged","attack_ticket","combo","hit_done","struck_targets","weapon_slot"]
var hero:Hero
var spec:Dictionary
var source_id:int
var source_model:Node3D
var controller:Node
var hero_state:Dictionary={}
var held=false
var surge_owned=false

func setup(caster:Hero,definition:Dictionary):
 hero=caster;spec=definition;source_id=int(spec.source)
 if spec.id=="knight/lion":
  controller=KnightLion.new();controller.hero=hero;controller.game=hero.game;controller.spell_owner=self
  add_child(controller);controller.active=true
 elif source_id>=3 and source_id<=12:
  controller=RogueRuntime.new();controller.spell_owner=self;add_child(controller)
  controller.configure(hero,Catalog.Roster.class_id(source_id))
  if source_id==9:
   source_model=load("res://scripts/rogue_hero_model.gd").new();source_model.class_id=controller.class_id
   hero.add_child(source_model);source_model.combat=controller;controller.sync_actor(source_model.actor)
   hide_source_geometry()
 elif source_id!=1 and spec.method!="flight":
  controller=hero.ROSTER[source_id].combat.new();controller.hero=hero;controller.game=hero.game;controller.spell_owner=self
  if hero.ROSTER[source_id].has("role"):controller.role=hero.ROSTER[source_id].role
  if source_id not in [2,19]:
   source_model=hero.ROSTER[source_id].model.new()
   if hero.ROSTER[source_id].has("character"):source_model.character=hero.ROSTER[source_id].character
   if hero.ROSTER[source_id].has("role"):source_model.role=hero.ROSTER[source_id].role
   hero.add_child(source_model)
   source_model.combat=controller
   hide_source_geometry()
  add_child(controller);controller.active=true
 hero_state=snapshot()
 hero_state.attack_left=0;hero_state.attack_ticket={};hero_state.struck_targets={}

func snapshot()->Dictionary:
 var result={}
 for field in STATE_FIELDS:result[field]=hero.get(field)
 return result

func restore(values:Dictionary):
 for field in values:hero.set(field,values[field])

func cast():
 held=true
 var saved=snapshot();restore(hero_state);align_model()
 match spec.method:
  "dash":hero.forward_dash.start()
  "sky":hero.sky_strike.request()
  "surge":hero.activate_surge();surge_owned=true
  "flight":hero.spell_loadout.flight_enabled=not hero.spell_loadout.flight_enabled
  "teleport":controller.teleport.start()
  "beam":
   if not controller.empowered():controller.activate_shield()
   controller.start_beam("equip")
  "charge":controller.begin_cast("primary");controller.Actions.begin_charge(controller)
  "input":controller.input(event(spec.args[0],true))
  "action":
   controller.player.angle=atan2(hero.facing.x,hero.facing.z)
   controller.secondary_held=spec.args[0]=="flintlock"
   controller.rapid_shot_held=spec.args[0]=="rapid_shot"
   controller.action(spec.args[0])
  _:controller.callv(spec.method,spec.args)
 hero_state=snapshot();restore(saved)
 # A spell never selects a different normal weapon for its wearer.
 hero_state.weapon_slot=saved.weapon_slot

func release():
 held=false
 var saved=snapshot();restore(hero_state)
 if spec.method=="input":
  var release=event(spec.args[0],false)
  if controller.has_method("release_input"):controller.release_input(release)
  else:controller.input(release)
 elif source_id==13 and spec.method=="select_number":controller.assimilation.held=false
 elif spec.method=="charge":controller.Actions.release_charge(controller)
 elif spec.method=="beam":controller.stop_hold_beam()
 elif controller is RogueRuntime:
  controller.rapid_shot_held=false
  controller.secondary_held=false;controller.player.secondaryBuffer=null
  if controller.class_id in ["knight","master-thief"]:
   controller.player.blocking=false;controller.player.guardTime=0
 hero_state=snapshot();restore(saved)

static func event(action:String,pressed:bool)->InputEventAction:
 var result=InputEventAction.new();result.action=action;result.pressed=pressed;return result

func align_model():
 if not is_instance_valid(source_model):return
 source_model.position=Vector3.ZERO
 source_model.rotation=Vector3(0,atan2(-hero.facing.x,-hero.facing.z),0)

func busy()->bool:
 if controller is KnightLion:return controller.is_attacking()
 if spec.method=="flight":return false
 if source_id==1:return hero.forward_dash.active if spec.method=="dash" else hero.sky_strike.active if spec.method=="sky" else false
 if controller is RogueRuntime:
  var p:Dictionary=controller.player
  return controller.rapid_shot_held or p.attack!=null or p.roll>0 or p.travel!=null or p.dive!=null or p.charging or p.blocking or p.guardCounter!=null
 if source_id==2:return controller.is_attacking() or controller.beam_held or controller.blocks_movement()
 if source_id==13:return controller.is_attacking() or controller.guarding()
 return controller.is_attacking()

func step(delta:float)->bool:
 if spec.method=="flight":return false
 var saved=snapshot();restore(hero_state);align_model()
 var controlled=false
 if controller is KnightLion:
  controller.tick(delta)
 elif controller is RogueRuntime:
  controlled=controller.step_spell(delta)
 elif source_id==1:
  if spec.method=="sky" and hero.sky_strike.active:
   hero.sky_strike.tick(delta);controlled=true
  elif spec.method=="dash" and hero.forward_dash.active:
   var from=hero.global_position
   var vertical=hero.velocity.y
   hero.velocity=hero.forward_dash.direction*hero.forward_dash.SPEED*hero.forward_dash.tempo*hero.growth_multiplier()*hero.skill_factor(hero.forward_dash.attack_ticket,"travel_speed");hero.velocity.y=vertical
   if not hero.is_on_floor():hero.velocity.y-=30.0*delta
   hero.move_and_slide();hero.forward_dash.after_move(from,delta);controlled=true
 elif source_id==2:
  controlled=controller.blocks_movement()
  controller.tick(delta,true);controller.after_pose()
 elif source_id==19:
  controller.tick(delta,false)
  if controller.is_attacking():controller.physics_step(delta);controlled=true
 else:
  controller.tick_timers(delta);controller.tick(delta,false)
  if source_id==13 and controller.controls_motion():
   controller.locomotion.physics_step(delta,Vector3.ZERO,false,false,false,false,controller);controlled=true
  align_model()
  source_model.animate(delta,0,hero.is_on_floor(),hero.velocity.y,0,hero.attack_heavy,hero.combo,false)
  if source_id==16:
   for pointer in ["0x9004918","0x90063d8"]:
    if source_model.native_parts.has(pointer):
     if source_model.native_parts[pointer] is GeometryInstance3D:source_model.native_parts[pointer].layers=1 if controller.mode in ["hair_up","hair_forward"] else 0
     for mesh in source_model.native_parts[pointer].find_children("*","GeometryInstance3D",true,false):mesh.layers=1 if controller.mode in ["hair_up","hair_forward"] else 0
  if source_id==17:
   var shield=controller.mode in ["shield_enter","shield","shield_exit"]
   for pointer in source_model.KATANA:
    var part=source_model.native_parts.get(pointer)
    if part is GeometryInstance3D:part.layers=1 if shield else 0
  if source_id==15:
   for mesh in source_model.ben_accessory_meshes:mesh.layers=1 if controller.is_bombing() else 0
  if source_id in [16,17]:
   controller.tick(delta,true)
   if source_id==16 and is_instance_valid(controller.charge_fx):
    if controller.charge_fx.get_parent()!=hero:controller.charge_fx.reparent(hero,true)
    controller.charge_fx.position=Vector3(0,1.1,0)
  if source_id in [14,15,16,17,28,29,30]:
   var motion:Vector3=controller.ground_attack_velocity()
   if motion.is_finite():
    hero.velocity.x=motion.x;hero.velocity.z=motion.z
    if source_id==14 and controller.mode=="smoke_assault":hero.velocity.y=motion.y
  if source_id==15 and controller.bomb_controls_flight():
   hero.velocity.y=controller.bomb_vertical_velocity(delta,false,false)
  elif source_id==16 and controller.controls_vertical_motion():hero.velocity.y=controller.vertical_velocity(delta)
 hero_state=snapshot();restore(saved)
 return controlled

func strike(combat:Node):
 hero.strike(combat)

func filter_damage(amount:float,direction:Vector3,projectile:bool)->float:
 if controller is KnightLion:return amount
 if controller is RogueRuntime or source_id==13:return controller.filter_damage(amount,direction,projectile)
 if source_id==17 and projectile and controller.blocks_projectile(direction):return 0
 if controller!=null and controller.protects_player():return 0
 return amount

func cancel(preserve_power:bool=false,movement:bool=false):
 held=false
 var saved=snapshot();restore(hero_state)
 if controller!=null:
  if movement:
   if controller is RogueRuntime:controller.interrupt_attack_for_movement()
   else:controller.interrupt_for_dodge()
  else:controller.cancel(preserve_power)
 elif spec.method=="sky":hero.sky_strike.cancel()
 elif spec.method=="dash":hero.forward_dash.cancel()
 hero_state=snapshot();restore(saved);hero_state.attack_left=0
 if not preserve_power and surge_owned:hero.end_surge();surge_owned=false

func _exit_tree():
 if is_instance_valid(source_model):source_model.queue_free()

func hide_source_geometry():
 # Authored collision rigs do not draw a second fighter; their emitted effects remain visible.
 for mesh in source_model.find_children("*","GeometryInstance3D",true,false):
  mesh.layers=0;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 source_model.set_process(false)

func can_cast()->bool:
 if source_id==30 and spec.args[0] in [1,2,3,4] and controller.mode=="attack" and controller.move==spec.args[0]:return true
 if source_id==33:return (spec.method=="start_clap" or not controller.is_attacking()) and cooldown_remaining()<=0 and (spec.method!="start_clap" or hero.is_on_floor())
 if source_id in [31,32]:return spec.method=="toggle_immolation" or (not controller.is_attacking() and cooldown_remaining()<=0)
 if controller is KnightLion:return controller.can_cast()
 if source_id==19:return not controller.is_attacking() and (controller.can_homing() if spec.method=="start_homing" else hero.is_on_floor())
 if source_id in [14,15,16,17,28,29,30] and controller!=null and controller.is_attacking():return false
 if source_id==2 and spec.method not in ["activate_shield","teleport"] and not controller.available():return false
 if controller is RogueRuntime:
  if spec.method=="charge":return controller.player.cooldowns.cutlass<=0 and not controller.player.charging
  if spec.method=="action":
   var slot:String=spec.args[0]
   return slot=="rapid_shot" or controller.player.cooldowns[slot]<=0 or (slot=="flintlock" and controller.energy_ready())
 if source_id==2 and spec.method=="activate_shield":return (controller.shield_left<=0 and controller.shield_cooldown<=0) or hero.attack_chain.unleashed()
 if source_id==13:
  if spec.method=="start_leaping_strike":return not hero.is_on_floor() and not controller.is_attacking() and hero.dodge_time<=0
  return (hero.is_on_floor() or (spec.method=="select_number" and spec.args[0]==3)) and not controller.is_attacking()
 if spec.method=="dash":return hero.dodge_cooldown<=0 or hero.attack_chain.unleashed()
 return true

func cooldown_state()->Dictionary:
 if source_id==33:return {"bolt_cooldown":controller.bolt_cooldown,"clap_cooldown":controller.clap_cooldown}
 if source_id in [31,32]:return {"cooldown":controller.cooldown,"wind_cooldown":controller.wind_cooldown,"mirror_cooldown":controller.mirror_cooldown}
 if controller is KnightLion:return {"lion":controller.cooldown}
 if controller is RogueRuntime:return controller.player.cooldowns.duplicate()
 if source_id==2:return {"shield":controller.shield_cooldown}
 return {}

func restore_cooldowns(values:Dictionary):
 if source_id==33:
  for key in ["bolt_cooldown","clap_cooldown"]:controller.set(key,float(values.get(key,0)))
 if source_id in [31,32]:
  for key in ["cooldown","wind_cooldown","mirror_cooldown"]:controller.set(key,float(values.get(key,0)))
 if controller is KnightLion:controller.cooldown=float(values.get("lion",0))
 elif controller is RogueRuntime:controller.player.cooldowns.merge(values,true)
 elif source_id==2:controller.shield_cooldown=float(values.get("shield",0))

func cooldown_remaining()->float:
 if source_id==33:return controller.bolt_cooldown if spec.method=="start_bolt" else controller.clap_cooldown
 if source_id in [31,32]:return controller.wind_cooldown if spec.method=="start_wind" else controller.mirror_cooldown if spec.method=="start_mirrors" else controller.cooldown
 if controller is KnightLion:return controller.cooldown
 if controller is RogueRuntime:
  var slot:String=spec.args[0] if spec.method=="action" else "cutlass"
  return float(controller.player.cooldowns.get(slot,0))
 if source_id==2 and spec.method=="activate_shield":return controller.shield_cooldown
 if spec.method=="dash":return hero.dodge_cooldown
 return maxf(0,float(hero_state.get("attack_left",0))) if busy() else 0.0
