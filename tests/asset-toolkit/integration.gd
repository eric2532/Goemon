extends SceneTree
## Compare actual imported animation state, then verify gameplay loader integration.
var failures=0
var checks=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func read_model(path:String)->Node3D:
	var doc=GLTFDocument.new();var state=GLTFState.new()
	check(doc.append_from_file(path,state)==OK,"GLB imports: "+path)
	var node=doc.generate_scene(state,30.0,false,false);root.add_child(node)
	return node
func player(node:Node)->AnimationPlayer:return node.find_child("AnimationPlayer",true,false) as AnimationPlayer
func sample(node:Node,clip:String,time:float):
	var animation=player(node);animation.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation.play(clip);animation.seek(time,true);animation.pause()
	for sk in node.find_children("*","Skeleton3D",true,false):sk.force_update_all_bone_transforms()
func visible_bounds(node:Node)->AABB:
	var result=AABB();var first=true
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		if mesh.global_basis.get_scale().length()<.025:continue
		for surface in mesh.mesh.get_surface_count():
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point=mesh.global_transform*vertex
				result=AABB(point,Vector3.ZERO) if first else result.expand(point);first=false
	return result
func compare_pair(source:String,optimized:String):
	var a=read_model(source);var b=read_model(optimized)
	var ap=player(a);var bp=player(b)
	check(ap.get_animation_list()==bp.get_animation_list(),"All imported clip names survive")
	var sa=a.find_child("Skeleton3D",true,false) as Skeleton3D
	var sb=b.find_child("Skeleton3D",true,false) as Skeleton3D
	if sa:check(sb!=null and sa.get_bone_count()==sb.get_bone_count(),"Joint counts match")
	for clip in ap.get_animation_list():
		check(absf(ap.get_animation(clip).length-bp.get_animation(clip).length)<.00001,"Clip duration "+clip)
		for fraction in [0.0,.25,.5,.75,1.0]:
			var time=ap.get_animation(clip).length*fraction
			sample(a,clip,time);sample(b,clip,time)
			if sa:
				for bone in sa.get_bone_count():
					var other=sb.find_bone(sa.get_bone_name(bone))
					check(other>=0 and sa.get_bone_global_pose(bone).is_equal_approx(sb.get_bone_global_pose(other)),"Bone pose "+clip+"/"+sa.get_bone_name(bone))
			else:
				var ab=visible_bounds(a);var bb=visible_bounds(b)
				check(ab.position.distance_to(bb.position)<.0001 and ab.size.distance_to(bb.size)<.0001,"Animated visible bounds "+clip+" @ "+str(fraction))
				for socket in ["socket_build_fx","socket_income_fx","socket_entrance"]:
					check(a.find_child(socket,true,false).global_transform.is_equal_approx(b.find_child(socket,true,false).global_transform),"Socket "+socket)
	a.free();b.free()
func run():
	compare_pair("res://assets/economy_v1/gold_mine/goldmine_v1.glb","res://assets/optimized/goldmine.glb")
	compare_pair("res://assets/characters/recovered_musashi/musashi.glb","res://assets/optimized/musashi.glb")
	check(load("res://scripts/recovered_musashi_model.gd").ASSET.resource_path=="res://assets/optimized/musashi.glb","Playable Musashi uses validated optimized model")
	check(load("res://scripts/fire_siege_structure.gd").MINE_SCENE.resource_path=="res://assets/optimized/goldmine.glb","Mine gameplay uses validated optimized model")
	print("ASSET_TOOLKIT_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
