extends SceneTree
const Profile=preload("res://scripts/recovered_goemon_combat_profile.gd")
const Weapons=preload("res://scripts/recovered_goemon_weapons.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1
 print("PASS: " if ok else "FAIL: ",label_)
func run():
 var model=load("res://scripts/recovered_goemon_model.gd").new();root.add_child(model);await process_frame;model.set_process(false)
 check(model.get_meta("original_pipe_tier",0)==3,"Goemon defaults to the original third-tier Gold Pipe")
 check(Profile.COMBO_ACTIONS==[0x68,0x69,0x6A] and Profile.COMBO_RECOVERIES==[0x6B,0x6C,0x6D],"Gold Pipe uses original third-tier combo and recovery actions")
 var part:Dictionary=Weapons.data().get("parts",{}).get("gold_pipe",{})
 check(not part.is_empty(),"Gold Pipe has its own recovered asset with resolved tier texture")
 if not part.is_empty():
  check(part.vertices.size()==115 and part.surfaces.reduce(func(n,s):return n+s.faces.size(),0)==90,"Gold Pipe preserves the original115vertices and90triangles")
  var textures_ok=true
  for surface in part.surfaces:
   var texture_file:String=surface.get("texture_file","")
   textures_ok=textures_ok and not texture_file.is_empty() and ResourceLoader.exists(Weapons.ROOT+texture_file)
  check(textures_ok,"Original dynamic segment-D gold texture is present in the game")
 var mounted=model.pipe.get_node_or_null("GoldPipe")
 check(mounted is MeshInstance3D,"Original Gold Pipe is mounted instead of the brown pipe")
 if mounted!=null:
  var exact=true
  for action in [0x68,0x69,0x6A,0x6B,0x6C,0x6D]:
   for frame in model.sampler.frame_count(action):
    var time_=float(frame)/(30*model.sampler.native_rate(action))
    model.apply_native_pose(action,time_)
    var source:Transform3D=model.sampler.sample_source(action,time_)["0x9002518"]
    var expected=Transform3D(source.basis.scaled(Vector3.ONE*model.source_scale),source.origin*model.source_scale+model.source_offset)
    exact=exact and model.pipe.transform.is_equal_approx(expected) and model.pipe.visible
  check(exact,"Gold Pipe follows every native weapon matrix across all six third-tier actions")
  model.apply_native_pose(0x0F,.1)
  check(not model.pipe.visible,"Original running leaves the hand empty between Gold Pipe attacks")
 model.queue_free();await process_frame
 print("GOEMON_GOLD_PIPE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
