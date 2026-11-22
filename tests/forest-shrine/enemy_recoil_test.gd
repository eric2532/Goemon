extends SceneTree
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Visual=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
var runtime
var checks=0
var failures=0
var traces=[]
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func fresh(kind:int,hp:float=10000)->int:
 runtime.clear();return runtime.spawn(1,0,kind,Vector3.ZERO,hp,Roles.footprint_radius(kind))
func reference_push(heavy:bool,steps:int)->float:
 var speed=3.0 if heavy else 1.2;var distance=0.0
 for i in steps:
  if speed>.1:distance+=speed/60;speed*=exp(-8.0/60)
 return distance
func run():
 runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null);runtime.set_navigation(1,{"width":0})
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 runtime.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model))
 for kind in Roles.RIGID_TYPES:
  for heavy in [false,true]:
   var handle=fresh(kind);var hit=runtime.apply_hit(handle,{"amount":22.0,"direction":Vector3.RIGHT,"heavy":heavy,"responsive_recoil":true})
   var instant:Dictionary=runtime.unit_state(handle);var resource:Resource=Visual.data(kind)
   var hurt:String=Roles.Dark.HURT_CLIP if kind==Roles.DARK_LUMINA_2 else resource.get_meta("semantics").hurt[0];var row:int=resource.get_meta("clips")[hurt].rows[0]
   check(hit.accepted and instant.hp==9978,"Kind %d damage remains synchronous"%kind)
   check(instant.action==6 and instant.pose_row==row,"Kind %d cancels into its actual hurt pose at contact"%kind)
   check(is_equal_approx(instant.stun,16.0/30),"Kind %d retains the soldier stagger window"%kind)
   var first=0.0;var early=0.0;var half_time=0.0
   for step in 60:
    runtime.step(1.0/60,{})
    var state:Dictionary=runtime.unit_state(handle)
    if step==0:first=state.position.x
    if step==5:early=state.position.x
    if half_time==0 and state.position.x>=reference_push(heavy,60)*.5:half_time=(step+1)/60.0
   var distance:float=runtime.unit_state(handle).position.x
   check(first>reference_push(heavy,1)*1.4,"Kind %d starts its terrain-driven knockback faster"%kind)
   check(early>reference_push(heavy,6)*1.2,"Kind %d delivers more recoil in the first 100ms"%kind)
   check(absf(distance/reference_push(heavy,60)-1)<.1,"Kind %d preserves approximately the old total push"%kind)
   traces.append({"kind":kind,"heavy":heavy,"first_step_m":first,"first_100ms_m":early,"half_push_seconds":half_time,"total_m":distance,"old_total_m":reference_push(heavy,60)})
  var frozen=fresh(kind);runtime.apply_hit(frozen,{"element":"ice","status_seconds":1.0})
  var held:Dictionary=runtime.unit_state(frozen);runtime.apply_hit(frozen,{"amount":1.0,"direction":Vector3.RIGHT,"heavy":true,"responsive_recoil":true});runtime.step(.2,{})
  var hurt_clip:String=Roles.Dark.HURT_CLIP if kind==Roles.DARK_LUMINA_2 else Visual.data(kind).get_meta("semantics").hurt[0]
  var hurt_rows:PackedInt32Array=Visual.data(kind).get_meta("clips")[hurt_clip].rows
  check(runtime.unit_state(frozen).position==held.position and runtime.unit_state(frozen).pose_row in hurt_rows,"Kind %d keeps frozen contact, plays its own get-hit reaction and queues its push"%kind)
  runtime.step(.9,{})
  check(runtime.unit_state(frozen).position.x>0 and runtime.unit_state(frozen).action==6,"Kind %d recoils after thaw without losing its hit"%kind)
 var ordinary=fresh(0);runtime.apply_hit(ordinary,{"amount":1.0,"direction":Vector3.RIGHT})
 for i in 6:runtime.step(1.0/60,{})
 check(absf(runtime.unit_state(ordinary).position.x-reference_push(false,6))<.0001,"Unmarked hits retain other characters' original knockback spacing")
 var custom=fresh(0);runtime.apply_hit(custom,{"amount":1.0,"direction":Vector3.RIGHT,"responsive_recoil":true})
 runtime.apply_hit(custom,{"knockback":Vector3(7,0,0),"flinch":.2});runtime.step(1.0/60,{});runtime.step(1.0/60,{})
 check(absf(runtime.unit_state(custom).position.x-7.0/60*(1+exp(-8.0/60)))<.0001,"Explicit skill impulses retain their existing travel and decay")
 var split=fresh(Roles.VAMBEE,1);runtime.apply_hit(split,{"amount":22.0,"direction":Vector3.RIGHT,"responsive_recoil":true})
 var form:Dictionary=runtime.unit_state(split);var torso:Resource=Visual.data(Roles.VAMBEE_TORSO)
 check(form.kind==Roles.VAMBEE_TORSO and form.action==6 and form.pose_row==torso.get_meta("clips")[torso.get_meta("semantics").hurt[0]].rows[0],"A split immediately uses the torso's own hurt pose in the same handle")
 var field={"width":33,"spacing":3.0,"origin":Vector3(-48,0,-48),"heights":PackedFloat32Array(),"covered":PackedByteArray(),"obstacle_min":PackedVector3Array([Vector3(1.6,0,-12)]),"obstacle_max":PackedVector3Array([Vector3(3,8,12)])}
 field.heights.resize(33*33);field.covered.resize(33*33);field.covered.fill(1);runtime.set_navigation(2,field)
 for kind in Roles.RIGID_TYPES:
  var radius=Roles.footprint_radius(kind)
  field.obstacle_min=PackedVector3Array([Vector3(radius+.3,0,-12)]);field.obstacle_max=PackedVector3Array([Vector3(radius+1.7,8,12)])
  runtime.set_navigation(100+kind,field)
  var h=fresh(kind);runtime.apply_hit(h,{"amount":22.0,"direction":Vector3.RIGHT,"heavy":true,"responsive_recoil":true})
  for i in 60:runtime.step(1.0/60,{})
  check(runtime.unit_state(h).position.x<=.301,"Kind %d faster recoil cannot pass through a wall from a clear starting position"%kind)
 print("ENEMY_RECOIL_TRACES ",JSON.stringify(traces))
 runtime.free();print("ENEMY_RECOIL_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
