extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Kits=preload("res://scripts/forest/crowd/army_kit_data.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 var data:Dictionary=Kits.from_model(model)
 if not data.get("ally_kinds",PackedInt32Array()).has(5):check(false,"Native Ninja Shadow Cut and autonomous kit are missing");finish();return
 data.ally_profiles[9]=0.0
 var r=Runtime.new();r.configure(null);r.set_navigation(1,{"width":0});r.configure_kits(data)
 var invalid=data.duplicate(true);invalid.ninja=PackedFloat64Array()
 check(not r.native.configure_kits(invalid),"An enabled Ninja kit requires complete special-action tuning")
 invalid=data.duplicate(true);invalid.ninja[0]=0.0
 check(not r.native.configure_kits(invalid),"A zero-duration Shadow Cut is rejected before simulation")
 r.configure_kits(data)
 var target:int=r.spawn(1,0,0,Vector3.ZERO,10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0})
 var ninja:int=r.spawn(-1,1,5,Vector3(0,0,12),100,.4)
 var events=[]
 for frame in 12:r.step(1.0/60,{});events.append_array(r.take_events())
 var hits=events.filter(func(e):return e.kind=="damage" and e.source_id==-1)
 check(hits.size()==2,"Shadow Cut delivers one swept travel hit and one separate endpoint cut")
 check(hits.all(func(e):return is_equal_approx(e.amount,76.0) or is_equal_approx(e.amount,152.0)),"Both cuts retain the same snapshotted source damage and crit rules")
 check(absf(r.unit_state(ninja).position.z-.66)<.001,"Eased source dash covers exactly81 times0.14 metres")
 check(r.unit_state(ninja).action!=Kits.ACTION.shadow_cut,"Ninja completes the dash once and leaves its travel action")
 r.clear();target=r.spawn(2,0,0,Vector3.ZERO,1000000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});ninja=r.spawn(-2,1,5,Vector3(0,0,30),100,.4)
 events=[]
 for frame in 90:r.step(1.0/60,{});events.append_array(r.take_events())
 check(events.filter(func(e):return e.kind=="bullet" and e.source_id==-2).size()>=5,"Ninja uses its original five-star utility while closing a ranged gap")
 check(r.unit_state(ninja).buff_left>0,"Ninja activates its original Anbu buff independently")
 await source_dash(r,data)
 # Two independently live victims each receive exactly the two authored cuts.
 r.clear()
 for id in [1,2,3]:
  var h:int=r.spawn(id,0,0,Vector3(10 if id==3 else 0,0,-3 if id==2 else 0),10000,3.9);r.apply_hit(h,{"element":"ice","status_seconds":100.0})
 ninja=r.spawn(-8,1,5,Vector3(0,0,12),100,.4);events=[]
 for frame in 12:r.step(1.0/60,{});events.append_array(r.take_events())
 print("NINJA_MULTI_VICTIMS ",events.filter(func(e):return e.kind=="damage").map(func(e):return [e.source_id,e.target_id,e.amount]))
 for id in [1,2]:check(events.filter(func(e):return e.kind=="damage" and e.source_id==-8 and e.target_id==id).size()==2,"Swept Shadow Cut preserves two independent contacts for victim%d"%id)
 check(not events.any(func(e):return e.kind=="damage" and e.target_id==3),"A soldier outside the swept width is not damaged")
 # Freeze preserves a committed dash; despawn removes its future contacts.
 r.clear();target=r.spawn(3,0,0,Vector3.ZERO,10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});ninja=r.spawn(-3,1,5,Vector3(0,0,12),100,.4)
 r.step(.05,{});r.take_events();var held:Vector3=r.unit_state(ninja).position
 check(not r.apply_hit(ninja,{"amount":1000.0,"source_id":3}).accepted,"Ninja retains the original dash invulnerability")
 r.apply_hit(ninja,{"element":"ice","status_seconds":.5});r.step(.4,{})
 check(r.unit_state(ninja).position==held and not r.take_events().any(func(e):return e.source_id==-3),"Freeze stops the dash body and contacts together")
 r.step(.3,{})
 check(r.take_events().filter(func(e):return e.kind=="damage" and e.source_id==-3).size()==2,"Thaw resumes the committed dash with two original contacts")
 r.clear();target=r.spawn(4,0,0,Vector3.ZERO,10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});ninja=r.spawn(-4,1,5,Vector3(0,0,12),100,.4)
 r.step(.05,{});r.take_events();r.despawn(ninja);r.step(.5,{})
 check(not r.take_events().any(func(e):return e.source_id==-4),"A Ninja removed during its dash cannot damage later victims or restart")
 r.clear();target=r.spawn(6,0,0,Vector3.ZERO,10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});ninja=r.spawn(-6,1,5,Vector3(0,0,12),100,.4)
 r.step(.05,{});r.take_events();r.apply_hit(ninja,{"knockback":Vector3.RIGHT,"flinch":.5})
 check(r.unit_state(ninja).action!=Kits.ACTION.shadow_cut,"An explicit action interruption clears the old Shadow Cut state immediately")
 # Exercise source execute/resistant behavior without probabilistic test flakiness.
 data.ninja[11]=1.0;r.configure_kits(data)
 for kind in [0,4]:
  r.clear();target=r.spawn(10+kind,0,kind,Vector3.ZERO,100000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});ninja=r.spawn(-10,1,5,Vector3(0,0,12),100,.4)
  events=[]
  for frame in 120:r.step(1.0/60,{});events.append_array(r.take_events())
  check(r.valid(target)==(kind==4),"Anbu executes ordinary enemies and retains resistant-target health (kind%d)"%kind)
 data.ninja[11]=0.0;r.configure_kits(data)
 r.clear();r.navigation_revision=-1;r.set_navigation(10,{"width":0,"layer_min":PackedVector3Array([Vector3(-6,5,-20)]),"layer_max":PackedVector3Array([Vector3(6,5,20)])})
 target=r.spawn(30,0,0,Vector3(0,5,0),10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});ninja=r.spawn(-30,1,5,Vector3(0,5,12),100,.4)
 for frame in 12:r.step(1.0/60,{})
 check(absf(r.unit_state(ninja).position.y-5)<.001,"Shadow Cut stays on the original raised bridge support")
 r.clear();r.navigation_revision=-1;r.set_navigation(11,{"width":0})
 target=r.spawn(40,0,0,Vector3.ZERO,100000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});ninja=r.spawn(-40,1,5,Vector3(0,0,12),100,.4)
 r.step(3.1,{});r.set_pose(target,Vector3(0,0,-12),0);var reused=false
 for frame in 60:r.step(1.0/60,{});reused=reused or r.unit_state(ninja).action==Kits.ACTION.shadow_cut
 check(reused,"Ninja reuses Shadow Cut after the original cooldown when its target moves out")
 r.clear();target=r.spawn(50,0,0,Vector3.ZERO,100000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});ninja=r.spawn(-50,1,5,Vector3(0,0,12),100,.4)
 var first_contact=false
 for frame in 90:
  r.step(1.0/60,{})
  if r.take_events().any(func(e):return e.kind=="melee" and e.source_id==-50):first_contact=true;break
 var before_drift:Vector3=r.unit_state(ninja).position;r.step(.16,{})
 check(first_contact and r.unit_state(ninja).position.distance_to(before_drift)>.01,"An accepted Ninja slash releases its original small movement impulse after planting")
 r.clear();r.navigation_revision=-1;r.set_navigation(20,{"width":0,"obstacle_min":PackedVector3Array([Vector3(-.3,0,6)]),"obstacle_max":PackedVector3Array([Vector3(.3,8,7)])})
 target=r.spawn(60,0,0,Vector3.ZERO,100000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});ninja=r.spawn(-60,1,5,Vector3(0,0,12),100,.4)
 r.step(.15,{})
 check(absf(r.unit_state(ninja).position.x)<.001 and r.unit_state(ninja).position.z>=7.399,"A committed Shadow Cut stops at a wall rather than pathfinding sideways")
 r.clear();r.navigation_revision=-1;r.set_navigation(21,{"width":0})
 # Released stars belong to their cast even after the caster retires.
 r.clear();target=r.spawn(70,0,0,Vector3.ZERO,100000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});r.spawn(-70,1,5,Vector3(0,0,12),100,.4);events=[]
 for frame in 120:r.step(1.0/60,{});events.append_array(r.take_events())
 var primaries=events.filter(func(e):return e.kind=="melee" and e.source_id==-70)
 check(primaries.size()>=3 and primaries.slice(0,3).map(func(e):return e.action_index)==[0,1,2],"Ninja repeats the original three primary actions after its opening")
 if primaries.size()>=3:check(primaries.slice(0,3).map(func(e):return e.amount)==[18.0,18.0,26.0],"Ninja primary raw damage remains the source18,18,26 combo")
 var baseline=stars_after_retire(r,false);var with_new=stars_after_retire(r,true)
 check(baseline>0 and is_equal_approx(baseline,with_new),"Another summon cannot cancel a retired Ninja's independent released stars")
 r.clear();r.free();finish()
func stars_after_retire(r,add_new:bool)->float:
 r.clear();var target:int=r.spawn(99,0,0,Vector3.ZERO,100000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});var ninja:int=r.spawn(-99,1,5,Vector3(0,0,30),100,.4)
 r.step(.5,{});r.take_events();r.despawn(ninja)
 if add_new:r.spawn(-100,1,5,Vector3(200,0,200),100,.4)
 var amount=0.0
 for frame in 120:
  r.step(1.0/60,{})
  for event in r.take_events():
   if event.kind=="damage" and event.source_id==-99:amount+=event.amount
 return amount
func source_dash(r,data):
 var f=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(f);var game=await f.make_game("original")
 f.clear_targets();var target=f.add_target(Vector3(0,0,52));var row=game.model.enemies[target.forest_id];row.hp=10000;row.max_hp=10000;target.hp=10000;target.max_hp=10000
 game.character_tuning["ninja"]={"critical_chance":0.0}
 var unit=game.explorer_helpers.pool.filter(func(u):return u.kit_id==5)[0]
 unit.summon(target,Vector3(0,.12,64),0);unit.set_physics_process(false);unit.think_left=0
 var clock={"frame":0};target.trace_clock=clock
 f.active_tick=func(dt):unit._physics_process(dt);clock.frame+=1
 await f.advance(.2);f.active_tick=Callable();var original=target.hits
 r.clear();r.configure_kits(data);var enemy:int=r.spawn(1,0,0,Vector3(0,0,52),10000,3.9);r.apply_hit(enemy,{"element":"ice","status_seconds":100.0});r.spawn(-1,1,5,Vector3(0,.12,64),100,.4)
 var native=[]
 for frame in 12:
  r.step(1.0/60,{})
  for e in r.take_events():
   if e.kind=="damage" and e.source_id==-1:native.append([frame,e.amount])
 check(original.size()==2 and native.size()==2,"Source and native Ninja both make the two real Shadow Cut contacts")
 if original.size()==2 and native.size()==2:
  print("NINJA_SOURCE_TIMING original=",original," native=",native)
  check(range(2).all(func(i):return original[i][0]==native[i][0] and is_equal_approx(original[i][2],native[i][1])),"Native dash hit frames and damage match the unchanged original controller")
 await f.close();f.queue_free();await process_frame
func finish():print("ARMY_NINJA_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
