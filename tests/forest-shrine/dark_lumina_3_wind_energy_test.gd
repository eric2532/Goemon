extends "res://tests/forest-shrine/dark_lumina_3_completeness_test.gd"
const REVISION_OUT=OUT+"Wind And Energy/"
var targets=[]
class PoseProbe extends "res://scripts/forest/crowd/army_presentation.gd":
 var rows={}
 func show_rows(node:MultiMeshInstance3D,poses:Array,_custom:Array):rows[node.name]=poses
func advance(count:int):
 var previous=Time.get_ticks_usec()
 for i in count:
  var begin=Time.get_ticks_usec()
  game.army_runtime.native.step(1.0/60)
  game.army_runtime.sync_compatibility()
  game.crowd.army.present(game.army_runtime.latest,[])
  game.player._physics_process(1.0/60)
  for nodes in Pool.service(game).all.values():
   for shot in nodes:
    if shot.pool_live and shot.get_script() in [Shot,WaveShot]:shot._physics_process(1.0/60)
  game.crowd.army.presentation.tick(1.0/60)
  step_times.append((Time.get_ticks_usec()-begin)/1000.0)
  if visual:
   await physics_frame
   var now=Time.get_ticks_usec();frame_times.append((now-previous)/1000.0);previous=now
  elif i%30==0:await process_frame
func save_view(label_:String):
 if not visual:return
 await process_frame
 game.crowd.army.presentation.draw_effects();RenderingServer.force_draw()
 check(root.get_texture().get_image().save_png(REVISION_OUT+label_+".png")==OK,"Captured "+label_)
func retire_shots():
 for nodes in Pool.service(game).all.values():
  for shot in nodes:
   if shot.pool_live and shot.get_script() in [Shot,WaveShot]:shot.retire()
func run():
 visual=DisplayServer.get_name()!="headless"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVISION_OUT))
 create_timer(150).timeout.connect(func():printerr("WIND_ENERGY_TIMEOUT");quit(1))
 await setup_fixture()
 root.title="Goemon · Aligned wings and expanded energy"
 root.set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
 game.player.set_process_input(false);game.player.set_process_unhandled_input(false);game.camera_rig.set_process_unhandled_input(false)
 game.ui.hide();game.model.phase="wave";game.tuning.invincible=true
 var p=game.player;p.select_character(30);fresh();var c=p.active_ability;var fx=game.crowd.army.presentation
 var probe=PoseProbe.new();probe.batches={"finale-wind":fx.batches["finale-wind"],"finale-wind_outer":fx.batches["finale-wind_outer"]};probe.effects=fx.effects
 game.training_dummy.home=STAGE+Vector3(90,0,0);game.training_dummy.position=game.training_dummy.home;game.training_dummy.hide()
 for i in 3:
  var row=game.model.waves.spawn_enemy(0,STAGE+Vector3((i-1)*15,0,-30));row.hp=100000;row.max_hp=100000
  game.army_runtime.import_arrivals();targets.append(game.army_runtime.enemy_target(row.id))
 game.army_runtime.native.set_navigation({})
 var pool=Pool.service(game);var prepared=pool.created;var misses=pool.misses
 pool.launched.connect(func(shot):
  if shot.get_script()==Shot:
   shot.set_physics_process(false);released.append({"kind":shot.kind,"point":shot.position,"direction":shot.velocity.normalized(),"damage":shot.damage})
  elif shot.get_script()==WaveShot:
   shot.set_physics_process(false)
   if shot.kind=="wind":released.append({"kind":0,"point":shot.position,"direction":shot.velocity.normalized(),"damage":shot.damage}))
 check(Finale.DAMAGE[1]==.75*3 and Finale.DAMAGE[0]==5*3,"Wind and energy damage are three times their previous values")
 check(is_equal_approx(Finale.SHOT_RADIUS[0],6.3),"Energy collision coverage is three times wider")
 check(Finale.meshes.sword_wave.get_aabb().size.is_equal_approx(Vector3(3.132,2.43,3.888)*3),"Ground wave geometry is exactly three times bigger")
 check(is_equal_approx(Finale.meshes.sword_cross.get_aabb().size.x,6.912*3),"Both flying crescents are exactly three times bigger")
 c.start_move(1);await advance(40)
 check(released.size()==Finale.WIND_FAN+3,"Every pushed target gets a directed attack beside the four-way barrage")
 check(released.all(func(s):return is_equal_approx(s.damage,65*.75*.5*3)),"Every wind projectile carries triple damage")
 var travelled=pool.all.values().filter(func(nodes):return not nodes.is_empty() and nodes[0].get_script()==Shot and nodes[0].kind==1)[0]
 check(travelled[0].visual.multimesh.instance_count==2,"Each wind projectile draws both wings")
 await advance(9)
 check(released.size()==Finale.WIND_FAN*2+3,"Repeated pulses do not create another target attack for the same victim (shots=%d mode=%s elapsed=%.2f hits=%d)"%[released.size(),c.mode,c.elapsed,c.hits.size()])
 await advance(35)
 check(targets.all(func(t):return game.army_runtime.unit_state(t.handle).hp<100000),"Directed wing attacks damage all three separated moving targets")
 p.position=STAGE+Vector3(0,0,20)
 for yaw in [0.0,PI/4,PI/2,PI*1.25]:
  p.facing=Vector3.FORWARD.rotated(Vector3.UP,yaw);p.model.rotation.y=yaw
  fx.draw_effects();probe.draw_effects()
  for key in ["finale-wind","finale-wind_outer"]:
   var poses:Array=probe.rows[fx.batches[key].name];var normal:Transform3D=poses[1];var mirror:Transform3D=poses[0]
   var expected=Basis(Vector3.UP,yaw);expected.x=-expected.x
   check(mirror.basis.is_equal_approx(expected) and normal.basis.is_equal_approx(Basis(Vector3.UP,yaw)),"Both wing layers mirror locally at yaw %.2f"%yaw)
  game.camera_rig.camera.position=p.position+Vector3(34,42,55).rotated(Vector3.UP,yaw);game.camera_rig.camera.look_at(p.position+Vector3.UP*4)
  await save_view("wind-yaw-%d"%roundi(rad_to_deg(yaw)))
 p.position+=Vector3(8,2,6);fx.draw_effects();probe.draw_effects()
 var wing_origin=probe.rows[fx.batches["finale-wind"].name][0].origin
 check(wing_origin.is_equal_approx(p.position+Vector3.UP*1.2*Finale.SCALE),"Wings stay attached while Lumina floats and moves")
 await save_view("wind-follow")
 c.cancel();check(not fx.effects.any(func(e):return e.get("owner_id",0)==c.get_instance_id()),"Cancellation removes attached wings and their weak references")
 retire_shots();fresh();released.clear()
 for target in targets:target.sync(game.army_runtime.unit_state(target.handle));target.hide()
 p.position=STAGE+Vector3(0,0,20)
 game.camera_rig.camera.position=p.position+Vector3(24,32,42);game.camera_rig.camera.look_at(p.position+Vector3(0,3,-14))
 for section in 3:
  c.start_attack();await advance(ceili(c.SWORD_SECTIONS[section].contact*2/c.CAST_RATE)+2)
  check(released.size()==section+1 and is_equal_approx(released[-1].damage,65*15),"Energy click %d releases one wave with triple damage"%(section+1))
  await save_view("energy-%d"%(section+1))
  await advance(ceili((c.SWORD_SECTIONS[section].ticks-c.SWORD_SECTIONS[section].contact)*2/c.CAST_RATE)+8)
 c.cancel();retire_shots()
 for i in 48:
  var row=game.model.waves.spawn_enemy(0,STAGE+Vector3((i%8-3.5)*6,0,-15-(i/8)*5));row.hp=100000;row.max_hp=100000
 game.army_runtime.import_arrivals()
 for repeat in 3:
  fresh();c.start_move(1);await advance(290)
 check(pool.created==prepared and pool.misses==misses,"Repeated expanded volleys reuse the prepared pool without misses")
 await advance(180)
 check(not pool.all.values().any(func(nodes):return nodes.any(func(s):return s.pool_live and s.get_script()==Shot)),"All repeated wing and energy attacks retire")
 step_times.sort();frame_times.sort()
 var report={"checks":checks,"failures":failures,"prepared":prepared,"pool_after":pool.created,"misses":pool.misses-misses,"manual_step_p95_ms":step_times[floori(step_times.size()*.95)]}
 if visual:report.frame_median_ms=frame_times[frame_times.size()/2];report.frame_p95_ms=frame_times[floori(frame_times.size()*.95)];report.frame_max_ms=frame_times[-1]
 FileAccess.open(REVISION_OUT+("rendered-results.json" if visual else "headless-results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("WIND_ENERGY_RESULT ",JSON.stringify(report))
 probe.free();game.queue_free();await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
