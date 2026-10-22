extends SceneTree
func _initialize():
 call_deferred("start")
func start():
 var lab=load("res://asset_packs/cedar_pass/interior_lab/lab.gd").new()
 root.add_child(lab)
