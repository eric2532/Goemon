extends SceneTree
var failures: Array[String] = []
var results: Array = []
const DIR = "/workspace/scratch/23f1a29e8f92/tower_assets_v1/"
const CLIP = "Tower_Build_Recoil_Reverse"
const BUILD_LENGTH = 71.0 / 24.0
const REVERSE_START = 108.0 / 24.0

func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func walk(node: Node, kind: String) -> Array:
	var output: Array = []
	if node.is_class(kind): output.append(node)
	for child in node.get_children(): output.append_array(walk(child, kind))
	return output

func position_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func snapshot(meshes: Array) -> Dictionary:
	var result: Dictionary = {}
	for mesh in meshes:
		result[str(mesh.name)] = {"position":mesh.position,"scale":mesh.scale}
	return result

func check_snapshot(a: Dictionary, b: Dictionary, message: String) -> void:
	for name in a:
		require(a[name]["position"].distance_to(b[name]["position"]) < 0.004, message + " position " + name)
		require(a[name]["scale"].distance_to(b[name]["scale"]) < 0.004, message + " scale " + name)

func visible_meshes(meshes: Array) -> int:
	var count := 0
	for mesh in meshes:
		if mesh.global_transform.basis.get_scale().length() > 0.025: count += 1
	return count

func bounds(meshes: Array) -> Dictionary:
	var low := Vector3(INF,INF,INF)
	var high := Vector3(-INF,-INF,-INF)
	for mesh in meshes:
		var bb: AABB = mesh.mesh.get_aabb()
		for i in range(8):
			var point: Vector3 = mesh.global_transform * bb.get_endpoint(i)
			low = low.min(point); high = high.max(point)
	return {"min":position_array(low),"max":position_array(high),"size":position_array(high-low)}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var entries := [
		["tower_stage_empty.glb",15],["tower_stage_frame.glb",51],
		["tower_stage_assembling.glb",105],["tower_stage_complete.glb",170],
		["tower_wall_mount.glb",10],["arrow_projectile.glb",5],["tower_build_recoil_reverse.glb",170]
	]
	for entry in entries:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(DIR+"exports/"+entry[0],state)
		require(error == OK,entry[0]+" parsing failed")
		if error != OK: continue
		var model := document.generate_scene(state,24.0)
		require(model != null,entry[0]+" scene generation failed")
		if model == null: continue
		get_root().add_child(model)
		var meshes := walk(model,"MeshInstance3D")
		require(meshes.size() == entry[1],entry[0]+" mesh count")
		var names: Array = []
		var metadata_count := 0
		for mesh in meshes:
			require(not names.has(mesh.name),"Duplicate mesh name "+str(mesh.name))
			names.append(mesh.name)
			if mesh.has_meta("stable_id"): metadata_count += 1
		var result := {"file":entry[0],"mesh_count":meshes.size(),"names_unique":true,"meshes_with_stable_id_meta":metadata_count,"bounds":bounds(meshes)}
		if entry[0] == "arrow_projectile.glb":
			var arrow_root := model.find_child("ARROW_PROJECTILE_ROOT",true,false) as Node3D
			var tip := model.find_child("SOCKET_ARROW_TIP",true,false) as Node3D
			require(arrow_root!=null and tip!=null,"Standalone arrow roots missing")
			require(tip.global_position.length()<0.0001,"Standalone arrow tip is not at origin")
			result["tip_at_origin"]=position_array(tip.global_position)
			require(result["bounds"]["max"][2]<0.001,"Arrow geometry extends beyond tip in forward direction")
			require(abs(result["bounds"]["min"][2]+2.28)<.01,"Arrow length incorrect")
		if entry[0] == "tower_build_recoil_reverse.glb":
			var players := walk(model,"AnimationPlayer")
			require(players.size()==1,"Expected one AnimationPlayer")
			if players.is_empty(): continue
			var player: AnimationPlayer = players[0]
			require(player.has_animation(CLIP),"Missing merged clip")
			var animation: Animation = player.get_animation(CLIP)
			result["animation_names"] = Array(player.get_animation_list())
			result["clip_length"] = animation.length
			result["track_count"] = animation.get_track_count()
			var first_key := INF
			var last_key := -INF
			for track in range(animation.get_track_count()):
				for key in range(animation.track_get_key_count(track)):
					var t := animation.track_get_key_time(track,key)
					first_key=min(first_key,t); last_key=max(last_key,t)
			result["first_key_seconds"]=first_key;result["last_key_seconds"]=last_key
			require(abs(first_key)<0.0001,"Unexpected animation start offset")
			require(abs(animation.length - 179.0/24.0)<0.0001,"Unexpected animation length")
			player.play(CLIP)
			player.pause()
			var samples: Array = []
			var forward_snapshots: Dictionary = {}
			for p in [0.0,0.25,0.5,0.75,1.0]:
				player.seek(p*BUILD_LENGTH,true)
				forward_snapshots[str(p)]=snapshot(meshes)
				samples.append({"progress":p,"time":p*BUILD_LENGTH,"visible_meshes":visible_meshes(meshes)})
			result["normalized_build_samples"]=samples
			require(samples[0]["visible_meshes"]==15,"Empty build state incorrect")
			require(samples[4]["visible_meshes"]==170,"Complete build state incorrect")
			result["completed_bounds"]=bounds(meshes)
			var bsize: Array = result["completed_bounds"]["size"]
			require(abs(bsize[0]-3.55)<.01 and abs(bsize[1]-3.785)<.01 and abs(bsize[2]-3.425)<.01,"Converted complete bounds incorrect")
			var muzzle := model.find_child("SOCKET_ARROW_MUZZLE",true,false) as Node3D
			var launcher := model.find_child("LAUNCHER_YAW",true,false) as Node3D
			var projectile := model.find_child("ARROW_PROJECTILE",true,false) as Node3D
			var recoil := model.find_child("LAUNCHER_RECOIL",true,false) as Node3D
			require(muzzle!=null and launcher!=null and projectile!=null and recoil!=null,"Missing interface nodes")
			result["muzzle_complete_global"]=position_array(muzzle.global_position)
			require(muzzle.global_position.distance_to(Vector3(0,1.86,1.73))<.001,"Muzzle axis mapping incorrect")
			# Reverse and arbitrary resume seeks must reproduce matching forward poses.
			for p in [1.0,0.75,0.5,0.25,0.0]:
				player.seek(REVERSE_START+(1.0-p)*BUILD_LENGTH,true)
				check_snapshot(forward_snapshots[str(p)],snapshot(meshes),"Reverse p="+str(p))
			for p in [0.75,0.25,0.5,0.0,1.0]:
				player.seek(p*BUILD_LENGTH,true)
				check_snapshot(forward_snapshots[str(p)],snapshot(meshes),"Resume p="+str(p))
			result["reverse_pose_matches_forward"]=true
			result["arbitrary_decay_resume_seek_matches"]=true
			var firing: Array = []
			for frame in [79,81,82,88,91,98,108]:
				var time: float = (float(frame)-1.0)/24.0
				player.seek(time,true)
				firing.append({"frame":frame,"time":time,"recoil_global":position_array(recoil.global_position),"projectile_global":position_array(projectile.global_position),"projectile_scale":position_array(projectile.scale)})
			result["firing_samples"]=firing
			require(abs(firing[2]["recoil_global"][2]+0.16)<.004,"Recoil direction or distance incorrect")
			require(abs(firing[4]["projectile_global"][2]-5.0)<.004,"Projectile forward travel incorrect")
			require(abs(firing[5]["projectile_global"][2])<.004,"Projectile reload/reset failed")
		result["passed"]=failures.is_empty()
		results.append(result)
		model.queue_free()
	var report := {"engine":Engine.get_version_info(),"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"checks":results,"scope":"Isolated import/playback at 24 FPS only; no game project edited or gameplay executed","import_bake_fps":24}
	var out := FileAccess.open(DIR+"godot_validation/godot_import_report.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"  "));out.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
