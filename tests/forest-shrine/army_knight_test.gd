extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Kits=preload("res://scripts/forest/crowd/army_kit_data.gd")
var checks=0
var failures=0
var r
var data:Dictionary
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func ticks(count:int,context:Dictionary={})->Array:
 var events=[]
 for i in count:r.step(1.0/60,context);events.append_array(r.take_events())
 return events
func guard_fixture()->Array:
 r.clear();r.configure_kits(data);r.set_navigation(1,{"width":0})
 var enemy:int=r.spawn(1,0,1,Vector3(0,0,8),10000,3.9)
 var knight:int=r.spawn(-1,1,7,Vector3.ZERO,500,.4)
 ticks(15)
 return [enemy,knight]
func run():
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 data=Kits.from_model(model)
 check(7 in data.ally_kinds,"Native Knight kit is available without a Hero controller")
 if not 7 in data.ally_kinds:finish();return
 # Hold the bodies still while exercising real soldier windup/guard decisions.
 for i in data.ally_kinds.size():data.ally_profiles[i*5+1]=0;data.ally_profiles[i*5+4]=0
 for i in data.soldier_kinds.size():data.soldier_profiles[i*6+1]=0
 r=Runtime.new();r.configure(null)
 var pair=guard_fixture();var enemy:int=pair[0];var knight:int=pair[1]
 var state:Dictionary=r.unit_state(knight)
 check(state.buff_left>7.7 and state.buff_left<8,"Knight opens with the original eight-second Code")
 check(state.get("blocking",false),"Knight interrupts primary intent and guards a recovered soldier attack")
 check(r.unit_state(enemy).get("target_id",0)==-1,"Code taunt directs the soldier at the native Knight")
 var blocked=r.apply_hit(knight,{"amount":81.0,"direction":Vector3.FORWARD,"projectile":true})
 check(not blocked.accepted and blocked.hp==500,"Frontal projectile is blocked without HP loss")
 r.apply_hit(knight,{"amount":81.0,"direction":Vector3.FORWARD})
 r.apply_hit(knight,{"amount":81.0,"direction":Vector3.ZERO})
 r.take_events()
 var response=ticks(45)
 var faces=response.filter(func(e):return e.kind=="shield_counter")
 var hits=response.filter(func(e):return e.kind=="damage" and e.source_id==-1)
 check(faces.size()==3 and faces.map(func(e):return e.action_index)==[0,1,2],"Simultaneous blocked attacks emit exactly one three-face counter")
 check(hits.size()==3 and hits.all(func(e):return e.amount==80.0),"Each swept shield face hits a victim exactly once for source damage")
 check(r.unit_state(knight).chain_count==1,"All counter faces confirm only one owned attack chain link")
 check(r.unit_state(knight).get("riposte",false),"A Code block arms one riposte without consuming it on counter faces")
 r.set_pose(enemy,Vector3(0,0,3.8),0);r.apply_hit(enemy,{"element":"ice","status_seconds":100.0})
 var riposte_hits=ticks(70).filter(func(e):return e.kind=="melee" and e.source_id==-1)
 check(riposte_hits.size()>=2 and riposte_hits[0].amount==76 and riposte_hits[1].amount==42,"Only the first post-block primary consumes the original 1.8x rounded riposte")
 pair=guard_fixture();knight=pair[1]
 var inside:int=r.spawn(2,0,0,Vector3(6.5,0,8),10000,3.9)
 var outside:int=r.spawn(3,0,0,Vector3(9,0,8),10000,3.9)
 var behind:int=r.spawn(4,0,0,Vector3(0,0,-10),10000,3.9)
 var above:int=r.spawn(5,0,0,Vector3(0,10,8),10000,3.9)
 for h in [inside,outside,behind,above]:r.apply_hit(h,{"element":"ice","status_seconds":100.0})
 r.apply_hit(knight,{"amount":40.0,"direction":Vector3.FORWARD});r.take_events();var area=ticks(45)
 check(area.filter(func(e):return e.kind=="damage" and e.source_id==-1 and e.target_id==2).size()==3,"All three faces reach the inside edge of the six-metre shield")
 check([outside,behind,above].all(func(h):return r.unit_state(h).hp==10000),"Shield polygon rejects outside, rear and elevated victims")
 pair=guard_fixture();knight=pair[1]
 r.apply_hit(knight,{"amount":40.0,"direction":Vector3.FORWARD});r.take_events()
 r.set_navigation(2,{"width":0,"ray_min":PackedVector3Array([Vector3(-4,0,2)]),"ray_max":PackedVector3Array([Vector3(4,8,3)]),"ray_owner":PackedInt64Array([99])})
 check(not ticks(45).any(func(e):return e.kind=="damage" and e.source_id==-1),"Real cover blocks shield counter damage")
 pair=guard_fixture();knight=pair[1]
 var rear=r.apply_hit(knight,{"amount":81.0,"direction":Vector3.BACK,"projectile":false})
 check(rear.accepted and rear.hp==459,"Code rounds half rear damage before the incoming multiplier")
 check(not r.apply_hit(knight,{"amount":81.0,"direction":Vector3.FORWARD}).accepted,"Incoming hit invulnerability precedes another counter trigger")
 check(not ticks(20).any(func(e):return e.kind=="shield_counter"),"Rear damage does not create a shield counter")
 pair=guard_fixture();knight=pair[1]
 var scaled=data.duplicate(true);scaled.damage_taken_multiplier=2;r.configure_kits(scaled)
 check(r.apply_hit(knight,{"amount":81.0,"direction":Vector3.BACK}).hp==418,"Code's half-damage rounding precedes the live incoming damage multiplier")
 pair=guard_fixture();knight=pair[1]
 r.apply_hit(knight,{"amount":40.0,"direction":Vector3.FORWARD});r.take_events();ticks(45)
 for i in 120:
  if r.unit_state(knight).get("blocking",false):break
  ticks(1)
 r.apply_hit(knight,{"amount":40.0,"direction":Vector3.FORWARD});r.take_events()
 check(ticks(45).filter(func(e):return e.kind=="shield_counter").size()==3,"A completed shield counter can be reused on a later guarded attack")
 pair=guard_fixture();knight=pair[1]
 r.apply_hit(knight,{"amount":40.0,"direction":Vector3.FORWARD});r.take_events()
 var frozen=r.unit_state(knight).position
 r.apply_hit(knight,{"element":"ice","status_seconds":1.0});r.take_events()
 check(not ticks(40).any(func(e):return e.kind=="shield_counter") and r.unit_state(knight).position==frozen,"Freeze suspends the guard counter and body together")
 check(ticks(65).filter(func(e):return e.kind=="shield_counter").size()==3,"Thaw resumes all three counter faces exactly once")
 # Overlapping taunts survive one Knight dying and cannot target reused slots.
 r.clear();r.configure_kits(data)
 enemy=r.spawn(10,0,1,Vector3(0,0,40),10000,3.9)
 var a:int=r.spawn(-10,1,7,Vector3.ZERO,500,.4);ticks(1)
 var b:int=r.spawn(-11,1,7,Vector3(20,0,0),500,.4);ticks(1)
 check(r.unit_state(enemy).get("target_id",0)==-11,"A newly activated Code overrides the current enemy target")
 r.apply_hit(a,{"amount":10000.0,"direction":Vector3.ZERO});ticks(8)
 check(r.unit_state(enemy).get("target_id",0)==-11,"Dying Knight removes only its own taunt")
 r.apply_hit(b,{"amount":10000.0,"direction":Vector3.ZERO});ticks(8)
 check(r.unit_state(enemy).get("target_id",0)!=-11,"Soldier reacquires after the last taunting Knight dies")
 var replacement:int=r.spawn(-11,1,12,Vector3(50,0,0),500,.4)
 r.spawn(-12,1,12,r.unit_state(enemy).position+Vector3(0,0,-20),500,.4);ticks(8)
 check(r.unit_state(enemy).get("target_id",0)==-12 and r.valid(replacement),"A reused logical ID cannot inherit the retired Knight's taunt")
 # Counter is a released cast: disappear/drain retains the captured origin.
 pair=guard_fixture();knight=pair[1]
 r.apply_hit(knight,{"amount":40.0,"direction":Vector3.FORWARD});r.take_events();r.despawn(knight)
 var reused:int=r.spawn(-1,1,12,Vector3(40,0,0),500,.4)
 check(ticks(45).filter(func(e):return e.kind=="shield_counter").size()==3 and r.unit_state(reused).chain_count==0,"Released counters drain independently without confirming a reused caster")
 # Expiry and reuse use active simulation time, with pause consuming none.
 r.clear();r.configure_kits(data);knight=r.spawn(-1,1,7,Vector3.ZERO,500,.4);ticks(1)
 var remaining:float=r.unit_state(knight).buff_left;ticks(60,{"paused":true})
 check(r.unit_state(knight).buff_left==remaining,"Pause never consumes Code duration")
 ticks(481);check(r.unit_state(knight).buff_left==0,"Code expires after eight active seconds")
 enemy=r.spawn(1,0,0,Vector3(0,0,14),10000,3.9);r.apply_hit(enemy,{"element":"ice","status_seconds":100.0})
 ticks(850);check(r.unit_state(knight).buff_left>0,"Autonomous Knight recasts Code after the original cooldown")
 await compare_source(model)
 r.clear();r.free();finish()
func compare_source(model):
 var f=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(f);var game=await f.make_game("original")
 f.clear_targets();var target=f.add_target(Vector3(0,0,52));var row=game.model.enemies[target.forest_id];row.hp=10000;row.max_hp=10000;target.hp=10000;target.max_hp=10000
 var unit=game.explorer_helpers.pool.filter(func(u):return u.kit_id==7)[0]
 unit.summon(target,Vector3(0,.12,56),0);unit.set_physics_process(false);unit.think_left=0
 var clock={"frame":0};target.trace_clock=clock
 f.active_tick=func(dt):unit._physics_process(dt);clock.frame+=1
 await f.advance(2);f.active_tick=Callable()
 var original=target.hits.slice(0,3)
 r.clear();var native_data=Kits.from_model(model)
 for i in native_data.ally_kinds.size():native_data.ally_profiles[i*5+4]=0
 r.configure_kits(native_data)
 var enemy:int=r.spawn(1,0,0,Vector3(0,0,52),10000,3.9);r.apply_hit(enemy,{"element":"ice","status_seconds":100.0})
 r.spawn(-1,1,7,Vector3(0,.12,56),500,.4)
 var native=[]
 for frame in 120:
  for e in ticks(1):
   if e.kind=="melee" and e.source_id==-1:native.append([frame,e.amount])
 print("KNIGHT_SOURCE_TIMING original=",original," native=",native.slice(0,3))
 check(original.size()==3 and native.size()>=3,"Original and native Knight both complete three real primary attacks")
 if original.size()==3 and native.size()>=3:check(range(3).all(func(i):return original[i][0]==native[i][0] and original[i][1]==native[i][1]),"Native Knight primary frames and raw damage match the original controller")
 # Independently compare the actual source damage filter at a frontal guard.
 var c=unit.active_ability;c.player.attack=null;c.player.blocking=true;c.player.guardTime=1;c.player.buffTime=8;unit.facing=Vector3.BACK;unit.invuln=0
 check(c.filter_damage(81,Vector3.FORWARD,true)==0 and c.filter_damage(81,Vector3.BACK,false)==41,"Original frontal guard and rounded Code damage confirm native filter expectations")
 # Tick the original released counter directly, avoiding unrelated locomotion.
 unit.global_position=Vector3(0,0,44);c.player.pos=unit.global_position;c.player.angle=0;c.player.guardCounter=null;c.hit_stop=0
 unit.attack_chain.reset();target.hits.clear();clock.frame=0
 c.filter_damage(40,Vector3.FORWARD,true)
 f.active_tick=func(dt):c.tick(dt);clock.frame+=1
 await f.advance(.75);f.active_tick=Callable();original=target.hits.duplicate(true)
 var pair=guard_fixture()
 # The reference target's CharacterBody is not being advanced in this
 # isolated ability trace; freeze native body motion as well as locomotion.
 r.apply_hit(pair[0],{"element":"ice","status_seconds":100.0})
 r.apply_hit(pair[1],{"amount":40.0,"direction":Vector3.FORWARD});r.take_events();native=[]
 for frame in 45:
  for e in ticks(1):
   if e.kind=="damage" and e.source_id==-1:native.append([frame,e.amount])
 print("KNIGHT_COUNTER_TIMING original=",original," native=",native)
 check(original.size()==3 and native.size()==3,"Original and native counters both hit with all three swept faces")
 if original.size()==3 and native.size()==3:check(range(3).all(func(i):return original[i][0]==native[i][0] and original[i][1]==native[i][1]),"Counter contact frames and raw damage match unchanged original geometry")
 await f.close();f.queue_free();await process_frame
func finish():print("ARMY_KNIGHT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
