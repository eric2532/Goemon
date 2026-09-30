extends "res://scripts/combat_tests.gd"
var max_scale=1.0
var max_extent=0.0
var warm_scale=1.0
func run():
	original_tuning=game.tuning.duplicate();game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.start_game();game.player.smoke_mode=true;game.tuning.freeze_ai=true
	game.set_process_unhandled_input(false);game.player.set_process_unhandled_input(false)
	await wait(0.5);await reset();game.player.invuln=0
	var m=game.player.model
	# Evaluate thousands of real controller/animation ticks quickly, with rapid clicks.
	game.player.set_physics_process(false)
	for tick in range(7200):
		if tick%6==0:
			var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;game.player._unhandled_input(down)
		if tick%6==2:
			var up=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;game.player._unhandled_input(up)
		game.player._physics_process(1.0/60)
		m.sync_skeleton()
		for i in range(m.skeleton.get_bone_count()):
			var pose=m.skeleton.get_bone_global_pose(i)
			max_scale=maxf(max_scale,maxf(pose.basis.x.length(),maxf(pose.basis.y.length(),pose.basis.z.length())))
			max_extent=maxf(max_extent,pose.origin.length())
		if tick==600:warm_scale=max_scale
		if tick%600==0:print("SOAK ",tick," scale=",max_scale," extent=",max_extent)
		if max_scale>2 or max_extent>10:break
	check(max_scale-warm_scale<0.0001,"Scale remains stable after warm-up across 120 seconds of attack spam")
	for tick in range(180):
		game.player._physics_process(1.0/60);m.sync_skeleton()
	check(m.scale.is_equal_approx(Vector3.ONE) and m.body.scale.is_equal_approx(Vector3.ONE),"Character and visual root retain original scale")
	check(max_scale<1.015,"Repeated clicking never accumulates bone scale")
	check(max_extent<4,"Repeated clicking preserves bounded skeletal proportions")
	print("ATTACK_SOAK_RESULT failures=",failures," scale=",max_scale," extent=",max_extent)
	game.tuning=original_tuning;get_tree().quit(1 if failures else 0)
