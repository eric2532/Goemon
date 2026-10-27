extends SceneTree
## Prepare the original skin with the existing army atlas format and shader.
const Baker=preload("res://scripts/forest/crowd/army_pose_baker.gd")
const DATA="res://assets/characters/warcraft/peasant/"
const MODEL="res://assets/models/characters/warcraft/peasant/peasant.glb"
func _initialize():run.call_deferred()
func run():
	var motion:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA+"motion.json"))
	var model=load(GameAssets.model_path(MODEL)).instantiate();root.add_child(model)
	model.rotation.y=-PI/2;model.scale=Vector3.ONE*preload("res://scripts/character_proportions.gd").GOEMON_HEIGHT/float(motion.standing_height)
	model.position.y=-float(motion.floor)*model.scale.x
	var player:AnimationPlayer=model.find_child("AnimationPlayer",true,false)
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var mesh=ArrayMesh.new();var palette=[];var textures=[];var refs=[]
	for spec in motion.meshes:
		var node:MeshInstance3D=model.find_child(spec.name,true,false);var sk:Skeleton3D=node.get_node(node.skeleton)
		var a=node.mesh.surface_get_arrays(0);var bones=PackedFloat32Array();var weights=PackedFloat32Array();var uv2=PackedVector2Array();var binds={}
		for v in a[Mesh.ARRAY_VERTEX].size():
			uv2.append(Vector2(textures.size(),0))
			for k in 4:
				var bind=int(a[Mesh.ARRAY_BONES][v*4+k]);var weight=float(a[Mesh.ARRAY_WEIGHTS][v*4+k])
				if weight>0 and not binds.has(bind):
					var bone=node.skin.get_bind_bone(bind)
					if bone<0:bone=sk.find_bone(node.skin.get_bind_name(bind))
					assert(bone>=0);binds[bind]=palette.size();palette.append({"node":node,"sk":sk,"bone":bone,"bind":bind,"geoset":textures.size()})
				bones.append(binds.get(bind,0));weights.append(weight)
		refs.append({"mesh":node.name,"vertices":a[Mesh.ARRAY_VERTEX].size()})
		a[Mesh.ARRAY_BONES]=null;a[Mesh.ARRAY_WEIGHTS]=null;a[Mesh.ARRAY_CUSTOM0]=bones;a[Mesh.ARRAY_CUSTOM1]=weights;a[Mesh.ARRAY_TEX_UV2]=uv2
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a,[],{},(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
		textures.append(node.get_active_material(0).albedo_texture)
	var definitions={"idle":"Stand","walk":"Walk","idle_gold":"Stand Gold","walk_gold":"Walk Gold","mine":"Attack","repair":"Stand Work","garrison":"Stand Ready","wounded":"Stand"}
	var clips={};var rows=0
	for key in definitions:
		var duration=player.get_animation(definitions[key]).length;var count=ceili(duration*60)+1
		clips[key]={"source":definitions[key],"start":rows,"count":count,"duration":duration};rows+=count
	var image=Image.create(palette.size()*6,rows,false,Image.FORMAT_RGBAF);var helper=Baker.new()
	for key in clips:
		var clip:Dictionary=clips[key];player.play(clip.source)
		for frame in int(clip.count):
			var time=minf(frame/60.0,clip.duration-.00001)
			var skeleton:Skeleton3D=model.find_child("Skeleton3D",true,false);skeleton.reset_bone_poses();player.seek(time,true)
			var sample:Dictionary=motion.clips[clip.source][mini(floori(time*30),motion.clips[clip.source].size()-1)]
			for i in palette.size():
				var p:Dictionary=palette[i];p.sk.force_update_all_bone_transforms()
				var pose:Transform3D=p.sk.global_transform*p.sk.get_bone_global_pose(p.bone)*p.node.skin.get_bind_pose(p.bind)
				helper.put_pose(image,i,int(clip.start)+frame,pose)
				var value=image.get_pixel(i*6+3,int(clip.start)+frame)
				value.a=0.0 if key in ["garrison","wounded"] and p.sk.get_bone_name(p.bone)=="AxHandle01" else float(sample.opacity[p.geoset])
				image.set_pixel(i*6+3,int(clip.start)+frame,value)
	var props=Image.create(3,textures.size(),false,Image.FORMAT_RGBAF)
	for i in textures.size():props.set_pixel(2,i,Color.WHITE)
	var events:Dictionary={}
	for event in JSON.parse_string(FileAccess.get_file_as_string(DATA+"sound-events.json")):
		if event.sound=="Repair":events[event.animation]=event.offset_seconds
	var resource=Resource.new()
	var metadata={"mesh":mesh,"textures":textures,"properties":ImageTexture.create_from_image(props),"pose_texture":ImageTexture.create_from_image(image),"clips":clips,"fps":60,"vertex_refs":refs,"palette":palette.map(func(p):return {"mesh":p.node.name,"bone":p.bone,"bind":p.bind}),"work_offset":events["Stand Work"]}
	for key in metadata:resource.set_meta(key,metadata[key])
	var hashes={}
	for path in ["res://tools/bake_warcraft_worker.gd","res://scripts/forest/crowd/army_pose_baker.gd",DATA+"motion.json",DATA+"sound-events.json",GameAssets.model_path(MODEL)]:helper.fingerprint(path,hashes)
	resource.set_meta("source_hashes",hashes)
	var result=ResourceSaver.save(resource,DATA+"worker.res");assert(result==OK)
	print("WARCRAFT_WORKER_BAKE palette=",palette.size()," rows=",rows," surfaces=",mesh.get_surface_count());model.free();quit()
