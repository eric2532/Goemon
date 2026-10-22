extends "res://scripts/power_combat_tests.gd"

var fixture: Node3D
var base=Vector3(0,80,41)

func frames(count: int):
	for i in range(count):await get_tree().physics_frame

func fresh_wall(id: int=1,cloak: bool=false):
	await prepare(id)
	game.player.set_scarf_equipped(cloak)
	game.player.smoke_move=Vector2.ZERO
	game.reset_player_at(base+Vector3.UP*.05)
	await frames(8)

func reach_wall():
	var p=game.player
	await key(KEY_SPACE)
	await frames(4)
	p.smoke_move=Vector2.RIGHT
	for i in range(60):
		await frames(1)
		if p.wall_jump_grace>0:return
	check(false,"Airborne movement reaches the physical wall")

func run():
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false)
	get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	fixture=Node3D.new();game.add_child(fixture)
	Geo.box(fixture,base-Vector3.UP*.5,Vector3(24,1,24),Geo.mat("888888"),true)
	Geo.box(fixture,base+Vector3(4,12,0),Vector3(.4,24,24),Geo.mat("888888"),true)
	var p=game.player
	var saved_custom=game.sound_library.custom.duplicate()
	var landing=AudioStreamWAV.new();landing.format=AudioStreamWAV.FORMAT_16_BITS;landing.mix_rate=22050
	var samples=PackedByteArray();samples.resize(44100);landing.data=samples
	game.sound_library.custom.land=landing
	for id in [1,2]:
		await fresh_wall(id)
		await reach_wall()
		check(p.is_on_wall() and not p.is_on_floor(),"Character %d makes a real airborne wall contact" % id)
		p.jumps_used=p.maximum_jumps()
		p.velocity.z=-4
		var origin=p.position
		await key(KEY_SPACE);await frames(2)
		check(p.velocity.x< -7 and p.velocity.y>12,"Character %d hops up and away even after spending air jumps" % id)
		check(p.velocity.z< -3,"Wall hop preserves momentum along the wall")
		check(p.jumps_used==p.maximum_jumps() and p.air_turn==0,"Wall hop does not refill air jumps or continue an old flip")
		check(game.last_sound_voice.stream==landing and game.last_sound_voice.get_meta("kind")=="land" and game.last_sound_voice.pitch_scale==1.0,"Wall hop plays the exact custom landing recording")
		await frames(6)
		check(p.position.x<origin.x-.75 and p.velocity.x< -5,"Holding toward the wall still produces a smooth, sustained push-off")
		var upward=p.velocity.y
		await key(KEY_SPACE);await frames(2)
		check(p.velocity.y<upward,"An immediate extra tap cannot reuse the same wall contact")
		game.show_pause();var recovery=p.wall_jump_recovery;var paused_position=p.position
		await wait(.08)
		check(p.wall_jump_recovery==recovery and p.position==paused_position,"Pause freezes wall-hop movement and steering recovery")
		game.resume()
		for i in range(70):
			await frames(1)
			if p.wall_jump_grace>0:break
		check(p.wall_jump_grace>0,"A fresh wall contact permits another hop")
		await key(KEY_SPACE);await frames(2)
		check(p.velocity.x< -7 and p.velocity.y>12,"Repeated hops require a new contact and press")
		game.reset_player_at(base+Vector3.UP*.05)
		check(p.wall_jump_grace==0 and p.wall_jump_recovery==0,"Respawn clears wall contact and steering recovery")

	await fresh_wall(1,true);await reach_wall();await key(KEY_SPACE);await frames(8)
	check(p.velocity.x< -5,"Cloak's 3x acceleration cannot swallow the wall push-off")
	await fresh_wall();await reach_wall()
	# Move away under normal physics, then press during contact grace.
	p.smoke_move=Vector2.LEFT;p.velocity.x=-5
	await frames(3)
	check(not p.is_on_wall() and p.wall_jump_grace>0,"Brief contact grace remains after leaving a wall")
	p.jumps_used=p.maximum_jumps()
	await key(KEY_SPACE);await frames(2)
	check(p.wall_jump_recovery>0 and p.velocity.y>12,"A slightly late press still wall hops")

	await fresh_wall();await reach_wall()
	p.smoke_move=Vector2.LEFT;p.velocity.x=-5;p.jumps_used=p.maximum_jumps()
	await frames(12)
	var before=p.velocity.y
	await key(KEY_SPACE);await frames(2)
	check(p.wall_jump_grace==0 and p.wall_jump_recovery==0 and p.velocity.y<before,"Expired contact cannot create a hop in open air")

	await fresh_wall();await reach_wall();p.jumps_used=p.maximum_jumps()
	var down=InputEventKey.new();down.physical_keycode=KEY_SPACE;down.pressed=true;Input.parse_input_event(down)
	await frames(45)
	check(p.wall_jump_recovery==0 and p.velocity.y<0,"Holding jump never auto-hops on recontact")
	var up=down.duplicate();up.pressed=false;Input.parse_input_event(up)

	await fresh_wall()
	p.smoke_move=Vector2.RIGHT;await frames(36)
	check(p.is_on_floor() and p.is_on_wall() and p.wall_jump_grace==0,"Grounded wall contact does not grant a wall hop")
	await key(KEY_SPACE);await frames(4)
	check(p.jumps_used==1 and p.velocity.y>12 and p.wall_jump_recovery==0,"Jump beside a wall on the floor remains a normal ground jump")

	await fresh_wall();await key(KEY_SPACE);await frames(5);await key(KEY_SPACE);await frames(2)
	check(p.jumps_used==2 and p.air_turn>0 and p.velocity.y>12,"Ordinary double jump in open air keeps its lift and animation")
	before=p.velocity.y;await key(KEY_SPACE);await frames(2)
	check(p.jumps_used==2 and p.velocity.y<before,"Open-air jump limit is unchanged")

	await fresh_wall()
	var ceiling=Geo.box(fixture,base+Vector3(0,3.5,0),Vector3(4,.4,4),Geo.mat("888888"),true)
	await frames(2);await key(KEY_SPACE)
	var hit_ceiling=false
	for i in range(20):
		await frames(1)
		if p.is_on_ceiling():hit_ceiling=true;break
	check(hit_ceiling and p.wall_jump_grace==0,"A ceiling collision never counts as a wall")
	ceiling.queue_free()
	await fresh_wall();await reach_wall();await key(KEY_SPACE);await frames(2);await key(KEY_E)
	check(p.forward_dash.active and p.wall_jump_recovery==0 and p.wall_jump_grace==0,"Forward dash clears wall-hop state and retains movement priority")
	game.sound_library.custom=saved_custom
	fixture.queue_free()
	print("WALL_JUMP_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
