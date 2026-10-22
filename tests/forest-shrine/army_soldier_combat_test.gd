extends SceneTree
const Source=preload("res://scripts/forest/forest_thirstquencher_combat.gd")
const Visual=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
var checks=0
var failures=0
var runtime
var model
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func source_trace(kind:int,deltas:Array)->Array:
 var state={"variant":kind};Source.begin(state);var result=[];var step=0
 while Source.active(state) and step<2000:
  for event in Source.advance(state,deltas[step%deltas.size()]):result.append([event.kind,snappedf(event.source_tick,.0001)])
  step+=1
 return result
func setup(kind:int):
 runtime.clear();runtime.set_navigation(kind+10,{"width":0,"origin":Vector3(-240,0,-240)})
 var enemy:int=runtime.spawn(1,0,kind,Vector3.ZERO,model.waves.role_stats(kind).hp,.4)
 var target:int=runtime.spawn(-1,1,12,Vector3(0,0,-4),500,.4)
 return [enemy,target]
func run():
 runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 if not runtime.has_method("configure_kits") or not runtime.has_method("apply_hit") or not runtime.has_method("take_events"):
  check(false,"Native soldier actions, damage and event ownership are missing");runtime.free();finish();return
 model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 runtime.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(model))
 var literals={0:[["melee",13.0],["melee",44.0],["done",54.0]],1:[["muzzle",15.0],["bullet",18.0],["muzzle",45.0],["bullet",48.0],["muzzle",75.0],["bullet",78.0],["done",120.0]],3:[["melee",13.0],["done",20.0]]}
 for kind in [0,1,3]:
  for deltas in [[1.0/60],[1.0/30],[.01,.04,.025,.015]]:
   var expected=source_trace(kind,deltas)
   check(expected==literals[kind],"Original source soldier %d markers match independently checked ROM ticks"%kind)
   var handles=setup(kind);var trace=[];var damages=[];var step=0;var done=false
   while not done and step<600:
    runtime.step(deltas[step%deltas.size()],{})
    for event in runtime.take_events():
     if event.source_id==1 and event.kind in ["melee","muzzle","bullet","done"]:
      trace.append([event.kind,snappedf(event.source_tick,.0001)])
      if event.kind=="done":done=true
      if event.kind in ["muzzle","bullet"]:check(event.position.distance_to(Vector3(0,4.32,-2.592))<.0001,"Gunner uses the recovered source muzzle at enlarged soldier scale")
     if event.kind=="damage" and event.target_id==-1:damages.append(event.amount)
    step+=1
   if not (done and trace==expected):print("SOLDIER_MARKER_MISMATCH kind=",kind," deltas=",deltas," actual=",trace," expected=",expected)
   check(done and trace==expected,"Native soldier %d preserves all source event markers across variable deltas"%kind)
   var amount=(25.0 if kind==1 else 11.0)*model.balance.enemy_damage_mult
   check(damages.size()==(3 if kind==1 else (2 if kind==0 else 1)) and damages.all(func(v):return is_equal_approx(v,amount)),"Every landed soldier strike/projectile damages its actual victim once")
 var handles=setup(0)
 runtime.step(.2,{});runtime.take_events()
 runtime.apply_hit(handles[0],{"amount":0.0,"element":"ice","status_seconds":1.0,"source_id":-1})
 runtime.step(.99,{})
 check(not runtime.take_events().any(func(e):return e.kind=="melee"),"Freeze suspends the live attack clock without replaying a contact")
 runtime.step(.4,{})
 check(runtime.take_events().filter(func(e):return e.kind=="melee").size()==1,"The suspended attack resumes with exactly one original contact")
 handles=setup(3)
 var hit=runtime.apply_hit(handles[0],{"amount":100000.0,"source_id":-1})
 check(hit.accepted and hit.dead and not runtime.valid(handles[0]),"Damage kills and invalidates the victim immediately")
 var replacement:int=runtime.spawn(2,0,3,Vector3.ZERO,100,.4)
 check(not runtime.apply_hit(handles[0],{"amount":50.0,"source_id":-1}).accepted,"A stale damage command cannot hit a recycled live slot")
 var snapshot=runtime.snapshot()
 check(snapshot.hp[snapshot.handles.find(replacement)]==100,"The replacement unit retains its independent health")
 check(runtime.take_events().filter(func(e):return e.kind=="death" and e.target_id==1).size()==1,"Death and reward ownership are emitted once even after a stale follow-up hit")
 # Projectiles retain external ownership, and cover is checked in true 3D.
 for height in [0.0,8.0]:
  runtime.clear();runtime.navigation_revision=-1;runtime.set_navigation(100,{"width":0})
  runtime.spawn(1,0,1,Vector3(0,height,0),100,.4)
  var external={"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3(0,height,-4)]),"hp":PackedFloat32Array([500])}
  var hits=[]
  for i in 245:
   runtime.step(1.0/60,{"targets":external})
   hits.append_array(runtime.take_events().filter(func(e):return e.kind=="external_damage"))
  check(hits.size()==3 and hits.all(func(e):return e.target_id==0 and e.external_kind==0 and e.projectile),"All three bullets damage the external hero once at height %s"%height)
 runtime.clear();runtime.navigation_revision=-1
 runtime.set_navigation(101,{"width":0,"ray_min":PackedVector3Array([Vector3(-2,0,-3)]),"ray_max":PackedVector3Array([Vector3(2,8,-2)]),"ray_owner":PackedInt64Array([44])})
 runtime.spawn(1,0,1,Vector3.ZERO,100,.4)
 var cover_target={"ids":PackedInt64Array([0]),"kinds":PackedInt32Array([0]),"positions":PackedVector3Array([Vector3(0,0,-4)]),"hp":PackedFloat32Array([500])}
 var blocked_hits=[]
 for i in 60:
  runtime.step(1.0/60,{"targets":cover_target})
  blocked_hits.append_array(runtime.take_events().filter(func(e):return e.kind=="external_damage"))
 check(blocked_hits.is_empty(),"Real vertical cover prevents ranged damage")
 # A red soldier must not commit a second melee after its victim disappears.
 handles=setup(0);runtime.step(.5,{});runtime.take_events();runtime.despawn(handles[1])
 var lost=[]
 for i in 60:runtime.step(1.0/60,{});lost.append_array(runtime.take_events())
 check(not lost.any(func(e):return e.kind=="melee") and lost.any(func(e):return e.kind=="done" and e.source_tick==20),"Red combo ends after the first slash when contact is lost")
 runtime.clear();runtime.navigation_revision=-1;runtime.set_navigation(102,{"width":0})
 var walker:int=runtime.spawn(-1,1,12,Vector3.ZERO,500,.4)
 runtime.apply_hit(walker,{"element":"slow","status_seconds":1.0,"slow_factor":.5})
 var goals={"goal_handles":PackedInt64Array([walker]),"goal_positions":PackedVector3Array([Vector3(20,0,0)]),"goal_speeds":PackedFloat32Array([4])}
 runtime.step(.5,goals);var slowed:Vector3=runtime.snapshot().positions[0]
 check(absf(slowed.x-1)<.001,"Slow scales movement without altering simulation time")
 runtime.step(.5,{"paused":true});check(runtime.snapshot().positions[0]==slowed,"Pause freezes both movement and status expiry")
 runtime.step(.5,goals);runtime.step(.5,goals)
 check(absf(runtime.snapshot().positions[0].x-4.033333)<.05,"Slow expires once and restores source speed")
 runtime.clear();runtime.free();finish()
func finish():
 print("ARMY_SOLDIER_COMBAT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
