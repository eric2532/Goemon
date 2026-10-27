extends SceneTree
func _initialize():run.call_deferred()
func run():
	var source=load("res://assets/characters/recovered_kojiro/kojiro.glb").instantiate()
	var authored=load("res://assets/optimized/kojiro.glb" if "--optimized" in OS.get_cmdline_user_args() else "res://assets/models/characters/kojiro/kojiro.glb").instantiate()
	if "--staged" in OS.get_cmdline_user_args():
		authored.free()
		var document=GLTFDocument.new();var state=GLTFState.new()
		assert(document.append_from_file("res://build/Other Files/Asset Toolkit/Candidates/kojiro.glb",state)==OK)
		authored=document.generate_scene(state,30.0,false,false)
	root.add_child(source);root.add_child(authored)
	var a=source.find_child("AnimationPlayer",true,false);var b=authored.find_child("AnimationPlayer",true,false)
	a.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;b.callback_mode_process=a.callback_mode_process
	var checks=0;var maximum=0.0;var rotation_error=0.0;var failed=false
	for clip in a.get_animation_list():
		if clip=="RESET":continue
		assert(b.has_animation(clip));a.play(clip);b.play(clip)
		for factor in [0,.2,.4,.6,.8]:
			var time=a.get_animation(clip).length*factor;a.seek(time,true);b.seek(time,true)
			for i in 15:
				var before:Transform3D=source.find_child("Part_%02d"%i,true,false).global_transform
				var after:Transform3D=authored.find_child("Part_%02d"%i,true,false).global_transform
				maximum=maxf(maximum,before.origin.distance_to(after.origin))
				var error=maxf((before.basis.x-after.basis.x).length(),maxf((before.basis.y-after.basis.y).length(),(before.basis.z-after.basis.z).length()))
				rotation_error=maxf(rotation_error,error)
				if before.origin.distance_to(after.origin)>.0001 or error>.00001:
					printerr("MOTION_ERROR ",clip," part=",i," t=",time," position=",before.origin.distance_to(after.origin)," basis=",error);failed=true
				checks+=1
	print("KOJIRO_IMPORT checks=",checks," maximum_position_error=",maximum," basis_error=",rotation_error)
	# Prepared ground variants retain source part orientation and sword grip while
	# lifting the whole pose clear of the floor; no runtime retargeting is needed.
	a.play("Source__801e2170");a.seek(0,true)
	var floor_y=lowest_vertex(source)
	for section in [["Ground__turning_cut","Source__801e2660",24,20],["Ground__somersault_cut","Source__801e2708",30,24]]:
		assert(b.has_animation(section[0]));b.play(section[0]);a.play(section[1])
		for tick in section[2]:
			b.seek(tick/30.0,true)
			assert(lowest_vertex(authored)>=floor_y-.00001,"Prepared grounded attack penetrates the floor")
			if tick>=4 and tick<section[3]:
				a.seek(tick/30.0,true)
				var source_hand=source.find_child("Part_02",true,false).global_transform
				var prepared_hand=authored.find_child("Part_02",true,false).global_transform
				for i in 15:
					var before=source_hand.affine_inverse()*source.find_child("Part_%02d"%i,true,false).global_transform
					var after=prepared_hand.affine_inverse()*authored.find_child("Part_%02d"%i,true,false).global_transform
					var gap=before.origin.distance_to(after.origin)
					var angle_error=maxf((before.basis.x-after.basis.x).length(),maxf((before.basis.y-after.basis.y).length(),(before.basis.z-after.basis.z).length()))
					if gap>.0001 or angle_error>.00001:
						printerr("GROUND_MOTION_ERROR ",section[0]," tick=",tick," part=",i," gap=",gap," basis=",angle_error);failed=true
					checks+=1
	print("KOJIRO_GROUND_IMPORT checks=",checks," floor=",floor_y)
	source.free();authored.free();quit(1 if failed else 0)

func lowest_vertex(model:Node)->float:
	var result=INF
	for i in 15:
		var part=model.find_child("Part_%02d"%i,true,false) as MeshInstance3D
		for surface in part.mesh.get_surface_count():
			for vertex in part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				result=minf(result,(part.global_transform*vertex).y)
	return result
