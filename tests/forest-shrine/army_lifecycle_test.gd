extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture)
 # Fixture defaults stay legacy for original-controller comparison suites.
 var game=await fixture.make_game("original")
 var exposed=game.get_property_list().any(func(p):return p.name=="army_runtime")
 check(exposed,"Game exposes the staged army lifecycle owner")
 if not exposed:
  await fixture.close();fixture.queue_free();await process_frame;finish();return
 await fixture.close();fixture.queue_free();await process_frame
 set_meta("forest_army_backend","native");set_meta("forest_fighter",11)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://army-lifecycle.cfg";root.add_child(game)
 await process_frame;await process_frame;game.set_physics_process(false);game.set_process(false)
 var army=game.army_runtime;check(is_instance_valid(army),"Native mode constructs one shared runtime")
 if army==null:finish();return
 check(game.explorer_helpers.pool.all(func(u):return not u is Hero),"Native preparation guards never instantiate playable Hero controllers")
 check(game.explorer_helpers.COUNTS==[1,1,1,1,1],"Current paid guard quantities are preserved")
 var guards=game.explorer_helpers
 var unit=guards.pool[0];unit.summon(null,Vector3(0,.12,12),0)
 check(unit.state=="prepared" and army.valid(unit.handle),"Prepared guards already own independent native health")
 var h:int=unit.handle;army.apply_hit(h,{"amount":10.0,"direction":Vector3.BACK})
 var hp:float=army.unit_state(h).hp
 guards.rest();check(unit.hp==hp and unit.state=="prepared","Rest preserves guard survivors and HP")
 game.model.phase="wave";game.paused=false;paused=false;guards.begin_wave()
 check(unit.state=="acting" and army.unit_state(h).age==0,"Wave start resets opening age without replacing survivor ownership")
 game.model.waves.pending=999;game.model.waves.spawn_clock=10000
 var data:Dictionary=game.model.waves.spawn_enemy(0,Vector3(0,0,40))
 army.integration_tick(1.0/60)
 check(army.handles.has(data.id) and game.actors[data.id] is Ninja,"Each arrival creates one lightweight compatible enemy target")
 var enemy:int=army.handles[data.id];var first:Dictionary=army.unit_state(enemy)
 game.model.tick(.1,game.player.position)
 check(army.unit_state(enemy).position==first.position,"World lifecycle never runs a second legacy enemy movement authority")
 var clock:float=army.unit_state(h).pose_time
 for field in ["ordinary_pause","settings_open","rogue_roster_open","transitioning"]:
  game.set(field,true);army.integration_tick(.2);game.set(field,false)
  check(army.unit_state(h).pose_time==clock,"NPC clocks stop during "+field)
 var voice=game.crowd.army.presentation.voices[0];voice.play();game.paused=true
 await process_frame
 check(not voice.playing,"Pause stops pooled gunshot voices even while physics integration is blocked")
 game.paused=false
 game.map_editor.active=true;army.integration_tick(.2);game.map_editor.active=false
 check(army.unit_state(h).pose_time==clock,"Map editing freezes native action clocks")
 game.paused=true;army.integration_tick(.2);game.paused=false
 check(army.unit_state(h).pose_time==clock,"Ordinary simulation pause freezes native action clocks")
 game.playing=false;army.integration_tick(.2);game.playing=true
 check(army.unit_state(h).pose_time==clock,"Title/cleanup state cannot continue NPC clocks")
 game.model.phase="preparing";army.integration_tick(.2)
 check(army.unit_state(h).pose_time==clock,"Preparation does not consume an opening move")
 game.model.phase="wave";army.integration_tick(.2)
 check(army.unit_state(h).pose_time>clock+.19,"Active combat consumes the complete physics delta")
 # The real game coordinator advances even when the20Hz world gate returns early.
 for i in 128:game.model.waves.spawn_enemy([0,1,3][i%3],Vector3(90+(i%16)*10,0,90+(i/16)*10))
 game.world_step_elapsed=0
 var step_count:int=army.simulation_steps;var world_count:int=game.model_tick_serial;var before_clock:float=army.unit_state(h).pose_time
 game._physics_process(.01);game._physics_process(.01)
 check(army.simulation_steps==step_count+2 and game.model_tick_serial==world_count,"Every physics call runs native combat once before a20Hz world early return")
 check(absf(army.unit_state(h).pose_time-before_clock-.02)<.00001,"World throttling never drops native NPC simulation time")
 var bunker=game.model.buildings.values().filter(func(b):return b.kind=="barracks")
 if bunker.is_empty():
  game.model.phase="preparing";game.model.gold=5000;var built=game.model.build("barracks",Vector2i(12,10),0);game.model.phase="wave"
  bunker=[built]
 if not bunker[0].is_empty():
  var shelter_unit=guards.pool[1];shelter_unit.summon(null,game.model.point(game.model.entry(bunker[0])),0)
  army.apply_hit(shelter_unit.handle,{"amount":80.0,"direction":Vector3.BACK});army.integration_tick(1.0/60)
  var hidden=army.unit_state(shelter_unit.handle)
  check(hidden.get("shelter_mode",0)==2,"A critically hurt guard enters the existing reachable barracks shelter")
  if hidden.get("shelter_mode",0)==2:
   check(not army.apply_hit(shelter_unit.handle,{"amount":1000.0}).accepted,"Sheltered native fighter is protected from damage")
   var before_hp:float=hidden.hp;army.integration_tick(.5)
   check(absf(army.unit_state(shelter_unit.handle).hp-before_hp-5)<.001,"Shelter heals ten independent native HP per second")
   for tick in 600:
    army.integration_tick(1.0/60)
    if army.unit_state(shelter_unit.handle).get("shelter_mode",2)!=2:break
   check(army.unit_state(shelter_unit.handle).hp==100 and army.unit_state(shelter_unit.handle).get("shelter_mode",2)!=2,"Full health returns a surviving native fighter toward its assigned post")
   army.apply_hit(shelter_unit.handle,{"amount":80.0,"direction":Vector3.BACK});army.integration_tick(1.0/60)
   var sheltered_before:float=army.unit_state(shelter_unit.handle).hp
   game.model.phase="preparing";guards.rest();army.preparation_tick(1)
   check(absf(army.unit_state(shelter_unit.handle).hp-sheltered_before-10)<.001 and shelter_unit.state=="sheltered","Sheltered survivors keep healing through preparation without losing identity")
   var healthy:float=army.unit_state(shelter_unit.handle).hp;game.ordinary_pause=true;army.preparation_tick(2);game.ordinary_pause=false
   check(army.unit_state(shelter_unit.handle).hp==healthy,"Pausing preparation also freezes shelter healing")
   game.model.phase="wave";game.model.damage_building(bunker[0].id,100000);game.model.phase="preparing";army.preparation_tick(.1)
   check(army.unit_state(shelter_unit.handle).get("shelter_mode",2)!=2 and shelter_unit.targetable,"Destroying a barracks ejects its surviving native fighter")
   game.model.phase="wave"
 army.rest();check(army.unit_state(h).hp==hp,"Native rest retains the same surviving health")
 army.clear();check(army.snapshot().handles.is_empty(),"Restart cleanup removes all native targets")
 var managed=load("res://scripts/forest/crowd/army_runtime.gd").new();managed.configure(null);managed.set_navigation(1,{"width":0});managed.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model))
 var waiting:int=managed.spawn(-10,1,7,Vector3.ZERO,500,.4);managed.native.set_guard(waiting,Vector3.ZERO,18)
 managed.step(1,{})
 check(managed.unit_state(waiting).buff_left==0 and managed.unit_state(waiting).age==0,"A prepared Knight waits for a local guard target before consuming its opening Code")
 managed.spawn(10,0,0,Vector3(0,0,8),10000,3.9);managed.step(.4,{})
 check(managed.unit_state(waiting).buff_left>7.5,"Local target activation starts the original Knight opening")
 managed.clear();var spear:int=managed.spawn(-10,1,8,Vector3.ZERO,200,.4);managed.native.set_guard(spear,Vector3.ZERO,18)
 managed.spawn(10,0,0,Vector3(0,0,8),10000,3.9);managed.step(1.0/60,{})
 check(managed.unit_state(spear).position.y>11.9,"Managed Dragoon opening begins from the source twelve-metre appearance height")
 managed.clear();managed.free()
 var routes=load("res://scripts/forest/crowd/army_runtime.gd").new();routes.configure(null)
 routes.set_navigation(1,{"width":0,"bounds_min":Vector3(-3,0,-12),"bounds_max":Vector3(3,0,12),"obstacle_min":PackedVector3Array([Vector3(-3,0,-1)]),"obstacle_max":PackedVector3Array([Vector3(3,10,1)]),"friendly_navigation":true,"friendly_obstacle_min":PackedVector3Array([Vector3(-3,0,-1),Vector3(2,0,-1)]),"friendly_obstacle_max":PackedVector3Array([Vector3(-2,10,1),Vector3(3,10,1)])})
 var enemy_route:int=routes.spawn(1,0,0,Vector3(0,0,-4),100,.4);var ally_route:int=routes.spawn(-1,1,11,Vector3(0,0,-4),100,.4)
 routes.step(2,{"goal_handles":PackedInt64Array([enemy_route,ally_route]),"goal_positions":PackedVector3Array([Vector3(0,0,5),Vector3(0,0,5)]),"goal_speeds":PackedFloat32Array([5,5])})
 check(routes.unit_state(enemy_route).position.z<-1 and routes.unit_state(ally_route).position.z>4,"Friendly ground navigation passes the gate opening while enemies obey its closed door")
 routes.clear();routes.free()
 var retreat=load("res://scripts/forest/crowd/army_runtime.gd").new();retreat.configure(null);retreat.set_navigation(1,{"width":0});retreat.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model))
 var runner:int=retreat.spawn(-1,1,10,Vector3.ZERO,100,.4);retreat.native.set_guard(runner,Vector3.ZERO,18)
 retreat.apply_hit(runner,{"amount":80.0,"direction":Vector3.BACK})
 var bunker_context={"targets":{"ids":PackedInt64Array(),"kinds":PackedInt32Array(),"positions":PackedVector3Array(),"hp":PackedFloat32Array(),"shelter_ids":PackedInt64Array([1]),"shelter_entrances":PackedVector3Array([Vector3(10,0,0)]),"shelter_centers":PackedVector3Array([Vector3(10,0,0)])}}
 retreat.step(1.0/60,bunker_context)
 check(retreat.unit_state(runner).shelter_mode==1 and not retreat.apply_hit(runner,{"amount":1.0,"direction":Vector3.BACK}).accepted,"Starting a retreat preserves the existing brief incoming-hit immunity")
 retreat.clear();retreat.free()
 var collision=army.static_collision_data(game.world)
 check(collision.faces.size()==collision.owners.size()*3 and Array(collision.owners).any(func(id):return id>=0),"True static triangles retain owner IDs for target-building cover")
 game.queue_free();await process_frame;finish()
func finish():print("ARMY_LIFECYCLE_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
