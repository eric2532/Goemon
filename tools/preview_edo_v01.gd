extends SceneTree
# Explicit opt-in preview harness. Never used by the normal game startup.
var game
var output="res://tests/edo-redesign-v01/"
var visual=false
var results=[]
func _initialize():
	visual="--visual" in OS.get_cmdline_user_args()
	call_deferred("run")
func check(ok,label):
	results.append({"check":label,"passed":ok})
	print("PASS " if ok else "FAIL ",label)
func snap(label):
	if not visual:return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+label+".png")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.start_game();game.tuning.freeze_ai=true;game.player.smoke_mode=true
	game.player.select_character(2)
	await process_frame
	var p=game.player
	p.set_physics_process(false);p.musashi.set_physics_process(false);p.musashi.set_process(false);p.model.set_process(false);game.camera_rig.set_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var cam=game.camera_rig.camera
	cam.fov=63
	var follow=p.global_position+Vector3.UP*1.4
	cam.global_position=follow+Vector3(0,sin(.36),cos(.36))*14
	cam.look_at(follow)
	var original=p.model.rig_visual
	var sk=p.model.skeleton
	var rest={}
	for i in sk.get_bone_count():rest[sk.get_bone_name(i)]=sk.get_bone_global_rest(i)
	await snap("gameplay_before")
	var candidate=load("res://assets/characters/musashi/preview/edo_ember_v01.glb").instantiate()
	p.model.body.add_child(candidate);original.hide()
	p.model.rig_visual=candidate;p.model.skeleton=candidate.find_child("Skeleton3D",true,false)
	sk=p.model.skeleton
	check(sk.get_bone_count()==16,"16 existing named bones")
	var match_rest=true
	for i in sk.get_bone_count():
		var n=sk.get_bone_name(i)
		match_rest=match_rest and rest.has(n) and sk.get_bone_global_rest(i).is_equal_approx(rest.get(n,Transform3D.IDENTITY))
	check(match_rest,"Exact compatible global rest transforms after GLB roundtrip")
	p.model.locomotion=MusashiMotion.new(p.model)
	await snap("gameplay_after")
	for state in ["idle","run","jump","beam","meteor"]:
		var motion=p.model.locomotion
		motion.reset();p.musashi.cancel()
		if state=="beam":p.musashi.state=p.musashi.State.BEAM
		if state=="meteor":p.musashi.state=p.musashi.State.METEOR_CAST
		motion.update(.016,Vector3(0,0,-8) if state=="run" else Vector3.ZERO,state!="jump",2 if state=="jump" else 0,0,false)
		motion.phase=.9
		for frame in 45:motion.dirty=true;motion.evaluate()
		var candidate_poses=[]
		for i in sk.get_bone_count():candidate_poses.append(sk.get_bone_global_pose(i))
		p.model.skeleton=original.find_child("Skeleton3D",true,false)
		var baseline=MusashiMotion.new(p.model)
		baseline.update(.016,Vector3(0,0,-8) if state=="run" else Vector3.ZERO,state!="jump",2 if state=="jump" else 0,0,false)
		baseline.phase=.9
		for frame in 45:baseline.dirty=true;baseline.evaluate()
		var same=true
		for i in sk.get_bone_count():same=same and candidate_poses[i].is_equal_approx(p.model.skeleton.get_bone_global_pose(i))
		check(same,state+" full skeleton pose and hand origins match original")
		p.model.skeleton=sk
		var finite=true
		for i in sk.get_bone_count():finite=finite and sk.get_bone_global_pose(i).origin.is_finite()
		check(finite,state+" uses existing MusashiMotion without invalid transforms")
		cam.global_position=p.global_position+Vector3(3,2.4,-4.4);cam.look_at(p.global_position+Vector3.UP*1.15);cam.fov=40
		await snap("pose_"+state)
	FileAccess.open(output+"compatibility.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	var ok=true
	for r in results:ok=ok and r.passed
	quit(0 if ok else 1)
