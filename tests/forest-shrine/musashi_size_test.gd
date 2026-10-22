extends SceneTree
## Real models, body, camera and source clock must agree at the larger presentation.
var checks=0
var failures=0
var fixture
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func bounds(model)->AABB:
	var result=AABB();var first=true
	for mesh in model.rig_visual.find_children("*","MeshInstance3D",true,false):
		var box=mesh.global_transform*mesh.get_aabb()
		result=box if first else result.merge(box);first=false
	return result
func run():
	fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture)
	var game=await fixture.make_game("original");fixture.clear_targets()
	var p=fixture.reset_player(13);p.set_physics_process(false);p.model.set_process(false)
	p.position=Vector3(0,.05,60);p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD
	var picker=load("res://scripts/recovered_musashi_outfit_picker.gd").new();root.add_child(picker);picker.set_process(false)
	await process_frame
	var large=bounds(p.model);var small=bounds(picker.preview)
	check(absf(large.size.y/small.size.y-3)<.001,"Playable imported mesh is three times the fitted equipment preview")
	check(large.size.y>5.4 and large.size.y<6.1,"Musashi stands roughly 5.6 world metres high")
	check(p.model.outfit_mask==31,"A new playable Musashi wears every recovered equipment piece")
	var large_blade=p.model.sword_segment(false);var small_blade=picker.preview.sword_segment(false)
	check(large_blade.size()==2 and small_blade.size()==2 and absf(large_blade[0].distance_to(large_blade[1])/small_blade[0].distance_to(small_blade[1])-3)<.001,"Actual Fusion blade endpoints grow with the imported rig")
	var shape=p.find_children("*","CollisionShape3D",false,false)[0]
	check(absf(shape.shape.height-5.55)<.001 and absf(shape.shape.radius-1.14)<.001 and absf(shape.position.y-2.85)<.001,"Playable capsule encloses the threefold body above its feet")
	check(p.scale.is_equal_approx(Vector3.ONE),"Intrinsic size leaves growth and reset root transforms available")
	game.camera_rig.distance=14;game.camera_rig.reset_follow()
	check(absf(game.camera_rig.follow.y-p.global_position.y-4.2)<.001,"Camera follows the enlarged torso")
	check(game.camera_rig.distance==14,"The requested camera distance is retained so the fighter reads larger")
	p.attack_heavy=false;check(absf(p.melee_strike_reach()-5.4)<.001,"Fusion contact reaches the enlarged blade")
	p.attack_heavy=true;check(absf(p.melee_strike_reach()-6.3)<.001,"Lumina contact reaches the enlarged blade")
	var outside_old_reach=fixture.add_target(p.position+Vector3.FORWARD*6.5);outside_old_reach.hp=10000;outside_old_reach.max_hp=10000
	var raised=fixture.add_target(p.position+Vector3.FORWARD*4.8+Vector3.UP*4.2);raised.hp=10000;raised.max_hp=10000
	await physics_frame;await physics_frame
	var combat=p.active_ability;p.attack_heavy=false;combat.primary_attack();combat.tick(.4)
	check(outside_old_reach.hp<10000,"Actual Fusion strike hits a fitted victim beyond the former reach")
	check(raised.hp<10000,"Actual enlarged contact reaches a raised fitted hurt volume")
	combat.cancel();fixture.clear_targets()
	var movement=p.active_ability.locomotion;movement.reset()
	movement.source_tick(Vector3.FORWARD,true,false,true,false,false)
	var run_velocity=Vector3.ZERO
	for i in 48:run_velocity=movement.source_tick(Vector3.FORWARD,true,false,true,false,false)
	check(absf(run_velocity.length()-17.82)<.001,"Source run travels threefold distance in the unchanged 48 acceleration ticks")
	movement.source_tick(Vector3.ZERO,true,false,true,false,false);var skid=0.0
	for i in 11:skid+=movement.source_tick(Vector3.ZERO,true,false,true,false,false).length()/30.0
	check(absf(skid-2.376)<.001,"Source skid keeps its eleven ticks and scales physical travel")
	p.select_character(1)
	check(absf(shape.shape.height-1.85)<.001 and absf(shape.shape.radius-.38)<.001 and absf(shape.position.y-.95)<.001,"Switching back restores Goemon's normal collision capsule")
	game.camera_rig.reset_follow();check(absf(game.camera_rig.follow.y-p.global_position.y-1.4)<.001,"Switching back restores the normal camera target")
	p.select_character(13);p.buildings_broken=1;p.grow_from_building()
	check(p.scale.x>1 and p.model.rig_visual.scale.x>5,"Existing building growth still compounds with Musashi's intrinsic size")
	picker.free();await fixture.close();fixture.queue_free();await process_frame
	print("MUSASHI_SIZE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
