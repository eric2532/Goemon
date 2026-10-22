extends SceneTree
## Real Hero input/collision path: no inherited Goemon gravity or extra jumps.
var checks=0
var failures=0
var fixture
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func step(p,n:int):
	for i in n:await physics_frame;p._physics_process(1.0/60.0)
func jump(p):
	var e=InputEventAction.new();e.action="jump";e.pressed=true;p._unhandled_input(e)
func run():
	fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture)
	var game=await fixture.make_game("original");Engine.physics_ticks_per_second=60;Engine.time_scale=1
	fixture.clear_targets();var p=fixture.reset_player(13);p.set_physics_process(false);p.position=Vector3(0,.05,60)
	for i in 3:p.velocity=Vector3.DOWN*20;p.move_and_slide()
	p.velocity=Vector3.ZERO;game.tuning.invincible=true
	var c=p.active_ability
	check(c.get("locomotion")!=null,"Musashi has his own movement controller on the actual playable Hero")
	if c.get("locomotion")==null:await finish();return
	c.locomotion.reset();Input.action_press("jump");jump(p);await step(p,4)
	check(p.jumps_used==1 and absf(p.velocity.y-26.5275)<.0001,"Space routes through the original -18 launch and first held-gravity step")
	await step(p,4)
	Input.action_release("jump");await step(p,2);Input.action_press("jump");jump(p);await step(p,2)
	check(p.jumps_used==2 and absf(p.velocity.y-20.0475)<.0001,"A second Space edge resets the original L-Belt double jump")
	check(p.model.current_clip=="Extra__800d4be0","Double jump displays the recovered spin through the real movement path")
	var vy=p.velocity.y;await step(p,4)
	check(p.velocity.y<vy and p.jumps_used==2,"Holding Space cannot retrigger another midair launch")
	jump(p);await step(p,2)
	check(p.jumps_used==2 and p.velocity.y<vy,"A third Space press cannot add another jump")
	Input.action_release("jump");await step(p,70)
	check(p.is_on_floor() and p.jumps_used==0,"Real floor contact resets the double-jump budget")
	# A real fourth-click finisher must rise and land under source motion,
	# rather than waiting indefinitely for a manually advanced phase clock.
	c.cancel();c.combo=2;c.combo_timer=1;c.primary_attack();var start_y=p.position.y;var peak=start_y
	for i in 90:await step(p,1);peak=maxf(peak,p.position.y)
	check(absf((peak-start_y)-1.89)<.02,"Fourth Fusion apex matches 35 source units without an extra launch step")
	check(p.is_on_floor() and not c.controls_motion() and not c.is_attacking(),"The finisher finishes physical landing and returns control")
	p.select_character(1);p.dodge_time=.28;p.select_character(13);await step(p,20)
	check(p.dodge_time<=0,"A previous fighter's dodge cannot permanently lock Musashi's attacks")
	c.primary_attack();check(c.is_attacking(),"Fusion remains usable after switching out of another fighter's dodge")
	c.cancel();c.locomotion.source_tick(Vector3.ZERO,true,true,true,false,false)
	c.locomotion.source_tick(Vector3.ZERO,false,false,true,false,false)
	p.model.locomotion.reset()
	check(c.locomotion.source_vertical==0 and c.locomotion.animation_state()=="idle","Existing run/revive movement reset also clears Musashi's source trajectory")
	p.jump_buffer=.15;c.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT);await step(p,4)
	check(p.jumps_used==0 and p.is_on_floor(),"Focus loss cannot replay a Space press queued before the next source update")
	await finish()
func finish():
	Input.action_release("jump");await fixture.close();fixture.queue_free();await process_frame
	print("MUSASHI_PLAYER_MOTION_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
