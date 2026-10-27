extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Real pipe sweeps against ordinary native enemy facades, with equal test HP.
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
var runtime
var hits=[]
var traces=[]
var current_kind=0
var capture_directory="res://build/Other Files/Asset Toolkit/Enemy Physics and Hits/"
func step(n:int):
 for i in n:
  game.player._physics_process(1.0/60)
  game.player.position=ORIGIN;game.player.velocity=Vector3.ZERO
  runtime.step(1.0/60,{});runtime.dispatch_events();runtime.sync_compatibility()
  if "--visual" in OS.get_cmdline_user_args():
   game.crowd.army.present(runtime.render_snapshot(),runtime.presentation_events);runtime.presentation_events.clear()
   game.crowd.army.presentation.tick(1.0/60)
   await physics_frame
   if not captured and game.player.combo==2 and game.player.hit_done:
    game.player.rogue_pipe_combo._process(0)
    var camera:Camera3D=game.camera_rig.camera;var aim=camera.global_transform
    camera.global_position=ORIGIN+Vector3(7,4,3);camera.look_at(ORIGIN+Vector3(0,1,-2))
    await RenderingServer.frame_post_draw
    var path=capture_directory.path_join("pipe-kind-%d.png"%current_kind)
    check(root.get_texture().get_image().save_png(path)==OK,"Rendered pipe contact capture saves for kind %d"%current_kind);captured=true
    camera.global_transform=aim
  elif i%40==0:await physics_frame
func run():
 if "--visual" in OS.get_cmdline_user_args():
  if not OS.get_environment("GOEMON_THREE_HIT_CAPTURE_DIR").is_empty():capture_directory=OS.get_environment("GOEMON_THREE_HIT_CAPTURE_DIR")
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_directory))
 await setup_fixture()
 game.set_process(false);game.army_runtime.set_physics_process(false);game.explorer_helpers.set_process(false)
 # This manually driven fixture must not accept desktop input during capture.
 game.player.set_process_input(false);game.player.set_process_unhandled_input(false);game.camera_rig.set_process_unhandled_input(false)
 for action in InputMap.get_actions():InputMap.action_erase_events(action);Input.action_release(action)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 if "--visual" in OS.get_cmdline_user_args():game.ui.hide()
 runtime=game.army_runtime
 game.training_dummy.collision_layer=0;game.training_dummy.hide();game.training_dummy.position=Vector3(0,-100,0);game.enemies.erase(game.training_dummy)
 game.camera_rig.camera.global_position=ORIGIN+Vector3(0,7,9);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1,-2))
 game.impact_confirmed.connect(func(victim,_strength,_duration):
  if victim!=game.training_dummy:hits.append(game.player.combo))
 for kind in Roles.RIGID_TYPES:
  current_kind=kind
  for distance in [2.0,4.0]:
   if "--visual" in OS.get_cmdline_user_args() and distance==4.0:continue
   runtime.clear();runtime.set_navigation(1000+traces.size(),{"width":0});game.actors.clear();game.enemies.clear();game.model.enemies.clear()
   fresh();game.player.select_weapon(1);captured=distance!=2.0
   var row=game.model.waves.spawn_enemy(kind,ORIGIN+Vector3(0,0,-distance));row.hp=10000;row.max_hp=10000
   runtime.import_arrivals();var actor=game.actors[row.id];var handle:int=runtime.handles[row.id]
   runtime.set_pose(handle,row.pos,0);runtime.sync_targets()
   await physics_frame;await physics_frame
   hits.clear();tap("light_attack");await step(200)
   traces.append({"kind":kind,"distance":distance,"hits":hits.duplicate(),"damage":10000-actor.hp,"bounds":str(actor.combat_bounds())})
   if kind==Roles.VAMBEE_TORSO and distance==4.0:
    check(hits.has(1) and hits.has(2) and hits.count(3)<=1,"Low crawler remains hittable after knockback; high third swing requires actual contact")
   else:check(hits==[1,2,3],"Every pipe stage contacts native kind %d at %.1fm: %s"%[kind,distance,str(hits)])
   var expected=0.0
   for stage in hits:expected+=30 if stage==3 else 22
   check(is_equal_approx(10000-actor.hp,expected*game.player.damage_multiplier()),"Same scaled pipe damage for every confirmed hit on kind %d"%kind)
   runtime.apply_hit(handle,{"amount":1.0,"direction":Vector3.RIGHT,"heavy":true})
   var hit_state:Dictionary=runtime.unit_state(handle)
   check(is_equal_approx(hit_state.stun,16.0/30),"Kind %d receives the soldier hit-stun duration"%kind)
   var before:Vector3=hit_state.position
   runtime.step(1.0/60,{})
   hit_state=runtime.unit_state(handle)
   check(hit_state.action==6 and hit_state.position.x>before.x,"Kind %d enters hurt pose and heavy knockback"%kind)
 # A form change during a sweep must update the existing collider immediately.
 runtime.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear();fresh()
 var row=game.model.waves.spawn_enemy(Roles.VAMBEE,ORIGIN+Vector3(0,0,-2));row.hp=1;row.max_hp=1
 runtime.import_arrivals();var actor=game.actors[row.id];var handle:int=runtime.handles[row.id]
 runtime.set_navigation(2000,{"width":0});runtime.set_pose(handle,row.pos,0);runtime.sync_targets()
 await physics_frame;await physics_frame
 hits.clear();tap("light_attack");await step(200)
 check(hits==[1,2,3] and actor.variant==Roles.VAMBEE_TORSO and actor.handle==handle,"A real pipe combo hits the standing Vambee and its new torso without replacing the target")
 check(is_equal_approx(actor.combat_bounds().size.y,1.152*runtime.enemy_size),"Split updates the gameplay hurtbox to the lower crawling form")
 check(is_equal_approx(actor.hp,game.model.waves.role_stats(Roles.VAMBEE_TORSO).hp-52*game.player.damage_multiplier()),"Remaining stages damage the new form exactly once")
 await check_interruption()
 check_render_publication()
 print("RECOVERED_ENEMY_HIT_TRACES ",JSON.stringify(traces))
 game.queue_free();game=null;runtime=null;paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("RECOVERED_ENEMY_HITS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
func check_interruption():
 for kind in Roles.RIGID_TYPES:
  runtime.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
  runtime.set_navigation(2100+kind,{"width":0})
  var handle:int=runtime.spawn(1,0,kind,Vector3.ZERO,10000,Roles.footprint_radius(kind))
  runtime.spawn(-1,1,12,Vector3(0,0,-1.6),100000,.4)
  for i in 18:runtime.step(1.0/60,{})
  check(runtime.unit_state(handle).action in [1,4],"Kind %d starts its ordinary attack before the interrupt"%kind)
  runtime.take_events();runtime.apply_hit(handle,{"amount":1.0,"direction":Vector3.BACK})
  for i in 24:runtime.step(1.0/60,{})
  var events=runtime.take_events()
  check(not events.any(func(e):return e.source_id==1 and e.kind in ["melee","bullet"]),"Kind %d cannot deliver a cancelled attack during the soldier stun window"%kind)
  check(runtime.unit_state(handle).action==6,"Kind %d holds its own hurt clip while stunned"%kind)
func check_render_publication():
 for kind in [Roles.VAMBEE,Roles.HAYA_WOLF,Roles.VAMBEE_TORSO]:
  runtime.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
  var row=game.model.waves.spawn_enemy(kind,ORIGIN+Vector3(0,0,-2));row.hp=10000;row.max_hp=10000
  runtime.import_arrivals();runtime.sync_compatibility()
  var handle:int=runtime.handles[row.id];var before:Dictionary=runtime.latest;var view=runtime.snapshot_view;var epoch:int=runtime.snapshot_epoch
  runtime.apply_hit(handle,{"amount":1.0,"direction":Vector3.RIGHT})
  runtime.apply_hit(handle,{"amount":1.0,"direction":Vector3.RIGHT})
  check(runtime.reaction_dirty and runtime.presentation_dirty,"Kind %d queues post-step hits for the current rendered frame"%kind)
  runtime.flush_presentation()
  check(runtime.latest.actions[0]==6 and runtime.latest.hp[0]==9998 and runtime.latest.pose_rows[0]==runtime.unit_state(handle).pose_row,"Kind %d rendered snapshot contains the actual immediate hurt pose"%kind)
  var renderer=game.crowd.army;var key=Vector3i(kind,floori(row.pos.x/renderer.CELL),floori(row.pos.z/renderer.CELL))
  var buffer:PackedFloat32Array=renderer.batches[key].multimesh.buffer
  check(buffer[12]==runtime.latest.pose_rows[0] and buffer[15]>0,"Kind %d GPU instance receives hurt pose and flash before another physics step"%kind)
  check(not runtime.reaction_dirty and not runtime.presentation_dirty,"Kind %d coalesces repeated hits into one presentation flush"%kind)
  check(is_same(view,runtime.snapshot_view) and epoch==runtime.snapshot_epoch and before.actions[0]==0,"Kind %d immediate rendering preserves immutable physics/contact snapshots"%kind)
  var point:Vector3=runtime.unit_state(handle).position
  game.actors[row.id].take_hit(1,Vector3.RIGHT,false,game.player.attack_chain.make_ticket("pipe"))
  runtime.step(1.0/60,{})
  check(absf(runtime.unit_state(handle).position.x-point.x-.03)<.0001,"Kind %d actual Goemon pipe ticket selects the faster physical impulse"%kind)
