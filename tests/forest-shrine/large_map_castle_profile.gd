extends "res://tests/forest-shrine/large_army_benchmark.gd"
## Normal-stat battle with real panel/keep destruction during measurement.
var breach_index=0
func _process(delta:float)->bool:
 if phase=="measuring" and breach_index<4 and (Time.get_ticks_usec()-started)/1000000.0>=4+breach_index*4:
  var castle=game.enemy_objectives[0]
  var target=castle.sections[breach_index] if breach_index<3 else castle
  var clock=Time.get_ticks_usec()
  target.take_hit(target.hp+1,Vector3.RIGHT,true,{"tower":true})
  assert(target.dead and target.collision_layer==0,"Destroyed castle target must immediately retire")
  assert(game.model.active_enemy_camps()==(3 if breach_index==3 else 4),"Only a keep stops its reinforcements")
  topology_events.append({"target":"keep" if breach_index==3 else "panel","seconds":(clock-started)/1000000.0,"synchronous_ms":(Time.get_ticks_usec()-clock)/1000.0})
  breach_index+=1
 return super._process(delta)
func finish():
 if breach_index!=4:stopped=true;printerr("FAIL: Castle profile did not complete all four destruction events")
 super.finish()
