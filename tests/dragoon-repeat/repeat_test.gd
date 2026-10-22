extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
func launch(c):
 game.player.jump_buffer=.15
 for i in 20:c.physics_step(1.0/120)
func run():
 game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
 await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.tuning.invincible=true;game.tuning.critical_chance=0.0;game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
 await fresh(8);var c=game.player.active_ability
 c.player.cooldowns.flintlock=2.6
 c.action("flintlock")
 check(c.player.travel==null,"Grounded RMB still respects its cooldown")
 c.player.secondaryBuffer=null
 launch(c)
 var remaining: float=c.player.cooldowns.flintlock
 game.forest_ui.sync()
 check(not game.forest_ui.cooldown_masks[1].visible,"Aerial RMB icon is ready even during a grounded cooldown")
 c.action("flintlock")
 check(c.player.travel!=null,"Airborne RMB bypasses the existing grounded cooldown")
 check(is_equal_approx(c.player.cooldowns.flintlock,remaining),"Aerial strike does not replace or refresh the grounded timer")
 if c.player.travel!=null:
  var ticket=c.player.travel.ticket
  c.action("flintlock")
  check(c.player.travel.ticket==ticket,"A committed dive cannot be restarted in midair")
  check(c.player.secondaryBuffer==null,"Extra clicks during a dive cannot queue an unwanted grounded leap")
 for i in 300:c.physics_step(1.0/120)
 check(game.player.is_on_floor(),"Aerial strike returns to a real floor")
 # Fresh aerial attacks leave no cooldown, so jump-strike can repeat immediately.
 await fresh(8);c=game.player.active_ability
 for cycle in 3:
  launch(c);c.action("flintlock")
  check(c.player.travel!=null,"Jump-strike cycle %s starts without a cooldown wait"%cycle)
  check(c.player.cooldowns.flintlock==0,"Aerial cycle %s creates no cooldown"%cycle)
  for i in 90:c.physics_step(1.0/120)
  check(game.player.is_on_floor() and c.player.travel==null,"Cycle %s finishes before the next jump"%cycle)
 await fresh(8);c=game.player.active_ability
 c.action("flintlock")
 check(c.player.attack!=null and c.player.attack.style=="dragoon-sweep" and c.player.cooldowns.flintlock>0,"Grounded sweep starts its normal cooldown")
 game.forest_ui.sync()
 check(game.forest_ui.cooldown_masks[1].visible,"Grounded sweep displays its normal cooldown")
 await fresh(6);c=game.player.active_ability
 launch(c);c.player.cooldowns.flintlock=1.0;c.action("flintlock")
 check(c.player.cooldowns.flintlock==1.0 and c.player.travel==null,"Other airborne heroes still respect their secondary cooldown")
 await fresh(8);c=game.player.active_ability
 var center: Vector3=c.player.pos
 var scale: float=c.range_scale()
 var near=target(Vector3(12.0*scale,0,0))
 var middle=target(Vector3(15.0*scale,0,0))
 var edge=target(Vector3(19.0*scale,0,0))
 var outside=target(Vector3(21.0*scale,0,0))
 c.begin_cast("secondary")
 c.Actions.lance_impact(c,{"ticket":c.current_ticket(),"rangeScale":scale})
 check(near.hp<10000 and middle.hp==10000,"First pulse reaches 12.6m but excludes the second ring")
 check(c.player.pulses.size()==2 and is_equal_approx(c.player.pulses[0].radius,16.2) and is_equal_approx(c.player.pulses[1].radius,19.8),"Remaining pulse radii are exactly 3x larger")
 for i in 80:c.tick_timers(1.0/120)
 check(middle.hp<10000 and edge.hp<10000,"Expanded later pulses damage enemies near the new outer edge")
 check(outside.hp==10000,"Enemies beyond the tripled outer radius remain outside")
 if DisplayServer.get_name()!="headless":
  game.camera_rig.camera.global_position=center+Vector3(0,40,32)
  game.camera_rig.camera.look_at(center)
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://tests/dragoon-repeat/triple-shockwave.png")
 game.queue_free();await frames(3)
 print("DRAGOON_REPEAT_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
