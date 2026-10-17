extends SceneTree
## Catches the old procedural run overriding the user's saved Blender poses.
var failures=0
var checks=0
var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/goemon_edo_run.json"))
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",label)
func run():
	var ground=StaticBody3D.new();root.add_child(ground)
	var collider=CollisionShape3D.new();collider.shape=BoxShape3D.new()
	collider.shape.size=Vector3(200,.2,200);collider.position.y=-.1;ground.add_child(collider)
	await physics_frame
	for edo in [false,true]:
		var model=MusashiModel.new() if edo else HeroModel.new()
		root.add_child(model);model.set_process(false)
		var motion=model.locomotion
		for speed in [10.2,18.0]:
			model.locomotion_velocity=Vector3.FORWARD*speed
			for tick in range(180):
				model.animate(1.0/120,speed,true,0,0,false,0,false)
				model.sync_skeleton()
			motion.dt=0.0 # Sample a fixed pose without advancing Edo’s evaluate-driven gait clock.
			for frame in range(61):
				motion.phase=float(frame)/60.0*(TAU if edo else 1.0)
				motion.dirty=true;model.sync_skeleton()
				var position_error=0.0
				var rotation_error=0.0
				for b in range(source.bones.size()):
					var name_: String=source.bones[b]
					var sample: Array=source.frames[frame][b]
					var actual=model.skeleton.get_bone_global_pose(model.skeleton.find_bone(name_))
					var want=Vector3(sample[0],sample[1]+source.floor_offset,sample[2])
					position_error=maxf(position_error,actual.origin.distance_to(want))
					var rotation=Basis(Quaternion(sample[3],sample[4],sample[5],sample[6]).normalized())*model.skeleton.get_bone_global_rest(model.skeleton.find_bone(name_)).basis
					rotation_error=maxf(rotation_error,actual.basis.get_rotation_quaternion().angle_to(rotation.get_rotation_quaternion()))
				print("SOURCE_MATCH edo=",edo," speed=",speed," frame=",frame," position_error=",position_error," rotation_error=",rotation_error)
				check(position_error<.003 and rotation_error<.003,"%s at speed %s retains Blender pose %s"%["Edo" if edo else "Goemon",speed,frame])
			var hand=model.skeleton.get_bone_global_pose(model.skeleton.find_bone("Hand_R")).origin
			model.sync_skeleton()
			check(hand.distance_to(model.skeleton.get_bone_global_pose(model.skeleton.find_bone("Hand_R")).origin)<.00001,"Repeated sync never accumulates run transforms")
		# An airborne character must release the grounded run silhouette.
		for tick in range(60):
			model.animate(1.0/120,18.0,false,8,0,false,0,false);model.sync_skeleton()
		var foot=model.skeleton.get_bone_global_pose(model.skeleton.find_bone("Foot_L")).origin
		check(foot.distance_to(Vector3(-.322915,.194359,-.572132))>.1,"Jump releases the authored ground stride")
		model.free()
	print("USER_STRIDE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
