extends SceneTree
## Exercise the shipped Forest controllers on an isolated, flat platform.
var game
var checks=0
var failures=0
var measurements=[]
var floor_: StaticBody3D
const DT=1.0/60.0

func _initialize():call_deferred("run")
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;print("FAIL: ",message)

func step(input_: Vector2):
	game.player.smoke_move=input_
	game.player._physics_process(DT)

func speed()->Vector2:return Vector2(game.player.velocity.x,game.player.velocity.z)

func reset_body():
	game.player.position=Vector3(0,100.02,0)
	game.player.velocity=Vector3.ZERO
	game.player.facing=Vector3.FORWARD
	game.player.model.rotation=Vector3.ZERO
	game.player.attack_left=0;game.player.dodge_time=0
	game.player.reset_wall_jump()
	if game.player.is_rogue_character():game.player.active_ability.reset_run()
	for i in range(10):step(Vector2.ZERO)
	check(game.player.is_on_floor(),"Controller settles onto the test platform")

func measure(id: int):
	game.player.select_character(id);reset_body()
	var top: float=game.hero_tuning("walk_speed")
	var start_frames=0
	while speed().length()<top*.95 and start_frames<60:
		step(Vector2(0,-1));start_frames+=1
	for i in range(20):step(Vector2(0,-1))
	check(absf(speed().length()-top)<.01,"%d retains its configured movement speed"%id)
	var stop_origin: Vector3=game.player.position
	var stop_frames=0
	while speed().length()>.01 and stop_frames<60:
		step(Vector2.ZERO);stop_frames+=1
	var stop_distance=stop_origin.distance_to(game.player.position)
	for i in range(30):step(Vector2(0,-1))
	var reverse_frames=0
	while speed().y<top*.95 and reverse_frames<60:
		step(Vector2(0,1));reverse_frames+=1
	var yaw_error=absf(angle_difference(game.player.model.rotation.y,PI))
	check(start_frames*DT<=.15,"%d reaches running speed within 150 ms"%id)
	check(stop_frames*DT<=.12,"%d stops within 120 ms"%id)
	check(reverse_frames*DT<=.20,"%d reverses within 200 ms"%id)
	check(yaw_error<.12,"%d body follows the reversal without trailing behind"%id)
	measurements.append({"character":id,"speed":top,"start_ms":start_frames*DT*1000,"stop_ms":stop_frames*DT*1000,"reverse_ms":reverse_frames*DT*1000,"stop_distance":stop_distance,"yaw_error":yaw_error})
	print("MOVEMENT_RESPONSE ",JSON.stringify(measurements.back()))

func check_controls():
	for id in [1,2,3,5,7,12]:
		game.player.select_character(id)
		var key=preload("res://scripts/character_balance.gd").key_for(id)
		game.character_tuning[key]={"walk_speed":24.0,"sprint_speed":40.0}
		reset_body()
		for i in range(9):step(Vector2(1,-1).normalized())
		check(absf(speed().length()-24)<.01,"%d keeps custom speed and normalized diagonal travel"%id)
		Input.action_press("sprint")
		for i in range(9):step(Vector2(0,-1))
		check(absf(speed().length()-40)<.01,"%d keeps custom sprint speed"%id)
		Input.action_release("sprint")
		for i in range(12):step(Vector2.ZERO)
		check(speed().length()<.01,"%d brakes from custom sprint without a long slide"%id)
		reset_body();Input.action_press("walk_modifier")
		for i in range(12):step(Vector2(0,-1))
		var walking_speed=2.2 if id<=2 else 12.0
		check(absf(speed().length()-walking_speed)<.01,"%d preserves its slow-walk modifier"%id)
		Input.action_release("walk_modifier")
		reset_body();game.player.position.y=110;game.player.velocity=Vector3.ZERO
		game.player.move_and_slide()
		check(not game.player.is_on_floor(),"%d leaves the platform for the air-control check"%id)
		step(Vector2(0,-1))
		check(absf(speed().length()-(24.0 if id<=2 else 52.0)*DT)<.01,"%d retains existing air steering"%id)
		game.character_tuning.erase(key)
	game.player.select_character(1);reset_body()
	game.player.dodge_time=.2
	step(Vector2(1,0))
	check(absf(speed().length()-23)<.01 and speed().y<0,"Goemon dodge keeps its committed forward travel")
	reset_body();game.player.velocity=Vector3.FORWARD*8
	step(Vector2.ZERO)
	var ordinary_braking=speed().length()
	reset_body();game.player.start_attack(false,1)
	game.player.velocity=Vector3.FORWARD*8
	step(Vector2.ZERO)
	check(absf(speed().length()-ordinary_braking)<.01,"Goemon windup retains ordinary grounded control before contact")
	reset_body();game.player.progression.level=99
	game.player.powerups.attack_speed=20;game.player.attack_speed_stacks=4
	game.player.attack_chain.count=20;game.player.attack_chain.remaining=1.75
	game.player.start_attack(false,3)
	var lunge_start: Vector3=game.player.position
	for i in range(30):
		step(Vector2.ZERO)
	check(game.player.position.distance_to(lunge_start)<.02 and speed().length()<.01,"Boosted energized finisher plants at contact instead of coasting through the strike")
	check(not game.player.attack_motion_pending,"Finisher releases ordinary movement response when its momentum settles")
	game.player.progression.reset();game.player.powerups.attack_speed=0
	game.player.attack_speed_stacks=0;game.player.attack_chain.reset()
	for id in [1,2]:
		game.player.select_character(id);reset_body()
		game.player.invuln=0;game.tuning.invincible=false
		game.player.take_hit(1,Vector3.RIGHT);game.tuning.invincible=true
		step(Vector2.ZERO)
		check(absf(speed().x-6.2)<.01 and game.player.velocity.y>0,"%d preserves grounded hit knockback through takeoff"%id)
	game.player.select_character(12);reset_body()
	game.player.active_ability.player.blocking=true
	step(Vector2(0,-1))
	check(speed().length()<.01,"Master Thief remains planted while guarding")

func setup_game():
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path="user://movement-response-test-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game
	game.begin_forest();game.choose_rogue_character(1);game.start_wave()
	game.tuning.invincible=true;game.character_tuning={}
	game.player.smoke_mode=true;game.player.soft_target=false
	game.camera_rig.yaw=0;game.camera_rig.set_process(false)
	game.set_process(false);game.set_physics_process(false);paused=true
	floor_=StaticBody3D.new();root.add_child(floor_)
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new()
	shape.shape.size=Vector3(100,1,100);shape.position.y=99.5;floor_.add_child(shape)
	await physics_frame

func run():
	await setup_game()
	for id in range(1,13):measure(id)
	check_controls()
	if "--report" in OS.get_cmdline_user_args():
		FileAccess.open("res://build/smooth-movement/verification/response.json",FileAccess.WRITE).store_string(JSON.stringify(measurements,"\t"))
	game.queue_free();floor_.queue_free();current_scene=null;paused=false
	await create_timer(.4).timeout
	print("MOVEMENT_RESPONSE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
