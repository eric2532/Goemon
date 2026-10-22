extends SceneTree
## Catch mandatory road detours, wrong-side gates, stale gate targets and unsafe approaches.
const Model=preload("res://scripts/forest/forest_model.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func layout()->Dictionary:
 var data={"format":"forest_shrine_map","schema":1,"title":"Direct gate fixture","buildings":[{"kind":"gate","x":0,"z":7,"rotation":0}],"trees":[],"deposits":[],"portals":[{"x":0,"z":22,"rotation":0}],"roads":[]}
 # A valid but unnecessary road first heads east, then circles back to the door.
 for x in range(0,11):data.roads.append({"x":x,"z":21})
 for z in range(20,7,-1):data.roads.append({"x":10,"z":z})
 for x in range(9,-1,-1):data.roads.append({"x":x,"z":8})
 return data
func fresh(data:Dictionary):
 var model=Model.new();model.reset(42,{"bosses_per_portal":0,"waves":[[0,0,0,0]]},data);model.start_wave();model.workers.clear();model.hero_targetable=false;return model
func gate(model,rotation:int=0)->Dictionary:
 for b in model.buildings.values():
  if b.kind=="gate" and b.rotation==rotation:return b
 return {}
func run():
 for variant in Roles.COUNT:
  var m=fresh(layout());check(m.waves.routes.spawn(variant,[],0),"Role %d spawns at the authored portal"%variant)
  if m.enemies.is_empty():continue
  var e=m.enemies.values()[0];var start:Vector3=e.pos
  for frame in 180:m.waves.tick_enemy(e,1.0/60,Vector3.ZERO)
  check(e.pos.z<start.z-.1 and absf(e.pos.x-start.x)<3,"Role %d immediately approaches the door instead of the road detour (%s -> %s)"%[variant,str(start),str(e.pos)])
  check(e.target_kind=="building" and e.target_id==gate(m).id,"Role %d commits to the gate from its first approach"%variant)
 var m=fresh(layout())
 if not m.waves.routes.has_method("gate_target"):
  check(false,"Gate routing exposes accessible entry selection");finish();return
 for variant in Roles.COUNT:
  m=fresh(layout());var door=gate(m);var actor=m.waves.spawn_enemy(variant,Vector3(0,0,72));var safe=true
  for frame in 1800:
   m.waves.arrows.tick(m.waves.projectiles,.05,Vector3.ZERO)
   m.waves.tick_enemy(actor,.05,Vector3.ZERO)
   safe=safe and m.waves.navigation.fitted_blocker(actor,actor.pos)<0
   if door.hp<door.max_hp:break
  check(door.hp<door.max_hp,"Role %d reaches and damages the chosen door"%variant)
  check(safe,"Role %d never overlaps the gate collider during its approach"%variant)
  m.damage_building(door.id,100000)
  for frame in 1800:
   m.waves.tick_enemy(actor,.05,Vector3.ZERO)
   if actor.pos.z<39:break
  if variant in [0,1,3]:
   check(actor.pos.z<39,"Role %d passes through the breach and resumes interior combat (%s)"%[variant,str(actor.pos)])
  else:
   check(actor.pos.z>=39 and m.waves.navigation.fitted_blocker(actor,actor.pos)<0,"Oversized role %d remains physically blocked by the permanent frame (%s)"%[variant,str(actor.pos)])
  check(m.buildings.has(door.id) and door.hp==0 and door.get("breached",false),"Gate %d retains its masonry and breached state"%door.id)
 m=fresh(layout());m.hero_targetable=true
 var close=m.waves.spawn_enemy(0,Vector3(0,0,90));var hero=Vector3(6,0,90)
 m.waves.tick_enemy(close,.1,hero)
 check(close.target_kind=="hero","Nearby combat interrupts the gate approach")
 m.defenders[90001]={"id":90001,"pos":Vector3(90,0,90),"hp":1e9,"targetable":true,"taunting":true}
 m.waves.tick_enemy(close,.1,hero)
 check(close.target_kind=="defender" and close.target_id==90001,"A distant taunt retains priority over entry routing")
 var data=layout();data.buildings.append({"kind":"gate","x":0,"z":-7,"rotation":2});data.buildings.append({"kind":"gate","x":7,"z":0,"rotation":1});data.buildings.append({"kind":"gate","x":-7,"z":0,"rotation":3})
 m=fresh(data)
 for fixture in [{"point":Vector3(0,0,120),"rotation":0},{"point":Vector3(120,0,0),"rotation":1},{"point":Vector3(0,0,-120),"rotation":2},{"point":Vector3(-120,0,0),"rotation":3}]:
  for variant in Roles.COUNT:
   var e=m.waves.spawn_enemy(variant,fixture.point)
   check(m.waves.routes.gate_target(e)==gate(m,fixture.rotation).id,"Role %d selects its arrival-side gate %d"%[variant,fixture.rotation])
 var e=m.waves.spawn_enemy(0,Vector3(0,0,72));var south=gate(m)
 check(m.waves.routes.gate_target(e)==south.id,"An outside enemy first selects the nearby front door")
 m.damage_building(south.id,100000)
 check(m.waves.routes.gate_target(e)==south.id,"A breached front door remains the crossing target instead of diverting survivors")
 m.phase="preparing";m.gold=100000
 check(m.repair(south.id) and not south.get("breached",false),"Repair restores the same retained gate")
 m.phase="wave"
 check(m.waves.routes.gate_target(e)==south.id,"The restored gate is reconsidered by an enemy still outside")
 e.pos=Vector3(0,0,30)
 check(m.waves.routes.gate_target(e)==-1,"Enemies inside the fort resume normal combat instead of walking back to a gate")
 m=fresh({"buildings":[],"trees":[],"deposits":[]});e=m.waves.spawn_enemy(3,Vector3(0,0,90))
 var before:Vector3=e.pos
 for frame in 120:m.waves.tick_enemy(e,1.0/60,Vector3.ZERO)
 check(m.waves.routes.gate_target(e)==-1 and e.pos.z<before.z-1,"A map with no gate keeps normal combat navigation")
 # A solid row of trees separates a seemingly near gate from the arrival.
 data=layout();data.roads=[];data.buildings.append({"kind":"gate","x":20,"z":25,"rotation":1})
 for x in range(-40,40):data.trees.append({"x":x,"z":15,"scale":1.0})
 m=fresh(data);e=m.waves.spawn_enemy(0,Vector3(180,0,126))
 check(m.waves.routes.gate_target(e)==gate(m,1).id,"An unreachable near-side gate yields to a reachable exterior entrance")
 # Real raised terrain must still use its supported bridge and ramps.
 data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_four_gates.json"))
 for portal in [0,2,4,6]:
  m=fresh(data)
  for variant in Roles.COUNT:
   var origin=m.waves.routes.exit_point(m.portals[portal],variant);origin.y=m.surface_height(origin.x,origin.z)
   e=m.waves.spawn_enemy(variant,origin);var id:int=m.waves.routes.gate_target(e)
   check(id>=0,"Role %d has an accessible gate from raised portal %d"%[variant,portal])
   if id<0:continue
   var approach:Dictionary=m.waves.navigation.approach(e,m.buildings[id]);var supported=true;var previous:Vector3=e.pos
   for cell in approach.get("path",[]):
    var point:Vector3=m.point(cell)
    supported=supported and m.terrain.step_clear(previous,point)
    previous=point
   check(supported and not approach.is_empty(),"Role %d gate route preserves cliffs and bridge support at portal %d"%[variant,portal])
 print("DIRECT_GATE_ROUTE_SCOPE movement, arrival sides, gate revisions, no-gate fallback, terrain reachability")
 finish()
func finish():
 print("GATE_DIRECT_ROUTE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
