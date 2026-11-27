extends SceneTree
## Native reused art and old-physics integration only; no traversal or screenshots.
const Frontier=preload("res://scripts/forest/forest_falan_frontier.gd")
const Kili=preload("res://scripts/forest/forest_kili_art.gd")
const Data=preload("res://assets/maps/falan/ghana_fronts.gd")
const Details=preload("res://scripts/forest/forest_ghana_details.gd")

class Terrain extends RefCounted:
 var variant="front_fixture"
 func disk_clear(_p:Vector3,_radius:float)->bool:return true

class Model extends RefCounted:
 var falan_area="ghana"
 var terrain=Terrain.new()
 var falan_frontier_plan=[]
 func surface_height(_x:float,_z:float)->float:return 6.0

func _initialize():
 create_timer(120).timeout.connect(func():printerr("EXPLORE_GHANA_FRONTS_TIMEOUT");quit(1))
 run.call_deferred()

func run():
 var model=Model.new()
 var props=Frontier.Regions.Sites.PROPS.ghana.filter(func(row):return Kili.SHELLS.has(row[0]) or row[0] in ["wall_piece","ghana_well","fence"])
 model.falan_frontier_plan=Frontier.scenery_plan(model,props)
 var original=var_to_str(model.falan_frontier_plan)
 var scene=Node3D.new();root.add_child(scene)
 Frontier.outer_art(scene,model)
 assert(var_to_str(model.falan_frontier_plan)==original,"Native Ghana visuals do not change plans or physical extents")
 var nodes=scene.find_children("BlueCGVillageBuilding_*","MeshInstance3D",true,false)
 assert(nodes.size()==8,"Ghana retains all eight native building pieces")
 for row in Data.BUILDINGS:
  var node=nodes.filter(func(n):return n.get_meta("source_graphic",0)==row[1])[0]
  assert(node.position.is_equal_approx(Vector3(row[0].x,6,row[0].y)),"Every native building retains its archived anchor")
  assert(node.mesh==Kili.Buildings.meshes[[Kili.Buildings.Atlas,row[1]]],"Ghana shares the complete matching Kili mesh")
 var walls=scene.find_children("NativeGhanaWall_*","MultiMeshInstance3D",true,false)
 var count=0
 for node in walls:
  count+=node.multimesh.instance_count
  assert(node.multimesh.mesh==Kili.prepare_wall(node.get_meta("source_graphic")),"Native walls reuse the existing prepared kit")
 assert(count==Data.WALLS.size() and count==46,"All 46 old wall placements use their original graphics")
 var shapes=scene.find_children("*","CollisionShape3D",true,false)
 assert(shapes.size()==props.size() and shapes.size()==126,"The six building, well, 73 fence and 46 wall physics shapes remain")
 for row in model.falan_frontier_plan:
  var box:AABB=row[2]
  assert(shapes.any(func(n):return n.global_position.is_equal_approx(box.get_center()) and n.shape.size.is_equal_approx(box.size)),"Every Ghana physical shape retains its old bounds")
 assert(Kili.wall_size(11236)==Vector3(.6,3.25,3),"The corrected painted facing leaves old collision dimensions intact")
 assert(Kili.prepare_wall(11236).get_aabb().size.x>Kili.prepare_wall(11236).get_aabb().size.z,"Native 11236 has its proper visible wall axis")
 assert(Kili.prepare_wall(11237)!=Kili.prepare_wall(11238),"Opposite column returns keep distinct native forms")
 for serial in Kili.WallBounds.RECTS:
  var mesh:Mesh=Kili.prepare_wall(serial)
  var bounds=Details.Fit.projected_bounds(Details.Fit.mesh_points(mesh),Transform3D(Basis(Vector3.UP,PI*.5),Vector3.ZERO))
  var target:Rect2=Kili.WallBounds.RECTS[serial]
  assert(bounds.position.distance_to(target.position)<.01 and bounds.size.distance_to(target.size)<.01,"Wall and column proportions retain their native projected source bounds")
 var well=scene.find_child("NativeGhanaWell_11229",true,false)
 assert(well.position.is_equal_approx(Vector3(10.5,6,13.5)),"The well keeps the original two-tile graphic centre")
 assert(well.mesh==Details.mesh() and well.mesh.get_surface_count()==1,"The complete native well shares one prepared surface")
 assert(well.mesh.get_aabb().size.y>6 and well.mesh.get_aabb().size.y<7,"The open well retains its native post height")
 for surface in well.mesh.get_surface_count():
  for p in well.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:assert(p.is_finite(),"Native well vertices remain finite")
 var fence_count=0
 for node in scene.find_children("NativeGhanaFence_*","MultiMeshInstance3D",true,false):
  fence_count+=node.multimesh.instance_count
  assert(node.multimesh.mesh==Details.fence_mesh(node.get_meta("source_graphic")),"Repeated fence forms reuse their complete mesh")
 assert(fence_count==73,"All original Ghana fence anchors reach the native shared kit")
 for serial in Data.FENCE_POST_PIXELS:
  assert(is_equal_approx(Details.fence_mesh(serial).get_aabb().size.y,Data.FENCE_POST_PIXELS[serial]/Details.Fit.VERTICAL),"Fence posts use the native camera height")
 print("EXPLORE_GHANA_FRONTS_PASS building_pieces=8 wall_pieces=46 native_well=1 fences=73 preserved_shapes=126")
 scene.queue_free();await process_frame;quit()
