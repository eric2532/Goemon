extends SceneTree
## Delayed native emissions must not rebuild every existing particle batch per birth.
class CountedParticles extends "res://scripts/halo_effect_particles.gd":
 var submissions=0
 var camera_queries=0
 func _camera()->Camera3D:
  camera_queries+=1;return super._camera()
 func _flush(draws:Dictionary):
  submissions+=1;super._flush(draws)
class CountedData extends "res://scripts/halo_effect_data.gd":
 var resolutions=0
 var frame_queries=0
 func bitmap_frame(reference:Variant,sequence:int=0,frame:float=0)->Dictionary:
  frame_queries+=1;return super.bitmap_frame(reference,sequence,frame)
 func resolve(reference:Variant,class_name_:String="")->Dictionary:
  resolutions+=1;return super.resolve(reference,class_name_)
var failures=0
var checks=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1;print("PASS: " if ok else "FAIL: ",label_)
 if not ok:failures+=1
func run():
 var fx=load("res://scripts/halo_weapon_effects.gd").new();root.add_child(fx);fx.set_process(false);fx.particles.free()
 var particles=CountedParticles.new();fx.add_child(particles);particles.configure(fx.data);fx.particles=particles;fx.trails.particles=particles;fx.light_volumes.particles=particles
 var bitmap={"class":"bitmap","path":"effects\\particles\\solid\\bitmaps\\casings h ar"}
 particles.spawn_sprite({"bitmap":bitmap,"lifetime":1.0,"position":Vector3.ZERO,"velocity":Vector3.RIGHT})
 # Native graph events still run at their original sub-frame birth times.
 for delay in [.001,.003,.007,.011]:fx._queue(delay,"dispatch",{"ref":{}})
 fx.advance(1.0/60)
 check(particles.camera_queries<=1,"A particle frame shares one camera snapshot across every sprite and batch")
 check(particles.submissions==1,"A frame with four delayed births submits existing particle batches once")
 var p=particles.snapshot()[0]
 check(is_equal_approx(p.age,1.0/60) and p.position.is_equal_approx(Vector3.RIGHT/60),"Skipping intermediate submissions preserves particle lifetime and motion")
 check(fx.pending_count()==0 and is_equal_approx(fx._clock,1.0/60),"All scheduled events execute within the frame")
 var data=CountedData.new()
 var frame=data.bitmap_frame(bitmap,0,0)
 check(not frame.is_empty(),"Recovered casing atlas is available")
 data.resolutions=0
 for i in 1000:
  data.bitmap_frame(bitmap,0,0);data.sequence_length(bitmap,0)
 check(data.resolutions==0,"A warmed sprite frame and sequence do not repeatedly resolve native tag graphs")
 particles.configure(data);particles.tick(0);data.frame_queries=0
 particles.tick(1.0/60)
 check(data.frame_queries==0,"Live simple sprites reuse their native frame sequence without frame lookups")
 var unrotated:Basis=particles._batches.values()[0].instances[0].transform.basis
 var quad_scale=Vector3(unrotated.x.x,unrotated.y.y,unrotated.z.z)
 var camera=Camera3D.new();root.add_child(camera);particles.camera_override=camera
 for rotation_ in [Vector3(.2,.4,.1),Vector3(-.3,-.6,.2)]:
  camera.rotation=rotation_;particles.tick(0)
  check(particles._batches.values()[0].instances[0].transform.basis.is_equal_approx(camera.global_basis.scaled(quad_scale)),"A shared billboard basis follows camera rotation each frame")
 camera.queue_free();particles.camera_override=null
 data.configure({"tags":{"test":{"class":"bitmap","data":{"sequences":[{"bitmap_count":3}]}}}})
 check(data.sequence_length("test")==3,"Changing manifests invalidates cached sequence lengths")
 data.configure({"tags":{"test":{"class":"bitmap","data":{"sequences":[{"bitmap_count":7}]}}}})
 check(data.sequence_length("test")==7,"A new manifest with the same bitmap path supplies its new sequence")
 particles.tick(0)
 check(particles._batches.values()[0].instances.is_empty(),"Reconfiguring native data invalidates sequences retained by live particles")
 fx.queue_free();await process_frame
 print("HALO_EFFECT_PERFORMANCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
