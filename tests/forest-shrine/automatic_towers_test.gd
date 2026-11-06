extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Document=preload("res://scripts/forest/forest_map_document.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",note)
func run():
 for large in [false,true]:
  var doc=Document.new(false)
  check((doc.load_wind_meadow_large() if large else doc.load_wind_meadow()).is_empty(),"Load bundled map")
  var m=Model.new();m.reset(42,{},doc.data,false)
  var guard=m._make_building("tower",Vector2i(0,8),0)
  var towers=m.buildings.values().filter(func(b):return b.kind in ["tower","cannon_tower"])
  check(not towers.is_empty() and m.workers.values().all(func(w):return m.buildings.get(w.job,{}).get("kind","") not in ["tower","cannon_tower"]),"Map towers leave the starting workers free")
  var workforce=m.workforce
  var cannon=m._make_building("cannon_tower",Vector2i(4,8),0);towers.append(cannon)
  for tower in towers:
   check(workforce.capacity(tower)==0 and workforce.assign_workers(tower.id)==0,"Tower never takes a worker reservation")
  m.workers.clear();m.phase="wave"
  for tower in [towers[0],cannon]:
   var center:Vector3=m.center(tower)
   var point=center+Vector3(0,0,24);point.y=m.surface_height(point.x,point.z)
   var target=m.waves.spawn_enemy(0,point);target.hp=100000;target.max_hp=100000
   m.update_vision(center)
   for b in towers:b.clock=1000
   tower.clock=0
   for cycle in 3:
    workforce.arrows.clear();m.events.clear();tower.clock=0
    workforce.tick(0,center)
    var shots=workforce.arrows.values()
    check(shots.size()==m.balance.tower_workers and shots.all(func(s):return s.target==target.id),"Empty tower fires its complete configured volley")
    check(is_equal_approx(tower.clock,workforce.attack_interval(tower)),"Tower owns the existing reload interval")
    var serial=m.next_id
    workforce.tick(.1,center)
    check(m.next_id==serial,"Tower cannot fire again during reload")
   m.team_progression.ranks.tower_speed=2;m.team_progression.ranks.tower_damage=2
   var config=m.balance.duplicate(true);config.tower_workers=1;config.tower_attack_speed=2
   tower.clock=100;m.apply_tower_balance(config)
   check(is_equal_approx(tower.clock,workforce.attack_interval(tower)),"Live speed tuning clamps the building cooldown")
   workforce.arrows.clear();tower.clock=0;workforce.tick(0,center)
   check(workforce.arrows.size()==1 and is_equal_approx(tower.clock,(workforce.CANNON_INTERVAL if tower.kind=="cannon_tower" else 1.0)/3.0),"Saved volley count and team speed upgrades work without workers")
   if tower.kind=="cannon_tower":check(is_equal_approx(workforce.arrows.values()[0].damage,100.5*1.6),"Cannon retains upgraded damage")
   m.phase="preparing";workforce.arrows.clear();tower.clock=0;workforce.tick(5,center)
   check(workforce.arrows.is_empty() and tower.clock==0,"Preparation never fires a tower")
   m.phase="wave";m.visible_cells.clear();workforce.tick(0,center)
   check(workforce.arrows.is_empty(),"Hidden targets are not acquired")
   m.update_vision(center);target.hp=0;workforce.tick(0,center)
   check(workforce.arrows.is_empty(),"Dead targets are not acquired")
   target.hp=100000;tower.hp=0;workforce.tick(0,center)
   check(workforce.arrows.is_empty(),"Dead towers never fire")
   tower.hp=tower.max_hp;m.enemies.clear();m.team_progression.ranks.clear()
  m.phase="preparing";var saved=Document.new(false);saved.capture(m)
  var loaded=Document.new(false)
  check(loaded.decode(saved.encode()).is_empty(),"Existing map format roundtrips autonomous towers")
  m.reset(43,{},loaded.data,false)
  check(m.workers.values().all(func(w):return m.buildings.get(w.job,{}).get("kind","") not in ["tower","cannon_tower"]) and m.buildings.values().filter(func(b):return b.kind in ["tower","cannon_tower"]).all(func(b):return b.clock==0),"Restart resets tower cooldowns and keeps workers free")
 print("AUTOMATIC_TOWERS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
