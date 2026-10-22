extends Node
const GuardFixture=preload("res://tests/forest-shrine/guard_combat_fixture.gd")
## Test-only driver for unchanged player input and original NPC action traces.
const Driver=preload("res://tests/forest-shrine/physics_step_driver.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
class RecordedRaider extends "res://scripts/forest/forest_raider.gd":
 var hits:Array=[]
 var trace_clock:Dictionary={}
 func take_hit(amount:float,direction:Vector3,heavy:bool,ticket:Dictionary={}):
  var before=hp
  super.take_hit(amount,direction,heavy,ticket)
  hits.append([int(trace_clock.get("frame",0)),snappedf(amount,.001),snappedf(before-hp,.001),dead])
var game
var driver
var tree:SceneTree
var cfg="user://large-army-reference-%d.cfg"%OS.get_process_id()
var tick_count=0
var active_tick:Callable
func make_game(layout:String)->Node:
 tree=get_tree();process_mode=Node.PROCESS_MODE_ALWAYS
 Engine.physics_ticks_per_second=600;Engine.time_scale=10
 tree.set_meta("forest_army_backend","legacy");tree.set_meta("forest_fighter",11)
 var doc=load("res://scripts/forest/forest_map_document.gd").new()
 if layout=="kai":doc.load_kai_highway()
 else:doc.load_original()
 tree.set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;tree.root.add_child(game)
 for i in 3:await tree.process_frame
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 driver=Driver.new();driver.process_mode=Node.PROCESS_MODE_ALWAYS;add_child(driver)
 AudioServer.set_bus_mute(0,true)
 freeze_background()
 game.camera_rig.camera.global_position=Vector3(0,24,80);game.camera_rig.camera.look_at(Vector3(0,1,52))
 return game
func freeze_background():
 game.set_physics_process(false);game.set_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 for unit in game.gate_defenders.units.values():unit.set_physics_process(false)
 for unit in game.explorer_helpers.pool:unit.set_physics_process(false)
 for actor in game.actors.values():actor.set_physics_process(false)
func advance(seconds:float)->void:
 await driver.advance(roundi(seconds*60),func(delta):
  seed(71013+tick_count);tick_count+=1
  if active_tick.is_valid():active_tick.call(delta)
 )
func input_map()->Dictionary:
 var result={}
 for action in InputMap.get_actions():
  if str(action).begins_with("ui_"):continue
  result[str(action)]=InputMap.action_get_events(action).map(func(event):return event.as_text())
 return result
func protected_hashes()->Dictionary:
 var result={}
 for path in ["scripts/player.gd","scripts/rogue_roster_combat.gd","assets/rogue/scripts/class_actions.gd","assets/rogue/data/classes.json","scripts/master_chief_combat.gd","scripts/recovered_leader_combat.gd","scripts/recovered_ed_beam.gd","scripts/recovered_musashi_combat.gd","scripts/recovered_goemon_pipe_combat.gd","scripts/recovered_sasuke_combat.gd","scripts/recovered_yae_combat.gd"]:
  if FileAccess.file_exists("res://"+path):result[path]=FileAccess.get_sha256("res://"+path)
 return result
func reset_player(id:int):
 Input.flush_buffered_events()
 for action in InputMap.get_actions():Input.action_release(action)
 # A fresh body resets floor contact/locomotion/controller state as well as
 # visible action fields. Reusing a CharacterBody carries its prior collision.
 game.player.free()
 var p=Hero.new();p.game=game;game.player=p;game.add_child(p);game.camera_rig.player=p
 p.progression.reset(false);p.reset_auto_attack()
 p.select_character(id);p.position=Vector3(0,.15,60);p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.jumps_used=0;p.coyote=.13;p.hp=p.max_hp
 if p.is_rogue_character():p.active_ability.reset_run()
 game.model.update_vision(p.position);tick_count=0
 game.explorer_helpers.clear();game.explorer_helpers.summon_serial=0
 return p
func send_action(action:String,pressed:bool):
 var event=InputEventAction.new();event.action=action;event.pressed=pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()
func clear_targets():
 for actor in game.actors.values():
  if is_instance_valid(actor):actor.free()
 game.actors.clear();game.enemies=game.enemies.filter(func(e):return is_instance_valid(e) and e.training_dummy)
 game.model.enemies.clear()
func add_target(point:Vector3,kind:int=0):
 var data=game.model.waves.spawn_enemy(kind,point)
 var actor=RecordedRaider.new();actor.game=game;actor.forest_id=data.id;actor.variant=kind;actor.swarm=true;actor.position=point
 game.add_child(actor);actor.hp=data.hp;actor.max_hp=data.max_hp;game.actors[data.id]=actor;game.enemies.append(actor)
 actor.set_physics_process(false);actor._sync_fitted_pose()
 return actor
func action_state(p)->String:
 if p.active_ability!=null and p.active_ability.get("player") is Dictionary:
  var state:Dictionary=p.active_ability.player
  if state.get("travel")!=null:return "travel:"+str(state.travel.get("kind",""))
  if state.get("dashAttack")!=null:return "dash"
  if state.get("attack")!=null:return str(state.attack.get("style",""))+":"+str(state.attack.get("index",0))
  if state.get("blocking",false):return "guard"
 return "attack" if p.has_offensive_action() else "idle"
func trace_player(id:int,events:Array)->Dictionary:
 clear_targets();var p=reset_player(id)
 var target=add_target(Vector3(0,0,52));var initial_hp=target.hp
 var samples=[];var states=[];var clock={"frame":0}
 target.trace_clock=clock
 var start=p.position
 active_tick=func(delta):
  var frame:int=clock.frame
  if frame==0:send_action("move_forward",true)
  if frame==18:send_action("move_forward",false)
  if frame==24:send_action("light_attack",true)
  if frame==65:send_action("light_attack",false)
  for event in events:
   if int(event.frame)==frame:send_action(event.action,event.pressed)
  p._physics_process(delta)
  var state=action_state(p)
  if states.is_empty() or states.back()!=state:states.append(state)
  if frame%12==0:samples.append([snappedf(p.position.x,.001),snappedf(p.position.y,.001),snappedf(p.position.z,.001),snappedf(target.hp,.001)])
  clock.frame+=1
 await advance(1.5)
 var movement=snappedf(Vector2(p.position.x-start.x,p.position.z-start.z).length(),.001)
 send_action("light_attack",true);game.show_pause();send_action("light_attack",false)
 var released=not Input.is_action_pressed("light_attack")
 if p.active_ability!=null and p.active_ability.get("primary_held")!=null:released=released and not p.active_ability.primary_held
 game.resume();freeze_background();Engine.time_scale=10
 active_tick=Callable()
 return {"samples":samples,"states":states,"hits":target.hits,"movement":movement,"damage":snappedf(initial_hp-target.hp,.001),"released":released}
func trace_ally(kit:int,_scenario:String)->Dictionary:
 clear_targets();reset_player(11)
 var target=add_target(Vector3(0,0,52));var initial_hp=target.hp
 var h=game.explorer_helpers;var slot=h.KITS.find(kit);GuardFixture.deploy(h,slot);freeze_background()
 var states=[];var samples=[];var clock={"frame":0}
 target.trace_clock=clock
 active_tick=func(delta):
  var frame:int=clock.frame
  for unit in h.pool:
   if unit.state!="idle":unit._physics_process(delta);unit.active_ability.fx.tick(delta)
  h.sync_targets();game.model.update_vision(game.player.position)
  var live=h.active_units(slot)
  var state=action_state(live[0]) if not live.is_empty() else "dead"
  if states.is_empty() or states.back()!=state:states.append(state)
  if frame%12==0:samples.append([snappedf(target.hp,.001),live.size()])
  clock.frame+=1
 await advance(2.0);active_tick=Callable();h.clear()
 return {"states":states,"samples":samples,"hits":target.hits,"damage":snappedf(initial_hp-target.hp,.001),"hp":h.HEALTH[slot],"count":h.COUNTS[slot]}
func close():
 active_tick=Callable()
 for action in InputMap.get_actions():Input.action_release(action)
 game.sound_library.cancel();game.music.stop();game.explorer_helpers.clear();game.queue_free();tree.paused=false
 for i in 4:await tree.process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))

class RecordedNativeRaider extends "res://scripts/forest/crowd/army_enemy_target.gd":
 var hits:Array=[]
 var trace_clock:Dictionary={}
 func take_hit(amount:float,direction:Vector3,heavy:bool,ticket:Dictionary={}):
  var before=hp
  super.take_hit(amount,direction,heavy,ticket)
  hits.append([int(trace_clock.get("frame",0)),snappedf(amount,.001),snappedf(before-hp,.001),dead])

func compare_backends(character_id:int,scenario:String)->Dictionary:
 var result={}
 for backend in ["legacy","native"]:result[backend]=await trace_scenario(character_id,scenario,backend)
 return result

func trace_scenario(id:int,scenario:String,backend:String)->Dictionary:
 for effect in tree.get_nodes_in_group("projectiles"):
  if is_instance_valid(effect):effect.queue_free()
 await tree.process_frame
 clear_targets();game.model.army_runtime=null;game.army_runtime=null
 game.crowd.set_process(false);game.crowd.low_fidelity=false # Compare the original single-soldier OBB, avoiding obsolete formation floor contacts.
 var p=reset_player(id);p.set_physics_process(false);p.model.set_process(false)
 game.character_tuning={};game.tuning.critical_chance=0
 game.camera_rig.yaw=0;game.camera_rig.pitch=0;game.camera_rig.reset_follow();game.camera_rig.update_camera(1)
 var row=game.model.waves.spawn_enemy(0,Vector3(0,0,56));row.hp=10 if scenario=="reward" else 100000;row.max_hp=row.hp
 var runtime
 var target
 if backend=="native":
  runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();game.add_child(runtime);runtime.configure(game)
  runtime.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model))
  game.model.army_runtime=runtime;game.army_runtime=runtime
  var handle:int=runtime.spawn(row.id,0,0,row.pos,row.hp,3.9)
  target=RecordedNativeRaider.new();target.runtime=runtime;target.game=game;target.handle=handle;target.forest_id=row.id;target.variant=0
  game.add_child(target);runtime.enemies[row.id]=target;target.sync(runtime.unit_state(handle));runtime.register_actor_facade(target,row)
 else:
  target=RecordedRaider.new();target.game=game;target.forest_id=row.id;target.variant=0;target.swarm=true;target.position=row.pos
  game.add_child(target);target.set_physics_process(false);target._sync_fitted_pose();target.hp=row.hp;target.max_hp=row.hp
 game.actors[row.id]=target;game.enemies.append(target)
 await tree.physics_frame
 await tree.physics_frame
 game.camera_rig.impulse=0;game.camera_rig.kick_age=1;game.camera_rig.kick_strength=0;game.camera_rig.first_person_recoil=0
 game.camera_rig.distance=14;game.camera_rig.current_distance=14;game.camera_rig.camera.fov=63
 game.camera_rig.reset_follow();game.camera_rig.update_camera(1)
 var initial_hp:float=row.hp;var initial_kills:int=game.kills;var initial_gold:int=game.model.gold
 var clock={"frame":0};target.trace_clock=clock
 var samples=[];var states=[];var action="light_attack"
 match scenario:
  "secondary":action="heavy_attack"
  "utility_tap","utility_hold":action="equip"
  "skill":action="surge"
 var release_frame=3 if scenario=="utility_tap" else 75
 active_tick=func(dt):
  var frame:int=clock.frame
  if frame==0:
   send_action("move_forward" if scenario=="movement" else action,true)
  if scenario=="movement":
   if frame==18:send_action("move_forward",false);send_action("move_right",true)
   if frame==30:send_action("jump",true)
   if frame==31:send_action("jump",false)
   if frame==45:send_action("move_right",false);send_action("dodge",true)
   if frame==46:send_action("dodge",false)
  elif frame==release_frame:send_action(action,false)
  if scenario=="switch" and frame==45:p.select_character(15 if id!=15 else 14)
  p._physics_process(dt)
  for effect in tree.get_nodes_in_group("projectiles"):
   if not is_instance_valid(effect) or effect.is_queued_for_deletion():continue
   effect.set_physics_process(false)
   if effect.has_method("_physics_process"):effect._physics_process(dt)
  var state=action_state(p)
  if states.is_empty() or states.back()!=state:states.append(state)
  if frame%6==0:
   samples.append([snappedf(p.position.x,.001),snappedf(p.position.y,.001),snappedf(p.position.z,.001),snappedf(maxf(0,target.hp),.001),snappedf(p.facing.x,.001),snappedf(p.facing.y,.001),snappedf(p.facing.z,.001),p.rogue_untargetable()])
  clock.frame+=1
 await advance(3.0);active_tick=Callable()
 send_action(action,true);game.show_pause();send_action(action,false)
 var released=not Input.is_action_pressed(action)
 for field in ["primary_held","secondary_held","utility_held"]:
  if p.active_ability!=null and p.active_ability.get(field)!=null:released=released and not p.active_ability.get(field)
 game.resume();freeze_background();Engine.time_scale=10
 var hits=target.hits.duplicate(true)
 if scenario=="reward":
  for hit in hits:hit[2]=minf(hit[2],initial_hp)
 var result={"samples":samples,"states":states,"hits":hits,"released":released,"input_map":input_map(),"rewards":[game.kills-initial_kills,game.model.gold-initial_gold,game.model.ryo.claimed_enemies.has(row.id)]}
 if p.active_ability!=null and p.active_ability.has_method("cancel"):p.active_ability.cancel()
 for effect in tree.get_nodes_in_group("projectiles"):
  if is_instance_valid(effect):effect.queue_free()
 clear_targets();game.model.army_runtime=null;game.army_runtime=null
 if runtime!=null:runtime.clear();runtime.queue_free()
 await tree.process_frame
 return result
