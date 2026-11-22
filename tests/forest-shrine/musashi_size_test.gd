extends SceneTree
## Real model, body, camera and source clock agree after the further 20% reduction.
const REDUCTION=.85*.8
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
	var reference=load("res://scripts/recovered_musashi_model.gd").new();reference.presentation_scale=3.0;root.add_child(reference);reference.hide();reference.set_process(false)
	await process_frame
	var current=bounds(p.model);var previous=bounds(reference)
	check(current.size.is_equal_approx(previous.size*REDUCTION),"Playable imported mesh is exactly 20% smaller than the previous 2.55 size on all three axes")
	check(current.size.y>5.4*REDUCTION and current.size.y<6.1*REDUCTION,"Musashi stands roughly 3.9 world metres high")
	check(p.model.outfit_mask==31,"A new playable Musashi wears every recovered equipment piece")
	var current_blade=p.model.sword_segment(false);var previous_blade=reference.sword_segment(false)
	check(current_blade.size()==2 and previous_blade.size()==2 and absf(current_blade[0].distance_to(current_blade[1])/previous_blade[0].distance_to(previous_blade[1])-REDUCTION)<.001,"Actual Fusion blade endpoints shrink with the imported rig")
	var shape=p.find_children("*","CollisionShape3D",false,false)[0]
	check(absf(shape.shape.height-5.55*REDUCTION)<.001 and absf(shape.shape.radius-1.14*REDUCTION)<.001 and absf(shape.position.y-2.85*REDUCTION)<.001,"Playable capsule shrinks with the body above its feet")
	check(p.scale.is_equal_approx(Vector3.ONE),"Intrinsic size leaves growth and reset root transforms available")
	game.camera_rig.distance=14;game.camera_rig.reset_follow()
	check(absf(game.camera_rig.follow.y-p.global_position.y-1.4)<.001,"Musashi uses the shared character camera anchor")
	check(game.camera_rig.distance==14,"The requested camera distance is retained so the fighter reads larger")
	p.attack_heavy=false;check(absf(p.melee_strike_reach()-5.4*REDUCTION)<.001,"Fusion contact reaches the resized blade")
	p.attack_heavy=true;check(absf(p.melee_strike_reach()-6.3*REDUCTION)<.001,"Lumina contact reaches the resized blade")
	var rows=[]
	for offset in [Vector3.FORWARD*4.5,Vector3.FORWARD*3.5+Vector3.UP*2,Vector3.FORWARD*9]:
		var row=game.model.waves.spawn_enemy(0,p.position+offset*REDUCTION);row.hp=10000;row.max_hp=10000;rows.append(row)
	game.sync_enemies()
	var nearby=game.actors[rows[0].id];var raised=game.actors[rows[1].id]
	await physics_frame;await physics_frame
	var combat=p.active_ability;p.attack_heavy=false;combat.primary_attack();combat.tick(.4)
	check(nearby.hp<10000,"Actual Fusion strike hits a native fitted victim at the resized reach")
	check(raised.hp<10000,"Actual resized contact reaches a raised native fitted hurt volume")
	check(game.actors[rows[2].id].hp==10000,"A native victim outside the resized strike remains unharmed")
	combat.cancel();fixture.clear_targets()
	var movement=p.active_ability.locomotion;movement.reset()
	movement.source_tick(Vector3.FORWARD,true,false,true,false,false)
	var run_velocity=Vector3.ZERO
	for i in 48:run_velocity=movement.source_tick(Vector3.FORWARD,true,false,true,false,false)
	check(absf(run_velocity.length()-17.82*REDUCTION)<.001,"Source run scales travel with the body in the unchanged 48 acceleration ticks")
	movement.source_tick(Vector3.ZERO,true,false,true,false,false);var skid=0.0
	for i in 11:skid+=movement.source_tick(Vector3.ZERO,true,false,true,false,false).length()/30.0
	check(absf(skid-2.376*REDUCTION)<.001,"Source skid keeps its eleven ticks and scales physical travel")
	p.select_character(1)
	check(absf(shape.shape.height-1.85)<.001 and absf(shape.shape.radius-.38)<.001 and absf(shape.position.y-.95)<.001,"Switching back restores Goemon's normal collision capsule")
	game.camera_rig.reset_follow();check(absf(game.camera_rig.follow.y-p.global_position.y-1.4)<.001,"Switching back restores the normal camera target")
	p.select_character(13);p.buildings_broken=1;p.grow_from_building()
	check(p.scale.x>1 and is_equal_approx(p.model.rig_visual.scale.x,5.4*REDUCTION),"Existing building growth still compounds with Musashi's intrinsic size")
	reference.free();await fixture.close();fixture.queue_free();await process_frame
	print("MUSASHI_SIZE_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
