extends SceneTree
const ORIGIN=Vector3(0,.1,70)
var game
var checks=0
var failures=0
var config_path="user://ninja-pierce-%d.cfg"%OS.get_process_id()
func _initialize():
 create_timer(90).timeout.connect(func():printerr("Ninja pierce timeout");quit(1))
 run.call_deferred()
func check(ok: bool,note: String):
 checks+=1;print("PASS: " if ok else "FAIL: ",note)
 if not ok:failures+=1
func frames(n=3):
 for i in n:await physics_frame
func fresh(id: int=5):
 for actor in game.actors.values():
  if is_instance_valid(actor):actor.queue_free()
 game.actors.clear();game.enemies.clear();game.model.enemies.clear();await frames()
 game.player.select_character(id);game.player.position=ORIGIN;game.player.velocity=Vector3.ZERO
 game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO;game.player.facing=Vector3.FORWARD
 game.player.attack_chain.reset();game.player.invuln=0
 var c=game.player.active_ability;c.fx.clear();c.reset_run();c.move_input=Vector3.ZERO;c.locomotion_velocity=Vector3.ZERO
 for i in 20:c._move_body(1.0/60)
 c.player.pos=game.player.position;c.player.angle=PI;c.aim=c.player.pos+Vector3.FORWARD*30
 game.camera_rig.yaw=0;game.camera_rig.camera.global_position=game.player.position+Vector3(0,2.4,10)
 game.camera_rig.camera.look_at(game.player.position+Vector3(0,1.1,-15));game.model.update_vision(game.player.position)
 return c
func target(offset: Vector3,variant: int=0):
 var e=game.model.waves.spawn_enemy(variant,ORIGIN+offset);e.hp=10000;e.max_hp=10000;e.stun=100
 game.sync_enemies();var actor=game.actors[e.id];actor.set_physics_process(false);actor._sync_fitted_pose();game.model.update_vision(game.player.position)
 return e
func segment(c,from: Vector3,to: Vector3,finish=false):
 game.player.position=to;c.player.pos=to
 if finish:c.player.roll=0
 c.Actions.resolve_dash_segment(c,from,to)
func capture(label_: String):
 game.world.update_fog()
 game.camera_rig.camera.global_position=game.player.position+Vector3(7,4.5,6)
 game.camera_rig.camera.look_at(game.player.position+Vector3(0,1,-1))
 await frames();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/bow-ninja-dash-20261017/"+label_+".png")==OK,"Native capture "+label_)
func run():
 var original=load("res://scripts/forest/forest_map_document.gd").new();original.load_original();set_meta("forest_custom_layout",original.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
 await frames();game.start_wave();game.model.waves.pending=0;game.model.waves.spawn_clock=10000
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.tuning.invincible=true;game.tuning.critical_chance=0;game.character_tuning={}
 var c=await fresh();var e1=target(Vector3(0,0,-3));var e2=target(Vector3(0,0,-7))
 c.action("flintlock");var a=c.player.dashAttack;var start: Vector3=c.player.pos
 segment(c,start,start+Vector3.FORWARD*8)
 check(e1.hp==9924 and e2.hp==9924,"Dash pierces every real enemy along a skipped-frame travel segment")
 segment(c,start,start+Vector3.FORWARD*8)
 check(e1.hp==9924 and e2.hp==9924,"Travel phase hits each enemy only once")
 var final_target=target(Vector3(0,0,-10.5));var outside=target(Vector3(7,0,-10.5))
 segment(c,start+Vector3.FORWARD*8,start+Vector3.FORWARD*8,true)
 check(final_target.hp==9924,"The final forward strike damages an enemy beyond the travelled path")
 check(e2.hp==9848,"An enemy touching both path and finish receives both distinct hits")
 check(outside.hp==10000,"Finishing strike misses enemies far beside its blade")
 check(c.player.dashAttack==null and c.player.ninjaHits==0,"Finisher retires once without refreshing its own cooldown")
 check(game.player.attack_chain.count==1,"Both damage phases earn only one attack-chain link")
 c=await fresh();var behind=target(Vector3(0,0,3));c.action("flintlock")
 segment(c,c.player.pos,c.player.pos,true)
 check(behind.hp==10000,"Finishing strike does not hit behind Ninja")
 c=await fresh();var covered=target(Vector3(0,0,-4));c.action("flintlock")
 var wall=StaticBody3D.new();wall.collision_layer=1;wall.position=ORIGIN+Vector3(0,3,-2)
 var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(10,8,.4);collision.shape=shape;wall.add_child(collision);game.add_child(wall);await frames()
 segment(c,c.player.pos,c.player.pos,true)
 check(covered.hp==10000,"The forward finishing strike cannot pass through cover")
 wall.queue_free();await frames()
 c=await fresh();var hidden=target(Vector3(0,0,-3));c.action("flintlock");game.model.visible_cells.clear()
 segment(c,c.player.pos,c.player.pos,true)
 check(hidden.hp==10000,"Finishing strike respects enemy fog visibility")
 c=await fresh();c.action("flintlock");c.cancel();var cancel_target=target(Vector3(0,0,-3))
 c.Actions.resolve_dash_segment(c,c.player.pos,c.player.pos)
 check(cancel_target.hp==10000,"Cancelling a dash discards its pending final hit")
 c=await fresh();var actor=c.visual_actor
 game.player.jump_buffer=.15;c.physics_step(1.0/60)
 check(game.player.velocity.y>0,"Ninja jump launches immediately using shared jump physics")
 check(actor.cosplay_rig.explorer_motion!=null and actor.cosplay_rig.explorer_motion.last_clip=="jump","Ninja uses Explorer's authored takeoff pose")
 if actor.cosplay_rig.explorer_motion!=null:
  var sample=c.player.duplicate();sample.grounded=false;sample.vertical=-4;sample.flip=-1
  actor.animate_pose(sample,.2,0,0)
  check(actor.cosplay_rig.explorer_motion.last_clip=="jump" and actor.cosplay_rig.explorer_motion.last_frame==60,"Ninja uses Explorer's falling pose")
 # A stationary landing must keep the authored landing skeleton, not
 # merely report its metadata while the Ninja idle overwrites it.
 c=await fresh();game.player.jump_buffer=.15
 for i in 8:c.physics_step(1.0/60)
 for i in 160:
  c.physics_step(1.0/60)
  if game.player.is_on_floor():break
 var rig=c.visual_actor.cosplay_rig
 var leg_index=rig.skeleton.find_bone("Leg_L")
 var actual_landing: Transform3D=rig.skeleton.get_bone_global_pose(leg_index)
 if rig.explorer_motion!=null:
  rig.explorer_motion.sample(c.visual_actor,"jump",rig.explorer_motion.last_frame,1.0)
  check(actual_landing.is_equal_approx(rig.skeleton.get_bone_global_pose(leg_index)),"Stationary landing retains Explorer's authored leg pose")
 for i in 30:c.physics_step(1.0/60)
 check(rig.ninja_motion.last_clip=="idle","Ninja returns to the user's custom idle after landing recovery")
 c=await fresh();game.player.smoke_move=Vector2(0,-1)
 for i in 40:c.physics_step(1.0/60)
 check(c.visual_actor.cosplay_rig.explorer_motion!=null and c.visual_actor.cosplay_rig.explorer_motion.last_clip=="run","Ninja uses Explorer's authored running cycle")
 # Full physics path: short native ticks must pierce and finish without
 # turning the dash into per-frame damage or moving through solid cover.
 c=await fresh();var real_path=target(Vector3(0,0,-4));var end_target=target(Vector3(0,0,-13.5))
 c.action("flintlock");var dash_start: Vector3=game.player.position
 for i in 40:c.physics_step(1.0/60)
 check(real_path.hp==9924 and end_target.hp==9924,"Actual moving dash damages route and endpoint (HP=%s/%s pos=%s)"%[real_path.hp,end_target.hp,game.player.position])
 check(absf(game.player.position.distance_to(dash_start)-11.34)<.3,"Hit contacts preserve Ninja's existing dash distance")
 if "--visual" in OS.get_cmdline_user_args():
  c=await fresh();game.player.jump_buffer=.15
  for i in 8:c.physics_step(1.0/60)
  await capture("ninja-jump")
  c=await fresh();game.player.smoke_move=Vector2(0,-1)
  for i in 40:c.physics_step(1.0/60)
  await capture("ninja-run")
  c=await fresh();target(Vector3(0,0,-4));target(Vector3(0,0,-13.5));c.action("flintlock")
  for i in 26:c.physics_step(1.0/60)
  await capture("ninja-finish")
 c.cancel();game.sound_library.cancel();game.music.stop()
 for voice in game.voices:voice.stop()
 game.queue_free();paused=false;await frames();await create_timer(.3).timeout
 DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
 print("NINJA_PIERCE_FINISH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
