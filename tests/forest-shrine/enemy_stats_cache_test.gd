extends SceneTree
## Catch stale live balance values, public dictionary aliases and repeated simulation allocations.
const Model=preload("res://scripts/forest/forest_model.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func original_stats(m,variant:int)->Dictionary:
 var stats=Roles.stats(variant)
 if variant==Roles.BOSS:stats.hp=m.balance.boss_health;stats.speed=m.balance.boss_speed
 stats.speed*=m.balance.enemy_speed_mult;stats.hp*=m.balance.enemy_health_mult;stats.damage*=m.balance.enemy_damage_mult
 return stats
func run():
 var m=Model.new();m.reset(90824)
 var w=m.waves
 check(w.has_method("_simulation_stats"),"Simulation has allocation-free shared role stats")
 if not w.has_method("_simulation_stats"):finish();return
 m.balance.boss_health=9000.0;m.balance.boss_speed=2.5
 m.balance.enemy_speed_mult=.5;m.balance.enemy_health_mult=2.0;m.balance.enemy_damage_mult=3.0
 var soldier=w._simulation_stats(0);var boss=w._simulation_stats(4)
 check(soldier.hp==128.0 and soldier.speed==2.16 and soldier.damage==33.0,"Soldier stats retain exact balance multiplication")
 check(boss.hp==18000.0 and boss.speed==1.25 and boss.damage==270.0,"Boss overrides precede the shared multipliers")
 var first=w.role_stats(0);var second=w.role_stats(0)
 first.speed=999.0;first.extra=true;second.erase("damage")
 check(w._simulation_stats(0)==soldier and not w.role_stats(0).has("extra") and w.role_stats(0).damage==33.0,"Public callers retain independent mutable dictionaries")
 m.balance.enemy_speed_mult=2.0;check(w._simulation_stats(0).speed==8.64,"A live speed multiplier change is immediate")
 m.balance.enemy_health_mult=3.0;check(w._simulation_stats(0).hp==192.0,"A live health multiplier change is immediate")
 m.balance.enemy_damage_mult=4.0;check(w._simulation_stats(0).damage==44.0,"A live damage multiplier change is immediate")
 m.balance.boss_health=9100.0;check(w._simulation_stats(4).hp==27300.0,"A live boss health change is immediate")
 m.balance.boss_speed=3.0;check(w._simulation_stats(4).speed==6.0,"A live boss speed change is immediate")
 for role in Roles.COUNT:check(w._simulation_stats(role)==original_stats(m,role),"Every role matches the original arithmetic")
 check(soldier.speed==2.16 and boss.hp==18000.0,"Refreshing the cache preserves previously borrowed snapshots")
 var start=Time.get_ticks_usec()
 for i in 40000:original_stats(m,i%Roles.COUNT)
 var original_us=Time.get_ticks_usec()-start
 start=Time.get_ticks_usec()
 for i in 40000:w._simulation_stats(i%Roles.COUNT)
 var cached_us=Time.get_ticks_usec()-start
 print("ENEMY_STATS_TIMING original_us=",original_us," cached_us=",cached_us)
 check(cached_us<original_us*.9,"Repeated simulation lookups avoid rebuilding dictionaries")
 finish()
func finish():
 print("ENEMY_STATS_CACHE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
