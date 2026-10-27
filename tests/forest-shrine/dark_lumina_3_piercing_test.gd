extends "res://tests/forest-shrine/dark_lumina_3_controls_test.gd"
const BladeShot=preload("res://scripts/dark_lumina_3_projectile.gd")
const PIERCE_OUT=OUT+"Piercing Combo/"
var shots=[]
var cpu=[]
func run():
 create_timer(120).timeout.connect(func():printerr("LUMINA_PIERCING_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PIERCE_OUT))
 visual=DisplayServer.get_name()!="headless"
 await setup_fixture()
 root.set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 game.set_process_input(false);game.set_process_unhandled_input(false)
 game.player.set_process_input(false);game.player.set_process_unhandled_input(false)
 game.camera_rig.set_process_unhandled_input(false)
 game.set_process(false);game.army_runtime.set_physics_process(false)
 var p=game.player;p.select_character(28)
 var reference_unit=p.model.source_unit()
 p.select_character(30);fresh()
 var c=p.active_ability;var origin=ORIGIN+Vector3.UP*1000
 var owner=game.army_runtime
 owner.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
 owner.set_navigation(9431,{"width":0})
 game.training_dummy.position=Vector3(0,-100,0);game.model.update_vision(origin)
 var victims=[]
 for offset in [Vector3(0,0,-6),Vector3(0,0,-12),Vector3(0,0,-18),Vector3(100,0,-12),Vector3(0,0,100)]:
  var row=game.model.waves.spawn_enemy(0,origin+offset);row.hp=100000;row.max_hp=100000
  owner.import_arrivals();owner.sync_targets();victims.append(game.actors[row.id])
 var point=Vector3(origin.x,AttackChain.aim_point(victims[0],origin).y,origin.z)
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):
  if shot.get_script() in [WaveShot,BladeShot]:
   shot.set_physics_process(false)
   if shot.get_script()==BladeShot or shot.kind=="wind":shots.append(shot))
 game.camera_rig.camera.position=origin+Vector3(24,18,28);game.camera_rig.camera.look_at(origin+Vector3(0,2,-10))
 game.crowd.army.present(owner.render_snapshot(),[])
 await frames(3)
 var created=pool.created;var misses=pool.misses
 var nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
 var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for delta in [1.0/20,1.0/30,1.0/60,.75]:
  c.cancel();p.attack_chain.reset();shots.clear();p.position=origin+Vector3.UP*30;p.ai_controlled=true;p.ai_aim=p.position+Vector3.FORWARD*100
  for section in 3:
   c.start_attack();c.tick(c.duration/c.CAST_RATE+.001)
  p.ai_controlled=false
  check(shots.size()==3 and shots[0].get_script()==WaveShot and shots[0].kind=="wind" and shots[1].get_script()==BladeShot and shots[2].get_script()==BladeShot,"Three clicks use Kojiro’s Wind wave followed by two original blades")
  check(is_equal_approx(shots[0].unit,reference_unit) and is_equal_approx(shots[0].velocity.length(),16*30*reference_unit),"Wind wave matches Kojiro’s prepared scale and speed")
  check(shots[0].position.is_equal_approx(p.position+p.facing*24*reference_unit+Vector3.UP*.08),"Wind wave uses Kojiro’s forward muzzle and ground height")
  check(shots.all(func(s):return is_equal_approx(s.damage,65*Finale.DAMAGE[0])),"All three releases retain Lumina’s damage")
  check(shots[1].piercing and shots[2].piercing,"Both energy blades enable piercing")
  for i in [1,2]:check(shots[i].visual.global_basis.z.normalized().dot(shots[i].velocity.normalized())>.9999,"Energy blade %d faces straight along its flight path"%(i+1))
  var before=victims.map(func(v):return v.hp)
  for shot in shots:shot.position=point
  var blade_bases=[shots[1].visual.global_basis,shots[2].visual.global_basis]
  for frame in int(ceil(1.0/delta)):
   var start=Time.get_ticks_usec()
   for shot in shots:
    if shot.pool_live:shot._physics_process(delta)
   for entries in pool.all.values():
    for effect in entries:
     if effect.pool_live and effect.get_script()==WaveShot and effect.kind=="dust":effect._physics_process(delta)
   cpu.append((Time.get_ticks_usec()-start)/1000.0)
   if visual:
    await physics_frame
    if frame==2:
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png(PIERCE_OUT+"combo-%.3f.png"%delta)
  for i in [1,2]:
   check(shots[i].visual.global_basis.is_equal_approx(blade_bases[i-1]),"Energy blade %d keeps its launch orientation throughout flight at delta %.4f"%[i+1,delta])
   check(shots[i].position.is_equal_approx(point+shots[i].velocity*delta*ceil(1.0/delta)),"Energy blade %d follows its straight launch direction at delta %.4f"%[i+1,delta])
  for i in 3:check(is_equal_approx(before[i]-victims[i].hp,3*65*Finale.DAMAGE[0]),"Each wave/blade hits native victim %d once at delta %.4f (damage=%s)"%[i,delta,before[i]-victims[i].hp])
  check(victims[3].hp==before[3] and victims[4].hp==before[4],"Piercing preserves off-lane and behind-caster exclusions")
  for shot in shots:
   check(shot.pool_live,"Every shot continues after multiple enemy contacts (kind=%s pos=%s age=%s)"%[shot.kind,shot.position,shot.age])
   shot.position=point;shot._physics_process(.05)
  for i in 3:check(is_equal_approx(before[i]-victims[i].hp,3*65*Finale.DAMAGE[0]),"Re-entering enemies cannot duplicate a shot’s damage")
  for shot in shots:shot.retire()
 check(pool.created==created and pool.misses==misses,"Repeated overlapping combos reuse prepared projectiles")
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated piercing does not grow nodes or resources")
 for yaw in [0.0,PI/4,PI/2,PI*1.25]:
  c.cancel();shots.clear();p.position=origin+Vector3.UP*30;p.ai_controlled=true
  var direction=Vector3.FORWARD.rotated(Vector3.UP,yaw);p.ai_aim=p.position+direction*100
  for section in 3:
   c.start_attack();c.tick(c.duration/c.CAST_RATE+.001)
  p.ai_controlled=false
  for i in [1,2]:
   var shot=shots[i];var start=shot.position
   shot._physics_process(.25 if i==1 else .55)
   check(shot.visual.global_basis.z.normalized().dot(direction)>.9999 and (shot.position-start).normalized().dot(direction)>.9999,"Reused blade %d keeps its crest and movement aligned at yaw %.2f"%[i+1,yaw])
  if visual:
   game.camera_rig.camera.position=p.position+Vector3(0,50,20).rotated(Vector3.UP,yaw);game.camera_rig.camera.look_at(p.position+direction*18)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(PIERCE_OUT+"straight-yaw-%d.png"%roundi(rad_to_deg(yaw)))
  for shot in shots:shot.retire()
  c.cancel();shots.clear();p.facing=direction;c.move=0
  for tick in [88,127,139]:c.release_event(1,tick)
  check(shots.size()==3 and shots.all(func(s):return s.visual.global_basis.z.normalized().dot(direction)>.9999),"Shared Sword keeps all three waves aligned at yaw %.2f"%yaw)
  for shot in shots:shot.retire()
 var wall=StaticBody3D.new();wall.collision_layer=1
 var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(80,40,.5)
 wall.add_child(shape);game.add_child(wall);wall.position=origin+Vector3(0,3,-9)
 await physics_frame;await physics_frame
 for section in 3:
  var script=WaveShot if section==0 else BladeShot
  var profile="wind" if section==0 else "finale0"
  var config={"kind":"wind" if section==0 else 0,"position":point,"velocity":Vector3.FORWARD*28,"damage":975.0}
  if section>0:config.merge({"piercing":true,"cross_slash":true,"slash_yaw":Finale.SWORD_CROSS_ANGLE*(1 if section==1 else -1)})
  var shot=pool.launch(p,script,profile,config)
  check(shot.hit_targets.is_empty(),"Reused shot clears its victim history")
  var hp=victims[1].hp;shot._physics_process(.8)
  check(not shot.pool_live and victims[1].hp==hp,"Shot %d stops at solid cover without hitting through it"%section)
  config.position=point+Vector3.UP*100
  shot=pool.launch(p,script,profile,config);shot._physics_process(3.1)
  check(not shot.pool_live,"Shot %d retains a finite lifetime"%section)
 var original=pool.launch(p,BladeShot,"finale0",{"kind":0,"position":point})
 check(not original.piercing and original.hit_targets.is_empty(),"Borrowed Sword retains its original contact behavior and reset state");original.retire()
 cpu.sort()
 var report={"checks":checks,"failures":failures,"pool_created":created,"pool_after":pool.created,"misses":pool.misses-misses,"three_shot_cpu_p95_ms":cpu[int(cpu.size()*.95)],"scope":"Focused native contacts and repeated overlapping player combos; not a full-battle benchmark or long-session soak."}
 FileAccess.open(PIERCE_OUT+("desktop.json" if visual else "headless.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("LUMINA_PIERCING_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
