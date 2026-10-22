extends SceneTree
## Only quads wholly outside the rendered camera may skip submission. Native
## trajectories, births, lifetime/animation and camera-edge sprites stay intact.
class CountedParticles extends "res://scripts/halo_effect_particles.gd":
 var bases=0
 var camera_queries=0
 var quads=0
 var states=0
 func _state_at(p:Dictionary)->Dictionary:
  states+=1;return super._state_at(p)
 func _draw_quad(p:Dictionary,entry:Dictionary,weight:float,draws:Dictionary,sequence_override:int=-1,frame_override:float=-INF,rotation_override:float=-INF,flip_u:bool=false):
  quads+=1;super._draw_quad(p,entry,weight,draws,sequence_override,frame_override,rotation_override,flip_u)
 func _sprite_basis(p:Dictionary,rotation_override:float=-INF)->Basis:
  bases+=1;return super._sprite_basis(p,rotation_override)
 func _camera()->Camera3D:
  camera_queries+=1;return super._camera()
var checks=0
var failures=0
const BITMAP={"class":"bitmap","path":"effects\\particles\\solid\\bitmaps\\casings h ar"}
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func instances(particles)->int:
 var count=0
 for batch in particles._batches.values():count+=batch.instances.size()
 return count
func spawn(particles,position_:Vector3,radius:float=.1)->int:
 return particles.spawn_sprite({"bitmap":BITMAP,"lifetime":1.0,"radius":radius,"position":position_,"velocity":Vector3.RIGHT,"rotation_rate":2.0})
func run():
 var camera=Camera3D.new();root.add_child(camera);camera.make_current();camera.near=.1;camera.far=1000
 var particles=CountedParticles.new();root.add_child(particles);particles.configure({},camera)
 for i in 100:spawn(particles,Vector3(0,0,10+i))
 particles.tick(.01)
 check(particles.bases==0 and instances(particles)==0,"A hundred quads wholly behind the camera allocate no draw transforms")
 check(particles.quads==0,"Cached native sprite bounds reject invisible simple particles before quad preparation")
 check(particles.states==0,"Simple native sprites skip construction of absent state timelines")
 check(particles.live_count()==100,"Invisible quads retain every native particle")
 var before=particles.snapshot()[0]
 check(is_equal_approx(before.age,.01) and is_equal_approx(before.rotation,.02) and before.position.is_equal_approx(Vector3(.01,0,10)),"Invisible quads retain exact age, angular motion and trajectory")
 check(particles.camera_queries==1,"Every submitted frame snapshots its camera and frustum once")
 camera.rotation.y=PI;particles.bases=0;particles.tick(0)
 check(particles.bases==100 and instances(particles)==100,"Turning the camera reveals the same live particles immediately")
 particles.clear();camera.rotation=Vector3.ZERO
 # A center just behind the near plane is invisible as a point, but its large
 # registered sprite still intersects the camera and must remain submitted.
 spawn(particles,Vector3(0,0,.15),2)
 check(not camera.is_position_in_frustum(Vector3(0,0,.15)),"Near-edge fixture center lies outside the camera")
 particles.tick(0)
 check(instances(particles)==1,"A sprite intersecting a camera plane is conservatively retained")
 particles.clear();spawn(particles,Vector3(10,0,-5))
 var registered=particles._particles[0]._sprite_frames[0].duplicate()
 registered.registration.x=registered.rect.size.x*50
 particles._particles[0].attachment_id="registered"
 particles.update_attachment("registered",[{"_sprite_frames":[registered]}])
 particles.tick(0)
 check(instances(particles)==1,"An offscreen anchor retains a registered rectangle that extends into view")
 particles.position=Vector3(100,20,30);particles.scale=Vector3(2,3,4)
 particles.clear();spawn(particles,Vector3(0,0,-5));particles.tick(0)
 check(instances(particles)==1,"World-space sprite batches retain visibility under a transformed emitter parent")
 var initial=particles._batches.values()[0].instances[0].duplicate()
 camera.position=Vector3(100,0,0);particles.tick(0)
 check(instances(particles)==0,"Moving the camera replaces stale visibility and clears old batch instances")
 camera.position=Vector3.ZERO;particles.tick(0)
 var returned=particles._batches.values()[0].instances[0]
 check(returned.transform.is_equal_approx(initial.transform) and returned.uv==initial.uv and returned.tint==initial.tint,"Visibility cycling preserves sprite transform, original UVs and tint")
 particles.tick(1.01,false)
 check(particles.live_count()==0,"Invisible simulation substeps retain exact native expiry")
 particles.clear();particles.camera_override=null;camera.clear_current();spawn(particles,Vector3(0,0,10));particles.tick(0)
 check(instances(particles)==1,"Camera-free diagnostics retain their existing submission behavior")
 particles.queue_free();camera.queue_free();await process_frame
 print("HALO_EFFECT_FRUSTUM_PERFORMANCE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
