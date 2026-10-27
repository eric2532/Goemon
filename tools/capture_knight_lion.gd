extends SceneTree
## Render the real T input and native contacts on the current painterly battlefield.
const OUT="res://build/Other Files/Asset Toolkit/Knight Lion/"
var game
var cfg="user://knight-lion-tour-%d.cfg"%OS.get_process_id()
func _initialize():run.call_deferred()
func frames(n:int):
	for i in n:await physics_frame
func capture(label_:String):
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label_+".png")
func run():
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=cfg
	root.add_child(game);current_scene=game;await frames(3)
	var p:Hero=game.player;p.select_character(7);p.set_auto_attack(false)
	game.tuning.invincible=true;game.start_wave()
	p.position=Vector3(0,game.world.height_at(0,110)+.15,110);p.velocity=Vector3.ZERO
	game.camera_rig.yaw=0;game.camera_rig.set_process(false)
	var camera=game.camera_rig.camera
	camera.global_position=p.position+Vector3(9,6,12);camera.look_at(p.position+Vector3(0,1,-4))
	await frames(40)
	var direction=p.combat_attack_direction();direction.y=0;direction=direction.normalized()
	var targets=[]
	for distance in [6,12,20]:
		var point=p.position+direction*distance;point.y=game.world.height_at(point.x,point.z)
		var row=game.model.waves.spawn_enemy(0,point);row.hp=1000;row.max_hp=1000;targets.append(row.id)
	game.sync_enemies();await frames(3)
	var event=InputEventAction.new();event.action="sky_strike";event.pressed=true;p._unhandled_input(event)
	event.pressed=false;p._input(event)
	await frames(25);await capture("field-charge")
	await frames(27);await capture("field-rush")
	var lions=get_nodes_in_group("knight_lions")
	if not lions.is_empty():
		var lion=lions[0];lion.set_physics_process(false)
		var saved=camera.global_transform;game.ui.hide()
		var side=lion.direction.cross(Vector3.UP)
		camera.global_position=lion.global_position+lion.direction*5+side*6+Vector3.UP*3.4
		camera.look_at(lion.global_position+Vector3.UP*1.8)
		await frames(2);await capture("field-lion")
		camera.global_transform=saved;game.ui.show();lion.set_physics_process(true)
	await frames(320)
	var damaged=0
	for id in targets:
		if not game.model.enemies.has(id) or game.model.enemies[id].hp<1000:damaged+=1
	print("KNIGHT_LION_FIELD_RESULT damaged=%d live_lions=%d"%[damaged,get_nodes_in_group("knight_lions").size()])
	var ok=damaged>0 and get_nodes_in_group("knight_lions").is_empty()
	game.queue_free();await frames(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	quit(0 if ok else 1)
