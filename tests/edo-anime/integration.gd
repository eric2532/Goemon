extends SceneTree
var failures=0
var game
var model
const MOTION="res://assets/characters/musashi/animations/relaxed_idle_v05.gd"

func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func poses_for(sk: Skeleton3D,velocity: Vector3,on_ground: bool,is_dodging: bool)->Array:
	model.skeleton=sk
	var motion=load(MOTION).new(model)
	motion.update(.016,velocity,on_ground,2 if not on_ground else 0,0,is_dodging)
	motion.phase=.9
	for frame in 45:motion.dirty=true;motion.evaluate()
	var poses=[]
	for i in sk.get_bone_count():poses.append(sk.get_bone_global_pose(i))
	return poses
func same_poses(a: Array,b: Array)->bool:
	if a.size()!=b.size():return false
	for i in a.size():
		if not a[i].is_equal_approx(b[i]):return false
	return true
func snap(label: String):
	for frame in 6:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/edo-anime/"+label+".png")
func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.smoke_test=true;game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.freeze_ai=true;game.tuning.invincible=true
	game.start_game();game.encounters.enabled=false;game.encounters.pending=0;game.orb_system.active=false;game.player.smoke_mode=true
	var p=game.player
	var shape=p.find_children("*","CollisionShape3D",false,false)[0]
	var collider=shape.shape;var collision_transform=shape.transform;var hp=p.hp
	p.select_character(2);await process_frame
	p.set_physics_process(false);p.musashi.set_physics_process(false);p.musashi.set_process(false);p.model.set_process(false)
	model=p.model
	var actual=model.skeleton
	check(model.rig_visual.scene_file_path==MusashiModel.ANIME_MODEL,"Normal character selection equips revamped Edo")
	check(shape.shape==collider and shape.transform==collision_transform and p.hp==hp,"Shared collision geometry and health are unchanged")
	check(model.locomotion.get_script().resource_path==MOTION,"Existing relaxed idle adapter remains active")
	var reference=load(MusashiModel.REVIEW_MODEL).instantiate();model.body.add_child(reference);reference.hide()
	# Compare animation/attachment compatibility at Edo's intentional display size.
	reference.scale=model.rig_visual.scale
	var reference_sk: Skeleton3D=reference.find_child("Skeleton3D",true,false)
	var rest_ok=reference_sk.get_bone_count()==actual.get_bone_count() and actual.get_bone_count()==16
	for i in actual.get_bone_count():
		var n=actual.get_bone_name(i);var j=reference_sk.find_bone(n)
		rest_ok=rest_ok and j==i and actual.get_bone_global_rest(i).is_equal_approx(reference_sk.get_bone_global_rest(j))
	check(rest_ok,"All 16 bone names, order and rest transforms match the previous Edo")
	var bound=true
	for mesh in model.rig_visual.find_children("*","MeshInstance3D",true,false):bound=bound and mesh.skin!=null and mesh.skin.get_bind_count()>0
	check(bound,"Face, hair, costume and hands all have bound skins")
	for label in ["idle","run","jump","dodge","beam","meteor","fireball","hit","shield"]:
		p.musashi.cancel();p.musashi.duration=1.0;p.musashi.elapsed=.5
		match label:
			"beam":p.musashi.state=p.musashi.State.BEAM
			"meteor":p.musashi.state=p.musashi.State.METEOR_CAST
			"fireball":p.musashi.state=p.musashi.State.FIREBALL
			"hit":p.musashi.state=p.musashi.State.HIT_REACTION
			"shield":p.musashi.state=p.musashi.State.FIRE_SHIELD
		var velocity=Vector3(0,0,-8) if label=="run" else Vector3.ZERO
		var baseline=poses_for(reference_sk,velocity,label!="jump",label=="dodge")
		var baseline_l=model.hand_position("L");var baseline_r=model.hand_position("R")
		var integrated=poses_for(actual,velocity,label!="jump",label=="dodge")
		check(same_poses(baseline,integrated),label+": every animated bone matches the previous model")
		check(model.hand_position("L").is_equal_approx(baseline_l) and model.hand_position("R").is_equal_approx(baseline_r),label+": fireball and beam hand origins match at the enlarged display scale")
	model.skeleton=actual;p.musashi.cancel()
	model.locomotion=load(MOTION).new(model)
	for frame in 45:model.animate(.016,0,true,0,0,false,0,false)
	p.select_character(1)
	check(p.character_models[1].skin_id==HeroSkins.valid_id(game.settings.goemon_skin),"Goemon's chosen skin survives character switching")
	p.select_character(2)
	check(p.model==model and p.model.visible,"Switching back restores the revamped Edo")
	if "--visual" in OS.get_cmdline_user_args():
		root.size=Vector2i(1440,900);root.set_flag(Window.FLAG_NO_FOCUS,true)
		p.position=Vector3(-2,game.world.height_at(-2,30)+.12,30);p.rotation.y=PI
		game.camera_rig.yaw=0;game.camera_rig.pitch=.36;game.camera_rig.distance=14;game.camera_rig.current_distance=14;game.camera_rig.reset_follow();game.camera_rig._process(1);game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
		game.hud.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		await snap("gameplay")
		var cam=game.camera_rig.camera
		cam.global_position=p.global_position+Vector3(1.8,1.8,3.9);cam.look_at(p.global_position+Vector3.UP*1.18);cam.fov=40
		await snap("in-game-close")
		for state in ["run","beam","meteor"]:
			p.musashi.cancel();p.musashi.duration=1;p.musashi.elapsed=.28
			if state=="beam":p.musashi.state=p.musashi.State.BEAM
			if state=="meteor":p.musashi.state=p.musashi.State.METEOR_CAST
			poses_for(actual,Vector3(0,0,-8) if state=="run" else Vector3.ZERO,true,false)
			await snap("pose-"+state)
	print("EDO_ANIME_RESULT failures=",failures)
	game.queue_free();await process_frame;await process_frame
	quit(1 if failures else 0)
