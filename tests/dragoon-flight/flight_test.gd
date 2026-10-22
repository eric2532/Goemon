extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
func shot(label: String):
 if DisplayServer.get_name()=="headless":return
 game.camera_rig.camera.global_position=game.player.position+Vector3(8,4,12)
 game.camera_rig.camera.look_at(game.player.position+Vector3(0,1,0))
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://tests/dragoon-flight/"+label+".png")
func jump_apex(id: int)->float:
 await fresh(id)
 var c=game.player.active_ability
 var ground_y: float=game.player.position.y
 game.player.jump_buffer=.15
 var top=ground_y
 for i in 240:
  c.physics_step(1.0/120)
  top=maxf(top,game.player.position.y)
 return top-ground_y
func run():
 game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
 await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.tuning.invincible=true;game.tuning.critical_chance=0.0
 game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
 var normal=await jump_apex(3)
 var dragon=await jump_apex(8)
 print("JUMP_HEIGHT normal=",normal," dragoon=",dragon," ratio=",dragon/normal)
 check(absf(dragon/normal-3)<.08,"Dragoon actual apex is three normal jump heights")
 check(game.player.maximum_jumps()==1,"Dragoon advertises one jump")
 await fresh(8);var c=game.player.active_ability
 game.player.jump_buffer=.15
 for i in 18:c.physics_step(1.0/60)
 var prior_vy: float=game.player.velocity.y
 game.player.jump_buffer=.15;c.physics_step(1.0/60)
 check(game.player.jumps_used==1 and game.player.velocity.y<=prior_vy,"Pressing Space in the air cannot launch a second jump")
 Input.action_press("jump")
 for i in 110:c.physics_step(1.0/60)
 await shot("hover")
 var hover_y: float=game.player.position.y
 for i in 90:c.physics_step(1.0/60)
 check(not game.player.is_on_floor() and absf(game.player.position.y-hover_y)<.01,"Holding Space maintains a stable hover at the apex")
 check(c.player.get("dragoonHovering",false) and absf(game.player.velocity.y)<.001,"Hover state and vertical velocity agree")
 check(c.visual_actor.cosplay_rig.dragoon_motion.last_clip=="jump","Hover keeps the approved airborne animation")
 Input.action_release("jump")
 for i in 20:c.physics_step(1.0/60)
 check(game.player.position.y<hover_y-.3,"Releasing Space resumes falling")
 for i in 200:c.physics_step(1.0/60)
 check(game.player.is_on_floor() and not c.player.get("dragoonHovering",false),"Landing clears hover and restores the single jump")
 await fresh(3);check(game.player.maximum_jumps()==2,"Other heroes retain their double jump")
 await fresh(8);c=game.player.active_ability
 game.player.jump_buffer=.15
 for i in 70:c.physics_step(1.0/60)
 Input.action_press("jump")
 for i in 5:c.physics_step(1.0/60)
 var point: Vector3=game.player.position+Vector3(12,-game.player.position.y,-14)
 game.camera_rig.camera.global_position=game.player.position+Vector3(0,2,4)
 game.camera_rig.camera.look_at(point)
 var aimed: Vector3=game.crosshair_target()
 c.action("flintlock")
 check(c.player.travel!=null and c.player.travel.get("phase","")=="aimed-drop","Airborne RMB begins a crosshair-directed strike")
 var start: Vector3=game.player.position
 check(not c.player.get("dragoonHovering",false),"Starting a strike immediately releases hover")
 if c.player.travel!=null:
  var target_: Vector3=c.player.travel.target
  check(Vector2(target_.x-start.x,target_.z-start.z).length()>4,"Aerial strike target follows the aimed landing point")
  var victim=target(Vector3(target_.x-ORIGIN.x,0,target_.z-ORIGIN.z))
  c.physics_step(1.0/120)
  check(victim.hp==10000,"Aimed strike does not apply landing damage while airborne")
  await shot("aimed-strike")
  for i in 240:c.physics_step(1.0/120)
  var delta: Vector3=game.player.position-start
  check(Vector2(delta.x,delta.z).length()>4,"Strike moves the actual collision body toward the crosshair")
  check(game.player.is_on_floor() and c.player.travel==null,"Aimed strike lands on real ground")
  check(Vector2(game.player.position.x-target_.x,game.player.position.z-target_.z).length()<1.5,"Open-ground strike arrives near its frozen landing target")
  var loss=10000.0-float(victim.hp)
  check(loss>100,"Landing creates a powerful shockwave attack at the actual destination")
  await shot("landing")
  var hp_after: float=victim.hp
  for i in 100:c.physics_step(1.0/120)
  check(victim.hp==hp_after,"A finished landing cannot replay its shockwave set")
 Input.action_release("jump")
 await fresh(8);c=game.player.active_ability
 game.player.jump_buffer=.15
 for i in 70:c.physics_step(1.0/60)
 var barrier=StaticBody3D.new();barrier.collision_layer=1;barrier.collision_mask=0
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(12,35,.4);shape.shape=box;barrier.add_child(shape);game.add_child(barrier)
 var launch: Vector3=game.player.position
 barrier.position=Vector3(launch.x,16,launch.z-6)
 await frames()
 c.action("flintlock")
 c.player.travel.target=Vector3(launch.x,0,launch.z-12)
 for i in 300:c.physics_step(1.0/120)
 check(game.player.position.z>launch.z-7,"Aimed launch cannot teleport or pass through a solid wall")
 check(c.player.travel==null and game.player.is_on_floor(),"A blocked launch descends and resolves against a real floor")
 barrier.queue_free();await frames()
 for raised in [false,true]:
  await fresh(8);c=game.player.active_ability
  game.player.jump_buffer=.15
  for i in 65:c.physics_step(1.0/60)
  var origin: Vector3=game.player.position
  var platform: StaticBody3D
  c.action("flintlock")
  if raised:
   platform=StaticBody3D.new();platform.collision_layer=1;platform.collision_mask=0
   var platform_shape=CollisionShape3D.new();var platform_box=BoxShape3D.new();platform_box.size=Vector3(8,10,8);platform_shape.shape=platform_box;platform.add_child(platform_shape);game.add_child(platform)
   platform.position=origin+Vector3(12,1,0)
   await frames()
   c.player.travel.target=origin+Vector3(12,6,0)
  else:c.player.travel.target=origin+Vector3(8,-3,0)
  for i in 450:c.physics_step(1.0/120)
  check(c.player.travel==null,"An unreachable landing target releases travel (raised=%s)"%raised)
  check(game.player.is_on_floor(),"Unreachable target falls safely onto a real floor (raised=%s)"%raised)
  if platform!=null:platform.queue_free();await frames()
 game.queue_free();await frames(3)
 print("DRAGOON_FLIGHT_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
