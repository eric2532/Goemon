extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
var checks=0
var failures=0
func check(ok: bool,label_: String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func _initialize():run.call_deferred()
func run():
 var m=Model.new();m.reset(42,{}, {"buildings":[],"trees":[],"deposits":[]},false);m.workers.clear()
 var hero=Vector3(100,0,100)
 m.defenders[101]={"id":101,"pos":Vector3(0,0,24),"hp":100,"targetable":true}
 var e=m.waves.spawn_enemy(0,Vector3(0,0,27))
 m.waves.choose_target(e,hero)
 check(e.target_kind=="defender" and e.target_id==101,"Nearby gate defender intercepts a raider")
 check(m.waves.in_reach(e,"defender",101,hero),"Raider can reach the defender at its real height")
 m.waves.start_attack(e,"defender",101,hero);m.events.clear();m.waves.attack_tick(e,.6,hero)
 check(m.events.any(func(ev):return ev.kind=="defender_hit" and ev.id==101 and ev.amount==22),"The native 11-damage melee strike delivers 22 damage at the configured 2x multiplier")
 check(not m.events.any(func(ev):return ev.kind=="hero_hit"),"A defender melee hit does not damage the human")
 var archer=m.waves.spawn_enemy(1,Vector3(0,0,38))
 m.waves.choose_target(archer,hero)
 check(archer.target_kind=="defender","Archers select a gate defender within shooting range")
 m.events.clear();m.waves.arrows.launch(m.waves.projectiles,archer,"defender",101,Vector3(0,1.3,24));m.waves.arrows.tick(m.waves.projectiles,.5,hero)
 check(m.events.any(func(ev):return ev.kind=="defender_hit" and ev.get("projectile",false)),"An enemy arrow sweeps into a live defender")
 m.defenders[101].hp=0
 check(not m.waves.valid_target("defender",101,hero),"A knocked out defender cannot receive another committed strike")
 m.waves.choose_target(e,hero)
 check(e.target_kind!="defender","Enemies choose another target after a defender falls")
 m.defenders[101].hp=100;m.defenders[101].targetable=false
 check(not m.waves.valid_target("defender",101,hero),"Ninja travel immunity is respected by enemy target validation")
 m.defenders[101].targetable=true
 m.waves.projectiles.clear();m.events.clear()
 m.waves.arrows.launch(m.waves.projectiles,archer,"hero",0,Vector3(0,1.3,12));m.waves.arrows.tick(m.waves.projectiles,.5,hero)
 check(m.events.any(func(ev):return ev.kind=="defender_hit"),"Defenders can intercept arrows aimed through their position")
 print("GATE_DEFENDER_TARGETS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
