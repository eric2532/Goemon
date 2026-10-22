extends SceneTree
## Catches wrong native frame-rate, rigid transforms, attachment visibility and drift.
var failures=0
func check(ok:bool,label:String):
 if not ok:failures+=1;push_error(label)
 else:print('PASS: ',label)
func _initialize():call_deferred('run')
func transform_(v:Array)->Transform3D:
 return Transform3D(Basis(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8])),Vector3(v[9],v[10],v[11]))
func close_(a:Transform3D,b:Transform3D)->bool:
 return a.origin.distance_to(b.origin)<.00005 and a.basis.x.distance_to(b.basis.x)<.00005 and a.basis.y.distance_to(b.basis.y)<.00005 and a.basis.z.distance_to(b.basis.z)<.00005
func run():
 check(ResourceLoader.exists('res://scripts/recovered_yae_model.gd'),'Native Yae model is available')
 if failures:quit(1);return
 var model=load('res://scripts/recovered_yae_model.gd').new();root.add_child(model);await process_frame;model.set_process(false)
 var archive:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://assets/characters/recovered_yae/motion.json'))
 check(model.sampler.frame_count(0x68)==9 and absf(model.sampler.duration(0x68)-8.0/42)<.000001,'Tier3 first katana attack uses original nine frames at1.4x')
 check(absf(model.sampler.duration(0x6b)-19.0/48)<.000001,'Recovery uses original1.6x action rate')
 var matrices=true;var samples=0;var finite=true
 for action in archive.actions:
  var clip:Dictionary=archive.clips[archive.actions[action]];var rate:float=archive.rates[action]
  for frame in [0,int(clip.frame_count)/2,int(clip.frame_count)-1]:
   var seconds=float(frame)/(30*rate);model.apply_native_pose(int(action),seconds)
   for pointer in model.native_parts:
    var index:int=clip.pointers.find(pointer);var part:Node3D=model.native_parts[pointer]
    if index<0:continue
    var raw=transform_(clip.frames[frame][index]);var expected=Transform3D(raw.basis.scaled(Vector3.ONE*model.source_scale),raw.origin*model.source_scale+model.source_offset)
    matrices=matrices and close_(part.transform,expected);finite=finite and part.transform.is_finite();samples+=1
 check(matrices,'Every rigid body and special attachment uses native matrices at '+str(samples)+' action samples')
 check(finite,'Native transforms are finite across all232 actions')
 model.apply_native_pose(0,0)
 var low=INF;var high=-INF
 for pointer in model.native_parts:
  var part:Node3D=model.native_parts[pointer]
  if not part.visible:continue
  for mesh in part.get_children():
   for surface in mesh.mesh.get_surface_count():
    for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
     var height=(part.transform*vertex).y
     low=minf(low,height);high=maxf(high,height)
 check(absf(high-low-2.79397708)<.0001 and absf(low)<.0001,'Native standing stature uses common source unit scale with feet on ground')
 check(model.sampler.sample_source(999,0).is_empty(),'Unknown actions return an empty pose')
 model.apply_native_pose(0,0);var stable=model.native_parts['0x90026e8'].transform
 for i in 30:model.apply_native_pose(0,0)
 check(close_(stable,model.native_parts['0x90026e8'].transform),'Repeated native sampling does not accumulate placement')
 var segments:Array=model.weapon_segments(0x68,3.0/30)
 check(segments.size()==1 and segments.all(func(s):return s.base.is_finite() and s.tip.is_finite() and s.base.distance_to(s.tip)>.1),'Gold katana exposes real blade segment for contact sweeps')
 check(model.native_parts['0x90026e8'].get_child(0).mesh.surface_get_material(0) is ShaderMaterial,'Gold katana retains native generated reflection shader')
 var moving=false
 var first:Array=model.weapon_segments(0x68,0)
 var last:Array=model.weapon_segments(0x68,6.0/30)
 for i in mini(first.size(),last.size()):moving=moving or first[i].tip.distance_to(last[i].tip)>.15
 check(moving,'Contact endpoints follow native attack matrices')
 model.locomotion.update(.1,Vector3(0,0,5),true,0,0,false);model.locomotion.evaluate()
 check(model.locomotion.source_action==0xf,'Fast gait uses Yae native running action')
 model.locomotion.update(.1,Vector3.ZERO,false,6,0,false);model.locomotion.evaluate()
 check(model.locomotion.source_action==0x18,'Jump rise uses native action18')
 model.locomotion.update(.1,Vector3.ZERO,false,-2,0,false);model.locomotion.evaluate()
 check(model.locomotion.source_action==0x19,'Fall uses native action19')
 var projectile=model.create_projectile_visual('bazooka')
 check(projectile.get_child_count()>0,'Bazooka projectile uses original recovered display list')
 var missile_mesh:MeshInstance3D=projectile.get_child(0)
 var missile_colors:PackedColorArray=missile_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
 check(missile_colors[0].is_equal_approx(Color.WHITE),'Native texel-only missile combiner bypasses unused blue vertex-normal bytes')
 projectile.free()
 var homing=model.create_projectile_visual('lock_on')
 check(homing.get_child_count()>0,'Charged lock-on missiles retain the native bazooka projectile art')
 homing.free()
 model.queue_free();await process_frame
 print('YAE MODEL TESTS failures=',failures);quit(1 if failures else 0)
