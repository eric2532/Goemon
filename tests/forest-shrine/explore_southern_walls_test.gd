extends SceneTree
## Headless geometry/preservation checks; no walkthrough or captures.
const Walls=preload("res://scripts/forest/forest_venoa_walls.gd")
const Kili=preload("res://scripts/forest/forest_kili_art.gd")

class WallModel extends RefCounted:
 var falan_area="wall_fixture"
 var terrain={"variant":"wall_fixture"}
 var falan_frontier_plan=[]
 func surface_height(_x:float,_z:float)->float:return 6.0

func _initialize():
 create_timer(120).timeout.connect(func():printerr("EXPLORE_SOUTHERN_WALLS_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 assert(load("res://scripts/forest/forest_falan_frontier.gd").can_instantiate(),"The existing outdoor owner still compiles")
 for path in ["connected_villages_test.gd","il_habaru_restoration_test.gd","village_building_wrap_test.gd","habaru_wayfinding_test.gd"]:
  assert(load("res://tests/forest-shrine/"+path).can_instantiate(),"Village fixtures accept the compound guild facade")
 var scene=Node3D.new();root.add_child(scene)
 var groups={}
 for serial in Walls.Data.FORMS:
  var before=Kili.wall_size(serial)
  var mesh:Mesh=Walls.prepare(serial)
  assert(mesh==Walls.prepare(serial),"Repeated walls share their prepared mesh")
  assert(mesh.get_meta("original_graphic")==serial,"Each weathered wall retains its original graphic")
  assert(mesh.get_aabb().position.y>=-.001 and mesh.get_aabb().size.y>1,"Walls stand above their source ground")
  var arrays=mesh.surface_get_arrays(0)
  for p in arrays[Mesh.ARRAY_VERTEX]:assert(p.is_finite(),"Native wall vertices remain finite")
  for normal in arrays[Mesh.ARRAY_NORMAL]:assert(normal.is_finite() and normal.length_squared()>.5,"Native wall normals remain usable")
  assert(Kili.wall_size(serial)==before,"Visual preparation cannot mutate collision extents")
  groups[serial]=[Transform3D(Basis.IDENTITY,Vector3(3,0,3)),Transform3D(Basis.IDENTITY,Vector3(60,0,3))]
 Walls.batch(scene,groups)
 assert(scene.find_children("*","MultiMeshInstance3D",true,false).size()==28,"Repeated native walls are split into local spatial batches")
 assert(scene.find_children("*","CollisionObject3D",true,false).is_empty(),"The visual wall owner adds no physics")
 assert(Walls.Data.FORMS[11261][2].size()==2,"The native corner retains both wall arms")
 var model=WallModel.new()
 for row in Kili.SOURCE.SCENERY.venoa:
  if not Walls.Data.FORMS.has(row[1]):continue
  model.falan_frontier_plan.append(Kili.wall_plan(model,Vector2(row[0])*3.0,row[1]))
 var original_plan=var_to_str(model.falan_frontier_plan)
 load("res://scripts/forest/forest_falan_frontier.gd").outer_art(scene,model)
 assert(var_to_str(model.falan_frontier_plan)==original_plan,"The outdoor visual pass preserves the source plans")
 var bodies=scene.find_children("*","CollisionShape3D",true,false)
 assert(bodies.size()==164,"All existing Venoa wall collision shapes remain under the outdoor owner")
 for row in model.falan_frontier_plan:
  var box:AABB=row[2]
  assert(bodies.any(func(n):return n.global_position.is_equal_approx(box.get_center()) and n.shape.size.is_equal_approx(box.size)),"Native wall visuals retain each old physical wall")
 var count=0
 for node in scene.find_children("NativeVenoaWall_*","MultiMeshInstance3D",true,false):count+=node.multimesh.instance_count
 assert(count==164+28,"All 164 source placements reach the native batch owner")
 print("EXPLORE_SOUTHERN_WALLS_PASS variants=14 isolated_batches=28 placements=164 preserved_wall_shapes=164")
 scene.queue_free();await process_frame;quit()
