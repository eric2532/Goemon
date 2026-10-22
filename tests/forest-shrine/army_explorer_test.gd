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
 var r=Runtime.new();r.configure(null);r.set_navigation(1,{"width":0})
 var data:Dictionary=Kits.from_model(model)
 data.ally_profiles[4]=0.0
 r.configure_kits(data)
 var enemy:int=r.spawn(1,0,0,Vector3.ZERO,10000,3.9);r.apply_hit(enemy,{"element":"ice","status_seconds":100.0})
 var ally:int=r.spawn(-1,1,11,Vector3(0,0,4),200,.4)
 var contacts=[];var events=[]
 for i in 240:
  r.step(1.0/60,{})
  for event in r.take_events():
   events.append(event)
   if event.kind=="melee" and event.source_id==-1:contacts.append(event)
 check(contacts.size()>=9,"Explorer independently approaches and repeats original primary combos")
 if contacts.size()>=4:
  check(contacts.slice(0,4).map(func(e):return e.action_index)==[0,1,2,0],"Explorer uses the original three-hit sequence and recovery")
  check(contacts.slice(0,4).map(func(e):return e.amount)==[19.0,19.0,28.0,19.0],"Explorer preserves captured source raw damage including the finisher")
  check(absf(contacts[0].source_tick-.055*30)<.00001,"Explorer preserves its source contact marker")
 check(not events.any(func(e):return e.source_id==-1 and e.kind in ["bullet","muzzle"]),"Dedicated Explorer never casts unsupported skills")
 var hits=events.filter(func(e):return e.kind=="damage" and e.source_id==-1)
 if hits.size()>=4:
  var expected=[19.0,19.95,30.8,21.85]
  check(range(4).all(func(i):return absf(hits[i].amount-expected[i])<.00001),"Independent NPC chain preserves source damage multipliers without cosmetic RNG")
 var baked=load("res://assets/crowd/army_kit_profiles.tres")
 for path in baked.get_meta("source_hashes"):
  check(FileAccess.get_sha256("res://"+path)==baked.get_meta("source_hashes")[path],"Fitted kit export is current for "+path)
 var s=r.unit_state(ally);check(s.hp==200 and s.get("chain_count",0)>0,"Explorer owns independent HP and its own attack chain")
 r.clear();r.set_pose(0,Vector3.ZERO,0)
 var raised:int=r.spawn(2,0,0,Vector3(0,8,0),10000,3.9);r.apply_hit(raised,{"element":"ice","status_seconds":100.0})
 ally=r.spawn(-2,1,11,Vector3(0,0,4),200,.4)
 var damage=[]
 for i in 120:r.step(1.0/60,{});damage.append_array(r.take_events().filter(func(e):return e.kind=="damage" and e.source_id==-2))
 check(damage.is_empty(),"Explorer cannot hit a target beyond original vertical reach")
 # Approach, freeze/resume and generation-safe target replacement.
 r.clear();enemy=r.spawn(3,0,0,Vector3.ZERO,10000,3.9);r.apply_hit(enemy,{"element":"ice","status_seconds":100.0})
 ally=r.spawn(-3,1,11,Vector3(0,0,20),200,.4);var approach=[]
 for i in 180:r.step(1.0/60,{});approach.append_array(r.take_events())
 check(approach.any(func(e):return e.kind=="damage" and e.source_id==-3),"Explorer closes the gap through autonomous movement and attacks")
 r.apply_hit(ally,{"element":"ice","status_seconds":1.0});r.take_events();var point:Vector3=r.unit_state(ally).position
 r.step(.9,{});check(r.take_events().filter(func(e):return e.source_id==-3).is_empty() and r.unit_state(ally).position==point,"An interrupted Explorer holds both action and body during freeze")
 r.despawn(enemy);enemy=r.spawn(4,0,0,Vector3(2,0,0),10000,3.9);r.apply_hit(enemy,{"element":"ice","status_seconds":100.0})
 var replacement=[]
 for i in 120:r.step(1.0/60,{});replacement.append_array(r.take_events())
 check(replacement.any(func(e):return e.kind=="damage" and e.source_id==-3 and e.target_id==4),"Explorer reacquires a living replacement after thaw without stale victim hits")
 await compare_real_source(r,model)
 r.clear();r.free();finish()
func compare_real_source(r,model):
 var f=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(f);var game=await f.make_game("original")
 f.clear_targets();var target=f.add_target(Vector3(0,0,52));var row=game.model.enemies[target.forest_id];row.hp=10000;row.max_hp=10000;target.hp=10000;target.max_hp=10000
 var unit=game.explorer_helpers.pool.filter(func(u):return u.kit_id==11)[0]
 unit.summon(target,Vector3(0,.12,56),0);unit.set_physics_process(false);unit.think_left=0
 var clock={"frame":0};target.trace_clock=clock
 f.active_tick=func(dt):unit._physics_process(dt);clock.frame+=1
 await f.advance(1.5);f.active_tick=Callable()
 var original=target.hits.slice(0,4)
 r.clear();var enemy:int=r.spawn(1,0,0,Vector3(0,0,52),10000,3.9);r.apply_hit(enemy,{"element":"ice","status_seconds":100.0});r.spawn(-1,1,11,Vector3(0,.12,56),200,.4)
 var native=[]
 for frame in 90:
  r.step(1.0/60,{})
  for e in r.take_events():
   if e.kind=="melee" and e.source_id==-1:native.append([frame,e.amount])
 check(original.size()==4 and native.size()>=4,"Original and native Explorer both complete four real swings")
 if original.size()==4 and native.size()>=4:
  print("EXPLORER_SOURCE_TIMING original=",original," native=",native.slice(0,4))
  check(range(4).all(func(i):return original[i][0]==native[i][0] and original[i][1]==native[i][1]),"Native Explorer contact frames and raw damage match actual source-controller simulation")
 await f.close();f.queue_free();await process_frame
func finish():print("ARMY_EXPLORER_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
