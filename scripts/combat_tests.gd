extends Node
var game: Node
var failures=0
var original_tuning: Dictionary
func check(ok: bool,message: String):
	if ok: print("PASS: ",message)
	else:
		failures+=1
		push_error("COMBAT TEST: "+message)
func wait(seconds: float):
	await get_tree().create_timer(seconds).timeout
func mouse(down: bool,right: bool=false):
	var e=InputEventMouseButton.new()
	e.button_index=MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	e.pressed=down
	Input.parse_input_event(e)
	await get_tree().process_frame
func key(code: Key):
	var e=InputEventKey.new()
	e.physical_keycode=code
	e.pressed=true
	Input.parse_input_event(e)
	var up=e.duplicate()
	up.pressed=false
	Input.parse_input_event(up)
	await get_tree().process_frame
func dummy(offset: Vector3)->Ninja:
	var e=Ninja.new()
	e.game=game
	e.training_dummy=true
	e.practice=true
	e.encounter_id="test"+str(game.enemies.size())
	e.position=game.player.position+offset
	game.add_child(e)
	e.hp=1000
	e.max_hp=1000
	game.enemies.append(e)
	return e
func reset():
	game.player.cancel_charge()
	game.player.attack_left=0
	game.player.combo=0
	game.player.end_surge()
	game.clear_practice()
	for n in get_tree().get_nodes_in_group("projectiles"): n.queue_free()
	game.reset_player_at(Vector3(0,game.world.height_at(0,41)+0.05,41))
	game.player.facing=Vector3.FORWARD
	game.player.soft_target=false
	game.camera_rig.yaw=0
	game.player.select_weapon(1)
	await wait(0.2)
func run():
	original_tuning=game.tuning.duplicate()
	game.tuning=PrototypeTuning.DEFAULTS.duplicate()
	game.start_game()
	game.player.smoke_mode=true
	game.tuning.freeze_ai=true
	await wait(0.5)
	await reset()
	var e=dummy(Vector3(0,0,-2.5))
	await mouse(true)
	await wait(0.06)
	await mouse(false)
	await wait(1.55)
	check(e.hp==926 and game.player.combo==3 and game.player.attack_left==0,"One physical left-click produces exactly three strikes (22 + 22 + 30)")
	var rotations=[]
	for stage in [1,2,3]:
		game.player.model.animate(0,0,true,0,0.45,false,stage,false)
		rotations.append(game.player.model.arms[1].rotation.y)
	check(rotations[0]>0 and rotations[1]<0 and rotations[2]>0,"Combo poses alternate left / right / left")
	await reset()
	var front=dummy(Vector3(0,0,-3))
	var back=dummy(Vector3(0,0,3))
	await mouse(true)
	await wait(1.2)
	check(front.hp==1000 and back.hp==1000 and game.player.primary_down,"Holding LMB charges without premature strikes")
	await mouse(false)
	await wait(0.85)
	check(front.hp==930 and back.hp==930,"Charged 360-degree sweep hits enemies in front and behind once")
	await reset()
	game.player.select_weapon(2)
	await mouse(true,true)
	await mouse(false,true)
	await wait(0.34)
	var coins=get_tree().get_nodes_in_group("projectiles")
	check(coins.size()==5,"Right-click coin attack splits into five projectiles")
	if coins.size()==5: check(coins[0].velocity.x*coins[4].velocity.x<0,"Split coins fan to both sides")
	await reset()
	game.player.select_weapon(2)
	front=dummy(Vector3(1.5,0,-6))
	back=dummy(Vector3(-1.5,0,-13))
	await mouse(true)
	await wait(1.2)
	await mouse(false)
	await wait(1.0)
	check(front.hp==930 and back.hp==930,"Giant charged coin pierces successive enemies with area damage")
	await wait(0.5)
	check(front.hp==930 and back.hp==930,"Piercing coin never damages the same enemy twice")
	await reset()
	game.player.select_weapon(2)
	front=dummy(Vector3(0,0,-11))
	var wall=Geo.box(game,game.player.position+Vector3(0,2,-5),Vector3(10,6,0.5),Geo.mat("665544"),true)
	await wait(0.1)
	game.throw_coin(true,true,1)
	await wait(0.7)
	check(front.hp==1000,"Solid wall stops charged projectile damage")
	wall.queue_free()
	await reset()
	await key(KEY_R)
	check(game.player.surge_left>29 and game.player.model.hair_gold.visible and not game.player.model.hair_normal.visible,"R activates 30-second golden, spikier hair and energy")
	var remaining=game.player.surge_left
	await key(KEY_R)
	check(game.player.surge_left<=remaining,"Pressing R while active does not extend the timer")
	game.player.select_weapon(2)
	game.throw_coin(false)
	coins=get_tree().get_nodes_in_group("projectiles")
	check(coins.size()==1 and is_equal_approx(coins[0].visual_size,1.8) and is_equal_approx(coins[0].velocity.length(),52.8),"Surge coins are 1.8x larger and 1.65x faster")
	game.player.select_weapon(1)
	front=dummy(Vector3(0,0,-5.3))
	game.player.start_attack(false)
	await wait(0.18)
	check(front.hp<1000,"Golden surge extends actual melee hit range")
	game.player.attack_left=0
	game.player.surge_left=0.1
	await wait(0.2)
	check(game.player.surge_left==0 and game.player.model.hair_normal.visible and not game.player.aura.visible,"Surge expires and restores normal hair, range, and aura state")
	await reset()
	await key(KEY_SPACE)
	await wait(0.2)
	game.player.smoke_move=Vector2(1,0)
	await key(KEY_SPACE)
	await wait(0.15)
	check(absf(game.player.model.body.rotation.x)>1 and absf(game.player.model.body.rotation.y)<0.01 and game.player.velocity.x>7,"Double jump front-flips around X and permits steering")
	game.player.smoke_move=Vector2.ZERO
	await wait(1.3)
	check(game.player.model.body.position.length()<0.1,"Front flip restores the body pivot without accumulating drift")
	await reset()
	game.tuning.coin_count=3
	game.player.select_weapon(2)
	game.throw_coin(false)
	check(get_tree().get_nodes_in_group("projectiles").size()==3,"Prototype coin count controls actual projectiles")
	for n in get_tree().get_nodes_in_group("projectiles"): n.queue_free()
	await wait(0.05)
	game.tuning.damage_mult=2
	game.player.select_weapon(1)
	front=dummy(Vector3(0,0,-2))
	game.player.start_attack(false)
	await wait(1.5)
	check(front.hp==852,"Player damage multiplier affects all three real hits")
	game.player.cancel_charge()
	await mouse(true)
	await wait(0.3)
	game.player.activate_surge()
	game.show_lab()
	check(get_tree().paused and not game.player.primary_down,"Prototype Lab pauses simulation and cancels pending charge")
	var hp=game.player.hp
	game.tuning.invincible=true
	game.player.invuln=0
	game.player.take_hit(100,Vector3.FORWARD)
	check(game.player.hp==hp,"Prototype invincibility prevents real damage")
	game.tuning.spawn_count=4
	var spawned=game.spawn_practice(true)
	check(spawned==4,"Prototype Lab places four practice enemies in free terrain")
	game.update_tuning("max_hp",350)
	game.player.hp=350
	game.save_settings()
	var saved=ConfigFile.new()
	saved.load("user://settings.cfg")
	check(game.player.max_hp==350 and saved.get_value("prototype","max_hp")==350,"Maximum HP tuning applies and persists")
	var timer=game.player.surge_left
	await wait(0.2)
	check(game.player.surge_left==timer,"Paused lab does not advance transformation timer")
	game.resume()
	await mouse(false)
	check(game.player.attack_left<=0,"Releasing mouse after leaving Lab does not fire a phantom attack")
	game.tuning=original_tuning
	game.save_settings()
	print("COMBAT_TEST_RESULT failures=",failures)
	game.playing=false
	game.music.stop()
	for voice in game.voices: voice.stop()
	await wait(0.3)
	get_tree().quit(0 if failures==0 else 1)
