extends SceneTree
## Source-form and existing-owner integration; no screenshots or walkthrough.
const Buildings=preload("res://scripts/forest/forest_venoa_buildings.gd")
const Coastal=preload("res://scripts/forest/forest_coastal_buildings.gd")
const Kili=preload("res://scripts/forest/forest_kili_art.gd")
const Frontier=preload("res://scripts/forest/forest_falan_frontier.gd")

class Terrain extends RefCounted:
 var variant="building_fixture"
 func disk_clear(_p:Vector3,_radius:float)->bool:return true

class Model extends RefCounted:
 var falan_area="building_fixture"
 var terrain=Terrain.new()
 var falan_frontier_plan=[]
 func surface_height(_x:float,_z:float)->float:return 6.0

func _initialize():
 create_timer(120).timeout.connect(func():printerr("EXPLORE_VENOA_BUILDINGS_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 for serial in Buildings.Data.FORMS:
  print("PREPARE_VENOA_BUILDING ",serial)
  var mesh:Mesh=Buildings.prepare(serial)
  assert(mesh==Buildings.prepare(serial),"Repeated native buildings share a prepared mesh")
  assert(mesh==Coastal.shape(serial),"The existing coastal owner routes to the native form")
  var bounds=mesh.get_aabb()
  print("VENOA_BUILDING_METRIC serial=",serial," triangles=",mesh.get_faces().size()/3," surfaces=",mesh.get_surface_count()," bounds=",bounds)
  assert(bounds.position.y>=-.4 and bounds.size.y>3,"Native buildings retain solid height with tucked chimney bases")
  for surface in mesh.get_surface_count():
   var arrays=mesh.surface_get_arrays(surface)
   for p in arrays[Mesh.ARRAY_VERTEX]:assert(p.is_finite(),"Source-form vertices are finite")
   for normal in arrays[Mesh.ARRAY_NORMAL]:assert(normal.is_finite() and normal.length_squared()>.5,"Source-form normals are usable")
  var origin:Vector2=mesh.get_meta("native_origin")
  var points:Array=mesh.get_meta("native_roof_points")
  var pixels:Array=mesh.get_meta("native_roof_profile")
  for i in points.size():
   var p:Vector3=points[i]
   var pixel=origin+Vector2((p.x+p.z)*(32.0/3.0),(p.z-p.x)*8.0-p.y*Buildings.Proportions.VERTICAL)
   assert(pixel.distance_to(Vector2(pixels[i][0],pixels[i][1]))<.002,"The visible gable keeps its native source stations")
  var row:Dictionary=Buildings.Data.FORMS[serial]
  var p:Vector3=points[row.peak]+mesh.get_meta("native_roof_rear")
  var pixel=origin+Vector2((p.x+p.z)*(32.0/3.0),(p.z-p.x)*8.0-p.y*Buildings.Proportions.VERTICAL)
  assert(pixel.distance_to(Vector2(row.rear[0],row.rear[1]))<.002,"The rear ridge keeps its source station")
 var scene=Node3D.new();root.add_child(scene)
 var model=Model.new()
 model.falan_frontier_plan=Frontier.scenery_plan(model,Kili.SOURCE.BUILDINGS.venoa)
 var before=var_to_str(model.falan_frontier_plan)
 Frontier.outer_art(scene,model)
 assert(var_to_str(model.falan_frontier_plan)==before,"Building art cannot rewrite source/collision plans")
 var nodes=scene.find_children("BlueCGVillageBuilding_*","MeshInstance3D",true,false)
 assert(nodes.size()==7,"All seven original Venoa building placements remain")
 var shapes=scene.find_children("*","CollisionShape3D",true,false)
 assert(shapes.size()==7,"Only the existing seven building physics shapes remain")
 for row in model.falan_frontier_plan:
  var box:AABB=row[2]
  assert(shapes.any(func(n):return n.global_position.is_equal_approx(box.get_center()) and n.shape.size.is_equal_approx(box.size)),"Each physical building keeps its original box")
 print("EXPLORE_VENOA_BUILDINGS_PASS variants=6 placements=7 preserved_shapes=7")
 scene.queue_free();await process_frame;quit()
