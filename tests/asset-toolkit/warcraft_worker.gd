extends "res://tests/asset-toolkit/gameplay.gd"
const Worker=preload("res://scripts/forest/forest_worker_warcraft.gd")
const DATA="res://assets/characters/warcraft/peasant/"
func atlas_pose(image:Image,index:int,row:int)->Transform3D:
	var a=image.get_pixel(index*6,row);var b=image.get_pixel(index*6+1,row);var c=image.get_pixel(index*6+2,row)
	return Transform3D(Basis(Vector3(a.r,a.g,a.b),Vector3(b.r,b.g,b.b),Vector3(c.r,c.g,c.b)),Vector3(a.a,b.a,c.a))
func run():
	Worker.prepare();var resource=Worker.resource
	for path in resource.get_meta("source_hashes"):check(FileAccess.get_sha256(path)==resource.get_meta("source_hashes")[path],"Fresh worker bake: "+path)
	var motion:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA+"motion.json"))
	check(motion.clips.size()==22 and motion.meshes.size()==6,"All original actions and independent geosets survive export")
	var model=load(GameAssets.model_path("res://assets/models/characters/warcraft/peasant/peasant.glb")).instantiate();root.add_child(model)
	model.rotation.y=-PI/2;model.scale=Vector3.ONE*preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT/float(motion.standing_height);model.position.y=-float(motion.floor)*model.scale.x
	var image:Image=resource.get_meta("pose_texture").get_image();var player:AnimationPlayer=animation(model);var sk:Skeleton3D=model.find_child("Skeleton3D",true,false)
	for key in resource.get_meta("clips"):
		var clip:Dictionary=resource.get_meta("clips")[key]
		for fraction in [0.0,.25,.5,.75,.99]:
			var frame=mini(roundi(float(clip.count-1)*fraction),clip.count-1);var time=minf(frame/60.0,clip.duration-.00001)
			sample(model,clip.source,time)
			for i in resource.get_meta("palette").size():
				var p:Dictionary=resource.get_meta("palette")[i];var node:MeshInstance3D=model.find_child(p.mesh,true,false)
				var actual=atlas_pose(image,i,int(clip.start)+frame)
				var expected=sk.global_transform*sk.get_bone_global_pose(p.bone)*node.skin.get_bind_pose(p.bind)
				check(actual.is_equal_approx(expected),"Original skin transform: %s @ %d bind %d"%[key,frame,i])
				if key=="garrison" and frame==0 and sk.get_bone_name(p.bone)=="Bone_Hand_R":
					var grip=actual*node.skin.get_bind_pose(p.bind).affine_inverse().origin
					check(grip.distance_to(preload("res://scripts/forest/forest_structure_profile.gd").TOWER_MUZZLE_OFFSET)<.01,"Original bow hand fits the shared tower muzzle: "+str(grip))
				var alpha=image.get_pixel(i*6+3,int(clip.start)+frame).a
				var native_alpha:float=motion.clips[clip.source][mini(floori(time*30),motion.clips[clip.source].size()-1)].opacity[int(str(p.mesh).trim_prefix("Geoset_"))]
				if key in ["garrison","wounded"] and sk.get_bone_name(p.bone)=="AxHandle01":native_alpha=0
				check(absf(alpha-native_alpha)<.00001,"Native body/cargo visibility, prepared stowed tool: "+key)
	model.free()
	var worker=Worker.new();root.add_child(worker);worker.setup()
	check(not worker.update_worker({"state":"repair","id":0},0),"Entering work does not invent an early hammer cue")
	check(not worker.update_worker({"state":"repair","id":0},.23),"Work is silent before its native 234 ms event")
	check(worker.update_worker({"state":"repair","id":0},.24),"The native work event fires at 234 ms")
	check(not worker.update_worker({"state":"repair","id":0},.24),"A repeated presentation update cannot duplicate a cue")
	check(worker.update_worker({"state":"repair","id":0},.84),"The next work loop delivers exactly one cue")
	check(not worker.update_worker({"state":"mine","id":0},1.0),"Mining does not borrow construction hammer audio")
	worker.update_worker({"state":"deliver","id":0,"cargo":10},1.1);check(worker.clip=="walk_gold","Carrying ryo uses the native sack and walk")
	worker.free()
	var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA+"source.json"))
	for item in source.samples:
		var stream=load(DATA+"audio/"+item.file) as AudioStreamWAV
		var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(stream.data)
		check(FileAccess.get_sha256(DATA+"audio/"+item.file)==item.sha256 and hash.finish().hex_encode()==item.pcm_sha256 and stream.mix_rate==item.sample_rate,"Unchanged file and imported PCM: "+item.file)
	print("WARCRAFT_WORKER_ASSET_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
