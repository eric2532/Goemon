extends SceneTree
var game
var checks=0
var failures=0
var cfg="user://movement-cancel-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label_)
func frames(n:int=3):
 for i in n:await process_frame
func press(action:String):
 var e=InputEventAction.new();e.action=action;e.pressed=true;game.player._unhandled_input(e)
func fresh(id:int):
 var p=game.player
 p.cancel_charge();p.quick_attacks.cancel();p.attack_left=0;p.impact_pause=0;p.dodge_time=0;p.dodge_cooldown=0;p.jump_buffer=0;p.jump_windup=0;p.attack_chain.reset();p.reset_auto_attack()
 p.select_character(id);p.position=Vector3(0,.15,60);p.velocity=Vector3.ZERO;p.smoke_mode=true;p.smoke_move=Vector2.ZERO;p.facing=Vector3.FORWARD;p.jumps_used=0;p.coyote=.13
 if p.is_rogue_character():p.active_ability.reset_run()
 for i in 20:p._physics_process(1.0/60)
 p.coyote=.13;p.jumps_used=0
 game.camera_rig.yaw=0;game.camera_rig.camera.global_position=p.position+Vector3(0,2.4,10);game.camera_rig.camera.look_at(p.position+Vector3(0,1,-20))
 return p
func begin(p):
 press("light_attack")
 if p.is_rogue_character():p.active_ability.hit_stop=.045
 p.impact_pause=.045
func run():
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_original();set_meta("forest_custom_layout",doc.data)
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames()
 game.start_wave();game.model.waves.pending=999;game.model.waves.spawn_clock=100000
 game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
 for id in range(1,13):
  var p=fresh(id);begin(p)
  var attack_left=p.attack_left;var impact_pause=p.impact_pause
  check(p.has_offensive_action(),"Character %d begins real offense before jumping"%id)
  var attack=p.active_ability.player.attack if p.is_rogue_character() else null
  press("jump")
  check(p.attack_left==attack_left and p.impact_pause==impact_pause,"Character %d jump preserves attack and hit pause"%id)
  if p.is_rogue_character():
   var c=p.active_ability
   check(c.player.attack==attack and c.hit_stop==.045,"Character %d jump retains its offensive action"%id)
  for i in 12:
   p._physics_process(1.0/60)
   if p.velocity.y>0:break
  check(p.velocity.y>0,"Character %d can take off while attacking"%id)
  p=fresh(id);begin(p);press("dodge")
  check(p.attack_left==0 and p.impact_pause==0,"Character %d dodge cancels the current attack immediately"%id)
  if p.is_rogue_character():
   var c=p.active_ability
   check(c.player.attack==null and not c.player.charging and c.hit_stop==0 and (c.player.roll>0 or c.player.invuln>0),"Character %d begins its actual evade without attack hit-stop"%id)
  else:check(p.dodge_time>0,"Character %d starts native evade immediately"%id)
 # Attacks can also be initiated after takeoff, without dropping the jump.
 for id in range(1,13):
  var airborne=fresh(id);press("jump")
  for i in 6:airborne._physics_process(1.0/60)
  var altitude=airborne.position.y;var ascending=airborne.velocity.y>0
  press("light_attack")
  var attacking=airborne.active_ability.player.attack!=null or airborne.active_ability.player.charging or airborne.active_ability.player.dive!=null or airborne.active_ability.player.travel!=null if airborne.is_rogue_character() else airborne.attack_left>0 or airborne.musashi!=null and airborne.musashi.blocks_movement()
  check(altitude>.2 and ascending and attacking,"Character %d can start an attack in mid-jump"%id)
 # Ordinary jumps carry existing running velocity, including in mid-air.
 for id in [1,2,5,10]:
  var running=fresh(id);running.velocity=Vector3(8,0,0)
  if running.is_rogue_character():running.active_ability.locomotion_velocity=Vector3(8,0,0)
  press("jump")
  check(is_equal_approx(running.velocity.x,8),"Character %d running jump retains normal horizontal momentum"%id)
  running.jumps_used=1;running.coyote=0;running.position.y=3;running.velocity=Vector3(8,2,0);press("jump")
  check(is_equal_approx(running.velocity.x,8),"Character %d double-jump retains normal horizontal momentum"%id)
 for action in ["jump","dodge"]:
  var swordsman=fresh(9);var sword=swordsman.active_ability;sword.action("roll");sword.physics_step(1.0/60)
  sword.player.cooldowns.roll=0 # Exercise an available dodge; cooldown rules stay intact.
  var previous_roll=float(sword.player.roll);press(action)
  check(sword.player.roll==previous_roll if action=="jump" else sword.player.roll>previous_roll,"Jump preserves offensive dash; dodge interrupts it (%s)"%action)
  if action=="jump":
   for i in 4:sword.physics_step(1.0/60)
   check(sword.player.roll>0 or sword.player.attack!=null,"Jump preserves the dash-strike and its delayed claymore attack")
 # Right-click speed changes time, not distance, damage or cooldown.
 var p=fresh(5);var c=p.active_ability;c.action("flintlock")
 check(is_equal_approx(c.player.rollDuration,.14) and is_equal_approx(c.player.rollSpeed,81),"Ninja Shadow Cut travels three times faster")
 check(is_equal_approx(c.player.rollDuration*c.player.rollSpeed,11.34) and c.player.dashAttack.damage==76,"Faster Ninja dash retains distance and damage")
 for action in ["jump","dodge"]:
  p=fresh(5);c=p.active_ability;c.action("flintlock");c.physics_step(1.0/60)
  var cooldown=float(c.player.cooldowns.flintlock);press(action)
  check(c.player.dashAttack!=null if action=="jump" else c.player.dashAttack==null and c.player.travel==null and c.player.dive==null,"Jump preserves Ninja dash; dodge discards its finishing hit (%s)"%action)
  check(c.player.cooldowns.flintlock==cooldown,"%s cancellation does not refund Ninja's secondary cooldown"%action)
 # Cancels do not erase released projectiles, buffs or skill cooldowns.
 p=fresh(10);c=p.active_ability;c.action("cutlass");c.tick(.08)
 var arrows=c.projectiles.duplicate();c.player.buffTime=4;var cooldown=float(c.player.cooldowns.cutlass);press("jump")
 check(not arrows.is_empty() and arrows.all(func(a):return is_instance_valid(a.mesh) and not a.mesh.is_queued_for_deletion()),"Jump preserves Ranger arrows already released")
 check(c.player.buffTime==4 and c.player.cooldowns.cutlass==cooldown,"Jump preserves buffs and attack cooldowns")
 # Cancelled windups cannot land after the original contact time.
 p=fresh(5);c=p.active_ability
 var foe=game.model.waves.spawn_enemy(0,p.position+Vector3.FORWARD*2.2);foe.hp=10000;foe.max_hp=10000
 game.sync_enemies();var enemy=game.actors[foe.id];enemy.set_physics_process(false);enemy._sync_fitted_pose();game.model.update_vision(p.position)
 begin(p);press("dodge")
 for i in 40:c.physics_step(1.0/60)
 check(foe.hp==10000,"A cancelled basic swing never deals its delayed damage")
 enemy.queue_free();game.enemies.erase(enemy);game.actors.clear();game.model.enemies.clear()
 # A jump must retain a real pending hit, not just its animation timer.
 p=fresh(5);c=p.active_ability
 foe=game.model.waves.spawn_enemy(0,p.position+Vector3.FORWARD*2.2);foe.hp=10000;foe.max_hp=10000
 game.sync_enemies();enemy=game.actors[foe.id];enemy.set_physics_process(false);enemy._sync_fitted_pose();game.model.update_vision(p.position)
 press("light_attack");press("jump");var airborne_contact=false
 for i in 40:
  p._physics_process(1.0/60)
  if foe.hp<10000 and p.position.y>.2:airborne_contact=true
 check(airborne_contact,"Ninja's swing deals damage after jumping instead of being cancelled")
 enemy.queue_free();game.enemies.erase(enemy);game.actors.clear();game.model.enemies.clear()
 # Stopping an active Shadow Cut must not apply its endpoint strike later.
 p=fresh(5);c=p.active_ability
 foe=game.model.waves.spawn_enemy(0,p.position+Vector3.FORWARD*13.5);foe.hp=10000;foe.max_hp=10000
 game.sync_enemies();enemy=game.actors[foe.id];enemy.set_physics_process(false);enemy._sync_fitted_pose();game.model.update_vision(p.position)
 c.action("flintlock");c.physics_step(1.0/60);press("dodge")
 for i in 40:c.physics_step(1.0/60)
 check(foe.hp==10000,"A cancelled Shadow Cut cannot damage its abandoned endpoint")
 p=fresh(5);c=p.active_ability;begin(p);var attack=c.player.attack;c.evade_cooldown=.75;press("dodge")
 check(c.player.attack==attack,"Dodge cancellation respects the existing evade cooldown")
 p=fresh(1);p.sky_strike.origin=Vector3(20,0,20);p.sky_strike.active=true;p.position.y=2;p.coyote=.13
 var position_before=p.position;p.dodge_cooldown=0;press("dodge")
 check(p.position==position_before and not p.sky_strike.active,"Cancelling Goemon's leap does not teleport back to its origin")
 game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames();await create_timer(.15).timeout
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("ATTACK_MOVEMENT_CANCEL_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
