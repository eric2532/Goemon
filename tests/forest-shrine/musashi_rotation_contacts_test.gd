extends SceneTree
## Actual Hero.strike against both supported enemy backends, including cover.
var checks=0
var failures=0
var fixture
var runtime
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label_)
func run():
	fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture)
	var game=await fixture.make_game("original")
	game.crowd.set_process(false);game.crowd.low_fidelity=false
	runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();game.add_child(runtime);runtime.configure(game)
	runtime.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model))
	game.tuning.critical_chance=0;game.character_tuning={}
	for backend in ["legacy","native"]:
		fixture.clear_targets();runtime.clear();game.model.army_runtime=runtime if backend=="native" else null
		var p=fixture.reset_player(13);p.set_physics_process(false);p.position=Vector3(0,.05,60)
		for i in 3:p.velocity=Vector3.DOWN*20;p.move_and_slide()
		p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD
		check(p.is_on_floor(),backend+": Mighty Strike begins from actual ground contact")
		var targets=[]
		# The retail soldier's fitted volume is longer along Z. Keep every
		# nearest surface within the existing 2.1m game reach, outside the hero.
		for offset in [Vector3.FORWARD*4.8,Vector3.BACK*4.8,Vector3.LEFT*3,Vector3.RIGHT*3]:
			var point=p.position+offset;point.y=0
			var row=game.model.waves.spawn_enemy(0,point);row.hp=10000;row.max_hp=10000
			var target
			if backend=="native":
				runtime.spawn(row.id,0,0,point,10000,3.9);target=runtime.enemy_target(row.id)
			else:
				target=load("res://scripts/forest/forest_raider.gd").new();target.game=game;target.forest_id=row.id;target.variant=0;target.position=point;target.swarm=true
				game.add_child(target);target.set_physics_process(false);target._sync_fitted_pose();target.hp=10000;target.max_hp=10000
			game.actors[row.id]=target;game.enemies.append(target);targets.append(target)
		await physics_frame;await physics_frame
		var c=p.active_ability;c.start_counter();c.tick(9.0/30.0)
		check(targets.all(func(e):return e.hp==10000),backend+": no damage before source tick ten")
		c.tick(1.0/30.0)
		check(targets.all(func(e):return e.hp<10000),backend+": source window damages front, back and both sides")
		check(p.model.rotation_effect.vortices.is_empty(),backend+": no effect before tick11 cue")
		c.tick(1.0/30.0)
		check(p.model.rotation_effect.vortices.size()==2,backend+": tick11 emits both original vortex actors")
		var first_effect=p.model.rotation_effect.vortices[0]
		var expected_anchor=p.model.rig_visual.global_transform*Vector3(0,.06,1.2)
		check(first_effect.global_position.distance_to(expected_anchor)<.0001,backend+": original pose-header spawn anchor")
		var hit_hp=targets.map(func(e):return e.hp)
		c.tick(.4)
		check(targets.map(func(e):return e.hp)==hit_hp,backend+": each victim takes one hit per Mighty Strike")
		check(p.model.rotation_effect.vortices[0]==first_effect,backend+": source cue emits once")
		var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
		var collider=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(1.2,4,.2);collider.shape=box;wall.add_child(collider)
		wall.position=p.position+Vector3(0,1,-.65);game.add_child(wall)
		await physics_frame;await physics_frame
		var ray_end=AttackChain.contact_point(targets[0],p.global_position+Vector3.UP,targets[0].global_position+Vector3.UP)
		var sight=PhysicsRayQueryParameters3D.create(p.global_position+Vector3.UP,ray_end,1)
		check(not p.get_world_3d().direct_space_state.intersect_ray(sight).is_empty(),backend+": the fixture wall actually separates Musashi from the fitted hurt volume")
		c.cancel();check(p.model.rotation_effect.vortices.is_empty(),backend+": cancellation removes owner effects")
		c.start_counter();c.tick(.7)
		check(targets[0].hp==hit_hp[0],backend+": solid cover blocks Mighty Strike damage")
		check(targets[1].hp<hit_hp[1] and targets[2].hp<hit_hp[2],backend+": a skipped-window frame still hits exposed victims exactly once")
		wall.free()
	game.model.army_runtime=null;runtime.clear();runtime.queue_free();await fixture.close();fixture.queue_free();await process_frame
	print("MUSASHI_ROTATION_CONTACTS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
