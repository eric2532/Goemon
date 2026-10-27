extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();root.add_child(runtime);runtime.configure(null);runtime.shared_snapshot_enabled=true
 for kind in [0,1,3]:
  var row:Dictionary=model.waves.spawn_enemy(kind,Vector3(1.25,2.5,3.75));var names=row.keys();var retained_path:Array=row.path
  for key in ["pos","hp","velocity","facing"]:
   var actual=names.filter(func(k):return k==key)[0]
   check(typeof(actual)==TYPE_STRING_NAME,"Hot mirror key is interned: "+key)
   check(row.has(key) and row.has(StringName(key)) and row[key]==row[StringName(key)],"String and StringName callers read the same source field")
  var h:int=runtime.spawn(row.id,0,kind,row.pos,row.hp,1.3)
  var actor=load("res://scripts/forest/crowd/army_enemy_target.gd").new();actor.runtime=runtime;actor.handle=h;actor.forest_id=row.id;actor.variant=kind;root.add_child(actor);actor.sync(runtime.unit_state(h));runtime.native.register_facade(h,row,actor)
  var data:Dictionary=runtime.render_snapshot();data.shared_facades=true
  for i in data.handles.size():data.hp[i]=33.125;data.positions[i]=Vector3(-2.5,4.25,7.5);data.velocities[i]=Vector3(.25,.5,.75);data.yaw[i]=.375;data.pose_rows[i]=42
  check(runtime.native.sync_registered_facades(data)==1,"Native publication retains exact source dictionary identity")
  check(row.hp==33.125 and row.pos==Vector3(-2.5,4.25,7.5) and row.velocity==Vector3(.25,.5,.75) and row.facing==.375 and row.army_pose_row==42,"Every hot field retains its full numeric value")
  check(is_same(retained_path,row.path) and row.variant==kind and row["pos"]==row.pos,"Unrelated metadata and string-based readers remain intact")
  actor.free();runtime.clear()
 runtime.free();print("ARMY_ROW_KEYS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
