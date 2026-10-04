extends SceneTree
var failures=0
var game
var model
const BASE_MOTION="res://assets/characters/musashi/animations/motion.gd"
const V05_MOTION="res://assets/characters/musashi/animations/relaxed_idle_v05.gd"
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func poses_for(sk: Skeleton3D,script_path: String,velocity: Vector3,on_ground: bool,is_dodging: bool)->Array:
	model.skeleton=sk
	var motion=load(script_path).new(model)
	motion.update(.016,velocity,on_ground,2 if not on_ground else 0,0,is_dodging)
	motion.phase=.9
	for frame in 45:
		motion.dirty=true
		motion.evaluate()
	var poses=[]
	for i in sk.get_bone_count():poses.append(sk.get_bone_global_pose(i))
	return poses
func same_poses(a: Array,b: Array)->bool:
	if a.size()!=b.size():return false
	for i in a.size():
		if not a[i].is_equal_approx(b[i]):return false
	return true
func snap(path: String):
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
	game.start_game();game.encounters.enabled=false;game.encounters.pending=0;game.orb_system.active=false;game.player.smoke_mode=true
	var p=game.player
	p.select_character(2);await process_frame
	p.set_physics_process(false);p.musashi.set_physics_process(false);p.musashi.set_process(false);p.model.set_process(false)
	model=p.model
	var actual=model.skeleton
	check(model.rig_visual.scene_file_path==MusashiModel.REVIEW_MODEL,"Default Edo selection loads V05 export")
	check(model.locomotion.get_script().resource_path==V05_MOTION,"Default Edo uses the stationary relaxed idle adapter")
	check(actual.get_bone_count()==16,"V05 retains the 16-bone animation contract")
	var reference=load(MusashiModel.ORIGINAL_MODEL).instantiate();model.body.add_child(reference);reference.hide()
	var reference_sk: Skeleton3D=reference.find_child("Skeleton3D",true,false)
	var rest_ok=reference_sk.get_bone_count()==actual.get_bone_count()
	for i in actual.get_bone_count():
		var n=actual.get_bone_name(i);var j=reference_sk.find_bone(n)
		rest_ok=rest_ok and j>=0 and actual.get_bone_global_rest(i).is_equal_approx(reference_sk.get_bone_global_rest(j))
	check(rest_ok,"V05 bone names and rest transforms match the original fallback")
	var meshes=model.rig_visual.find_children("*","MeshInstance3D",true,false)
	var skin_ok=not meshes.is_empty()
	for mesh in meshes:skin_ok=skin_ok and mesh.skin!=null and mesh.skin.get_bind_count()>0
	check(skin_ok,"Every V05 mesh retains a bound skin")
	var colors_ok=true;var geometry_ok=true;var triangles_ok=true
	for mesh in meshes:
		if mesh.material_override:
			colors_ok=colors_ok and not mesh.material_override.resource_name.to_lower().contains("clay")
		else:
			var source: Mesh=mesh.mesh.get_meta("v05_source_mesh")
			var original=source.surface_get_arrays(0);var total=0
			for surface in mesh.mesh.get_surface_count():
				var arrays=mesh.mesh.surface_get_arrays(surface)
				geometry_ok=geometry_ok and arrays[Mesh.ARRAY_VERTEX]==original[Mesh.ARRAY_VERTEX] and arrays[Mesh.ARRAY_BONES]==original[Mesh.ARRAY_BONES] and arrays[Mesh.ARRAY_WEIGHTS]==original[Mesh.ARRAY_WEIGHTS]
				total+=arrays[Mesh.ARRAY_INDEX].size()
				colors_ok=colors_ok and not mesh.mesh.surface_get_material(surface).resource_name.to_lower().contains("clay")
			triangles_ok=triangles_ok and total==original[Mesh.ARRAY_INDEX].size()
	check(colors_ok,"Every V05 mesh uses the established V01 color palette")
	check(geometry_ok,"Color mapping preserves all V05 positions and skin weights")
	check(triangles_ok,"Material partitioning preserves the complete V05 triangle set")
	for label in ["run","jump","dodge","beam","meteor","fireball","hit","shield"]:
		p.musashi.cancel();p.musashi.duration=1.0;p.musashi.elapsed=.5
		match label:
			"beam":p.musashi.state=p.musashi.State.BEAM
			"meteor":p.musashi.state=p.musashi.State.METEOR_CAST
			"fireball":p.musashi.state=p.musashi.State.FIREBALL
			"hit":p.musashi.state=p.musashi.State.HIT_REACTION
			"shield":p.musashi.state=p.musashi.State.FIRE_SHIELD
		var velocity=Vector3(0,0,-8) if label=="run" else Vector3.ZERO
		var baseline=poses_for(reference_sk,BASE_MOTION,velocity,label!="jump",label=="dodge")
		var integrated=poses_for(actual,V05_MOTION,velocity,label!="jump",label=="dodge")
		check(same_poses(baseline,integrated),"V05 preserves original "+label+" full skeleton pose")
		var finite=true
		for pose in integrated:finite=finite and pose.origin.is_finite() and pose.basis.is_finite()
		check(finite and model.hand_position("L").is_finite() and model.hand_position("R").is_finite(),label+" transforms and hand attachments remain finite")
	p.musashi.cancel()
	var baseline_idle=poses_for(reference_sk,BASE_MOTION,Vector3.ZERO,true,false)
	var idle=poses_for(actual,V05_MOTION,Vector3.ZERO,true,false)
	check(not same_poses(baseline_idle,idle),"Stationary idle uses the relaxed arm posture")
	var lower_unchanged=true
	for n in ["Hips","Chest","Head","Leg_L","Leg_R","Shin_L","Shin_R","Foot_L","Foot_R"]:
		var i=actual.find_bone(n)
		lower_unchanged=lower_unchanged and idle[i].is_equal_approx(baseline_idle[reference_sk.find_bone(n)])
	check(lower_unchanged,"Relaxed idle preserves head, torso and planted-leg poses")
	model.skeleton=actual
	if "--visual" in OS.get_cmdline_user_args():
		root.size=Vector2i(1024,720);root.set_flag(Window.FLAG_NO_FOCUS,true)
		p.position=Vector3(-2,game.world.height_at(-2,30)+.12,30);p.rotation.y=PI
		game.camera_rig.yaw=0;game.camera_rig.pitch=.36;game.camera_rig.distance=14;game.camera_rig.current_distance=14;game.camera_rig.reset_follow();game.camera_rig._process(1);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
		game.hud.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		await snap("/tmp/goemon-edo-v05-colored-gameplay.png")
		var cam=game.camera_rig.camera
		cam.global_position=p.global_position+Vector3(3,2.4,4.4);cam.look_at(p.global_position+Vector3.UP*1.15);cam.fov=40
		await snap("/tmp/goemon-edo-v05-colored-idle.png")
		cam.global_position=p.global_position+Vector3(.2,1.6,2.7);cam.look_at(p.global_position+Vector3.UP*1.55);cam.fov=35
		await snap("/tmp/goemon-edo-v05-colored-face.png")
	print("EDO_V05_INTEGRATION_RESULT failures=",failures)
	game.queue_free();await process_frame;await process_frame
	quit(1 if failures else 0)
