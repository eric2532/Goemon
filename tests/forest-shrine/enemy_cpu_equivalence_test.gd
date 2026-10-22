extends SceneTree
## Exact state/event comparison, including live tuning, status and geometry changes.
const Model=preload("res://scripts/forest/forest_model.gd")
const Original=preload("res://tests/forest-shrine/enemy_cpu_reference.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func run():
 var layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_blood_gulch.json"))
 var a=Model.new();a.reset(90824,{"waves":[[1200,1200,0,1200]]},layout)
 var b=Model.new();b.reset(90824,{"waves":[[1200,1200,0,1200]]},layout);Original.install(b)
 a.buildings[1].hp=1000000000.0;b.buildings[1].hp=1000000000.0;a.start_wave();b.start_wave()
 var hero=Vector3(0,a.surface_height(0,18),18)
 var peak=0
 var optimized_us=0;var reference_us=0
 for step in 1400:
  for m in [a,b]:
   if step==400:m.balance.enemy_speed_mult=.9;m.balance.enemy_damage_mult=.8
   if step==600:
    for enemy in m.enemies.values():
     if enemy.id%7==0:enemy.frozen=.15
     if enemy.id%11==0:enemy.stun=.2
   if step==800:
    for building in m.buildings.values():
     if building.kind=="gate":m.damage_building(building.id,1000000);break
   if step==1050:
    for building in m.buildings.values():
     if building.kind=="gate" and building.get("breached",false):building.breached=false;building.hp=building.max_hp;m.rebuild_navigation();break
   var started=Time.get_ticks_usec();m.tick(.05,hero)
   if step>=1100:
    if m==a:optimized_us+=Time.get_ticks_usec()-started
    else:reference_us+=Time.get_ticks_usec()-started
  var same=a.enemies==b.enemies and a.workers==b.workers and a.buildings==b.buildings and a.waves.projectiles==b.waves.projectiles and a.events==b.events and a.phase==b.phase and a.waves.pending==b.waves.pending and a.gold==b.gold
  checks+=1;peak=maxi(peak,a.enemies.size())
  if not same:
   printerr("FAIL: CPU optimization changes gameplay at step ",step+1)
   for id in a.enemies:
    if a.enemies.get(id)!=b.enemies.get(id):printerr("FIRST_ENEMY_DIFFERENCE id=",id," optimized=",a.enemies[id]," original=",b.enemies.get(id));break
   failures+=1;break
  a.events.clear();b.events.clear()
  if step%200==199:print("CPU_EQUIVALENCE_PROGRESS step=",step+1," enemies=",a.enemies.size())
 checks+=1
 if peak!=240:failures+=1;printerr("FAIL: The sustained comparison must reach the unchanged 240-enemy active cap, got ",peak)
 print("ENEMY_CPU_SUSTAINED_TIMING optimized_ms=",optimized_us/300000.0," reference_ms=",reference_us/300000.0)
 print("ENEMY_CPU_EQUIVALENCE_RESULT checks=%d failures=%d peak_enemies=%d"%[checks,failures,peak]);quit(1 if failures else 0)
