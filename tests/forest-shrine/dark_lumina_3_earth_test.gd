extends "res://tests/forest-shrine/dark_lumina_3_controls_test.gd"
const EARTH_OUT=OUT+"Ground Slam/Airborne Repeats/"
var fx:Node
var waves_seen=0
var victim:Node
var damage_before=0.0
var pulse_damage=[]

func advance(count:int):
 for i in count:
  await super.advance(1)
  for effect in fx.effects:
   if effect.kind=="finale-blast" and not effect.has("earth_test_seen"):
    effect.earth_test_seen=true;waves_seen+=1
  var damage=damage_before-victim.hp
  if damage>0:pulse_damage.append(damage);damage_before=victim.hp

func reset_slam():
 fresh();fx.clear();waves_seen=0;pulse_damage.clear();damage_before=victim.hp
 game.player.impact_pause=0

func finish_slam():
 await advance(300)

func view(label_:String):
 if not visual:return
 fx.draw_effects();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(EARTH_OUT+label_+".png")

func run():
 create_timer(180).timeout.connect(func():printerr("LUMINA_EARTH_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EARTH_OUT))
 visual=DisplayServer.get_name()!="headless"
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_physics_process(false)
 game.model.phase="wave";game.tuning.invincible=true
 root.title="Goemon · Dark Lumina 3 queued ground slam"
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 if visual:root.set_flag(Window.FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground()
 var p=game.player;p.select_character(30);fresh();fx=game.crowd.army.presentation
 var owner=game.army_runtime
 owner.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear();owner.set_navigation(9432,{"width":0})
 game.training_dummy.position=Vector3(0,-100,0)
 var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3(0,0,-10));row.hp=100000;row.max_hp=100000
 owner.import_arrivals();owner.sync_targets();victim=game.actors[row.id]
 game.model.update_vision(ORIGIN);game.crowd.army.present(owner.render_snapshot(),[])
 game.ui.hide();game.forest_ui.hide()
 game.camera_rig.camera.position=ORIGIN+Vector3(75,95,100);game.camera_rig.camera.look_at(ORIGIN)
 var c=p.active_ability;var pool=Pool.service(game)
 var prepared=pool.created;var misses=pool.misses;var presentation_nodes=fx.get_child_count()
 for presses in [1,2,3,4,5,9]:
  reset_slam();key(4);await advance(6)
  var ticket=c.ticket.duplicate(true)
  for i in presses-1:
   var elapsed=c.elapsed;var velocity=p.velocity;var height=p.position.y
   key(4)
   if i<4:
    check(is_zero_approx(c.elapsed) and c.marker==0 and is_equal_approx(p.velocity.y,13),"Press %d restarts the airborne gesture and upward motion"%(i+2))
    await advance(6)
    check(p.position.y>height,"Accepted repeat physically lifts the caster")
   else:
    check(is_equal_approx(c.elapsed,elapsed) and p.velocity==velocity,"Press beyond five cannot restart or lift the caster")
    await advance(6)
  check(c.ticket==ticket,"All queued waves retain the original damage ticket")
  check(waves_seen==0 and pulse_damage.is_empty(),"No wave or damage before landing")
  if presses==5:
   var camera=game.camera_rig.camera;var wide_view=camera.transform
   camera.position=ORIGIN+Vector3(20,12,25);camera.look_at(p.position+Vector3.UP*2)
   await view("fifth-airborne-press");camera.transform=wide_view
  for i in 150:
   await advance(1)
   if c.marker>40:break
  check(p.is_on_floor() and waves_seen>0,"Earth releases on the physical landing")
  # A press after the impact cannot restart the cast or extend the locked queue.
  var elapsed=c.elapsed;key(4)
  check(is_equal_approx(c.elapsed,elapsed),"Recovery press leaves the slam running")
  if presses in [1,5]:
   await advance(75 if presses==5 else 16);await view("waves-%d"%presses)
  await finish_slam()
  var expected=mini(presses,5)
  check(waves_seen==expected,"%d presses produce exactly %d visible waves (got %d)"%[presses,expected,waves_seen])
  check(pulse_damage.size()==expected and pulse_damage.all(func(value):return is_equal_approx(value,65*Finale.DAMAGE[4])),"Each wave damages the native target exactly once at unchanged strength (got %s)"%str(pulse_damage))
  check(not c.is_attacking() and fx.effects.is_empty(),"The queued slam and its effects finish")
 # Interruptions discard the unspent queue; a later cast starts at one wave.
 for interruption in ["dodge","switch","sword"]:
  reset_slam();for i in 5:key(4)
  await advance(5)
  if interruption=="dodge":c.interrupt_for_dodge()
  elif interruption=="switch":p.select_character(1);p.select_character(30);c=p.active_ability
  else:click();c.cancel()
  await finish_slam()
  check(waves_seen==0 and pulse_damage.is_empty(),"%s discards every pending wave"%interruption)
 reset_slam();key(4);await finish_slam()
 check(waves_seen==1 and pulse_damage.size()==1,"A fresh cast never inherits the previous queue")
 # The transferable skill must use the same queue without the loadout interrupting it.
 p.select_character(1);p.spell_loadout.equip(1,"equip","dark-lumina-3/earth")
 reset_slam();key(1);await advance(6)
 var borrowed=p.spell_loadout.current.controller;var borrowed_ticket=borrowed.ticket.duplicate(true)
 for i in 7:
  var elapsed=borrowed.elapsed;var velocity=p.velocity;key(1)
  check((is_zero_approx(borrowed.elapsed) and is_equal_approx(p.velocity.y,13)) if i<4 else (is_equal_approx(borrowed.elapsed,elapsed) and p.velocity==velocity),"Borrowed Earth repeats its airborne motion only up to five presses")
  await advance(6)
 check(borrowed.ticket==borrowed_ticket,"Borrowed Earth retains its damage ticket across airborne repeats")
 await finish_slam()
 check(waves_seen==5 and pulse_damage.size()==5,"Borrowed Earth also caps at five damaging waves (waves=%d damage=%s)"%[waves_seen,str(pulse_damage)])
 p.spell_loadout.equip(1,"equip","");p.select_character(30);reset_slam()
 await advance(60)
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 3:
  reset_slam();for i in 5:key(4)
  await finish_slam()
  check(waves_seen==5 and pulse_damage.size()==5,"Repeated five-wave slam %d retains every damage pulse"%repeat)
 await advance(60)
 check(pool.created==prepared and pool.misses==misses,"Queued slams reuse existing prepared resources with no pool misses")
 check(fx.get_child_count()==presentation_nodes and Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated slams retain no nodes or resources")
 reset_slam();key(4)
 var echo=InputEventKey.new();echo.physical_keycode=KEY_4;echo.keycode=KEY_4;echo.pressed=true;echo.echo=true
 for i in 8:Input.parse_input_event(echo.duplicate());Input.flush_buffered_events()
 await finish_slam()
 check(waves_seen==1 and pulse_damage.size()==1,"Holding the key cannot turn auto-repeat into queued presses")
 reset_slam();for i in 5:key(4)
 for i in 150:
  await advance(1)
  if c.marker>40:break
 c.interrupt_for_dodge();await finish_slam()
 check(waves_seen==1 and pulse_damage.size()==1,"Interrupting after landing discards the four unreleased waves")
 reset_slam();for i in 5:key(4)
 p.position=ORIGIN+Vector3.UP*10;p.move_and_slide();c.tick(10)
 check(victim.hp==damage_before and not fx.effects.any(func(e):return e.kind=="finale-blast"),"A long airborne frame cannot release ground waves")
 p.position=ORIGIN-Vector3.UP*.11;p.velocity=Vector3.DOWN*5;p.move_and_slide()
 check(p.is_on_floor(),"Long-frame fixture reaches the physical floor")
 c.tick(10);c.tick(10)
 check(fx.effects.filter(func(e):return e.kind=="finale-blast").size()==5 and is_equal_approx(damage_before-victim.hp,5*65*Finale.DAMAGE[4]),"A long landing frame releases all five waves once without dropping or duplicating damage")
 step_times.sort();frame_times.sort()
 var report={"checks":checks,"failures":failures,"pool_created":pool.created,"pool_misses":pool.misses-misses,"presentation_nodes":fx.get_child_count(),"node_delta":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-nodes,"resource_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources,"step_p95_ms":step_times[int(step_times.size()*.95)]}
 if visual:report.frame_p95_ms=frame_times[int(frame_times.size()*.95)];report.frame_max_ms=frame_times[-1]
 var suffix="before" if "--baseline" in OS.get_cmdline_user_args() else "after"
 FileAccess.open(EARTH_OUT+("desktop-" if visual else "headless-")+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("LUMINA_EARTH_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
