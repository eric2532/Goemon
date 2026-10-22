extends SceneTree
const Model=preload("res://scripts/forest/forest_model.gd")
const Art=preload("res://scripts/forest/forest_art.gd")
const World=preload("res://scripts/forest/forest_world.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label_)
func run():
	var m=Model.new();m.reset(42);m.trees.clear();m.workers.clear()
	for b in m.buildings.values():
		if b.kind!="shrine":m._remove_building(b.id)
	var tower=m._make_building("tower",Vector2i(4,8),0);m.rebuild_navigation()
	var w={"id":90,"pos":m.center(tower),"hp":100.0,"max_hp":100.0,"state":"garrison","job":tower.id,"follow":false,"cargo":0,"timer":0.0,"safe":0.0,"path":[],"destination":Vector2i(-999,-999),"nav":-1}
	m.workers[w.id]=w;m.start_wave();m.workforce.assignment_clock=10000
	for x in range(-40,40):
		for z in range(-40,40):m.visible_cells[Vector2i(x,z)]=true
	var world=World.new();world.model=m;root.add_child(world);await process_frame;await physics_frame
	var crew:Node3D=world.worker_nodes[w.id]
	var space=world.get_world_3d().direct_space_state
	var center=m.center(tower)
	var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3(0,23,0),center+Vector3(0,17,0),1))
	check(not hit.is_empty() and is_equal_approx(hit.position.y,20),"Occupied deck has real collision above both walls and gate")
	check(is_equal_approx(crew.position.y,20),"Crew feet rest on the actual raised deck")
	var high_body=space.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3(0,17,-7),center+Vector3(0,17,7),1))
	check(not high_body.is_empty(),"Extended masonry body remains physically solid up to deck")
	var e=m.waves.spawn_enemy(0,center+Vector3(24,0,0));e.hp=1000;e.stun=100
	m.workforce.tick(0,m.hero_position);world.sync(0)
	check(m.workforce.arrows.size()==1,"Raised tower still fires at an enemy inside existing range")
	if not m.workforce.arrows.is_empty():
		var arrow=m.workforce.arrows.values()[0]
		var bow=crew.to_global(Vector3(.85,1.25,.6))
		check(arrow.from.distance_to(bow)<.001 and is_equal_approx(arrow.from.y,21.25),"Projectile starts at visible rotated bow on raised deck")
		check(is_equal_approx(w.timer,1.0/m.balance.tower_attack_speed),"Tower cadence remains unchanged")
		var hp=e.hp
		for i in 60:m.workforce.tick_arrows(1.0/60)
		check(is_equal_approx(e.hp,hp-m.balance.tower_damage),"Tower arrow retains one physical hit and existing damage")
	# An adjacent wall must sit below the real outgoing trajectory.
	m.enemies.clear();m.workforce.arrows.clear();w.timer=0
	var wall=m._make_building("wall",Vector2i(4,10),0);m.rebuild_navigation();m.revision+=1;world.sync(0)
	var far=m.waves.spawn_enemy(0,center+Vector3(0,0,47));far.hp=1000
	m.workforce.tick(0,m.hero_position)
	if not m.workforce.arrows.is_empty():
		var shot=m.workforce.arrows.values()[0]
		var to:Vector3=m.events.back().to
		check(m.waves.navigation.line_clear(shot.from,to,tower.id),"Raised bow trajectory clears the adjacent 16m wall toward a distant raider")
		var ray=PhysicsRayQueryParameters3D.create(shot.from,to,1)
		var ignored:Array[RID]=[]
		for body in world.structure_nodes[tower.id].get_children():
			if body is StaticBody3D:ignored.append(body.get_rid())
		ray.exclude=ignored
		check(space.intersect_ray(ray).is_empty(),"Actual outgoing arrow also clears native wall collision")
	else:check(false,"Raised crew fires past adjacent wall")
	m._remove_building(wall.id);m.rebuild_navigation()
	check(is_equal_approx(m.waves.arrows.worker_point(w).y,21.6),"Enemy arrows aim at raised crew torso")
	m.enemies.clear();m.workforce.arrows.clear();w.timer=0
	m.waves.spawn_enemy(0,center+Vector3(60,0,0));m.workforce.tick(0,m.hero_position)
	check(m.workforce.arrows.is_empty(),"Taller deck does not extend tower attack range")
	m.workforce.release_job(w);var entry=m.point(m.entry(tower));var distance=w.pos.distance_to(entry)
	check(is_equal_approx(w.deck_height,20),"Recall starts at occupied deck height")
	m.workforce.tick_exit(w,distance/16)
	check(is_equal_approx(w.deck_height,10),"Recall smoothly descends halfway to entrance")
	m.workforce.tick_exit(w,10)
	check(not w.has("exit_point") and w.pos==entry and is_zero_approx(w.deck_height),"Recall finishes at entrance without residual elevation")
	world.queue_free();await process_frame
	# Authored terrain can place the same lightweight tower on an 18m foundation.
	m.terrain.configure([{ "ax":4,"az":8,"bx":4,"bz":14,"width":6,"h0":18,"h1":18 }]);m.rebuild_navigation()
	w.state="garrison";w.job=tower.id;w.pos=m.center(tower)
	world=World.new();world.model=m;root.add_child(world);await process_frame;await physics_frame
	crew=world.worker_nodes[w.id];center=m.center(tower)
	check(is_equal_approx(center.y,18) and is_equal_approx(crew.position.y,38),"Garrison deck follows the raised tower foundation")
	space=world.get_world_3d().direct_space_state
	hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3(0,23,0),center+Vector3(0,17,0),1))
	check(not hit.is_empty() and is_equal_approx(hit.position.y,38),"Raised foundation carries the physical tower deck")
	check(not m.waves.navigation.line_clear(center+Vector3(0,17,-7),center+Vector3(0,17,7)),"Logical projectile blocker includes the raised foundation height")
	check(m.waves.navigation.line_clear(center+Vector3(0,27,-7),center+Vector3(0,27,7)),"Logical projectile blocker ends above the raised lookout")
	world.queue_free();await process_frame
	print("TALL_TOWERS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
