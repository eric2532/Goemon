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
 var kinds=[0,1,3,11,5,7,8,10,31]
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
  check(renderer.writes==0 and renderer.submitted==kinds.size() and renderer.counts().health==kinds.size()-3,"Real rendering submits every fighter without per-unit GDScript packing")
 var invalid=snapshot.duplicate(true);invalid.positions=PackedVector3Array()
 check(not runtime.native.instance_buffers(invalid,profiles).valid,"Malformed render data cannot expose mismatched memory")
 # Coarser batches must preserve every root/pose in source order, with tight
 # bounds around occupied positions and the original animation padding.
 for i in 2000:
  var x=[-512.0001,-512.0,-256.0001,-256.0,-.0001,0.0,255.9999,256.0,511.9999,512.0][i%10]
  runtime.spawn(10000+i,i%2,0 if i%2==0 else 11,Vector3(x,i%17,(i/10)%20*15-150),500,.4)
 var crowded:Dictionary=runtime.render_snapshot();var packed:Dictionary=runtime.native.instance_buffers(crowded,profiles);var expected_groups={}
 for i in crowded.handles.size():
  var p:Vector3=crowded.positions[i];var key=Vector3i(crowded.kinds[i],floori(p.x/renderer.CELL),floori(p.z/renderer.CELL))
  if not expected_groups.has(key):expected_groups[key]=[]
  expected_groups[key].append(i)
 check(packed.valid and packed.submitted==2000+kinds.size() and packed.batches.size()==expected_groups.size(),"Every fighter remains in exactly one spatial batch across positive/negative cell edges")
 for batch_:Dictionary in packed.batches:
  var indices:Array=expected_groups[batch_.key];var low=Vector3.INF;var high=-Vector3.INF
  check(batch_.buffer.size()==indices.size()*16,"Batch capacity contains every independent fighter")
  for row in indices.size():
   var i:int=indices[row];var p:Vector3=crowded.positions[i];low=low.min(p);high=high.max(p)
   renderer._buffer=PackedFloat32Array();renderer._buffer.resize(16)
   renderer.write_instance(0,Transform3D(Basis(Vector3.UP,crowded.yaw[i]),p),renderer.pose_sample(crowded,i))
   check(range(16).all(func(n):return absf(renderer._buffer[n]-batch_.buffer[row*16+n])<.0001),"Crowded packing preserves exact source order, position, facing and animation")
  check(batch_.bounds==AABB(low-Vector3(12,4,12),high-low+Vector3(24,20,24)),"Occupied bounds retain full original animation padding without empty cell space")
 verify_enemy_feedback(runtime,renderer)
 runtime.clear();renderer.queue_free();runtime.free();await process_frame;finish()
func verify_enemy_feedback(runtime,renderer):
 for kind in preload("res://scripts/forest/forest_enemy_roles.gd").RIGID_TYPES:
  runtime.clear();runtime.set_navigation(3000+kind,{"width":0})
  var handle:int=runtime.spawn(1,0,kind,Vector3.ZERO,1000,1.3)
  runtime.spawn(2,0,kind,Vector3(3,0,0),1000,1.3)
  var idle:Dictionary=runtime.render_snapshot()
  check(renderer.pose_sample(idle,0).a==0,"Unhit kind %d has no hit flash"%kind)
  check(not runtime.apply_hit(handle,{"amount":0.0}).accepted and renderer.pose_sample(runtime.render_snapshot(),0).a==0,"Kind %d cannot flash without accepted damage"%kind)
  runtime.apply_hit(handle,{"amount":22.0,"direction":Vector3.BACK})
  var hit:Dictionary=runtime.render_snapshot();var packed:Dictionary=runtime.native.instance_buffers(hit,{})
  check(hit.hp[0]==978 and is_equal_approx(hit.flash_left[0],.115),"Kind %d records damage and its existing flash immediately"%kind)
  check(is_equal_approx(packed.batches[0].buffer[15],hit.flash_left[0]),"Kind %d sends its actual hit flash to the native GPU buffer"%kind)
  check(packed.batches[0].buffer[31]==0 and renderer.pose_sample(hit,1).a==0,"Kind %d hit cannot flash its unhit batch neighbour"%kind)
  check(is_equal_approx(renderer.pose_sample(hit,0).a,hit.flash_left[0]),"Kind %d script packing preserves the same hit flash"%kind)
  runtime.step(.2,{})
  var recovered:Dictionary=runtime.render_snapshot()
  check(renderer.pose_sample(recovered,0).a==0 and runtime.native.instance_buffers(recovered,{}).batches[0].buffer[15]==0,"Kind %d flash expires through the existing timer"%kind)
  runtime.apply_hit(handle,{"amount":22.0});runtime.despawn(handle)
  runtime.spawn(3,0,kind,Vector3.ZERO,1000,1.3)
  check(renderer.pose_sample(runtime.render_snapshot(),0).a==0,"Kind %d slot reuse cannot inherit a prior hit flash"%kind)
func finish():
 print("ARMY_INSTANCE_BUFFERS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
