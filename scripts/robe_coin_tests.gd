extends "res://scripts/scarf_tests.gd"

var launches: Array=[]

func observe_projectile(node: Node):
	if node is GoldCoin and not node is MusashiFireball and not node.hostile:
		launches.append({"direction":node.velocity.normalized(),"speed":node.velocity.length(),"damage":node.damage,"radius":node.hit_radius,"lifetime":node.lifetime,"piercing":node.piercing,"energy":node.combo_energy})

func fresh_robe(equipped: bool=true):
	await fresh()
	game.player.invuln=0
	game.player.set_scarf_equipped(equipped)
	launches.clear()

func capture_coins(label: String):
	if not visual:return
	game.hud.toast_time=0;game.hud.banner_time=0
	game.camera_rig.set_process(false)
	game.camera_rig.camera.global_position=game.player.position+Vector3(9,13,15)
	game.camera_rig.camera.look_at(game.player.position+Vector3.UP)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/robe-coins/"+label+".png")

func run():
	visual="--robe-coins-visual" in OS.get_cmdline_user_args()
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.child_entered_tree.connect(observe_projectile)
	var p=game.player
	await fresh_robe(false);var enemy=target(Vector3(0,0,-2.4))
	await mouse(true);await mouse(false);await attack_frames()
	check(launches.is_empty() and is_equal_approx(enemy.hp,9867.6),"Without the robe the three melee hits and two red follow-ups emit no bonus coins")
	await fresh_robe(false);await key(KEY_R);await mouse(true);await mouse(false);await attack_frames()
	check(launches.is_empty(),"Unrobed R spin has no coin ring")
	for boosted in [false,true]:
		await fresh_robe()
		if boosted:
			for i in range(4):p.collect_powerup("attack_speed")
			p.collect_powerup("damage");p.collect_powerup("range")
		enemy=target(Vector3(0,0,-12));enemy.set_physics_process(false)
		await mouse(true);await mouse(false);await attack_frames();await wait(.5)
		check(launches.size()==3,"Combo emits exactly one bonus coin per hit at speed boost=%s" % boosted)
		check(is_equal_approx(enemy.hp,9908.5 if boosted else 9939),"All three robe coins inherit cast damage; the final coin gets the first confirmed-link bonus at speed boost=%s (HP %s)" % [boosted,enemy.hp])
		if launches.size()>0:
			var c=launches[0]
			check(is_equal_approx(c.damage,30 if boosted else 20) and is_equal_approx(c.speed,96 if boosted else 32) and is_equal_approx(c.radius,.45 if boosted else .3) and is_equal_approx(c.speed*c.lifetime,64),"Bonus coins inherit damage, speed, range and constant travel distance")
	await fresh_robe();await mouse(true,true);await mouse(false,true);await attack_frames()
	check(launches.size()==1,"Heavy pipe strike emits one coin across its entire contact window")
	for right in [false,true]:
		await fresh_robe();p.select_weapon(3)
		await mouse(true,right);await mouse(false,right);await attack_frames()
		check(launches.size()==1,"Chain %s emits exactly one bonus coin" % ("fan" if right else "throw"))
	for right in [false,true]:
		await fresh_robe();p.select_weapon(2)
		await mouse(true,right);await mouse(false,right);await attack_frames()
		check(launches.size()==(6 if right else 2),"Coin weapon retains original projectiles and adds one bonus (RMB=%s)" % right)
	await fresh_robe();p.select_weapon(2);await key(KEY_R);await mouse(true);await mouse(false);await attack_frames()
	var piercing_count=0
	for shot_data in launches:
		if shot_data.piercing:piercing_count+=1
	check(launches.size()==2 and piercing_count==1,"R giant toss retains its piercing projectile plus a regular bonus coin")
	for boosted in [false,true]:
		await fresh_robe()
		if boosted:
			for i in range(4):p.collect_powerup("attack_speed")
		var targets=[]
		for direction in [Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]:
			var e=target(direction*14);e.set_physics_process(false);targets.append(e)
		await key(KEY_R);await mouse(true);await mouse(false)
		if visual and not boosted:
			await wait(.44);await capture_coins("01-spin-coin-ring")
		await attack_frames();await wait(.35)
		check(launches.size()==16,"R spin emits exactly 16 coins, without repeating during contact (boost=%s)" % boosted)
		var sum=Vector3.ZERO;var angles={};var ordinary=true
		for c in launches:
			sum+=c.direction;angles[roundi(atan2(c.direction.x,c.direction.z)*1000)]=true
			ordinary=ordinary and not c.piercing and c.damage==20
		check(sum.length()<.001 and angles.size()==16 and ordinary,"Ring distributes regular damaging coins evenly through the full circle")
		var all_hit=true
		for e in targets:all_hit=all_hit and e.hp==9980
		check(all_hit,"Spin coins hit distant enemies in front, behind, left and right")
	await fresh_robe();enemy=target(Vector3(0,0,-10));enemy.set_physics_process(false)
	var wall=Geo.box(game,p.position+Vector3(0,1.5,-5),Vector3(8,4,.4),Geo.mat("888888"),true)
	await wait(.05);await mouse(true);await mouse(false);await attack_frames();await wait(.3)
	check(launches.size()==3 and enemy.hp==10000,"Bonus coins collide with solid cover and cannot damage enemies behind it")
	wall.queue_free()
	await fresh_robe();await mouse(true,true);await mouse(false,true);p.set_scarf_equipped(false);await attack_frames()
	check(launches.is_empty(),"Removing the robe before contact prevents bonus projectiles")
	await fresh_robe();await key(KEY_R);await mouse(true);await mouse(false);await key(KEY_E);await wait(.85)
	check(launches.is_empty(),"E interruption before contact cancels the pending coin ring")
	await fresh_robe();await key(KEY_R);await mouse(true);await mouse(false)
	game.show_pause();await wait(.4)
	check(launches.is_empty(),"Pause cannot advance a spin to its coin release")
	game.resume();await attack_frames()
	check(launches.is_empty(),"Pause cancels the windup without leaving a deferred coin burst")
	await wait(.1);await mouse(true);await mouse(false);await attack_frames()
	check(launches.size()==16,"A fresh attack after resume releases a single complete ring")
	await fresh_robe();await key(KEY_Q);await mouse(true);await mouse(false);await wait(.6)
	check(launches.is_empty() and p.character_id==2,"Edo never inherits robe coins (character=%s, coins=%s)" % [p.character_id,launches.size()])
	p.musashi.cancel();await wait(.1)
	print("ROBE_COINS_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
