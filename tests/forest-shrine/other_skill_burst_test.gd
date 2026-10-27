extends "res://tests/forest-shrine/dark_lumina_3_test.gd"
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const EVIDENCE=OUT+"Wind Burst/"
const SKILLS=["dark-lumina-3/water","dark-lumina-3/fire","dark-lumina-3/sky","dark-lumina-2/fireballs","kojiro/homing","kojiro/wind","sasuke/hail","yae/lock-on","ben/bombs","ed/fireballs"]
var launches=0
var report=[]
func run():
 create_timer(180).timeout.connect(func():printerr("OTHER_SKILL_BURST_TIMEOUT");quit(1))
 set_meta("forest_painterly_preview",true);root.size=Vector2i(1280,800);await setup_fixture()
 var visual=DisplayServer.get_name()!="headless"
 if visual:root.set_flag(Window.FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground()
 Engine.max_fps=60 if visual else 0
 game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
 game.player.set_process_input(false);game.player.set_process_unhandled_input(false);game.camera_rig.set_process_unhandled_input(false)
 game.model.phase="wave";game.tuning.invincible=true;game.ui.hide()
 game.training_dummy.home=ORIGIN+Vector3(100,0,0);game.training_dummy.position=game.training_dummy.home;game.training_dummy.hide()
 for i in 240:
  var row=game.model.waves.spawn_enemy([0,1,3,6,9,16][i%6],ORIGIN+Vector3((i%20-9.5)*2.5,0,-5-(i/20)*2.5));row.hp=1000000;row.max_hp=row.hp
 game.army_runtime.import_arrivals();game.army_runtime.native.set_navigation({})
 game.camera_rig.camera.position=ORIGIN+Vector3(35,38,65);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,3,-10))
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):shot.set_physics_process(false);launches+=1)
 for id in SKILLS:
  check(Catalog.all().has(id),"Audited skill exists: "+id)
  if not Catalog.all().has(id):continue
  var spec=Catalog.all()[id];game.player.select_character(spec.source);fresh()
  var prepared=pool.created;var misses=pool.misses;var count=launches
  var times=[];var first_release=[];var focused=0;var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
  for repeat in 2:
   fresh();game.player.position=ORIGIN+Vector3(0,0,20)
   var controller=game.player.active_ability
   if spec.method=="input":
    var event=InputEventAction.new();event.action=spec.args[0];event.pressed=true;controller.input(event)
   else:controller.callv(spec.method,spec.args)
   for tick in 240:
    game.army_runtime.native.step(1.0/60);game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
    game.crowd.army.present(game.army_runtime.latest,[])
    var before=launches;var started=Time.get_ticks_usec()
    game.player._physics_process(1.0/60)
    for nodes in pool.all.values():
     for shot in nodes:
      if shot.pool_live:shot._physics_process(1.0/60)
    var elapsed=(Time.get_ticks_usec()-started)/1000.0;times.append(elapsed)
    if launches>before:first_release.append(elapsed)
    game.crowd.army.presentation.tick(1.0/60)
    if visual:
     if DisplayServer.window_is_focused():focused+=1
     await process_frame
    elif tick%30==0:await process_frame
   controller.cancel(true)
  times.sort();first_release.sort()
  var row={"skill":id,"launches_including_trails":launches-count,"step_p95_ms":times[floori(times.size()*.95)],"step_max_ms":times[-1],"release_max_ms":first_release[-1] if not first_release.is_empty() else 0,"pool_growth":pool.created-prepared,"misses":pool.misses-misses,"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources,"focused":focused,"stepped_frames":480}
  report.append(row);print("OTHER_SKILL_BURST ",JSON.stringify(row))
  check(launches>count,"Both casts release their prepared projectiles: "+id)
  check(pool.created==prepared and pool.misses==misses,"Repeated casts stay within prepared leases: "+id)
  for nodes in pool.all.values():
   for shot in nodes:
    if shot.pool_live:shot.retire()
  game.crowd.army.presentation.effects.clear()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
 FileAccess.open(EVIDENCE+("other-skills-desktop.json" if visual else "other-skills-headless.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"skills":report,"note":"Controlled high-HP fixture. Manual player/projectile CPU samples are not full-world frame times. Selection preparation is excluded."},"  "))
 game.queue_free();await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("OTHER_SKILL_BURST_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
