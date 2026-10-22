extends SceneTree
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func near(value:float,want:float,label_:String,tolerance:float=.0001):check(absf(value-want)<tolerance,label_+" (%s expected %s)"%[value,want])
func run():
 check(ResourceLoader.exists("res://scripts/halo_effect_light_volume.gd"),"Native light-volume adapter exists")
 if failures:finish();return
 var data=load("res://scripts/halo_effect_data.gd").new()
 var renderer=load("res://scripts/halo_effect_particles.gd").new();root.add_child(renderer)
 var camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,0,5)
 renderer.configure(data,camera,1)
 var volume=load("res://scripts/halo_effect_light_volume.gd").new();root.add_child(volume);volume.configure(data,renderer,camera,1)
 var native=data.resolve({"class":"light_volume","path":"weapons\\rocket launcher\\rocket"})
 check(native.map_count==20,"Recovered rocket widget retains its native twenty sprites")
 volume.start(1,native,Vector3.ZERO,Vector3.RIGHT)
 renderer.tick(0)
 check(renderer.live_count()==20,"Native rocket widget creates twenty original-texture sprites")
 check(renderer.batch_count()==1,"Twenty native widgets share one actual texture batch")
 var points=renderer.snapshot()
 near(points[0].position.x,-1.8288,"Hither glow starts at native negative axial offset")
 near(points[19].position.x,-.3048,"Yon glow ends at native offset plus native length")
 near(points[0].radius,.1524,"Native hither radius converts Halo units to metres")
 near(points[19].radius,.19812,"Native yon radius converts Halo units to metres")
 near(points[0].tint.a,.05,"Hither sprite retains native low opacity")
 near(points[19].tint.a,.35,"Yon sprite retains native warm plume opacity")
 near(points[19].tint.b,.392157,"Native yon warm color comes from original tag")
 var original=data.bitmap_frame(data.manifest().defaults.light_volume_bitmap).texture
 var batch=renderer._batches.values()[0]
 check(batch.node.material_override.get_shader_parameter("atlas")==original,"Null authored map binds recovered native rasterizer glow bitmap")
 var first_id=points[0].id
 volume.move(1,Vector3(2,0,0),Vector3.UP);renderer.tick(0)
 points=renderer.snapshot()
 check(points[0].id==first_id,"Moving rocket refreshes persistent sprites without reallocating particles")
 near(points[0].position.x,2,"Widget follows actual rocket position")
 near(points[0].position.y,-1.8288,"Widget rotates with rocket forward axis")
 # View fade uses depth along the camera, with native48..50 world-unit limits.
 camera.position=Vector3.ZERO
 volume.move(1,Vector3(0,0,-149.352),Vector3.RIGHT);renderer.tick(0)
 points=renderer.snapshot()
 near(points[0].tint.a,.025,"Native camera-depth midpoint halves widget brightness")
 volume.move(1,Vector3(0,0,-160),Vector3.RIGHT);renderer.tick(0)
 near(renderer.snapshot()[19].tint.a,0,"Widget fades completely beyond native far distance")
 for id in range(2,10):volume.start(id,native,Vector3.ZERO,Vector3.RIGHT)
 check(renderer.live_count()==120,"Rocket widget pool stays bounded to six owners and120sprites")
 volume.clear();renderer.tick(0)
 check(renderer.live_count()==0,"Clear retires all owner-bound widget sprites")
 camera.position=Vector3(0,0,5)
 volume.start(10,native,Vector3.ZERO,Vector3.RIGHT)
 volume.stop(10);renderer.tick(0)
 check(renderer.live_count()==0,"Owner stop removes its glow immediately")
 if DisplayServer.get_name()!="headless":
  volume.start(11,native,Vector3(1,0,0),Vector3.RIGHT);renderer.tick(0)
  await process_frame;await process_frame
  root.get_texture().get_image().save_png("/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/master-chief-weapons/native-light-volume-test.png")
  volume.stop(11)
 volume.clear();volume.free();renderer.clear();renderer.free();camera.free();data=null;finish()
func finish():
 await process_frame;await process_frame
 print("HALO_EFFECT_LIGHT_VOLUME_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
