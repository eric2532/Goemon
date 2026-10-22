extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
class Runtime extends "res://scripts/forest/crowd/army_runtime.gd":
 var queries=0
 var reads=0
 func query_aabb(bounds:AABB,team:int)->PackedInt64Array:
  queries+=1;return super.query_aabb(bounds,team)
 func unit_state(handle:int)->Dictionary:
  reads+=1;return super.unit_state(handle)
const Profile=preload("res://scripts/forest/forest_structure_profile.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func exhaustive(model,worker)->int:
 var best=-1;var nearest=48.0*48.0
 for enemy in model.enemies.values():
  if enemy.hp<=0:continue
  var offset:Vector3=enemy.pos-worker.pos
  var muzzle:Vector3=worker.pos+Vector3.UP*Profile.TOWER_DECK_HEIGHT+Basis(Vector3.UP,atan2(offset.x,offset.z))*Profile.TOWER_MUZZLE_OFFSET
  var hurt=Roles.hurt_point(enemy,muzzle)
  var distance=worker.pos.distance_squared_to(hurt)
  if distance<nearest and (model.visible_at(enemy.pos) or model.visible_at(hurt)):best=enemy.id;nearest=distance
 return best
func verify_shot(model,worker,label_:String):
 var expected=exhaustive(model,worker)
 model.workforce.arrows.clear();worker.timer=0
 model.workforce.tick(0,Vector3.ZERO)
 var arrows=model.workforce.arrows.values()
 check((arrows[0].target if not arrows.is_empty() else -1)==expected,label_)
func run():
 var model=Model.new();model.reset(42,{}, {"buildings":[],"trees":[],"deposits":[]},false);model.phase="wave"
 var army=Runtime.new();army.configure(null);model.army_runtime=army
 var tower=model._make_building("tower",Vector2i(0,8),0)
 var worker={"id":3000,"pos":Vector3(0,0,60),"hp":100,"state":"garrison","job":tower.id,"timer":0.0}
 model.workers={3000:worker};model.workforce.assignment_clock=1000
 var rng=RandomNumberGenerator.new();rng.seed=102121
 for fixture in 160:
  army.clear();model.enemies.clear();model.visible_cells.clear()
  worker.pos.y=rng.randf_range(-20,65)
  for i in 20:
   var kind=[0,1,3,2,4][i%5]
   var angle=rng.randf_range(-PI,PI);var distance=rng.randf_range(38,90)
   var position:Vector3=worker.pos+Vector3(cos(angle)*distance,rng.randf_range(-60,60),sin(angle)*distance)
   var row=model.waves.spawn_enemy(kind,position);row.facing=rng.randf_range(-PI,PI);row.walk_phase=rng.randf()*TAU
   if i%4!=0:
    var handle=army.spawn(row.id,0,kind,row.pos,row.hp,Roles.footprint_radius(kind));army.set_pose(handle,row.pos,row.facing)
   if i%7==0:row.hp=0
   if i%3!=0:model.visible_cells[model.cell_of(row.pos)]=true
  verify_shot(model,worker,"Indexed targeting matches exhaustive original contacts, including pending spawns, heights, giants and hidden/dead rows")
 # Native slot reuse and logical-ID sorting must not change model insertion ties.
 army.clear();model.enemies.clear();model.visible_cells.clear();worker.pos=Vector3(0,0,60)
 var first=model.waves.spawn_enemy(0,Vector3(0,0,85));var second=model.waves.spawn_enemy(0,first.pos)
 for row in [second,first]:army.spawn(row.id,0,0,row.pos,row.hp,3.9)
 model.enemies.erase(first.id);model.enemies[first.id]=first
 model.visible_cells[model.cell_of(first.pos)]=true
 verify_shot(model,worker,"Equal distances preserve original model insertion order despite native handle order")
 army.despawn(army.handles[second.id]);model.enemies.erase(second.id)
 verify_shot(model,worker,"Despawned candidate disappears immediately")
 model.army_runtime=null
 verify_shot(model,worker,"Legacy backend retains the same exhaustive targeting")
 army.clear();model.enemies.clear();model.army_runtime=army
 for i in 2000:
  var row=model.waves.spawn_enemy(0,Vector3(0,0,85) if i==0 else Vector3(100+i%30,0,60+i/30))
  army.spawn(row.id,0,0,row.pos,row.hp,3.9)
 army.queries=0;army.reads=0
 verify_shot(model,worker,"A 2000-soldier army preserves the exact reachable shot")
 check(army.queries>0 and army.reads==0,"Distant armies use the shared index without allocating individual native state dictionaries")
 army.clear();army.free()
 print("ARMY_TOWER_TARGETS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
