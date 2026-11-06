extends SceneTree
const OUT="res://build/Other Files/Asset Toolkit/Crescent Optimization/"
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func exercise(trail,kind:String,frames:int)->Dictionary:
 var timings=[];var idle=kind=="idle"
 for frame in frames:
  var before=Time.get_ticks_usec()
  if kind=="musashi":
   trail.brightness=244;trail._draw()
  else:
   var time=frame/60.0;var direction=Vector3(sin(time*8),.4,cos(time*8))*3
   trail.advance(1.0/60,PackedVector3Array() if idle else PackedVector3Array([Vector3.ZERO,direction]),not idle,frame%180<90)
   if trail.has_method("flush_mesh"):trail.flush_mesh()
  timings.append(Time.get_ticks_usec()-before)
 timings.sort()
 return {"p50_us":timings[timings.size()/2],"p95_us":timings[int(timings.size()*.95)],"total_us":timings.reduce(func(a,b):return a+b,0)}
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var label_="before"
 var baseline=false
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--label="):label_=arg.trim_prefix("--label=")
  if arg=="--baseline":baseline=true
 var leader_script=load("res://scripts/recovered_leader_trail.gd")
 var musashi_script=load("res://scripts/recovered_musashi_trail.gd")
 if baseline:
  leader_script=GDScript.new();leader_script.source_code=FileAccess.get_file_as_string(OUT+"recovered_leader_trail-before.txt");assert(leader_script.reload()==OK)
  musashi_script=GDScript.new();musashi_script.source_code=FileAccess.get_file_as_string(OUT+"recovered_musashi_trail-before.txt");assert(musashi_script.reload()==OK)
 var rows={}
 for kind in ["idle","crescent","original","musashi"]:
  var trail
  if kind=="musashi":
   trail=musashi_script.new();root.add_child(trail)
   for i in 16:trail.samples.append({"inner":Vector3.ZERO,"outer":Vector3(sin(i*.1),.4,cos(i*.1))*3})
  else:
   trail=leader_script.new();trail.additive=kind=="original";root.add_child(trail)
  exercise(trail,kind,300)
  var material=trail.material_override.get_instance_id();var prepared=trail.prepared_mesh.get_instance_id()
  var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  rows[kind]=exercise(trail,kind,3000)
  check(trail.material_override.get_instance_id()==material and trail.prepared_mesh.get_instance_id()==prepared,"Prepared resources reused: "+kind)
  check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"No resource growth: "+kind)
  if kind!="idle" and kind!="musashi":
   trail.advance(1,PackedVector3Array(),false,false)
   check(trail.samples.is_empty() and trail.mesh==null,"Full expiry: "+kind)
  trail.free()
 var report={"label":label_,"renderer":DisplayServer.get_name(),"checks":checks,"failures":failures,"effects":rows,"note":"Isolated owner CPU microbenchmark, not rendered FPS."}
 FileAccess.open(OUT+label_+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CRESCENT_EFFECT_PERFORMANCE_RESULT ",JSON.stringify(report));quit(1 if failures else 0)
