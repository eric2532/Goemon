extends SceneTree
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok: bool,message: String):
	checks+=1
	if not ok:failures+=1;push_error(message)
	else:print("PASS: ",message)
func run():
	var fx=load("res://assets/rogue/scripts/effects.gd").new();root.add_child(fx)
	fx.particles(Vector3.ZERO,Color.RED,24,1)
	var batches=fx.find_children("*","MultiMeshInstance3D",true,false)
	check(batches.size()==1,"An impact burst uses one batched particle draw instead of individual spark nodes")
	if not batches.is_empty():
		var before=batches[0].multimesh.get_instance_transform(0).origin
		fx.tick(.1)
		check(before!=batches[0].multimesh.get_instance_transform(0).origin,"Batched sparks visibly travel during the combat clock")
	fx.tick(1);await process_frame
	check(fx.items.is_empty(),"Batched bursts expire and release their scene nodes")
	check(fx.has_method("apply_quality"),"Combat effects support the existing graphics quality setting")
	if fx.has_method("apply_quality"):
		fx.apply_quality(0);fx.particles(Vector3.ZERO,Color.RED,48,1)
		batches=fx.find_children("*","MultiMeshInstance3D",true,false)
		check(batches.size()==1 and batches[0].multimesh.instance_count<=6,"Low quality caps a large impact at six sparks")
		fx.clear();await process_frame
		for i in range(220):fx.ring(Vector3.ZERO,Color.RED,1,.3)
		check(fx.items.size()<=180,"Sustained effects cannot exceed the Low quality budget")
	fx.clear();await process_frame
	check(fx.items.is_empty() and fx.get_child_count()==0,"Hero interruption clears all transient VFX")
	fx.apply_quality(1)
	for i in range(24):fx.weapon_impact(Vector3.ZERO,0,"sword",Color.RED,false)
	batches=fx.find_children("*","MultiMeshInstance3D",true,false)
	check(batches.size()<=8,"A crowd contact caps impact visuals per combat frame without capping damage")
	fx.clear();await process_frame
	fx.queue_free();await process_frame
	print("COMBAT_VFX_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
