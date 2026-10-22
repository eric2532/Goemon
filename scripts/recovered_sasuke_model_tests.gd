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
 check(ResourceLoader.exists('res://scripts/recovered_sasuke_model.gd'),'Native Sasuke model is available')
 if failures:quit(1);return
 var model=load('res://scripts/recovered_sasuke_model.gd').new();root.add_child(model);await process_frame;model.set_process(false)
 var archive:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://assets/characters/recovered_sasuke/motion.json'))
 check(model.sampler.frame_count(0x68)==9 and absf(model.sampler.duration(0x68)-8.0/30)<.000001,'Tier3 first kunai attack uses original nine frames at1x')
 check(absf(model.sampler.duration(0x6b)-10.0/48)<.000001,'Recovery uses original1.6x action rate')
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
 check(absf(high-low-2.523715)<.0001 and absf(low)<.0001,'Native standing stature stays shorter than Goemon with feet on ground')
 check(model.sampler.sample_source(999,0).is_empty(),'Unknown actions return an empty pose')
 model.apply_native_pose(0,0);var stable=model.native_parts['0x9004918'].transform
 for i in 30:model.apply_native_pose(0,0)
 check(close_(stable,model.native_parts['0x9004918'].transform),'Repeated native sampling does not accumulate placement')
 var segments:Array=model.weapon_segments(0x68,3.0/30)
 check(segments.size()==2 and segments.all(func(s):return s.base.is_finite() and s.tip.is_finite() and s.base.distance_to(s.tip)>.1),'Both gold kunai expose real blade segments for contact sweeps')
 check(model.native_parts['0x9002aa8'].get_child(0).mesh.surface_get_material(0) is ShaderMaterial,'Gold kunai retains native generated reflection shader')
 var moving=false
 var first:Array=model.weapon_segments(0x68,0)
 var last:Array=model.weapon_segments(0x68,6.0/30)
 for i in mini(first.size(),last.size()):moving=moving or first[i].tip.distance_to(last[i].tip)>.15
 check(moving,'Contact endpoints follow native attack matrices')
 model.locomotion.update(.1,Vector3(0,0,5),true,0,0,false);model.locomotion.evaluate()
 check(model.locomotion.source_action==0xf,'Fast gait uses Sasuke native running action')
 model.locomotion.update(.1,Vector3.ZERO,false,6,0,false);model.locomotion.evaluate()
 check(model.locomotion.source_action==0x18,'Jump rise uses native action18')
 model.locomotion.update(.1,Vector3.ZERO,false,-2,0,false);model.locomotion.evaluate()
 check(model.locomotion.source_action==0x19,'Fall uses native action19')
 var combat=load('res://scripts/recovered_sasuke_combat.gd').new()
 combat.active=true;combat.mode='primary';combat.action_id=0x69;combat.elapsed=6.0/30
 model.combat=combat;model.locomotion.dirty=true;model.locomotion.evaluate()
 check(model.source_action==0x69 and absf(model.source_time-.2)<.00001,'Actual combat Node owns native action and elapsed pose clock')
 model.combat=null;combat.free()
 for kind in ['bomb','ice','hail']:
  var projectile=model.create_projectile_visual(kind)
  check(projectile.get_child_count()>0,'Native '+kind+' projectile contains recovered source meshes')
  projectile.free()
 var hair=model.weapon_segments(0x6f,.15)
 check(hair.size()>=1 and hair[0].base.distance_to(hair[0].tip)>.1,'Forward hair contact uses original long hair mesh')
 model.queue_free();await process_frame
 print('SASUKE MODEL TESTS failures=',failures);quit(1 if failures else 0)
