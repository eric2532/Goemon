extends SceneTree
class Actor extends Node:
 var handle=10
 var hp=100.0
 var synced=[]
 func set_enemy_kind(_kind:int):pass
 func sync(data:Dictionary):hp=data.hp;synced.append(hp)
class WaveGate extends RefCounted:
 var hits=[]
 func enemy_started_attack(id:int):hits.append(id)
class Model extends RefCounted:
 var enemies={8:{"hp":100.0}}
 var waves=WaveGate.new()
 var callback:Callable
 func damage_worker(_id:int,_amount:float):callback.call()
class Arena extends Node:
 var model=Model.new()
class Delivery extends "res://scripts/forest/crowd/army_runtime.gd":
 var queued=[]
 var hp_now=40.0
 var reads=0
 func _take_scene_events()->Array:
  var result=queued;queued=[];return result
 func unit_state(_handle:int)->Dictionary:
  reads+=1;return {"hp":hp_now}
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func damage(serial:int,hp:float)->Dictionary:
 return {"serial":serial,"kind":"damage","target_id":8,"team":0,"ticket_id":1,"hp":hp,"source_id":2,"unit_kind":0,"amount":30.0}
func run():
 var arena=Arena.new();root.add_child(arena);var runtime=Delivery.new();runtime.game_ref=weakref(arena);runtime.pooled_presentation=true;runtime.collect_stats=true
 var actor=Actor.new();arena.add_child(actor);runtime.enemies[8]=actor;runtime.tickets[1]={"tower":true,"critical":true}
 runtime.queued=[{"serial":1,"kind":"muzzle"},damage(2,70),{"serial":3,"kind":"bullet"},{"serial":4,"kind":"external_damage","external_kind":1,"target_id":9,"source_id":2,"amount":1}]
 var seen=[]
 arena.model.callback=func():
  seen.assign(runtime.presentation_events.map(func(e):return e.serial));runtime.hp_now=20.0
  runtime.queued=[{"serial":5,"kind":"melee"},damage(6,20)];runtime.dispatch_events()
 runtime.dispatch_events()
 check(seen==[1,2,3],"Callbacks observe exactly the preceding presentation events, without future events")
 check(runtime.presentation_events.map(func(e):return e.serial)==[1,2,3,4,5,6],"Nested drains preserve every gameplay and cosmetic event in source order")
 check(actor.synced==[40.0,20.0] and actor.hp==20 and arena.model.enemies[8].hp==20,"Damage observes live state after a nested callback rather than a stale cached hit snapshot")
 check(runtime.reads==2 and runtime.event_gaps==0 and runtime.observed_counts=={"muzzle":1,"damage":2,"bullet":1,"external_damage":1,"melee":1},"Cosmetics require no unit-state reads and diagnostics retain exact event counts")
 check(runtime.tickets.is_empty() and runtime.event_log.size()==6 and not runtime.dispatching,"Tickets drain only after callbacks and recording retains all events")
 check(runtime.presentation_events.filter(func(e):return e.kind=="damage").all(func(e):return e.critical),"Player critical tickets survive dispatch until pooled presentation consumes them")
 runtime.record_events=false;runtime.presentation_events.clear();runtime.event_log.clear();runtime.queued=[]
 for i in 4000:runtime.queued.append({"serial":7+i,"kind":"projectile_impact"})
 runtime.dispatch_events()
 check(runtime.presentation_events.size()==4000 and runtime.event_log.is_empty() and runtime.reads==2,"Production cosmetic delivery keeps all 4000 events without gameplay dictionaries or state reads")
 var native_hit=damage(4007,10);native_hit.critical=true;runtime.queued=[native_hit];runtime.dispatch_events()
 check(runtime.presentation_events.back().critical,"Native ally critical flags survive dispatch without a player ticket")
 check(arena.model.waves.hits.is_empty(),"Landed damage does not control the attack-start gate")
 runtime.queued=[{"serial":4008,"kind":"attack_started","source_id":2}];runtime.dispatch_events()
 check(arena.model.waves.hits==[2],"Attack startup reaches the wave gate with no damage event")
 runtime.queued=[{"serial":4008,"kind":"attack_started","source_id":2}];runtime.dispatch_events()
 check(arena.model.waves.hits==[2],"A duplicate native event cannot retrigger attack startup")
 runtime.free();arena.free();print("ARMY_EVENT_DISPATCH_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
