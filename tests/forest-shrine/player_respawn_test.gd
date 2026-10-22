extends SceneTree
## Fatal damage must preserve the live siege, including when the wave ends
## during the respawn delay. Exercise the actual scene and character controls.
var checks=0
var failures=0
var game
var config_path="user://player-respawn-test-%d.cfg"%OS.get_process_id()
func _initialize():
	create_timer(150).timeout.connect(func():printerr("FAIL: respawn test timeout");quit(1))
	run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func frames(count:int=3):
	for i in range(count):await physics_frame
func fatal_hit():
	var p=game.player
	game.tuning.invincible=false;p.invuln=0
	p.cancel_charge();p.hp=1
	p.take_hit(100000,Vector3.RIGHT)
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game
	await frames()
	game.player.select_character(18)
	game.start_wave();game.model.waves.spawn_clock=10000
	var p=game.player;var m=game.model
	var gold=m.gold;var wave=m.wave;var buildings=m.buildings.size()
	var ticks=game.model_tick_serial
	p.position=Vector3(75,20,60)
	fatal_hit()
	check(p.hp<=0,"Fatal damage still kills the character")
	check(m.phase=="wave" and not game.paused and not paused,"Player death leaves the battle running")
	check(not is_instance_valid(game.forest_ui.overlay),"Player death does not open the defeat menu")
	if m.phase!="wave":await finish();return
	check(game.respawn_left>0,"Death starts a short respawn countdown")
	check(not m.hero_targetable,"Enemies stop targeting the dead player immediately")
	game.forest_ui.sync()
	check(game.forest_ui.respawn_notice.visible and "RESPAWNING" in game.forest_ui.respawn_notice.text,"The HUD explains the respawn countdown")
	await frames(5)
	check(game.model_tick_serial>ticks,"The world continues advancing while the player is dead")
	check(game.respawn_left<game.PLAYER_RESPAWN_DELAY,"The live physics loop advances the countdown")
	check(m.gold==gold and m.wave==wave and m.buildings.size()==buildings,"Death preserves the settlement, wave and economy")
	var left=game.respawn_left
	game.show_pause();await frames(5)
	check(is_equal_approx(game.respawn_left,left),"Pausing freezes the respawn countdown")
	game.resume()
	# Deterministic advance of the real countdown; regular physics already
	# verified it runs alongside the live world above.
	game._tick_player_respawn(left+.01)
	check(p.hp==p.max_hp and game.respawn_left==0,"Respawn restores full health")
	check(p.character_id==18 and p.active_ability.ammo_infinite,"Respawn preserves the selected fighter and infinite rifle")
	check(p.position.distance_to(Vector3(0,m.surface_height(0,18)+.15,18))<40,"Player returns near the castle")
	check(p.position.y>=m.surface_height(p.position.x,p.position.z),"Respawn is above the current map's terrain")
	check(not m.occupancy.has(m.cell_of(p.position)) and not m.trees.has(m.cell_of(p.position)),"Respawn avoids structures and trees")
	check(p.invuln>=1.9,"Respawn provides two seconds of protection")
	check(p.velocity==Vector3.ZERO and not p.primary_down and not p.active_ability.primary_held,"Respawn clears movement and held attacks")
	check(m.hero_targetable,"Living player becomes targetable again")
	game.camera_rig.update_camera(0)
	check(game.camera_rig.first_person_active() and not p.model.visible,"Master Chief returns to first person")
	game.forest_ui.sync()
	check(not game.forest_ui.respawn_notice.visible,"Countdown disappears after respawn")
	var health=p.hp;p.take_hit(100000,Vector3.RIGHT)
	check(p.hp==health,"Respawn protection prevents immediate repeated damage")
	await frames(120)
	check(p.hp>0 and absf(p.position.y-m.surface_height(p.position.x,p.position.z))<1,"Respawn settles onto the real Kai Highway collision surface")
	# If the home area becomes obstructed, choose another physical opening.
	var home=m.cell_of(game.checkpoint)
	m._make_building("wall",home,0,1);m.rebuild_navigation();m.revision+=1;game.world.sync(0)
	fatal_hit();game._tick_player_respawn(4)
	check(p.hp==p.max_hp and not m.occupancy.has(m.cell_of(p.position)),"Repeated respawn finds a new clear point if home is obstructed")
	# Native death poses must survive the delay, then reset for normal play.
	for id in range(1,18):
		p.select_character(id);fatal_hit()
		check(p.hp<=0 and m.phase=="wave","Character %d dies without ending the wave"%id)
		if id in [16,17]:check(p.active_ability.mode=="dead","Character %d retains its native death pose during the countdown"%id)
		game._tick_player_respawn(4)
		check(p.hp==p.max_hp and p.character_id==id,"Character %d respawns with the same loadout"%id)
		if id in [16,17]:check(p.active_ability.mode!="dead","Character %d leaves its death pose on respawn"%id)
	fatal_hit()
	m.enemies.clear();m.waves.pending=0
	game._physics_process(.1)
	check(p.hp==p.max_hp and game.respawn_left==0,"A wave ending during the countdown restores the player for preparation")
	check(not game.forest_ui.respawn_notice.visible,"Preparation has no stale countdown")
	game.start_wave();m.waves.spawn_clock=10000
	check(m.phase=="wave","The next wave starts normally after a respawn")
	fatal_hit()
	m.damage_building(1,100000);game.set_phase_view()
	game._tick_player_respawn(4)
	check(m.phase=="defeat" and game.respawn_left==0 and p.hp<=0,"Castle destruction still ends the run and cancels pending respawn")
	check(is_instance_valid(game.forest_ui.overlay),"Castle defeat still displays the defeat menu")
	await finish()
func finish():
	print("PLAYER RESPAWN: %d checks, %d failures"%[checks,failures])
	paused=false
	game.queue_free();await frames()
	if FileAccess.file_exists(config_path):DirAccess.remove_absolute(config_path)
	quit(1 if failures else 0)
