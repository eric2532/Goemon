extends SceneTree
class CountedTarget extends "res://scripts/forest/crowd/army_enemy_target.gd":
 var bounds_calls=0
 var contact_calls=0
 func combat_contact_point(from:Vector3)->Vector3:
  contact_calls+=1
  return super.combat_contact_point(from)
 func combat_bounds()->AABB:
  bounds_calls+=1
  return super.combat_bounds()
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture)
 var game=await fixture.make_game("original");fixture.clear_targets()
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();game.add_child(runtime);runtime.configure(game);game.army_runtime=runtime;game.model.army_runtime=runtime
 var targets=[]
 for i in 2000:
  var point=Vector3((i-1)*4,0,60) if i<3 else Vector3(80+(i%30)*3,0,80+int(i/30)*3)
  var row=game.model.waves.spawn_enemy([0,1,3][i%3],point);row.hp=10000;row.max_hp=10000
  var h=runtime.spawn(row.id,0,row.variant,point,10000,3.9)
  var actor=CountedTarget.new();actor.runtime=runtime;actor.game=game;actor.handle=h;actor.forest_id=row.id;actor.variant=row.variant
  game.add_child(actor);actor.sync(runtime.unit_state(h));runtime.enemies[row.id]=actor;runtime.register_actor_facade(actor,row)
  game.actors[row.id]=actor;game.enemies.append(actor);targets.append(actor);game.model.visible_cells[game.model.cell_of(point)]=true
 var combat=game.player.active_ability
 var points=[Vector3(0,1,60),Vector3(5,8,60),Vector3(150,1,150),Vector3(0,-5,60)]
 for center in points:
  game.army_runtime=null
  var expected=combat.living(center,4).map(func(t):return t.uid)
  game.army_runtime=runtime
  for target in targets:target.bounds_calls=0
  var actual=combat.living(center,4).map(func(t):return t.uid)
  check(actual==expected,"Bounded player contacts retain exact victims and source order")
  var visited=0
  for target in targets:visited+=target.bounds_calls
  check(visited<100,"A local attack does not prepare all2000 enemy hulls")
 game.army_runtime=null
 var nearby_expected=combat._nearby_targets(Vector3(0,1,60),5).map(func(t):return t.uid)
 game.army_runtime=runtime
 for target in targets:target.contact_calls=0
 check(combat._nearby_targets(Vector3(0,1,60),5).map(func(t):return t.uid)==nearby_expected,"Area effects retain exact nearby victims and ordering")
 var contacts=0
 for target in targets:contacts+=target.contact_calls
 check(contacts<100,"Area effects do not refine distant enemy contacts")
 # Reordered source lists and a rotated edge contact preserve hit ordering/reach.
 game.enemies.reverse();runtime.set_pose(targets[0].handle,Vector3(7,0,60),PI/4);runtime.sync_targets()
 game.army_runtime=null;var expected=combat.living(Vector3(0,1,60),4).map(func(t):return t.uid)
 game.army_runtime=runtime
 check(combat.living(Vector3(0,1,60),4).map(func(t):return t.uid)==expected,"Rotated hull edges and reordered enemy lists are retained")
 targets[1].dead=true;targets[1].hp=0
 check(not combat.living(Vector3(0,1,60),4).any(func(t):return t.node==targets[1]),"Dead targets are excluded immediately")
 game.army_runtime=null;expected=combat.living().map(func(t):return t.uid);game.army_runtime=runtime
 check(expected.size()>1900 and combat.living().map(func(t):return t.uid)==expected,"Unbounded abilities retain their complete visible population")
 var extra=fixture.add_target(Vector3(0,0,61));game.model.visible_cells[game.model.cell_of(extra.position)]=true
 game.army_runtime=null;expected=combat.living(Vector3(0,1,60),4).map(func(t):return t.uid);game.army_runtime=runtime
 check(expected.has(extra.get_instance_id()) and combat.living(Vector3(0,1,60),4).map(func(t):return t.uid)==expected,"Additional legacy/custom targets safely retain the original scan")
 game.model.visible_cells.clear()
 check(combat.living(Vector3(0,1,60),4).is_empty(),"Fog visibility remains authoritative")
 game.army_runtime=null;game.model.army_runtime=null;runtime.clear();runtime.queue_free();await fixture.close();fixture.queue_free();await process_frame
 print("ARMY_BOUNDED_COMBAT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
