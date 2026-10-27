extends "res://scripts/recovered_leaders_tests.gd"
const Fixture=preload("res://scripts/recovered_leader_projectile_tests.gd")
func run():
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="user://ed-assault-%s.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;await frames(5)
 game.begin_forest();game.choose_rogue_character(14);game.start_wave();game.tuning.invincible=true;game.tuning.freeze_ai=true;game.tuning.critical_chance=0;game.character_tuning={};await frames(10)
 var p=game.player;p.smoke_mode=true;p.position=Vector3(0,.05,18);p.velocity=Vector3.ZERO
 p.ai_controlled=true;p.ai_aim=p.position+Vector3.RIGHT*20;p.facing=Vector3.FORWARD
 var c=p.active_ability
 check(game.forest_ui.ben_utility_tile.visible and game.forest_ui.ben_utility_tile.tooltip_text=="E · Smoke assault · R · Quick Burst","Ed HUD exposes his E smoke assault")
 var event=InputEventAction.new();event.action="equip";event.pressed=true;c.input(event)
 check(c.mode=="smoke_assault","E starts Ed's separate smoke assault")
 if c.mode=="smoke_assault":
  check(get_nodes_in_group("ed_assault_charge").size()==1,"Ed holds the native purple charge before releasing the large ball")
  var origin=p.position;await frames(20)
  check(p.position.distance_to(origin)>1 and p.position.y>origin.y+.3,"Smoke assault moves Ed through real collision physics in an airborne somersault")
  p.set_physics_process(false)
  var clock=c.elapsed;game.paused=true;c.tick(.5);check(c.elapsed==clock,"Pause freezes the assault timeline");game.paused=false
  c.tick(.75)
  check(get_nodes_in_group("ed_assault_orbs").any(func(shot):return is_equal_approx(shot.damage,270)),"Ed releases a large triple-damage assault ball during his leap")
  check(get_nodes_in_group("ed_assault_orbs").any(func(shot):return shot.velocity.normalized().dot(Vector3.RIGHT)>.8),"Smoke-assault ball follows Ed's current combat aim rather than stale facing")
  check(get_nodes_in_group("leader_projectiles").is_empty(),"Recovered assault ball replaces the ordinary fireball volleys")
  p.ai_controlled=false
  check(get_nodes_in_group("ed_assault_smoke").size()>0,"Assault emits visible smoke")
  c.cancel();check(not c.is_attacking() and c.ground_attack_velocity()==Vector3.INF and get_nodes_in_group("ed_assault_charge").is_empty(),"Cancellation immediately releases movement and removes the attached charge")
  for shot in get_nodes_in_group("ed_assault_orbs"):shot.free()
  c.start_utility()
  var victim=Fixture.Victim.new();victim.position=p.position+Vector3(6,0,0);game.add_child(victim);victim.hp=1000;game.enemies.append(victim);game.enemies.append(victim)
  c.tick(4.11)
  check(victim.hp==1000,"Completing the leap timeline cannot trigger an unrelated finishing blast")
  var balls=get_nodes_in_group("ed_assault_orbs")
  check(balls.size()==3 and c.assault.balls_fired==3,"A long frame releases exactly one original ball per hop")
  check(balls.size()==3 and balls.all(func(ball):return is_equal_approx(ball.fire_speed_scale,3.0) and is_equal_approx(ball.fuse,2.4)),"All three E balls spread fire three times faster while keeping their original fuse")
  if not balls.is_empty():
   balls[0].global_position=p.global_position+Vector3.UP;balls[0]._explode()
   check(victim.hp==730 and c.assault.bursts==1,"The actual ball burst damages a fitted target six metres away for270 once despite duplicate snapshots")
  game.enemies.erase(victim);game.enemies.erase(victim);victim.free()
  c.tick(1);check(c.assault.bursts==1 and not c.is_attacking(),"Assault completes without duplicating the released ball burst or leaving a stuck attack")
  var previous_ball=balls[1] if balls.size()>1 else null
  c.start_utility();c._notification(NOTIFICATION_APPLICATION_FOCUS_OUT);c.tick(5)
  if is_instance_valid(previous_ball):previous_ball._explode()
  check(not c.is_attacking() and c.assault.bursts==0 and get_nodes_in_group("ed_assault_charge").is_empty(),"Focus loss clears charge and old released balls cannot mutate a later cast")
  c.start_utility();event.action="light_attack";c.input(event)
  check(c.mode=="beam","Primary fire immediately replaces the smoke assault")
  c.cancel();c.start_utility();p.dodge_cooldown=0;event.action="dodge";p._unhandled_input(event)
  check(not c.is_attacking() and p.dodge_time>0,"C evade interrupts the smoke assault immediately")
  p.dodge_time=0;c.start_utility();p.select_character(15);check(not c.is_attacking(),"Switching fighters cancels Ed's assault")
 for shot in get_nodes_in_group("ed_assault_orbs"):shot.free()
 p.select_character(14);p.ai_controlled=false;p.set_physics_process(false);p.dodge_time=0
 event.action="surge";event.pressed=true;p._unhandled_input(event)
 check(c.mode=="quick_burst" and p.spell_loadout.spell_for(14,"surge")=="ed/quick-burst","R starts Quick Burst and exposes it as Edo's default R spell")
 c.tick(.06)
 var quick_balls=get_nodes_in_group("ed_assault_orbs")
 check(quick_balls.size()==1 and get_nodes_in_group("ed_assault_charge").is_empty(),"Quick Burst releases exactly one E ball without the hop sequence")
 if quick_balls.size()==1:
  var ball=quick_balls[0];ball.set_physics_process(false)
  check(is_equal_approx(ball.damage,270) and is_equal_approx(ball.fuse,.18),"Quick Burst keeps E's damage with a short fuse")
  ball.global_position=Vector3(0,200,0);ball.velocity=Vector3.ZERO
  game.paused=true;ball._physics_process(1);game.paused=false
  check(is_zero_approx(ball.age) and not ball.exploded,"Pause freezes the quick fuse")
  ball._physics_process(.17);check(not ball.exploded,"Quick ball remains visible before its fuse expires")
  ball._physics_process(.01)
  check(ball.exploded and ball.flames.size()==8 and ball.cast_stats.bursts==1,"Quick ball bursts after 0.18 seconds into the same eight fire fronts")
  ball._physics_process(.5)
  var distance=6.0*ball.attack_scale*ball.range_scale
  check(ball.flames.all(func(flame):return is_equal_approx(Vector2(flame.global_position.x-ball.fire_origin.x,flame.global_position.z-ball.fire_origin.z).length(),distance)),"All eight Quick Burst flames travel three times faster")
  ball._physics_process(1.01)
  check(ball.is_queued_for_deletion() and is_equal_approx(ball.fire_age,1.5),"Quick Burst keeps its original reach by finishing the faster spread in 1.5 seconds")
  c.tick(3)
  check(get_nodes_in_group("ed_assault_orbs").size()==1 and not c.is_attacking(),"Holding R or a long frame cannot release more balls or leave casting stuck")
 c.cancel();p._unhandled_input(event);c.interrupt_for_dodge();c.tick(1)
 check(get_nodes_in_group("ed_assault_orbs").size()==1 and not c.is_attacking(),"Evading before quick release cancels the pending shot")
 for shot in get_nodes_in_group("leader_projectiles"):shot.queue_free()
 for shot in get_nodes_in_group("ed_assault_orbs"):shot.queue_free()
 stop_audio(game);game.move_audio.stop();await create_timer(.35).timeout;current_scene=null;game.queue_free();await frames(3)
 print("ED_SMOKE_ASSAULT_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
