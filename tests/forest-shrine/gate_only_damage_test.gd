extends SceneTree
## Catches perimeter destruction, lost breach frames and repairs spending on walls.
const Model=preload("res://scripts/forest/forest_model.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func fresh():
 var m=Model.new();preload("res://tests/forest-shrine/empty_settlement.gd").reset(m)
 m.trees.clear();m.gold=1000
 while m.workers.size()>2:m.workers.erase(m.workers.keys().back())
 var wall=m._make_building("wall",Vector2i(-8,7),0,6)
 var gate=m._make_building("gate",Vector2i(0,7),0)
 m.rebuild_navigation()
 for w in m.workers.values():w.pos=m.point(Vector2i(0 if w.id%2==0 else 1,6))
 return {"m":m,"wall":wall,"gate":gate}
func work(m,seconds:float):
 for i in roundi(seconds/.05):m.workforce.tick(.05,m.hero_position)
func run():
 var f=fresh();var m=f.m;var wall=f.wall;var gate=f.gate
 m.phase="wave";var nav=m.navigation_revision
 m.damage_building(wall.id,1000000)
 check(m.buildings.has(wall.id) and wall.hp==wall.max_hp,"Overwhelming enemy damage cannot break or damage a perimeter wall")
 check(m.navigation_revision==nav and m.events.is_empty(),"Wall attacks create neither breaches nor damage events")
 m.phase="preparing";wall.hp=wall.max_hp-100
 var money=m.gold;m.workforce.auto_assign();work(m,2)
 check(m.workers.values().all(func(w):return w.job!=wall.id) and m.gold==money,"Workers never reserve or spend ryo repairing indestructible walls")
 check(not m.repair(wall.id) and m.gold==money,"Manual wall repair cannot spend ryo either")
 m.phase="wave";m.damage_building(gate.id,500)
 check(gate.hp==1500 and m.events.any(func(e):return e.kind=="wall_damage" and e.id==gate.id),"Only the door takes gate damage and emits its cracking feedback")
 check(not m._line_visible(Vector2i(0,5),Vector2i(0,9),false),"A closed door blocks ground-level sight")
 m.events.clear();nav=m.navigation_revision;m.damage_building(gate.id,1000000)
 check(m.buildings.has(gate.id) and gate.hp==0 and gate.get("breached",false),"A destroyed door leaves the same permanent gate frame in the model")
 check(m.occupancy.get(gate.cell,-1)==gate.id and m.navigation_revision>nav,"A breach retains frame occupancy and invalidates closed-door navigation")
 if not m.buildings.has(gate.id):finish();return
 check(m._line_visible(Vector2i(0,5),Vector2i(0,9),false),"An open breach reveals enemies through the doorway")
 nav=m.navigation_revision;m.damage_building(gate.id,1000000)
 check(m.navigation_revision==nav,"Repeated attacks cannot repeatedly destroy a breached frame")
 m.phase="preparing";m.gold=300;work(m,35)
 check(gate.hp==gate.max_hp and not gate.get("breached",false),"Workers rebuild a completely destroyed door instead of losing its repair job")
 check(m.gold==100,"A full 2000 HP door costs exactly 200 ryo to rebuild")
 check(m.workers.values().all(func(w):return w.job!=gate.id),"Fully rebuilt doors release repair crews")
 m.phase="wave";m.damage_building(gate.id,1000000);m.phase="preparing";m.gold=199
 check(not m.repair(gate.id) and m.gold==199,"An unaffordable destroyed-door repair cannot spend funds")
 m.gold=200
 check(m.repair(gate.id) and gate.hp==2000 and not gate.get("breached",false) and m.gold==0,"Manual preparation repair restores the same door for the exact price")
 # A rebuilt leaf must not trap enemies that are still passing through it.
 m.phase="wave";m.damage_building(gate.id,1000000);gate.hp=1990;m.gold=1
 var enemy=m.waves.spawn_enemy(0,m.center(gate));enemy.hp=100
 var worker=m.workers.values()[0];worker.job=gate.id;worker.state="repair";worker.timer=0
 m.workforce.repairs.tick(worker,gate,.25)
 check(gate.hp==2000 and gate.get("breached",false) and m.gold==0,"A paid rebuilt door waits open while an enemy occupies its passage")
 m.enemies.clear();m.workforce.tick(.05,m.hero_position)
 check(not gate.get("breached",false) and m.gold==0,"A fully paid door closes when clear without requiring more ryo")
 # The shrine remains the defended objective after enemies enter a breach.
 m.damage_building(1,1000000)
 check(m.phase=="defeat","Enemies that enter can still destroy the defended shrine")
 f=fresh();m=f.m;gate=f.gate;m.phase="wave"
 var inside=m.center(gate)-Vector3.BACK*5
 var outside=m.center(gate)+Vector3.BACK*5
 m.waves.spawn_enemy(0,outside)
 for health in [100.0,2000.0]:
  gate.hp=health;gate.breached=true
  check(not m.workforce.repairs.wall_between(inside,outside),"An absent door is not cover at repaired HP %d"%health)
  check(m.workforce.threatened(inside),"Workers detect enemies through an open breach at repaired HP %d"%health)
 gate.breached=false
 check(m.workforce.repairs.wall_between(inside,outside) and not m.workforce.threatened(inside),"A restored closed door protects its inner repair face again")
 finish()
func finish():
 print("GATE_ONLY_DAMAGE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
