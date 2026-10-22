extends SceneTree
## A clear physical spawn can round onto a conservative cliff cell. Chasing
## from that offset must enter the grid through a safe segment, not freeze.
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Model=preload("res://scripts/forest/forest_model.gd")
const LAYOUT="res://assets/maps/forest_four_gates.json"
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func fresh():
 var m=Model.new();m.reset(42,{"bosses_per_portal":0,"waves":[[0,0,0,0]]},JSON.parse_string(FileAccess.get_file_as_string(LAYOUT)));m.start_wave();return m
func run():
 for portal_index in 8:
  var m=fresh();var portal=m.portals[portal_index];var forward=m.waves.routes.direction(portal)
  var origin=m.waves.routes.exit_point(portal,0);origin.y=m.surface_height(origin.x,origin.z)
  var hero:Vector3=origin+forward*12;m.hero_position=hero
  # A previous enlarged soldier occupies the center. Use the real portal spawn
  # search to choose its next clear lateral slot, just as a crowded wave does.
  var blocker=m.waves.spawn_enemy(0,origin)
  var spawned=m.waves.routes.spawn(0,[],portal_index)
  check(spawned,"Portal %d admits a real offset arrival"%portal_index)
  m.enemies.erase(blocker.id)
  if not spawned:continue
  var e=m.enemies.values()[0];var start:Vector3=e.pos;var safe=true
  for frame in 180:
   var previous:Vector3=e.pos;m.waves.tick_enemy(e,1.0/60,hero)
   safe=safe and m.terrain.step_clear(previous,e.pos) and m.waves.navigation.move_clear(e.pos,Roles.footprint_radius(e.variant))
  check(e.pos.distance_to(start)>5 or e.attack,"A portal %d arrival chases the nearby player without a Knight (%s -> %s)"%[portal_index,str(start),str(e.pos)])
  check(safe,"Portal %d pursuit stays on the supported wall surface"%portal_index)
 # A taunt or moving chase can leave a valid lane at a later wall/ramp corner.
 # These retain the measured lane interruption offsets, inset for enlarged body clearance.
 for point in [Vector3(-118.5409,18,10.5),Vector3(10.5,14.42563,-102.0854)]:
  var m=fresh();m.defenders[90001]={"id":90001,"pos":Vector3(0,0,18),"hp":1e9,"targetable":true,"taunting":true}
  var e=m.waves.spawn_enemy(0,point);var safe=true
  for frame in 240:
   var previous:Vector3=e.pos;m.waves.tick_enemy(e,1.0/60,Vector3(0,0,18))
   safe=safe and m.terrain.step_clear(previous,e.pos) and m.waves.navigation.move_clear(e.pos,Roles.footprint_radius(e.variant))
  check(e.pos.distance_to(point)>10,"An interrupted lane at %s can resume its pursuit"%str(point))
  check(safe,"Rejoining from %s never cuts across a cliff"%str(point))
 # A bridge must not invent a route out of an unsafe physical position.
 var m=fresh();var unsafe=m.waves.spawn_enemy(0,Vector3(-198,18,110.5))
 check(m.waves.navigation.route(unsafe,Vector3.ZERO).is_empty(),"A body straddling a cliff cannot be projected across the drop")
 var tree_data={"format":"forest_shrine_map","schema":1,"title":"Tree fixture","buildings":[],"trees":[{"x":10,"z":10,"scale":1.0}],"deposits":[]}
 m=Model.new();m.reset(42,{},tree_data)
 var trapped=m.waves.spawn_enemy(0,Vector3(60,0,60))
 check(m.waves.navigation.route(trapped,Vector3(0,0,18)).is_empty(),"A spawn inside a tree cannot tunnel through its trunk to join a path")
 print("ENEMY_ROUTE_ENTRY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
