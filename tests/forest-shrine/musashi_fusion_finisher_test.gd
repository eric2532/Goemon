extends SceneTree
## Reject the old three-cut loop and generic jump substituted for the retail
## fourth attack. Literal phase/velocity expectations come from 55B20–55D70.
var checks=0
var failures=0
var fixture
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func run():
	fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture)
	var game=await fixture.make_game("original")
	fixture.clear_targets();var p=fixture.reset_player(13);p.set_physics_process(false)
	p.position=Vector3(0,.05,60)
	for i in 3:p.velocity=Vector3.DOWN*20;p.move_and_slide()
	p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;game.character_tuning={};game.tuning.critical_chance=0
	var c=p.active_ability
	for clip in ["Extra__800d4c94","Source__800d4ce4","Source__800d4d38"]:
		c.primary_attack();check(c.clip==clip,"The first three Fusion cuts retain their own entries")
		c.tick(p.attack_duration+.001)
	var target=fixture.add_target(p.position+Vector3.FORWARD*1.3);target.hp=10000;target.max_hp=10000
	c.primary_attack()
	check(c.clip=="Recovered__800d4d88" and p.combo==4,"The fourth click begins the original finisher instead of looping cut one")
	check(c.has_method("source_motion_tick"),"The finisher has its own source motion phases")
	if not c.has_method("source_motion_tick"):await finish();return
	for i in 5:
		check(c.source_motion_tick().is_zero_approx(),"Finisher windup remains planted")
	check(c.clip=="Recovered__800d4d88","Six-tick windup has not been shortened")
	var motion:Vector3=c.source_motion_tick()
	check(c.clip=="Recovered__800d4da8" and motion.is_zero_approx(),"Windup initializes the -16 impulse without integrating an extra launch step")
	for i in 5:c.source_motion_tick()
	check(c.clip=="Recovered__800d4da8","One-pose rise entry waits for vertical velocity, not its one-frame clip length")
	motion=c.source_motion_tick()
	check(c.clip=="Recovered__800d4db4" and is_equal_approx(motion.y,-3.24),"The sixth gravity step crosses the apex and selects the transition")
	for i in 5:
		check(c.source_motion_tick().is_zero_approx(),"The six-pose apex transition holds source height")
	c.source_motion_tick()
	check(c.clip=="Recovered__800d4dd4","The transition enters the source falling-contact pause")
	check(target.hp==10000,"Finisher windup, launch and apex cannot damage a nearby real victim")
	motion=c.source_motion_tick()
	check(is_equal_approx(motion.y,-8.1) and c.trail_active(),"The falling strike resumes +3 source gravity with contact active")
	check(target.hp<10000,"The source falling-contact state damages a real enemy")
	var hit_hp=target.hp
	for i in 8:c.source_motion_tick()
	check(target.hp==hit_hp,"A held falling contact cannot damage the same victim twice")
	check(is_equal_approx(c.source_motion_tick().y,-51.84),"Source soft terminal gravity crosses from 29 to 32 units instead of clamping to 31")
	check(is_equal_approx(c.source_motion_tick().y,-51.84),"Source terminal guard retains the crossed value on later ticks")
	check(c.clip=="Recovered__800d4dd4" and c.controls_motion(),"A paused falling entry waits for physical landing")
	c.after_source_motion(true,false)
	check(c.clip=="Recovered__800d4df4" and not c.trail_active(),"Actual floor contact begins the original landing recovery and closes contact")
	for i in 5:c.source_motion_tick()
	check(not c.is_attacking() and not c.controls_motion(),"Five landing poses finish the action and release movement")
	c.cancel();c.combo=2;c.combo_timer=1;c.primary_attack();c.source_motion_tick();c.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not c.controls_motion() and not c.is_attacking(),"Losing focus cancels every pending finisher phase")
	c.combo=2;c.combo_timer=1;c.primary_attack();p.select_character(1)
	check(not c.controls_motion(),"Switching fighters cannot leave finisher gravity active")
	check(game.sound_preview(13,"move_primary_4_voice")!=null,"The fourth action has its confirmed original exertion voice")
	await finish()
func finish():
	await fixture.close();fixture.queue_free();await process_frame
	print("MUSASHI_FUSION_FINISHER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
