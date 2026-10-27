extends "res://scripts/recovered_leaders_tests.gd"
## Real controller: grounded bomb throws, voluntary flight and faster descent.
func input_(action: String,down: bool):
 if down:Input.action_press(action)
 else:Input.action_release(action)
 var event=InputEventAction.new();event.action=action;event.pressed=down;game.player._unhandled_input(event)
func shots()->int:
 return get_nodes_in_group("leader_projectiles").filter(func(p):return not p.is_queued_for_deletion()).size()
func run():
 set_meta("forest_painterly_preview",true)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="user://ben-flight-test-%s.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;await frames(5)
 game.begin_forest();game.choose_rogue_character(15);game.start_wave()
 game.tuning.invincible=true;game.tuning.freeze_ai=true;game.character_tuning={}
 var p=game.player;p.position=Vector3(0,.2,22);p.velocity=Vector3.ZERO
 await frames(20)
 var c=p.active_ability;var floor_y=p.position.y
 check(p.is_on_floor(),"Ben starts the bomb test grounded")
 input_("heavy_attack",true);await frames(5)
 check(c.bomb_phase=="deploy" and p.is_on_floor() and absf(p.position.y-floor_y)<.1 and shots()==0,"Ground bombs retain a short windup without lifting Ben")
 await frames(28)
 check(c.bomb_phase=="barrage" and p.is_on_floor() and absf(p.position.y-floor_y)<.1 and shots()>0,"Ben throws bombs directly from the floor after windup")
 await frames(45)
 check(c.bomb_phase=="barrage" and p.is_on_floor() and absf(p.position.y-floor_y)<.1 and shots()>0,"Holding RMB sustains the barrage without an automatic takeoff")
 var count=shots();input_("heavy_attack",false);await frames(10)
 check(not c.is_attacking() and p.is_on_floor() and shots()<=count,"Releasing a grounded barrage stops throws without a flight landing phase")
 await frames(170)
 check(not c.is_attacking() and p.is_on_floor() and absf(p.position.y-floor_y)<.15,"The full descent and retraction restore grounded control")
 var extra_landing=false
 for i in 35:
  extra_landing=extra_landing or p.model.state in ["fly","land"]
  await physics_frame
 check(not extra_landing and not p.model.was_flying,"Completed retraction returns directly to ground control without another flight or landing pose")
 input_("heavy_attack",true);await frames(110);input_("heavy_attack",false);input_("jump",true);await frames(10)
 check(not c.is_attacking() and p.flying and p.velocity.y>0,"Space takes over directly from bomb descent without forced landing")
 input_("heavy_attack",true);await frames(2)
 var lift_start=p.position.y;var steady_lift=true
 for i in 64:
  await physics_frame
  steady_lift=steady_lift and absf(p.velocity.y-15)<.02
 check(c.bomb_phase=="barrage" and steady_lift and absf(p.position.y-lift_start-64.0/60.0*15)<.05,"Space-held bombing uses faster ascent without bob feedback or runaway height")
 input_("sprint",true)
 var boost_start=p.position.y;var steady_boost=true
 for i in 24:
  await physics_frame
  steady_boost=steady_boost and absf(p.velocity.y-24)<.02
 check(steady_boost and absf(p.position.y-boost_start-24.0/60.0*24)<.05,"Shift keeps the faster boosted ascent during bombing")
 input_("sprint",false);input_("heavy_attack",false);await frames(2)
 check(not c.is_attacking() and p.flying,"Releasing RMB while Space remains held preserves direct flight")
 input_("jump",false);await frames(240)
 check(p.is_on_floor(),"Releasing Space returns Ben to the floor after takeover")
 input_("jump",true);await frames(20);input_("heavy_attack",true);await frames(10)
 input_("jump",false);input_("heavy_attack",false);await frames(2)
 check(c.bomb_phase=="land","The input interruption test reaches automatic bomb descent")
 input_("heavy_attack",true)
 check(c.mode=="bombs" and c.bomb_phase!="land","RMB during descent immediately starts a fresh barrage instead of waiting for retraction")
 await frames(55)
 check(c.barrage_fired>0,"The restarted barrage releases bombs on its own schedule")
 input_("heavy_attack",false);await frames(2);input_("equip",true)
 check(c.mode=="fan" and c.bomb_phase.is_empty(),"E interrupts bomb descent with the distinct three-star throw")
 input_("equip",false);await frames(25)
 check(get_nodes_in_group("leader_projectiles").any(func(shot):return shot.shuriken and not shot.is_queued_for_deletion()),"The descent interruption releases actual E projectiles")
 await frames(150)
 check(not c.is_attacking() and p.is_on_floor(),"E interruption leaves neither automatic hover nor a stuck descent phase")
 input_("heavy_attack",true);await frames(35);c._notification(NOTIFICATION_APPLICATION_FOCUS_OUT);input_("heavy_attack",false);await frames(90)
 check(not c.is_attacking() and c.bomb_phase.is_empty() and p.is_on_floor(),"Focus loss cancels automatic flight and permits natural landing")
 stop_audio(game);game.move_audio.stop();current_scene=null;game.queue_free();await frames(4);game=null
 await create_timer(.35).timeout
 print("RECOVERED_BEN_FLIGHT_RESULT checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
