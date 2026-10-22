extends SceneTree
## Native body regression: reject skinned/retargeted geometry, altered source
## matrices, accumulated transforms, and accidental changes to accepted sizes.
const MOTION_PATH="res://assets/characters/recovered_goemon/motion.json"
const POINTERS=["0x9004f48","0x9005a28","0x90050f8","0x9005498","0x90055b8","0x9005748","0x9005868","0x90047f8","0x9004ac8","0x9004930","0x9004bb0","0x9004e48","0x9004cd0"]
const ACTIONS=[0,0x0F,0x18,0x19,0x1A,0x58,0x59,0x5A,0x68,0x69,0x6A,0x6B,0x6C,0x6D,0x82,0x83]
const ACCEPTED_HEIGHT=3.2206185
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1
 print("PASS: " if ok else "FAIL: ",label_)
func finish():
 print("RECOVERED_GOEMON_NATIVE_RESULT checks=%d failures=%d"%[checks,failures])
 quit(1 if failures else 0)
func roster_model_path(id:int)->String:
 var script:Variant=Hero.ROSTER[id].model
 return script.resource_path
func raw_transform(v:Array)->Transform3D:
 return Transform3D(Basis(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8])),Vector3(v[9],v[10],v[11]))
func close_matrix(a:Transform3D,b:Transform3D)->bool:
 return a.origin.distance_to(b.origin)<.00002 and a.basis.x.distance_to(b.basis.x)<.00002 and a.basis.y.distance_to(b.basis.y)<.00002 and a.basis.z.distance_to(b.basis.z)<.00002
func meshes_in(node:Node)->Array[MeshInstance3D]:
 var result:Array[MeshInstance3D]=[]
 if node is MeshInstance3D:result.append(node)
 for child in node.get_children():result.append_array(meshes_in(child))
 return result
func geometry_snapshot(node:Node)->Dictionary:
 var result={}
 for mesh in meshes_in(node):
  var surfaces=[]
  for surface in mesh.mesh.get_surface_count():
   var arrays=mesh.mesh.surface_get_arrays(surface)
   surfaces.append([hash(arrays[Mesh.ARRAY_VERTEX]),hash(arrays[Mesh.ARRAY_INDEX]),hash(arrays[Mesh.ARRAY_TEX_UV])])
  result[mesh.get_instance_id()]={"mesh":mesh.mesh,"surfaces":surfaces}
 return result
func native_bounds(model:Node3D)->AABB:
 var bounds=AABB();var first=true
 for pointer in model.native_parts:
  for mesh in meshes_in(model.native_parts[pointer]):
   if not mesh.is_visible_in_tree():continue
   var transform_=model.global_transform.affine_inverse()*mesh.global_transform
   for surface in mesh.mesh.get_surface_count():
    var vertices:PackedVector3Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
    for vertex in vertices:
     var point:Vector3=transform_*vertex
     bounds=AABB(point,Vector3.ZERO) if first else bounds.expand(point);first=false
 return bounds
func run():
 var model=load("res://scripts/recovered_goemon_model.gd").new();root.add_child(model)
 await process_frame
 var has_native=typeof(model.get("native_parts"))==TYPE_DICTIONARY and model.has_method("apply_native_pose")
 check(has_native,"Goemon renders source rigid parts instead of retargeting the Kai skin")
 if not has_native:
  model.queue_free();await process_frame;finish();return
 model.set_process(false)
 check(model.native_parts.size()==13 and POINTERS.all(func(p):return model.native_parts.has(p)),"All thirteen original body display lists are present")
 var archive:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MOTION_PATH))
 var meshes=meshes_in(model)
 var unskinned=true;var original_meshes=true;var native_geometry=true
 for mesh in meshes:
  if mesh.mesh==null:continue
  unskinned=unskinned and mesh.skin==null
  original_meshes=original_meshes and not mesh.mesh.resource_path.contains("kai")
  for surface in mesh.mesh.get_surface_count():
   var arrays=mesh.mesh.surface_get_arrays(surface)
   unskinned=unskinned and (arrays[Mesh.ARRAY_BONES]==null or arrays[Mesh.ARRAY_BONES].is_empty()) and (arrays[Mesh.ARRAY_WEIGHTS]==null or arrays[Mesh.ARRAY_WEIGHTS].is_empty())
 for pointer in POINTERS:
  native_geometry=native_geometry and model.native_parts.has(pointer) and not meshes_in(model.native_parts[pointer]).is_empty()
 check(unskinned and original_meshes,"Goemon contains no Kai mesh, skin bindings, or vertex bone weights")
 check(native_geometry,"Every source body part contains rendered rigid geometry")
 var before=geometry_snapshot(model)
 var matrices_ok=true;var finite_ok=true;var samples=0
 for action in ACTIONS:
  var clip:Dictionary=archive.clips[archive.actions[str(action)]]
  var rate:float=maxf(.01,float(archive.rates.get(str(action),1.0)))
  for frame in range(int(clip.frame_count)):
   model.apply_native_pose(action,float(frame)/(30.0*rate))
   for pointer in POINTERS:
    var part:Node3D=model.native_parts[pointer]
    var index:int=clip.pointers.find(pointer)
    if index<0:
     matrices_ok=false;continue
    var raw=raw_transform(clip.frames[frame][index])
    var expected=Transform3D(raw.basis.scaled(Vector3.ONE*model.source_scale),raw.origin*model.source_scale+model.source_offset)
    var actual:Transform3D=model.rig_visual.global_transform.affine_inverse()*part.global_transform
    matrices_ok=matrices_ok and close_matrix(actual,expected)
    finite_ok=finite_ok and actual.is_finite()
    samples+=1
 check(matrices_ok,"Every native part matches original ROM matrices over %d action-frame samples"%samples)
 check(finite_ok,"All native action matrices remain finite")
 check(before==geometry_snapshot(model),"Running, jumping, combo and golden animation never alter source vertices or mesh resources")
 model.apply_native_pose(0,0)
 var standing=native_bounds(model)
 check(absf(standing.size.y-ACCEPTED_HEIGHT)<.001,"Original body preserves the accepted Goemon standing height")
 check(absf(standing.position.y)<.001,"Original standing feet anchor to the existing ground plane")
 var stable=[]
 for pointer in POINTERS:stable.append(model.native_parts[pointer].global_transform)
 for i in 20:model.apply_native_pose(0,0)
 check(POINTERS.all(func(p):return close_matrix(model.native_parts[p].global_transform,stable[POINTERS.find(p)])),"Repeated sampling cannot accumulate scale, translation or rotation")
 model.body.rotation=Vector3(.7,.4,-.2)
 model.apply_native_pose(0x18,.05)
 check(model.body.rotation.distance_to(Vector3(.7,.4,-.2))<.00001,"Native sampling preserves the controller's whole-body double-jump turn")
 model.body.rotation=Vector3.ZERO
 var native_front:Vector3=(model.global_transform.affine_inverse()*model.rig_visual.global_transform).basis*Vector3.BACK
 check(native_front.normalized().distance_to(Vector3.FORWARD)<.00001,"Native source +Z front faces the controller's -Z attack direction")
 var original_mesh_snapshot=geometry_snapshot(model)
 model.apply_skin("ren")
 check(geometry_snapshot(model)==original_mesh_snapshot,"Saved skin preferences cannot replace original ROM geometry")
 check(roster_model_path(1)=="res://scripts/recovered_goemon_model.gd","Playable roster Goemon selects the native model")
 var expected_paths={2:"res://assets/characters/musashi/model/musashi_model.gd",13:"res://scripts/recovered_musashi_model.gd",14:"res://scripts/recovered_ed_model.gd",15:"res://scripts/recovered_ben_model.gd"}
 check(expected_paths.keys().all(func(id):return roster_model_path(id)==expected_paths[id]),"Edo, Musashi, Ed and Ben retain their accepted model bindings")
 for id in [2,15]:
  var other=Hero.ROSTER[id].model.new();root.add_child(other);await process_frame;other.set_process(false)
  var expected_scale=(ACCEPTED_HEIGHT*.8/3.3) if id==2 else (ACCEPTED_HEIGHT*2.0/1.8)
  check(absf(other.rig_visual.scale.y-expected_scale)<.00001,"%s keeps its accepted size relative to unchanged Goemon height"%("Edo" if id==2 else "Ben"))
  other.queue_free();await process_frame
 model.queue_free();await process_frame
 finish()
