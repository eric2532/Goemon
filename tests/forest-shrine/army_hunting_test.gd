extends SceneTree
var checks=0
var failures=0
func check(ok,label_):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var army=load("res://scripts/forest/crowd/army_runtime.gd").new();army.configure(null);army.set_navigation(1,{"width":0})
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42);army.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model))
 var explorer:int=army.spawn(-10,1,11,Vector3(-60,0,60),200,.4);army.native.set_guard(explorer,Vector3(-60,0,60),18)
 var foe:int=army.spawn(10,0,0,Vector3(0,0,60),100000,3.9);army.apply_hit(foe,{"element":"ice","status_seconds":100})
 for i in 120:army.step(1.0/60,{})
 check(army.unit_state(explorer).target_id==10,"A managed native ally acquires enemies beyond the old post and48m limits")
 check(army.unit_state(explorer).position.x>-42,"A native ally pursues beyond its old placement circle")
 army.despawn(foe);army.spawn(11,0,0,Vector3(40,0,60),100000,3.9);army.step(.25,{})
 check(army.unit_state(explorer).target_id==11,"A defeated distant target is replaced by another live enemy")
 army.clear()
 for kind in [0,1,3]:
  var enemy:int=army.spawn(1,0,kind,Vector3(0,0,40),100000,3.9)
  var ally:int=army.spawn(-10,1,11,Vector3(0,0,0),200,.4);army.apply_hit(ally,{"element":"ice","status_seconds":100})
  var rows={"ids":PackedInt64Array([0,100]),"kinds":PackedInt32Array([0,2]),"positions":PackedVector3Array([Vector3(0,0,41),Vector3(100,0,100)]),"hp":PackedFloat32Array([100,10000]),"minimum":PackedVector3Array([Vector3.ZERO,Vector3(96,0,96)]),"maximum":PackedVector3Array([Vector3.ZERO,Vector3(104,6,104)])}
  army.step(.01,{"targets":rows})
  check(army.unit_state(enemy).target_id==-10,"Soldier%d pursues the closest objective beyond its old aggro range"%kind)
  army.set_pose(ally,Vector3(100,0,100),0);rows.positions[1]=Vector3(0,0,35);rows.minimum[1]=Vector3(-3,0,32);rows.maximum[1]=Vector3(3,6,38);army.step(.12,{"targets":rows})
  var state=army.unit_state(enemy)
  check(state.get("external_target",-1)==100 and state.get("external_kind",-1)==2,"Soldier%d compares actual building edges ahead of distant helpers"%kind)
  army.apply_hit(enemy,{"amount":1,"source_id":0});army.step(.6,{"targets":rows})
  check(army.unit_state(enemy).get("external_kind",-1)==0,"A player's hit still provokes real native retaliation")
  army.clear()
 army.free()
 print("ARMY_HUNTING_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
