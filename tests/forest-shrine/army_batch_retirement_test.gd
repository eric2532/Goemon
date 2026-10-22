extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var renderer=load("res://scripts/forest/crowd/army_renderer.gd").new();root.add_child(renderer);renderer.configure(null)
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 var handles=[]
 for i in 3:handles.append(runtime.spawn(i+1,0,0,Vector3(i*4,0,0),192,3.9))
 renderer.present(runtime.render_snapshot(),[]);var batch=renderer.batches[Vector3i(0,0,0)]
 check(batch.multimesh.instance_count==4 and batch.multimesh.visible_instance_count==3,"Batch capacity grows geometrically while retaining every live body")
 runtime.despawn(handles[2]);renderer.present(runtime.render_snapshot(),[])
 check(batch.multimesh.instance_count==4 and batch.multimesh.visible_instance_count==2,"Population changes reuse the GPU allocation")
 for handle in handles.slice(0,2):runtime.set_pose(handle,Vector3(100,0,0),0)
 renderer.present(runtime.render_snapshot(),[])
 check(not batch.visible and renderer.counts().units==2,"An empty spatial batch leaves the render queue without removing any unit")
 runtime.set_pose(handles[0],Vector3.ZERO,0);renderer.present(runtime.render_snapshot(),[])
 check(batch.visible and batch.multimesh.visible_instance_count==1,"Returning actors reactivate their original spatial batch")
 renderer.clear()
 check(renderer.batches.values().all(func(node):return not node.visible),"Cleared batches stop issuing empty render commands")
 runtime.clear();runtime.free();renderer.queue_free();await process_frame
 print("ARMY_BATCH_RETIREMENT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
