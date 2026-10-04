extends "res://scripts/combat_tests.gd"
var visual=false
func frames(n: int):
	for i in range(n):await get_tree().physics_frame
func hold(code: Key,down: bool):
	var e=InputEventKey.new();e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e)
	await get_tree().process_frame
func capture(label: String):
	if not visual:return
	game.hud.toast_time=0;game.hud.banner_time=0;game.player.invuln=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/sky-descent/"+label+".png")
func run():
	visual="--flight-visual" in OS.get_cmdline_user_args()
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
	game.start_game();var p=game.player;var sky=game.world.sky_islands;var run=game.encounters
	p.smoke_mode=true;game.camera_rig.yaw=0
	game.camera_rig.set_process_unhandled_input(false);Input.use_accumulated_input=false;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await frames(20)
	check(sky.COUNT==784 and sky.clouds.size()>150 and sky.clouds.size()<350,"Full map contains 784 islands and a sparse set of solid clouds")
	check(sky.bridges.is_empty() and sky.jump_routes.size()==672,"Cloud roads are replaced by local jumping routes")
	var coverage=true
	for layer in range(sky.LAYERS):
		var extent=Rect2(Vector2(sky.islands[layer*sky.PER_LAYER].x,sky.islands[layer*sky.PER_LAYER].z),Vector2.ZERO)
		for slot in range(sky.PER_LAYER):
			var point=sky.islands[layer*sky.PER_LAYER+slot];extent=extent.expand(Vector2(point.x,point.z))
		coverage=coverage and extent.size.x>game.world.playable_bounds.size.x*.6 and extent.size.y>game.world.playable_bounds.size.y*.6
	check(coverage,"Island groups span both axes of the expanded world on every layer")
	var surfaces=true
	for point in sky.islands:
		var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP,point-Vector3.UP,1))
		surfaces=surfaces and not hit.is_empty() and hit.normal.y>.99
	check(surfaces,"Every island has an exact walkable surface after full-map expansion")
	var clouds=true
	for point in sky.cloud_origins:
		var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP,point-Vector3.UP,1))
		clouds=clouds and not hit.is_empty() and hit.normal.y>.99
	check(clouds,"All scattered cloud platforms have matching collision")
	var cape=p.model.ronin_scarf
	var mesh=cape.find_children("*","MeshInstance3D",true,false)[0].mesh
	await key(KEY_5)
	check(p.gold_cloak and p.scarf_equipped and cape.visible and cape.cloth.get_shader_parameter("gold_cloak"),"5 equips the gold flying cape")
	check(cape.find_children("*","MeshInstance3D",true,false)[0].mesh==mesh,"Gold cape reuses the exact original mesh and cloth animation")
	var start_y=p.position.y
	await hold(KEY_SPACE,true);await frames(70)
	check(p.flying and p.position.y>start_y+12 and p.velocity.y>17,"Holding Space ascends continuously from the ground")
	p.smoke_move=Vector2.RIGHT;await frames(60)
	var normal=Vector2(p.velocity.x,p.velocity.z).length()
	check(normal>35 and normal<37 and p.model.body.rotation.x<-.1,"Flight has directional control and a gentle forward body lean")
	await hold(KEY_SHIFT,true);await frames(60)
	check(Vector2(p.velocity.x,p.velocity.z).length()>normal*1.7 and p.velocity.y>31,"Shift boosts both horizontal flight and ascent")
	if visual:
		p.smoke_move=Vector2.ZERO
		game.camera_rig.set_process(false)
		game.camera_rig.camera.global_position=p.position+Vector3(5,3,8)
		game.camera_rig.camera.look_at(p.position+Vector3.UP*1.2)
		await capture("12-gold-flight")
		game.camera_rig.set_process(true)
	await hold(KEY_SHIFT,false);await hold(KEY_SPACE,false);p.smoke_move=Vector2.ZERO;await frames(70)
	check(p.flying and p.velocity.y< -9,"Releasing Space smoothly descends instead of hovering forever")
	game.show_pause();var paused_at=p.position;await frames(15)
	check(p.position==paused_at,"Pause freezes flight")
	game.resume();await key(KEY_4)
	check(not p.gold_cloak and p.scarf_equipped and not cape.cloth.get_shader_parameter("gold_cloak"),"4 switches back to the original red cape")
	await key(KEY_5);await key(KEY_Q);await frames(3)
	check(not p.can_fly() and not cape.is_visible_in_tree(),"Switching character disables gold-cape flight and hides the cape")
	await key(KEY_Q);await frames(3)
	check(p.can_fly() and cape.is_visible_in_tree(),"Returning to Goemon restores the selected gold cape")
	# Same-altitude travel must load the destination without a layer change.
	var far_index=sky.PER_LAYER-1
	game.reset_player_at(sky.islands[far_index]+Vector3.UP*.12)
	var spawned_before=run.total_spawned
	run.refresh_encounters()
	check(run.total_spawned==spawned_before and not run.pending_spawns.is_empty(),"Travel queues new encounters without a synchronous actor-creation burst")
	run.spawn_pending()
	check(run.total_spawned-spawned_before==run.SPAWNS_PER_FRAME,"Encounter loading creates only the configured four actors per tick")
	await frames(20)
	check(run.current_island==far_index and run.spawned.has(far_index),"Cross-map travel activates the chosen island's enemies")
	check(game.active_enemy_count()<=120,"Full-map flight keeps island encounters bounded to ten nearby arenas")
	# Test collision against an isolated solid wall in open air.
	game.reset_player_at(sky.islands[far_index]+Vector3.UP*70);p.smoke_move=Vector2.UP
	game.camera_rig.yaw=0
	var wall=Geo.box(game,p.position+Vector3(0,15,-6),Vector3(40,60,.6),Geo.mat("888888"),true)
	await hold(KEY_SPACE,true);await frames(55)
	check(p.position.z>wall.position.z+.6,"Boost-capable flight still respects solid world collision")
	await hold(KEY_SPACE,false);p.smoke_move=Vector2.ZERO;wall.queue_free()
	# Lift from the ground through a clear edge lane back into the sky.
	var edge=game.world.playable_bounds.position+Vector2(18,18)
	game.reset_player_at(Vector3(edge.x,game.world.height_at(edge.x,edge.y)+.2,edge.y))
	p.set_gold_cloak(false);await frames(20)
	check(run.completed and run.ground_spawned,"Ground arrival still starts giant encounters")
	await key(KEY_5);await hold(KEY_SPACE,true);await hold(KEY_SHIFT,true);await frames(150)
	check(not run.completed and not run.spawned.is_empty() and p.position.y>sky.ground_point.y+sky.DROP,"Flying back up reactivates sky encounters after reaching ground")
	await hold(KEY_SPACE,false);await hold(KEY_SHIFT,false)
	var rooms=game.world.furnished_town.rooms
	check(rooms.size()==96 and is_equal_approx(rooms[0].root.scale.x,1.5),"All 96 furnished buildings are 50 percent larger")
	if visual:
		game.hud.hide();game.camera_rig.set_process(false)
		var district=game.world.furnished_districts[0]
		game.camera_rig.camera.global_position=district+Vector3(60,65,95);game.camera_rig.camera.look_at(district)
		await capture("13-larger-buildings")
		game.camera_rig.camera.global_position=Vector3(700,900,650);game.camera_rig.camera.look_at(Vector3(0,450,-430))
		# A survey view reveals the whole grid; normal play culls distant detail.
		for mesh_node in sky.find_children("*","GeometryInstance3D",true,false):mesh_node.visibility_range_end=0
		await capture("14-full-map-sky")
	print("FLIGHT_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
