extends SceneTree
## Catches range settings scaling hit volumes while leaving visible blades unchanged.
var failures=0
class ReachGame:
 extends Node
 var tuning={}
class ReachHero:
 extends Hero
 var requested_reach=1.0
 func _ready():pass
 func _physics_process(_delta):pass
 func melee_reach_setting()->float:return requested_reach
func check(ok:bool,label:String):
 if not ok:failures+=1;push_error(label)
 else:print('PASS: ',label)
func close_(a:Transform3D,b:Transform3D)->bool:
 return a.origin.distance_to(b.origin)<.00005 and a.basis.x.distance_to(b.basis.x)<.00005 and a.basis.y.distance_to(b.basis.y)<.00005 and a.basis.z.distance_to(b.basis.z)<.00005
func _initialize():run.call_deferred()
func run():
 var model=load('res://scripts/recovered_sasuke_model.gd').new();root.add_child(model);await process_frame;model.set_process(false)
 check(model.has_method('reach_scale') and model.has_method('scaled_source_pose'),'Model applies reach settings to native rendered poses')
 if failures:model.queue_free();await process_frame;quit(1);return
 check(is_equal_approx(model.reach_scale(),1),'Unbound model retains exact native1x reach')
 var caster=ReachHero.new();root.add_child(caster)
 var combat=load('res://scripts/recovered_sasuke_combat.gd').new();combat.hero=caster
 var time=.1
 var baseline:Array=model.weapon_segments(0x68,time)
 var original:Dictionary=model.sampler.sample_source(0x68,time)
 caster.requested_reach=2.0;caster.powerups['range']=3.0;model.combat=combat
 check(is_equal_approx(model.reach_scale(),combat.reach_scale()),'Lightweight controller fallback keeps visible and contact reach paired')
 var arena=ReachGame.new();root.add_child(arena);combat.game=arena
 check(is_equal_approx(model.reach_scale(),3),'Melee setting and live range pickup combine once')
 model.apply_native_pose(0x68,time)
 var extended:Array=model.weapon_segments(0x68,time)
 var handles=true;var length=true;var visible=true
 for i in 2:
  handles=handles and baseline[i].base.distance_to(extended[i].base)<.00001
  length=length and absf(extended[i].base.distance_to(extended[i].tip)/baseline[i].base.distance_to(baseline[i].tip)-3)<.00001
  var part:Node3D=model.native_parts[extended[i].pointer]
  var actual=model.rig_visual.transform*(part.transform*Vector3(0,-44,0))
  visible=visible and actual.distance_to(extended[i].tip)<.00001
 check(handles,'Extended kunai keep both source handle attachments fixed')
 check(length,'Visible kunai endpoints receive the combined3x range')
 check(visible,'Endpoint sweeps match the rendered blade tip exactly')
 var untouched=true
 for pointer in ['0x9004aa8','0x90053d0','0x9005c10']:
  var native:Transform3D=original[pointer]
  var expected=Transform3D(native.basis.scaled(Vector3.ONE*model.source_scale),native.origin*model.source_scale+model.source_offset)
  untouched=untouched and close_(model.native_parts[pointer].transform,expected)
 check(untouched,'Weapon range leaves head and body proportions unchanged')
 var hair_exact=true
 for action in [0x6f,0x9a]:
  var raw:Dictionary=model.sampler.sample_source(action,.2);var head:Vector3=raw['0x90063d8'].origin
  model.apply_native_pose(action,.2)
  var shaft_origin:Vector3=model.native_parts['0x90063d8'].position
  check(shaft_origin.distance_to(head*model.source_scale+model.source_offset)<.00001,'Hair shaft stays attached at its original head surface root')
  for pointer in ['0x9004918','0x90063d8']:
   var native:Transform3D=raw[pointer];var point=native*Vector3(0,5,0)
   var expected=model.rig_visual.transform*((head+(point-head)*3)*model.source_scale+model.source_offset)
   var actual=model.rig_visual.transform*(model.native_parts[pointer].transform*Vector3(0,5,0))
   hair_exact=hair_exact and actual.distance_to(expected)<.00005
 check(hair_exact,'Both native hair moves extend tuft and shaft around the unchanged native hair attachment')
 caster.requested_reach=1;caster.powerups['range']=0
 var exact=true
 for action in [0x68,0x69,0x6a,0x6e,0x6f,0x9a]:
  var raw:Dictionary=model.sampler.sample_source(action,.1);var scaled:Dictionary=model.scaled_source_pose(action,.1)
  for pointer in raw:exact=exact and close_(raw[pointer],scaled[pointer])
 check(exact,'Returning to1x preserves every source matrix without drift')
 model.combat=null;combat.free();caster.queue_free();arena.queue_free();model.queue_free();await process_frame
 print('SASUKE_REACH_RESULT failures=',failures);quit(1 if failures else 0)
