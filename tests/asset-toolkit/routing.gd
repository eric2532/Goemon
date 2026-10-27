extends SceneTree
## Published routes must resolve in the actual engine and keep source identities.
var failures=0
var checks=0
func _initialize():run.call_deferred()
func check(ok:bool,message:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",message)
func run():
	var routes=JSON.parse_string(FileAccess.get_file_as_string("res://assets/optimized/routes.json"))
	for source in routes:
		var target:String=routes[source]
		check(GameAssets.model_path(source)==target,"Route "+source)
		check(GameAssets.source_model_path(target)==source,"Reverse identity "+source)
		var scene=load(target)
		check(scene is PackedScene,"Imported candidate "+target)
		if scene is PackedScene:
			var instance=scene.instantiate();root.add_child(instance)
			check(instance.scene_file_path==target,"Actual scene "+source);instance.free()
		if source.begins_with("res://assets/models/"):
			var id=String(source).trim_prefix("res://assets/models/").trim_suffix(".glb")
			var instance=GameAssets.instantiate_model(id);check(instance.scene_file_path==target,"GameAssets load boundary "+id);instance.free()
	check(GameAssets.model_path("res://missing.glb")=="res://missing.glb","Unmapped sources retain normal loading")
	check(load("res://scripts/forest/forest_enemy_roles.gd").asset_path(2).is_empty(),"Retired Daruma has no gameplay asset route")
	print("ASSET_ROUTING_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
