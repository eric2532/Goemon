extends SceneTree
## Validate every registered derivative against actual Godot-imported source motion.
var failures=0
var checks=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func imported(path:String)->Node3D:
	if "--packed" in OS.get_cmdline_user_args():
		var packed=load(path) as PackedScene
		if packed==null:check(false,"Packed import "+path);return null
		var instance=packed.instantiate();root.add_child(instance);return instance
	var doc=GLTFDocument.new();var state=GLTFState.new()
	if doc.append_from_file(path,state)!=OK:check(false,"Import "+path);return null
	var scene=doc.generate_scene(state,30.0,false,false);root.add_child(scene);return scene
func animation(node:Node)->AnimationPlayer:return node.find_child("AnimationPlayer",true,false) as AnimationPlayer
func sample(node:Node,clip:String,time:float):
	var player=animation(node)
	if player:
		player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play(clip);player.seek(time,true);player.pause()
	for sk in node.find_children("*","Skeleton3D",true,false):sk.force_update_all_bone_transforms()
func bounds(node:Node)->AABB:
	var result=AABB();var first=true
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point=mesh.global_transform*vertex
				result=AABB(point,Vector3.ZERO) if first else result.expand(point);first=false
	return result
func check_pose(a:Node,b:Node,label_:String):
	var bones=a.find_children("*","Skeleton3D",true,false)
	for sk in bones:
		var other=b.find_child(String(sk.name),true,false) as Skeleton3D
		check(other!=null and other.get_bone_count()==sk.get_bone_count(),label_+" skeleton "+String(sk.name))
		if other==null:continue
		for bone in sk.get_bone_count():
			var index=other.find_bone(sk.get_bone_name(bone))
			check(index>=0 and sk.get_bone_global_pose(bone).is_equal_approx(other.get_bone_global_pose(index)),label_+" joint "+sk.get_bone_name(bone))
	if bones.is_empty():
		var ab=bounds(a);var bb=bounds(b)
		check(ab.position.distance_to(bb.position)<.001 and ab.size.distance_to(bb.size)<.001,label_+" visible geometry extent")
func pair(item:Dictionary):
	var a=imported("res://"+item.source);var b=imported("res://"+item.output)
	if a==null or b==null:return
	var ap=animation(a);var bp=animation(b)
	var ac=ap.get_animation_list() if ap else PackedStringArray()
	var bc=bp.get_animation_list() if bp else PackedStringArray()
	check(ac==bc,item.asset+" clip names")
	var protected=RegEx.new()
	if not item.get("preserve_mesh_nodes","").is_empty():
		protected.compile(item.preserve_mesh_nodes)
		for node in a.find_children("*","MeshInstance3D",true,false):
			if protected.search(String(node.name)):
				var other=b.find_child(String(node.name),true,false)
				check(other is MeshInstance3D,item.asset+" keeps named mesh "+String(node.name))
				if other is MeshInstance3D:
					check(other.get_blend_shape_count()==node.get_blend_shape_count(),item.asset+" morph channels "+String(node.name))
	check_pose(a,b,item.asset+" rest")
	for clip in ac:
		check(absf(ap.get_animation(clip).length-bp.get_animation(clip).length)<.00001,item.asset+" duration "+clip)
		for fraction in [0.0,.25,.5,.75,1.0]:
			var time=ap.get_animation(clip).length*fraction;sample(a,clip,time);sample(b,clip,time)
			check_pose(a,b,item.asset+" "+clip+" @ "+str(fraction))
	a.free();b.free()
func run():
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/optimized/manifest.json"))
	if "--staged" in OS.get_cmdline_user_args():
		var staged=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/gameplay-candidates.json"));manifest.assets.append_array(staged.assets)
	for item in manifest.assets:
		pair(item)
		print("GAMEPLAY_ASSET_CHECK ",item.asset," checks=",checks," failures=",failures)
		await process_frame
	print("GAMEPLAY_ASSET_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
