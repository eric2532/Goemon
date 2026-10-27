extends "res://tests/forest-shrine/goemon_rom_weapons_test.gd"
const OUTPUT="res://build/Other Files/Asset Toolkit/Chain Steering/"
var native_targets=[]
var tip_costs=[]
func aim(angle:float):
 var direction=Vector3.FORWARD.rotated(Vector3.UP,angle)
 game.camera_rig.yaw=angle
 game.camera_rig.camera.global_position=game.player.global_position-direction*12+Vector3.UP*6
 game.camera_rig.camera.look_at(game.player.global_position+direction*50+Vector3.UP*1.2)
func begin_throw():
 fresh();ground_player();aim(0);game.player.select_weapon(3);game.player.chain_pipe_combat.start()
func spawn_target(point:Vector3):
 var row=game.model.waves.spawn_enemy(0,point);row.hp=10000;row.max_hp=10000
 game.army_runtime.import_arrivals()
 var actor=game.actors[row.id]
 game.army_runtime.set_pose(actor.handle,point,0);game.army_runtime.sync_targets()
 return actor
func run():
 create_timer(90).timeout.connect(func():printerr("FAIL: chain steering timed out");quit(1))
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_physics_process(false);game.explorer_helpers.set_process(false)
 # Isolate the swing from the original map's side walls; cover is placed explicitly below.
 for body in game.world.find_children("*","CollisionObject3D",true,false):body.set_collision_layer_value(1,false)
 await physics_frame;await physics_frame
 game.player.set_process_input(false);game.player.set_process_unhandled_input(false);game.camera_rig.set_process_unhandled_input(false)
 for action in InputMap.get_actions():InputMap.action_erase_events(action);Input.action_release(action)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 game.training_dummy.hide();game.training_dummy.collision_layer=0;game.training_dummy.position=Vector3(0,-100,0);game.enemies.erase(game.training_dummy)
 game.army_runtime.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
 game.army_runtime.set_navigation(3000,{"width":0})
 var p=game.player;var c=p.chain_pipe_combat
 begin_throw()
 var release=RecoveredGoemonCombatProfile.chain_release_time(false)
 var original_flight=RecoveredGoemonCombatProfile.CHAIN_FLIGHT_TICKS/RecoveredGoemonCombatProfile.LOGIC_HZ
 var original_duration=release+original_flight+RecoveredGoemonCombatProfile.action_duration(0x72)
 check(is_equal_approx(c.duration,original_duration+1.0),"Throw adds exactly one second at normal attack speed")
 for angle in [0.0,-PI/4,-PI/2]:
  native_targets.append(spawn_target(p.position+Vector3.FORWARD.rotated(Vector3.UP,angle)*(c.reach+.5)))
 c.tick(release+.2)
 check(native_targets[0].hp<10000 and native_targets[1].hp==10000 and native_targets[2].hp==10000,"Outbound tip hits only the enemy on its actual path")
 var radius=c.last_point.distance_to(c.origin)
 aim(-PI/2);chain_step(20)
 check(c.phase=="flight" and absf(c.last_point.distance_to(c.origin)-radius)<.001,"Steering holds the extended tip at the original reach: %s %.3f/%.3f age=%.3f"%[c.phase,c.last_point.distance_to(c.origin),radius,c.flight_age])
 check(c.direction.dot(Vector3.RIGHT)>.999 and p.facing.dot(Vector3.RIGHT)>.999,"Live camera aim turns the tip and Goemon together")
 for target in native_targets:
  check(is_equal_approx(target.hp,10000-c.damage),"Swept native enemy receives exactly one unchanged-damage hit: %.1f"%target.hp)
 aim(0);chain_step(20)
 for target in native_targets:
  check(is_equal_approx(target.hp,10000-c.damage),"Swinging back cannot damage the same enemy again")
 c.tick(.29)
 check(c.phase=="flight" and absf(c.last_point.distance_to(c.origin)-radius)<.001,"Tip remains extended near the end of the extra second")
 c.tick(.06)
 check(c.last_point.distance_to(c.origin)<radius,"Original return resumes after the extra second")
 c.tick(1)
 check(not c.active and c.struck.is_empty() and not p.model.chain_pipe.endpoint_override,"Return clears extended-hit state")
 begin_throw();c.tick(release+.2);aim(PI);c.tick(1.0/60)
 check(c.direction.is_finite() and c.direction.dot(Vector3.FORWARD)>.98 and c.direction.distance_to(Vector3.FORWARD)>.01,"An opposite aim begins a bounded swing instead of a teleport")
 chain_step(30)
 check(c.direction.dot(Vector3.BACK)>.999,"An opposite aim completes its turn")
 c.cancel()
 begin_throw();c.tick(release+.2);aim(-PI/2);c.tick(.25)
 var coarse=c.last_point
 c.cancel();begin_throw();c.tick(release+.2);aim(-PI/2);chain_step(15)
 check(c.last_point.distance_to(coarse)<.001,"A long update and small updates follow the same swept arc")
 c.cancel()
 var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.3,4,10);collision.shape=box;wall.add_child(collision);game.add_child(wall);wall.position=ORIGIN+Vector3(8,1.5,-16)
 await physics_frame;await physics_frame
 var protected_hp:float=native_targets[1].hp
 begin_throw();c.tick(release+.2);aim(-PI/2);chain_step(120)
 check(native_targets[1].hp==protected_hp and not c.active,"A wall in the sideways swing stops the tip and protects the next enemy")
 wall.queue_free();await physics_frame
 for interruption in ["focus","weapon","fighter","dodge"]:
  begin_throw();c.tick(release+.3)
  match interruption:
   "focus":c.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
   "weapon":p.select_weapon(1)
   "fighter":p.select_character(2)
   "dodge":p.interrupt_attack_for_movement()
  check(not c.active and c.struck.is_empty() and not p.character_models[1].chain_pipe.endpoint_override,"Extended throw clears on "+interruption)
  p.select_character(1)
 begin_throw();p.powerups.attack_speed=5;p.attack_speed_stacks=1
 c.tick(c.duration/p.attack_speed_multiplier()+.01)
 check(not c.active,"Extended timing still follows the existing attack-speed multiplier")
 # Keep a full native population present; local sweeps should ignore distant units.
 for i in 237:spawn_target(Vector3(140+(i%16)*4,0,140+int(i/16)*4))
 for i in 4:
  begin_throw()
  for tick in 135:aim(-PI*.5*sin(tick/30.0));c.tick(1.0/60)
 await create_timer(.5).timeout
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for cast in 20:
  begin_throw()
  for tick in 135:
   aim(-PI*.5*sin(tick/30.0))
   var before=Time.get_ticks_usec();c.tick(1.0/60);tip_costs.append(Time.get_ticks_usec()-before)
 await create_timer(.5).timeout
 check(get_node_count()<=nodes+4 and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources+4,"Repeated steered throws retain no nodes or resources")
 tip_costs.sort()
 var report={"native_enemies":game.enemies.size(),"tick_samples":tip_costs.size(),"tick_p95_us":tip_costs[int(tip_costs.size()*.95)],"tick_max_us":tip_costs[-1],"nodes_before":nodes,"nodes_after":get_node_count(),"resources_before":resources,"resources_after":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"note":"Focused chain CPU cost with stationary native enemies; not a full-battle benchmark."}
 if "--visual" in OS.get_cmdline_user_args():await render_swing()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var file=FileAccess.open(OUTPUT+"checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
 game.queue_free();await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("CHAIN_STEERING_PROFILE ",JSON.stringify(report))
 print("CHAIN_STEERING_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func render_swing():
 root.size=Vector2i(1280,800);game.forest_ui.close_overlay();game.ui.hide()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var p=game.player;var c=p.chain_pipe_combat
 begin_throw()
 for tick in 115:
  if tick>25:aim(-minf(PI/2,(tick-25)*PI/90))
  c.tick(1.0/60)
  p.model.rotation.y=atan2(-p.facing.x,-p.facing.z)
  p.model.animate(0,0,true,0,p.attack_left/maxf(.001,p.attack_duration),false,1,false);p.model.sync_skeleton()
  game.army_runtime.flush_presentation()
  await physics_frame
  if tick in [25,55,75]:
   var camera:Camera3D=game.camera_rig.camera;var camera_pose=camera.global_transform
   camera.global_position=ORIGIN+Vector3(25,15,15);camera.look_at(ORIGIN+Vector3(5,1,-6))
   await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png(OUTPUT+"swing-%d.png"%tick)==OK,"Rendered extended swing capture %d"%tick)
   camera.global_transform=camera_pose
