extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Kits=preload("res://scripts/forest/crowd/army_kit_data.gd")
var checks=0
var failures=0
var original_releases=[]
var original_hits=[]
var original_first_buff=0.0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 await source_ranger()
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 var data:Dictionary=Kits.from_model(model)
 if not data.get("ally_kinds",PackedInt32Array()).has(10):check(false,"Native Ranger rapid arrows and autonomous five-arrow fan are missing");finish();return
 data.ally_profiles[data.ally_kinds.find(10)*5+4]=0
 var r=Runtime.new();r.configure(null);r.set_navigation(1,{"width":0});r.configure_kits(data)
 var target:int=r.spawn(1,0,0,Vector3(0,0,52),10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100})
 var ranger:int=r.spawn(-1,1,10,Vector3(0,.12,72),100,.4);var events=[]
 var first_buff=0.0
 for frame in 90:
  r.step(1.0/60,{})
  if frame==0:first_buff=r.unit_state(ranger).buff_left
  for event in r.take_events():event.frame=frame;event.foot=r.unit_state(ranger).position;events.append(event)
 check(events.filter(func(e):return e.kind=="bullet" and e.source_id==-1).size()>5,"Ranger combines its source five-arrow fans with later rapid primary releases")
 check(r.unit_state(ranger).buff_left>0,"Ranger autonomously activates its original10-second power-arrow buff")
 var native_hits=events.filter(func(e):return e.kind=="damage" and e.source_id==-1).map(func(e):return [e.frame,snappedf(e.amount,.001)])
 var expected_hits=original_hits.map(func(e):return [e[0],e[2]])
 print("RANGER_DAMAGE_COMPARISON native=",native_hits," source=",expected_hits)
 check(native_hits==expected_hits,"All opening arrow impact frames and actual HP changes match the original controller")
 check(absf(first_buff-original_first_buff)<.0000001,"The opening buff timer consumes the same first physics tick as the source")
 var primaries=events.filter(func(e):return e.kind=="bullet" and e.action_index!=3)
 var original=original_releases.filter(func(e):return e.weapon=="cutlass")
 print("RANGER_NATIVE_PRIMARY_FRAMES ",primaries.map(func(e):return [e.frame,e.amount])," source=",original.map(func(e):return [e.frame,e.damage]))
 check(primaries.size()>=3 and original.size()>=3 and range(3).all(func(i):return primaries[i].frame==original[i].frame and primaries[i].amount==original[i].damage),"Rapid primary release cadence and power damage match the unchanged controller")
 check(r.snapshot().has("projectile_ids"),"Owned projectile snapshots must expose live arrow positions independently of rendering")
 if primaries.size()>=3 and original.size()>=3:
  var hands_match=true
  for i in 3:
   var actual:Vector3=primaries[i].position-primaries[i].direction*.12-primaries[i].foot
   var expected:Vector3=original[i].origin-original[i].direction*.12-original[i].cast_foot
   hands_match=hands_match and actual.distance_to(expected)<.01
  check(hands_match,"All three primary releases start at the real authored hand within one centimetre")
 await grazing_cover(r,data)
 await trajectories(r,data)
 var normal=groups(r,data,64);var hidden=groups(r,data,0)
 check(normal.hits==hidden.hits and normal.hp==hidden.hp,"Disabling cosmetic capacity cannot change real arrow damage or attack timing")
 check(normal.sources==[-53,-52,-51,-50],"Two simultaneous Ranger groups retain four independent attacking owners")
 var baseline=retired_shots(r,data,false);var another=retired_shots(r,data,true)
 check(baseline>0 and is_equal_approx(baseline,another),"A new summon cannot cancel or alter a retired Ranger's released arrows")
 standoff_and_bridges(r,data)
 r.clear();r.set_navigation(500,{"width":0});r.configure_kits(data)
 target=r.spawn(500,0,0,Vector3.ZERO,1000000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});ranger=r.spawn(-500,1,10,Vector3(0,0,20),100,.4);r.step(12,{})
 var all_primary=r.take_events().filter(func(e):return e.kind=="bullet" and e.action_index!=3)
 var plain=all_primary.filter(func(e):return e.amount==67)
 check(r.unit_state(ranger).buff_left<=0 and plain.size()>=3,"The power buff expires and regular67damage primary arrows return")
 check(range(all_primary.size()).all(func(i):return i%3!=2 or all_primary[i].amount==101),"Every third lifetime primary release stays powered across combo resets and buff expiry")
 r.clear();r.free();finish()
func source_ranger():
 var f=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(f);var game=await f.make_game("original")
 f.clear_targets();var target=f.add_target(Vector3(0,0,52));var row=game.model.enemies[target.forest_id];row.hp=10000;row.max_hp=10000;target.hp=10000;target.max_hp=10000;game.character_tuning["ranger"]={"critical_chance":0.0}
 var unit=game.explorer_helpers.pool.filter(func(u):return u.kit_id==10)[0]
 unit.summon(target,Vector3(0,.12,72),0);unit.set_physics_process(false);unit.think_left=0
 var clock={"frame":0};target.trace_clock=clock
 f.active_tick=func(dt):
  var before:Vector3=unit.global_position
  unit._physics_process(dt)
  if clock.frame==0:original_first_buff=unit.active_ability.player.buffTime
  for shot in unit.active_ability.projectiles:
   if shot.has("army_test_seen"):continue
   shot.army_test_seen=true
   original_releases.append({"frame":clock.frame,"origin":shot.rangerFlight.origin,"direction":shot.rangerFlight.direction,"damage":shot.damage,"speed":shot.vel.length(),"range":shot.rangerFlight.range,"width":shot.width,"weapon":shot.weapon,"curved":shot.rangerFlight.curved,"foot":unit.global_position,"cast_foot":before if shot.weapon=="flintlock" else unit.global_position})
  clock.frame+=1
 await f.advance(1.5);f.active_tick=Callable();original_hits=target.hits.duplicate(true)
 print("RANGER_SOURCE_RELEASES ",original_releases.slice(0,12));print("RANGER_SOURCE_HITS ",target.hits)
 check(original_releases.size()>5 and original_releases.slice(0,5).all(func(e):return e.frame==0 and e.damage==38),"The original Ranger opens with five buffed38damage arrows before its rapid primaries")
 await f.close();f.queue_free();await process_frame
func grazing_cover(r,data):
 r.clear();r.set_navigation(2,{"width":0});r.configure_kits(data)
 var target:int=r.spawn(2,0,0,Vector3.ZERO,10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});r.spawn(-2,1,10,Vector3(0,0,20),100,.4);r.step(1.0/60,{})
 var arrows=r.take_events().filter(func(e):return e.kind=="bullet")
 check(arrows.size()==5,"The grazing-cover fixture starts with one five-arrow fan")
 if arrows.size()!=5:return
 var arrow:Dictionary=arrows[2];var side:Vector3=arrow.direction.cross(Vector3.UP).normalized()
 var world=Node3D.new();root.add_child(world);var body=StaticBody3D.new();world.add_child(body)
 var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.04,2,.3);collision.shape=box;body.add_child(collision)
 body.global_transform=Transform3D(Basis.looking_at(arrow.direction,Vector3.UP),arrow.position+arrow.direction*2+side*.22)
 await physics_frame;r.set_navigation(3,{"width":0,"air_faces":r.static_collision_faces(world)});r.step(.1,{})
 check(r.take_events().any(func(e):return e.kind=="projectile_impact" and e.projectile_id==arrow.projectile_id),"The arrow's authored thin-box volume clips grazing cover even when its centre ray misses")
 world.queue_free();await process_frame
 world=Node3D.new();root.add_child(world);load("res://scripts/forest/forest_art.gd").solid(world,Vector3(0,2,-.5),Vector3(20,4,.2));await physics_frame
 r.clear();r.set_navigation(4,{"width":0,"air_faces":r.static_collision_faces(world)})
 target=r.spawn(3,0,0,Vector3(0,0,-4),10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});r.spawn(-3,1,10,Vector3.ZERO,100,.4);r.step(.1,{})
 check(is_equal_approx(r.unit_state(target).hp,10000),"An arrow obstructed at release cannot damage an overlapping enemy through the wall")
 world.queue_free();await process_frame
func trajectories(r,data):
 r.clear();r.set_navigation(20,{"width":0});r.configure_kits(data)
 var target:int=r.spawn(20,0,0,Vector3.ZERO,10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});r.spawn(-20,1,10,Vector3(0,0,20),100,.4);r.step(1.0/60,{})
 var events=r.take_events().filter(func(e):return e.kind=="bullet");var originals={};var flight=load("res://assets/rogue/scripts/ranger_arrow_flight.gd")
 for i in events.size():
  var e:Dictionary=events[i];var mesh=Node3D.new();mesh.position=e.position
  var shot={"mesh":mesh,"vel":e.direction*34,"life":20.0/34,"aimDirection":e.direction};flight.attach(shot,i,1,true);originals[e.projectile_id]=shot
 var matches=true
 for frame in 10:
  if frame>0:r.step(1.0/60,{})
  var snapshot=r.snapshot()
  for id in originals:
   flight.advance(originals[id],1.0/60);var index:int=snapshot.projectile_ids.find(id)
   matches=matches and index>=0
   if index>=0:matches=matches and snapshot.projectile_positions[index].distance_to(originals[id].mesh.position)<.0001 and snapshot.projectile_directions[index].distance_to(originals[id].flightDirection)<.0001
 check(matches,"All five native arrow positions and tangents match the original curved-flight module across ten ticks")
 for shot in originals.values():shot.mesh.free()
func groups(r,data,cosmetic:int)->Dictionary:
 r.clear();r.set_navigation(30+cosmetic,{"width":0});var tuned=data.duplicate(true);tuned.ally_profiles[tuned.ally_kinds.find(10)*5+4]=0;r.configure_kits(tuned)
 var enemies=[];var units=[]
 for i in 2:
  var h:int=r.spawn(i+1,0,0,Vector3(-15+i*30,0,0),100000,3.9);enemies.append(h);r.apply_hit(h,{"element":"ice","status_seconds":100})
  for j in 2:units.append(r.spawn(-50-i*2-j,1,10,Vector3(-16+i*30+j*2,0,20),100,.4))
 var hits=[];var sources=[]
 for frame in 180:
  r.step(1.0/60,{"cosmetic_capacity":cosmetic})
  for event in r.take_events():
   if event.kind=="damage" and event.source_id<0:
    hits.append([frame,event.source_id,event.target_id,event.amount])
    if event.source_id not in sources:sources.append(event.source_id)
 sources.sort();return {"hits":hits,"sources":sources,"hp":enemies.map(func(h):return r.unit_state(h).hp)}
func retired_shots(r,data,add_new:bool)->float:
 r.clear();r.set_navigation(200+int(add_new),{"width":0});var tuned=data.duplicate(true);tuned.ally_profiles[tuned.ally_kinds.find(10)*5+4]=0;r.configure_kits(tuned)
 var target:int=r.spawn(90,0,0,Vector3.ZERO,100000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});var owner_:int=r.spawn(-90,1,10,Vector3(0,0,20),100,.4)
 r.step(.1,{});r.take_events();r.despawn(owner_)
 if add_new:r.spawn(-91,1,10,Vector3(0,0,20),100,.4)
 r.step(.8,{});var damage=0.0
 for e in r.take_events():
  if e.kind=="damage" and e.source_id==-90:damage+=e.amount
 return damage
func standoff_and_bridges(r,data):
 for gap in [5,35]:
  r.clear();r.set_navigation(300+gap,{"width":0});r.configure_kits(data)
  var target:int=r.spawn(1,0,0,Vector3.ZERO,100000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});var ranger:int=r.spawn(-1,1,10,Vector3(0,0,gap),100,.4);r.step(3,{})
  var p:Vector3=r.unit_state(ranger).position;var distance=maxf(0,p.z-3.456)
  check(distance>=6.8 and distance<=19.2,"Ranger establishes its original ranged standoff from initial gap%d"%gap)
 r.clear();r.set_navigation(400,{"width":0,"layer_min":PackedVector3Array([Vector3(-50,8,-50)]),"layer_max":PackedVector3Array([Vector3(50,8,50)])})
 var target:int=r.spawn(1,0,0,Vector3(0,8,0),100000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});r.spawn(-1,1,10,Vector3(0,8,20),100,.4);r.step(1,{})
 check(r.unit_state(target).hp<100000,"Ranger arrows damage a real fitted target on raised bridge support")
 r.clear();target=r.spawn(1,0,0,Vector3.ZERO,100000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});r.spawn(-1,1,10,Vector3(0,8,20),100,.4);r.step(1,{})
 check(is_equal_approx(r.unit_state(target).hp,100000),"Bridge collision blocks arrows aimed through the deck at a lower target")
func finish():print("ARMY_RANGER_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
