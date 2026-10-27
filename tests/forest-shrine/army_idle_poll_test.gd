extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Snapshot=preload("res://scripts/forest/crowd/army_snapshot.gd")
class CountedHelper extends "res://scripts/forest/crowd/army_helper_unit.gd":
 var reads=0
 func _refresh_shared():
  reads+=1;super._refresh_shared()
class State extends RefCounted:
 var phase="wave"
 var fighter_count=2000
 var defenders={}
class Arena extends Node3D:
 var model=State.new()
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var arena=Arena.new();root.add_child(arena)
 var runtime=Runtime.new();runtime.configure(null);runtime.shared_snapshot_enabled=true
 var director=load("res://scripts/forest/explorer_helpers.gd").new();director.game=arena
 var live=[]
 for i in 2000:
  var unit=CountedHelper.new();unit.runtime=runtime;unit.game=arena;unit.director=director;unit.gate_id=-i-1;unit.slot=i%5
  arena.add_child(unit);unit.handle=runtime.spawn(unit.gate_id,1,11,Vector3(i%50,0,i/50),200,.4);unit.state="acting";unit.hp=200
  director.pool.append(unit);director.actors[unit.gate_id]=unit;live.append(unit)
 for i in 15:
  var unit=CountedHelper.new();unit.runtime=runtime;unit.game=arena;unit.director=director;unit.gate_id=-3000-i;unit.slot=i%5;arena.add_child(unit)
  director.pool.append(unit);director.actors[unit.gate_id]=unit
 runtime.snapshot_epoch+=1;runtime.snapshot_view=Snapshot.new(runtime.render_snapshot())
 for unit in live:unit.reads=0 # Measure pool maintenance separately from field initialization.
 director.prune_pool()
 check(director.pool.size()==2005 and live.all(func(u):return director.pool.has(u)),"Pruning keeps all 2000 live allies plus one idle reserve per kit")
 check(live.all(func(u):return u.reads==0 and u._seen_epoch==-1),"Pool maintenance never refreshes 2000 unrelated combat/status snapshots")
 var first=live[0];first.park()
 check(first.is_idle() and not runtime.valid(first.handle),"Parking immediately changes local pool ownership without polling a snapshot")
 director.prune_pool()
 check(director.pool.filter(func(u):return u.slot==first.slot and u.is_idle()).size()==1,"A newly parked ally replaces excess idle reserves")
 live[1].mark_dead();check(live[1].is_idle(),"Death immediately retires the ally from the live pool")
 for unit in director.pool:unit.free()
 director.pool.clear();director.free();runtime.free();arena.free();await process_frame
 print("ARMY_IDLE_POLL_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
