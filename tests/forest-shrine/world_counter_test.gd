extends "res://tests/forest-shrine/guard_reply_test.gd"

const WORLD_OUT="res://build/Other Files/Asset Toolkit/World Counter/"

func world_patrol()->int:
 var at=home+Vector3.FORWARD*2.5
 at.y=game.model.world_height(at.x,at.z)
 var row=game.model.waves.spawn_enemy(20,at)
 row.hp=100000;row.max_hp=row.hp;row.frontier_patrol=true;row.skin=1;row.patrol_radius=14.0
 game.army_runtime.import_arrivals();game.army_runtime.sync_targets()
 return game.army_runtime.handles[row.id]

func counter_case(response:String):
 var p=game.player;var army=game.army_runtime
 await settle(p.RogueRoster.KAZI_ID)
 p.timed_dodge.shadow_counter_enabled=false
 var handle=world_patrol()
 var state:Dictionary=army.unit_state(handle)
 check(state.dodge_chance==0 and is_equal_approx(state.counter_chance,.20),"World patrol has counter chance and zero dodge")
 var hp:float=state.hp
 for i in 5:army.apply_hit(handle,{"amount":1.0,"direction":Vector3.FORWARD,"source_id":0})
 check(army.unit_state(handle).hp==hp-5,"All five incoming hits damage the patrol; it never dodges")
 var ready={"value":false}
 await driver.advance(1,func(_dt):
  for i in 180:
   advance(1)
   if army.unit_state(handle).counter_active and army.native.hero_dodge_threat().seconds>0:
    ready.value=true;break)
 check(ready.value,"The native counter exposes its real contact warning: "+response)
 if not ready.value:return
 p.timed_dodge._process(0)
 check(p.timed_dodge.mark.is_visible_in_tree(),"Counter shows the existing ! dodge cue")
 if response=="dodge":
  army.flush_presentation();await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(WORLD_OUT+"counter-warning.png")==OK,"Captured counter warning")
 var before:float=p.hp
 if response=="dodge":
  key();key(false)
  check(p.timed_dodge.reacting,"Physical Space accepts the enemy counter warning")
 elif response=="leave":p.position+=Vector3.RIGHT*15
 await driver.advance(1,func(_dt):
  for i in 180:
   advance(1)
   if not army.unit_state(handle).counter_active:break)
 check(p.hp<before if response=="stay" else p.hp==before,"Counter hits an idle player and misses a dodge or retreat: "+response)
 check(p.active_ability.shin_counter.is_empty(),"The counter cannot start a counter loop: "+response)

func guard_pose_case():
 var p=game.player;var army=game.army_runtime
 await settle(p.RogueRoster.KAZI_ID)
 var enemy=world_patrol()
 army.native.set_boss_reactions(enemy,0,0)
 var center:Vector3=army.unit_state(enemy).position
 var pet=army.spawn(-1000000,1,19,center+Vector3.FORWARD*2,150,.5)
 army.native.set_guard(pet,center+Vector3.FORWARD*2,18)
 p.position=home+Vector3.BACK*16
 army.order_hounds(army.HoundOrder.ATTACK,enemy)
 var guarded=false
 for i in 240:
  await driver.advance(1,func(_dt):advance(1))
  if army.unit_state(enemy).blocking:guarded=true;break
 check(guarded,"An actual pet swing triggers the recovered guard pose")
 if guarded:
  var camera:Camera3D=game.camera_rig.camera
  camera.global_position=center+Vector3(6,4,6);camera.look_at(center+Vector3.UP*1.2);camera.reset_physics_interpolation()
  army.flush_presentation();await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(WORLD_OUT+"guard-pose.png")==OK,"Captured the recovered guard pose against a pet")

func run():
 create_timer(180).timeout.connect(func():printerr("WORLD_COUNTER_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(WORLD_OUT);root.size=Vector2i(1280,800)
 await setup_fixture(Tour.Regions.layout("north_coast"))
 game.set_process(false);game.set_process_input(false);game.set_process_unhandled_input(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.army_runtime.record_events=true;game.music.stop();game.tuning.invincible=false
 game.training_dummy.position=Vector3.DOWN*1000
 game.army_runtime.refresh_navigation(0)
 var found=false
 for x in range(-240,241,24):
  for z in range(-240,241,24):
   var point:Vector3=game.model.world_point(Vector2(x,z))
   if game.army_runtime.native.ally_ground_clear(point,20):home=point;found=true;break
  if found:break
 check(found,"Counter fixture uses an actual North Coast clearing")
 home.y=game.model.world_height(home.x,home.z)+.05;game.model.update_vision(home/game.model.falan_scale)
 game.camera_rig.set_process(false)
 game.camera_rig.camera.global_position=home+Vector3(7,5,10)
 game.camera_rig.camera.look_at(home+Vector3(0,1.5,-1))
 driver=load("res://tests/forest-shrine/physics_step_driver.gd").new();root.add_child(driver)
 for response in ["stay","dodge","leave"]:await counter_case(response)
 await guard_pose_case()
 game.queue_free();current_scene=null;await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("WORLD_COUNTER_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
