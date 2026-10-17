extends SceneTree
## Deterministic 30-fps captures of the production Forest battlefield and rigs.
const STEP=1.0/30.0
var game
var out="res://docs/combat-polish"
var captures=0
func _initialize():call_deferred("run")
func capture(path: String):
	await process_frame
	RenderingServer.force_draw(false)
	var image=root.get_texture().get_image()
	image.save_png(out.path_join(path));captures+=1
func simulate(combat=null):
	game._physics_process(STEP)
	if combat!=null:combat.physics_step(STEP);combat.fx.tick(STEP)
	for actor in game.actors.values():
		if is_instance_valid(actor):actor._physics_process(STEP)
	game.crowd._process(STEP)
	game._process(STEP);game.forest_ui.sync()
func run():
	if DisplayServer.get_name()=="headless":quit(1);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.trim_prefix("--out=")
	for folder in [out,out.path_join("tower-frames"),out.path_join("wave-frames")]:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var ignore=FileAccess.open(out.path_join(".gdignore"),FileAccess.WRITE);ignore.store_string("");ignore.close()
	root.size=Vector2i(1440,900);root.content_scale_size=root.size
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://combat-polish-tour-%d.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game
	await process_frame;await process_frame
	game.player.position=Vector3(60,.15,30);game.player.facing=Vector3.FORWARD
	game.tuning.invincible=true;game.character_tuning={};game.tuning.pipe_range=3.5
	var m=game.model;var tower=m._make_building("tower",Vector2i(5,-3),0);m.rebuild_navigation();m.revision+=1
	game.world.sync(0);game.start_wave();game.model.waves.spawn_clock=10000
	game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	paused=true # Automatic nodes stop; production simulation advances only by STEP.
	m.waves.spawn_one();var target=m.enemies.values()[0]
	target.pos=Vector3(60,0,8);target.hp=10000;target.max_hp=10000;target.stun=100
	game.sync_enemies();m.update_vision(game.player.position)
	for w in m.workers.values():w.state="wounded"
	var worker=m.workers.values()[0];worker.state="garrison";worker.job=tower.id;worker.pos=m.center(tower);worker.timer=0
	game.world.sync(0)
	var camera=game.camera_rig.camera;camera.fov=60;camera.global_position=Vector3(76,19,37);camera.look_at(Vector3(48,5,-4))
	for frame in range(45):
		simulate();await capture("tower-frames/%03d.png"%frame)
		if frame==7:await capture("tower-arrow-flight.png")
		if frame==19:await capture("tower-arrow-impact.png")
	for w in m.workers.values():w.state="wounded"
	m.workforce.arrows.clear();game.tower_arrows.clear()
	game.player.select_character(9);game.player.set_physics_process(false)
	var combat=game.player.active_ability;combat.reset_run();combat.player.pos=game.player.global_position
	game.camera_rig.yaw=0;game.camera_rig.reset_follow();game.camera_rig._process(0)
	camera.fov=65
	game.player.model.rotation.y=0
	combat.action("flintlock")
	for frame in range(39):
		simulate(combat);await capture("wave-frames/%03d.png"%frame)
		if frame==1:await capture("purple-wave-windup.png")
		if frame==4:await capture("purple-wave-release.png")
		if frame==8:await capture("purple-wave-flight.png")
		if frame==12:await capture("purple-wave-follow-through.png")
	game.queue_free();paused=false;await process_frame;await create_timer(.4).timeout
	print("COMBAT_POLISH_TOUR captures=",captures);quit(0)
