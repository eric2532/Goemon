extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
class CountWaves extends "res://scripts/forest/forest_waves.gd":
 var defender_checks=0
 func valid_target(kind:String,id:int,hero:Vector3)->bool:
  if kind=="defender":defender_checks+=1
  return super.valid_target(kind,id,hero)
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func fresh():
 var m=Model.new();m.reset(42,{}, {"format":"forest_shrine_map","schema":1,"title":"Shared enemy targeting","buildings":[],"trees":[],"deposits":[]})
 m.waves=CountWaves.new(m);m.phase="wave";m.waves.pending=999;m.waves.spawn_clock=1e9;return m
func defender(m,id:int,pos:Vector3,hp:float=100,targetable:bool=true,taunting:bool=false):
 m.defenders[id]={"id":id,"pos":pos,"hp":hp,"targetable":targetable,"taunting":taunting}
func step(m,e):
 e.action="walk";e.action_left=0.0
 m.waves.tick(1.0/60,Vector3(0,0,-120))
func run():
 # Literal equal-distance targets straddle spatial cells. Their insertion
 # order, rather than the order of spatial buckets, owns the original tie.
 var m=fresh();var e=m.waves.spawn_enemy(0,Vector3(0,0,90))
 defender(m,201,Vector3(10,0,90));defender(m,202,Vector3(-10,0,90));step(m,e)
 check(e.target_kind=="defender" and e.target_id==201,"Equal-distance defenders retain their insertion-order target priority")
 m.defenders[201].hp=0;step(m,e)
 check(e.target_id==202,"A defender defeated between world steps is removed from target choices")
 m.defenders[201].hp=100;m.defenders[201].targetable=false;step(m,e)
 check(e.target_id==202,"Travel immunity excludes an otherwise nearest defender")
 m.defenders[201].targetable=true;m.defenders[201].pos=Vector3(100,0,90);m.defenders[202].pos=Vector3(6,0,90);step(m,e)
 check(e.target_id==202,"Moving allies are indexed at their current positions on the next world step")
 defender(m,-1008,Vector3(180,18,180),100,true,true);defender(m,-1020,Vector3(-180,18,-180),100,true,true);step(m,e)
 check(e.target_id==-1008,"The first live Knight taunt retains global priority across distance and height")
 m.defenders[-1008].targetable=false;step(m,e)
 check(e.target_id==-1020,"An invalid first taunt immediately yields to the next live taunt")
 m.defenders[-1020].hp=0;m.waves.choose_target(e,Vector3(0,0,-120))
 check(e.target_id==202,"Direct targeting outside a world step observes a newly defeated taunt immediately")
 defender(m,401,Vector3(20,0,90));e.retaliation_defender=401;e.retaliation=2;step(m,e)
 check(e.target_id==401,"A valid retaliation target keeps priority over a nearer ordinary defender")
 # A nearer objective behind a trunk is pursued by the normal terrain route.
 m=fresh();e=m.waves.spawn_enemy(0,Vector3(0,0,90));defender(m,501,Vector3(8,0,90));defender(m,502,Vector3(-10,0,90));m.trees[Vector2i(1,15)]=1.0;m.rebuild_navigation();step(m,e)
 check(e.target_id==501,"A nearer ally behind a tree is pursued around cover")
 # All roles compare nearest objectives beyond the former aggro envelopes.
 for variant in [0,1,2,3,4]:
  m=fresh();e=m.waves.spawn_enemy(variant,Vector3(0,0,90));defender(m,601,Vector3(20,0,90));step(m,e)
  check(e.target_kind=="defender","Enemy role %d acquires a nearer helper beyond the former aggro radius"%variant)
 m=fresh();e=m.waves.spawn_enemy(0,Vector3(0,0,90));defender(m,701,Vector3(0,4,90));step(m,e)
 check(e.target_kind=="defender" and e.action=="walk","An elevated helper is pursued without attacking through the floor")
 # The break this catches is repeated whole-army validation during one real
 # enemy world step. It must scale with the army plus actual nearby targets.
 m=fresh()
 for index in 48:defender(m,1000+index,Vector3((index%8)*.2,0,90+int(index/8)*.2))
 for index in 80:m.waves.spawn_enemy(0,Vector3(96,0,96+index*.02))
 m.waves.tick(1.0/30,Vector3(0,0,-120))
 print("ENEMY_DEFENDER_VALIDATIONS enemies=80 defenders=48 checks=",m.waves.defender_checks)
 check(m.waves.defender_checks<=48+80*4,"One80-enemy world step avoids revalidating all48 defenders for every enemy")
 check(m.enemies.values().all(func(actor):return actor.target_kind=="defender" and actor.velocity.length()>0),"The optimized targeting step preserves distant pursuit and physical movement")
 print("ENEMY_DEFENDER_SNAPSHOT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
