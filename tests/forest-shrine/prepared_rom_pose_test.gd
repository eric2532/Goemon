extends SceneTree
var checks=0
var failures=0
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",note)
func _initialize():run.call_deferred()
func original_sample(sampler,raw:Dictionary,action:int,seconds:float)->Dictionary:
 var pointer:String=raw.actions.get(str(action),"")
 if pointer.is_empty():return {}
 var clip:Dictionary=raw.clips[pointer]
 var position=clampf(seconds*30*sampler.native_rate(action),0,float(clip.frame_count)-1)
 var a=floori(position);var b=mini(a+1,int(clip.frame_count)-1);var t=position-a;var result={}
 for i in clip.pointers.size():
  var key:String=clip.pointers[i]
  if key=="0x0":continue
  var first=sampler._transform(clip.frames[a][i])
  result[key]=first if t<.000001 else sampler._interpolate_transform(first,sampler._transform(clip.frames[b][i]),t)
 return result
func cost(sampler,raw:Dictionary,original:bool)->float:
 var begin=Time.get_ticks_usec()
 for i in 500:
  var time=fmod(i*.01337,sampler.duration(0x68))
  if original:original_sample(sampler,raw,0x68,time)
  else:sampler.sample_source(0x68,time)
 return (Time.get_ticks_usec()-begin)/1000.0
func run():
 var timings={}
 for who in ["goemon","sasuke","yae"]:
  var sampler=load("res://scripts/recovered_"+who+"_pose.gd").new()
  var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(sampler.DATA_PATH))
  check(sampler.source_metadata==raw.metadata,"Original metadata stays intact")
  for action_key in raw.actions:
   var action=int(action_key)
   for frame in sampler.frame_count(action):
    for fraction in [0.0,.37]:
     var time=(frame+fraction)/(30*sampler.native_rate(action))
     var expected=original_sample(sampler,raw,action,time)
     check(sampler.sample_source(action,time)==expected,"Every prepared source pose matches the original arithmetic exactly")
     for part in expected:
      check(sampler.sample_part(action,time,part)==expected[part],"Weapon-anchor sampling retains exact source matrices")
  for time in [-1.0,1000.0]:check(sampler.sample_source(0,time)==original_sample(sampler,raw,0,time),"Time clamping is unchanged")
  check(sampler.sample_source(99999,0).is_empty() and sampler.sample_part(99999,0,"missing")==Transform3D.IDENTITY,"Unknown actions retain their fallbacks")
  var second=sampler.get_script().new();check(second.sample_source(0,0)==sampler.sample_source(0,0),"Additional heroes reuse prepared matrices without converting them twice")
  var before=sampler.sample_source(0,0);var modified=sampler.sample_source(0,0);modified[modified.keys()[0]]=Transform3D.IDENTITY
  check(sampler.sample_source(0,0)==before,"Changing a sampled pose cannot mutate shared source frames")
  cost(sampler,raw,true);cost(sampler,raw,false)
  var rounds=[]
  for round in 8:
   var original=0.0;var prepared=0.0
   if round%2==0:original=cost(sampler,raw,true);prepared=cost(sampler,raw,false)
   else:prepared=cost(sampler,raw,false);original=cost(sampler,raw,true)
   rounds.append({"original_ms":original,"prepared_ms":prepared})
  timings[who]=rounds
 FileAccess.open("res://build/Other Files/Asset Toolkit/24 Hero Optimization/prepared-pose-cost.json",FileAccess.WRITE).store_string(JSON.stringify(timings,"  "))
 print("PREPARED_ROM_POSE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
