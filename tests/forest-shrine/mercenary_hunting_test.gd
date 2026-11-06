extends SceneTree
## Exercise paid recruits through the real Wind Meadow navigation and presentation.
var game
var army
var units=[]
var checks=0
var failures=0
var step_ms=[]
var output="res://build/Other Files/Castle Defense AI/"
var cfg="user://mercenary-hunting-%d.cfg"%OS.get_process_id()
func _initialize():
 set_meta("forest_painterly_preview",true)
 if "--large" in OS.get_cmdline_user_args():set_meta("forest_custom_layout",JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/forest_wind_meadow_large.json")))
 output+=("large" if "--large" in OS.get_cmdline_user_args() else "standard")+("-baseline" if "--baseline" in OS.get_cmdline_user_args() else "-final")
 DirAccess.make_dir_recursive_absolute(output)
 create_timer(300).timeout.connect(func():printerr("FAIL: mercenary defense timeout");quit(1))
 run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func advance(ticks:int):
 for i in ticks:
  var started=Time.get_ticks_usec()
  army.integration_tick(1.0/60)
  step_ms.append((Time.get_ticks_usec()-started)/1000.0)
  if i%12==0:
   army.flush_presentation()
   await process_frame
func foe(point:Vector3)->int:
 var row=game.model.waves.spawn_enemy(0,point);row.hp=1000000;row.max_hp=row.hp
 army.import_arrivals()
 var handle:int=army.handles[row.id]
 army.apply_hit(handle,{"element":"ice","status_seconds":1000})
 return handle
func capture(label_:String,point:Vector3):
 if DisplayServer.get_name()=="headless":return
 game.camera_rig.camera.global_position=point+Vector3(25,55,45)
 game.camera_rig.camera.look_at(point+Vector3.UP*2)
 army.flush_presentation()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/"+label_+".png")
func run():
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game
 for i in 5:await process_frame
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.crowd.set_process(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 game.camera_rig.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;game.camera_rig.camera.fov=63
 game.ui.hide();root.title="Goemon · Mercenary castle defense"
 army=game.army_runtime;army.set_process(false);army.record_events=true
 var h=game.explorer_helpers;game.model.gold=5000;game.model.starting_food=100
 for slot in 5:check(h.request(slot),"Recruit "+h.NAMES[slot]+" through the current purchase path")
 units=h.active_units();check(units.size()==5,"All five paid kits own native units")
 game.model.phase="wave";game.paused=false;paused=false;h.begin_wave()
 await advance(30)
 check(units.all(func(u):return u.position.distance_to(u.guard_post)<.25),"Without enemies recruits wait at their preparation posts")
 var point:Vector3=game.model.waves.routes.exit_point(game.model.portals[0],0)
 point.y=game.model.surface_height(point.x,point.z)
 check(Vector2(point.x-h.guard_center().x,point.z-h.guard_center().z).length()>h.guard_radius(),"Enemy entrance stays outside the four-hill defense area")
 var enemy=foe(point)
 await advance(120)
 check(units.all(func(u):return army.unit_state(u.handle).target_id!=army.unit_state(enemy).logical_id and u.position.distance_to(u.guard_post)<.25),"All five kits ignore distant enemies and hold the castle")
 army.despawn(enemy)
 # Fight on the open inner feet of each of the four authored hills.
 var scale_:float=game.model.terrain_scale
 for hill in [Vector3(-105,0,-90),Vector3(105,0,-87),Vector3(-105,0,90),Vector3(105,0,90)]:
  var lawn:Vector3=(hill-hill.normalized()*45)*scale_;lawn.y=game.model.surface_height(lawn.x,lawn.z)
  check(Vector2(lawn.x,lawn.z).length()<h.guard_radius(),"Hill approach belongs to the defense area")
  enemy=foe(lawn)
  await advance(30)
  check(units.all(func(u):return army.unit_state(u.handle).target_id==army.unit_state(enemy).logical_id),"All five acquire a reachable enemy at the hill approach")
  for batch in 24:
   await advance(600)
   if units.all(func(u):return army.event_log.any(func(e):return e.kind=="damage" and e.source_id==u.gate_id)):break
   if not army.valid(enemy):enemy=foe(lawn)
  for unit in units:check(army.event_log.any(func(e):return e.kind=="damage" and e.source_id==unit.gate_id),h.NAMES[unit.slot]+" reaches combat in the defensive area")
  await capture("hill-%d-%d"%[hill.x,hill.z],lawn)
  army.despawn(enemy)
  # Clear per-hill event history so every approach must deliver fresh damage.
  army.event_log.clear()
 # A live enemy leaving the area must be released, just like a dead target.
 enemy=foe(game.model.center(game.model.shrine())+Vector3(18,0,0))
 army.set_pose(enemy,point,0)
 for batch in 24:
  await advance(600)
  if units.all(func(u):return u.position.distance_to(u.guard_post)<1):break
 check(units.all(func(u):return army.unit_state(u.handle).target_id!=army.unit_state(enemy).logical_id and u.position.distance_to(u.guard_post)<1),"All five release an escaped enemy and return to their castle posts")
 army.despawn(enemy)
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 await advance(600)
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated idle searches retain no additional nodes or resources")
 game.model.phase="preparing";h.rest()
 check(units.all(func(u):return u.state=="prepared" and u.position==u.guard_post),"Preparation restores all five placement positions")
 step_ms.sort()
 var report={"checks":checks,"failures":failures,"steps":step_ms.size(),"step_p95_ms":step_ms[int(step_ms.size()*.95)],"step_max_ms":step_ms[-1],"node_delta":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes,"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources}
 var file=FileAccess.open(output+"/results.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("MERCENARY_DEFENSE_RESULT ",JSON.stringify(report))
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false
 for i in 3:await process_frame
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
