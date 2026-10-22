extends "res://scripts/combat_tests.gd"
var visual=false
func frames(n: int):
	for i in range(n):await get_tree().physics_frame
func capture(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/sky-descent/"+label+".png")
func go(room,local: Vector3,limit=240)->bool:
	var target=room.root.to_global(local)
	for i in range(limit):
		var diff=target-game.player.position;diff.y=0
		if diff.length()<.16:game.player.smoke_move=Vector2.ZERO;await frames(6);return true
		var direction=diff.normalized().rotated(Vector3.UP,-game.camera_rig.yaw)*minf(1,diff.length())
		game.player.smoke_move=Vector2(direction.x,direction.z)
		await frames(1)
	game.player.smoke_move=Vector2.ZERO
	print("MISSED ",room.data.id," target=",target," actual=",game.player.position)
	return false
func run():
	visual="--district-visual" in OS.get_cmdline_user_args()
	check(not game.tuning.freeze_ai,"A normal launch ignores stale saved AI freeze")
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.start_game()
	var p=game.player;var world=game.world;var run=game.encounters
	p.smoke_mode=true;Input.use_accumulated_input=false
	game.camera_rig.set_process_unhandled_input(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await frames(20)
	var old_area=186.0*163.0*10
	check(is_equal_approx(world.playable_bounds.get_area(),old_area*4),"Playable ground has exactly four times the previous area")
	check(world.furnished_town.rooms.size()==96 and world.furnished_districts.size()==16,"96 furnished buildings fill 16 new ground districts")
	var fits=true
	for lot in world.furnished_lots:fits=fits and world.playable_bounds.encloses(lot.rect.grow(6))
	check(fits,"All furnished buildings and their entrance pads fit inside the ground map")
	var first=game.enemies[0];var remote=game.enemies[-1]
	var distance=first.position.distance_to(p.position);var remote_start=remote.position
	await frames(220)
	check(first.position.distance_to(p.position)<distance,"Island enemy pursues the player with AI enabled")
	var attacks=0
	for enemy in game.enemies:attacks+=enemy.attack_count
	check(attacks>0 and p.hp<100,"Real enemy windups and strikes damage the player")
	check(remote.position.distance_to(remote_start)>.5,"Other islands visibly patrol instead of standing frozen")
	game.tuning.freeze_ai=true;game.tuning.invincible=true;p.hp=p.max_hp
	var initial=run.remaining_on(0)
	run.tick(8.01);await frames(2)
	check(run.remaining_on(0)==initial+2,"Uncleared island receives two reinforcements after eight seconds")
	var level=p.progression.level
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.island_index==0 and not enemy.dead:enemy.take_hit(100000,Vector3.UP,true)
	await frames(2)
	check(run.cleared.has(0) and run.remaining_on(0)==0 and p.progression.level>level,"Defeating the full island roster clears its spawner and grants levels")
	for i in range(12):run.tick(8.01)
	await frames(2)
	check(run.remaining_on(0)==0 and run.remaining_on(1)==12,"Cleared island stays empty while uncleared islands fill to their population cap")
	check(game.active_enemy_count()<=game.active_enemy_limit and game.active_enemy_count()<=120,"Reinforcements obey per-island and global live enemy limits")
	var scheduled=run.next_reinforcement;var elapsed=run.elapsed
	game.show_pause();run.tick(20);await frames(2)
	check(run.next_reinforcement==scheduled and run.elapsed==elapsed,"Pause does not advance reinforcement timers")
	game.resume()
	# Freeze the encounter director while checking the actual furnished rooms.
	run.enabled=false
	var town=world.furnished_town
	for room in town.rooms.slice(0,6):
		game.reset_player_at(room.root.to_global(Vector3(0,.15,room.data.body_depth/2+3)))
		game.camera_rig.yaw=room.root.rotation.y;await frames(20)
		var entered=await go(room,Vector3(0,.36,0))
		check(entered and p.is_on_floor(),"Walk through furnished "+room.data.id+" entrance with actual player collision")
		await frames(10)
		check(town.indoor and not room.meshes.Roof.visible,"Interior cutaway reveals "+room.data.id+" furnishings")
		var facing=true
		for yaw in [0,PI/2,PI,-PI/2]:
			game.camera_rig.yaw=room.root.rotation.y+yaw;await frames(12)
			facing=facing and not game.camera_rig.camera.is_position_behind(p.position+Vector3.UP)
		check(facing,"Indoor camera keeps player visible in "+room.data.id)
		if visual:await capture("district-interior-"+room.data.id)
		game.camera_rig.yaw=room.root.rotation.y
		if room.data.id=="inn":
			game.reset_player_at(room.root.to_global(Vector3(3.65,.42,2.6)));await frames(20)
			var upstairs=await go(room,Vector3(3.65,3.66,-2.6))
			check(upstairs and room.root.to_local(p.position).y>3.4,"Furnished inn stairs reach the upstairs rooms without jumping")
			check(await go(room,Vector3(3.65,.36,2.6)),"Walk back down the inn stairs")
			check(await go(room,Vector3(0,.36,0)),"Return from inn stairs to the exit aisle")
		check(await go(room,Vector3(0,0,room.data.body_depth/2+3)),"Walk back out of "+room.data.id)
		await frames(10)
		check(room.meshes.Roof.visible,"Roof restores after leaving "+room.data.id)
	# Land on original ground to start the giant encounters across old and new districts.
	run.enabled=true;game.reset_player_at(world.sky_islands.ground_point+Vector3.UP*.15);await frames(120)
	check(run.completed and run.ground_remaining()==50,"All 25 original and new districts spawn two ground giants")
	var giant=null
	for enemy in game.enemies:
		if enemy.ground_giant and (giant==null or enemy.position.distance_squared_to(p.position)<giant.position.distance_squared_to(p.position)):giant=enemy
	var before=giant.position.distance_to(p.position)
	game.tuning.freeze_ai=false;game.tuning.invincible=false;p.hp=p.max_hp;p.invuln=0
	await frames(250)
	check(giant.position.distance_to(p.position)<before and giant.attack_count>0,"Ground giant pursues and initiates attacks with real AI")
	check(p.hp<p.max_hp,"Ground giant attacks cause real damage")
	game.tuning.freeze_ai=true;game.tuning.invincible=true
	if visual:
		game.camera_rig.set_process(false);game.hud.hide()
		var district=world.furnished_districts[0]
		game.camera_rig.camera.global_position=district+Vector3(60,65,95)
		game.camera_rig.camera.look_at(district);await capture("10-furnished-district")
		game.camera_rig.camera.global_position=Vector3(850,1000,350)
		game.camera_rig.camera.look_at(Vector3(0,0,-430));await capture("11-expanded-ground")
	print("DISTRICT_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
