extends SceneTree
## Run the actual roster pose code against source and optimized meshes.
class ComparisonActor extends "res://assets/rogue/scripts/actor.gd":
	var asset_override=""
	func model_asset_path()->String:return asset_override
var failures=0
var checks=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func run():
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/optimized/manifest.json"))
	if "--staged" in OS.get_cmdline_user_args():
		var staged=JSON.parse_string(FileAccess.get_file_as_string("res://build/Other Files/Asset Toolkit/gameplay-candidates.json"));manifest.assets.append_array(staged.assets)
	for item in manifest.assets:
		if not item.asset.begins_with("roster-"):continue
		var id=String(item.asset).trim_prefix("roster-")
		var a=ComparisonActor.new();a.asset_override="res://"+item.source;root.add_child(a);a.seed=0;a.setup(id)
		var b=ComparisonActor.new();b.asset_override="res://"+item.output;root.add_child(b);b.seed=0;b.setup(id)
		var states=[{"grounded":true},{"grounded":true,"motionSpeed":7.0,"localMotion":Vector3.BACK*7},{"grounded":false,"vertical":12.0},{"grounded":false,"vertical":-12.0},{"grounded":true,"blocking":true,"guardTime":1.0},{"grounded":true,"shot":.1},{"grounded":true,"flip":.25}]
		for stage in 3:
			states.append({"grounded":true,"attack":{"primary":true,"index":stage,"style":"cutlass","contact":.15,"time":.15,"duration":.4,"angle":0.0}})
		for state in states:
			for frame in 4:
				a.animate_pose(state,.016,frame*.016,1.0 if state.has("motionSpeed") else 0.0)
				b.animate_pose(state,.016,frame*.016,1.0 if state.has("motionSpeed") else 0.0)
				for key in a.joints:
					check(b.joints.has(key) and a.joints[key].node.global_transform.is_equal_approx(b.joints[key].node.global_transform),id+" driver "+key)
				var sa=a.cosplay_rig.skeleton;var sb=b.cosplay_rig.skeleton
				for bone in sa.get_bone_count():check(sa.get_bone_global_pose(bone).is_equal_approx(sb.get_bone_global_pose(sb.find_bone(sa.get_bone_name(bone)))),id+" joint "+sa.get_bone_name(bone))
				for mesh_name in ["Knight_Long_Dark_Navy_Cape","ScarfTail_Geometry"]:
					var am=a.model.find_child(mesh_name,true,false);var bm=b.model.find_child(mesh_name,true,false)
					if am is MeshInstance3D:
						check(bm is MeshInstance3D,id+" animated cloth stays addressable")
						for morph in am.get_blend_shape_count():check(absf(am.get_blend_shape_value(morph)-bm.get_blend_shape_value(morph))<.00001,id+" cape morph "+str(morph))
		a.free();b.free();await process_frame
		print("PROCEDURAL_ASSET_CHECK ",id," checks=",checks," failures=",failures)
	print("PROCEDURAL_ASSET_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
