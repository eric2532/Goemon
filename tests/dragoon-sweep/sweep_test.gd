extends "res://tests/forest-shrine/explorer_close_assist_test.gd"
func run():
 game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
 await frames(3);game.start_wave();game.model.waves.spawn_clock=10000;game.model.waves.pending=0
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 game.tuning.invincible=true;game.tuning.critical_chance=0.0;game.player.smoke_mode=true;game.player.smoke_move=Vector2.ZERO
 await fresh(8);var c=game.player.active_ability
 var basic=target(Vector3(0,0,-2.5));c.action("cutlass");c.tick(.101,false)
 var normal=10000.0-float(basic.hp)
 check(normal>0,"Baseline is real normal lance damage")
 await fresh(8);c=game.player.active_ability
 var victim=target(Vector3(0,0,-2.5));var left=target(Vector3(-2,0,-2.5));var right=target(Vector3(2,0,-2.5));var behind=target(Vector3(0,0,3));var far=target(Vector3(0,0,-12))
 c.action("flintlock")
 check(c.player.travel==null and c.player.attack!=null and c.player.attack.get("style","")=="dragoon-sweep","Grounded RMB starts a sweep instead of a leap")
 if c.player.attack!=null:
  check(c.player.cooldowns.flintlock>0,"Grounded sweep retains a cooldown")
  c.tick(.19,false);check(victim.hp==10000,"Sweep damage waits for the stroke")
  c.tick(.04,false);check(is_equal_approx(10000-float(victim.hp),normal*3),"First sweep hit deals 3x normal left-click damage")
  c.tick(.12,false);check(is_equal_approx(10000-float(victim.hp),normal*6),"Second sweep hit deals another 3x")
  c.tick(.12,false);check(is_equal_approx(10000-float(victim.hp),normal*9),"Third sweep hit completes 9x total base damage")
  check(left.hp<10000 and right.hp<10000,"Wide sweep hits enemies on both sides of the front arc")
  check(behind.hp==10000 and far.hp==10000,"Sweep excludes enemies behind or beyond its reach")
  var hp: float=victim.hp
  c.tick(.6,false);c.tick(1.0,false)
  check(victim.hp==hp,"Sweep never repeats extra hits after recovery")
 await fresh(8);c=game.player.active_ability;victim=target(Vector3(0,0,-2.5))
 c.action("flintlock");c.tick(2.0,false)
 check(is_equal_approx(10000-float(victim.hp),normal*9),"A large boosted tick still resolves exactly three hits")
 for button in ["cutlass","flintlock"]:
  await fresh(8);c=game.player.active_ability
  game.player.jump_buffer=.15
  for i in 20:c.physics_step(1.0/120)
  c.player.cooldowns.cutlass=10;c.player.cooldowns.flintlock=10
  game.forest_ui.sync()
  check(not game.forest_ui.cooldown_masks[0].visible and not game.forest_ui.cooldown_masks[1].visible,"Both aerial attack icons ignore ground cooldowns")
  c.action(button)
  check(c.player.travel!=null and c.player.travel.phase=="aimed-drop","Airborne "+button+" triggers Dragon Leap despite ground cooldowns")
  check(c.player.attack==null,"Airborne "+button+" does not perform a ground attack")
  var landed=false
  for i in 180:
   c.physics_step(1.0/120)
   if game.player.is_on_floor() and c.player.travel==null:
    landed=true
    check(c.visual_actor.cosplay_rig.dragoon_motion.last_clip=="jump_strike","Rapid "+button+" dive uses its approved landing pose")
    break
  check(landed,"Rapid "+button+" dive returns to the floor")
 await fresh(8);c=game.player.active_ability;victim=target(Vector3(0,0,-2.5))
 var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(8,6,.3);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.position=ORIGIN+Vector3(0,2,-1.3);await frames()
 c.action("flintlock");c.tick(1.0,false)
 check(victim.hp==10000,"All sweep hits respect solid cover")
 wall.queue_free();await frames()
 # A canceled stroke cannot release delayed hits.
 await fresh(8);c=game.player.active_ability;victim=target(Vector3(0,0,-2.5))
 c.action("flintlock");c.tick(.1,false);c.action("roll");c.tick(1.0,false)
 check(victim.hp==10000,"Dodging before contact cancels all sweep damage")
 await fresh(8);c=game.player.active_ability
 var actor=c.visual_actor;var sk: Skeleton3D=actor.cosplay_rig.skeleton
 var tips=[]
 for t in [.16,.58]:
  actor.animate_pose({"grounded":true,"attack":{"style":"dragoon-sweep","time":t,"duration":.84,"contact":.22}},0,t)
  tips.append(sk.to_local(actor.joints.Weapon_Cutlass.node.to_global(actor.WEAPON_AXES.dragoon)))
 check(tips[0].x<tips[1].x-.8,"Approved lance pose sweeps from character left to right")
 var moves=SoundLibrary.moves_for(8)
 check(moves.has("sweep") and moves.has("secondary"),"Sweep and Dragon Leap retain separate paired sound groups")
 game.queue_free();await frames(3)
 print("DRAGOON_SWEEP_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
