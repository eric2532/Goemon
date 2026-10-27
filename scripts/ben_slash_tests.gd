extends "res://scripts/recovered_leaders_tests.gd"
const Fixture=preload("res://scripts/recovered_leader_projectile_tests.gd")

func press(down: bool):
 var event=InputEventAction.new();event.action="light_attack";event.pressed=down
 game.player.active_ability.input(event)

func run():
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="user://ben-slash-%s.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;await frames(5)
 game.begin_forest();game.choose_rogue_character(15);game.start_wave()
 game.tuning.invincible=true;game.tuning.freeze_ai=true;game.tuning.critical_chance=0;game.character_tuning={};await frames(10)
 var p=game.player;var c=p.active_ability
 p.set_physics_process(false);p.model.set_process(false);p.set_auto_attack(false)
 p.position=Vector3(0,80,0);p.ai_controlled=true;p.ai_aim=p.position+Vector3.FORWARD*100
 var victim=Fixture.Victim.new();victim.position=p.position+Vector3.FORWARD*8
 game.add_child(victim);game.enemies.append(victim);victim.hp=1000
 press(true);press(false);c.tick(.8)
 check(not c.is_attacking() and c.polearm_dash_distance==0,"One click finishes only the spinning slash")
 check(victim.hp==868,"First click damages a target only once")
 c.tick(2.0)
 check(not c.is_attacking() and victim.hp==868,"No second strike runs without another press")
 press(true);press(false)
 check(c.combo==1 and is_equal_approx(c.motion_time(),44.0/30.0),"Second click resumes at the original lunge windup")
 c.tick(.4);var second_hp=victim.hp;c.tick(.4)
 check(second_hp<868 and victim.hp==second_hp and not c.is_attacking(),"Second click has one independent damage contact")
 press(true);press(false)
 check(c.combo==0,"The next click returns to the first slash")
 c.tick(.8);c.tick_timers(1.2);press(true);press(false)
 check(c.combo==0,"Waiting past the combo window restarts at the first slash")
 c.cancel();press(true);c.tick(.8);c.tick(.8)
 check(not c.is_attacking(),"Holding LMB cannot automatically perform the second slash")
 press(false);c.cancel();press(true);press(false);c.tick(.1)
 press(true);press(false)
 check(c.queued_primary,"An early second click buffers the lunge")
 c.tick(.7)
 check(c.is_attacking() and c.combo==1 and not c.queued_primary,"A buffered click starts exactly one follow-through")
 c.tick(.8);c.tick(.8)
 check(not c.is_attacking(),"A buffered tap cannot keep repeating attacks")
 c.cancel();press(true);press(false);press(true);press(false)
 c._notification(NOTIFICATION_APPLICATION_FOCUS_OUT);c.tick(2)
 check(not c.queued_primary and not c.is_attacking() and c.combo_timer==0,"Focus loss clears queued clicks and combo progress")
 c.start_utility();c.tick(.5);press(true);press(false)
 check(c.combo==0,"Switching from the star fan starts with the first slash")
 c.cancel();c.start_attack(false)
 for i in 3:
  c.tick(.04);p.model.animate(.04,0,true,0,1,false,1,false)
 var trail=p.model.sword_trail
 check(trail.mesh!=null,"The actual animated blade draws its slash ribbon")
 if trail.mesh!=null:
  var colors=trail.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
  check(colors[0].r>.99 and colors[0].g>.9 and colors[0].b<.8,"Ben's slash trail uses warm yellow")
 trail.advance(.12,PackedVector3Array(),false,true)
 check(trail.mesh!=null,"Slash samples remain visible beyond the former 0.11 second lifetime")
 trail.advance(.11,PackedVector3Array(),false,true)
 check(trail.mesh==null and trail.samples.is_empty(),"The doubled 0.22 second trail still expires completely")
 c.cancel();game.enemies.erase(victim);victim.free();p.ai_controlled=false
 stop_audio(game);game.move_audio.stop();await create_timer(.35).timeout
 current_scene=null;game.queue_free();await frames(4)
 print("BEN_SLASH_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
