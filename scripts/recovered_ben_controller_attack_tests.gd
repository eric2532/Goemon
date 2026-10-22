extends "res://scripts/recovered_leaders_tests.gd"
## Real Ben controller: planted source windup, collision-aware lunge, recovery.
func press(action: String,down: bool):
 var e=InputEventAction.new();e.action=action;e.pressed=down;game.player._unhandled_input(e)
func run():
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="user://ben-original-controller-%s.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;await frames(5)
 game.begin_forest();game.choose_rogue_character(15);game.start_wave();game.tuning.invincible=true;game.tuning.freeze_ai=true;game.character_tuning={}
 var p=game.player;p.smoke_mode=true;p.position=Vector3(0,.05,22);p.velocity=Vector3.ZERO
 game.camera_rig.yaw=-PI/2;game.camera_rig.reset_follow();await frames(15)
 var start=p.position;press("light_attack",true);press("light_attack",false)
 check("source_16" in p.active_ability.clip,"Polearm input uses Ben's original complete source16 action")
 await frames(40)
 check(Vector2(p.position.x-start.x,p.position.z-start.z).length()<.15,"Ben plants his feet through the original polearm windup")
 await frames(23)
 check(Vector2(p.position.x-start.x,p.position.z-start.z).length()>1 and Vector2(p.position.x-start.x,p.position.z-start.z).length()<=3.2,"The short polearm lunge moves Ben at most three metres through the real controller")
 await frames(30)
 check(not p.active_ability.is_attacking(),"The complete polearm recovery ends without starting an invented combo")
 var after=p.position;await frames(15)
 check(Vector2(p.position.x-after.x,p.position.z-after.z).length()<.1,"Ending the polearm lunge does not leave residual sliding")
 # Start beside a real wall in the attack direction: the same lunge must stop.
 var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.3,5,8);shape.shape=box;body.add_child(shape);body.position=p.position+Vector3.RIGHT*1.6+Vector3.UP*2;game.add_child(body)
 await frames(3);var wall_x=body.position.x;press("light_attack",true);press("light_attack",false);await frames(100)
 check(p.position.x<wall_x-.35,"The authored polearm lunge respects solid world collision")
 p.active_ability.cancel();body.queue_free();await frames(3)
 # Focus cancellation must strip the owned charge impulse immediately.
 p.position=Vector3(0,.05,35);p.velocity=Vector3.ZERO;p.ai_controlled=false;p.ai_aim=p.position+Vector3.RIGHT*8
 press("light_attack",true);press("light_attack",false);p.ai_controlled=true;await frames(53)
 check(Vector2(p.velocity.x,p.velocity.z).length()>1,"Cancellation test reaches the real source polearm lunge")
 p.active_ability._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(Vector2(p.velocity.x,p.velocity.z).is_zero_approx(),"Cancelling the polearm lunge removes its owned horizontal impulse")
 p.ai_controlled=false
 var fan_start=p.position;p.smoke_move=Vector2(1,0);press("equip",true);press("equip",false);await frames(20)
 check(Vector2(p.position.x-fan_start.x,p.position.z-fan_start.z).length()<.1,"The original projectile throw plants Ben's feet despite held movement")
 p.smoke_move=Vector2.ZERO;p.active_ability.cancel();stop_audio(game);game.move_audio.stop();current_scene=null;game.queue_free();await frames(4);game=null;await create_timer(.35).timeout
 print("BEN_CONTROLLER_ATTACK_RESULT checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
