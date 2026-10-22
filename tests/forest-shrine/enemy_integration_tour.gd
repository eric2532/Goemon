extends SceneTree
## Native snapshots of the approved enemy models in the real Forest scene.
var game
var output="res://docs/enemy-concepts/runtime-v01/"
func _initialize():call_deferred("run")
func run():
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://scenes/forest_shrine.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame
	game.start_wave();game.set_physics_process(false);game.model.waves.spawn_clock=100000
	game.forest_ui.message_left=0;AudioServer.set_bus_mute(0,true)
	game.player.position=Vector3(-22,.15,52)
	var positions=[Vector3(-16,0,28),Vector3(-7,0,28),Vector3(18,0,28),Vector3(2,0,28)]
	for variant in range(4):
		var e=game.model.waves.spawn_enemy(variant,positions[variant]);e.facing=PI;e.action="walk";e.velocity=Vector3.ZERO;e.stun=100
	game.sync_enemies()
	for x in range(-20,21):
		for y in range(-20,21):game.model.visible_cells[Vector2i(x,y)]=true;game.model.explored[Vector2i(x,y)]=true
	game.world.update_fog();game.camera_rig.set_process(false)
	var camera=game.camera_rig.camera;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=62
	camera.position=Vector3(0,32,105);camera.look_at(Vector3(0,8,28))
	await capture("front")
	for e in game.model.enemies.values():e.facing=PI*.5
	await capture("side")
	for e in game.model.enemies.values():e.facing=0
	await capture("back")
	for e in game.model.enemies.values():e.facing=PI;e.velocity=Vector3(0,0,e.variant*.05+1);e.walk_phase=PI*.5
	await capture("walk-left")
	for e in game.model.enemies.values():e.walk_phase=PI*1.5
	await capture("walk-right")
	for e in game.model.enemies.values():
		e.velocity=Vector3.ZERO;e.action="windup";e.attack=true;e.attack_progress=.6;e.attack_point=e.pos+Vector3(0,2,10)
	await capture("windup")
	for e in game.model.enemies.values():e.attack_progress=1.0
	await capture("contact")
	var giant=game.model.enemies.values()[2];var actor=game.actors[giant.id]
	game.player.position=giant.pos+Vector3(0,.15,13);actor.bar.visible=true;actor.hp=2400;giant.hp=2400
	game.camera_rig.set_process(true);game.camera_rig.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	game.camera_rig.yaw=0;game.camera_rig.reset_follow();game.camera_rig._process(0)
	await capture("giant-combat")
	for e in game.model.enemies.values():e.pos+=Vector3(96,0,96);e.attack_point+=Vector3(96,0,96)
	game.player.position=giant.pos+Vector3(0,.15,13)
	for x in range(-39,40):
		for y in range(-39,40):game.model.visible_cells[Vector2i(x,y)]=true;game.model.explored[Vector2i(x,y)]=true
	game.world.update_fog();game.camera_rig.reset_follow();game.camera_rig._process(0)
	await capture("giant-away-from-origin")
	game.show_pause();await capture("paused")
	game.queue_free();paused=false;await process_frame;await create_timer(.25).timeout
	print("FOREST_ENEMY_TOUR_RESULT complete");quit()
func capture(label: String):
	for i in range(6):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+label+".png")
