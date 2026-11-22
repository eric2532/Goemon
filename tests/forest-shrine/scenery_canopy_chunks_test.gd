extends SceneTree
const Assets=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
var failures=0

func check(ok:bool,message:String):
 if not ok:failures+=1;printerr("CANOPY_CHUNK_FAIL ",message)

func _initialize():
 for kind in ["broadleaf_tree","cedar_tree","pine_tree"]:
  var parent=Node3D.new()
  var poses=[]
  for i in 160:poses.append(Transform3D(Basis(Vector3.UP,i*.15).scaled(Vector3.ONE*1.1),Vector3((i%20)*18,6,(i/20)*18)))
  Assets.batch(parent,kind,poses,true)
  var parts=Assets.source(kind)
  check(parent.get_child_count()>parts.size(),"Large groves have local culling bounds")
  for part in parts:
   var actual=[]
   var materials={}
   for node in parent.get_children():
    if node.multimesh.mesh!=part.mesh:continue
    materials[node.material_override]=true
    var low=INF;var high=-INF
    for i in node.multimesh.instance_count:
     var pose:Transform3D=node.multimesh.get_instance_transform(i)
     actual.append(pose)
     low=minf(low,pose.origin.x);high=maxf(high,pose.origin.x)
    if DisplayServer.get_name()!="headless":check(high-low<97,"Each batch stays in a 96 m cell")
    check(node.extra_cull_margin>=.5,"Wind retains a safe culling margin")
   check(actual.size()==poses.size(),"Every authored tree remains present")
   check(materials.size()==1,"Chunks share the existing immutable material")
   if DisplayServer.get_name()!="headless":
    for pose:Transform3D in poses:
     var expected:Transform3D=pose*part.transform
     check(actual.any(func(value):return value.is_equal_approx(expected)),"Chunking preserves every tree transform")
  parent.free()
 print("CANOPY_CHUNK_RESULT failures=",failures)
 if DisplayServer.get_name()=="headless":print("GPU transform reads require the desktop replay")
 quit(int(failures>0))
