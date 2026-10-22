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
 var model=load('res://scripts/recovered_yae_model.gd').new();root.add_child(model);await process_frame;model.set_process(false)
 check(model.has_method('reach_scale') and model.has_method('scaled_source_pose'),'Model applies reach settings to native rendered poses')
 if failures:model.queue_free();await process_frame;quit(1);return
 check(is_equal_approx(model.reach_scale(),1),'Unbound model retains exact native1x reach')
 var caster=ReachHero.new();root.add_child(caster)
 var combat=load('res://scripts/recovered_yae_combat.gd').new();combat.hero=caster
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
 for i in 1:
  var native:Transform3D=original['0x90026e8']
  var anchor:Vector3=model.rig_visual.transform*((native*Vector3(0,15,0))*model.source_scale+model.source_offset)
  var rendered:Node3D=model.native_parts['0x90026e8']
  handles=handles and anchor.distance_to(model.rig_visual.transform*(rendered.transform*Vector3(0,15,0)))<.00001
  length=length and absf(extended[i].base.distance_to(extended[i].tip)/baseline[i].base.distance_to(baseline[i].tip)-3)<.00001
  var part:Node3D=model.native_parts[extended[i].pointer]
  var actual=model.rig_visual.transform*(part.transform*Vector3(0,91,-4))
  visible=visible and actual.distance_to(extended[i].tip)<.00001
 check(handles,'Extended katana keeps the original source handle grip fixed')
 check(length,'Visible katana endpoints receive the combined3x range')
 check(visible,'Endpoint sweeps match the rendered blade tip exactly')
 var untouched=true
 for pointer in ['0x9004a88','0x9005748','0x9005f80']:
  var native:Transform3D=original[pointer]
  var expected=Transform3D(native.basis.scaled(Vector3.ONE*model.source_scale),native.origin*model.source_scale+model.source_offset)
  untouched=untouched and close_(model.native_parts[pointer].transform,expected)
 check(untouched,'Weapon range leaves head and body proportions unchanged')
 caster.requested_reach=1;caster.powerups['range']=0
 var exact=true
 for action in [0x68,0x69,0x6a,0x6e,0x6f,0x9d]:
  var raw:Dictionary=model.sampler.sample_source(action,.1);var scaled:Dictionary=model.scaled_source_pose(action,.1)
  for pointer in raw:exact=exact and close_(raw[pointer],scaled[pointer])
 check(exact,'Returning to1x preserves every source matrix without drift')
 combat.mode='primary';combat.action_id=0x69;combat.elapsed=.2
 model.locomotion.dirty=true;model.locomotion.evaluate()
 check(model.source_action==0x69 and absf(model.source_time-.2)<.00001,'Actual combat Node owns the rendered action clock')
 caster.model=model
 check(absf(combat.melee_reach()-5.0767410917)<.0001,'AI reach comes from the full native gold sphere envelope rather than a guessed blade length')
 var source:Dictionary=load('res://scripts/recovered_yae_combat_profile.gd').data().collision_spheres['104']
 combat.action_id=0x68;combat.elapsed=0
 var one:Array=combat._source_spheres(source,0,Transform3D.IDENTITY)
 caster.requested_reach=2;caster.powerups['range']=3
 var three:Array=combat._source_spheres(source,0,Transform3D.IDENTITY)
 var source_pose:Dictionary=model.sampler.sample_source(0x68,0)
 var grip:Vector3=source_pose['0x9007478']*Vector3(0,15,0)
 var native_center=Vector3(27.5,70.125,.375)
 var expected:Vector3=model.rig_visual.transform*((grip+(native_center-grip)*3)*model.source_scale+model.source_offset)
 check(three[0].center.distance_to(expected)<.00001 and absf(three[0].radius/one[0].radius-3)<.00001,'Four native contact spheres extend about the same fixed grip as the visible katana')
 check(combat.melee_reach()>8,'AI approach distance follows the enlarged native contact envelope')
 model.combat=null;combat.free();caster.queue_free();arena.queue_free();model.queue_free();await process_frame
 print('YAE_REACH_RESULT failures=',failures);quit(1 if failures else 0)
