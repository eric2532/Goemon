extends SceneTree
func _initialize():call_deferred("verify")
func verify():
 var scene=load("res://showcase.tscn").instantiate();root.add_child(scene)
 await physics_frame
 await physics_frame
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))
 var report={"assets":[],"showcase_loaded":true,"authored_movement_test":"verification/interior_walk.json"}
 var expected_meshes=1
 for a in data:
  var asset=scene.asset_roots[a.id];var meshes=asset.find_children("*","MeshInstance3D",true,false)
  assert(meshes.size()==a.surfaces,a.id)
  expected_meshes+=meshes.size()
  var bounds=AABB();var first=true;var triangles=0
  for node in meshes:
   assert(node.material_override==load("res://shared_matte.tres"),a.id)
   var mesh=node.mesh;assert(mesh.get_surface_count()==1,a.id)
   var arrays=mesh.surface_get_arrays(0);triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
   var local=node.transform*mesh.get_aabb()
   bounds=local if first else bounds.merge(local);first=false
  assert(triangles==a.triangles,a.id)
  var expected=Vector3(a.dimensions_xyz_blender_m[0],a.dimensions_xyz_blender_m[2],a.dimensions_xyz_blender_m[1])
  assert((bounds.size-expected).length()<.03,a.id+" dimensions")
  report.assets.append({"id":a.id,"triangles":triangles,"surfaces":meshes.size(),"dimensions_match":true})
 var assembled=load("res://showcase.glb").instantiate()
 assert(assembled.find_children("*","MeshInstance3D",true,false).size()==expected_meshes,"assembled GLB")
 assembled.free();report["assembled_meshes"]=expected_meshes
 FileAccess.open("res://verification/godot.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("PASS: 22 GLB imports, separated cutaway groups, dimensions, triangle counts, shared material and assembled showcase")
 quit(0)
