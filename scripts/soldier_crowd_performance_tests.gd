extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
class Routes extends "res://scripts/forest/forest_routes.gd":
 var road_queries=0
 func guidance(_point:Vector3,_variant:int=0)->Array:road_queries+=1;return [Vector2i(0,19)]
class GateHints extends RefCounted:
 var blocked_gate=-1
 var refreshes=0
 var queries=0
 func refresh():refreshes+=1
 func gate_exterior(_e:Dictionary,_b:Dictionary)->bool:return true
 func horizontal_path_lower_bound(_a:Vector3,_b:Vector3)->float:return 0
 func gate_approach(e:Dictionary,b:Dictionary)->Dictionary:
  queries+=1
  if e.pos.z>0 or (e.pos.x>0 and int(b.id)==blocked_gate):return {}
  return {"cost":float(b.id),"path":[Vector2i.ZERO]}
class Terrain extends "res://scripts/forest/forest_ramparts.gd":
 var disks=0
 func disk_clear(_point:Vector3,_radius:float)->bool:disks+=1;return true
 func cliff_cell(_cell:Vector2i)->bool:return false
class DividedTerrain extends Terrain:
 func cliff_cell(cell:Vector2i)->bool:return cell.y==10
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var m=Model.new();m.reset(41,{}, {"trees":[],"deposits":[],"buildings":[]});var ground=Terrain.new();m.terrain=ground
 var nav=m.waves.navigation;var a=nav.clearance_grid(0);var queries=ground.disks
 check(queries==6400,"One complete clearance mask is built for the enlarged footprint")
 check(is_same(a,nav.clearance_grid(1)) and is_same(a,nav.clearance_grid(3)),"All three equal soldier footprints share one navigation mask")
 check(ground.disks==queries,"New soldier types do not repeat6400native terrain checks")
 m.occupancy[Vector2i(15,15)]=1;m.navigation_revision+=1
 var b=nav.clearance_grid(0)
 check(is_same(a,b) and ground.disks==queries,"Adding a wall updates weights without rebuilding native terrain clearance")
 check(is_equal_approx(b.get_point_weight_scale(Vector2i(15,15)),12.0),"New wall occupancy receives its normal breach route cost")
 m.occupancy.erase(Vector2i(15,15));m.navigation_revision+=1;var c=nav.clearance_grid(0)
 check(is_same(a,c) and ground.disks==queries and is_equal_approx(c.get_point_weight_scale(Vector2i(15,15)),1.0),"Breaching a wall clears its cost without another mask rebuild")
 m.trees[Vector2i(20,20)]=1.;m.navigation_revision+=1;var d=nav.clearance_grid(0)
 check(not is_same(a,d) and ground.disks>queries,"Changed native tree geometry invalidates clearance masks")
 check(d.is_point_solid(Vector2i(20,20)),"Changed tree trunks remain physically blocked at the new size")
 var gate=m._make_building("gate",Vector2i(0,6),0);m.rebuild_navigation()
 var actor=m.waves.spawn_enemy(0,Vector3(0,0,90));var first=nav.gate_approach(actor,gate)
 check(not first.is_empty(),"Large soldiers have a supported gate approach fixture")
 var initial_size=first.path.size();var initial_cost:float=first.cost;queries=ground.disks
 first.path.pop_front();actor.variant=1;var same=nav.gate_approach(actor,gate)
 check(ground.disks==queries and same.path.size()==initial_size,"Equal footprints reuse a gate route while each actor owns an independent path")
 actor.pos.x+=1.1;queries=ground.disks;var offset=nav.gate_approach(actor,gate)
 check(not offset.is_empty() and ground.disks-queries<20 and ground.disks>queries,"Offcenter cache hits validate the real root to the first supported waypoint")
 check(absf(float(offset.cost)-initial_cost-1.1)<.001,"Shared routes retain the actual first-leg cost when comparing gates")
 queries=ground.disks;m.navigation_revision+=1;nav.gate_approach(actor,gate)
 check(ground.disks>queries+20,"Changed geometry invalidates a shared gate route certificate")
 var spawn=Model.new();spawn.reset(41,{}, {"trees":[],"deposits":[],"buildings":[],"portals":[{"x":0,"z":20,"rotation":0}]})
 var routes=Routes.new(spawn);spawn.waves.routes=routes
 check(routes.spawn(0,[],0),"An ordinary portal arrival still spawns with valid native support")
 check(routes.road_queries==0 and spawn.enemies.values()[0].get("road_path",[]).is_empty(),"Direct gate arrivals do not compute unused road network searches")
 var hints=Model.new();hints.reset(41,{}, {"trees":[],"deposits":[],"buildings":[]});hints.waves.navigation=GateHints.new()
 var left_gate=hints._make_building("gate",Vector2i(0,6),0);var right_gate=hints._make_building("gate",Vector2i(6,0),1)
 hints.waves.navigation.blocked_gate=left_gate.id
 var first_root=hints.waves.spawn_enemy(0,Vector3(-1,0,0));var second_root=hints.waves.spawn_enemy(1,Vector3(1,0,0))
 check(hints.waves.routes.gate_target(first_root)==left_gate.id and hints.waves.routes.gate_target(second_root)==right_gate.id,"Shared gate hints revalidate reachability for another offset root in the same cell")
 hints.waves.routes.gate_cache.clear();first_root.erase("entry_gate");second_root.erase("entry_gate");first_root.pos=Vector3(-1,0,1);second_root.pos=Vector3(-1,0,-1)
 check(hints.waves.routes.gate_target(first_root)==-1 and hints.waves.routes.gate_target(second_root)==left_gate.id,"An unreachable offset root cannot poison another root in the same navigation cell")
 var attempts=hints.waves.navigation.queries;first_root.entry_gate_retry=0
 check(hints.waves.routes.gate_target(first_root)==-1 and hints.waves.navigation.queries==attempts,"A stationary actor retains its exact-root negative result even when another actor replaces the shared cell hint")
 first_root.entry_gate_retry=.75;first_root.pos.z=1.2
 check(hints.waves.routes.gate_target(first_root)==-1 and hints.waves.navigation.queries==attempts,"A moving unreachable actor retries gate searches on a short budget rather than each crowd tick")
 first_root.entry_gate_retry=0;first_root.pos.z=-1.0
 check(hints.waves.routes.gate_target(first_root)==left_gate.id,"An actor retries an earlier gate miss after its budget expires")
 first_root.pos.z=1;first_root.erase("entry_gate");hints.navigation_revision+=1;hints.waves.routes.gate_target(first_root);first_root.pos.z=-1;hints.navigation_revision+=1
 check(hints.waves.routes.gate_target(first_root)==left_gate.id,"Navigation changes invalidate a negative actor gate budget immediately")
 hints.workers.clear();hints.wave=2;hints.phase="preparing";hints.tick(.01,Vector3.ZERO)
 check(hints.waves.navigation.refreshes==0,"Soldiers-only preparation does not rebuild an unused giant clearance grid")
 var divided=Model.new();divided.reset(41,{}, {"trees":[],"deposits":[],"buildings":[]});var barrier=DividedTerrain.new();divided.terrain=barrier
 divided._make_building("gate",Vector2i(0,6),0);divided.rebuild_navigation()
 var across_a=divided.waves.spawn_enemy(0,Vector3(-1,0,90));var across_b=divided.waves.spawn_enemy(1,Vector3(1,0,90))
 check(divided.waves.routes.gate_target(across_a)==-1,"An open cell beyond a solid terrain barrier has no reachable exterior gate")
 queries=barrier.disks
 check(divided.waves.routes.gate_target(across_b)==-1 and barrier.disks==queries,"A certified unreachable cell shares its static failure without rescanning complete gate corridors")
 var new_gate=divided._make_building("gate",Vector2i(0,12),0);divided.rebuild_navigation()
 check(divided.waves.routes.gate_target(across_b)==new_gate.id,"A new reachable gate immediately invalidates a shared static failure certificate")
 print("SOLDIER_CROWD_PERFORMANCE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
