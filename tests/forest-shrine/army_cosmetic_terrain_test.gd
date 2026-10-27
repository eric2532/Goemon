extends SceneTree
class Arena extends Node:
 var model
 var paused=false
 var transitioning=false
class Presentation extends "res://scripts/forest/crowd/army_presentation.gd":
 func draw_effects():pass
 func draw_corpses():pass
var checks=0
var failures=0
var reference_usec=0
var batched_usec=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func reference_tick(rows:Array[Dictionary],delta:float,model,size_:float):
 for i in range(rows.size()-1,-1,-1):
  var row=rows[i];row.age+=delta
  if row.age>=.8:rows.remove_at(i);continue
  var before:Vector3=row.position;var next:Vector3=before+Vector3(row.velocity)*delta
  row.velocity.y-=13.5*1.8*size_*delta;row.pitch-=deg_to_rad(22.5)*30*delta
  var floor_:float=model.surface_height(next.x,next.z)
  if not model.waves.navigation.move_clear(Vector3(next.x,floor_,next.z),preload("res://scripts/forest/forest_enemy_roles.gd").footprint_radius(row.kind,size_)):
   next.x=before.x;next.z=before.z;row.velocity.x=0;row.velocity.z=0
  if next.y<floor_:next.y=floor_;row.velocity=Vector3.ZERO
  row.position=next
func run():
 var rng=RandomNumberGenerator.new();rng.seed=71021
 for map_ in ["kai_highway","blood_gulch","wind_meadow","ramparts","original"]:
  var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.call("load_"+map_)
  var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{},doc.data)
  var corridor=model.waves.navigation.terrain_corridors;var bounds:Rect2=model.world_bounds()
  var points=PackedVector3Array();var radii=PackedFloat64Array()
  for i in 1400:
   points.append(Vector3(rng.randf_range(bounds.position.x-10,bounds.end.x+10),0,rng.randf_range(bounds.position.y-10,bounds.end.y+10)))
   radii.append([0.0,.4,1.3,3.9,8.5,14.75][i%6])
  for r in [.4,1.3,3.9,8.5]:
   var edge=14.0 if r>=8.5 else r
   for x in [bounds.position.x+edge,bounds.end.x-edge]:
    for z in [bounds.position.y+edge,bounds.end.y-edge]:
     for offset in [-.00001,0.0,.00001]:points.append(Vector3(x+offset,0,z));radii.append(r)
  var probes:PackedFloat64Array=corridor.probe(points,radii)
  check(probes.size()==points.size()*2,map_+": one batch retains every point and its full precision height")
  for i in points.size():
   var p:Vector3=points[i];var floor_:float=model.surface_height(p.x,p.z)
   check(probes[i*2]==floor_,map_+": terrain height matches the original sampler exactly")
   check((probes[i*2+1]!=0)==model.waves.navigation.move_clear(Vector3(p.x,floor_,p.z),radii[i]),map_+": original hills, bridges, trees, walls and map-edge clearance remains exact")
  if map_ in ["kai_highway","blood_gulch","wind_meadow"]:
   check(corridor.native_sampler!=null,map_+": real field uses native batched probing")
   var native=corridor.native_sampler
   check(native.probe(PackedVector3Array([Vector3.ZERO]),PackedFloat64Array()).is_empty(),"Mismatched probe buffers are rejected")
   var invalid:PackedFloat64Array=native.probe(PackedVector3Array([Vector3(NAN,0,0),Vector3.ZERO]),PackedFloat64Array([1.3,-1]))
   check(is_nan(invalid[0]) and invalid[1]==0 and is_nan(invalid[2]) and invalid[3]==0,"Non-finite points and negative radii cannot pass clearance")
  else:check(corridor.native_sampler==null,map_+": authored ramparts and custom terrain keep their original sampler")
  var gates:Array=model.buildings.values().filter(func(b):return b.kind=="gate")
  if not gates.is_empty():
   var gate:Dictionary=gates[0];var p:Vector3=model.center(gate)
   for breached in [true,false]:
    gate.breached=breached;model.navigation_revision+=1
    var changed:PackedFloat64Array=corridor.probe(PackedVector3Array([p]),PackedFloat64Array([1.3]))
    var floor_:float=model.surface_height(p.x,p.z)
    check(changed[0]==floor_ and (changed[1]!=0)==model.waves.navigation.move_clear(Vector3(p.x,floor_,p.z),1.3),map_+": breach/repair immediately refreshes cached building contacts")
  var arena=Arena.new();arena.model=model;root.add_child(arena)
  var presentation=Presentation.new();presentation.game=arena;presentation.enemy_size=3;arena.add_child(presentation)
  for i in 128:
   var p:Vector3=points[i];p.y=model.surface_height(p.x,p.z)+float(i%7)*.3
   presentation.corpses.append({"age":float(i%8)*.09,"life":.8,"tumble":true,"kind":[0,1,3][i%3],"position":p,"velocity":Vector3(i%5-2,6,i%9-4)*1.8*3,"yaw":i*.2,"pitch":deg_to_rad(67.5)})
  var reference:Array[Dictionary]=presentation.corpses.duplicate(true)
  for tick in 60:
   var dt=[1.0/60,1.0/30,.025][tick%3]
   var clock=Time.get_ticks_usec();reference_tick(reference,dt,model,3);reference_usec+=Time.get_ticks_usec()-clock
   clock=Time.get_ticks_usec();presentation.tick(dt);batched_usec+=Time.get_ticks_usec()-clock
   check(presentation.corpses==reference,map_+": corpse trajectories, rotation, collision, expiry and removal order remain exact")
  arena.free()
 print("ARMY_COSMETIC_TERRAIN_TIMING reference_usec=",reference_usec," batched_usec=",batched_usec)
 print("ARMY_COSMETIC_TERRAIN_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
