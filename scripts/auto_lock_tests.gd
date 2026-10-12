extends "res://scripts/auto_attack_tests.gd"
func run():
 game.smoke_test=true;Input.use_accumulated_input=false
 game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
 ProjectSettings.set_setting("goemon/experimental_crosshair",true)
 game.player.smoke_mode=true;game.start_mode("defense");pause_fixture_director();await frames(3)
 await fresh_class(7)
 var p=game.player;var rig=game.camera_rig
 rig.set_process(false);p.set_physics_process(false)
 p.position=Vector3(0,.1,210);p.active_ability.player.pos=p.position
 rig.camera.global_position=p.position+Vector3(0,3,10);rig.camera.look_at(p.position+Vector3(0,1,-20))
 var near=fixture(Vector3(4,0,-12));var far=fixture(Vector3(-4,0,-25));var behind=fixture(Vector3(0,0,18))
 await frames(2);p.set_auto_attack(true)
 var want=(near.position+Vector3.UP*1.1-p.position).normalized();want.y=0;want=want.normalized()
 check(game.attack_direction().dot(want)>.999,"J aims at nearest visible enemy even away from camera center")
 var before=rig.camera.global_transform;var yaw=rig.yaw
 if p.has_method("auto_aim_target"):
  check(p.auto_aim_target()==near,"J locks onto nearest visible living target")
  near.dead=true
  check(p.auto_aim_target()==far,"Death immediately reacquires the next target")
  near.dead=false
  var wall=obstacle(Vector3(2,2,-6),Vector3(3,5,.5));await frames(2);p.set_auto_attack(true)
  check(p.auto_aim_target()==far,"A closer enemy behind a physical wall cannot lock")
  wall.free();await frames(2);p.set_auto_attack(true)
  check(p.auto_aim_target()==near,"Removing cover makes nearest enemy available again")
  var camera_cover=obstacle(Vector3(0,3,6),Vector3(7,6,.5));await frames(2);p.set_auto_attack(true)
  check(p.auto_aim_target()==null,"Camera cover prevents locking even with a clear muzzle path")
  camera_cover.free();await frames(2);p.set_auto_attack(true)
  var low_cover=obstacle(Vector3(2,.6,-6),Vector3(2,1.2,.5));await frames(2);p.set_auto_attack(true)
  check(p.auto_aim_target()==far,"Low cover excludes enemies blocked at Ranger's real launch height")
  var low_origin=p.position+Vector3.UP*1.05
  check(game.projectile_direction(low_origin).dot((far.position+Vector3.UP*1.1-low_origin).normalized())>.999,"Ranger release aims at the unobstructed enemy beyond low cover")
  low_cover.free();await frames(2);p.set_auto_attack(true)
  rig.camera.look_at(p.position+Vector3(0,1,40))
  check(p.auto_aim_target()==behind,"Turning the camera drops enemies that leave sight")
  rig.camera.look_at(p.position+Vector3(0,1,-20));p.set_auto_attack(true)
  for id in range(1,13):
   p.select_character(id);p.set_physics_process(false);p.position=Vector3(0,.1,210);p.set_auto_attack(true)
   if p.is_rogue_character():p.active_ability.player.pos=p.position;p.active_ability._update_aim()
   var origin=p.position+Vector3.UP*1.05
   check(game.projectile_direction(origin).dot((near.position+Vector3.UP*1.1-origin).normalized())>.999,"Hero %d projectiles use locked aim" % id)
   if p.is_rogue_character():check(p.active_ability.aim.distance_to(near.position+Vector3.UP*1.1)<.01,"Hero %d melee and abilities use locked aim" % id)
  p.select_character(10);p.set_physics_process(false);p.position=Vector3(0,.1,210);p.set_auto_attack(true)
  var a=p.active_ability;a.player.pos=p.position;a._update_aim();a.player.angle=atan2(a.aim.x-p.position.x,a.aim.z-p.position.z)
  a.Actions.fire_ranger_fan(a,a.player.angle,true,"flintlock",a.ranger_ground_target(a.player.angle))
  check(a.projectiles.size()==5 and a.projectiles.all(func(pr):return pr.rangerFlight.get("curved",false)),"Locked Ranger fan retains five curved arrows")
  check(a.projectiles.any(func(pr):return pr.vel.normalized().distance_to(pr.aimDirection)>.001),"Locked Ranger keeps independent release deviation")
  check(absf(a.projectiles[0].aimDirection.signed_angle_to(a.projectiles[4].aimDirection,Vector3.UP))>.9,"Locked Ranger keeps broad fan spread")
  a.cancel()
  near.free()
  check(p.auto_aim_target()==far,"Freed enemy references safely reacquire a living enemy")
  far.dead=true;behind.dead=true
  check(p.auto_aim_target()==null,"No visible living enemies releases the lock")
  p.set_auto_attack(false)
  check(p.auto_aim_target()==null,"J off releases target")
  check(game.attack_direction().dot(Vector3.FORWARD.rotated(Vector3.UP,yaw))>.999,"J off restores manual camera aim")
  p.set_auto_attack(true);p.hp=0;check(p.auto_aim_target()==null,"Death cannot retain active lock");p.hp=p.max_hp
  p.reset_auto_attack();check(p.auto_aim_target()==null,"New run reset clears lock")
 # Stand behind the target-facing camera: both targets are on screen, but only
 # the closer one is hidden behind cover along the camera's sight line.
 await clear_enemies();p.select_character(1);p.set_physics_process(false);p.position=Vector3(0,.1,210)
 var visible=fixture(Vector3(-4,0,-25));var hidden=fixture(Vector3(4,0,-12))
 rig.camera.global_position=p.position+Vector3(0,3,10);rig.camera.look_at(p.position+Vector3(0,1,-20))
 var camera_wall=obstacle(Vector3(1.1,2.5,4),Vector3(1.2,4,.3));await frames(2);p.set_auto_attack(true)
 check(p.auto_aim_target()==visible,"Camera-hidden enemy does not override J target")
 game.throw_coin(false,false,1,{},true)
 var coins=get_tree().get_nodes_in_group("projectiles").filter(func(pr):return pr is GoldCoin)
 check(not coins.is_empty() and coins.back().velocity.normalized().dot((visible.position+Vector3.UP*1.1-(p.position+Vector3.UP*1.25)).normalized())>.999,"Goemon background coins keep J's camera-visible target")
 camera_wall.free();await frames(2)
 p.select_character(2);p.set_physics_process(false);p.set_auto_attack(true)
 var hand=p.model.hand_position("R")
 var near_point=hidden.position+Vector3.UP*1.1
 var block_point=hand.lerp(near_point,.25)
 var release_wall=obstacle(block_point-p.position,Vector3(.1,.1,.1));await frames(2);p.set_auto_attack(true)
 check(p.auto_aim_target()==visible,"Edo acquisition checks the animated hand rather than a fixed chest height")
 p.musashi.large_cast=true;p.musashi.launch()
 var balls=get_tree().get_nodes_in_group("musashi_projectiles")
 check(not balls.is_empty() and balls.back().velocity.normalized().dot((visible.position+Vector3.UP*1.1-hand).normalized())>.999,"Actual Edo fireball release chooses an unobstructed enemy around hand cover")
 release_wall.free();await frames(2);p.reset_auto_attack()
 check(rig.camera.global_transform.is_equal_approx(before) and rig.yaw==yaw,"J never takes over mouse camera control")
 # Actual primary releases must reach an enemy offset from the camera heading.
 rig.set_process(true);p.set_physics_process(true)
 for id in range(1,13):
  if id>=3:await fresh_class(id-3)
  else:await fresh_goemon();p.select_character(id);game.camera_rig.yaw=-PI/2;await frames(5)
  p.set_physics_process(true);p.attack_chain.reset()
  var victim=fixture(Vector3(3,0,-1));tap("auto_attack_toggle");await frames(110)
  check(victim.hp<10000,"Hero %d auto primary damages an off-center locked enemy" % id)
  p.set_auto_attack(false)
 finish()
func finish():
 game.show_main_menu();game.sound_library.cancel();game.music.stop();stop_audio(game);await frames(3)
 print("AUTO_LOCK_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
