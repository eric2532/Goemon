extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
class Visibility extends RefCounted:
 func visible_at(point:Vector3)->bool:return point.x>=-10
class Arena extends Node3D:
 var model=Visibility.new()
 var actors={}
 var settings={}
 var paused=false
 var transitioning=false
 func forest_point_visible(point:Vector3)->bool:return model.visible_at(point)
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,note:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",note)
func run():
 var arena=Arena.new();root.add_child(arena)
 var camera=Camera3D.new();arena.add_child(camera);camera.position=Vector3(0,6,16);camera.look_at(Vector3(0,2,0));camera.make_current()
 var fx=load("res://scripts/forest/crowd/army_presentation.gd").new();arena.add_child(fx);fx.configure(arena)
 var baseline:int=fx.get_child_count()
 fx.present([
  {"kind":"damage","position":Vector3(-3,1,0),"amount":37},
  {"kind":"damage","position":Vector3(0,1,0),"amount":80,"heavy":true},
  {"kind":"damage","position":Vector3(3,1,0),"amount":160,"heavy":true,"critical":true}])
 check(fx.counts().labels==3,"Normal, heavy and critical events reach the reusable pool")
 check(fx.labels[0].text=="37" and fx.labels[0].font_size==36,"Normal hits show the recovered digits")
 check(fx.labels[1].text=="80" and fx.labels[1].font_size==48,"Heavy hits show larger digits")
 check(fx.labels[2].text=="160" and fx.labels[2].font_size==52,"Critical digits take precedence over heavy sizing")
 check(fx.labels.all(func(label):return label.font==fx.DAMAGE_FONT and label.no_depth_test and label.fixed_size and label.outline_size==0 and is_equal_approx(label.pixel_size,.00065) and label.billboard==BaseMaterial3D.BILLBOARD_ENABLED),"The shared bitmap font supplies its own outline and stays readable across camera zoom")
 check(fx.DAMAGE_FONT.get_supported_chars()=="0123456789","The imported bitmap font contains all ten source digits")
 check(fx.effects.filter(func(effect):return effect.kind=="critical").size()==1,"Only the critical hit adds a burst over the ordinary contacts")
 check(fx.labels[0].position.is_equal_approx(Vector3(-3,2.6,0)),"Native hit feedback floats above the target instead of inside its body")
 fx.tick(0)
 var burst:MultiMesh=fx.batches.critical.multimesh
 check(burst.visible_instance_count==1,"The batch submits one critical burst")
 var rendered=DisplayServer.get_name()!="headless"
 if rendered:check(is_equal_approx(burst.get_instance_transform(0).basis.x.length(),2.8),"The submitted critical quad uses the enlarged shared size")
 if rendered:check(burst.get_instance_custom_data(0).r==0,"The batch starts on the first recovered frame")
 fx.tick(.1)
 if rendered:check(burst.get_instance_custom_data(0).r==1 and is_equal_approx(burst.get_instance_custom_data(0).g,.85),"The burst keeps source cadence with stronger critical opacity")
 check(is_equal_approx(fx.labels[0].position.y,2.6+.1*1.4/.65),"Pooled labels regain the original upward travel speed")
 arena.paused=true;var held:Vector3=fx.labels[0].position;fx.tick(.5)
 check(fx.labels[0].position==held and fx.counts().labels==3,"Pause preserves live labels and their lifetime")
 arena.paused=false;fx.tick(.6)
 check(burst.visible_instance_count==0,"Expired critical bursts release their batch slots")
 check(fx.counts().labels==0 and fx.labels.all(func(label):return not label.visible),"Expired labels hide without freeing their nodes")
 fx.clear()
 for i in 1000:
  fx.label_damage(Vector3(-20,1,0),10)
  fx.label_damage(Vector3(0,1,40),10)
  fx.label_damage(Vector3(100,1,0),10)
  fx.critical_burst(Vector3(-20,1,0))
  fx.critical_burst(Vector3(0,1,40))
 check(fx.counts().labels==0,"Fog-hidden, behind-camera and offscreen hits consume no popup slots")
 check(fx.effects.is_empty(),"Fog-hidden and behind-camera criticals consume no burst slots")
 var allocations={"labels":0}
 fx.child_entered_tree.connect(func(node):
  if node is Label3D:allocations.labels+=1)
 seed(73415);var expected=randf();seed(73415)
 for i in 4000:fx.label_damage(Vector3(0,1,0),i,i%2==0,i%3==0)
 check(randf()==expected,"Popup admission and styling never advance combat RNG")
 check(fx.counts().labels==32 and fx.labels.size()==32 and fx.get_child_count()==baseline and allocations.labels==0,"A 4000-hit burst keeps exactly 32 preallocated labels and allocates no nodes")
 arena.settings.reduced_flashes=true
 for i in 4000:fx.critical_burst(Vector3(0,1,0))
 fx.tick(.21)
 check(burst.visible_instance_count==fx.MAX_EFFECTS and burst.instance_count==fx.MAX_EFFECTS and fx.get_child_count()==baseline,"Repeated simultaneous criticals stay within the preallocated batch")
 if rendered:check(burst.get_instance_custom_data(0).r==3 and is_equal_approx(burst.get_instance_custom_data(0).g,.35*.85),"Reduced Flashes dims the stronger burst and preserves the last frame")
 var retained=fx.labels.duplicate();fx.tick(.7);fx.label_damage(Vector3(0,1,0),8)
 check(fx.labels==retained and fx.labels[0].text=="8" and fx.labels[0].font_size==36 and fx.labels[0].modulate==Color.WHITE,"Reused critical slots reset to ordinary styling and full opacity")
 fx.clear();check(fx.counts().labels==0,"World reset clears every active popup")
 fx.add_effect("kazi_combo",Vector3.ZERO,.5,1.0);fx.tick(.1)
 if rendered:check(is_equal_approx(fx.batches.kazi_combo.multimesh.get_instance_custom_data(0).g,.35*128.0/255),"Critical emphasis leaves combo opacity unchanged under Reduced Flashes")
 arena.free()
 verify_native_criticals()
 print("ARMY_POOLED_DAMAGE_NUMBERS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
func verify_native_criticals():
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 var data:Dictionary=load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model)
 data.ninja[11]=0 # Disable executions so damage comparisons cannot depend on remaining HP.
 var runtime=Runtime.new();runtime.configure(null)
 for compact in [false,true]:
  var target:int=runtime.spawn(1,0,0,Vector3.ZERO,1000,.4)
  runtime.apply_hit(target,{"amount":10,"heavy":true,"critical":true})
  var events:Array=runtime.native.take_scene_events() if compact else runtime.take_events()
  check(events.size()==1 and events[0].critical and events[0].heavy and events[0].amount==10,"Explicit critical flags survive the native %s event transfer without changing damage"%("compact" if compact else "full"))
  runtime.clear()
 for kind in [11,5,8,10,7]:
  var traces=[]
  for chance in [0,100]:
   runtime.clear();runtime.navigation_revision=-1;runtime.set_navigation(1,{"width":0})
   data.ally_profiles[data.ally_kinds.find(kind)*5+4]=chance;runtime.configure_kits(data)
   var target:int=runtime.spawn(1,0,0,Vector3.ZERO,10000000,1.3)
   runtime.apply_hit(target,{"element":"ice","status_seconds":100});runtime.take_events()
   runtime.spawn(-1,1,kind,Vector3(0,0,20 if kind==10 else (12 if kind in [5,8] else 4)),500,.4)
   var hits=[]
   for frame in 360:
    runtime.step(1.0/60,{})
    for event in runtime.native.take_scene_events():
     if event.kind=="damage" and event.team==0:hits.append(event)
   check(not hits.is_empty() and hits.all(func(event):return event.critical==(chance==100)),"Kind %d publishes its actual %d%% critical rolls through compact events"%[kind,chance])
   traces.append(hits.map(func(event):return [event.amount,event.heavy,event.projectile]))
  check(traces[1]==traces[0].map(func(hit):return [hit[0]*2,hit[1],hit[2]]),"Kind %d retains the same contacts, heavy/projectile flags and exactly doubled critical damage"%kind)
 runtime.free()
