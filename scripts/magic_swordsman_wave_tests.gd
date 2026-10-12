extends "res://scripts/rogue_equipment_combat_tests.gd"
## Exercise real secondary input and terrain rather than just projectile counts.
func run():
 Input.use_accumulated_input=false;game.smoke_test=true
 game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
 ProjectSettings.set_setting("goemon/experimental_crosshair",true)
 game.player.smoke_mode=true;game.start_mode("defense");pause_fixture_director();await frames(3)
 for mode in ["manual","low-reticle","close-lock"]:
  await fresh_class(6)
  var p=game.player;var a=p.active_ability
  for i in range(60):
   if p.is_on_floor():break
   await frames(1)
  var near=fixture(Vector3(3.5,0,0));var far=fixture(Vector3(35,0,0))
  var rig=game.camera_rig
  if mode=="low-reticle":
   rig.set_process(false)
   rig.camera.global_position=p.position+Vector3(-10,3,.65)
   rig.camera.look_at(p.position+Vector3(2,0,0))
  await frames(2)
  if mode=="close-lock":p.set_auto_attack(true)
  check(p.is_on_floor(),"%s starts on the real arena floor" % mode)
  press("heavy_attack")
  check(a.projectiles.size()==1,"%s RMB releases one shockwave" % mode)
  if not a.projectiles.is_empty():
   var wave=a.projectiles[0]
   check(wave.kind=="wave" and wave.mesh.get_child_count()>=4,"%s retains the visible energy wave" % mode)
   var bounds=AABB()
   for child in wave.mesh.get_children():
    if child is MeshInstance3D:bounds=bounds.merge(child.transform*child.get_aabb())
   check(bounds.size.y*wave.mesh.scale.y>.75,"%s wave has a visible upright silhouette from the gameplay camera" % mode)
  await frames(150)
  check(is_equal_approx(10000-near.hp,100),"%s shockwave hits the close enemy once" % mode)
  check(is_equal_approx(10000-far.hp,100),"%s piercing shockwave reaches the enemy 35 metres away" % mode)
  check(a.projectiles.is_empty(),"%s shockwave expires at its configured range" % mode)
  press("heavy_attack",false);p.set_auto_attack(false);rig.set_process(true)
 await fresh_class(6)
 var p=game.player;var a=p.active_ability
 var left=fixture(Vector3(18,0,-2.4));var right=fixture(Vector3(18,0,2.4))
 # Enemy/projectile collision radii extend the final travel segment's contact.
 var outside=fixture(Vector3(18,0,5));var beyond=fixture(Vector3(48,0,0))
 tap("heavy_attack")
 var cooldown=a.player.cooldowns.flintlock
 await frames(150)
 check(is_equal_approx(10000-left.hp,100) and is_equal_approx(10000-right.hp,100),"Wide wave damages enemies on both sides of its 5-metre corridor")
 check(outside.hp==10000 and beyond.hp==10000,"Wave respects its width and 40-metre range limits")
 check(cooldown>2,"Normal wave retains its existing secondary cooldown")
 # Airborne casts retain the actual 3D aim instead of forcing every wave level.
 await fresh_class(6);a=p.active_ability
 game.reset_player_at(TEST_ORIGIN+Vector3.UP*20);await frames(2)
 var aerial=fixture(Vector3(20,-8,0));p.set_auto_attack(true)
 var origin=p.position+Vector3.UP*1.65
 var aim_direction=(aerial.position+Vector3.UP*1.1-origin).normalized()
 press("heavy_attack")
 check(not p.is_on_floor() and a.projectiles.size()==1 and a.projectiles[0].vel.normalized().dot(aim_direction)>.999,"Airborne wave keeps the crosshair/locked target's vertical aim")
 await frames(100)
 check(is_equal_approx(10000-aerial.hp,100),"Airborne ranged wave reaches an elevated target")
 press("heavy_attack",false);p.set_auto_attack(false)
 await fresh_class(6);a=p.active_ability;tap("surge");press("heavy_attack");await frames(60)
 check(native_projectiles.size()==3,"Final Strike still repeats energy waves at its existing cadence")
 press("heavy_attack",false)
 # The restored wave must still stop at buildings rather than pass through cover.
 await fresh_class(6)
 a=p.active_ability
 var wall=obstacle(Vector3(5,3,0),Vector3(.5,6,10));var hidden=fixture(Vector3(10,0,0))
 await frames(2);tap("weapon_chain");await frames(150)
 check(native_projectiles.size()==1,"Key 3 still releases one shockwave")
 check(hidden.hp==10000 and a.projectiles.is_empty(),"Solid cover stops the ranged shockwave")
 wall.free()
 # A secondary press during sword windup is consumed once after contact.
 await fresh_class(6);a=p.active_ability
 tap("light_attack");await frames(2);tap("heavy_attack");await frames(30)
 check(native_projectiles.size()==1,"Sword windup buffers RMB without losing or duplicating the shockwave")
 game.show_main_menu();game.sound_library.cancel();game.music.stop();stop_audio(game);await frames(3)
 print("MAGIC_SWORDSMAN_WAVE_RESULT checks=",checks," failures=",failures)
 get_tree().quit(1 if failures else 0)
