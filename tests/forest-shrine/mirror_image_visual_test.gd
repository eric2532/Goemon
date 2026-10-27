extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Mirrors=preload("res://scripts/warcraft_mirrors.gd")
const OUT="res://build/Other Files/Asset Toolkit/Warcraft/Mirror Image/"
var intervals=[]
var work=[]
func run():
 create_timer(120).timeout.connect(func():printerr("MIRROR_VISUAL_TIMEOUT");quit(1))
 await setup_fixture();game.tuning.invincible=true
 DirAccess.make_dir_recursive_absolute(OUT)
 var p=game.player;var army=game.army_runtime
 game.update_character_tuning(1,"model_scale",1.7)
 game.set_process_input(false);game.set_process_unhandled_input(false)
 p.set_process_input(false);p.set_process_unhandled_input(false)
 game.camera_rig.set_process_input(false);game.camera_rig.set_process_unhandled_input(false)
 game.camera_rig.yaw=PI
 var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3(0,0,-12));row.hp=1000000;row.max_hp=1000000
 army.import_arrivals();army.sync_targets();var enemy=game.actors[row.id]
 army.apply_hit(enemy.handle,{"element":"ice","status_seconds":1000.0})
 for id in [31,1,32]:
  p.select_character(id);fresh();p.facing=Vector3.BACK
  p.model.rotation.y=PI;p.model.animate(0,0,true,0,0,false,0,false)
  var mirrors=Mirrors.new(p)
  p.ai_controlled=true;p.ai_aim=ORIGIN+Vector3.BACK*100
  check(mirrors.cast(),"Open-field pursuit cast %d"%id);p.ai_controlled=false
  check(mirrors.bodies.all(func(body):return body.model.scale==p.model.scale),"All five images retain the fighter's saved size %d"%id)
  game.camera_rig.camera.position=ORIGIN+Vector3(26,30,32)
  game.camera_rig.camera.look_at(ORIGIN+Vector3(0,4,-6))
  var starts=mirrors.bodies.map(func(body):return body.global_position)
  var scattered=true
  for i in 5:
   for j in range(i+1,5):scattered=scattered and starts[i].distance_to(starts[j])>2.5
  check(scattered,"Five images spawn spread around the caster %d"%id)
  for frame in 300:
   var start=Time.get_ticks_usec()
   army.integration_tick(1.0/60)
   game.crowd.army.present(army.render_snapshot(),army.presentation_events)
   army.presentation_events.clear()
   if frame>10:work.append((Time.get_ticks_usec()-start)/1000.0)
   await physics_frame
   if frame>10:intervals.append((Time.get_ticks_usec()-start)/1000.0)
   if frame==20:
    var approaching=true
    for i in 5:approaching=approaching and mirrors.bodies[i].global_position.distance_to(enemy.global_position)<starts[i].distance_to(enemy.global_position)-.5
    check(approaching,"All five immediately pursue the enemy behind the caster %d"%id)
   if frame in [0,110,299]:
    game.forest_ui.sync()
    game.camera_rig.camera.global_position=ORIGIN+Vector3(26,30,32)
    game.camera_rig.camera.look_at(ORIGIN+Vector3(0,4,-6))
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(OUT+"scatter-%d-%d.png"%[id,frame])
  check(mirrors.bodies.any(func(body):return not body.action_history.is_empty()),"Pursuit reaches the enemy and starts original attacks %d"%id)
  var widest=0.0
  for i in 5:
   for j in range(i+1,5):widest=maxf(widest,Vector2(mirrors.bodies[i].position.x,mirrors.bodies[i].position.z).distance_to(Vector2(mirrors.bodies[j].position.x,mirrors.bodies[j].position.z)))
  check(widest>4.0,"Images remain spread while attacking a shared enemy %d"%id)
  check(mirrors.handles.size()==5,"Five copies plus caster remain visible %d"%id)
  mirrors.dispose();await frames(3)
 for offset in [Vector3(-10,0,-8),Vector3(10,0,-8),Vector3(-10,0,4),Vector3(10,0,4)]:
  var extra=game.model.waves.spawn_enemy(0,ORIGIN+offset);extra.hp=1000000;extra.max_hp=1000000
 army.import_arrivals();army.sync_targets()
 for actor in game.actors.values():army.apply_hit(actor.handle,{"element":"ice","status_seconds":1000.0})
 p.select_character(31);fresh();var crowd_mirrors=Mirrors.new(p)
 check(crowd_mirrors.cast(),"Blademaster summons into a spread-out crowd")
 for frame in 180:
  army.integration_tick(1.0/60)
  game.crowd.army.present(army.render_snapshot(),army.presentation_events);army.presentation_events.clear()
  await physics_frame
 var targets={}
 for handle in crowd_mirrors.handles:targets[army.unit_state(handle).target_id]=true
 targets.erase(0)
 check(targets.size()>=3,"Images spread across nearby enemies instead of sharing one target")
 game.forest_ui.sync();game.camera_rig.camera.global_position=ORIGIN+Vector3(32,42,36)
 game.camera_rig.camera.look_at(ORIGIN+Vector3(0,4,-4));await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+"scatter-crowd.png")
 crowd_mirrors.dispose();await frames(3)
 work.sort();intervals.sort()
 var report={"checks":checks,"failures":failures,"step_p95_ms":work[int(work.size()*.95)],"step_max_ms":work[-1],"frame_p95_ms":intervals[int(intervals.size()*.95)],"frame_max_ms":intervals[-1]}
 FileAccess.open(OUT+"scatter-desktop.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("MIRROR_VISUAL_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
