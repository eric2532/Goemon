extends SceneTree
## Current recovering-bunker attacks must remain independent in the crowd port.
var checks=0
var failures=0
var game
var bunker:Dictionary
var army
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func step(seconds:float):
 for i in ceili(seconds*60):army.integration_tick(1.0/60)
func reset(slot:int):
 game.explorer_helpers.clear();army.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
 game.model.phase="wave";game.paused=false;paused=false
 var u=game.explorer_helpers.make_unit(slot);var entrance:Vector3=game.model.point(game.model.entry(bunker))
 u.summon(null,entrance,0);army.apply_hit(u.handle,{"amount":u.max_hp-20.0})
 army.set_pose(u.handle,entrance,0);army.integration_tick(1.0/60);army.integration_tick(1.0/60)
 return u
func target(offset:Vector3):
 var row=game.model.waves.spawn_enemy(0,game.model.center(bunker)+offset);row.hp=10000;row.max_hp=row.hp
 game.model.visible_cells[game.model.cell_of(row.pos)]=true
 army.import_arrivals();army.apply_hit(army.handles[row.id],{"element":"ice","status_seconds":100})
 return army.handles[row.id]
func obstacle(offset:Vector3,size_:Vector3):
 var body=StaticBody3D.new();body.collision_layer=1
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size_;shape.shape=box;body.add_child(shape);game.world.add_child(body)
 body.global_position=game.model.center(bunker)+offset;game.model.navigation_revision+=1
 return body
func add_occupant(slot:int):
 var unit=game.explorer_helpers.make_unit(slot);var entrance:Vector3=game.model.point(game.model.entry(bunker))
 unit.summon(null,entrance,0);army.apply_hit(unit.handle,{"amount":unit.max_hp-20.0});army.set_pose(unit.handle,entrance,0);step(.04)
 return unit
func run():
 set_meta("forest_army_backend","native")
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://army-bunker-%d.cfg"%OS.get_process_id();root.add_child(game)
 for i in 3:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.crowd.set_process(false)
 for u in game.gate_defenders.units.values():u.set_physics_process(false)
 game.model.gold=5000;bunker=game.model.build("barracks",Vector2i(12,10),0);game.world.sync(0)
 army=game.army_runtime;army.record_events=true;game.tuning.critical_chance=0
 for slot in [1,2]:
  var u=reset(slot);var enemy=target(Vector3(0,0,20));step(1.0)
  check(u.state=="sheltered" and u.hp>20,"Native ranged occupant heals while sheltered")
  check(army.event_log.any(func(e):return e.kind=="bullet" and e.source_id==u.gate_id),"Sheltered kit%d emits its own native weapon"%u.kit_id)
  check(army.unit_state(enemy).hp<10000,"Sheltered kit%d damages a real fitted enemy outside the bunker"%u.kit_id)
  var hp:float=army.unit_state(enemy).hp;game.ordinary_pause=true;step(.5);game.ordinary_pause=false
  check(army.unit_state(enemy).hp==hp,"Pause freezes native bunker firing")
  game.model.phase="preparing";game.explorer_helpers.rest();var count:int=army.render_snapshot().projectile_ids.size();army.preparation_tick(.1)
  check(count==0 and army.render_snapshot().projectile_ids.is_empty(),"Preparation cancels native bunker projectiles")
 var explorer=reset(4);var near=target(Vector3(0,0,11));step(.5)
 check(army.unit_state(near).hp==10000,"Native sheltered Explorer waits for a building hit")
 game.model.damage_building(bunker.id,20);bunker.hp=bunker.max_hp;step(.8)
 check(army.unit_state(near).hp<10000,"Native sheltered Explorer counter-slashes after a repaired bunker hit")
 var dragoon=reset(0);var enemy=target(Vector3(0,0,20))
 check(dragoon.visible and dragoon.position.y>game.model.center(bunker).y+5.9,"Native recovering Dragoon stands on the original bunker deck")
 var leaped=false
 var takeoff=false
 var takeoff_time=-1.0
 var takeoff_advanced=false
 for i in 360:
  army.integration_tick(1.0/60)
  if int(army.unit_state(dragoon.handle).get("shelter_mode",0))==4:leaped=true
  var snapshot:Dictionary=army.render_snapshot();var index:int=snapshot.handles.find(dragoon.handle)
  if index>=0 and snapshot.air_phase[index]==5:
   if not takeoff:
    var clip:Dictionary=game.crowd.army.resources[8].get_meta("clips").jump
    var expected:float=game.crowd.army.clip_row(clip,snapshot.render_time[index])
    check(absf(game.crowd.army.pose_sample(snapshot,index).r-expected)<.001,"Bunker takeoff uses the original ordinary jump pose before Dragon Leap")
    takeoff=true;takeoff_time=snapshot.render_time[index]
   elif snapshot.render_time[index]>takeoff_time:takeoff_advanced=true
  if army.unit_state(enemy).hp<10000:break
 check(takeoff and takeoff_advanced,"Bunker jump animation advances with every actual takeoff physics tick")
 check(leaped and army.unit_state(enemy).hp<10000,"Native deck Dragoon executes Dragon Leap and real landing damage")
 # Shared shelter must retain independent casts, chains and population slots.
 var first=reset(1);var second=add_occupant(1);var shared=target(Vector3(0,0,20));step(1.0)
 check([first,second].all(func(u):return army.event_log.any(func(e):return e.kind=="bullet" and e.source_id==u.gate_id)),"Two recovering Rangers each own their outgoing arrows")
 check(army.unit_state(first.handle).chain_count>0 and army.unit_state(second.handle).chain_count>0,"Both recovering Rangers receive independent chain credit")
 game.explorer_helpers.sync_targets()
 check(game.model.fighter_count==2,"Both protected occupants retain their food and identity")
 var wall=obstacle(Vector3(0,6,14),Vector3(24,12,1));step(3.0)
 var before:float=army.unit_state(shared).hp;step(.5)
 check(army.unit_state(shared).hp==before and army.render_snapshot().projectile_ids.is_empty(),"Solid cover blocks bunker target selection and drains earlier arrows")
 check(army.unit_state(first.handle).chain_count==0 and army.unit_state(second.handle).chain_count==0,"Blocked bunker fire expires both original chain grace periods")
 wall.queue_free();game.model.navigation_revision+=1;step(.8)
 check(army.unit_state(shared).hp<before,"Removing cover resumes real bunker fire")
 game.model.phase="preparing";game.explorer_helpers.rest();army.preparation_tick(20)
 check(first.state=="prepared" and second.state=="prepared" and first.hp==first.max_hp and second.hp==second.max_hp,"Full passive recovery leaves no firing state or hidden fighter")
 # A blocked deck launch must recover without crossing the parapet on foot.
 dragoon=reset(0);enemy=target(Vector3(0,0,20));var ceiling=obstacle(Vector3(0,9.3,0),Vector3(20,.5,20));step(6.5)
 check(dragoon.state=="sheltered" and dragoon.visible and dragoon.hp>20,"A blocked launch returns the surviving Dragoon to protected deck recovery")
 ceiling.queue_free();game.model.navigation_revision+=1
 dragoon=reset(0);enemy=target(Vector3(0,0,20));step(.5)
 check(dragoon.state=="bunker_leaping","Destruction fixture reaches a real active deck leap")
 game.model.damage_building(bunker.id,100000);game.world.sync(0);step(7)
 check(dragoon.state in ["acting","returning"] and dragoon.visible,"A destroyed bunker cannot strand a leaping survivor")
 game.model.phase="preparing";game.explorer_helpers.rest();army.preparation_tick(.01)
 check(dragoon.state=="prepared" and dragoon.position==dragoon.guard_post and army.render_snapshot().projectile_ids.is_empty(),"Wave end restores the survivor's preparation placement and clears casts")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 print("ARMY_BUNKER_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
