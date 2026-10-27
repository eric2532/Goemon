extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Desktop launcher: identical scene/counts for old soldiers and mixed enemies.
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const Visual=preload("res://scripts/forest/forest_thirstquencher_visual.gd")
const OUT="res://build/Other Files/Asset Toolkit/Gorilla and Wolf/"
var r
var renderer
func capture(name_:String):
 await frames(3);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+name_+".png")
 print("MONSTER_CAPTURE ",name_)
func populate(kinds:Array,count:int):
 r.clear();renderer.clear();r.set_navigation(900+count,{"width":0,"origin":Vector3(-240,0,-240)})
 for i in count:
  var kind:int=kinds[i%kinds.size()];var point=ORIGIN+Vector3((i%16-7.5)*4,0,-floori(i/16)*4)
  var hp:float=game.model.waves.role_stats(kind).hp
  r.spawn(i+1,0,kind,point,hp,Roles.footprint_radius(kind))
  r.spawn(-i-1,1,12,point+Vector3(0,0,-1.6),1000000,.3)
func measure(kinds:Array)->Dictionary:
 populate(kinds,240)
 for i in 90:
  r.step(1.0/60,{});renderer.present(r.render_snapshot(),r.take_events());renderer.presentation.tick(1.0/60);await process_frame
 var frames_ms=[];var native_ms=[];var resources_before=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var nodes_before=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 for i in 300:
  var before=Time.get_ticks_usec();r.step(1.0/60,{});native_ms.append((Time.get_ticks_usec()-before)/1000.0)
  renderer.present(r.render_snapshot(),r.take_events());renderer.presentation.tick(1.0/60);await process_frame
  frames_ms.append(root.get_process_delta_time()*1000)
 frames_ms.sort();native_ms.sort()
 return {"enemy_count":240,"target_count":240,"frame_ms_p95":frames_ms[285],"frame_ms_p99":frames_ms[297],"native_step_ms_p95":native_ms[285],"native_step_ms_p99":native_ms[297],"node_growth":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes_before,"resource_growth":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources_before,"batches":renderer.counts().batches,"rendered_units":renderer.counts().units}
func run():
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.explorer_helpers.set_process(false);game.player.set_physics_process(false);game.player.invuln=100000
 game.training_dummy.hide();game.player.position=ORIGIN+Vector3(0,0,10)
 r=game.army_runtime;renderer=game.crowd.army
 r.clear();renderer.clear();game.model.enemies.clear();r.set_navigation(899,{"width":0})
 var lineup=[0,Roles.VAMBEE,Roles.HAYA_WOLF,Roles.SLOW_GUY,1,3]
 var vambee_id=-1
 for i in lineup.size():
  var kind:int=lineup[i];var point=ORIGIN+Vector3((i-2)*4.0,0,-4)
  var row:Dictionary=game.model.waves.spawn_enemy(kind,point);r.import_arrivals()
  if kind==Roles.VAMBEE:vambee_id=row.id
  var handle:int=r.handles[row.id]
  r.set_pose(handle,point,PI)
 game.camera_rig.camera.global_position=ORIGIN+Vector3(13,10,22);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1,-4));game.camera_rig.camera.fov=48
 for x in range(-10,11):
  for z in range(-10,11):game.model.visible_cells[game.model.cell_of(ORIGIN)+Vector2i(x,z)]=true
 renderer.present(r.render_snapshot(),[]);await capture("enemy_lineup")
 var snapshot:Dictionary=r.render_snapshot()
 for index in snapshot.kinds.size():
  var kind:int=snapshot.kinds[index]
  if kind not in [Roles.VAMBEE,Roles.HAYA_WOLF,Roles.SLOW_GUY]:continue
  var data:Resource=Visual.data(kind);var semantic:Dictionary=data.get_meta("semantics");var clips:Dictionary=data.get_meta("clips")
  var key:String=semantic.grab if kind==Roles.VAMBEE else semantic.attack[0]
  snapshot.pose_rows[index]=clips[key].rows[13 if kind==Roles.VAMBEE else 15]
 renderer.present(snapshot,[]);await capture("original_attacks")
 var handle:int=r.handles[vambee_id];r.apply_hit(handle,{"amount":100000})
 check(r.unit_state(handle).kind==Roles.VAMBEE_TORSO and game.actors[vambee_id].variant==Roles.VAMBEE_TORSO and game.model.enemies[vambee_id].variant==Roles.VAMBEE_TORSO,"Native form change updates the real gameplay facade and model through shared damage events")
 check(is_equal_approx(game.actors[vambee_id].combat_bounds().size.y,1.152),"The crawling form updates the real player/projectile contact shape")
 renderer.present(r.render_snapshot(),r.presentation_events);r.presentation_events.clear();await capture("vambee_split")
 game.camera_rig.camera.global_position=ORIGIN+Vector3(55,58,65);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1,-28));game.camera_rig.camera.fov=52
 var baseline=await measure([0,1,3,Roles.VAMBEE,Roles.HAYA_WOLF]);var mixed=await measure(Roles.WAVE_TYPES)
 await capture("mixed_240")
 var report={"renderer":RenderingServer.get_current_rendering_method(),"baseline":baseline,"mixed":mixed,"gameplay_checks":checks,"failures":failures,"notes":"Fresh desktop rendered comparison in the same original painterly map, camera and fixed 240 enemies plus 240 inert native targets. Includes repeated simultaneous attacks and normal pooled effect/audio updates. Background application activity is not controlled; excludes long-session stability and full 2000-vs-2000 army stress."}
 var file=FileAccess.open(OUT+"rendered-check.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();print("MONSTER_RENDERED_CHECK ",report)
 game.sound_library.cancel();game.music.stop();game.move_audio.stop();game.queue_free();game=null;r=null;renderer=null;current_scene=null;paused=false
 await frames(3);quit()
