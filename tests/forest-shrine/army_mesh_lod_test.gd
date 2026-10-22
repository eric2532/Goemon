extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var path="res://scripts/forest/crowd/army_mesh_lod.gd"
 if not ResourceLoader.exists(path):check(false,"Attachment-safe crowd mesh distance detail is available");finish();return
 var builder=load(path);var total_base=0;var total_far=0
 for kind in [11,5,7,8,10]:
  var resource=load("res://assets/characters/ally_crowd/%d.res"%kind);var source:ArrayMesh=resource.get_meta("mesh");var result:ArrayMesh=builder.build(resource)
  check(result.get_surface_count()==source.get_surface_count(),"All material surfaces survive")
  var base_count=0;var coarse_count=0
  for surface in source.get_surface_count():
   var original=source.surface_get_arrays(surface);var actual=result.surface_get_arrays(surface)
   for field in Mesh.ARRAY_MAX:check(actual[field]==original[field],"Close-up vertices, attributes, weights and indices are unchanged")
   var lods:Dictionary=result.get_meta("lod_indices")[surface]
   var indices:PackedInt32Array=original[Mesh.ARRAY_INDEX];base_count+=indices.size()
   var deformable={}
   for i in range(0,indices.size(),3):
    var a=indices[i];var b=indices[i+1];var c=indices[i+2]
    var part=rigid_part(original,a)
    if part<0 or part!=rigid_part(original,b) or part!=rigid_part(original,c):deformable[Vector3i(a,b,c)]=true
   for level in lods:
    var selected:PackedInt32Array=lods[level];var retained={}
    check(selected.size()%3==0 and selected.size()<=indices.size(),"Distance detail is a valid smaller triangle list")
    for i in range(0,selected.size(),3):
     var a=selected[i];var b=selected[i+1];var c=selected[i+2];var tri=Vector3i(a,b,c);var part=rigid_part(original,a)
     check(deformable.has(tri) or (part>=0 and part==rigid_part(original,b) and part==rigid_part(original,c)),"No simplified triangle crosses independently animated attachments")
     if deformable.has(tri):retained[tri]=true
    check(retained.size()==deformable.size(),"Every deforming/body-joint triangle is preserved at every distance")
   coarse_count+=(lods.values().back() as PackedInt32Array).size() if not lods.is_empty() else indices.size()
  check(coarse_count<=base_count,"Distance detail never increases kit geometry")
  total_base+=base_count;total_far+=coarse_count
  print("ARMY_LOD_COUNTS kind=",kind," base=",base_count/3," far=",coarse_count/3)
 var owner=Node3D.new();root.add_child(owner)
 var renderer=load("res://scripts/forest/crowd/army_renderer.gd").new();root.add_child(renderer);renderer.configure(owner)
 var tuning={"ally_kinds":PackedInt32Array([11,5,7,8,10]),"ally_profiles":PackedFloat64Array(),"pose_resources":{}}
 for kind in tuning.ally_kinds:tuning.ally_profiles.append_array(PackedFloat64Array([200,renderer.speeds[kind],1,1,0]))
 var batch=renderer.batch(Vector3i(11,0,0));var detailed=renderer.meshes[11]
 tuning.pose_resources[11]=load("res://assets/characters/ally_crowd/11.res").duplicate()
 renderer.configure_profiles(tuning)
 check(not renderer.meshes[11].has_meta("lod_indices"),"Unbounded custom pose scales retain exact full geometry")
 check(batch.multimesh.mesh==renderer.meshes[11],"Existing instances follow custom-tuning geometry fallback")
 tuning.pose_resources.clear();renderer.configure_profiles(tuning)
 check(renderer.meshes[11]==detailed and batch.multimesh.mesh==detailed,"Default tuning restores the validated distance mesh")
 renderer.free();owner.free()
 check(total_far<total_base*.8,"The full mixed roster loses at least20percent of far triangles")
 finish()
func rigid_part(arrays:Array,index:int)->int:
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM1]
 if weights[index*4]!=1 or weights[index*4+1]!=0 or weights[index*4+2]!=0 or weights[index*4+3]!=0:return -1
 return int(arrays[Mesh.ARRAY_CUSTOM0][index*4])
func finish():print("ARMY_MESH_LOD_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
