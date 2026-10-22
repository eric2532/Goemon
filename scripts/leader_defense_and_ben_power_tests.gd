extends "res://scripts/recovered_leaders_tests.gd"
const Fixture=preload("res://scripts/recovered_leader_projectile_tests.gd")

func hit_pair(p: Hero,c: Node,label_: String):
 var hp=p.hp;var velocity=p.velocity
 p.invuln=0;p.take_hit(5,Vector3.RIGHT,false)
 p.invuln=0;p.take_hit(5,Vector3.BACK,true)
 check(p.hp==hp and p.velocity==velocity and c.is_attacking(),label_+" prevents melee, projectiles and hit interruption")

func clear_shots():
 for shot in get_nodes_in_group("leader_projectiles"):shot.free()
 for shot in get_nodes_in_group("ed_assault_orbs"):shot.free()

func run():
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="user://leader-defense-power-%s.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;await frames(5)
 game.begin_forest();game.choose_rogue_character(14);game.start_wave()
 game.tuning.invincible=false;game.tuning.freeze_ai=true;game.tuning.critical_chance=0;game.character_tuning={};await frames(10)
 var p=game.player;p.set_physics_process(false);p.model.set_process(false)
 p.position=Vector3(0,20,0);p.velocity=Vector3.ZERO;p.hp=p.max_hp
 var c=p.active_ability
 c.primary_held=true;c.start_attack(false)
 check(c.protects_player(),"Ed's held beam protects immediately during its windup")
 var shield=c.beam.get("shield") if is_instance_valid(c.beam) else null
 check(is_instance_valid(shield) and shield.is_visible_in_tree(),"Held beam displays a blue protective shield")
 hit_pair(p,c,"Held beam")
 c.tick(2.0);check(c.protects_player(),"Beam protection survives repeated native animation loops")
 c.release_input(event("light_attack",false));var hp=p.hp;p.invuln=0;p.take_hit(5,Vector3.RIGHT)
 check(p.hp<hp and not c.protects_player(),"Releasing the beam immediately restores incoming damage")
 p.hp=p.max_hp;p.invuln=0;p.velocity=Vector3.ZERO;c.start_utility()
 check(c.protects_player(),"Ed's E smoke assault is invulnerable from the first hop")
 hit_pair(p,c,"Smoke assault")
 c.tick(4.0);check(c.protects_player(),"Smoke-assault invulnerability lasts through its final active hop")
 c.tick(1.0);check(not c.protects_player(),"Finishing E removes invulnerability while released balls remain independent")
 clear_shots();c.start_utility();c._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(not c.protects_player(),"Focus loss cancels Ed's protection")
 c.primary_held=true;c.start_attack(false);p.select_character(15)
 check(not c.protects_player(),"Switching from Ed removes beam protection")
 c=p.active_ability;p.position=Vector3(0,80,0);p.velocity=Vector3.ZERO;p.ai_controlled=true;p.ai_aim=p.position+Vector3.FORWARD*100
 c.start_attack(false)
 check(is_equal_approx(p.attack_duration,1.45),"Ben completes the full polearm sequence in half its former2.9seconds")
 c.tick(.8);check(c.polearm_dash_distance==0,"Faster polearm retains its planted setup before the lunge")
 c.tick(.04)
 check(c.polearm_dash_distance>0 and c.polearm_dash_distance<=1.412,"A far aim cannot create a screen-crossing polearm impulse")
 c.tick(.7);check(not c.is_attacking(),"Ben's faster polearm exits recovery after its original source keys")
 c.cancel();c.start_utility();c.tick(.17)
 var stars=get_nodes_in_group("leader_projectiles").filter(func(shot):return shot.shuriken)
 check(stars.size()==3 and is_equal_approx(stars[0].damage,168),"Ben's doubled-speed E launches three projectiles with doubled168damage")
 if not stars.is_empty():
  var victim=Fixture.Victim.new();victim.position=stars[1].global_position+stars[1].velocity.normalized()*3;game.add_child(victim);victim.hp=1000;game.enemies.append(victim)
  stars[1]._physics_process(.5)
  check(victim.hp==832,"Ben's projectile deals its doubled damage to a real fitted hurt volume")
  game.enemies.erase(victim);victim.free()
 clear_shots();c.cancel();c.start_attack(true);c.release_bomb(Vector3(0,80,-6))
 var bombs=get_nodes_in_group("leader_projectiles").filter(func(shot):return shot.bomb)
 check(bombs.size()==1 and is_equal_approx(bombs[0].damage,276),"Ben's bomb snapshots doubled276damage")
 if not bombs.is_empty():
  var victim=Fixture.Victim.new();victim.position=Vector3(0,80,-6);game.add_child(victim);victim.hp=1000;game.enemies.append(victim)
  bombs[0]._physics_process(1.0)
  check(victim.hp==724,"The one-second bomb deals doubled damage once on actual detonation")
  game.enemies.erase(victim);victim.free()
 clear_shots();c.cancel();c.start_attack(false)
 var melee=Fixture.Victim.new();melee.position=p.position+Vector3.FORWARD*8;game.add_child(melee);melee.hp=1000;game.enemies.append(melee)
 p.strike();check(melee.hp==868,"Ben's actual polearm hit deals doubled132damage")
 game.enemies.erase(melee);melee.free();p.ai_controlled=false;c.cancel()
 stop_audio(game);game.move_audio.stop();await create_timer(.35).timeout;current_scene=null;game.queue_free();await frames(4)
 print("LEADER_DEFENSE_POWER_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)

func event(action: String,pressed: bool=true)->InputEventAction:
 var e=InputEventAction.new();e.action=action;e.pressed=pressed;return e
