extends SceneTree
func _initialize():
 call_deferred("verify")
func verify():
 var scene = load("res://showcase.tscn").instantiate()
 root.add_child(scene)
 await physics_frame
 await physics_frame
 var report := {"assets": [], "doorways": [], "showcase_loaded": true}
 var assembled = load("res://showcase.glb").instantiate()
 assert(assembled.find_children("*", "MeshInstance3D", true, false).size() == 23, "assembled GLB")
 assembled.free()
 var data = JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))
 for a in data:
  var asset = scene.asset_roots[a.id]
  var meshes = asset.find_children("*", "MeshInstance3D", true, false)
  assert(meshes.size() == 1, a.id)
  assert(meshes[0].material_override == load("res://shared_matte.tres"), a.id)
  var mesh = meshes[0].mesh
  assert(mesh.get_surface_count() == 1, a.id)
  var arrays = mesh.surface_get_arrays(0)
  var triangle_count = arrays[Mesh.ARRAY_INDEX].size() / 3
  assert(triangle_count == a.triangles, a.id)
  var size = mesh.get_aabb().size
  var expected = Vector3(a.dimensions_xyz_blender_m[0],a.dimensions_xyz_blender_m[2],a.dimensions_xyz_blender_m[1])
  assert((size-expected).length() < 0.03, a.id + " dimensions differ")
  report.assets.append({"id":a.id,"triangles":triangle_count,"surfaces":1,"dimensions_match":true})
 var space = scene.get_world_3d().direct_space_state
 for id in ["machiya_open","tea_house_open","gatehouse"]:
  var p = scene.asset_roots[id].position
  var ray = PhysicsRayQueryParameters3D.create(p+Vector3(0,1.5,6),p+Vector3(0,1.5,1))
  var hit = space.intersect_ray(ray)
  assert(hit.is_empty(), id + " doorway blocked")
  var floor_ray = PhysicsRayQueryParameters3D.create(p+Vector3(0,1.5,1),p+Vector3(0,-1,1))
  assert(not space.intersect_ray(floor_ray).is_empty(), id + " missing floor")
  # Test a 0.6m-wide, 1.8m-tall player capsule at intervals through the entry.
  var capsule = CapsuleShape3D.new()
  capsule.radius = .3
  capsule.height = 1.8
  for step in range(9):
   var query = PhysicsShapeQueryParameters3D.new()
   query.shape = capsule
   query.transform = Transform3D(Basis.IDENTITY,p+Vector3(0,1.31,4.5-step*.4))
   assert(space.intersect_shape(query).is_empty(), id + " capsule clearance")
  report.doorways.append({"id":id,"ray_clear":true,"floor_present":true,"capsule_0_6_by_1_8_clear":true})
 var p = scene.asset_roots["warehouse"].position
 assert(not space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3(0,1.5,6),p+Vector3(0,1.5,1))).is_empty(), "closed warehouse must block")
 var f = FileAccess.open("res://verification/godot.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(report,"  "))
 print("PASS: 22 GLB imports, dimensions, triangle counts, shared surfaces; showcase; 3 clear passages and floors")
 quit(0)
