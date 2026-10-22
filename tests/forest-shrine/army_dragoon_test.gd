extends SceneTree
const Runtime=preload("res://scripts/forest/crowd/army_runtime.gd")
const Kits=preload("res://scripts/forest/crowd/army_kit_data.gd")
var checks=0
var failures=0
var original_hits=[]
var original_positions=[]
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 await source_drop()
 var model=load("res://scripts/forest/forest_model.gd").new();model.reset(42,{}, {},false)
 var data:Dictionary=Kits.from_model(model)
 var baked:Dictionary=load("res://assets/crowd/army_kit_profiles.tres").get_meta("profiles")[8]
 check(baked.has("body") and baked.has("jump_speed"),"Flight body dimensions and jump speed are baked from the actual configured ally")
 if not data.get("ally_kinds",PackedInt32Array()).has(8):check(false,"Native Dragoon aimed drop and landing pulses are missing");finish();return
 var index:int=data.ally_kinds.find(8);data.ally_profiles[index*5+4]=0.0
 var r=Runtime.new();r.configure(null);r.set_navigation(1,{"width":0});r.configure_kits(data)
 var target:int=r.spawn(1,0,0,Vector3(0,0,52),10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0})
 var dragoon:int=r.spawn(-1,1,8,Vector3(0,12.12,52),200,.4);var native=[];var positions=[]
 for frame in 60:
  r.step(1.0/60,{});positions.append(r.unit_state(dragoon).position)
  for event in r.take_events():
   if event.kind=="damage" and event.source_id==-1:native.append([frame,event.amount])
 print("DRAGOON_NATIVE_DROP ",native," positions=",positions.slice(0,22))
 check(native.size()==3,"The opening has exactly three landing pulses")
 if original_hits.size()==3 and native.size()==3:
  check(range(3).all(func(i):return original_hits[i][0]==native[i][0]),"All three landing pulse frames match the unchanged source controller")
  check(range(3).all(func(i):return is_equal_approx(original_hits[i][2],native[i][1])),"The landing cast retains source snapshotted damage and one chain confirmation")
 check(positions[0].y>11 and positions[0].y<12.12,"Opening descent advances in the air instead of snapping to ground navigation")
 check(range(mini(60,original_positions.size())).all(func(i):return positions[i].distance_to(original_positions[i])<.001),"The complete opening trajectory and landing match the original real-physics body")
 await source_sweep(r,data)
 await source_jump(r,data)
 var bad=data.duplicate(true);bad.dragoon=PackedFloat64Array()
 check(not r.native.configure_kits(bad),"An enabled Dragoon requires complete flight and attack tuning")
 r.configure_kits(data)
 r.clear();target=r.spawn(20,0,0,Vector3.ZERO,10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});dragoon=r.spawn(-20,1,8,Vector3(0,48.12,0),200,.4)
 r.step(.9,{})
 check(r.unit_state(dragoon).position.y>0 and not r.apply_hit(dragoon,{"amount":1000.0}).accepted,"A long descent stays invulnerable after the nominal0.72-second animation time")
 r.clear()
 for id in [21,22,23,24]:
  var z={21:0,22:17,23:21,24:24}[id];var h:int=r.spawn(id,0,0,Vector3(0,0,z),10000,3.9);r.apply_hit(h,{"element":"ice","status_seconds":100})
 dragoon=r.spawn(-21,1,8,Vector3(0,12.12,0),200,.4);r.step(.84,{})
 var pulses=r.take_events().filter(func(e):return e.kind=="damage" and e.source_id==-21)
 check([21,22,23,24].map(func(id):return pulses.filter(func(e):return e.target_id==id).size())==[3,2,1,0],"The three expanding fitted-body areas independently hit3,2,1,0 times at increasing distances")
 check(pulses.all(func(e):return is_equal_approx(e.amount,64)) and r.unit_state(dragoon).chain_count==1,"A multi-victim three-pulse cast snapshots64damage and confirms its chain once")
 r.clear();target=r.spawn(2,0,0,Vector3.ZERO,10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});dragoon=r.spawn(-2,1,8,Vector3(0,12.12,0),200,.4)
 r.step(.1,{});r.take_events();var held:Vector3=r.unit_state(dragoon).position
 check(not r.apply_hit(dragoon,{"amount":1000.0,"source_id":2}).accepted,"The committed airborne thrust is protected from incoming damage")
 r.apply_hit(dragoon,{"element":"ice","status_seconds":.5});r.step(.4,{})
 check(r.unit_state(dragoon).position==held and not r.take_events().any(func(e):return e.kind=="landing_pulse"),"Freeze pauses descent and cannot create a premature landing")
 r.step(.9,{})
 check(r.take_events().filter(func(e):return e.kind=="landing_pulse").size()==3,"Thaw resumes the same flight and three-pulse cast")
 r.clear();target=r.spawn(3,0,0,Vector3.ZERO,10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});dragoon=r.spawn(-3,1,8,Vector3(0,12.12,0),200,.4)
 r.step(.1,{});r.take_events();r.apply_hit(dragoon,{"knockback":Vector3(5,0,0),"flinch":.25});r.step(.9,{})
 check(not r.take_events().any(func(e):return e.kind=="landing_pulse"),"An explicitly interrupted flight falls without replaying its cancelled landing attack")
 check(r.unit_state(dragoon).position.x>.1 and absf(r.unit_state(dragoon).position.y)<.05,"An interrupted airborne body keeps gravity and incoming horizontal knockback")
 r.clear();target=r.spawn(4,0,0,Vector3.ZERO,10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});dragoon=r.spawn(-4,1,8,Vector3(0,12.12,0),200,.4)
 r.step(.29,{});r.take_events();r.despawn(dragoon);r.step(.6,{})
 check(r.take_events().filter(func(e):return e.kind=="landing_pulse" and e.source_id==-4).size()==2,"Already released delayed pulses survive caster retirement")
 r.clear();target=r.spawn(5,0,0,Vector3.ZERO,10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});dragoon=r.spawn(-5,1,8,Vector3(0,12.12,0),200,.4)
 r.step(.1,{});r.take_events();r.despawn(target);r.step(.9,{})
 check(r.take_events().filter(func(e):return e.kind=="landing_pulse").size()==3 and absf(r.unit_state(dragoon).position.z)<.001,"A dead target cannot redirect the committed landing to another aim source")
 r.clear();r.set_navigation(2,{"width":0,"layer_min":PackedVector3Array([Vector3(-4,5,-4)]),"layer_max":PackedVector3Array([Vector3(4,5,4)])})
 target=r.spawn(6,0,0,Vector3(3.8,5,0),10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});dragoon=r.spawn(-6,1,8,Vector3(3.8,17.12,0),200,.4);r.step(.6,{})
 check(absf(r.unit_state(dragoon).position.y-4.976)<.002,"A drop at the bridge edge lands on real raised support instead of the terrain below")
 r.clear();var heights=PackedFloat32Array();var covered=PackedByteArray()
 for z in 33:
  for x in 33:heights.append((x*3-48)*.2);covered.append(1)
 r.set_navigation(3,{"width":33,"spacing":3.0,"origin":Vector3(-48,0,-48),"heights":heights,"covered":covered})
 target=r.spawn(7,0,0,Vector3(0,0,0),10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100.0});dragoon=r.spawn(-7,1,8,Vector3(0,12.12,0),200,.4);r.step(.9,{})
 check(r.take_events().filter(func(e):return e.kind=="landing_pulse").size()==3 and absf(r.unit_state(dragoon).position.y)<.05,"A sloping triangle floor produces one physical landing and all three pulses")
 await later_leaps(r,data)
 r.clear();r.set_navigation(8,{"width":0});target=r.spawn(80,0,0,Vector3.ZERO,100000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});dragoon=r.spawn(-80,1,8,Vector3(0,12.12,0),200,.4)
 r.step(18,{});var primaries=r.take_events().filter(func(e):return e.kind=="melee" and e.source_id==-80 and e.amount!=111)
 check(primaries.size()>=3 and primaries.slice(0,3).map(func(e):return e.amount)==[37.0,37.0,54.0],"When the secondary is cooling down, Dragoon retains its original37,37,54 primary combo")
 if not r.has_method("static_collision_faces"):
  check(false,"Flights require an exporter of actual scenery collision, separate from navigation footprints")
 else:await actual_solids(r)
 r.clear();r.free();finish()
func source_sweep(r,data):
 var f=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(f);var game=await f.make_game("original")
 f.clear_targets();var target=f.add_target(Vector3(0,0,52));var row=game.model.enemies[target.forest_id];row.hp=10000;row.max_hp=10000;target.hp=10000;target.max_hp=10000
 game.character_tuning["dragoon"]={"critical_chance":0.0}
 var unit=game.explorer_helpers.pool.filter(func(u):return u.kit_id==8)[0]
 unit.summon(target,Vector3(0,.12,58),0);unit.set_physics_process(false);unit.think_left=0
 # Establish actual floor contact, then request the unchanged ground secondary.
 unit.opening=false;unit.state="acting";unit.ai_move=Vector3.ZERO
 f.active_tick=func(dt):unit.velocity.y=-2;unit.move_and_slide()
 await f.advance(.15);f.active_tick=Callable();unit.active_ability.player.pos=unit.global_position;unit.ai_aim=Vector3(0,1,52);unit.active_ability.player.angle=PI;unit.active_ability.action("flintlock")
 var clock={"frame":0};target.trace_clock=clock
 f.active_tick=func(dt):unit.active_ability.tick(dt);clock.frame+=1
 await f.advance(.85);f.active_tick=Callable();var source=target.hits.duplicate(true)
 r.clear();r.set_navigation(4,{"width":0});r.configure_kits(data);var e:int=r.spawn(1,0,0,Vector3(0,0,52),10000,3.9);r.apply_hit(e,{"element":"ice","status_seconds":100});r.spawn(-1,1,8,Vector3(0,0,58),200,.4);var native=[]
 for frame in 51:
  r.step(1.0/60,{})
  for event in r.take_events():
   if event.kind=="damage" and event.source_id==-1:native.append([frame,event.amount])
 print("DRAGOON_SOURCE_SWEEP ",source," native=",native)
 check(source.size()==3 and native.size()==3,"Original and native ground sweep each make three authored contacts")
 if source.size()==3 and native.size()==3:
  check(range(3).all(func(i):return source[i][0]==native[i][0] and is_equal_approx(source[i][2],native[i][1])),"All ground sweep markers and snapshotted damage match the source")
 await f.close();f.queue_free();await process_frame
func later_leaps(r,data):
 r.clear();r.set_navigation(5,{"width":0});r.configure_kits(data)
 var target:int=r.spawn(100,0,0,Vector3.ZERO,100000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});var dragoon:int=r.spawn(-100,1,8,Vector3(0,12.12,0),200,.4)
 r.step(1,{});r.take_events()
 for cycle in 2:
  var p:Vector3=r.unit_state(dragoon).position
  r.set_pose(target,p+Vector3(0,-p.y,16),0);var ascending=false;var pulses=[];var first_jump=-1
  for frame in 420:
   # Keep a fleeing enemy in leap range while the previous committed sweep or
   # five-second leap cooldown finishes; stop moving it once the jump launches.
   if not ascending:
    p=r.unit_state(dragoon).position;r.set_pose(target,p+Vector3(0,-p.y,16),0)
   r.step(1.0/60,{})
   ascending=ascending or r.unit_state(dragoon).velocity.y>5
   if ascending and first_jump<0:first_jump=frame
   for event in r.take_events():
    if event.kind=="landing_pulse" and event.source_id==-100:pulses.append([frame,event.action_index,event.position])
   if pulses.size()>=3:break
  print("DRAGOON_REUSED_LEAP ",cycle," ",pulses)
  check(ascending and pulses.size()==3,"Later skill cycle%d performs a real upward jump followed by one three-pulse landing"%cycle)
  if cycle==0:check(first_jump>=239,"The source's initial five-second leap cooldown starts at summon, before the opening drop")
func source_jump(r,data):
 var f=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(f);var game=await f.make_game("original")
 f.clear_targets();var target=f.add_target(Vector3(0,0,52));var row=game.model.enemies[target.forest_id];row.hp=10000;row.max_hp=10000;target.hp=10000;target.max_hp=10000;game.character_tuning["dragoon"]={"critical_chance":0.0}
 var unit=game.explorer_helpers.pool.filter(func(u):return u.kit_id==8)[0]
 unit.summon(target,Vector3(0,.12,64),0);unit.set_physics_process(false);unit.think_left=0;unit.state="acting";unit.opening=false;unit.leap_left=0
 f.active_tick=func(dt):unit.velocity.y=-2;unit.move_and_slide()
 await f.advance(.15);f.active_tick=Callable();unit.active_ability.player.pos=unit.global_position;var start:Vector3=unit.global_position
 var clock={"frame":0,"travel_seen":false};target.trace_clock=clock;var positions=[]
 f.active_tick=func(dt):
  unit._physics_process(dt);positions.append(unit.global_position)
  if unit.active_ability.player.travel!=null:clock.travel_seen=true
  elif clock.travel_seen:unit.state="draining" # Isolate released pulses from later ground attacks.
  clock.frame+=1
 await f.advance(1.1);f.active_tick=Callable();var source=target.hits.filter(func(h):return h[1]==64.0)
 r.clear();r.set_navigation(11,{"width":0});r.configure_kits(data);var dragoon:int=r.spawn(-1,1,8,start,200,.4);r.step(5,{});r.take_events();var e:int=r.spawn(1,0,0,Vector3(0,0,52),10000,3.9);r.apply_hit(e,{"element":"ice","status_seconds":100});var native=[];var path=[]
 var contacts=[]
 for frame in 66:
  r.step(1.0/60,{});path.append(r.unit_state(dragoon).position if r.valid(dragoon) else path[-1])
  for event in r.take_events():
   if event.kind=="landing_pulse":
    native.append([frame,event.position])
    if event.action_index==0:r.despawn(dragoon)
   if event.kind=="melee":contacts.append([frame,event.amount])
 print("DRAGOON_SOURCE_JUMP ",source," native=",native," source_path=",positions.slice(0,8)," native_path=",path.slice(0,8))
 print("DRAGOON_JUMP_GROUND_CONTACTS ",contacts)
 check(not source.is_empty() and native.size()==3,"Source and native later leaps both jump upward before a three-pulse landing")
 if source.size()>=3 and native.size()==3:check(range(3).all(func(i):return source[i][0]==native[i][0]),"Later leap landing and both delayed pulse frames match the original real-physics controller")
 check(path[0].y>start.y and absf(path[0].y-positions[0].y)<.001,"The later leap uses the original jump launch velocity instead of a replacement arc")
 await f.close();f.queue_free();await process_frame
func actual_solids(r):
 var world=Node3D.new();root.add_child(world)
 var art=load("res://scripts/forest/forest_art.gd");art.solid(world,Vector3(0,4.5,0),Vector3(16,1,8))
 world.rotation.y=.4;await physics_frame
 var faces:PackedVector3Array=r.static_collision_faces(world)
 check(faces.size()==36,"Actual transformed BoxShape collision exports twelve triangles")
 r.clear();r.set_navigation(6,{"width":0,"air_faces":faces})
 var target:int=r.spawn(8,0,0,Vector3(0,5,0),10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});var dragoon:int=r.spawn(-8,1,8,Vector3(0,17.12,0),200,.4);r.step(.6,{})
 check(absf(r.unit_state(dragoon).position.y-4.976)<.002,"A real scenery roof can catch the capsule without a fake ground-nav obstacle")
 world.queue_free();await process_frame
 world=Node3D.new();root.add_child(world);art.solid(world,Vector3(0,10,6),Vector3(8,20,.2));await physics_frame
 r.clear();r.set_navigation(7,{"width":0,"air_faces":r.static_collision_faces(world)})
 target=r.spawn(9,0,0,Vector3.ZERO,10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});dragoon=r.spawn(-9,1,8,Vector3(0,12.12,12),200,.4);r.step(1.2,{})
 var contacts=r.take_events().filter(func(e):return e.kind=="landing_pulse")
 var p:Vector3=contacts[0].position if not contacts.is_empty() else r.unit_state(dragoon).position
 print("DRAGOON_WALL_LANDING ",p)
 check(absf(p.x)<.001 and p.z>=6.47 and absf(p.y)<.05,"A committed drop slides down a real wall and lands on its own side")
 check(contacts.size()==3,"Wall contact cannot replay or prematurely activate the landing")
 check(is_equal_approx(r.unit_state(target).hp,10000),"A real scenery wall blocks landing-pulse damage to a soldier on the other side")
 var body=StaticBody3D.new();world.add_child(body);var collision=CollisionShape3D.new();var hull=ConvexPolygonShape3D.new()
 hull.points=PackedVector3Array([Vector3(-2,0,-2),Vector3(2,0,-2),Vector3(2,0,2),Vector3(-2,0,2),Vector3(-2,5,-2),Vector3(2,5,-2),Vector3(2,5,2),Vector3(-2,5,2)]);collision.shape=hull;body.add_child(collision);body.position=Vector3(24,0,0)
 await physics_frame;r.clear();r.set_navigation(9,{"width":0,"air_faces":r.static_collision_faces(world)})
 target=r.spawn(10,0,0,Vector3(24,5,0),10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});dragoon=r.spawn(-10,1,8,Vector3(24,17.12,0),200,.4);r.step(.6,{})
 check(absf(r.unit_state(dragoon).position.y-4.976)<.002,"Actual convex rampart collision exports a supporting hull without flattening its height")
 body=StaticBody3D.new();world.add_child(body);collision=CollisionShape3D.new();var mesh=ConcavePolygonShape3D.new();mesh.set_faces(PackedVector3Array([Vector3(-4,6,-4),Vector3(-4,6,4),Vector3(4,6,-4),Vector3(4,6,-4),Vector3(-4,6,4),Vector3(4,6,4)]));collision.shape=mesh;body.add_child(collision);body.position=Vector3(-24,0,0)
 await physics_frame;r.clear();r.set_navigation(10,{"width":0,"air_faces":r.static_collision_faces(world)})
 target=r.spawn(11,0,0,Vector3(-24,6,0),10000,3.9);r.apply_hit(target,{"element":"ice","status_seconds":100});dragoon=r.spawn(-11,1,8,Vector3(-24,18.12,0),200,.4);r.step(.6,{})
 check(absf(r.unit_state(dragoon).position.y-5.976)<.002,"Actual triangulated scenery collision preserves its elevated landing surface")
 world.queue_free();await process_frame
func source_drop():
 var f=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(f);var game=await f.make_game("original")
 f.clear_targets();var target=f.add_target(Vector3(0,0,52));var row=game.model.enemies[target.forest_id];row.hp=10000;row.max_hp=10000;target.hp=10000;target.max_hp=10000
 game.character_tuning["dragoon"]={"critical_chance":0.0}
 var unit=game.explorer_helpers.pool.filter(func(u):return u.kit_id==8)[0]
 unit.summon(target,Vector3(0,12.12,52),0);unit.set_physics_process(false);unit.think_left=0
 var clock={"frame":0};target.trace_clock=clock
 f.active_tick=func(dt):unit._physics_process(dt);original_positions.append(unit.global_position);clock.frame+=1
 await f.advance(1.0);f.active_tick=Callable();original_hits=target.hits.duplicate(true)
 print("DRAGOON_SOURCE_DROP ",original_hits," positions=",original_positions.slice(0,22))
 check(original_hits.size()==3,"Unchanged real-physics source produces three opening pulses")
 await f.close();f.queue_free();await process_frame
func finish():print("ARMY_DRAGOON_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
