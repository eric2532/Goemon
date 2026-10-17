extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
func capture(label: String):
 if DisplayServer.get_name()=="headless":return
 game.camera_rig.camera.global_position=game.player.global_position+Vector3(6,3,8)
 game.camera_rig.camera.look_at(game.player.global_position+Vector3(0,1.2,0))
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/dragoon-animations/"+label+".png")
func run():
 game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
 await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.tuning.invincible=true;game.tuning.critical_chance=0.0
 await fresh(8)
 var c=game.player.active_ability
 var actor=c.visual_actor
 check(c.class_id=="dragoon","Fixture uses real Dragoon")
 actor.reset_motion();c._animate(0,0)
 var motion=actor.cosplay_rig.dragoon_motion
 check(motion!=null and motion.last_clip=="idle","Idle is the approved breathing loop")
 await capture("idle")
 var e=target(Vector3(0,0,-2.5));var enemy=game.actors[e.id]
 c.attack()
 var contact=float(c.player.attack.contact);var duration=float(c.player.attack.duration)
 check(is_equal_approx(contact,.1) and is_equal_approx(duration,.36),"Existing attack contact and duration preserved")
 c.tick(contact-.001,false);c._animate(contact-.001,0)
 check(is_equal_approx(e.hp,10000),"Damage waits for the existing contact tick")
 c.tick(.002,false);c._animate(.002,0)
 check(e.hp<10000 and motion.last_clip=="attack","Real damage tick plays approved lance contact")
 check(motion.last_frame>=7 and motion.last_frame<9,"Contact pose aligns to combat hit")
 await capture("lance-contact")
 c.tick(.12,false);c._animate(.12,0)
 check(motion.last_frame>18,"Lance advances to the deeper second poke")
 await capture("lance-extension")
 c.tick(.3,false);c._animate(.3,0)
 await fresh(8);c=game.player.active_ability;actor=c.visual_actor
 c._animate(0,0);motion=actor.cosplay_rig.dragoon_motion
 var start_y: float=game.player.position.y
 game.player.jump_buffer=.15
 var apex=start_y
 var saw_jump=false
 for i in 240:
  c.physics_step(1.0/60)
  apex=maxf(apex,game.player.position.y)
  if motion.last_clip=="jump":saw_jump=true
  if i==25:await capture("jump-airborne")
 check(saw_jump and apex>start_y+1,"Regular jump poses follow a real collision-body jump")
 check(game.player.is_on_floor() and absf(game.player.position.y-start_y)<.1,"Regular jump lands at the real floor")
 check(motion.last_clip!="jump_strike","Regular jump never selects the dive")
 await fresh(8);c=game.player.active_ability;actor=c.visual_actor
 c._animate(0,0);motion=actor.cosplay_rig.dragoon_motion
 game.player.jump_buffer=.15
 for i in 12:c.physics_step(1.0/60)
 var second_y: float=game.player.position.y
 var before_vy: float=game.player.velocity.y
 game.player.jump_buffer=.15;c.physics_step(1.0/60)
 check(game.player.jumps_used==1 and game.player.velocity.y<=before_vy,"Airborne Space cannot launch a second jump")
 check(motion.last_clip=="jump" and actor.model.quaternion.angle_to(Quaternion.IDENTITY)<.001,"Airborne Space keeps Dragoon's upright silhouette")
 for i in 12:c.physics_step(1.0/60)
 check(game.player.position.y>second_y,"The single launch continues its natural ascent")
 c.action("flintlock")
 check(c.player.travel!=null and c.player.travel.phase=="aimed-drop","Airborne RMB starts the aimed plunge")
 for i in 100:c.physics_step(1.0/60)
 check(c.player.travel==null and game.player.is_on_floor(),"Aimed airborne plunge lands against the real floor")
 await fresh(8);c=game.player.active_ability;actor=c.visual_actor
 c._animate(0,0);motion=actor.cosplay_rig.dragoon_motion
 c.action("flintlock")
 check(c.player.attack!=null and c.player.attack.style=="dragoon-sweep" and c.player.travel==null,"Grounded RMB starts the new sweep")
 c.tick(1.0,false)
 game.player.jump_buffer=.15
 var saw_air=false;var saw_dive=false;var saw_land=false
 for i in 30:
  c.physics_step(1.0/60)
  if motion.last_clip=="jump":saw_air=true
 c.action("flintlock")
 for i in 180:
  c.physics_step(1.0/60)
  if motion.last_clip=="jump_strike":
   if motion.last_frame>=114 and motion.last_frame<=150:saw_dive=true
   if motion.last_frame>=180:saw_land=true
 check(saw_air and saw_dive and saw_land,"Jump then RMB reaches approved airborne, dive and landing poses")
 check(c.player.travel==null and game.player.is_on_floor(),"Special completes against the real floor")
 check(actor.model.position.length()<.001,"No Blender preview height is added to collision movement")
 c.player.roll=.2;c.player.travel=null;c._animate(.01,0)
 check(motion.last_clip=="","Dodge releases authored jump and idle poses")
 actor.reset_motion();check(motion.last_clip=="" and motion.landing_age>10,"Reset clears clip state")
 game.queue_free();await frames(3)
 print("DRAGOON_GAMEPLAY_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
