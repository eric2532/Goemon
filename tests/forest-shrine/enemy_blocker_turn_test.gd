extends SceneTree
## A waypoint and its blocking wall must not spend the same turn budget in
## opposite directions every tick, leaving a slow boss perpetually walking.
const Model=preload("res://scripts/forest/forest_model.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func run():
 var layout=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_four_gates.json"))
 for variant in [4]:
  var m=Model.new();m.reset(42,{},layout);m.phase="wave"
  var origin=Vector3(6,0,-56.9);origin.y=m.surface_height(origin.x,origin.z)
  check(m.waves.navigation.move_clear(origin,5.35),"The gate-corner encounter starts at a clear supported boss position")
  var target=Vector3(-6,1.8,-60)
  m.defenders[90001]={"id":90001,"pos":target,"hp":1e9,"targetable":true,"taunting":true}
  var e=m.waves.spawn_enemy(variant,origin)
  var initial_hp=float(m.buildings[16].hp)
  for frame in 600:m.waves.tick_enemy(e,1.0/60,Vector3(0,0,18))
  var hp=float(m.buildings.get(16,{"hp":0}).hp)
  check(hp<initial_hp,"Blocked role %d turns to strike the gate instead of endlessly facing its waypoint"%variant)
  check(e.target_kind=="defender" and e.target_id==90001,"Role %d retains the original taunted target while dealing with cover"%variant)
 print("ENEMY_BLOCKER_TURN_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
