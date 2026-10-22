extends SceneTree
const ORIGIN=Vector3(0,.1,70)
var game
var checks=0
var failures=0
var config_path="user://ddii-combat-view-%d.cfg"%OS.get_process_id()
func _initialize():
	create_timer(90).timeout.connect(func():printerr("FAIL: DDII combat view timeout");quit(1))
	run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func frames(n: int=3):
	for i in n:await physics_frame
func fresh(id: int):
	Input.action_release("move_right");game.player.select_character(id);game.player.cancel_charge(true)
	game.player.position=ORIGIN;game.player.velocity=Vector3.DOWN*10;game.player.move_and_slide();game.player.velocity=Vector3.ZERO
	game.player.set_auto_attack(false);game.player.combat_aim_left=0
	if game.player.is_rogue_character():
		game.player.active_ability.reset_run();game.player.active_ability.player.pos=game.player.position
	game.camera_rig.yaw=.43;game.camera_rig.pitch=.22;game.camera_rig.reset_follow();game.camera_rig.current_distance=17;game.camera_rig.update_camera(0)
	game.model.update_vision(game.player.position)
func run():
	# These movement fixtures use flat ground, independent of raised-route map presets.
	var map_doc=load("res://scripts/forest/forest_map_document.gd").new();map_doc.load_original();set_meta("forest_custom_layout",map_doc.data)
	game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path=config_path;root.add_child(game);current_scene=game;await frames();game.start_wave();game.model.waves.spawn_clock=10000
	game.set_physics_process(false);game.player.set_physics_process(false);game.camera_rig.set_process(false)
	game.set_forest_camera_distance(17);game.set_forest_character_screen_offset(.08);game.set_forest_hud_scale(.85)
	var rig=game.camera_rig;var p=game.player
	p.position=ORIGIN;p.smoke_mode=true;p.smoke_move=Vector2(0,-1);rig.yaw=0;rig.reset_follow();p.position.z-=.2;rig.update_camera(1.0/60)
	check(rig.follow.z<ORIGIN.z-.01 and not rig.travel_follow.buffering,"Combat camera follows the first forward step without a one-metre hesitation")
	var legacy=preload("res://scripts/travel_camera_follow.gd").new();legacy.reset(Vector3.ZERO)
	var legacy_position=legacy.update(Vector3(0,0,-.2),Vector2.UP,0,1.0/60)
	check(legacy.buffering and absf(legacy_position.z)<.001,"Other game modes retain their existing forward camera buffer")
	p.smoke_mode=false;p.smoke_move=Vector2.ZERO
	check(game.has_method("attack_aim_point"),"Forest provides one shared aim point for mixed combat")
	if not game.has_method("attack_aim_point"):await finish();return
	for id in range(1,13):
		await fresh(id);var before: Transform3D=rig.camera.global_transform
		var expected: Vector3=game.attack_aim_point()-p.position;expected.y=0;expected=expected.normalized()
		check(game.attack_direction().dot(expected)>.9999,"Fighter %d uses the shared crosshair direction"%id)
		if p.is_rogue_character():
			var c=p.active_ability;c._update_aim();var flat: Vector3=c.aim-p.position;flat.y=0
			check(flat.normalized().dot(expected)>.9999,"Rogue fighter %d shares the same aim as native fighters"%id)
		else:
			if id==1:p.start_attack(false,1)
			else:p.musashi.cast_fireball(false)
			check(p.facing.dot(expected)>.9999,"Native fighter %d faces the crosshair at attack start"%id)
		check(rig.camera.global_transform.is_equal_approx(before) and rig.distance==17 and rig.pitch==.22,"Fighter %d does not snap or zoom the shared camera when attacking"%id)
	await fresh(3);var c=p.active_ability;c.action("flintlock")
	check(p.combat_aiming() and c.projectiles.size()==1,"A hybrid's actual ranged secondary starts the aim-facing hold")
	Input.action_press("move_right");p._physics_process(.02)
	check(p.facing.dot(game.attack_direction())>.98,"A hybrid strafes while continuing to face its ranged aim")
	check(Vector2(p.velocity.x,p.velocity.z).length()>.1,"Ranged aim-facing preserves movement")
	for i in 30:p._physics_process(.02)
	var right=Vector3.RIGHT.rotated(Vector3.UP,rig.yaw)
	check(not p.combat_aiming() and p.facing.dot(right)>.99,"Released ranged aim returns naturally to movement facing")
	Input.action_release("move_right");p.hold_combat_aim();c.player.cooldowns.cutlass=0;c.attack();var committed: float=c.player.attack.angle
	check(not p.combat_aiming(),"Starting a melee strike releases the ranged-facing hold")
	rig.yaw+=.3;p._physics_process(.01)
	check(absf(wrapf(c.player.attack.angle-committed,-PI,PI))<.001,"Melee retains its committed authored attack direction")
	await fresh(6);c=p.active_ability;c.action("cutlass");rig.yaw+=.3;p._physics_process(.02)
	check(c.player.charging and p.facing.dot(game.attack_direction())>.99,"A charging ranged primary follows manual camera aim while moving")
	await fresh(1);p.select_weapon(2);game.throw_coin(false);Input.action_press("move_right");p._physics_process(.02)
	check(p.combat_aiming() and p.facing.dot(game.attack_direction())>.98,"Goemon's ranged coin attack shares the hybrid strafe-facing behavior")
	p.select_weapon(1);p.start_attack(false,1);check(not p.combat_aiming(),"Returning to Goemon's pipe restores melee-facing ownership")
	await fresh(1);p.select_weapon(2);p.start_attack(false,1);rig.yaw+=.35;rig.update_camera(0);Input.action_press("move_right");p._physics_process(.02)
	check(p.attack_left>0 and p.combat_aiming() and p.facing.dot(game.attack_direction())>.99,"Goemon's actual coin cast tracks aim during windup while strafing")
	await fresh(2);p.musashi.cast_fireball(false);rig.yaw+=.2;p._physics_process(.02)
	check(p.facing.dot(game.attack_direction())>.99,"Edo's ranged cast follows the same manual aim direction")
	await fresh(5);p.hold_combat_aim();c=p.active_ability;c.standard_evade();p._physics_process(.02)
	check(not p.combat_aiming() and p.combat_aim_left==0,"Evasion cancels the short ranged-facing hold")
	p.hold_combat_aim();p.select_character(7);check(p.combat_aim_left==0,"Changing fighters clears transient aim-facing state")
	await fresh(5);rig.yaw=0;rig.pitch=.22;rig.reset_follow();rig.update_camera(0)
	var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
	var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(12,12,.2);collision.shape=box;wall.add_child(collision);game.add_child(wall)
	wall.position=ORIGIN+Vector3(0,3,3);await frames()
	var aim: Vector3=game.crosshair_target()
	check((aim-p.position).dot(game.attack_direction())>0 and aim.z<ORIGIN.z,"Geometry between camera and hero cannot flip manual attacks backward")
	wall.position.z=ORIGIN.z-3;await frames();aim=game.crosshair_target()
	check(aim.z>ORIGIN.z-3.3 and aim.z<ORIGIN.z-2.5,"Cover ahead still blocks the shared aim ray")
	wall.queue_free();await frames()
	rig.pitch=.22;rig.yaw=0;rig.update_camera(0)
	if DisplayServer.get_name()!="headless":
		var before_look: Vector3=-rig.camera.global_basis.z
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		var mouse=InputEventMouseMotion.new();mouse.relative=Vector2(90,-10);rig._unhandled_input(mouse)
		check((-rig.camera.global_basis.z).dot(before_look)<.99,"Mouse look updates the aim ray immediately before the next attack, without waiting for a rendered frame")
	rig.yaw=0
	rig.pitch=-.65;rig.update_camera(0);check(game.projectile_direction(p.position+Vector3.UP).y>0,"Upward ranged aim remains available")
	rig.pitch=1.15;rig.update_camera(0);check(game.attack_direction().dot(Vector3.FORWARD)>.8,"Looking steeply down cannot turn melee attacks back toward the camera")
	var original: Vector3=game.crosshair_target();game.set_forest_show_crosshair(false)
	check(game.crosshair_target().is_equal_approx(original) and not game.forest_ui.crosshair_visible(),"The crosshair visibility preference remains independent of aim")
	check(game.settings.forest_camera_distance==17 and game.settings.forest_character_screen_offset==.08 and game.settings.forest_hud_scale==.85,"Saved camera and HUD preferences survive mixed combat")
	game.set_forest_show_crosshair(true)
	if "--visual" in OS.get_cmdline_user_args():
		await fresh(3);rig.pitch=.22;rig.update_camera(0);p.active_ability.action("flintlock");await shot("hybrid-ranged")
		await fresh(5);p.active_ability.action("cutlass");await shot("melee")
	game.model.phase="preparing";game.set_phase_view()
	check(rig.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and not game.forest_ui.crosshair_visible(),"Building-map camera and input remain independent")
	await finish()
func shot(label: String):
	await RenderingServer.frame_post_draw
	var folder=OS.get_environment("SONIC_DDII_CAPTURE_DIR")
	if folder.is_empty():folder="/tmp"
	root.get_texture().get_image().save_png(folder+"/ddii-view-"+label+".png")
func finish():
	Input.action_release("move_right");game.sound_library.cancel();game.music.stop()
	for voice in game.voices:voice.stop()
	game.queue_free();paused=false;await frames();await create_timer(.35).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	print("FOREST_DDII_COMBAT_VIEW_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
