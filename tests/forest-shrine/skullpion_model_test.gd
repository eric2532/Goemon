extends SceneTree
var failures=0
var checks=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func sample(model:Node,clip:String,time:float):
 var player:AnimationPlayer=model.find_child("AnimationPlayer",true,false)
 player.play(clip);player.seek(time,true);player.pause()
func points(model:Node,names:Array)->PackedVector3Array:
 var result=PackedVector3Array()
 for name_ in names:
  var part:MeshInstance3D=model.find_child(name_,true,false)
  for surface in part.mesh.get_surface_count():
   for p in part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:result.append(part.global_transform*p)
 return result
func run():
 var old=load("res://assets/characters/recovered_skullpion/skullpion.glb").instantiate()
 var model=load("res://assets/models/enemies/skullpion.glb").instantiate();root.add_child(old);root.add_child(model)
 var player:AnimationPlayer=model.find_child("AnimationPlayer",true,false)
 var original:AnimationPlayer=old.find_child("AnimationPlayer",true,false)
 check(player.get_animation_list().size()==27,"All 22 source clips and five prepared castle clips are imported")
 var names=[]
 for i in 22:
  var key="Part_%02d"%i;names.append(key)
  var a:MeshInstance3D=old.find_child(key,true,false);var b:MeshInstance3D=model.find_child(key,true,false)
  check(a.mesh.get_surface_count()==b.mesh.get_surface_count(),"Original material surfaces survive on "+key)
  for s in a.mesh.get_surface_count():
   var aa=a.mesh.surface_get_arrays(s);var bb=b.mesh.surface_get_arrays(s)
   var error=0.0
   check(aa[Mesh.ARRAY_VERTEX].size()==bb[Mesh.ARRAY_VERTEX].size(),"Original vertex count survives on "+key)
   for v in aa[Mesh.ARRAY_VERTEX].size():error=maxf(error,aa[Mesh.ARRAY_VERTEX][v].distance_to(bb[Mesh.ARRAY_VERTEX][v]))
   # Godot's mesh compression changes local coordinates by up to .0015 ROM units.
   check(error<.002,"Imported original geometry survives on "+key)
   if aa[Mesh.ARRAY_TEX_UV]!=null:check(aa[Mesh.ARRAY_TEX_UV]==bb[Mesh.ARRAY_TEX_UV],"Original UVs survive on "+key)
 for clip in original.get_animation_list():
  var length=original.get_animation(clip).length
  check(is_equal_approx(length,player.get_animation(clip).length),"Source duration survives: "+clip)
  for tick in 5:
   var time=length*tick/4;sample(old,clip,time);sample(model,clip,time)
   for name_ in names:
    check(old.find_child(name_,true,false).transform.is_equal_approx(model.find_child(name_,true,false).transform),"Source rigid pose survives: %s %s %s"%[clip,tick,name_])
 for clip in ["Castle_Idle","Castle_Walk","Castle_Ascend","Castle_Cling","Castle_Jump"]:
  var length=player.get_animation(clip).length
  for tick in 49:
   sample(model,clip,length*tick/48)
   var feet=points(model,["Part_10","Part_11"]);var low=INF
   for p in feet:low=minf(low,p.y)
   check(absf(low)*12<.31,"Prepared feet follow the origin floor: %s %s"%[clip,tick])
   if clip=="Castle_Cling":
    var contact=points(model,["Part_01","Part_02","Part_10","Part_11"]);var front=-INF
    for p in contact:front=maxf(front,p.z)
    check(absf(front-1)*12<.31,"Prepared claws meet the native wall plane")
 old.queue_free();model.queue_free();await process_frame
 print("SKULLPION_MODEL_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
