extends SceneTree
class Counting extends "res://scripts/forest/crowd/army_coordinator.gd":
 var state_reads=0
 func unit_state(handle:int)->Dictionary:
  state_reads+=1;return super.unit_state(handle)
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 set_meta("forest_army_backend","legacy")
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 var game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://army-packed-%d.cfg"%OS.get_process_id();root.add_child(game)
 for i in 3:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 var army=Counting.new();game.add_child(army);game.army_runtime=army;army.setup(game)
 for i in 30:
  var row=game.model.waves.spawn_enemy([0,1,3][i%3],Vector3(i*4,3,60));army.spawn(row.id,0,row.variant,row.pos,row.hp,3.9)
  var actor=army.enemy_target(row.id);game.actors[row.id]=actor;game.enemies.append(actor)
  var handle:int=army.spawn(-1000-i,1,[11,5,7,8,10][i%5],Vector3(i*4,3,30),200,.4);army.ally_target(-1000-i)
 army.native.simulation_profile(true)
 army.profile_enabled=true
 army.state_reads=0;army.sync_compatibility()
 check(["compatibility_snapshot","compatibility_view","compatibility_facades","compatibility_cleanup"].all(func(key):return army.profile_totals.has(key) and army.profile_totals[key]>=0),"Compatibility attribution covers packed capture, typed view, facades and retirement without changing updates")
 check(army.native.simulation_profile(false).get("shared_enemy_updates",-1)==30,"Shared enemy views avoid per-unit script metadata copies while physical poses stay current")
 check(army.native.simulation_profile(false).get("shared_ally_updates",-1)==30,"Shared ally views avoid per-unit lifecycle copies while health and motion stay current")
 check(army.state_reads==0,"A packed crowd update never creates a per-unit native state Dictionary")
 var snapshot=army.latest
 check(snapshot.has("ages") and snapshot.has("shelter_modes"),"Owned packed buffers include facade lifecycle state")
 var Contact=load("res://scripts/forest/forest_enemy_contact.gd")
 for i in snapshot.handles.size():
  if snapshot.teams[i]!=0:continue
  var actor=game.actors[snapshot.logical_ids[i]]
  check(actor.position==snapshot.positions[i] and actor.hp==snapshot.hp[i],"Packed proxy retains authoritative pose and health")
  var data={"variant":snapshot.kinds[i],"pos":snapshot.positions[i],"facing":snapshot.yaw[i]}
  check(actor.combat_bounds().is_equal_approx(Contact.bounds(data)),"Lazy fitted bounds retain exact source OBB")
  var point:Vector3=actor.position+Vector3(4,2,7)
  check(actor.combat_contact_point(point).distance_to(Contact.contact(data,point))<.0001,"Lazy contact retains the original exact fitted surface")
 check(game.actors.values().all(func(actor):return actor.pose_data.is_empty() and actor.fitted_contact.is_empty()),"Soldier point contacts use their exact static OBB without allocating animation dictionaries")
 # A later native step must not mutate a snapshot retained for lazy contacts.
 var first_id:int=snapshot.logical_ids[0];var actor=game.actors[first_id]
 var old_snapshot=actor._packed
 var old_position:Vector3=old_snapshot.positions[0];var old_hp:float=old_snapshot.hp[0]
 army.set_pose(actor.handle,old_position+Vector3(2,4,6),1.234)
 army.apply_hit(actor.handle,{"amount":.125,"element":"ice","status_seconds":1.0})
 army.step(1.0/60,{})
 army.sync_compatibility()
 check(old_snapshot.positions[0]==old_position and old_snapshot.hp[0]==old_hp,"Retained contact snapshots stay immutable across native updates")
 check(actor.position==old_position+Vector3(2,4,6) and absf(actor.rotation.y-1.234)<.00001 and actor.hp==old_hp-.125,"Typed state retains exact position, facing and fractional health")
 check(actor._combat_data().frozen>0,"Lazy contact data sees status changes on the same physics step")
 army.sync_targets()
 check(actor._combat_data().frozen>0 and actor.position==old_position+Vector3(2,4,6),"Direct-state sync can safely replace packed state without stale contact fields")
 # Explicit same-frame state must win over the older global view.
 var override_point:Vector3=actor.position+Vector3(13,0,1)
 army.set_pose(actor.handle,override_point,.6);actor._sync_fitted_pose()
 check(actor._combat_data().pos==override_point and absf(actor._yaw-.6)<.00001,"Direct same-frame state cannot be replaced by an older shared view")
 army.sync_compatibility();actor._combat_data()
 var previous_view=weakref(army.snapshot_view)
 for frame in 8:
  army.set_pose(actor.handle,override_point+Vector3(frame,0,0),.6);army.sync_compatibility()
 check(previous_view.get_ref()==null,"Unqueried facades do not retain entire old army snapshots")
 var old_handle:int=actor.handle;army.despawn(old_handle)
 var replacement:Dictionary=game.model.waves.spawn_enemy(0,override_point+Vector3(25,0,0));army.import_arrivals();army.sync_compatibility()
 check(army.handles[replacement.id]!=old_handle and actor._packed==null,"A retired facade never adopts a recycled slot's newer generation")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 print("ARMY_PACKED_SYNC_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
