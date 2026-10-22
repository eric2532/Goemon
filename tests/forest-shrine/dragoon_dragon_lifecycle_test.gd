extends SceneTree
const FX=preload("res://assets/rogue/scripts/effects.gd")
var checks=0
var failures=0
func check(ok:bool,note:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+note)
func _initialize():run.call_deferred()
func run():
	var world=Node3D.new();root.add_child(world)
	var anchor=CharacterBody3D.new();world.add_child(anchor);anchor.velocity=Vector3.DOWN*45
	var fx=FX.new();fx.army_trails=true;fx.effect_budget=5;world.add_child(fx)
	var dive=fx.dragon_descent(anchor,0)
	check(dive.global_basis.y.normalized().is_equal_approx(Vector3.DOWN) and dive.global_basis.z.normalized().is_equal_approx(Vector3.BACK),"The helper's vertical dragon keeps its original downward spine and forward face")
	for i in 12:fx.lance_wave(Vector3.ZERO,12.6,i%3)
	check(is_instance_valid(dive) and not dive.is_queued_for_deletion(),"An army's small feedback pool retains its diving dragon under ordinary wave pressure")
	check(fx.items.size()<=5,"Protecting the dragon does not increase the army feedback cap")
	anchor.velocity=Vector3(0,-6,44);fx.tick(.016)
	check(dive.global_basis.y.normalized().dot(Vector3(0,-6,44).normalized())>.999,"The helper's existing oblique descent orientation stays aligned with its native trajectory")
	anchor.queue_free();await process_frame
	fx.tick(.016);await process_frame
	check(not is_instance_valid(dive),"Removing the attached body retires its diving dragon")
	fx.clear();await process_frame
	var eruption=fx.dragon_eruption(Vector3.ZERO,0)
	for i in 12:fx.lance_wave(Vector3.ZERO,12.6,i%3)
	check(not eruption.is_queued_for_deletion(),"Damage wave feedback cannot evict a fresh landing dragon before it is drawn")
	fx.tick(0);fx.tick(1.6);await process_frame
	check(not is_instance_valid(eruption),"A protected eruption still expires normally")
	world.queue_free();await process_frame
	print("DRAGOON_DRAGON_LIFECYCLE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
