extends SceneTree
class Renderer extends "res://scripts/forest/crowd/army_renderer.gd":
 var writes=0
 func write_instance(index:int,pose:Transform3D,color:Color):
  writes+=1;super.write_instance(index,pose,color)
var checks=0
var failures=0
func check(ok,label_):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 if not runtime.native.has_method("instance_buffers"):
  check(false,"Crowd rendering needs native packed instance preparation");runtime.free();finish();return
 var renderer=Renderer.new();root.add_child(renderer);renderer.configure(null)
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42);runtime.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model))
 var kinds=[0,1,3,11,5,7,8,10]
 for i in kinds.size():runtime.spawn(i+1,0 if i<3 else 1,kinds[i],Vector3(i*11-45,i%3,-32),500,.4)
 var snapshot=runtime.render_snapshot();var profiles=renderer.instance_profiles()
 for case_ in 48:
  for i in kinds.size():
   snapshot.yaw[i]=float(case_)*.231+i*.2;snapshot.status[i]=1 if case_%5==0 else (64 if case_%7==0 else 0)
   snapshot.pose_velocities[i]=Vector3(sin(case_*.3),0,cos(case_*.3))*(case_%17)
   snapshot.walk_phase[i]=case_*.274;snapshot.pose_time[i]=case_*.029;snapshot.flash_left[i]=.03 if case_%9==0 else 0
   snapshot.render_actions[i]=[0,8,9,10,11,12,13,16,6][case_%9];snapshot.render_time[i]=case_*.039-.1;snapshot.action_indices[i]=case_%6;snapshot.air_phase[i]=[0,3,4,5][case_%4]
   snapshot.hp[i]=case_+25
  var data:Dictionary=runtime.native.instance_buffers(snapshot,profiles)
  check(data.get("valid",false),"Native render input is validated")
  var submitted=0;var health=0
  for i in kinds.size():
   if snapshot.status[i]&64 and kinds[i]!=8:continue
   submitted+=1
   if snapshot.teams[i]==1:health+=1
   var key=Vector3i(kinds[i],floori(snapshot.positions[i].x/renderer.CELL),floori(snapshot.positions[i].z/renderer.CELL))
   var batch=data.batches.filter(func(row):return row.key==key)[0]
   renderer._buffer=PackedFloat32Array();renderer._buffer.resize(16)
   renderer.write_instance(0,Transform3D(Basis(Vector3.UP,snapshot.yaw[i]),snapshot.positions[i]),renderer.pose_sample(snapshot,i))
   var expected:PackedFloat32Array=renderer._buffer;var actual:PackedFloat32Array=batch.buffer
   check(range(16).all(func(n):return absf(expected[n]-actual[n])<.0001),"Kind%d case%d retains exact source root, pose interpolation, tint and flash"%[kinds[i],case_])
   check(batch.bounds.has_point(snapshot.positions[i]+Vector3.UP*6),"Native batch bounds retain terrain height and full body")
  check(data.submitted==submitted and data.health.size()==health*16,"Native packing retains every visible body and independent health bar")
 if not renderer.has_method("use_native_buffers"):
  check(false,"The game renderer must consume native packed buffers")
 else:
  renderer.use_native_buffers(runtime.native);renderer.writes=0;renderer.present(snapshot,[])
  check(renderer.writes==0 and renderer.submitted==8 and renderer.counts().health==5,"Real rendering submits every fighter without per-unit GDScript packing")
 var invalid=snapshot.duplicate(true);invalid.positions=PackedVector3Array()
 check(not runtime.native.instance_buffers(invalid,profiles).valid,"Malformed render data cannot expose mismatched memory")
 runtime.clear();renderer.queue_free();runtime.free();await process_frame;finish()
func finish():
 print("ARMY_INSTANCE_BUFFERS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
